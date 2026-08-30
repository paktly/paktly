import { randomUUID } from "node:crypto";
import type { FastifyPluginAsync, FastifyInstance } from "fastify";
import { z, type ZodType } from "zod";
import { simplifyDebts } from "../balances/debt-simplification.js";
import { requireAuthentication } from "../auth/authentication.js";
import { calculateSplits, convertSplits, type SplitInput } from "./split-engine.js";

const uuid = z.string().uuid();
const currency = z.string().length(3).transform((value) => value.toUpperCase());
const weighted = z.object({ userId: uuid, value: z.number().int().nonnegative() });
const splitSchema = z.discriminatedUnion("method", [
  z.object({ method: z.literal("EQUAL"), participantIds: z.array(uuid).min(1) }),
  z.object({ method: z.literal("EXACT"), shares: z.array(weighted).min(1) }),
  z.object({ method: z.literal("PERCENTAGE"), shares: z.array(weighted).min(1) }),
  z.object({ method: z.literal("SHARES"), shares: z.array(weighted.extend({ value: z.number().int().positive() })).min(1) }),
  z.object({ method: z.literal("ITEMIZED"), items: z.array(z.object({ amountMinor: z.number().int().positive(), participantIds: z.array(uuid).min(1) })).min(1) })
]);
const expenseFields = z.object({
  description: z.string().trim().min(1).max(200), category: z.string().trim().min(1).max(50),
  amountMinor: z.number().int().positive().max(Number.MAX_SAFE_INTEGER), currency,
  paidBy: uuid, expenseDate: z.string().datetime(), notes: z.string().trim().max(2000).nullable().optional(), split: splitSchema,
  exchangeRate: z.object({ numerator: z.number().int().positive(), denominator: z.number().int().positive(), provider: z.string().trim().min(1).max(80), timestamp: z.string().datetime() }).optional()
});

function parse<T>(schema: ZodType<T>, input: unknown, app: FastifyInstance): T {
  const result = schema.safeParse(input);
  if (!result.success) throw app.httpErrors.badRequest(result.error.issues[0]?.message ?? "Invalid request.");
  return result.data;
}

async function assertMembership(app: FastifyInstance, groupId: string, userId: string): Promise<{ currency: string; memberIds: Set<string> }> {
  const rows = await app.db`SELECT gm.user_id,g.default_currency FROM group_members gm JOIN groups g ON g.id=gm.group_id WHERE gm.group_id=${groupId} AND gm.status='ACTIVE'`;
  const memberIds = new Set(rows.map((row) => String(row.user_id)));
  if (!memberIds.has(userId)) throw app.httpErrors.forbidden("You are not a member of this plan.");
  return { currency: String(rows[0]?.default_currency), memberIds };
}

async function assertExpenseManager(app: FastifyInstance, expenseId: string, userId: string): Promise<void> {
  const [permission] = await app.db`
    SELECT e.created_by,v.paid_by,gm.role FROM expenses e
    JOIN expense_versions v ON v.expense_id=e.id AND v.version=e.current_version
    JOIN group_members gm ON gm.group_id=e.group_id AND gm.user_id=${userId} AND gm.status='ACTIVE'
    WHERE e.id=${expenseId}
  `;
  if (!permission || (String(permission.created_by) !== userId && String(permission.paid_by) !== userId && !["OWNER","ADMIN"].includes(String(permission.role)))) throw app.httpErrors.forbidden("Only the creator, payer, or a plan admin can change this expense.");
}

function participantIds(input: SplitInput): string[] {
  if (input.method === "EQUAL") return input.participantIds;
  if (input.method === "ITEMIZED") return input.items.flatMap((item) => item.participantIds);
  return input.shares.map((share) => share.userId);
}

