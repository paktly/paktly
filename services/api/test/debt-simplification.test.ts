import { describe, expect, it } from "vitest";
import { simplifyDebts } from "../src/modules/balances/debt-simplification.js";

describe("debt simplification", () => {
  it("produces minimal recommended paths without rewriting history", () => expect(simplifyDebts([
    { userId: "a", netMinor: -2000 }, { userId: "b", netMinor: 0 }, { userId: "c", netMinor: 2000 }
  ])).toEqual([{ fromUserId: "a", toUserId: "c", amountMinor: 2000 }]));
  it("rejects an unbalanced ledger", () => expect(() => simplifyDebts([{ userId: "a", netMinor: 1 }])).toThrow());
});
