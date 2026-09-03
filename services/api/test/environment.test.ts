import { describe, expect, it } from "vitest";
import { loadEnvironment } from "../src/config/environment.js";

describe("loadEnvironment", () => {
  it("provides safe local defaults", () => {
    expect(loadEnvironment({})).toEqual({
      apiHost: "0.0.0.0",
      apiPort: 4000,
      corsOrigins: ["http://localhost:3000"],
      databaseUrl: "postgres://pakt:pakt_local_only@localhost:56432/pakt",
      emailAuth: {
        enabled: false,
        from: "Paktly <hello@paktly.io>",
        publicAppUrl: "https://paktly.io"
      },
      appleAuth: {
        enabled: false,
        clientId: "io.paktly.app"
      },
      googleAuth: {
        enabled: false,
        serverClientId: "not-configured"
      },
      apns: {
        enabled: false,
        teamId: "0000000000",
        keyId: "0000000000",
        privateKey: "disabled",
        bundleId: "io.paktly.app"
      },
      assistant: {
        enabled: false,
        apiKey: "disabled",
        model: "gpt-5.4-mini"
      },
      logLevel: "info",
      nodeEnvironment: "development",
      rateLimitMax: 300,
      rateLimitWindowMs: 60_000,
      trustedProxies: ["loopback", "linklocal", "uniquelocal"],
      socketFi: {
        apiUrl: "https://api.socket.fi",
        clientId: "sf_client_live_mq2aa2w2ofwynne6gkftyendov8k",
        clientSecret: "development-only-socketfi-secret",
        issuer: "https://socket.fi",
        origin: "https://socket.fi",
        network: "TESTNET"
      }
    });
  });

  it("normalizes multiple allowed origins", () => {
    expect(
      loadEnvironment({ CORS_ORIGINS: "https://pakt.example, https://app.pakt.example" })
        .corsOrigins
    ).toEqual(["https://pakt.example", "https://app.pakt.example"]);
  });

  it("fails fast for an invalid port", () => {
    expect(() => loadEnvironment({ API_PORT: "70000" })).toThrow(
      "Invalid environment configuration"
    );
  });

  it("rejects an empty origin list", () => {
    expect(() => loadEnvironment({ CORS_ORIGINS: " , " })).toThrow(
      "CORS_ORIGINS is empty"
    );
  });

  it("requires explicit secure production connectivity", () => {
    expect(() => loadEnvironment({ NODE_ENV: "production" })).toThrow(
      "DATABASE_URL is required in production"
    );
    expect(() =>
      loadEnvironment({
        NODE_ENV: "production",
        DATABASE_URL: "postgres://user:pass@postgres/db"
      })
    ).toThrow("CORS_ORIGINS is required in production");
    expect(() =>
      loadEnvironment({
        NODE_ENV: "production",
        DATABASE_URL: "postgres://user:pass@postgres/db",
        CORS_ORIGINS: "http://paktly.io"
      })
    ).toThrow("must use HTTPS");
  });

  it("requires OTP and SMTP secrets whenever email auth is enabled", () => {
    expect(() => loadEnvironment({
      EMAIL_AUTH_ENABLED: "true"
    })).toThrow("EMAIL_OTP_SECRET, SMTP_HOST, SMTP_USERNAME, and SMTP_PASSWORD");
  });

  it("requires an OpenAI key whenever Ask Paktly is enabled", () => {
    expect(() => loadEnvironment({ AI_ASSISTANT_ENABLED: "true" })).toThrow(
      "OPENAI_API_KEY is required"
    );
    expect(loadEnvironment({
      AI_ASSISTANT_ENABLED: "true",
      OPENAI_API_KEY: "sk-test-key-that-is-long-enough"
    }).assistant).toMatchObject({ enabled: true, model: "gpt-5.4-mini" });
  });

  it("loads a secure SMTP email transport", () => {
    expect(loadEnvironment({
      EMAIL_AUTH_ENABLED: "true",
      EMAIL_OTP_SECRET: "a".repeat(32),
      SMTP_HOST: "smtppro.zoho.com",
      SMTP_PORT: "465",
      SMTP_SECURE: "true",
      SMTP_USERNAME: "hello@paktly.io",
      SMTP_PASSWORD: "app-specific-password"
    }).emailAuth).toEqual({
      enabled: true,
      otpSecret: "a".repeat(32),
      from: "Paktly <hello@paktly.io>",
      publicAppUrl: "https://paktly.io",
      smtp: {
        host: "smtppro.zoho.com",
        port: 465,
        secure: true,
        username: "hello@paktly.io",
        password: "app-specific-password"
      }
    });
  });

  it("requires provider client IDs when federated authentication is enabled", () => {
    expect(() => loadEnvironment({ APPLE_AUTH_ENABLED: "true" })).toThrow("APPLE_CLIENT_ID");
    expect(() => loadEnvironment({ GOOGLE_AUTH_ENABLED: "true" })).toThrow("GOOGLE_SERVER_CLIENT_ID");
  });

  it("requires APNs signing credentials when push delivery is enabled", () => {
    expect(() => loadEnvironment({ APNS_ENABLED: "true" })).toThrow("APNS_TEAM_ID");
  });
});
