import { randomBytes, randomUUID } from "node:crypto";
import type { FastifyInstance, FastifyPluginAsync } from "fastify";
import { z, type ZodType } from "zod";
import type { Environment } from "../../config/environment.js";
import { createDevelopmentSession, createSocketFiSession, hashToken, linkSocketFiIdentity, requireAuthentication } from "../auth/authentication.js";
import { requestEmailOtp, verifyEmailOtp } from "../auth/email-otp.js";
import { SmtpEmailProvider } from "../auth/email-provider.js";
import { verifySocketFiToken } from "../auth/socketfi.js";
import { isValidUsername, normalizeUsername } from "../auth/username.js";
import { createFederatedSession, verifyAppleIdentityToken, verifyGoogleIdentityToken } from "../auth/federated.js";

const currency = z.string().trim().length(3).transform((value) => value.toUpperCase());
const uuid = z.string().uuid();

function parse<T>(schema: ZodType<T>, input: unknown, badRequest: (message: string) => Error): T {
  const result = schema.safeParse(input);
  if (!result.success) throw badRequest(result.error.issues[0]?.message ?? "Invalid request.");
  return result.data;
}

async function requireMember(app: FastifyInstance, groupId: string, userId: string, admin = false) {
  const [membership] = await app.db`SELECT role FROM group_members WHERE group_id=${groupId} AND user_id=${userId} AND status='ACTIVE'`;
  if (!membership) throw app.httpErrors.forbidden("You are not a member of this plan.");
  if (admin && !["OWNER", "ADMIN"].includes(String(membership.role))) throw app.httpErrors.forbidden("An owner or admin is required.");
  return membership;
}

async function invitationForRecipient(app: FastifyInstance, invitationId: string, email: string) {
  const [invitation] = await app.db`
    SELECT i.id,i.group_id,i.email,i.status,i.expires_at,i.created_at,
      g.name group_name,p.display_name inviter_name
    FROM invitations i
    JOIN groups g ON g.id=i.group_id
    JOIN user_profiles p ON p.user_id=i.invited_by
    WHERE i.id=${invitationId} AND i.email=${email}
  `;
  return invitation;
}

