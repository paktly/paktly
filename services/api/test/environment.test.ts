import { describe, expect, it } from "vitest";
import { loadEnvironment } from "../src/config/environment.js";

describe("loadEnvironment", () => {
  it("provides safe local defaults", () => {
    expect(loadEnvironment({})).toEqual({
      apiHost: "0.0.0.0",
      apiPort: 4000,
      corsOrigins: ["http://localhost:3000"],
      databaseUrl: "postgres://pakt:pakt_local_only@localhost:56432/pakt",
      logLevel: "info",
      nodeEnvironment: "development"
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
});
