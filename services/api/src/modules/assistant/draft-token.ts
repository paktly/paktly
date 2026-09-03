import { createHmac, randomUUID, timingSafeEqual } from "node:crypto";
import { z } from "zod";
import { assistantDraftSchema, type AssistantDraft } from "./openai-provider.js";

const payloadSchema = z.object({
  id: z.string().uuid(),
  userId: z.string().uuid(),
  expiresAt: z.number().int().positive(),
  draft: assistantDraftSchema
});

export type AssistantDraftTokenPayload = z.infer<typeof payloadSchema>;

export function issueDraftToken(userId: string, draft: AssistantDraft, secret: string, lifetimeSeconds = 300) {
  const payload: AssistantDraftTokenPayload = {
    id: randomUUID(), userId, draft, expiresAt: Math.floor(Date.now() / 1_000) + lifetimeSeconds
  };
  const encoded = Buffer.from(JSON.stringify(payload)).toString("base64url");
  const signature = sign(encoded, secret);
  return { token: `${encoded}.${signature}`, payload };
}

export function verifyDraftToken(token: string, expectedUserId: string, secret: string): AssistantDraftTokenPayload {
  const [encoded, supplied] = token.split(".");
  if (!encoded || !supplied) throw new Error("INVALID_DRAFT_TOKEN");
  const expected = sign(encoded, secret);
  const left = Buffer.from(supplied);
  const right = Buffer.from(expected);
  if (left.length !== right.length || !timingSafeEqual(left, right)) throw new Error("INVALID_DRAFT_TOKEN");
  const payload = payloadSchema.parse(JSON.parse(Buffer.from(encoded, "base64url").toString("utf8")));
  if (payload.userId !== expectedUserId) throw new Error("DRAFT_ACTOR_MISMATCH");
  if (payload.expiresAt <= Math.floor(Date.now() / 1_000)) throw new Error("DRAFT_EXPIRED");
  return payload;
}

function sign(value: string, secret: string): string {
  return createHmac("sha256", secret).update(value).digest("base64url");
}
