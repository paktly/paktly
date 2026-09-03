import type { FastifyPluginAsync } from "fastify";
import { z } from "zod";
import type { Environment } from "../../config/environment.js";
import { requireAuthentication } from "../auth/authentication.js";
import { OpenAIAssistantProvider, type AssistantDraft, type AssistantProvider } from "./openai-provider.js";

const requestSchema = z.object({
  prompt: z.string().trim().min(3).max(1_000),
  contextPlanId: z.string().uuid().nullable().optional()
});

export function assistantRoutes(environment: Environment, injectedProvider?: AssistantProvider): FastifyPluginAsync {
  return async (app) => {
    app.addHook("preHandler", requireAuthentication);

    app.post("/assistant/interpret", { config: { rateLimit: { max: 20, timeWindow: 60_000 } } }, async (request) => {
      if (!environment.assistant?.enabled && !injectedProvider) {
        throw app.httpErrors.serviceUnavailable("Ask Paktly is not available right now.");
      }
      const parsed = requestSchema.safeParse(request.body);
      if (!parsed.success) throw app.httpErrors.badRequest(parsed.error.issues[0]?.message ?? "Invalid request.");
      const actor = request.authenticatedUser!;
      const rows = await app.db`
        SELECT g.id group_id,g.name group_name,g.description,g.default_currency,
          gm.user_id,p.display_name,p.username
        FROM groups g
        JOIN group_members own ON own.group_id=g.id AND own.user_id=${actor.id} AND own.status='ACTIVE'
        JOIN group_members gm ON gm.group_id=g.id AND gm.status='ACTIVE'
        JOIN user_profiles p ON p.user_id=gm.user_id
        WHERE g.status='ACTIVE'
        ORDER BY g.updated_at DESC,gm.joined_at
        LIMIT 500
      `;
      const plansById = new Map<string, { id: string; name: string; description: string | null; currency: string; members: { id: string; name: string; username: string | null }[] }>();
      for (const row of rows) {
        const id = String(row.group_id);
        const plan = plansById.get(id) ?? { id, name: String(row.group_name), description: row.description ? String(row.description) : null, currency: String(row.default_currency), members: [] };
        plan.members.push({ id: String(row.user_id), name: String(row.display_name), username: row.username ? String(row.username) : null });
        plansById.set(id, plan);
      }
      if (parsed.data.contextPlanId && !plansById.has(parsed.data.contextPlanId)) {
        throw app.httpErrors.forbidden("The selected plan is unavailable.");
      }
      const provider = injectedProvider ?? new OpenAIAssistantProvider(
        environment.assistant!.apiKey,
        environment.assistant!.model,
        environment.assistant!.transcriptionModel
      );
      try {
        const draft = await provider.interpret({
          prompt: parsed.data.prompt,
          today: new Date().toISOString(),
          user: { id: actor.id, name: actor.displayName },
          plans: [...plansById.values()],
          ...(parsed.data.contextPlanId ? { contextPlanId: parsed.data.contextPlanId } : {})
        });
        return { draft: validateAssistantDraft(draft, plansById, actor.id) };
      } catch (error) {
        request.log.error({ err: error }, "Ask Paktly interpretation failed");
        throw app.httpErrors.serviceUnavailable("Ask Paktly couldn’t interpret that request. Please try again.");
      }
    });

    app.post("/assistant/transcribe", { config: { rateLimit: { max: 10, timeWindow: 60_000 } } }, async (request) => {
      if (!environment.assistant?.enabled) {
        throw app.httpErrors.serviceUnavailable("Speak to Paktly is not available right now.");
      }
      const part = await request.file();
      if (!part) throw app.httpErrors.badRequest("An audio recording is required.");
      const allowedTypes = new Set(["audio/mp4", "audio/m4a", "audio/x-m4a", "audio/mpeg", "audio/wav"]);
      if (!allowedTypes.has(part.mimetype)) throw app.httpErrors.unsupportedMediaType("This audio format is not supported.");
      const audio = await part.toBuffer();
      if (audio.length === 0) throw app.httpErrors.badRequest("The audio recording is empty.");
      try {
        const provider = new OpenAIAssistantProvider(
          environment.assistant.apiKey,
          environment.assistant.model,
          environment.assistant.transcriptionModel
        );
        const extension = part.mimetype === "audio/wav" ? "wav" : part.mimetype === "audio/mpeg" ? "mp3" : "m4a";
        return { transcript: await provider.transcribe(audio, `paktly-command.${extension}`, part.mimetype) };
      } catch (error) {
        request.log.error({ err: error }, "Speak to Paktly transcription failed");
        throw app.httpErrors.serviceUnavailable("Paktly couldn’t hear that clearly. Please try again.");
      }
    });
    await app.after();
  };
}

export function validateAssistantDraft(
  draft: AssistantDraft,
  plans: Map<string, { id: string; currency: string; members: { id: string }[] }>,
  actorId: string
): AssistantDraft {
  if (draft.needsClarification || draft.intent === "UNSUPPORTED") return draft;
  if (draft.intent === "CREATE_PLAN") {
    if (!draft.planName) return clarify(draft, "What would you like to call the plan?");
    return { ...draft, currency: draft.currency?.toUpperCase() ?? "USD" };
  }
  const plan = draft.planId ? plans.get(draft.planId) : undefined;
  if (!plan) return clarify(draft, "Which plan should I use?");
  if (draft.intent === "INVITE_PERSON") {
    if (!draft.inviteIdentifier) return clarify(draft, "Who would you like to invite?");
    return draft;
  }
  const memberIds = new Set(plan.members.map((member) => member.id));
  const payerId = draft.payerId ?? actorId;
  const participantIds = draft.participantIds.length ? draft.participantIds : [...memberIds];
  if (!draft.description || !draft.amountMinor) return clarify(draft, "What was the expense and how much did it cost?");
  if (!memberIds.has(payerId) || participantIds.some((id) => !memberIds.has(id))) return clarify(draft, "Who paid, and who should share this expense?");
  return { ...draft, payerId, participantIds, currency: draft.currency?.toUpperCase() ?? plan.currency };
}

function clarify(draft: AssistantDraft, question: string): AssistantDraft {
  return { ...draft, needsClarification: true, clarification: question };
}
