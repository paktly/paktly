import { randomUUID } from "node:crypto";
import type { FastifyPluginAsync } from "fastify";
import { z } from "zod";
import { requireAuthentication } from "../auth/authentication.js";

const uuid = z.string().uuid();
const paramsSchema = z.object({ groupId: uuid });
const contributionSchema = z.object({
  amountMinor: z.number().int().positive().max(Number.MAX_SAFE_INTEGER),
  currency: z.string().trim().length(3).transform((value) => value.toUpperCase()),
  note: z.string().trim().max(500).nullable().optional(),
  clientOperationId: uuid
});

export const savingsRoutes: FastifyPluginAsync = async (app) => {
  app.addHook("preHandler", requireAuthentication);

  app.post("/groups/:groupId/savings-contributions", async (request, reply) => {
    const params = paramsSchema.safeParse(request.params);
    const body = contributionSchema.safeParse(request.body);
    if (!params.success) throw app.httpErrors.badRequest("Invalid plan.");
    if (!body.success) throw app.httpErrors.badRequest(body.error.issues[0]?.message ?? "Invalid savings contribution.");
    const actor = request.authenticatedUser!;
    const [group] = await app.db`
      SELECT g.default_currency FROM groups g
      JOIN group_members gm ON gm.group_id=g.id AND gm.user_id=${actor.id} AND gm.status='ACTIVE'
      WHERE g.id=${params.data.groupId} AND g.status='ACTIVE'
    `;
    if (!group) throw app.httpErrors.forbidden("You are not a member of this plan.");
    if (String(group.default_currency) !== body.data.currency) {
      throw app.httpErrors.badRequest("Tracked savings must use the plan currency.");
    }
    const [existing] = await app.db`
      SELECT * FROM savings_contributions
      WHERE user_id=${actor.id} AND client_operation_id=${body.data.clientOperationId}
    `;
    if (existing) return reply.send({ contribution: existing, idempotentReplay: true });

    const contributionId = randomUUID();
    const summary = `${actor.displayName} tracked ${formatMoney(body.data.amountMinor, body.data.currency)} saved outside Paktly`;
    await app.db.begin(async (tx) => {
      await tx`
        INSERT INTO savings_contributions(id,group_id,user_id,amount_minor,currency,note,client_operation_id)
        VALUES(${contributionId},${params.data.groupId},${actor.id},${body.data.amountMinor},${body.data.currency},${body.data.note ?? null},${body.data.clientOperationId})
      `;
      await tx`
        INSERT INTO activity_events(id,group_id,actor_user_id,type,entity_type,entity_id,summary,metadata)
        VALUES(${randomUUID()},${params.data.groupId},${actor.id},'SAVINGS_TRACKED','SAVINGS_CONTRIBUTION',${contributionId},${summary},${tx.json({ amountMinor: body.data.amountMinor, currency: body.data.currency, source: "TRACKED_EXTERNAL" })})
      `;
      await tx`
        INSERT INTO notifications(id,user_id,group_id,type,title,body,entity_type,entity_id)
        SELECT gen_random_uuid(),user_id,${params.data.groupId},'CONTRIBUTION_TRACKED','Savings updated',${summary},'SAVINGS_CONTRIBUTION',${contributionId}
        FROM group_members WHERE group_id=${params.data.groupId} AND status='ACTIVE' AND user_id<>${actor.id}
      `;
    });
    return reply.status(201).send({
      contribution: { id: contributionId, groupId: params.data.groupId, userId: actor.id, ...body.data, source: "TRACKED_EXTERNAL" }
    });
  });

  app.get("/groups/:groupId/savings-contributions", async (request) => {
    const params = paramsSchema.safeParse(request.params);
    if (!params.success) throw app.httpErrors.badRequest("Invalid plan.");
    const actor = request.authenticatedUser!;
    const [membership] = await app.db`
      SELECT 1 FROM group_members WHERE group_id=${params.data.groupId} AND user_id=${actor.id} AND status='ACTIVE'
    `;
    if (!membership) throw app.httpErrors.forbidden("You are not a member of this plan.");
    const contributions = await app.db`
      SELECT sc.*,p.display_name FROM savings_contributions sc
      JOIN user_profiles p ON p.user_id=sc.user_id
      WHERE sc.group_id=${params.data.groupId} ORDER BY sc.created_at DESC
    `;
    const [total] = await app.db`
      SELECT COALESCE(sum(amount_minor),0)::bigint amount_minor FROM savings_contributions
      WHERE group_id=${params.data.groupId}
    `;
    return { contributions, totalMinor: Number(total?.amount_minor ?? 0) };
  });
  await Promise.resolve();
};

function formatMoney(amountMinor: number, currency: string): string {
  return new Intl.NumberFormat("en", { style: "currency", currency }).format(amountMinor / 100);
}
