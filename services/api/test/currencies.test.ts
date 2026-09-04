import { describe, expect, it } from "vitest";
import { currencyDisplayName, isSupportedCurrency } from "../src/platform/currencies.js";

describe("currency validation", () => {
  it("accepts real ISO currencies across regions", () => {
    expect(["USD", "EUR", "NGN", "INR", "BRL", "JPY"].every(isSupportedCurrency)).toBe(true);
  });

  it("rejects arbitrary three-letter values", () => {
    expect(isSupportedCurrency("ZZZ")).toBe(false);
  });

  it("provides searchable display names", () => {
    expect(currencyDisplayName("NGN").toLowerCase()).toContain("naira");
  });
});
