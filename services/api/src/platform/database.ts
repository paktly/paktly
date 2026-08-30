import postgres, { type Sql } from "postgres";
import type { FastifyInstance } from "fastify";

declare module "fastify" {
  interface FastifyInstance { db: Sql; }
  interface FastifyRequest { authenticatedUser?: { id: string; email: string; displayName: string }; }
}

export function registerDatabase(app: FastifyInstance, databaseUrl: string): void {
  const database = postgres(databaseUrl, { max: 10, idle_timeout: 20, connect_timeout: 10 });
  app.decorate("db", database);
  app.addHook("onClose", async () => database.end());
}
