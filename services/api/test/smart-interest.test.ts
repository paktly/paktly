import Fastify from "fastify";
import sensible from "@fastify/sensible";
import { describe, expect, it, vi } from "vitest";
import { smartRoutes } from "../src/modules/smart/routes.js";

describe("Smart interest API", () => {
  it("requires authentication before reading or changing interest", async () => {
    const app = Fastify();
    await app.register(sensible);
    const db = vi.fn();
    app.decorate("db", db as never);
    await app.register(smartRoutes);
    try {
      for (const method of ["GET", "PUT"] as const) {
        const response = await app.inject({ method, url: "/me/smart-interest" });
        expect(response.statusCode).toBe(401);
      }
      expect(db).not.toHaveBeenCalled();
    } finally { await app.close(); }
  });

  it("validates intent and binds writes to the authenticated account", async () => {
    const app = Fastify();
    await app.register(sensible);
    const db = vi.fn().mockResolvedValue([{ id: "signed-in-user", email: "test@example.com", display_name: "Test" }]);
    app.decorate("db", db as never);
    await app.register(smartRoutes);
    const headers = { authorization: "Bearer test-session" };
    try {
      for (const payload of [{ interested: "yes" }, { interested: true, userId: "another-user" }]) {
        const response = await app.inject({ method: "PUT", url: "/me/smart-interest", headers, payload });
        expect(response.statusCode).toBe(400);
      }
      for (const interested of [true, false]) {
        db.mockResolvedValueOnce([{ id: "signed-in-user" }]).mockResolvedValueOnce([{ interested }]);
        const response = await app.inject({ method: "PUT", url: "/me/smart-interest", headers, payload: { interested } });
        expect(response.statusCode).toBe(200);
        expect(response.json()).toEqual({ interested });
        expect(db.mock.lastCall?.slice(1)).toEqual(["signed-in-user", interested]);
      }
    } finally { await app.close(); }
  });
});
