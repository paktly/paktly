import { afterAll, describe, expect, it } from "vitest";
import postgres from "postgres";
import { randomUUID } from "node:crypto";
import { APP_REVIEW_EMAIL, requestEmailOtp, verifyEmailOtp } from "../src/modules/auth/email-otp.js";
import type { Environment } from "../src/config/environment.js";
import { loadEnvironment } from "../src/config/environment.js";
import { createApp } from "../src/app.js";

const url = process.env.TEST_APP_REVIEW_DATABASE_URL;
describe.skipIf(!url)("dedicated reviewer OTP (disposable database only)", () => {
  const db = postgres(url ?? "postgres://unused", { max: 2 });
  const config: NonNullable<Environment["emailAuth"]> = {
    enabled: true, from: "test@example.com", otpSecret: "test-only-secret-abcdefghijklmnopqrstuvwxyz",
    review: { pin: "654321", expiresAt: new Date(Date.now() + 3_600_000).toISOString() }
  };
  afterAll(async () => { await db.end(); });

  it("fails closed when disabled or expired", async () => {
    const disabled = { enabled: true, from: "test", otpSecret: config.otpSecret! };
    await expect(requestEmailOtp(db, APP_REVIEW_EMAIL, disabled, "test")).rejects.toThrow("EMAIL_AUTH_DISABLED");
    await expect(requestEmailOtp(db, APP_REVIEW_EMAIL, { ...config, review: { pin: "654321", expiresAt: "2020-01-01T00:00:00Z" } }, "test")).rejects.toThrow("EMAIL_AUTH_DISABLED");
  });

  it("never takes over an ordinary account", async () => {
    const id = randomUUID();
    await db`INSERT INTO users(id,email) VALUES(${id},${APP_REVIEW_EMAIL})`;
    await expect(requestEmailOtp(db, APP_REVIEW_EMAIL, config, "test")).rejects.toThrow("REVIEW_ACCOUNT_CONFLICT");
    await db`DELETE FROM users WHERE id=${id}`;
  });

  it("persists five failures and rejects reuse; creates only the dedicated account", async () => {
    const challenge = await requestEmailOtp(db, " APP-REVIEW@PAKTLY.IO ", config, "production");
    expect(challenge).toMatchObject({ delivery: "app-review" });
    expect(challenge).not.toHaveProperty("developmentCode");
    const input = { challengeId: challenge.challengeId, email: APP_REVIEW_EMAIL, code: "000000" };
    await expect(requestEmailOtp(db, APP_REVIEW_EMAIL, config, "test")).rejects.toThrow("OTP_RATE_LIMITED");
    for (let i = 0; i < 5; i++) await expect(verifyEmailOtp(db, input, config)).rejects.toThrow("OTP_INVALID");
    const [failed] = await db`SELECT attempts, consumed_at FROM email_otp_challenges WHERE id=${challenge.challengeId}`;
    expect(failed!.attempts).toBe(5);
    expect(failed!.consumed_at).not.toBeNull();
    await expect(verifyEmailOtp(db, { ...input, code: "654321" }, config)).rejects.toThrow("OTP_INVALID");

    const next = await requestEmailOtp(db, APP_REVIEW_EMAIL, config, "production");
    const correct = { ...input, challengeId: next.challengeId, code: "654321" };
    await expect(verifyEmailOtp(db, { ...correct, email: "other@example.com" }, config)).rejects.toThrow("OTP_INVALID");
    await expect(verifyEmailOtp(db, correct, { ...config, review: { ...config.review!, pin: "777777" } })).rejects.toThrow("OTP_INVALID");
    const session = await verifyEmailOtp(db, correct, config);
    expect(session.user.email).toBe(APP_REVIEW_EMAIL);
    expect(session.expiresAt).toBe(config.review!.expiresAt);
    const [user] = await db`SELECT is_app_review FROM users WHERE id=${session.user.id}`;
    expect(user!.is_app_review).toBe(true);
    await expect(verifyEmailOtp(db, correct, config)).rejects.toThrow("OTP_INVALID");
    for (const enabled of [true, false]) {
      const app = await createApp({
        ...loadEnvironment({ NODE_ENV: "test", DATABASE_URL: url! }),
        emailAuth: enabled ? config : { enabled: true, from: "test", otpSecret: config.otpSecret! }
      });
      try {
        const response = await app.inject({ method: "GET", url: "/api/v1/me", headers: { authorization: `Bearer ${session.accessToken}` } });
        expect(response.statusCode).toBe(enabled ? 200 : 401);
      } finally { await app.close(); }
    }
  });

  it("normal addresses still receive random emailed codes and cannot use the review PIN", async () => {
    const email = `${randomUUID()}@example.com`;
    let delivered = "";
    const challenge = await requestEmailOtp(db, email, config, "production", {
      sendAuthenticationCode: ({ code }) => { delivered = code; return Promise.resolve(); },
      sendPlanInvitation: async () => {}
    });
    expect(delivered).toMatch(/^\d{6}$/);
    const wrong = delivered === "654321" ? "000000" : "654321";
    await expect(verifyEmailOtp(db, { challengeId: challenge.challengeId, email, code: wrong }, config)).rejects.toThrow("OTP_INVALID");
    const session = await verifyEmailOtp(db, { challengeId: challenge.challengeId, email, code: delivered }, config);
    const [user] = await db`SELECT is_app_review FROM users WHERE id=${session.user.id}`;
    expect(user!.is_app_review).toBe(false);
  });
});
