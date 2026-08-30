import { randomUUID } from "node:crypto";
import { afterAll, beforeAll, describe, expect, it } from "vitest";
import { createApp } from "../src/app.js";
import type { Environment } from "../src/config/environment.js";
import { createSocketFiSession } from "../src/modules/auth/authentication.js";

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
      clientId: "paktly",
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
    const first = await createSocketFiSession(app.db, {
      subject,
      username: "Native member",
      wallets: { TESTNET: "CTESTNETONE" },
      network: "TESTNET"
    });
    const second = await createSocketFiSession(app.db, {
      subject,
      username: "Native member",
      wallets: { TESTNET: "CTESTNETTWO" },
      network: "TESTNET"
    });

    expect(second.user.id).toBe(first.user.id);
    expect(second.wallet).toBe("CTESTNETTWO");
    expect(second.accessToken).not.toBe(first.accessToken);

    const [identityCount] = await app.db`
      SELECT count(*)::int AS count FROM auth_identities
      WHERE provider='SOCKETFI' AND provider_subject=${subject}
    `;
    expect(Number(identityCount?.count)).toBe(1);
  });
});
