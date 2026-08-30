import cors from "@fastify/cors";
import helmet from "@fastify/helmet";
import sensible from "@fastify/sensible";
import Fastify, { LogController } from "fastify";
import type { Environment } from "./config/environment.js";
import { healthRoutes } from "./modules/health/routes.js";
import { coreRoutes } from "./modules/core/routes.js";
import { expenseRoutes } from "./modules/expenses/routes.js";
import { registerDatabase } from "./platform/database.js";
import { registerErrorHandling } from "./platform/errors.js";
import { loggerOptions } from "./platform/logger.js";

export async function createApp(environment: Environment) {
  const app = Fastify({
    logController: new LogController({
      disableRequestLogging: environment.nodeEnvironment === "test"
    }),
    logger: loggerOptions(environment),
    requestIdHeader: "x-request-id",
    trustProxy: environment.nodeEnvironment === "production"
  });

  await app.register(helmet, {
    contentSecurityPolicy: false
  });
  await app.register(cors, {
    credentials: true,
    origin: environment.corsOrigins
  });
  await app.register(sensible);
  registerDatabase(app, environment.databaseUrl);

  app.addHook("onSend", async (request, reply) => {
    void reply.header("x-request-id", request.id);
  });

  registerErrorHandling(app);

  await app.register(
    async (versionedApi) => {
      await versionedApi.register(healthRoutes(async () => {
        if (environment.nodeEnvironment !== "test") await app.db`SELECT 1`;
      }));
      await versionedApi.register(coreRoutes(environment));
      await versionedApi.register(expenseRoutes);
    },
    { prefix: "/api/v1" }
  );

  return app;
}
