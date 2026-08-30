import { afterEach, describe, expect, it } from "vitest";
import Fastify from "fastify";
import { createApp } from "../src/app.js";
import type { Environment } from "../src/config/environment.js";
import { healthRoutes } from "../src/modules/health/routes.js";

const testEnvironment: Environment = {
  apiHost: "127.0.0.1",
  apiPort: 4000,
  corsOrigins: ["http://localhost:3000"],
  databaseUrl: "postgres://pakt:pakt_local_only@localhost:56432/pakt",
  logLevel: "silent",
  nodeEnvironment: "test",
  rateLimitMax: 300,
  rateLimitWindowMs: 60_000,
  trustedProxies: ["loopback", "linklocal", "uniquelocal"],
  socketFi: { apiUrl: "https://api.socket.fi", clientId: "paktly", clientSecret: "test-socketfi-secret", issuer: "https://socket.fi", origin: "https://socket.fi", network: "TESTNET" }
};

const apps: Awaited<ReturnType<typeof createApp>>[] = [];

afterEach(async () => {
  await Promise.all(apps.splice(0).map(async (app) => app.close()));
});

describe("platform routes", () => {
  it("reports liveness and returns the request ID", async () => {
    const app = await createApp(testEnvironment);
    apps.push(app);

    const response = await app.inject({
      headers: { "x-request-id": "test-request-1" },
      method: "GET",
      url: "/api/v1/health"
    });

    expect(response.statusCode).toBe(200);
    expect(response.headers["x-request-id"]).toBe("test-request-1");
    expect(response.json()).toMatchObject({
      service: "paktly-api",
      status: "ok",
      version: "0.1.0"
    });
  });

  it("returns a standardized not-found response", async () => {
    const app = await createApp(testEnvironment);
    apps.push(app);

    const response = await app.inject({ method: "GET", url: "/missing" });
    const payload = response.json();

    expect(response.statusCode).toBe(404);
    expect(payload.error.code).toBe("NOT_FOUND");
    expect(payload.error.requestId).toBeTypeOf("string");
  });

  it("reports dependency readiness", async () => {
    const app = await createApp(testEnvironment);
    apps.push(app);

    const response = await app.inject({ method: "GET", url: "/api/v1/ready" });

    expect(response.statusCode).toBe(200);
    expect(response.json().status).toBe("ok");
  });

  it("returns 503 readiness without leaking dependency errors", async () => {
    const app = Fastify();
    apps.push(app);
    await app.register(
      healthRoutes(() =>
        Promise.reject(new Error("postgres://secret-password@database"))
      )
    );

    const response = await app.inject({ method: "GET", url: "/ready" });

    expect(response.statusCode).toBe(503);
    expect(response.json()).toMatchObject({
      service: "paktly-api",
      status: "unavailable"
    });
    expect(response.body).not.toContain("secret-password");
  });

  it("enforces the configured global rate limit", async () => {
    const app = await createApp({ ...testEnvironment, rateLimitMax: 1 });
    apps.push(app);
    app.get("/test/rate-limit", () => ({ ok: true }));

    const first = await app.inject({ method: "GET", url: "/test/rate-limit" });
    const second = await app.inject({ method: "GET", url: "/test/rate-limit" });

    expect(first.statusCode).toBe(200);
    expect(second.statusCode).toBe(429);
  });

  it("returns safe client errors", async () => {
    const app = await createApp(testEnvironment);
    apps.push(app);
    app.get("/test/client-error", () => {
      throw app.httpErrors.badRequest("The request is invalid.");
    });

    const response = await app.inject({ method: "GET", url: "/test/client-error" });

    expect(response.statusCode).toBe(400);
    expect(response.json().error).toMatchObject({
      code: "REQUEST_ERROR",
      message: "The request is invalid."
    });
  });

  it("redacts unexpected server errors from responses", async () => {
    const app = await createApp(testEnvironment);
    apps.push(app);
    app.get("/test/server-error", () => {
      throw new Error("database credential appeared here");
    });

    const response = await app.inject({ method: "GET", url: "/test/server-error" });

    expect(response.statusCode).toBe(500);
    expect(response.json().error).toMatchObject({
      code: "INTERNAL_ERROR",
      message: "Something went wrong. Please try again."
    });
    expect(response.body).not.toContain("database credential");
  });
});
