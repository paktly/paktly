import { describe, expect, it } from "vitest";
import { isValidUsername, normalizeUsername } from "../src/modules/auth/username.js";

describe("Paktly usernames", () => {
  it("normalizes spaces into underscores", () => {
    expect(normalizeUsername("  Alex On Tour  ")).toBe("alex_on_tour");
    expect(normalizeUsername("Alex   Shared Plan")).toBe("alex_shared_plan");
  });

  it("enforces the canonical username format", () => {
    expect(isValidUsername("alex_on_tour")).toBe(true);
    expect(isValidUsername("ab")).toBe(false);
    expect(isValidUsername("_alex")).toBe(false);
    expect(isValidUsername("alex_")).toBe(false);
    expect(isValidUsername("alex-on-tour")).toBe(false);
  });
});
