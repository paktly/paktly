import { createHash } from "node:crypto";
import { exportPKCS8, generateKeyPair, SignJWT } from "jose";
import { describe, expect, it, vi } from "vitest";
import { revokeAppleForDeletion } from "../src/modules/auth/apple-revocation.js";

describe("Apple deletion revocation", () => {
  async function fixture(subject = "apple-user", nonce = "confirmation-nonce-123456") {
    const signing = await generateKeyPair("ES256", { extractable: true });
    const apple = await generateKeyPair("RS256");
    const configuration = { enabled: true, clientId: "io.paktly.app", teamId: "GC29BX444D", keyId: "TESTKEY123", privateKey: await exportPKCS8(signing.privateKey) };
    const idToken = await new SignJWT({ nonce: createHash("sha256").update(nonce).digest("hex") })
      .setProtectedHeader({ alg: "RS256" }).setIssuer("https://appleid.apple.com")
      .setAudience(configuration.clientId).setSubject(subject).setExpirationTime("5m").sign(apple.privateKey);
    const transport = vi.fn<typeof fetch>()
      .mockResolvedValueOnce(Response.json({ id_token: idToken, refresh_token: "private-refresh-token" }))
      .mockResolvedValueOnce(new Response(null, { status: 200 }));
    const keys = () => Promise.resolve(apple.publicKey);
    return { configuration, transport, keys, proof: { authorizationCode: "one-time-code", nonce: "confirmation-nonce-123456" } };
  }
  it("exchanges a fresh code, verifies identity and revokes the Apple grant", async () => {
    const f = await fixture();
    await revokeAppleForDeletion(f.configuration, "apple-user", f.proof, f.transport, f.keys);
    expect(f.transport).toHaveBeenCalledTimes(2);
    expect(f.transport.mock.calls[1]?.[0]).toBe("https://appleid.apple.com/auth/revoke");
    const body = f.transport.mock.calls[1]?.[1]?.body as URLSearchParams;
    expect(body.get("token_type_hint")).toBe("refresh_token");
    expect(body.get("client_id")).toBe("io.paktly.app");
  });
  it.each([ ["another-user", "confirmation-nonce-123456"], ["apple-user", "wrong-nonce"] ])("rejects mismatched identity or nonce (%s)", async (subject, nonce) => {
    const f = await fixture(subject, nonce);
    await expect(revokeAppleForDeletion(f.configuration, "apple-user", f.proof, f.transport, f.keys)).rejects.toThrow("APPLE_ACCOUNT_MISMATCH");
    expect(f.transport).toHaveBeenCalledTimes(1);
  });
  it("rejects a failed code exchange", async () => {
    const f = await fixture();
    f.transport.mockReset().mockResolvedValue(new Response(null, { status: 503 }));
    await expect(revokeAppleForDeletion(f.configuration, "apple-user", f.proof, f.transport, f.keys)).rejects.toThrow("APPLE_REAUTHENTICATION_FAILED");
  });
  it("does not report success if Apple revocation fails", async () => {
    const f = await fixture();
    const exchange = await f.transport("https://appleid.apple.com/auth/token");
    f.transport.mockReset().mockResolvedValueOnce(exchange).mockResolvedValueOnce(new Response(null, { status: 503 }));
    await expect(revokeAppleForDeletion(f.configuration, "apple-user", f.proof, f.transport, f.keys)).rejects.toThrow("APPLE_REVOCATION_FAILED");
  });
});
