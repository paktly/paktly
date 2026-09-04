import type { FastifyPluginAsync } from "fastify";
import { z } from "zod";
import type { Environment } from "../../config/environment.js";
import { requireAuthentication } from "../auth/authentication.js";
import { assistantDraftSchema, OpenAIAssistantProvider, type AssistantDraft, type AssistantProvider } from "./openai-provider.js";
import { deterministicIntent, deterministicPlanId } from "./deterministic-resolution.js";
import { issueDraftToken, verifyDraftToken } from "./draft-token.js";

const requestSchema = z.object({
  prompt: z.string().trim().min(3).max(1_000),
  contextPlanId: z.string().uuid().nullable().optional()
});
const confirmationSchema = z.object({
  token: z.string().min(40).max(30_000),
  idempotencyKey: z.string().trim().min(8).max(100)
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
      await consumeUsage(app, actor.id, "interpretations", 100);
      const rows = await app.db`
        SELECT g.id group_id,g.name group_name,g.description,g.default_currency,
          gm.user_id,p.display_name,p.username,u.email
        FROM groups g
        JOIN group_members own ON own.group_id=g.id AND own.user_id=${actor.id} AND own.status='ACTIVE'
        JOIN group_members gm ON gm.group_id=g.id AND gm.status='ACTIVE'
        JOIN user_profiles p ON p.user_id=gm.user_id
        JOIN users u ON u.id=gm.user_id
        WHERE g.status='ACTIVE'
        ORDER BY g.updated_at DESC,gm.joined_at
        LIMIT 500
      `;
      const plansById = new Map<string, { id: string; name: string; description: string | null; currency: string; members: { id: string; name: string; username: string | null; email: string }[] }>();
      for (const row of rows) {
        const id = String(row.group_id);
        const plan = plansById.get(id) ?? { id, name: String(row.group_name), description: row.description ? String(row.description) : null, currency: String(row.default_currency), members: [] };
        plan.members.push({ id: String(row.user_id), name: String(row.display_name), username: row.username ? String(row.username) : null, email: String(row.email) });
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
        const intentHint = deterministicIntent(parsed.data.prompt);
        const resolvedPlanId = intentHint === "CREATE_PLAN" ? undefined : deterministicPlanId(
          parsed.data.prompt,
          plansById.values(),
          parsed.data.contextPlanId ?? undefined
        );
        const startedAt = performance.now();
        const draft = await provider.interpret({
          prompt: parsed.data.prompt,
          today: new Date().toISOString(),
          user: { id: actor.id, name: actor.displayName },
          plans: [...plansById.values()],
          intentHint,
          ...(resolvedPlanId ? { resolvedPlanId } : {}),
          ...(parsed.data.contextPlanId ? { contextPlanId: parsed.data.contextPlanId } : {})
        });
        const validated = validateAssistantDraft(
          intentHint ? { ...draft, intent: intentHint, planId: resolvedPlanId ?? draft.planId } : draft,
          plansById,
          actor.id
        );
        request.log.info({
          event: "assistant_interpretation_completed",
          intent: validated.intent,
          needsClarification: validated.needsClarification,
          latencyMs: Math.round(performance.now() - startedAt)
        }, "Ask Paktly interpretation completed");
        const issued = issueDraftToken(actor.id, validated, environment.assistant!.draftSecret);
        return { draft: validated, confirmationToken: issued.token, expiresAt: new Date(issued.payload.expiresAt * 1_000).toISOString() };
      } catch (error) {
        request.log.error({ err: error }, "Ask Paktly interpretation failed");
        throw app.httpErrors.serviceUnavailable("Ask Paktly couldn’t interpret that request. Please try again.");
      }
    });

    app.post("/assistant/confirm", { config: { rateLimit: { max: 20, timeWindow: 60_000 } } }, async (request) => {
      if (!environment.assistant?.enabled && !injectedProvider) throw app.httpErrors.serviceUnavailable("Ask Paktly is not available right now.");
      const body = confirmationSchema.safeParse(request.body);
      if (!body.success) throw app.httpErrors.badRequest(body.error.issues[0]?.message ?? "Invalid confirmation.");
      const actor = request.authenticatedUser!;
      let payload;
      try { payload = verifyDraftToken(body.data.token, actor.id, environment.assistant!.draftSecret); }
      catch { throw app.httpErrors.gone("This action preview expired. Please ask Paktly again."); }
      const rows = await app.db`
        INSERT INTO assistant_action_confirmations(draft_id,user_id,idempotency_key,draft)
        VALUES(${payload.id},${actor.id},${body.data.idempotencyKey},${app.db.json(payload.draft)})
        ON CONFLICT(user_id,idempotency_key) DO UPDATE SET idempotency_key=EXCLUDED.idempotency_key
        RETURNING draft_id,draft,confirmed_at
      `;
      const record = rows[0]!;
      request.log.info({ event: "assistant_draft_confirmed", draftId: String(record.draft_id), intent: payload.draft.intent }, "Ask Paktly draft confirmed");
      return { confirmationId: String(record.draft_id), draft: assistantDraftSchema.parse(record.draft), confirmedAt: String(record.confirmed_at) };
    });

    app.post("/assistant/realtime-session", { config: { rateLimit: { max: 6, timeWindow: 60_000 } } }, async (request) => {
      if (!environment.assistant?.enabled) throw app.httpErrors.serviceUnavailable("Speak to Paktly is not available right now.");
      await consumeUsage(app, request.authenticatedUser!.id, "transcription_sessions", 30);
      const startedAt = performance.now();
      const response = await fetch("https://api.openai.com/v1/realtime/transcription_sessions", {
        method: "POST",
        headers: { Authorization: `Bearer ${environment.assistant.apiKey}`, "Content-Type": "application/json", "OpenAI-Beta": "realtime=v1" },
        body: JSON.stringify({
          input_audio_format: "pcm16",
          input_audio_transcription: { model: environment.assistant.realtimeTranscriptionModel, prompt: "Paktly shared plans and expenses. Preserve names, emails, amounts, currencies, and plan names." },
          turn_detection: { type: "server_vad", silence_duration_ms: 700 }
        }),
        signal: AbortSignal.timeout(10_000)
      });
      if (!response.ok) {
        request.log.error({ event: "assistant_realtime_session_failed", statusCode: response.status }, "OpenAI Realtime session creation failed");
        throw app.httpErrors.serviceUnavailable("Live transcription is unavailable right now.");
      }
      const session = await response.json() as { client_secret?: { value?: string; expires_at?: number } };
      if (!session.client_secret?.value) throw app.httpErrors.serviceUnavailable("Live transcription is unavailable right now.");
      request.log.info({ event: "assistant_realtime_session_created", latencyMs: Math.round(performance.now() - startedAt) }, "OpenAI Realtime session created");
      return { clientSecret: session.client_secret.value, expiresAt: session.client_secret.expires_at, model: environment.assistant.realtimeTranscriptionModel };
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
      if (audio.length > 12_000_000) throw app.httpErrors.payloadTooLarge("The recording is too long.");
      await consumeAudioUsage(app, request.authenticatedUser!.id, audio.length);
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

async function consumeUsage(app: Parameters<FastifyPluginAsync>[0], userId: string, column: "interpretations" | "transcription_sessions", dailyLimit: number) {
  const incrementInterpretations = column === "interpretations" ? 1 : 0;
  const incrementSessions = column === "transcription_sessions" ? 1 : 0;
  const rows = await app.db`
    INSERT INTO assistant_usage_daily(user_id,interpretations,transcription_sessions)
    VALUES(${userId},${incrementInterpretations},${incrementSessions})
    ON CONFLICT(user_id,usage_date) DO UPDATE SET
      interpretations=assistant_usage_daily.interpretations+${incrementInterpretations},
      transcription_sessions=assistant_usage_daily.transcription_sessions+${incrementSessions}
    RETURNING interpretations,transcription_sessions
  `;
  const count = Number(rows[0]![column]);
  if (count > dailyLimit) throw app.httpErrors.tooManyRequests("You’ve reached today’s Speak to Paktly limit. Try again tomorrow.");
}

async function consumeAudioUsage(app: Parameters<FastifyPluginAsync>[0], userId: string, bytes: number) {
  const rows = await app.db`
    INSERT INTO assistant_usage_daily(user_id,audio_bytes) VALUES(${userId},${bytes})
    ON CONFLICT(user_id,usage_date) DO UPDATE SET audio_bytes=assistant_usage_daily.audio_bytes+${bytes}
    RETURNING audio_bytes
  `;
  if (Number(rows[0]!.audio_bytes) > 120_000_000) throw app.httpErrors.tooManyRequests("You’ve reached today’s voice processing limit. Try again tomorrow.");
}

export function validateAssistantDraft(
  draft: AssistantDraft,
  plans: Map<string, { id: string; currency: string; members: { id: string; name?: string; username?: string | null; email?: string }[] }>,
  actorId: string
): AssistantDraft {
  if (draft.intent === "UNSUPPORTED") return draft;
  if (draft.intent === "CREATE_PLAN") {
    if (!draft.planName) return clarify(draft, "What would you like to call the plan?");
    return {
      ...draft,
      needsClarification: false,
      clarification: null,
      planId: null,
      currency: draft.currency?.toUpperCase() ?? "USD"
    };
  }
  if (draft.needsClarification) return draft;
  const plan = draft.planId ? plans.get(draft.planId) : undefined;
  if (!plan) return clarify(draft, "Which plan should I use?");
  if (draft.intent === "INVITE_PERSON") {
    const inviteIdentifiers = draft.inviteIdentifiers.length ? [...new Set(draft.inviteIdentifiers)] : draft.inviteIdentifier ? [draft.inviteIdentifier] : [];
    if (!inviteIdentifiers.length) return clarify(draft, "Who would you like to invite?");
    return { ...draft, inviteIdentifier: inviteIdentifiers[0]!, inviteIdentifiers };
  }
  const memberIds = new Set(plan.members.map((member) => member.id));
  const payerResolution = draft.payerQuery ? resolveMember(draft.payerQuery, plan.members) : undefined;
  if (draft.payerQuery && !payerResolution) return clarify(draft, `I couldn’t uniquely match “${draft.payerQuery}” to a plan member.`);
  const queriedParticipants = draft.participantQueries.map((query) => resolveMember(query, plan.members));
  if (queriedParticipants.some((id) => !id)) return clarify(draft, "I couldn’t uniquely match everyone in that split.");
  const payerId = payerResolution ?? draft.payerId ?? actorId;
  const participantIds = queriedParticipants.length
    ? [...new Set(queriedParticipants as string[])]
    : draft.participantIds.length ? draft.participantIds : [...memberIds];
  if (!draft.description || !draft.amountMinor) return clarify(draft, "What was the expense and how much did it cost?");
  if (!memberIds.has(payerId) || participantIds.some((id) => !memberIds.has(id))) return clarify(draft, "Who paid, and who should share this expense?");
  const resolvedSplits = draft.splitValues.map((entry) => ({ ...entry, participantId: resolveMember(entry.participantQuery, plan.members) ?? null }));
  if (resolvedSplits.some((entry) => !entry.participantId)) return clarify(draft, "I couldn’t uniquely match everyone in that split.");
  if (draft.splitMethod === "EXACT" && resolvedSplits.reduce((sum, entry) => sum + entry.value, 0) !== draft.amountMinor) return clarify(draft, "The exact split amounts don’t add up to the expense total.");
  if (draft.splitMethod === "PERCENTAGE" && resolvedSplits.reduce((sum, entry) => sum + entry.value, 0) !== 10_000) return clarify(draft, "The split percentages must add up to 100%.");
  if (draft.splitMethod !== "EQUAL" && resolvedSplits.length === 0) return clarify(draft, "How should I divide this expense?");
  return { ...draft, payerId, participantIds, splitValues: resolvedSplits, currency: draft.currency?.toUpperCase() ?? plan.currency };
}

function resolveMember(query: string, members: { id: string; name?: string; username?: string | null; email?: string }[]): string | undefined {
  const target = normalizeIdentity(query);
  const matches = members.filter((member) => [member.name, member.username, member.email]
    .filter((value): value is string => Boolean(value))
    .some((value) => normalizeIdentity(value) === target));
  return matches.length === 1 ? matches[0]!.id : undefined;
}

function normalizeIdentity(value: string): string {
  return value.trim().toLowerCase().replace(/^@/, "").replace(/\s+/g, " ");
}

function clarify(draft: AssistantDraft, question: string): AssistantDraft {
  return { ...draft, needsClarification: true, clarification: question };
}
