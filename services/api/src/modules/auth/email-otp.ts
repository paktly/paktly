import { createHash, randomInt, randomUUID, timingSafeEqual } from "node:crypto";
import type { Sql } from "postgres";
import type { Environment } from "../../config/environment.js";
import { hashToken } from "./authentication.js";
import type { EmailProvider } from "./email-provider.js";

const OTP_TTL_MINUTES = 10;
const MAX_ATTEMPTS = 5;

function otpHash(challengeId: string, email: string, code: string, secret: string): string {
  return createHash("sha256")
    .update(`${challengeId}\0${email}\0${code}\0${secret}`)
    .digest("hex");
}

export async function requestEmailOtp(
  database: Sql,
  email: string,
  configuration: NonNullable<Environment["emailAuth"]>,
  nodeEnvironment: Environment["nodeEnvironment"],
  emailProvider?: EmailProvider
) {
  if (!configuration.enabled || !configuration.otpSecret) throw new Error("EMAIL_AUTH_DISABLED");
  const normalizedEmail = email.trim().toLowerCase();
  const [recent] = await database`
    SELECT created_at FROM email_otp_challenges
    WHERE email=${normalizedEmail} AND consumed_at IS NULL
    ORDER BY created_at DESC LIMIT 1
  `;
  if (recent && Date.now() - new Date(String(recent.created_at)).getTime() < 60_000) {
    throw new Error("OTP_RATE_LIMITED");
  }
  const challengeId = randomUUID();
  const code = randomInt(0, 1_000_000).toString().padStart(6, "0");
  const expiresAt = new Date(Date.now() + OTP_TTL_MINUTES * 60_000);
  await database.begin(async (tx) => {
    await tx`
      UPDATE email_otp_challenges SET consumed_at=now()
      WHERE email=${normalizedEmail} AND consumed_at IS NULL
    `;
    await tx`
      INSERT INTO email_otp_challenges(id,email,code_hash,expires_at)
      VALUES(${challengeId},${normalizedEmail},${otpHash(challengeId, normalizedEmail, code, configuration.otpSecret!)},${expiresAt})
    `;
  });
  if (nodeEnvironment === "test") {
    return { challengeId, expiresAt: expiresAt.toISOString(), developmentCode: code };
  }
  try {
    if (!emailProvider) throw new Error("Email delivery is not configured.");
    await emailProvider.sendAuthenticationCode({
      recipient: normalizedEmail,
      code,
      expiresInMinutes: OTP_TTL_MINUTES
    });
  } catch (error) {
    await database`
      UPDATE email_otp_challenges SET consumed_at=now()
      WHERE id=${challengeId} AND consumed_at IS NULL
    `;
    throw error;
  }
  return { challengeId, expiresAt: expiresAt.toISOString() };
}

export async function verifyEmailOtp(
  database: Sql,
  input: { challengeId: string; email: string; code: string },
  configuration: NonNullable<Environment["emailAuth"]>
) {
  if (!configuration.enabled || !configuration.otpSecret) throw new Error("EMAIL_AUTH_DISABLED");
  const email = input.email.trim().toLowerCase();
  return database.begin(async (tx) => {
    const [challenge] = await tx`
      SELECT * FROM email_otp_challenges WHERE id=${input.challengeId} FOR UPDATE
    `;
    if (!challenge || challenge.consumed_at || String(challenge.email) !== email) {
      throw new Error("OTP_INVALID");
    }
    if (new Date(String(challenge.expires_at)).getTime() <= Date.now()) {
      await tx`UPDATE email_otp_challenges SET consumed_at=now() WHERE id=${input.challengeId}`;
      throw new Error("OTP_EXPIRED");
    }
    const attempts = Number(challenge.attempts);
    if (attempts >= MAX_ATTEMPTS) throw new Error("OTP_ATTEMPTS_EXCEEDED");
    const expected = Buffer.from(String(challenge.code_hash), "hex");
    const supplied = Buffer.from(otpHash(input.challengeId, email, input.code, configuration.otpSecret!), "hex");
    if (expected.length !== supplied.length || !timingSafeEqual(expected, supplied)) {
      await tx`
        UPDATE email_otp_challenges SET attempts=attempts+1,
          consumed_at=CASE WHEN attempts+1>=${MAX_ATTEMPTS} THEN now() ELSE consumed_at END
        WHERE id=${input.challengeId}
      `;
      throw new Error("OTP_INVALID");
    }
    await tx`UPDATE email_otp_challenges SET consumed_at=now() WHERE id=${input.challengeId}`;

    const [existing] = await tx`
      SELECT u.id,u.email,p.display_name,p.username FROM users u
      JOIN user_profiles p ON p.user_id=u.id WHERE u.email=${email}
    `;
    let user = existing;
    let isNewUser = false;
    if (!user) {
      isNewUser = true;
      [user] = await tx`
        INSERT INTO users(id,email) VALUES(${randomUUID()},${email}) RETURNING id,email
      `;
      if (!user) throw new Error("USER_CREATION_FAILED");
      await tx`
        INSERT INTO user_profiles(user_id,display_name) VALUES(${String(user.id)},'Paktly member')
      `;
      user = { ...user, display_name: "Paktly member", username: null };
    }
    if (!user) throw new Error("USER_SESSION_FAILED");
    const accessToken = randomUUID() + randomUUID();
    const expiresAt = new Date(Date.now() + 30 * 24 * 60 * 60 * 1_000);
    await tx`
      INSERT INTO auth_sessions(id,user_id,token_hash,expires_at)
      VALUES(${randomUUID()},${String(user.id)},${hashToken(accessToken)},${expiresAt})
    `;
    return {
      accessToken,
      expiresAt: expiresAt.toISOString(),
      isNewUser,
      user: {
        id: String(user.id),
        email,
        displayName: String(user.display_name),
        username: user.username == null ? null : String(user.username),
        smartAccount: null
      }
    };
  });
}
