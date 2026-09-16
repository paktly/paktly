import type { FastifyPluginAsync } from "fastify";
import { z } from "zod";
import type { Environment } from "../../config/environment.js";
import { requireAuthentication } from "../auth/authentication.js";
import { AppleRevocationError, canRevokeApple, revokeAppleForDeletion } from "../auth/apple-revocation.js";
import { PublicAPIError } from "../../platform/errors.js";
import { eraseAccount } from "./deletion.js";

const input = z.object({
  confirmation: z.literal("DELETE"),
  apple: z.object({ authorizationCode: z.string().min(1).max(4096), nonce: z.string().min(16).max(256) }).strict().optional()
}).strict();

export function accountRoutes(environment: Environment): FastifyPluginAsync {
  return async (app) => {
    await Promise.resolve();
    app.addHook("preHandler", requireAuthentication);
    app.get("/me/account-deletion", async (request, reply) => {
      reply.header("Cache-Control", "no-store");
      const [apple] = await app.db`SELECT id FROM auth_identities WHERE user_id=${request.authenticatedUser!.id} AND provider='APPLE'`;
      return { requiresApple: Boolean(apple), available: !apple || canRevokeApple(environment.appleAuth) };
    });
    app.post("/me/account-deletion", { config: { rateLimit: { max: 5, timeWindow: 60_000 } } }, async (request, reply) => {
      const parsed = input.safeParse(request.body);
      if (!parsed.success) throw app.httpErrors.badRequest("Confirm that you want to delete your account.");
      const userId = request.authenticatedUser!.id;
      await app.db.begin(async (tx) => {
        const [user] = await tx`SELECT id,email,status FROM users WHERE id=${userId} FOR UPDATE`;
        if (!user || user.status !== "ACTIVE") throw app.httpErrors.unauthorized("This account is no longer active.");
        const [apple] = await tx`SELECT provider_subject FROM auth_identities WHERE user_id=${userId} AND provider='APPLE'`;
        if (apple) {
          if (!canRevokeApple(environment.appleAuth)) throw new PublicAPIError(503, "APPLE_DELETION_UNAVAILABLE", "Apple account deletion is temporarily unavailable. Please try again later.");
          if (!parsed.data.apple) throw app.httpErrors.badRequest("Confirm your Apple account to continue.");
        }
        // Exercise all database cleanup before the irreversible external revocation.
        // An Apple failure rolls this transaction back, including the session deletion.
        await eraseAccount(tx, userId, String(user.email));
        if (apple) {
          try {
            await revokeAppleForDeletion(environment.appleAuth!, String(apple.provider_subject), parsed.data.apple!);
          } catch (error) {
            request.log.warn({ event: "apple_deletion_failed",
              stage: error instanceof AppleRevocationError ? error.stage : "transport",
              reason: error instanceof AppleRevocationError ? error.reason : "unavailable",
              upstreamStatus: error instanceof AppleRevocationError ? error.upstreamStatus : undefined
            }, "Apple account deletion failed");
            if (error instanceof AppleRevocationError && error.reason === "account_mismatch") {
              throw new PublicAPIError(403, "APPLE_ACCOUNT_MISMATCH", "Use the same Apple account you used to sign in to Paktly. Your Paktly account has not been deleted.");
            }
            throw new PublicAPIError(502, "APPLE_DELETION_FAILED", "We couldn’t disconnect your Apple account. Please try Apple confirmation again. Your Paktly account has not been deleted.");
          }
        }
      });
      reply.header("Cache-Control", "no-store");
      return { deleted: true };
    });
  };
}
