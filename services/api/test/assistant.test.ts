import { describe, expect, it } from "vitest";
import type { AssistantDraft } from "../src/modules/assistant/openai-provider.js";
import { fallbackAssistantDraft, validateAssistantDraft } from "../src/modules/assistant/routes.js";

const planId = "11111111-1111-4111-8111-111111111111";
const actorId = "22222222-2222-4222-8222-222222222222";
const otherId = "33333333-3333-4333-8333-333333333333";
const plans = new Map([[planId, {
  id: planId,
  currency: "USD",
  members: [
    { id: actorId, name: "Alex Morgan", username: "alex", email: "alex@example.com" },
    { id: otherId, name: "Sam Lee", username: "sam", email: "sam@example.com" }
  ]
}]]);

const base: AssistantDraft = {
  intent: "CREATE_EXPENSE", summary: "Add dinner", needsClarification: false,
  clarification: null, planId, description: "Dinner", amountMinor: 4800,
  currency: null, payerId: null, participantIds: [], planName: null,
  participantQueries: [], payerQuery: null, splitMethod: "EQUAL", splitValues: [],
  category: "Other", expenseDate: null, planDescription: null,
  planStartDate: null, planEndDate: null, inviteIdentifier: null, inviteIdentifiers: []
};

describe("Ask Paktly draft validation", () => {
  it("does not turn a savings contribution into an expense when interpretation fails", () => {
    expect(fallbackAssistantDraft("Add $200 I saved to our car plan", null)).toMatchObject({
      intent: "UNSUPPORTED",
      needsClarification: false,
      summary: "Savings contributions by voice are not available yet"
    });
  });

  it("defaults an expense to the actor, plan currency, and all members", () => {
    expect(validateAssistantDraft(base, plans, actorId)).toMatchObject({
      payerId: actorId, participantIds: [actorId, otherId], currency: "USD",
      needsClarification: false
    });
  });

  it("does not allow model-created member identifiers", () => {
    const result = validateAssistantDraft({
      ...base, payerId: "44444444-4444-4444-8444-444444444444"
    }, plans, actorId);
    expect(result.needsClarification).toBe(true);
  });

  it("requires a valid plan before any shared action", () => {
    const result = validateAssistantDraft({ ...base, planId: null }, plans, actorId);
    expect(result).toMatchObject({ needsClarification: true, clarification: "Which plan should I use?" });
  });

  it("resolves spoken names and usernames only within the selected plan", () => {
    const result = validateAssistantDraft({
      ...base, payerQuery: "Alex Morgan", participantQueries: ["@sam", "alex@example.com"]
    }, plans, actorId);
    expect(result).toMatchObject({ payerId: actorId, participantIds: [otherId, actorId], needsClarification: false });
  });

  it("asks for clarification instead of guessing an unknown member", () => {
    const result = validateAssistantDraft({ ...base, participantQueries: ["Jordan"] }, plans, actorId);
    expect(result.needsClarification).toBe(true);
  });

  it("resolves and validates exact split values", () => {
    const result = validateAssistantDraft({
      ...base, splitMethod: "EXACT", participantQueries: ["alex", "sam"],
      splitValues: [
        { participantQuery: "alex", participantId: null, value: 2_400 },
        { participantQuery: "sam", participantId: null, value: 2_400 }
      ]
    }, plans, actorId);
    expect(result.splitValues).toEqual([
      { participantQuery: "alex", participantId: actorId, value: 2_400 },
      { participantQuery: "sam", participantId: otherId, value: 2_400 }
    ]);
  });

  it("rejects percentage splits that do not total 100 percent", () => {
    const result = validateAssistantDraft({
      ...base, splitMethod: "PERCENTAGE",
      splitValues: [{ participantQuery: "alex", participantId: null, value: 9_000 }]
    }, plans, actorId);
    expect(result).toMatchObject({ needsClarification: true, clarification: "The split percentages must add up to 100%." });
  });

  it("does not ask for an existing plan when creating a new one", () => {
    const result = validateAssistantDraft({
      ...base,
      intent: "CREATE_PLAN",
      summary: "Create a New York plan",
      needsClarification: true,
      clarification: "Which existing plan should I use?",
      planId,
      description: null,
      amountMinor: null,
      planName: "New York"
    }, plans, actorId);
    expect(result).toMatchObject({
      intent: "CREATE_PLAN",
      planName: "New York",
      planId: null,
      needsClarification: false,
      clarification: null
    });
  });
});
