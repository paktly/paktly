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

const unavailableResponseSchema = {
  type: "object",
  additionalProperties: false,
  required: ["status", "service", "timestamp"],
  properties: {
    service: { type: "string" },
    status: { type: "string", enum: ["unavailable"] },
    timestamp: { type: "string", format: "date-time" }
  }
} as const;

export function healthRoutes(
  checkDependencies: () => Promise<void>
): FastifyPluginCallback {
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
      (): HealthResponse => ({
        service: "paktly-api",
        status: "ok" as const,
        timestamp: new Date().toISOString(),
        version: "0.1.0"
      })
    );

    app.get(
      "/ready",
      {
        schema: {
          description: "Dependency readiness check",
          response: {
            200: healthResponseSchema,
            503: unavailableResponseSchema
          },
          tags: ["platform"]
        }
      },
      async (_request, reply): Promise<HealthResponse | undefined> => {
        try {
          await checkDependencies();
        } catch {
          await reply.code(503).send({
            service: "paktly-api",
            status: "unavailable",
            timestamp: new Date().toISOString()
          });
          return;
        }

        return {
          service: "paktly-api",
          status: "ok" as const,
          timestamp: new Date().toISOString(),
          version: "0.1.0"
        };
      }
    );
    done();
  };
}
