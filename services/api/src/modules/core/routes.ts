import { randomBytes, randomUUID } from "node:crypto";
import type { FastifyInstance, FastifyPluginAsync } from "fastify";
import { z, type ZodType } from "zod";
import type { Environment } from "../../config/environment.js";
import { createDevelopmentSession, createSocketFiSession, hashToken, requireAuthentication } from "../auth/authentication.js";
import { verifySocketFiToken } from "../auth/socketfi.js";

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

export function coreRoutes(environment: Environment): FastifyPluginAsync {
  return async (app) => {
    app.post("/auth/dev-session", { config: { rateLimit: { max: 10, timeWindow: 60_000 } } }, async (request) => {
      if (environment.nodeEnvironment === "production") throw app.httpErrors.notFound();
      const body = parse(z.object({ email: z.string().email(), displayName: z.string().trim().min(1).max(80) }), request.body, app.httpErrors.badRequest);
      return createDevelopmentSession(app.db, body);
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
        return { profile };
      });

      authenticated.patch("/me", async (request) => {
        const body = parse(z.object({ displayName: z.string().trim().min(1).max(80).optional(), username: z.string().trim().min(3).max(30).nullable().optional(), avatarUrl: z.string().url().nullable().optional(), defaultCurrency: currency.optional(), locale: z.string().min(2).max(20).optional(), timezone: z.string().min(1).max(80).optional() }), request.body, app.httpErrors.badRequest);
        const userId = request.authenticatedUser!.id;
        const [profile] = await app.db`
          UPDATE user_profiles SET
            display_name=COALESCE(${body.displayName ?? null},display_name), username=CASE WHEN ${body.username === undefined} THEN username ELSE ${body.username ?? null} END,
            avatar_url=CASE WHEN ${body.avatarUrl === undefined} THEN avatar_url ELSE ${body.avatarUrl ?? null} END,
            default_currency=COALESCE(${body.defaultCurrency ?? null},default_currency), locale=COALESCE(${body.locale ?? null},locale),
            timezone=COALESCE(${body.timezone ?? null},timezone),updated_at=now()
          WHERE user_id=${userId} RETURNING *
        `;
        return { profile };
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
        const body = parse(z.object({ email: z.string().email().transform((value) => value.toLowerCase()) }), request.body, app.httpErrors.badRequest);
        const userId = request.authenticatedUser!.id;
        await requireMember(app, groupId, userId, true);
        const rawToken = randomBytes(24).toString("base64url");
        const invitationId = randomUUID();
        try {
          await app.db`INSERT INTO invitations(id,group_id,email,invited_by,token_hash,expires_at) VALUES(${invitationId},${groupId},${body.email},${userId},${hashToken(rawToken)},now()+interval '7 days')`;
        } catch { throw app.httpErrors.conflict("A pending invitation already exists for this email."); }
        await app.db`INSERT INTO activity_events(id,group_id,actor_user_id,type,entity_type,entity_id,summary,metadata) VALUES(${randomUUID()},${groupId},${userId},'INVITATION_SENT','INVITATION',${invitationId},${`${request.authenticatedUser!.displayName} invited ${body.email}`},${app.db.json({ email: body.email })})`;
        await app.db`INSERT INTO notifications(id,user_id,group_id,type,title,body,entity_type,entity_id) SELECT ${randomUUID()},id,${groupId},'INVITATION_RECEIVED','You were invited',${`${request.authenticatedUser!.displayName} invited you to a shared plan`},'INVITATION',${invitationId} FROM users WHERE email=${body.email}`;
        return reply.status(201).send({ invitation: { id: invitationId, email: body.email, status: "PENDING", ...(environment.nodeEnvironment !== "production" ? { token: rawToken } : {}) } });
      });

      authenticated.post("/invitations/accept", async (request) => {
        const { token } = parse(z.object({ token: z.string().min(10) }), request.body, app.httpErrors.badRequest);
        const user = request.authenticatedUser!;
        return app.db.begin(async (tx) => {
          const [invitation] = await tx`SELECT * FROM invitations WHERE token_hash=${hashToken(token)} FOR UPDATE`;
          if (!invitation || invitation.status !== "PENDING" || new Date(String(invitation.expires_at)) <= new Date()) throw app.httpErrors.gone("This invitation is no longer valid.");
          if (String(invitation.email) !== user.email) throw app.httpErrors.forbidden("This invitation belongs to a different email address.");
          const [group] = await tx`SELECT default_currency,name FROM groups WHERE id=${String(invitation.group_id)}`;
          await tx`INSERT INTO group_members(group_id,user_id,role) VALUES(${String(invitation.group_id)},${user.id},'MEMBER') ON CONFLICT(group_id,user_id) DO UPDATE SET status='ACTIVE',role='MEMBER'`;
          await tx`INSERT INTO ledger_accounts(id,group_id,user_id,currency) VALUES(${randomUUID()},${String(invitation.group_id)},${user.id},${String(group?.default_currency)}) ON CONFLICT DO NOTHING`;
          await tx`UPDATE invitations SET status='ACCEPTED',accepted_by=${user.id},accepted_at=now() WHERE id=${String(invitation.id)}`;
          await tx`INSERT INTO activity_events(id,group_id,actor_user_id,type,entity_type,entity_id,summary) VALUES(${randomUUID()},${String(invitation.group_id)},${user.id},'MEMBER_JOINED','MEMBER',${user.id},${`${user.displayName} joined ${String(group?.name)}`})`;
          await tx`INSERT INTO notifications(id,user_id,group_id,type,title,body,entity_type,entity_id) SELECT gen_random_uuid(),user_id,${String(invitation.group_id)},'MEMBER_JOINED','A member joined',${`${user.displayName} joined ${String(group?.name)}`},'MEMBER',${user.id} FROM group_members WHERE group_id=${String(invitation.group_id)} AND status='ACTIVE' AND user_id<>${user.id}`;
          return { groupId: String(invitation.group_id), status: "ACCEPTED" };
        });
      });

      authenticated.get("/groups/:groupId/activity", async (request) => {
        const { groupId } = parse(z.object({ groupId: uuid }), request.params, app.httpErrors.badRequest);
        await requireMember(app, groupId, request.authenticatedUser!.id);
        const events = await app.db`SELECT * FROM activity_events WHERE group_id=${groupId} ORDER BY created_at DESC LIMIT 100`;
        return { events };
      });

      authenticated.get("/notifications", async (request) => ({ notifications: await app.db`SELECT * FROM notifications WHERE user_id=${request.authenticatedUser!.id} ORDER BY created_at DESC LIMIT 100` }));
      authenticated.post("/notifications/:notificationId/read", async (request) => {
        const { notificationId } = parse(z.object({ notificationId: uuid }), request.params, app.httpErrors.badRequest);
        const [notification] = await app.db`UPDATE notifications SET read_at=COALESCE(read_at,now()) WHERE id=${notificationId} AND user_id=${request.authenticatedUser!.id} RETURNING *`;
        if (!notification) throw app.httpErrors.notFound("Notification not found.");
        return { notification };
      });
      await Promise.resolve();
    });
    await Promise.resolve();
  };
}
