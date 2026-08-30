import { describe, expect, it } from "vitest";
import { parseWaitlistRequest } from "./waitlist";

describe("waitlist request", () => {
  it("normalizes a consented email address", () => {
    const result = parseWaitlistRequest({
      company: "",
      email: "  Traveler@Example.COM ",
      marketingConsent: true,
      termsAcknowledged: true
    });
    expect(result.success).toBe(true);
    if (result.success) expect(result.data.email).toBe("traveler@example.com");
  });

  it("rejects missing consent", () => {
    expect(parseWaitlistRequest({ email: "a@example.com", marketingConsent: false, termsAcknowledged: true }).success).toBe(false);
  });

  it("rejects malformed addresses", () => {
    expect(parseWaitlistRequest({ email: "not-an-email", marketingConsent: true, termsAcknowledged: true }).success).toBe(false);
  });
});
