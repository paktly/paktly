import { randomUUID } from "node:crypto";
import type { FastifyPluginAsync } from "fastify";
import { z } from "zod";
import type { Environment } from "../../config/environment.js";
import { requireAuthentication } from "../auth/authentication.js";

const registration = z.object({
  installationId: z.string().uuid(),
  token: z.string().trim().regex(/^[a-fA-F0-9]{32,512}$/),
  environment: z.enum(["SANDBOX","PRODUCTION"]),
  locale: z.string().min(2).max(35),
  timezone: z.string().min(1).max(80),
  appVersion: z.string().max(40).optional(),
  deviceModel: z.string().max(80).optional()
});

const preferenceUpdate = z.object({
  invitations: z.boolean().optional(), expenses: z.boolean().optional(), settlements: z.boolean().optional(),
  contributions: z.boolean().optional(), planReminders: z.boolean().optional(), marketing: z.boolean().optional(),
  soundEnabled: z.boolean().optional(), badgesEnabled: z.boolean().optional(),
  lockScreenDetail: z.enum(["STANDARD","PRIVATE"]).optional()
});

export function notificationRoutes(environment: Environment): FastifyPluginAsync {
  return async (app) => {
    app.addHook("preHandler", requireAuthentication);

    app.post("/devices/push", { config: { rateLimit: { max: 20, timeWindow: 60_000 } } }, async (request, reply) => {
      const parsed = registration.safeParse(request.body);
      if (!parsed.success) throw app.httpErrors.badRequest(parsed.error.issues[0]?.message ?? "Invalid push registration.");
      const body = parsed.data;
      const userId = request.authenticatedUser!.id;
      const deviceId = randomUUID();
      await app.db.begin(async (tx) => {
        await tx`DELETE FROM push_devices WHERE apns_token=${body.token.toLowerCase()} AND apns_environment=${body.environment} AND bundle_id=${environment.apns?.bundleId ?? "io.paktly.app"} AND installation_id<>${body.installationId}`;
        const [device] = await tx`
          INSERT INTO push_devices(id,user_id,installation_id,platform,apns_token,apns_environment,bundle_id,locale,timezone,app_version,device_model)
          VALUES(${deviceId},${userId},${body.installationId},'IOS',${body.token.toLowerCase()},${body.environment},${environment.apns?.bundleId ?? "io.paktly.app"},${body.locale},${body.timezone},${body.appVersion ?? null},${body.deviceModel ?? null})
          ON CONFLICT(installation_id) DO UPDATE SET user_id=excluded.user_id,apns_token=excluded.apns_token,
            apns_environment=excluded.apns_environment,bundle_id=excluded.bundle_id,locale=excluded.locale,timezone=excluded.timezone,
            app_version=excluded.app_version,device_model=excluded.device_model,status='ACTIVE',invalidated_at=NULL,last_seen_at=now(),updated_at=now()
          RETURNING id
        `;
        await tx`INSERT INTO notification_preferences(user_id) VALUES(${userId}) ON CONFLICT(user_id) DO NOTHING`;
        await tx`
          INSERT INTO notification_deliveries(id,notification_id,device_id)
          SELECT gen_random_uuid(),n.id,${String(device!.id)} FROM notifications n
          WHERE n.user_id=${userId} AND n.read_at IS NULL AND n.created_at>now()-interval '30 days'
            AND (n.expires_at IS NULL OR n.expires_at>now())
          ON CONFLICT(notification_id,device_id) DO NOTHING
        `;
      });
      return reply.status(201).send({ device: { installationId: body.installationId, status: "ACTIVE" } });
    });

    app.delete("/devices/push/:installationId", async (request, reply) => {
      const parsed = z.object({ installationId: z.string().uuid() }).safeParse(request.params);
      if (!parsed.success) throw app.httpErrors.badRequest("Invalid installation.");
      await app.db`UPDATE push_devices SET status='INACTIVE',updated_at=now() WHERE installation_id=${parsed.data.installationId} AND user_id=${request.authenticatedUser!.id}`;
      return reply.status(204).send();
    });

    app.get("/notification-preferences", async (request) => {
      const userId = request.authenticatedUser!.id;
      await app.db`INSERT INTO notification_preferences(user_id) VALUES(${userId}) ON CONFLICT(user_id) DO NOTHING`;
      const [preferences] = await app.db`SELECT * FROM notification_preferences WHERE user_id=${userId}`;
      return { preferences };
    });

    app.patch("/notification-preferences", async (request) => {
      const parsed = preferenceUpdate.safeParse(request.body);
      if (!parsed.success) throw app.httpErrors.badRequest(parsed.error.issues[0]?.message ?? "Invalid preferences.");
      const body = parsed.data;
      const userId = request.authenticatedUser!.id;
      const [preferences] = await app.db`
        INSERT INTO notification_preferences(user_id,invitations,expenses,settlements,contributions,plan_reminders,marketing,sound_enabled,badges_enabled,lock_screen_detail)
        VALUES(${userId},${body.invitations ?? true},${body.expenses ?? true},${body.settlements ?? true},${body.contributions ?? true},${body.planReminders ?? true},${body.marketing ?? false},${body.soundEnabled ?? true},${body.badgesEnabled ?? true},${body.lockScreenDetail ?? "STANDARD"})
        ON CONFLICT(user_id) DO UPDATE SET
          invitations=COALESCE(${body.invitations ?? null},notification_preferences.invitations),
          expenses=COALESCE(${body.expenses ?? null},notification_preferences.expenses),
          settlements=COALESCE(${body.settlements ?? null},notification_preferences.settlements),
          contributions=COALESCE(${body.contributions ?? null},notification_preferences.contributions),
          plan_reminders=COALESCE(${body.planReminders ?? null},notification_preferences.plan_reminders),
          marketing=COALESCE(${body.marketing ?? null},notification_preferences.marketing),
          sound_enabled=COALESCE(${body.soundEnabled ?? null},notification_preferences.sound_enabled),
          badges_enabled=COALESCE(${body.badgesEnabled ?? null},notification_preferences.badges_enabled),
          lock_screen_detail=COALESCE(${body.lockScreenDetail ?? null},notification_preferences.lock_screen_detail),updated_at=now()
        RETURNING *
      `;
      return { preferences };
    });
    await Promise.resolve();
  };
}