export const expenseRoutes: FastifyPluginAsync = async (app) => {
  app.addHook("preHandler", requireAuthentication);

  app.post("/groups/:groupId/expenses", async (request, reply) => {
    const { groupId } = parse(z.object({ groupId: uuid }), request.params, app);
    const body = parse(expenseFields.extend({ clientOperationId: uuid }), request.body, app);
    const actor = request.authenticatedUser!;
    const membership = await assertMembership(app, groupId, actor.id);
    const people = new Set([...participantIds(body.split), body.paidBy]);
    if ([...people].some((id) => !membership.memberIds.has(id))) throw app.httpErrors.badRequest("Payer and participants must be active plan members.");
    const existing = await app.db`SELECT id,current_version FROM expenses WHERE group_id=${groupId} AND client_operation_id=${body.clientOperationId}`;
    if (existing[0]) return reply.send({ expense: { id: String(existing[0].id), version: Number(existing[0].current_version), idempotentReplay: true } });
    const expense = await saveExpense(app, { groupId, actorId: actor.id, actorName: actor.displayName, body, groupCurrency: membership.currency, version: 1 });
    return reply.status(201).send({ expense });
  });

  app.patch("/expenses/:expenseId", async (request) => {
    const { expenseId } = parse(z.object({ expenseId: uuid }), request.params, app);
    const body = parse(expenseFields.extend({ expectedVersion: z.number().int().positive() }), request.body, app);
    const actor = request.authenticatedUser!;
    const [current] = await app.db`SELECT group_id,current_version,status FROM expenses WHERE id=${expenseId}`;
    if (!current || current.status !== "ACTIVE") throw app.httpErrors.notFound("Expense not found.");
    if (Number(current.current_version) !== body.expectedVersion) throw app.httpErrors.conflict("This expense changed on another device. Refresh and try again.");
    const groupId = String(current.group_id);
    const membership = await assertMembership(app, groupId, actor.id);
    await assertExpenseManager(app, expenseId, actor.id);
    const people = new Set([...participantIds(body.split), body.paidBy]);
    if ([...people].some((id) => !membership.memberIds.has(id))) throw app.httpErrors.badRequest("Payer and participants must be active plan members.");
    return { expense: await saveExpense(app, { expenseId, groupId, actorId: actor.id, actorName: actor.displayName, body, groupCurrency: membership.currency, version: body.expectedVersion + 1, reverseVersion: body.expectedVersion }) };
  });

  app.delete("/expenses/:expenseId", async (request, reply) => {
    const { expenseId } = parse(z.object({ expenseId: uuid }), request.params, app);
    const actor = request.authenticatedUser!;
    const [expense] = await app.db`SELECT group_id,current_version,status FROM expenses WHERE id=${expenseId}`;
    if (!expense || expense.status === "DELETED") return reply.status(204).send();
    const groupId = String(expense.group_id);
    await assertMembership(app, groupId, actor.id);
    await assertExpenseManager(app, expenseId, actor.id);
    await app.db.begin(async (tx) => {
      const [version] = await tx`SELECT id,description FROM expense_versions WHERE expense_id=${expenseId} AND version=${Number(expense.current_version)}`;
      const [entry] = await tx`SELECT id FROM journal_entries WHERE type='EXPENSE' AND reference_id=${String(version?.id)}`;
      if (entry) {
        const reversalId = randomUUID();
        await tx`INSERT INTO journal_entries(id,group_id,type,reference_id,reversal_of,description,created_by) VALUES(${reversalId},${groupId},'EXPENSE_REVERSAL',${expenseId},${String(entry.id)},${`Deleted ${String(version?.description)}`},${actor.id})`;
        await tx`INSERT INTO journal_lines(id,journal_entry_id,ledger_account_id,debit_minor,credit_minor) SELECT gen_random_uuid(),${reversalId},ledger_account_id,credit_minor,debit_minor FROM journal_lines WHERE journal_entry_id=${String(entry.id)}`;
      }
      await tx`UPDATE expenses SET status='DELETED',updated_at=now() WHERE id=${expenseId}`;
      await tx`INSERT INTO activity_events(id,group_id,actor_user_id,type,entity_type,entity_id,summary) VALUES(${randomUUID()},${groupId},${actor.id},'EXPENSE_DELETED','EXPENSE',${expenseId},${`${actor.displayName} deleted ${String(version?.description)}`})`;
      await tx`INSERT INTO notifications(id,user_id,group_id,type,title,body,entity_type,entity_id) SELECT gen_random_uuid(),user_id,${groupId},'EXPENSE_DELETED','Expense deleted',${`${actor.displayName} deleted ${String(version?.description)}`},'EXPENSE',${expenseId} FROM group_members WHERE group_id=${groupId} AND status='ACTIVE' AND user_id<>${actor.id}`;
    });
    return reply.status(204).send();
  });

  app.get("/groups/:groupId/expenses", async (request) => {
    const { groupId } = parse(z.object({ groupId: uuid }), request.params, app);
    await assertMembership(app, groupId, request.authenticatedUser!.id);
    const expenses = await app.db`
      SELECT e.id,e.current_version,e.created_at,v.description,v.category,v.original_amount_minor,v.original_currency,
        v.converted_amount_minor,v.group_currency,v.paid_by,v.expense_date,v.notes,v.split_method,p.display_name payer_name
      FROM expenses e JOIN expense_versions v ON v.expense_id=e.id AND v.version=e.current_version
      JOIN user_profiles p ON p.user_id=v.paid_by WHERE e.group_id=${groupId} AND e.status='ACTIVE' ORDER BY v.expense_date DESC
    `;
    return { expenses };
  });

  app.get("/expenses/:expenseId", async (request) => {
    const { expenseId } = parse(z.object({ expenseId: uuid }), request.params, app);
    const [expense] = await app.db`SELECT e.group_id,e.id expense_id,e.current_version,v.id version_id,v.* FROM expenses e JOIN expense_versions v ON v.expense_id=e.id AND v.version=e.current_version WHERE e.id=${expenseId} AND e.status='ACTIVE'`;
    if (!expense) throw app.httpErrors.notFound("Expense not found.");
    await assertMembership(app, String(expense.group_id), request.authenticatedUser!.id);
    const splits = await app.db`SELECT s.*,p.display_name FROM expense_splits s JOIN user_profiles p ON p.user_id=s.user_id WHERE s.expense_version_id=${String(expense.version_id)}`;
    return { expense, splits };
  });

  app.get("/groups/:groupId/balances", async (request) => {
    const { groupId } = parse(z.object({ groupId: uuid }), request.params, app);
    const membership = await assertMembership(app, groupId, request.authenticatedUser!.id);
    const rows = await app.db`
      SELECT la.user_id,p.display_name,COALESCE(sum(jl.credit_minor-jl.debit_minor),0)::bigint net_minor
      FROM ledger_accounts la JOIN user_profiles p ON p.user_id=la.user_id LEFT JOIN journal_lines jl ON jl.ledger_account_id=la.id
      WHERE la.group_id=${groupId} GROUP BY la.user_id,p.display_name ORDER BY p.display_name
    `;
    const balances = rows.map((row) => ({ userId: String(row.user_id), displayName: String(row.display_name), netMinor: Number(row.net_minor) }));
    return { currency: membership.currency, balances, suggestedSettlements: simplifyDebts(balances) };
  });

  app.post("/groups/:groupId/settlements", async (request, reply) => {
    const { groupId } = parse(z.object({ groupId: uuid }), request.params, app);
    const body = parse(z.object({ fromUserId: uuid, toUserId: uuid, amountMinor: z.number().int().positive(), method: z.enum(["EXTERNAL", "CASH", "MARKED_PAID"]), note: z.string().max(1000).nullable().optional(), clientOperationId: uuid }), request.body, app);
    const actor = request.authenticatedUser!;
    const membership = await assertMembership(app, groupId, actor.id);
    if (!membership.memberIds.has(body.fromUserId) || !membership.memberIds.has(body.toUserId) || body.fromUserId === body.toUserId) throw app.httpErrors.badRequest("Settlement members are invalid.");
    if (actor.id !== body.fromUserId && actor.id !== body.toUserId) throw app.httpErrors.forbidden("Only a party to the settlement can record it.");
    const [existing] = await app.db`SELECT * FROM settlements WHERE group_id=${groupId} AND client_operation_id=${body.clientOperationId}`;
    if (existing) return { settlement: existing, idempotentReplay: true };
    const settlementId = randomUUID();
    await app.db.begin(async (tx) => {
      await tx`INSERT INTO settlements(id,group_id,from_user_id,to_user_id,amount_minor,currency,method,note,client_operation_id,created_by) VALUES(${settlementId},${groupId},${body.fromUserId},${body.toUserId},${body.amountMinor},${membership.currency},${body.method},${body.note ?? null},${body.clientOperationId},${actor.id})`;
      const accounts = await tx`SELECT id,user_id FROM ledger_accounts WHERE group_id=${groupId} AND user_id IN ${tx([body.fromUserId,body.toUserId])}`;
      const fromAccount = accounts.find((row) => row.user_id === body.fromUserId);
      const toAccount = accounts.find((row) => row.user_id === body.toUserId);
      if (!fromAccount || !toAccount) throw new Error("Ledger accounts are missing.");
      const entryId = randomUUID();
      await tx`INSERT INTO journal_entries(id,group_id,type,reference_id,description,created_by) VALUES(${entryId},${groupId},'SETTLEMENT',${settlementId},'Settlement recorded',${actor.id})`;
      await tx`INSERT INTO journal_lines(id,journal_entry_id,ledger_account_id,debit_minor,credit_minor) VALUES(${randomUUID()},${entryId},${String(toAccount.id)},${body.amountMinor},0),(${randomUUID()},${entryId},${String(fromAccount.id)},0,${body.amountMinor})`;
      await tx`INSERT INTO activity_events(id,group_id,actor_user_id,type,entity_type,entity_id,summary) VALUES(${randomUUID()},${groupId},${actor.id},'SETTLEMENT_RECORDED','SETTLEMENT',${settlementId},${`${actor.displayName} recorded a settlement`})`;
      await tx`INSERT INTO notifications(id,user_id,group_id,type,title,body,entity_type,entity_id) SELECT gen_random_uuid(),user_id,${groupId},'SETTLEMENT_RECORDED','Settlement recorded',${`${actor.displayName} recorded a settlement`},'SETTLEMENT',${settlementId} FROM group_members WHERE group_id=${groupId} AND status='ACTIVE' AND user_id<>${actor.id}`;
    });
    return reply.status(201).send({ settlement: { id: settlementId, ...body, currency: membership.currency } });
  });
  await Promise.resolve();
};

