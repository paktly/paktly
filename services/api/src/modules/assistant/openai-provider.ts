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
  participantQueries: z.array(z.string().min(1).max(254)).max(100),
  payerQuery: z.string().max(254).nullable(),
  splitMethod: z.enum(["EQUAL", "EXACT", "PERCENTAGE", "SHARES", "ITEMIZED"]),
  splitValues: z.array(z.object({ participantQuery: z.string().min(1).max(254), participantId: z.string().uuid().nullable(), value: z.number().int().nonnegative() })).max(100),
  category: z.enum(["Accommodation", "Flights", "Transportation", "Food", "Drinks", "Activities", "Shopping", "Groceries", "Tickets", "Fuel", "Fees", "Other"]),
  expenseDate: z.string().date().nullable(),
  planName: z.string().max(100).nullable(),
  planDescription: z.string().max(1000).nullable(),
  planStartDate: z.string().date().nullable(),
  planEndDate: z.string().date().nullable(),
  inviteIdentifier: z.string().max(254).nullable(),
  inviteIdentifiers: z.array(z.string().min(1).max(254)).max(20)
});

export type AssistantDraft = z.infer<typeof assistantDraftSchema>;

const outputSchema = {
  type: "object",
  additionalProperties: false,
  required: ["intent", "summary", "needsClarification", "clarification", "planId", "description", "amountMinor", "currency", "payerId", "participantIds", "participantQueries", "payerQuery", "splitMethod", "splitValues", "category", "expenseDate", "planName", "planDescription", "planStartDate", "planEndDate", "inviteIdentifier", "inviteIdentifiers"],
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
    participantQueries: { type: "array", items: { type: "string" } },
    payerQuery: { type: ["string", "null"] },
    splitMethod: { type: "string", enum: ["EQUAL", "EXACT", "PERCENTAGE", "SHARES", "ITEMIZED"] },
    splitValues: { type: "array", items: { type: "object", additionalProperties: false, required: ["participantQuery", "participantId", "value"], properties: { participantQuery: { type: "string" }, participantId: { type: ["string", "null"] }, value: { type: "integer" } } } },
    category: { type: "string", enum: ["Accommodation", "Flights", "Transportation", "Food", "Drinks", "Activities", "Shopping", "Groceries", "Tickets", "Fuel", "Fees", "Other"] },
    expenseDate: { type: ["string", "null"] },
    planName: { type: ["string", "null"] },
    planDescription: { type: ["string", "null"] },
    planStartDate: { type: ["string", "null"] },
    planEndDate: { type: ["string", "null"] },
    inviteIdentifier: { type: ["string", "null"] },
    inviteIdentifiers: { type: "array", items: { type: "string" } }
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
        "Supported intents are creating an expense, creating a plan, or inviting people.",
        "Treat create, start, or make a plan, group, or trip as CREATE_PLAN. This always means a new plan: set planId=null and never ask which existing plan to use.",
        "Treat invite, add, or bring a named person, username, or email into a plan as INVITE_PERSON; resolve the destination only from accessible plans.",
        "Treat a paid cost with an amount, such as dinner, taxi, hotel, or tickets, as CREATE_EXPENSE; resolve the destination only from accessible plans.",
        "The current context plan may resolve an invitation or expense, but must never turn an explicit CREATE_PLAN request into an edit of an existing plan.",
        "Use only IDs supplied in context. Never invent a plan, user, member, amount, or currency.",
        "Amounts are integer minor units. Default expense payer to the current user when the user says they paid.",
        "Put spoken names, usernames, or emails in payerQuery and participantQueries. Use IDs only when supplied verbatim in context; the server resolves human identifiers.",
        "For everyone/equal splits, include every active member ID. For exact amounts use minor units, for percentages use basis points totaling 10000, and for shares use positive integer weights in splitValues.",
        "Always set splitValues participantId to null; the server resolves participantQuery securely.",
        "Infer a category only from the allowed category list. Parse relative dates using today; otherwise expenseDate may be null.",
        "Support multiple invitees in inviteIdentifiers. Put a single invitee in both inviteIdentifier and inviteIdentifiers for compatibility.",
        "Use the plan currency unless another currency is explicit.",
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
