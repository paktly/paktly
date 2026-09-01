# Notifications

PostgreSQL is the notification source of truth. APNs is an optional delivery channel. An `AFTER INSERT` trigger creates one durable delivery per active device in the same transaction that creates the notification. The worker claims rows with `FOR UPDATE SKIP LOCKED`, making it safe to run multiple worker replicas.

## Delivery lifecycle

`PENDING → PROCESSING → SUBMITTED`

Transient APNs/network failures become `RETRY_PENDING` with exponential backoff and jitter. Processing locks older than five minutes are recovered. Delivery stops after eight attempts. APNs `410`, `BadDeviceToken`, and `Unregistered` responses invalidate the device. Permanent payload/topic errors become `FAILED`. Preferences and expired notifications become `SUPPRESSED`.

The worker uses persistent HTTP/2 sessions for Apple sandbox and production endpoints and refreshes its ES256 provider JWT before Apple's one-hour limit. Each device records its APNs environment so development and TestFlight tokens never cross environments.

## Configuration

```env
APNS_ENABLED=true
APNS_TEAM_ID=GC29BX444D
APNS_KEY_ID=XXXXXXXXXX
APNS_PRIVATE_KEY=-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----
APNS_BUNDLE_ID=io.paktly.app
```

The API can run with `APNS_ENABLED=false`; delivery rows remain pending and the worker stays idle. The `.p8` key is a server secret. It must never be added to Xcode, Git, logs, or unencrypted backups.

## iOS behavior

Paktly asks for permission contextually from Profile, registers only authenticated installations, updates rotated tokens idempotently, unregisters during sign-out, displays foreground banners, maintains the unread badge, and routes push taps after cold launch. Invitation pushes open the invitation decision sheet; plan activity opens the relevant plan.

Payloads contain identifiers only. Private lock-screen mode replaces title/body content with a generic Paktly message. Authoritative data is fetched after the app opens.

## Operations

```bash
export PAKTLY_RELEASE="$(cat /opt/paktly/current-release)"
docker compose --env-file /opt/paktly/.env -f infrastructure/production/compose.yml ps
docker compose --env-file /opt/paktly/.env -f infrastructure/production/compose.yml logs --follow --tail=100 notification-worker
```

Monitor pending age, retries, permanent failures, invalid-token rate, and submission latency. A useful database check is:

```sql
SELECT status,count(*),min(created_at) oldest
FROM notification_deliveries
GROUP BY status ORDER BY status;
```

## Release verification

1. Build a signed Debug app and verify sandbox APNs on a physical device.
2. Verify foreground, background, locked, and force-closed delivery.
3. Reinstall and confirm token rotation updates the installation.
4. Verify sign-out deactivates delivery.
5. Verify private previews and each preference category.
6. Distribute through TestFlight and repeat against production APNs.
7. Confirm invalid tokens transition to `INVALID` without retry storms.
