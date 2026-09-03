import { describe, expect, it } from "vitest";
import { issueDraftToken, verifyDraftToken } from "../src/modules/assistant/draft-token.js";
import type { AssistantDraft } from "../src/modules/assistant/openai-provider.js";

const userId = "11111111-1111-4111-8111-111111111111";
const draft: AssistantDraft = {
  intent: "CREATE_PLAN", summary: "Create Lisbon", needsClarification: false, clarification: null,
  planId: null, description: null, amountMinor: null, currency: "USD", payerId: null,
  participantIds: [], participantQueries: [], payerQuery: null, splitMethod: "EQUAL", splitValues: [],
  category: "Other", expenseDate: null, planName: "Lisbon", planDescription: null,
  planStartDate: null, planEndDate: null, inviteIdentifier: null, inviteIdentifiers: []
};

describe("assistant draft tokens", () => {
  it("binds a draft to the user", () => {
    const issued = issueDraftToken(userId, draft, "a-secure-test-secret-that-is-long-enough");
    expect(verifyDraftToken(issued.token, userId, "a-secure-test-secret-that-is-long-enough").draft).toEqual(draft);
    expect(() => verifyDraftToken(issued.token, "22222222-2222-4222-8222-222222222222", "a-secure-test-secret-that-is-long-enough")).toThrow();
  });

  it("rejects tampering", () => {
    const issued = issueDraftToken(userId, draft, "a-secure-test-secret-that-is-long-enough");
    expect(() => verifyDraftToken(`${issued.token}x`, userId, "a-secure-test-secret-that-is-long-enough")).toThrow();
  });
});
