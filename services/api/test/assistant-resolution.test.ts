import { describe, expect, it } from "vitest";
import { deterministicIntent, deterministicPlanId } from "../src/modules/assistant/deterministic-resolution.js";

describe("deterministic assistant resolution", () => {
  it.each([
    ["Create a trip to New York for one month", "CREATE_PLAN"],
    ["Start a group for our house renovation", "CREATE_PLAN"],
    ["Add the $48 dinner I paid for everyone in Lisbon", "CREATE_EXPENSE"],
    ["I spent 35 USD on a taxi", "CREATE_EXPENSE"],
    ["Invite alex@example.com to Bali", "INVITE_PERSON"],
    ["Bring @sam to the Lisbon trip", "INVITE_PERSON"]
  ])("resolves %s", (prompt, expected) => expect(deterministicIntent(prompt)).toBe(expected));

  it("matches one accessible plan by normalized name", () => {
    expect(deterministicPlanId("Add dinner to Lisbon Trip", [
      { id: "lisbon", name: "Lisbon Trip" }, { id: "bali", name: "Bali" }
    ])).toBe("lisbon");
  });

  it("does not guess between duplicate plan names", () => {
    expect(deterministicPlanId("Add dinner to Lisbon", [
      { id: "one", name: "Lisbon" }, { id: "two", name: "Lisbon" }
    ])).toBeUndefined();
  });
});
