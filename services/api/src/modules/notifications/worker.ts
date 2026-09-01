import postgres, { type Sql } from "postgres";
import { loadEnvironment } from "../../config/environment.js";
import { ApnsPushNotificationProvider, DisabledPushProvider, type PushNotificationProvider } from "./apns-provider.js";

function preferenceColumn(type: string): "invitations" | "expenses" | "settlements" | "contributions" | "plan_reminders" | "marketing" | undefined {
  if (type.startsWith("INVITATION") || type === "MEMBER_JOINED") return "invitations";
  if (type.startsWith("EXPENSE")) return "expenses";
  if (type.startsWith("SETTLEMENT")) return "settlements";
  if (type.startsWith("CONTRIBUTION") || type.startsWith("REFUND")) return "contributions";
  if (type.startsWith("PLAN_")) return "plan_reminders";
  if (type.startsWith("MARKETING")) return "marketing";
  return undefined;
}

export class NotificationDeliveryWorker {
  constructor(private readonly database: Sql, private readonly provider: PushNotificationProvider) {}

  async runBatch(limit = 50): Promise<number> {
    await this.database`
      UPDATE notification_deliveries SET status='RETRY_PENDING',available_at=now(),locked_at=NULL,updated_at=now(),last_error='STALE_PROCESSING_LOCK'
      WHERE status='PROCESSING' AND locked_at<now()-interval '5 minutes'
    `;
    const claimed = await this.database`
      WITH ready AS (
        SELECT id FROM notification_deliveries
        WHERE status IN ('PENDING','RETRY_PENDING') AND available_at<=now()
        ORDER BY available_at,created_at FOR UPDATE SKIP LOCKED LIMIT ${limit}
      )
      UPDATE notification_deliveries d SET status='PROCESSING',locked_at=now(),attempts=d.attempts+1,updated_at=now()
      FROM ready WHERE d.id=ready.id RETURNING d.id
    `;
    for (const row of claimed) await this.process(String(row.id));
    return claimed.length;
  }

  private async process(deliveryId: string): Promise<void> {
    const [row] = await this.database`
      SELECT d.*,n.user_id,n.type,n.title,n.body,n.category,n.data,n.group_id,n.entity_type,n.entity_id,n.deep_link,n.expires_at,n.read_at,
        pd.apns_token,pd.apns_environment,pd.bundle_id,pd.status device_status,
        COALESCE(np.invitations,true) invitations,COALESCE(np.expenses,true) expenses,
        COALESCE(np.settlements,true) settlements,COALESCE(np.contributions,true) contributions,
        COALESCE(np.plan_reminders,true) plan_reminders,COALESCE(np.marketing,false) marketing,
        COALESCE(np.sound_enabled,true) sound_enabled,COALESCE(np.badges_enabled,true) badges_enabled,
        COALESCE(np.lock_screen_detail,'STANDARD') lock_screen_detail
      FROM notification_deliveries d JOIN notifications n ON n.id=d.notification_id
      JOIN push_devices pd ON pd.id=d.device_id
      LEFT JOIN notification_preferences np ON np.user_id=n.user_id
      WHERE d.id=${deliveryId}
    `;
    if (!row) return;
    const preference = preferenceColumn(String(row.type));
    if (row.device_status !== "ACTIVE" || row.read_at || (preference && row[preference] === false) || (row.expires_at && new Date(String(row.expires_at)) <= new Date())) {
      await this.finish(deliveryId, "SUPPRESSED", undefined, "PREFERENCE_OR_EXPIRATION");
      return;
    }
    const [unread] = await this.database`SELECT count(*)::int count FROM notifications WHERE user_id=${String(row.user_id)} AND read_at IS NULL`;
    const privateContent = row.lock_screen_detail === "PRIVATE";
    try {
      const result = await this.provider.send({
        apnsId: deliveryId,
        token: String(row.apns_token), environment: String(row.apns_environment) as "SANDBOX" | "PRODUCTION",
        bundleId: String(row.bundle_id), title: privateContent ? "Paktly update" : String(row.title),
        body: privateContent ? "Open Paktly to view this notification." : String(row.body), category: String(row.category),
        sound: Boolean(row.sound_enabled), ...(row.badges_enabled ? { badge: Number(unread?.count ?? 0) } : {}),
        ...(row.expires_at ? { expiration: new Date(String(row.expires_at)) } : {}),
        data: {
          notificationId: String(row.notification_id), type: String(row.type),
          ...(row.group_id ? { groupId: String(row.group_id) } : {}),
          ...(row.entity_type ? { entityType: String(row.entity_type) } : {}),
          ...(row.entity_id ? { entityId: String(row.entity_id) } : {}),
          ...(row.deep_link ? { deepLink: String(row.deep_link) } : {}),
          ...((row.data as Record<string, unknown> | null) ?? {})
        }
      });
      if (result.status === 200) await this.finish(deliveryId, "SUBMITTED", result.apnsId);
      else if (result.status === 410 || result.reason === "BadDeviceToken" || result.reason === "Unregistered") {
        await this.database.begin(async (tx) => {
          await tx`UPDATE push_devices SET status='INVALID',invalidated_at=now(),updated_at=now() WHERE id=${String(row.device_id)}`;
          await tx`UPDATE notification_deliveries SET status='INVALID_TOKEN',apns_id=${result.apnsId ?? null},last_error=${result.reason ?? `HTTP_${result.status}`},updated_at=now() WHERE id=${deliveryId}`;
        });
      } else if (result.status === 429 || result.status >= 500) await this.retry(deliveryId, Number(row.attempts), result.reason ?? `HTTP_${result.status}`);
      else await this.finish(deliveryId, "FAILED", result.apnsId, result.reason ?? `HTTP_${result.status}`);
    } catch (error) {
      await this.retry(deliveryId, Number(row.attempts), error instanceof Error ? error.message : "APNS_NETWORK_ERROR");
    }
  }

  private async retry(id: string, attempts: number, error: string) {
    if (attempts >= 8) return this.finish(id, "FAILED", undefined, error);
    const delaySeconds = Math.min(3600, 2 ** Math.max(attempts, 1) * 15) + Math.floor(Math.random() * 10);
    await this.database`UPDATE notification_deliveries SET status='RETRY_PENDING',available_at=now()+(${delaySeconds}*interval '1 second'),locked_at=NULL,last_error=${error.slice(0,500)},updated_at=now() WHERE id=${id}`;
  }

  private async finish(id: string, status: string, apnsId?: string, error?: string) {
    await this.database`UPDATE notification_deliveries SET status=${status},submitted_at=CASE WHEN ${status}='SUBMITTED' THEN now() ELSE submitted_at END,apns_id=${apnsId ?? null},last_error=${error?.slice(0,500) ?? null},locked_at=NULL,updated_at=now() WHERE id=${id}`;
  }
}

async function main() {
  const environment = loadEnvironment();
  const database = postgres(environment.databaseUrl, { max: 5, idle_timeout: 20, connect_timeout: 10 });
  const provider = environment.apns?.enabled ? new ApnsPushNotificationProvider(environment.apns) : new DisabledPushProvider();
  const worker = new NotificationDeliveryWorker(database, provider);
  let stopping = false;
  process.on("SIGTERM", () => { stopping = true; });
  process.on("SIGINT", () => { stopping = true; });
  while (!stopping) {
    const count = environment.apns?.enabled ? await worker.runBatch() : 0;
    if (count === 0) await new Promise((resolve) => setTimeout(resolve, 2_000));
  }
  await database.end();
}

if (process.env.NODE_ENV !== "test") main().catch((error) => { console.error(error); process.exit(1); });