export function coreRoutes(environment: Environment): FastifyPluginAsync {
  return async (app) => {
    const emailProvider = environment.emailAuth?.smtp
      ? new SmtpEmailProvider({ ...environment.emailAuth.smtp, from: environment.emailAuth.from })
      : undefined;
    app.post("/auth/dev-session", { config: { rateLimit: { max: 10, timeWindow: 60_000 } } }, async (request) => {
      if (environment.nodeEnvironment === "production") throw app.httpErrors.notFound();
      const body = parse(z.object({ email: z.string().email(), displayName: z.string().trim().min(1).max(80) }), request.body, app.httpErrors.badRequest);
      return createDevelopmentSession(app.db, body);
    });

    app.post("/auth/email/request", { config: { rateLimit: { max: 5, timeWindow: 60_000 } } }, async (request, reply) => {
      const { email } = parse(
        z.object({ email: z.string().trim().email().transform((value) => value.toLowerCase()) }),
        request.body,
        app.httpErrors.badRequest
      );
      try {
        const result = await requestEmailOtp(
          app.db,
          email,
          environment.emailAuth ?? { enabled: false, from: "" },
          environment.nodeEnvironment,
          emailProvider
        );
        return reply.status(201).send({ delivery: "email", ...result });
      } catch (error) {
        if ((error as Error).message === "EMAIL_AUTH_DISABLED") throw app.httpErrors.serviceUnavailable("Email sign-in is not available.");
        if ((error as Error).message === "OTP_RATE_LIMITED") throw app.httpErrors.tooManyRequests("Please wait before requesting another code.");
        request.log.error({ err: error }, "email OTP delivery failed");
        throw app.httpErrors.serviceUnavailable("We couldn’t send a code. Please try again.");
      }
    });

    app.post("/auth/email/verify", { config: { rateLimit: { max: 10, timeWindow: 60_000 } } }, async (request) => {
      const body = parse(
        z.object({
          challengeId: z.string().uuid(),
          email: z.string().trim().email().transform((value) => value.toLowerCase()),
          code: z.string().regex(/^\d{6}$/)
        }),
        request.body,
        app.httpErrors.badRequest
      );
      try {
        return await verifyEmailOtp(app.db, body, environment.emailAuth ?? { enabled: false, from: "" });
      } catch (error) {
        const message = (error as Error).message;
        if (message === "EMAIL_AUTH_DISABLED") throw app.httpErrors.serviceUnavailable("Email sign-in is not available.");
        if (message === "OTP_EXPIRED") throw app.httpErrors.gone("This code has expired. Request a new one.");
        if (message === "OTP_ATTEMPTS_EXCEEDED") throw app.httpErrors.tooManyRequests("Too many attempts. Request a new code.");
        throw app.httpErrors.unauthorized("That verification code is incorrect.");
      }
    });

    app.post("/auth/apple", { config: { rateLimit: { max: 10, timeWindow: 60_000 } } }, async (request) => {
      const body = parse(
        z.object({
          identityToken: z.string().min(100).max(16_384),
          nonce: z.string().min(32).max(256),
          displayName: z.string().trim().min(1).max(80).optional()
        }),
        request.body,
        app.httpErrors.badRequest
      );
      try {
        const identity = await verifyAppleIdentityToken(
          body.identityToken,
          body.nonce,
          environment.appleAuth ?? { enabled: false, clientId: "io.paktly.app" },
          body.displayName
        );
        return await createFederatedSession(app.db, identity);
      } catch (error) {
        if ((error as Error).message === "APPLE_AUTH_DISABLED") {
          throw app.httpErrors.serviceUnavailable("Apple sign-in is not available.");
        }
        if ((error as Error).message === "FEDERATED_ASSERTION_REPLAYED") {
          throw app.httpErrors.conflict("This Apple authorization was already used. Please try again.");
        }
        request.log.warn({ err: error }, "Apple identity verification failed");
        throw app.httpErrors.unauthorized("Apple authentication is invalid or expired.");
      }
    });

    app.post("/auth/google", { config: { rateLimit: { max: 10, timeWindow: 60_000 } } }, async (request) => {
      const { identityToken } = parse(
        z.object({ identityToken: z.string().min(100).max(16_384) }),
        request.body,
        app.httpErrors.badRequest
      );
      try {
        const identity = await verifyGoogleIdentityToken(
          identityToken,
          environment.googleAuth ?? { enabled: false, serverClientId: "not-configured" }
        );
        return await createFederatedSession(app.db, identity);
      } catch (error) {
        if ((error as Error).message === "GOOGLE_AUTH_DISABLED") {
          throw app.httpErrors.serviceUnavailable("Google sign-in is not available.");
        }
        if ((error as Error).message === "FEDERATED_ASSERTION_REPLAYED") {
          throw app.httpErrors.conflict("This Google authorization was already used. Please try again.");
        }
        request.log.warn({ err: error }, "Google identity verification failed");
        throw app.httpErrors.unauthorized("Google authentication is invalid or expired.");
      }
    });

    app.post("/auth/socketfi", { config: { rateLimit: { max: 10, timeWindow: 60_000 } } }, async (request) => {
      const body = parse(
        z.object({
          accessToken: z.string().min(100).max(16_384),
          displayName: z.string().trim().min(1).max(80).optional()
        }),
        request.body,
        app.httpErrors.badRequest
      );
      let identity;
      try {
        identity = await verifySocketFiToken(body.accessToken, environment.socketFi);
      } catch {
        throw app.httpErrors.unauthorized("SocketFi authentication is invalid or expired.");
      }
      return createSocketFiSession(app.db, identity, body.displayName);
    });

    app.register(async (authenticated) => {
      authenticated.addHook("preHandler", requireAuthentication);

      authenticated.get("/me", async (request) => {
        const userId = request.authenticatedUser!.id;
        const [profile] = await app.db`SELECT u.id,u.email,p.display_name,p.username,p.avatar_url,p.default_currency,p.locale,p.timezone FROM users u JOIN user_profiles p ON p.user_id=u.id WHERE u.id=${userId}`;
        const [smartAccount] = await app.db`
          SELECT provider,network,address FROM wallet_addresses
          WHERE user_id=${userId} AND provider='SOCKETFI' AND network=${environment.socketFi.network}
        `;
        return { profile: { ...profile, smartAccount: smartAccount ?? null } };
      });

      authenticated.post("/me/username-availability", { config: { rateLimit: { max: 30, timeWindow: 60_000 } } }, async (request) => {
        const { username: rawUsername } = parse(
          z.object({ username: z.string().max(100) }),
          request.body,
          app.httpErrors.badRequest
        );
        const username = normalizeUsername(rawUsername);
        if (!isValidUsername(username)) {
          return { username, available: false, reason: "INVALID" };
        }
        const [owner] = await app.db`
          SELECT user_id FROM user_profiles
          WHERE username=${username} AND user_id<>${request.authenticatedUser!.id}
          LIMIT 1
        `;
        return { username, available: !owner, reason: owner ? "TAKEN" : null };
      });

      authenticated.post("/me/smart-wallet/socketfi", { config: { rateLimit: { max: 5, timeWindow: 60_000 } } }, async (request) => {
        const { accessToken } = parse(
          z.object({ accessToken: z.string().min(100).max(16_384) }),
          request.body,
          app.httpErrors.badRequest
        );
        let identity;
        try {
          identity = await verifySocketFiToken(accessToken, environment.socketFi);
        } catch {
          throw app.httpErrors.unauthorized("SocketFi wallet authorization is invalid or expired.");
        }
        try {
          return await linkSocketFiIdentity(app.db, request.authenticatedUser!.id, identity);
        } catch (error) {
          if (["SOCKETFI_IDENTITY_IN_USE", "SOCKETFI_WALLET_IN_USE"].includes((error as Error).message)) {
            throw app.httpErrors.conflict("This smart wallet is already linked to another Paktly account.");
          }
          throw error;
        }
      });

      authenticated.patch("/me", async (request) => {
        const body = parse(z.object({ displayName: z.string().trim().min(1).max(80).optional(), username: z.string().transform(normalizeUsername).refine(isValidUsername, "Use 3–30 letters, numbers, or underscores, beginning and ending with a letter or number.").nullable().optional(), avatarUrl: z.string().url().nullable().optional(), defaultCurrency: currency.optional(), locale: z.string().min(2).max(20).optional(), timezone: z.string().min(1).max(80).optional() }), request.body, app.httpErrors.badRequest);
        const userId = request.authenticatedUser!.id;
        try {
          const [profile] = await app.db`
            UPDATE user_profiles SET
              display_name=COALESCE(${body.displayName ?? null},display_name), username=CASE WHEN ${body.username === undefined} THEN username ELSE ${body.username ?? null} END,
              avatar_url=CASE WHEN ${body.avatarUrl === undefined} THEN avatar_url ELSE ${body.avatarUrl ?? null} END,
              default_currency=COALESCE(${body.defaultCurrency ?? null},default_currency), locale=COALESCE(${body.locale ?? null},locale),
              timezone=COALESCE(${body.timezone ?? null},timezone),updated_at=now()
            WHERE user_id=${userId} RETURNING *
          `;
          return { profile };
        } catch (error) {
          if ((error as { code?: string }).code === "23505") {
            throw app.httpErrors.conflict("That username is already taken.");
          }
          throw error;
        }
      });

      authenticated.post("/groups", async (request, reply) => {
        const body = parse(z.object({ name: z.string().trim().min(1).max(100), description: z.string().trim().max(1000).nullable().optional(), defaultCurrency: currency.default("USD") }), request.body, app.httpErrors.badRequest);
        const userId = request.authenticatedUser!.id;
        const groupId = randomUUID();
        await app.db.begin(async (tx) => {
          await tx`INSERT INTO groups(id,name,description,default_currency,created_by) VALUES(${groupId},${body.name},${body.description ?? null},${body.defaultCurrency},${userId})`;
          await tx`INSERT INTO group_members(group_id,user_id,role) VALUES(${groupId},${userId},'OWNER')`;
          await tx`INSERT INTO ledger_accounts(id,group_id,user_id,currency) VALUES(${randomUUID()},${groupId},${userId},${body.defaultCurrency})`;
          await tx`INSERT INTO activity_events(id,group_id,actor_user_id,type,entity_type,entity_id,summary) VALUES(${randomUUID()},${groupId},${userId},'GROUP_CREATED','GROUP',${groupId},${`${request.authenticatedUser!.displayName} created ${body.name}`})`;
        });
        return reply.status(201).send({ group: { id: groupId, ...body, role: "OWNER" } });
      });

      authenticated.get("/groups", async (request) => {
        const groups = await app.db`
          SELECT g.id,g.name,g.description,g.default_currency,g.status,g.created_at,gm.role,
            (SELECT count(*)::int FROM group_members m WHERE m.group_id=g.id AND m.status='ACTIVE') member_count
          FROM groups g JOIN group_members gm ON gm.group_id=g.id
          WHERE gm.user_id=${request.authenticatedUser!.id} AND gm.status='ACTIVE' ORDER BY g.updated_at DESC
        `;
        return { groups };
      });

      authenticated.get("/groups/:groupId", async (request) => {
        const { groupId } = parse(z.object({ groupId: uuid }), request.params, app.httpErrors.badRequest);
        await requireMember(app, groupId, request.authenticatedUser!.id);
        const [group] = await app.db`SELECT * FROM groups WHERE id=${groupId}`;
        const members = await app.db`SELECT u.id,u.email,p.display_name,p.avatar_url,gm.role,gm.joined_at FROM group_members gm JOIN users u ON u.id=gm.user_id JOIN user_profiles p ON p.user_id=u.id WHERE gm.group_id=${groupId} AND gm.status='ACTIVE' ORDER BY gm.joined_at`;
        return { group, members };
      });

      authenticated.post("/groups/:groupId/invitations", async (request, reply) => {
        const { groupId } = parse(z.object({ groupId: uuid }), request.params, app.httpErrors.badRequest);
        const body = parse(
          z.union([
            z.object({ identifier: z.string().trim().min(3).max(254) }),
            z.object({ email: z.string().trim().email() })
          ]),
          request.body,
          app.httpErrors.badRequest
        );
        const userId = request.authenticatedUser!.id;
        await requireMember(app, groupId, userId, true);
        const rawIdentifier = ("identifier" in body ? body.identifier : body.email).trim().toLowerCase();
        let invitationEmail: string;
        let invitedUserId: string | undefined;
        if (rawIdentifier.includes("@") && !rawIdentifier.startsWith("@")) {
          const parsedEmail = z.string().email().safeParse(rawIdentifier);
          if (!parsedEmail.success) throw app.httpErrors.badRequest("Enter a valid email address or Paktly username.");
          invitationEmail = parsedEmail.data;
          const [account] = await app.db`SELECT id FROM users WHERE email=${invitationEmail} AND status='ACTIVE'`;
          invitedUserId = account ? String(account.id) : undefined;
        } else {
          const username = normalizeUsername(rawIdentifier.replace(/^@/, ""));
          if (!isValidUsername(username)) throw app.httpErrors.badRequest("Enter a valid email address or Paktly username.");
          const [account] = await app.db`
            SELECT u.id,u.email FROM user_profiles p
            JOIN users u ON u.id=p.user_id
            WHERE p.username=${username} AND u.status='ACTIVE'
          `;
          if (!account) throw app.httpErrors.notFound("No Paktly member has that username.");
          invitationEmail = String(account.email);
          invitedUserId = String(account.id);
        }
        if (invitationEmail === request.authenticatedUser!.email) {
          throw app.httpErrors.conflict("You are already a member of this plan.");
        }
        if (invitedUserId) {
          const [membership] = await app.db`
            SELECT 1 FROM group_members WHERE group_id=${groupId} AND user_id=${invitedUserId} AND status='ACTIVE'
          `;
          if (membership) throw app.httpErrors.conflict("That person is already a member of this plan.");
        }
        const [group] = await app.db`SELECT name FROM groups WHERE id=${groupId} AND status='ACTIVE'`;
        if (!group) throw app.httpErrors.notFound("Plan not found.");
        const rawToken = randomBytes(24).toString("base64url");
        const invitationId = randomUUID();
        try {
          await app.db.begin(async (tx) => {
            await tx`INSERT INTO invitations(id,group_id,email,invited_by,token_hash,expires_at) VALUES(${invitationId},${groupId},${invitationEmail},${userId},${hashToken(rawToken)},now()+interval '7 days')`;
            await tx`INSERT INTO activity_events(id,group_id,actor_user_id,type,entity_type,entity_id,summary,metadata) VALUES(${randomUUID()},${groupId},${userId},'INVITATION_SENT','INVITATION',${invitationId},${`${request.authenticatedUser!.displayName} invited ${invitationEmail}`},${app.db.json({ email: invitationEmail })})`;
            if (invitedUserId) {
              await tx`INSERT INTO notifications(id,user_id,group_id,type,title,body,entity_type,entity_id,category,data,deep_link,deduplication_key,priority,expires_at) VALUES(${randomUUID()},${invitedUserId},${groupId},'INVITATION_RECEIVED','You were invited',${`${request.authenticatedUser!.displayName} invited you to ${String(group.name)}`},'INVITATION',${invitationId},'INVITATION',${app.db.json({ invitationId, groupId })},${`paktly://invitation/${invitationId}`},${`invitation:${invitationId}`},'HIGH',now()+interval '7 days')`;
            }
          });
        } catch { throw app.httpErrors.conflict("A pending invitation already exists for this email."); }
        const invitationUrl = `${environment.emailAuth?.publicAppUrl ?? "https://paktly.io"}/invite?token=${encodeURIComponent(rawToken)}`;
        if (emailProvider) {
          try {
            await emailProvider.sendPlanInvitation({
              recipient: invitationEmail,
              inviterName: request.authenticatedUser!.displayName,
              planName: String(group.name),
              invitationUrl,
              expiresInDays: 7
            });
          } catch (error) {
            await app.db`UPDATE invitations SET status='REVOKED' WHERE id=${invitationId}`;
            request.log.error({ err: error, invitationId }, "plan invitation delivery failed");
            throw app.httpErrors.serviceUnavailable("We couldn’t send this invitation. Please try again.");
          }
        } else if (environment.nodeEnvironment === "production") {
          await app.db`UPDATE invitations SET status='REVOKED' WHERE id=${invitationId}`;
          throw app.httpErrors.serviceUnavailable("Invitation email delivery is not configured.");
        }
        return reply.status(201).send({ invitation: { id: invitationId, email: invitationEmail, status: "PENDING", ...(environment.nodeEnvironment !== "production" ? { token: rawToken } : {}) } });
      });

      authenticated.get("/invitations", async (request) => {
        const invitations = await app.db`
          SELECT i.id,i.group_id,i.email,i.status,i.expires_at,i.created_at,
            g.name group_name,p.display_name inviter_name
          FROM invitations i
          JOIN groups g ON g.id=i.group_id
          JOIN user_profiles p ON p.user_id=i.invited_by
          WHERE i.email=${request.authenticatedUser!.email}
            AND i.status='PENDING' AND i.expires_at>now() AND g.status='ACTIVE'
          ORDER BY i.created_at DESC
        `;
        return { invitations };
      });

      authenticated.post("/invitations/resolve", async (request) => {
        const { token } = parse(z.object({ token: z.string().min(10) }), request.body, app.httpErrors.badRequest);
        const [record] = await app.db`SELECT id FROM invitations WHERE token_hash=${hashToken(token)}`;
        if (!record) throw app.httpErrors.gone("This invitation is no longer valid.");
        const invitation = await invitationForRecipient(app, String(record.id), request.authenticatedUser!.email);
        if (!invitation) throw app.httpErrors.forbidden("This invitation belongs to a different email address.");
        if (invitation.status !== "PENDING" || new Date(String(invitation.expires_at)) <= new Date()) {
          throw app.httpErrors.gone("This invitation is no longer valid.");
        }
        return { invitation };
      });

      authenticated.post("/invitations/:invitationId/accept", async (request) => {
        const { invitationId } = parse(z.object({ invitationId: uuid }), request.params, app.httpErrors.badRequest);
        const invitation = await invitationForRecipient(app, invitationId, request.authenticatedUser!.email);
        if (!invitation) throw app.httpErrors.notFound("Invitation not found.");
        return acceptInvitation(app, invitationId, request.authenticatedUser!);
      });

      authenticated.post("/invitations/:invitationId/decline", async (request) => {
        const { invitationId } = parse(z.object({ invitationId: uuid }), request.params, app.httpErrors.badRequest);
        const [invitation] = await app.db`
          UPDATE invitations SET status='DECLINED'
          WHERE id=${invitationId} AND email=${request.authenticatedUser!.email}
            AND status='PENDING' AND expires_at>now()
          RETURNING id,group_id
        `;
        if (!invitation) throw app.httpErrors.gone("This invitation is no longer available.");
        return { invitation: { id: String(invitation.id), status: "DECLINED" } };
      });

      authenticated.post("/invitations/accept", async (request) => {
        const { token } = parse(z.object({ token: z.string().min(10) }), request.body, app.httpErrors.badRequest);
        const [invitation] = await app.db`SELECT id,email FROM invitations WHERE token_hash=${hashToken(token)}`;
        if (!invitation) throw app.httpErrors.gone("This invitation is no longer valid.");
        if (String(invitation.email) !== request.authenticatedUser!.email) throw app.httpErrors.forbidden("This invitation belongs to a different email address.");
        return acceptInvitation(app, String(invitation.id), request.authenticatedUser!);
      });

      authenticated.get("/groups/:groupId/activity", async (request) => {
        const { groupId } = parse(z.object({ groupId: uuid }), request.params, app.httpErrors.badRequest);
        await requireMember(app, groupId, request.authenticatedUser!.id);
        const events = await app.db`SELECT * FROM activity_events WHERE group_id=${groupId} ORDER BY created_at DESC LIMIT 100`;
        return { events };
      });

      authenticated.get("/notifications", async (request) => ({
        notifications: await app.db`SELECT * FROM notifications WHERE user_id=${request.authenticatedUser!.id} ORDER BY created_at DESC LIMIT 100`,
        unreadCount: Number((await app.db`SELECT count(*)::int count FROM notifications WHERE user_id=${request.authenticatedUser!.id} AND read_at IS NULL`)[0]?.count ?? 0)
      }));
      authenticated.post("/notifications/:notificationId/read", async (request) => {
        const { notificationId } = parse(z.object({ notificationId: uuid }), request.params, app.httpErrors.badRequest);
        const [notification] = await app.db`UPDATE notifications SET read_at=COALESCE(read_at,now()) WHERE id=${notificationId} AND user_id=${request.authenticatedUser!.id} RETURNING *`;
        if (!notification) throw app.httpErrors.notFound("Notification not found.");
        return { notification };
      });
      authenticated.post("/notifications/read-all", async (request) => {
        const result = await app.db`UPDATE notifications SET read_at=COALESCE(read_at,now()) WHERE user_id=${request.authenticatedUser!.id} AND read_at IS NULL RETURNING id`;
        return { updated: result.length };
      });
      await Promise.resolve();
    });
    await Promise.resolve();
  };
}

