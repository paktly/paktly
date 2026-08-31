import { createHash, randomUUID, timingSafeEqual } from "node:crypto";
import { createRemoteJWKSet, jwtVerify } from "jose";
import type { Sql } from "postgres";
import type { Environment } from "../../config/environment.js";
import { hashToken } from "./authentication.js";

const appleKeys = createRemoteJWKSet(new URL("https://appleid.apple.com/auth/keys"));
const googleKeys = createRemoteJWKSet(new URL("https://www.googleapis.com/oauth2/v3/certs"));

export type FederatedIdentity = {
  provider: "APPLE" | "GOOGLE";
  subject: string;
  email: string;
  displayName?: string;
  assertionHash: string;
  expiresAt: Date;
};

export async function verifyAppleIdentityToken(
  identityToken: string,
  rawNonce: string,
  configuration: NonNullable<Environment["appleAuth"]>,
  displayName?: string
): Promise<FederatedIdentity> {
  if (!configuration.enabled) throw new Error("APPLE_AUTH_DISABLED");
  const nonce = createHash("sha256").update(rawNonce).digest("hex");
  const { payload } = await jwtVerify(identityToken, appleKeys, {
    issuer: "https://appleid.apple.com",
    audience: configuration.clientId,
    algorithms: ["RS256"]
  });
  const receivedNonce = typeof payload.nonce === "string" ? Buffer.from(payload.nonce) : Buffer.alloc(0);
  const expectedNonce = Buffer.from(nonce);
  if (receivedNonce.length !== expectedNonce.length || !timingSafeEqual(receivedNonce, expectedNonce)) {
    throw new Error("APPLE_NONCE_INVALID");
  }
  const emailVerified = payload.email_verified === true || payload.email_verified === "true";
  if (!payload.sub || typeof payload.email !== "string" || !emailVerified || typeof payload.exp !== "number") {
    throw new Error("APPLE_IDENTITY_INCOMPLETE");
  }
  return {
    provider: "APPLE",
    subject: payload.sub,
    email: payload.email.toLowerCase(),
    ...(displayName?.trim() ? { displayName: displayName.trim() } : {}),
    assertionHash: hashToken(identityToken),
    expiresAt: new Date(Number(payload.exp) * 1_000)
  };
}

export async function verifyGoogleIdentityToken(
  identityToken: string,
  configuration: NonNullable<Environment["googleAuth"]>
): Promise<FederatedIdentity> {
  if (!configuration.enabled) throw new Error("GOOGLE_AUTH_DISABLED");
  const { payload } = await jwtVerify(identityToken, googleKeys, {
    issuer: ["https://accounts.google.com", "accounts.google.com"],
    audience: configuration.serverClientId,
    algorithms: ["RS256"]
  });
  if (!payload.sub || typeof payload.email !== "string" || payload.email_verified !== true || typeof payload.exp !== "number") {
    throw new Error("GOOGLE_IDENTITY_INCOMPLETE");
  }
  return {
    provider: "GOOGLE",
    subject: payload.sub,
    email: payload.email.toLowerCase(),
    ...(typeof payload.name === "string" && payload.name.trim() ? { displayName: payload.name.trim() } : {}),
    assertionHash: hashToken(identityToken),
    expiresAt: new Date(Number(payload.exp) * 1_000)
  };
}

export async function createFederatedSession(database: Sql, identity: FederatedIdentity) {
  return database.begin(async (tx) => {
    try {
      await tx`
        INSERT INTO federated_auth_assertions(id,provider,assertion_hash,expires_at)
        VALUES(${randomUUID()},${identity.provider},${identity.assertionHash},${identity.expiresAt})
      `;
    } catch (error) {
      if ((error as { code?: string }).code === "23505") {
        throw new Error("FEDERATED_ASSERTION_REPLAYED", { cause: error });
      }
      throw error;
    }

    const [knownIdentity] = await tx`
      SELECT user_id FROM auth_identities
      WHERE provider=${identity.provider} AND provider_subject=${identity.subject}
      FOR UPDATE
    `;
    let userId = knownIdentity ? String(knownIdentity.user_id) : undefined;
    let isNewUser = false;

    if (!userId) {
      const [emailUser] = await tx`SELECT id FROM users WHERE email=${identity.email} FOR UPDATE`;
      if (emailUser) {
        userId = String(emailUser.id);
      } else {
        userId = randomUUID();
        isNewUser = true;
        await tx`INSERT INTO users(id,email) VALUES(${userId},${identity.email})`;
        await tx`
          INSERT INTO user_profiles(user_id,display_name)
          VALUES(${userId},${identity.displayName ?? "Paktly member"})
        `;
      }
      await tx`
        INSERT INTO auth_identities(id,user_id,provider,provider_subject)
        VALUES(${randomUUID()},${userId},${identity.provider},${identity.subject})
      `;
    }

    const [profile] = await tx`
      SELECT u.id,u.email,p.display_name,p.username
      FROM users u JOIN user_profiles p ON p.user_id=u.id
      WHERE u.id=${userId} AND u.status='ACTIVE'
    `;
    if (!profile) throw new Error("FEDERATED_PROFILE_MISSING");
    const accessToken = randomUUID() + randomUUID();
    const sessionExpiresAt = new Date(Date.now() + 30 * 24 * 60 * 60 * 1_000);
    await tx`
      INSERT INTO auth_sessions(id,user_id,token_hash,expires_at)
      VALUES(${randomUUID()},${userId},${hashToken(accessToken)},${sessionExpiresAt})
    `;
    return {
      accessToken,
      expiresAt: sessionExpiresAt.toISOString(),
      isNewUser,
      user: {
        id: String(profile.id),
        email: String(profile.email),
        displayName: String(profile.display_name),
        username: profile.username == null ? null : String(profile.username),
        smartAccount: null
      }
    };
  });
}
