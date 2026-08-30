import type { FastifyPluginCallback } from "fastify";
import type { HealthResponse } from "@pakt/api-types";

const healthResponseSchema = {
  type: "object",
  additionalProperties: false,
  required: ["status", "service", "version", "timestamp"],
  properties: {
    service: { type: "string" },
    status: { type: "string", enum: ["ok"] },
    timestamp: { type: "string", format: "date-time" },
    version: { type: "string" }
  }
} as const;

export function healthRoutes(checkDependencies: () => Promise<void>): FastifyPluginCallback {
  return (app, _options, done) => {
  app.get(
    "/health",
    {
      schema: {
        description: "Process liveness check",
        response: { 200: healthResponseSchema },
        tags: ["platform"]
      }
    },
    async (): Promise<HealthResponse> => {
      await checkDependencies();
      return {
      service: "paktly-api",
      status: "ok" as const,
      timestamp: new Date().toISOString(),
      version: "0.1.0"
      };
    }
  );

  app.get(
    "/ready",
    {
      schema: {
        description: "Dependency readiness check",
        response: { 200: healthResponseSchema },
        tags: ["platform"]
      }
    },
    (): HealthResponse => ({
      service: "paktly-api",
      status: "ok" as const,
      timestamp: new Date().toISOString(),
      version: "0.1.0"
    })
  );
  done();
  };
}
