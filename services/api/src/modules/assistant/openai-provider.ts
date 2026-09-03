import OpenAI, { toFile } from "openai";
import { z } from "zod";

export const assistantDraftSchema = z.object({
  intent: z.enum(["CREATE_EXPENSE", "CREATE_PLAN", "INVITE_PERSON", "UNSUPPORTED"]),
  summary: z.string().min(1).max(300),
  needsClarification: z.boolean(),
  clarification: z.string().max(300).nullable(),
  planId: z.string().uuid().nullable(),
  description: z.string().max(200).nullable(),
  amountMinor: z.number().int().positive().nullable(),
  currency: z.string().length(3).nullable(),
  payerId: z.string().uuid().nullable(),
  participantIds: z.array(z.string().uuid()).max(100),
  planName: z.string().max(100).nullable(),
  planDescription: z.string().max(1000).nullable(),
  inviteIdentifier: z.string().max(254).nullable()
});

export type AssistantDraft = z.infer<typeof assistantDraftSchema>;

const outputSchema = {
  type: "object",
  additionalProperties: false,
  required: ["intent", "summary", "needsClarification", "clarification", "planId", "description", "amountMinor", "currency", "payerId", "participantIds", "planName", "planDescription", "inviteIdentifier"],
  properties: {
    intent: { type: "string", enum: ["CREATE_EXPENSE", "CREATE_PLAN", "INVITE_PERSON", "UNSUPPORTED"] },
    summary: { type: "string" },
    needsClarification: { type: "boolean" },
    clarification: { type: ["string", "null"] },
    planId: { type: ["string", "null"] },
    description: { type: ["string", "null"] },
    amountMinor: { type: ["integer", "null"] },
    currency: { type: ["string", "null"] },
    payerId: { type: ["string", "null"] },
    participantIds: { type: "array", items: { type: "string" } },
    planName: { type: ["string", "null"] },
    planDescription: { type: ["string", "null"] },
    inviteIdentifier: { type: ["string", "null"] }
  }
} as const;

export interface AssistantProvider {
  interpret(input: { prompt: string; today: string; user: unknown; plans: unknown[]; contextPlanId?: string; intentHint?: string | null; resolvedPlanId?: string }): Promise<AssistantDraft>;
}

export class OpenAIAssistantProvider implements AssistantProvider {
  private readonly client: OpenAI;

  constructor(apiKey: string, private readonly model: string, private readonly transcriptionModel = "gpt-4o-transcribe") {
    this.client = new OpenAI({ apiKey });
  }

  async transcribe(audio: Buffer, filename: string, mimeType: string): Promise<string> {
    const file = await toFile(audio, filename, { type: mimeType });
    const result = await this.client.audio.transcriptions.create({
      file,
      model: this.transcriptionModel,
      prompt: "Paktly shared plans and expenses. Preserve names, email addresses, amounts, currencies, and plan names exactly."
    });
    const transcript = result.text.trim();
    if (transcript.length < 2) throw new Error("OPENAI_EMPTY_TRANSCRIPT");
    return transcript;
  }

  async interpret(input: { prompt: string; today: string; user: unknown; plans: unknown[]; contextPlanId?: string; intentHint?: string | null; resolvedPlanId?: string }) {
    const response = await this.client.responses.create({
      model: this.model,
      store: false,
      instructions: [
        "You interpret natural-language requests for Paktly, a shared planning and expense app.",
        "Return a draft only. Never claim an action was executed.",
        "Supported intents are creating an equal-split expense, creating a plan, or inviting one person.",
        "Treat create, start, or make a plan, group, or trip as CREATE_PLAN. This always means a new plan: set planId=null and never ask which existing plan to use.",
        "Treat invite, add, or bring a named person, username, or email into a plan as INVITE_PERSON; resolve the destination only from accessible plans.",
        "Treat a paid cost with an amount, such as dinner, taxi, hotel, or tickets, as CREATE_EXPENSE; resolve the destination only from accessible plans.",
        "The current context plan may resolve an invitation or expense, but must never turn an explicit CREATE_PLAN request into an edit of an existing plan.",
        "Use only IDs supplied in context. Never invent a plan, user, member, amount, or currency.",
        "Amounts are integer minor units. Default expense payer to the current user when the user says they paid.",
        "For everyone/equal splits, include every active member ID. Use the plan currency unless another currency is explicit.",
        "If a required fact is ambiguous or missing, set needsClarification=true and ask one concise question.",
        "CREATE_PLAN needs only a concise planName; put destinations, duration, and other supplied details in planDescription. Dates are optional.",
        "For anything else return UNSUPPORTED."
      ].join(" "),
      input: JSON.stringify(input),
      text: {
        format: {
          type: "json_schema",
          name: "paktly_action_draft",
          strict: true,
          schema: outputSchema
        }
      }
    });
    if (!response.output_text) throw new Error("OPENAI_EMPTY_RESPONSE");
    return assistantDraftSchema.parse(JSON.parse(response.output_text));
  }
}
