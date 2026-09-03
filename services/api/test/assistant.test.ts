import { describe, expect, it } from "vitest";
import type { AssistantDraft } from "../src/modules/assistant/openai-provider.js";
import { validateAssistantDraft } from "../src/modules/assistant/routes.js";

const planId = "11111111-1111-4111-8111-111111111111";
const actorId = "22222222-2222-4222-8222-222222222222";
const otherId = "33333333-3333-4333-8333-333333333333";
const plans = new Map([[planId, {
  id: planId,
  currency: "USD",
  members: [{ id: actorId }, { id: otherId }]
}]]);

const base: AssistantDraft = {
  intent: "CREATE_EXPENSE", summary: "Add dinner", needsClarification: false,
  clarification: null, planId, description: "Dinner", amountMinor: 4800,
  currency: null, payerId: null, participantIds: [], planName: null,
  planDescription: null, inviteIdentifier: null
};

describe("Ask Paktly draft validation", () => {
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
