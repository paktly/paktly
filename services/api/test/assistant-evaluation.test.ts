import { describe, expect, it } from "vitest";
import { deterministicIntent } from "../src/modules/assistant/deterministic-resolution.js";

const commands = [
  ["Create a plan called New York summer for June 3 through June 20", "CREATE_PLAN"],
  ["Make a house renovation plan with a twenty thousand dollar goal", "CREATE_PLAN"],
  ["Start a birthday dinner group for next Friday", "CREATE_PLAN"],
  ["I paid 87 dollars 50 for dinner in Lisbon, split it equally", "CREATE_EXPENSE"],
  ["Add yesterday's €42 taxi to Paris", "CREATE_EXPENSE"],
  ["Put the 120 dollar hotel in Bali, sixty percent me and forty percent Sam", "CREATE_EXPENSE"],
  ["I paid 35 pounds for groceries, two shares for me and one for Alex", "CREATE_EXPENSE"],
  ["Add the 18 dollar drinks from Tuesday", "CREATE_EXPENSE"],
  ["Invite alex@example.com to Lisbon", "INVITE_PERSON"],
  ["Bring @maria into the Bali plan", "INVITE_PERSON"],
  ["Add Sam to our New York trip", "INVITE_PERSON"],
  ["Add $200 I saved to our car plan", null],
  ["Record my 50 dollar contribution to the holiday fund", null],
  ["I deposited 100 dollars into our savings", null],
  ["What is the weather tomorrow?", null]
] as const;

describe("Speak to Paktly intent regression corpus", () => {
  it.each(commands)("classifies %s", (utterance, expected) => {
    expect(deterministicIntent(utterance)).toBe(expected);
  });
});
