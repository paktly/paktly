import type { Environment } from "../config/environment.js";

export function loggerOptions(environment: Environment) {
  if (environment.nodeEnvironment === "test") {
    return false as const;
  }

  return {
    level: environment.logLevel,
    redact: {
      censor: "[REDACTED]",
      paths: [
        "req.headers.authorization",
        "req.headers.cookie",
        "res.headers.set-cookie",
        "password",
        "passkeyAssertion",
        "privateKey",
        "token"
      ]
    }
  };
}
