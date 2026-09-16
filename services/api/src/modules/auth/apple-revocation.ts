import { createHash } from "node:crypto";
import { createRemoteJWKSet, importPKCS8, jwtVerify, SignJWT } from "jose";
import type { Environment } from "../../config/environment.js";

const appleKeys = createRemoteJWKSet(new URL("https://appleid.apple.com/auth/keys"));
export type AppleDeletionProof = { authorizationCode: string; nonce: string };

export class AppleRevocationError extends Error {
  constructor(readonly stage: "configuration" | "exchange" | "verification" | "revocation",
    readonly reason: string, readonly upstreamStatus?: number) {
    super(`APPLE_${stage.toUpperCase()}_FAILED`);
  }
}

async function responseFailure(response: Response, stage: "exchange" | "revocation") {
  const body = await response.json().catch(() => ({})) as { error?: unknown };
  // Log only known protocol codes, never response bodies or authorization tokens.
  const reason = typeof body.error === "string" &&
    ["invalid_client", "invalid_grant", "invalid_request", "invalid_token", "unauthorized_client", "unsupported_grant_type"].includes(body.error)
    ? body.error : "upstream_error";
  return new AppleRevocationError(stage, reason, response.status);
}

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
  if (!canRevokeApple(configuration)) throw new AppleRevocationError("configuration", "missing_key");
  const key = await importPKCS8(configuration.privateKey!, "ES256").catch(() => {
    throw new AppleRevocationError("configuration", "invalid_key");
  });
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
  if (!exchange.ok) throw await responseFailure(exchange, "exchange");
  const tokens = await exchange.json() as Record<string, unknown>;
  const token = typeof tokens.refresh_token === "string" && tokens.refresh_token.length > 0
    ? { value: tokens.refresh_token, hint: "refresh_token" }
    : typeof tokens.access_token === "string" && tokens.access_token.length > 0
      ? { value: tokens.access_token, hint: "access_token" } : undefined;
  if (typeof tokens.id_token !== "string" || !token) {
    throw new AppleRevocationError("exchange", "incomplete_response");
  }
  const { payload } = await jwtVerify(tokens.id_token, keys, {
    issuer: "https://appleid.apple.com", audience: configuration.clientId, algorithms: ["RS256"]
  }).catch(() => { throw new AppleRevocationError("verification", "invalid_identity_token"); });
  if (payload.sub !== subject || payload.nonce !== createHash("sha256").update(proof.nonce).digest("hex")) {
    throw new AppleRevocationError("verification", "account_mismatch");
  }
  const revoked = await transport("https://appleid.apple.com/auth/revoke", {
    method: "POST", signal: AbortSignal.timeout(15_000),
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({ client_id: configuration.clientId, client_secret: secret,
      token: token.value, token_type_hint: token.hint })
  });
  if (!revoked.ok) throw await responseFailure(revoked, "revocation");
}
