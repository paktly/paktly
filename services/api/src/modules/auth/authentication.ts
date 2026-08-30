import { createHash, randomBytes, randomUUID } from "node:crypto";
import type { FastifyReply, FastifyRequest } from "fastify";
import type { Sql } from "postgres";

export function hashToken(token: string): string { return createHash("sha256").update(token).digest("hex"); }

export async function requireAuthentication(request: FastifyRequest, reply: FastifyReply): Promise<void> {
  const authorization = request.headers.authorization;
  if (!authorization?.startsWith("Bearer ")) return reply.unauthorized("Authentication is required.");
  const token = authorization.slice(7);
  const [row] = await request.server.db`
    SELECT u.id, u.email, p.display_name
    FROM auth_sessions s JOIN users u ON u.id=s.user_id JOIN user_profiles p ON p.user_id=u.id
    WHERE s.token_hash=${hashToken(token)} AND s.revoked_at IS NULL AND s.expires_at>now() AND u.status='ACTIVE'
  `;
  if (!row) return reply.unauthorized("Your session is invalid or expired.");
  request.authenticatedUser = { id: String(row.id), email: String(row.email), displayName: String(row.display_name) };
}

export async function createDevelopmentSession(database: Sql, input: { email: string; displayName: string }) {
  const email = input.email.trim().toLowerCase();
  const token = randomBytes(32).toString("base64url");
  return database.begin(async (tx) => {
    const [user] = await tx`
      INSERT INTO users(id,email) VALUES(${randomUUID()},${email})
      ON CONFLICT(email) DO UPDATE SET updated_at=now() RETURNING id,email
    `;
    if (!user) throw new Error("Unable to create user.");
    await tx`
      INSERT INTO user_profiles(user_id,display_name) VALUES(${String(user.id)},${input.displayName.trim()})
      ON CONFLICT(user_id) DO UPDATE SET display_name=excluded.display_name,updated_at=now()
    `;
    const expiresAt = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000);
    await tx`INSERT INTO auth_sessions(id,user_id,token_hash,expires_at) VALUES(${randomUUID()},${String(user.id)},${hashToken(token)},${expiresAt})`;
    return { accessToken: token, expiresAt: expiresAt.toISOString(), user: { id: String(user.id), email, displayName: input.displayName.trim() } };
  });
}
