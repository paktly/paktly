import { randomUUID } from "node:crypto";
import { afterAll, beforeAll, describe, expect, it } from "vitest";
import { createApp } from "../src/app.js";
import type { Environment } from "../src/config/environment.js";
import { createSocketFiSession } from "../src/modules/auth/authentication.js";
import { requestEmailOtp, verifyEmailOtp } from "../src/modules/auth/email-otp.js";

const databaseUrl = process.env.TEST_DATABASE_URL;
const suite = databaseUrl ? describe : describe.skip;

suite("SocketFi identity persistence", () => {
  const environment: Environment = {
    apiHost: "127.0.0.1",
    apiPort: 4000,
    corsOrigins: ["http://localhost:3000"],
    databaseUrl: databaseUrl!,
    logLevel: "silent",
    nodeEnvironment: "test",
    rateLimitMax: 300,
    rateLimitWindowMs: 60_000,
    trustedProxies: ["loopback", "linklocal", "uniquelocal"],
    socketFi: {
      apiUrl: "https://api.socket.fi",
      clientId: "sf_client_live_mq2aa2w2ofwynne6gkftyendov8k",
      clientSecret: "test-socketfi-secret",
      issuer: "https://socket.fi",
      origin: "https://socket.fi",
      network: "TESTNET"
    }
  };
  let app: Awaited<ReturnType<typeof createApp>>;

  beforeAll(async () => {
    app = await createApp(environment);
  });

  afterAll(async () => {
    await app.close();
  });

  it("maps one SocketFi subject to one Paktly user and updates its network wallet", async () => {
    const subject = `socketfi-test-${randomUUID()}`;
    const addressSuffix = randomUUID().replaceAll("-", "").slice(0, 12).toUpperCase();
    const firstAddress = `CTESTNETONE${addressSuffix}`;
    const secondAddress = `CTESTNETTWO${addressSuffix}`;
    const first = await createSocketFiSession(app.db, {
      subject,
      username: "socketfi-123456",
      wallets: { TESTNET: firstAddress },
      network: "TESTNET"
    });
    const second = await createSocketFiSession(app.db, {
      subject,
      username: "socketfi-123456",
      wallets: { TESTNET: secondAddress },
      network: "TESTNET"
    });

    expect(second.user.id).toBe(first.user.id);
    expect(second.wallet).toBe(secondAddress);
    expect(second.accessToken).not.toBe(first.accessToken);

    const [identityCount] = await app.db`
      SELECT count(*)::int AS count FROM auth_identities
      WHERE provider='SOCKETFI' AND provider_subject=${subject}
    `;
    expect(Number(identityCount?.count)).toBe(1);

    const profile = await app.inject({
      method: "GET",
      url: "/api/v1/me",
      headers: { authorization: `Bearer ${second.accessToken}` }
    });
    expect(profile.statusCode).toBe(200);
    expect(profile.json().profile).toMatchObject({
      display_name: "Paktly member",
      username: null,
      smartAccount: {
        provider: "SOCKETFI",
        network: "TESTNET",
        address: secondAddress
      }
    });
  });

  it("uses a SocketFi project username as the editable initial Paktly username", async () => {
    const suffix = randomUUID().replaceAll("-", "").slice(0, 8);
    const projectUsername = `paktly_user_${suffix}`;
    const session = await createSocketFiSession(app.db, {
      subject: `socketfi-project-user-${randomUUID()}`,
      username: `${projectUsername}--internal-id`,
      projectUsername,
      wallets: { TESTNET: `CPROJECTUSER${suffix.toUpperCase()}` },
      network: "TESTNET"
    });
    const profile = await app.inject({
      method: "GET",
      url: "/api/v1/me",
      headers: { authorization: `Bearer ${session.accessToken}` }
    });
    expect(profile.statusCode).toBe(200);
    expect(profile.json().profile).toMatchObject({
      display_name: projectUsername,
      username: projectUsername
    });
  });

  it("creates a Paktly account through a single-use email OTP without a wallet", async () => {
    const email = `otp-${randomUUID()}@example.com`;
    const emailAuth = {
      enabled: true,
      otpSecret: "test-only-email-otp-secret-with-32-characters",
      from: "Paktly Test <test@example.com>"
    };
    const challenge = await requestEmailOtp(app.db, email, emailAuth, "test");
    if (!challenge.developmentCode) throw new Error("Expected a test OTP code");
    const session = await verifyEmailOtp(app.db, {
      challengeId: challenge.challengeId,
      email,
      code: challenge.developmentCode
    }, emailAuth);
    expect(session.isNewUser).toBe(true);
    expect(session.user).toMatchObject({ email, displayName: "Paktly member", smartAccount: null });
    await expect(verifyEmailOtp(app.db, {
      challengeId: challenge.challengeId,
      email,
      code: challenge.developmentCode
    }, emailAuth)).rejects.toThrow("OTP_INVALID");
  });
});