async function saveExpense(app: FastifyInstance, options: { expenseId?: string; groupId: string; actorId: string; actorName: string; groupCurrency: string; version: number; reverseVersion?: number; body: z.infer<typeof expenseFields> & { clientOperationId?: string } }) {
  const { body } = options;
  let numerator = 1;
  let denominator = 1;
  let provider = "SYSTEM";
  let rateTimestamp = new Date().toISOString();
  if (body.currency !== options.groupCurrency) {
    if (!body.exchangeRate) throw app.httpErrors.badRequest("A locked exchange-rate snapshot is required for foreign-currency expenses.");
    ({ numerator, denominator, provider, timestamp: rateTimestamp } = body.exchangeRate);
  }
  const convertedTotal = Math.round((body.amountMinor * numerator) / denominator);
  if (!Number.isSafeInteger(convertedTotal) || convertedTotal <= 0) throw app.httpErrors.badRequest("The converted amount is invalid.");
  let originalSplits;
  try { originalSplits = calculateSplits(body.amountMinor, body.split); } catch (error) { throw app.httpErrors.badRequest(error instanceof Error ? error.message : "Invalid split."); }
  const convertedSplits = convertSplits(originalSplits, convertedTotal);
  const convertedByUser = new Map(convertedSplits.map((share) => [share.userId, share.amountMinor]));
  const expenseId = options.expenseId ?? randomUUID();
  const versionId = randomUUID();
  await app.db.begin(async (tx) => {
    if (options.reverseVersion) {
      const [oldVersion] = await tx`SELECT id FROM expense_versions WHERE expense_id=${expenseId} AND version=${options.reverseVersion}`;
      const [oldEntry] = await tx`SELECT id FROM journal_entries WHERE type='EXPENSE' AND reference_id=${String(oldVersion?.id)}`;
      if (oldEntry) {
        const reversalId = randomUUID();
        await tx`INSERT INTO journal_entries(id,group_id,type,reference_id,reversal_of,description,created_by) VALUES(${reversalId},${options.groupId},'EXPENSE_REVERSAL',${versionId},${String(oldEntry.id)},'Expense edited',${options.actorId})`;
        await tx`INSERT INTO journal_lines(id,journal_entry_id,ledger_account_id,debit_minor,credit_minor) SELECT gen_random_uuid(),${reversalId},ledger_account_id,credit_minor,debit_minor FROM journal_lines WHERE journal_entry_id=${String(oldEntry.id)}`;
      }
      const updated = await tx`UPDATE expenses SET current_version=${options.version},updated_at=now() WHERE id=${expenseId} AND current_version=${options.reverseVersion} RETURNING id`;
      if (!updated[0]) throw app.httpErrors.conflict("This expense changed on another device. Refresh and try again.");
    } else {
      await tx`INSERT INTO expenses(id,group_id,created_by,client_operation_id) VALUES(${expenseId},${options.groupId},${options.actorId},${body.clientOperationId!})`;
    }
    await tx`INSERT INTO expense_versions(id,expense_id,version,description,category,original_amount_minor,original_currency,converted_amount_minor,group_currency,rate_numerator,rate_denominator,rate_provider,rate_timestamp,paid_by,expense_date,notes,split_method,created_by) VALUES(${versionId},${expenseId},${options.version},${body.description},${body.category},${body.amountMinor},${body.currency},${convertedTotal},${options.groupCurrency},${numerator},${denominator},${provider},${rateTimestamp},${body.paidBy},${body.expenseDate},${body.notes ?? null},${body.split.method},${options.actorId})`;
    for (const share of originalSplits) await tx`INSERT INTO expense_splits(expense_version_id,user_id,original_amount_minor,converted_amount_minor) VALUES(${versionId},${share.userId},${share.amountMinor},${convertedByUser.get(share.userId) ?? 0})`;
    const accounts = await tx`SELECT id,user_id FROM ledger_accounts WHERE group_id=${options.groupId}`;
    const accountByUser = new Map(accounts.map((row) => [String(row.user_id), String(row.id)]));
    const entryId = randomUUID();
    await tx`INSERT INTO journal_entries(id,group_id,type,reference_id,description,created_by) VALUES(${entryId},${options.groupId},'EXPENSE',${versionId},${body.description},${options.actorId})`;
    for (const split of convertedSplits) {
      if (split.userId === body.paidBy || split.amountMinor === 0) continue;
      const participantAccount = accountByUser.get(split.userId);
      const payerAccount = accountByUser.get(body.paidBy);
      if (!participantAccount || !payerAccount) throw new Error("Ledger accounts are missing.");
      await tx`INSERT INTO journal_lines(id,journal_entry_id,ledger_account_id,debit_minor,credit_minor) VALUES(${randomUUID()},${entryId},${participantAccount},${split.amountMinor},0),(${randomUUID()},${entryId},${payerAccount},0,${split.amountMinor})`;
    }
    const activityType = options.version === 1 ? "EXPENSE_CREATED" : "EXPENSE_UPDATED";
    await tx`INSERT INTO activity_events(id,group_id,actor_user_id,type,entity_type,entity_id,summary) VALUES(${randomUUID()},${options.groupId},${options.actorId},${activityType},'EXPENSE',${expenseId},${`${options.actorName} ${options.version === 1 ? "added" : "updated"} ${body.description}`})`;
    await tx`INSERT INTO notifications(id,user_id,group_id,type,title,body,entity_type,entity_id) SELECT gen_random_uuid(),user_id,${options.groupId},${activityType},${options.version === 1 ? "Expense added" : "Expense updated"},${`${options.actorName}: ${body.description}`},'EXPENSE',${expenseId} FROM group_members WHERE group_id=${options.groupId} AND status='ACTIVE' AND user_id<>${options.actorId}`;
  });
  return { id: expenseId, version: options.version, description: body.description, amountMinor: body.amountMinor, currency: body.currency, convertedAmountMinor: convertedTotal, groupCurrency: options.groupCurrency, paidBy: body.paidBy, splitMethod: body.split.method, splits: originalSplits.map((share) => ({ ...share, convertedAmountMinor: convertedByUser.get(share.userId) })) };
}
