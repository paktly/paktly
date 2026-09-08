import type { FastifyPluginAsync } from "fastify";
import { z } from "zod";
import { requireAuthentication } from "../auth/authentication.js";

const interestInput = z.object({ interested: z.boolean() }).strict();

export const smartRoutes: FastifyPluginAsync = async (app) => {
  await Promise.resolve();
  app.addHook("preHandler", requireAuthentication);
  app.get("/me/smart-interest", async (request, reply) => {
    reply.header("Cache-Control", "no-store");
    const [row] = await app.db`
      SELECT interested FROM smart_interest WHERE user_id=${request.authenticatedUser!.id}
    `;
    return { interested: row?.interested === true };
  });
  app.put("/me/smart-interest", async (request, reply) => {
    const parsed = interestInput.safeParse(request.body);
    if (!parsed.success) throw app.httpErrors.badRequest("Choose whether you are interested in Paktly Smart.");
    reply.header("Cache-Control", "no-store");
    const [row] = await app.db`
      INSERT INTO smart_interest(user_id, interested)
      VALUES(${request.authenticatedUser!.id}, ${parsed.data.interested})
      ON CONFLICT(user_id) DO UPDATE SET interested=EXCLUDED.interested, updated_at=now()
      RETURNING interested
    `;
    return { interested: row?.interested === true };
  });
};
