import { connect, type ClientHttp2Session } from "node:http2";
import { importPKCS8, SignJWT } from "jose";

export type PushMessage = {
  apnsId: string;
  token: string;
  environment: "SANDBOX" | "PRODUCTION";
  bundleId: string;
  title: string;
  body: string;
  category: string;
  data: Record<string, unknown>;
  sound: boolean;
  badge?: number;
  expiration?: Date;
};

export type PushResult = { status: number; apnsId?: string; reason?: string };

export interface PushNotificationProvider {
  send(message: PushMessage): Promise<PushResult>;
}

export class DisabledPushProvider implements PushNotificationProvider {
  send(): Promise<PushResult> { return Promise.resolve({ status: 503, reason: "APNS_DISABLED" }); }
}

export class ApnsPushNotificationProvider implements PushNotificationProvider {
  private signingKey?: Awaited<ReturnType<typeof importPKCS8>>;
  private jwt?: { value: string; createdAt: number };
  private readonly sessions = new Map<string, ClientHttp2Session>();

  constructor(private readonly configuration: { teamId: string; keyId: string; privateKey: string }) {}

  private session(authority: string): ClientHttp2Session {
    const existing = this.sessions.get(authority);
    if (existing && !existing.closed && !existing.destroyed) return existing;
    const session = connect(authority);
    this.sessions.set(authority, session);
    const discard = () => { if (this.sessions.get(authority) === session) this.sessions.delete(authority); };
    session.on("error", discard);
    session.on("close", discard);
    session.on("goaway", () => { discard(); session.close(); });
    return session;
  }

  private async authorizationToken(): Promise<string> {
    const now = Math.floor(Date.now() / 1_000);
    if (this.jwt && now - this.jwt.createdAt < 50 * 60) return this.jwt.value;
    this.signingKey ??= await importPKCS8(this.configuration.privateKey.replace(/\\n/g, "\n"), "ES256");
    const value = await new SignJWT({})
      .setProtectedHeader({ alg: "ES256", kid: this.configuration.keyId })
      .setIssuer(this.configuration.teamId)
      .setIssuedAt(now)
      .sign(this.signingKey);
    this.jwt = { value, createdAt: now };
    return value;
  }

  async send(message: PushMessage): Promise<PushResult> {
    const authority = message.environment === "SANDBOX"
      ? "https://api.sandbox.push.apple.com"
      : "https://api.push.apple.com";
    const authorization = await this.authorizationToken();
    const alert = { title: message.title, body: message.body };
    const payload = JSON.stringify({
      aps: {
        alert,
        category: message.category,
        ...(message.sound ? { sound: "default" } : {}),
        ...(message.badge == null ? {} : { badge: message.badge })
      },
      ...message.data
    });

    return new Promise((resolve, reject) => {
      const session = this.session(authority);
      const request = session.request({
        ":method": "POST",
        ":path": `/3/device/${message.token}`,
        authorization: `bearer ${authorization}`,
        "apns-topic": message.bundleId,
        "apns-push-type": "alert",
        "apns-priority": "10",
        "apns-id": message.apnsId,
        ...(message.expiration ? { "apns-expiration": String(Math.floor(message.expiration.getTime() / 1_000)) } : {})
      });
      let responseStatus = 0;
      let apnsId: string | undefined;
      let responseBody = "";
      request.setEncoding("utf8");
      request.on("response", (headers) => {
        responseStatus = Number(headers[":status"] ?? 0);
        apnsId = typeof headers["apns-id"] === "string" ? headers["apns-id"] : undefined;
      });
      request.on("data", (chunk: string) => { responseBody += chunk; });
      request.on("end", () => {
        let reason: string | undefined;
        try { reason = (JSON.parse(responseBody) as { reason?: string }).reason; } catch { reason = responseBody || undefined; }
        resolve({ status: responseStatus, ...(apnsId ? { apnsId } : {}), ...(reason ? { reason } : {}) });
      });
      request.setTimeout(15_000, () => request.destroy(new Error("APNS_REQUEST_TIMEOUT")));
      request.once("error", reject);
      request.end(payload);
    });
  }
}