async function acceptInvitation(
  app: FastifyInstance,
  invitationId: string,
  user: { id: string; email: string; displayName: string }
) {
  return app.db.begin(async (tx) => {
    const [invitation] = await tx`SELECT * FROM invitations WHERE id=${invitationId} FOR UPDATE`;
    if (!invitation || invitation.status !== "PENDING" || new Date(String(invitation.expires_at)) <= new Date()) {
      throw app.httpErrors.gone("This invitation is no longer valid.");
    }
    if (String(invitation.email) !== user.email) throw app.httpErrors.forbidden("This invitation belongs to a different email address.");
    const [group] = await tx`SELECT default_currency,name FROM groups WHERE id=${String(invitation.group_id)} AND status='ACTIVE'`;
    if (!group) throw app.httpErrors.gone("This plan is no longer available.");
    await tx`INSERT INTO group_members(group_id,user_id,role) VALUES(${String(invitation.group_id)},${user.id},'MEMBER') ON CONFLICT(group_id,user_id) DO UPDATE SET status='ACTIVE',role='MEMBER'`;
    await tx`INSERT INTO ledger_accounts(id,group_id,user_id,currency) VALUES(${randomUUID()},${String(invitation.group_id)},${user.id},${String(group.default_currency)}) ON CONFLICT DO NOTHING`;
    await tx`UPDATE invitations SET status='ACCEPTED',accepted_by=${user.id},accepted_at=now() WHERE id=${invitationId}`;
    await tx`INSERT INTO activity_events(id,group_id,actor_user_id,type,entity_type,entity_id,summary) VALUES(${randomUUID()},${String(invitation.group_id)},${user.id},'MEMBER_JOINED','MEMBER',${user.id},${`${user.displayName} joined ${String(group.name)}`})`;
    await tx`INSERT INTO notifications(id,user_id,group_id,type,title,body,entity_type,entity_id) SELECT gen_random_uuid(),user_id,${String(invitation.group_id)},'MEMBER_JOINED','A member joined',${`${user.displayName} joined ${String(group.name)}`},'MEMBER',${user.id} FROM group_members WHERE group_id=${String(invitation.group_id)} AND status='ACTIVE' AND user_id<>${user.id}`;
    return { groupId: String(invitation.group_id), status: "ACCEPTED" };
  });
}
