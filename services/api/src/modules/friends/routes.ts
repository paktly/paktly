import { randomUUID } from "node:crypto";
import type { FastifyPluginAsync } from "fastify";
import { z } from "zod";
import { requireAuthentication } from "../auth/authentication.js";

const friendInput = z.object({
  name: z.string().trim().min(1).max(120),
  email: z.string().trim().email().transform((value) => value.toLowerCase())
});

function nullableString(value: unknown): string | null {
  return typeof value === "string" ? value : value == null ? null : JSON.stringify(value);
}

export const friendRoutes: FastifyPluginAsync = async (app) => {
  await Promise.resolve();
  app.addHook("preHandler", requireAuthentication);

  app.get("/friends", async (request) => {
    const rows = (await app.db`
      SELECT f.id, f.name, f.email, f.linked_user_id, f.created_at
      FROM friends f
      WHERE f.user_id=${request.authenticatedUser!.id}
      ORDER BY lower(f.name), f.created_at DESC
    `) as Array<Record<string, unknown>>;
    return {
      friends: rows.map((row) => ({
        id: String(row.id),
        name: String(row.name),
        email: String(row.email),
        linkedUserId: nullableString(row.linked_user_id),
        createdAt: row.created_at
      }))
    };
  });

  app.post("/friends", async (request, reply) => {
    const parsed = friendInput.safeParse(request.body);
    if (!parsed.success) throw app.httpErrors.badRequest(parsed.error.issues[0]?.message ?? "Enter a valid name and email.");
    const { name, email } = parsed.data;
    const userId = request.authenticatedUser!.id;
    const [linked] = (await app.db`SELECT id FROM users WHERE email=${email} AND status='ACTIVE'`) as Array<Record<string, unknown>>;
    const linkedUserId = nullableString(linked?.id);
    const [friend] = (await app.db`
      INSERT INTO friends(id,user_id,name,email,linked_user_id)
      VALUES(${randomUUID()},${userId},${name},${email},${linkedUserId})
      ON CONFLICT(user_id,email) DO UPDATE SET name=EXCLUDED.name, linked_user_id=EXCLUDED.linked_user_id, updated_at=now()
      RETURNING id,name,email,linked_user_id,created_at
    `) as Array<Record<string, unknown>>;
    if (!friend) throw app.httpErrors.internalServerError("Friend could not be saved.");
    return reply.status(201).send({
      friend: {
        id: String(friend.id), name: String(friend.name), email: String(friend.email),
        linkedUserId: nullableString(friend.linked_user_id),
        createdAt: friend.created_at
      }
    });
  });

  app.delete("/friends/:friendId", async (request, reply) => {
    const params = z.object({ friendId: z.string().uuid() }).safeParse(request.params);
    if (!params.success) throw app.httpErrors.badRequest("Invalid friend.");
    await app.db`DELETE FROM friends WHERE id=${params.data.friendId} AND user_id=${request.authenticatedUser!.id}`;
    return reply.status(204).send();
  });
};
