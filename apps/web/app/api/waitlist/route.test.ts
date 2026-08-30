import { randomUUID } from "node:crypto";
import { describe, expect, it } from "vitest";
import { NextRequest } from "next/server";
import { POST } from "./route";

function request(body: unknown) {
  return new NextRequest("http://localhost:3000/api/waitlist", {
    method: "POST",
    headers: { "content-type": "application/json", "x-forwarded-for": randomUUID() },
    body: JSON.stringify(body)
  });
}

describe("waitlist route", () => {
  it("rejects an invalid email", async () => {
    const response = await POST(request({ email: "bad", marketingConsent: true, termsAcknowledged: true, company: "" }));
    expect(response.status).toBe(400);
  });

  it("requires explicit marketing consent", async () => {
    const response = await POST(request({ email: "a@example.com", marketingConsent: false, termsAcknowledged: true, company: "" }));
    expect(response.status).toBe(400);
  });

  it("silently accepts likely bot submissions without persistence", async () => {
    const response = await POST(request({ email: "bot@example.com", marketingConsent: true, termsAcknowledged: true, company: "Spam Corp" }));
    expect(response.status).toBe(202);
  });
});
