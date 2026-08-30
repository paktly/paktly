import { describe, expect, it } from "vitest";
import type { Environment } from "../src/config/environment.js";
import { loggerOptions } from "../src/platform/logger.js";

const productionEnvironment: Environment = {
  apiHost: "0.0.0.0",
  apiPort: 4000,
  corsOrigins: ["https://paktly.io"],
  databaseUrl: "postgres://pakt:pakt_local_only@localhost:56432/pakt",
  logLevel: "info",
  nodeEnvironment: "production",
  rateLimitMax: 300,
  rateLimitWindowMs: 60_000,
  trustedProxies: ["loopback", "linklocal", "uniquelocal"]
};

describe("loggerOptions", () => {
  it("disables log output under test", () => {
    expect(
      loggerOptions({ ...productionEnvironment, nodeEnvironment: "test" })
    ).toBe(false);
  });

  it("redacts credential-bearing fields outside test", () => {
    const options = loggerOptions(productionEnvironment);
    expect(options).not.toBe(false);
    if (options !== false) {
      expect(options.redact.paths).toContain("req.headers.authorization");
      expect(options.redact.censor).toBe("[REDACTED]");
    }
  });
});
