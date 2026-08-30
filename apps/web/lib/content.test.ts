import { describe, expect, it } from "vitest";
import { journeySteps, trustPoints } from "./content";

describe("marketing content", () => {
  it("covers the complete first-release journey", () => {
    expect(journeySteps.map((step) => step.label)).toEqual([
      "Plan",
      "Fund",
      "Spend",
      "Settle"
    ]);
  });

  it("states concrete trust signals", () => {
    expect(trustPoints).toHaveLength(4);
  });
});
