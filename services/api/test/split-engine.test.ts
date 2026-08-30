import { describe, expect, it } from "vitest";
import { calculateSplits, convertSplits } from "../src/modules/expenses/split-engine.js";

describe("split engine", () => {
  it("allocates equal splits deterministically", () => expect(calculateSplits(100, { method: "EQUAL", participantIds: ["c", "a", "b"] })).toEqual([
    { userId: "a", amountMinor: 34 }, { userId: "b", amountMinor: 33 }, { userId: "c", amountMinor: 33 }
  ]));
  it("supports exact, percentage and shares", () => {
    expect(calculateSplits(100, { method: "EXACT", shares: [{ userId: "a", value: 70 }, { userId: "b", value: 30 }] })).toHaveLength(2);
    expect(calculateSplits(101, { method: "PERCENTAGE", shares: [{ userId: "a", value: 5000 }, { userId: "b", value: 5000 }] })[0]?.amountMinor).toBe(51);
    expect(calculateSplits(100, { method: "SHARES", shares: [{ userId: "a", value: 2 }, { userId: "b", value: 1 }] })).toEqual([{ userId: "a", amountMinor: 67 }, { userId: "b", amountMinor: 33 }]);
  });
  it("supports itemized allocations and converted totals", () => {
    const split = calculateSplits(150, { method: "ITEMIZED", items: [{ amountMinor: 100, participantIds: ["a", "b"] }, { amountMinor: 50, participantIds: ["b"] }] });
    expect(split).toEqual([{ userId: "a", amountMinor: 50 }, { userId: "b", amountMinor: 100 }]);
    expect(convertSplits(split, 200)).toEqual([{ userId: "a", amountMinor: 67 }, { userId: "b", amountMinor: 133 }]);
  });
  it("rejects invalid definitions", () => {
    expect(() => calculateSplits(100, { method: "EXACT", shares: [{ userId: "a", value: 99 }] })).toThrow();
    expect(() => calculateSplits(100, { method: "PERCENTAGE", shares: [{ userId: "a", value: 9000 }] })).toThrow();
    expect(() => calculateSplits(100, { method: "SHARES", shares: [] })).toThrow();
    expect(() => calculateSplits(100, { method: "ITEMIZED", items: [] })).toThrow();
  });
});
