import { createHash } from "node:crypto";
import { createRemoteJWKSet, importPKCS8, jwtVerify, SignJWT } from "jose";
import type { Environment } from "../../config/environment.js";

const appleKeys = createRemoteJWKSet(new URL("https://appleid.apple.com/auth/keys"));
export type AppleDeletionProof = { authorizationCode: string; nonce: string };

export function canRevokeApple(configuration: Environment["appleAuth"]): boolean {
  return Boolean(configuration?.teamId && configuration.keyId && configuration.privateKey);
}

export async function revokeAppleForDeletion(
  configuration: NonNullable<Environment["appleAuth"]>,
  subject: string,
  proof: AppleDeletionProof,
  transport: typeof fetch = fetch,
  keys: Parameters<typeof jwtVerify>[1] = appleKeys
): Promise<void> {
  if (!canRevokeApple(configuration)) throw new Error("APPLE_REVOCATION_NOT_CONFIGURED");
  const key = await importPKCS8(configuration.privateKey!, "ES256");
  const secret = await new SignJWT({})
    .setProtectedHeader({ alg: "ES256", kid: configuration.keyId! })
    .setIssuer(configuration.teamId!).setSubject(configuration.clientId)
    .setAudience("https://appleid.apple.com").setIssuedAt().setExpirationTime("5m").sign(key);
  const exchange = await transport("https://appleid.apple.com/auth/token", {
    method: "POST", signal: AbortSignal.timeout(15_000),
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({ client_id: configuration.clientId, client_secret: secret,
      code: proof.authorizationCode, grant_type: "authorization_code" })
  });
  if (!exchange.ok) throw new Error("APPLE_REAUTHENTICATION_FAILED");
  const tokens = await exchange.json() as Record<string, unknown>;
  if (typeof tokens.id_token !== "string" || typeof tokens.refresh_token !== "string") {
    throw new Error("APPLE_REAUTHENTICATION_FAILED");
  }
  const { payload } = await jwtVerify(tokens.id_token, keys, {
    issuer: "https://appleid.apple.com", audience: configuration.clientId, algorithms: ["RS256"]
  });
  if (payload.sub !== subject || payload.nonce !== createHash("sha256").update(proof.nonce).digest("hex")) {
    throw new Error("APPLE_ACCOUNT_MISMATCH");
  }
  const revoked = await transport("https://appleid.apple.com/auth/revoke", {
    method: "POST", signal: AbortSignal.timeout(15_000),
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({ client_id: configuration.clientId, client_secret: secret,
      token: tokens.refresh_token, token_type_hint: "refresh_token" })
  });
  if (!revoked.ok) throw new Error("APPLE_REVOCATION_FAILED");
}
