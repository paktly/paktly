# Deployment

## API

Account deletion requires the API migration, updated iOS build, and a separate Sign in with Apple revocation key for Apple-linked accounts. See [ACCOUNT_DELETION.md](ACCOUNT_DELETION.md) for configuration and release checks.

The API builds from the repository root so workspace dependencies remain available:

```bash
docker build -f services/api/Dockerfile -t paktly-api:local .
docker run --rm --env-file .env paktly-api:local node scripts/migrate.mjs
docker run --rm -p 4000:4000 --env-file .env paktly-api:local
```

Run migrations as a one-off release task before shifting traffic. `/api/v1/health` checks process liveness; `/api/v1/ready` verifies PostgreSQL connectivity and should gate traffic.

Production deployments must supply validated configuration through the platform secret manager. Images must not contain `.env` files.

The Contabo/VPS deployment stack, reverse-proxy examples, backup timer, rollout, and rollback procedures are documented in [`infrastructure/production/README.md`](../infrastructure/production/README.md). The default stack binds the API only to loopback and does not publish PostgreSQL or Redis.

Production authentication is a launch gate: the development session endpoint is disabled in production. Email OTP uses the provider-neutral `SmtpEmailProvider` backed by Nodemailer and Zoho Mail or ZeptoMail SMTP. Enable it with `EMAIL_AUTH_ENABLED=true`, a high-entropy `EMAIL_OTP_SECRET`, `SMTP_HOST`, `SMTP_PORT`, `SMTP_SECURE`, `SMTP_USERNAME`, `SMTP_PASSWORD`, and a matching sender on a verified domain. Use a Zoho application-specific password when two-factor authentication is enabled. SocketFi verification remains required for Smart Wallet linking; never place SMTP or SocketFi credentials in the iOS app.

Set `PUBLIC_APP_URL=https://paktly.io` in production. Plan invitation email links
are generated from this origin; an incorrect value sends recipients to an
untrusted or unusable acceptance page. Invitation delivery uses the same SMTP
configuration as email OTP and production fails closed when email is unavailable.

Apple authentication requires the Sign in with Apple capability on App ID `io.paktly.app`, `APPLE_AUTH_ENABLED=true`, and `APPLE_CLIENT_ID=io.paktly.app`. Google authentication requires an iOS OAuth client for the bundle ID, a separate web OAuth client for backend token audience verification, their values in `apps/ios/project.yml`, and the same web client ID in `GOOGLE_SERVER_CLIENT_ID`. The reversed iOS client ID must be registered as the app URL scheme. Provider options must not be enabled in production until these identifiers are real and matching.

Remote notifications use an APNs token-signing key. Enable the Push Notifications capability for `io.paktly.app`, create an Apple `.p8` key with APNs access, then configure `APNS_ENABLED`, `APNS_TEAM_ID`, `APNS_KEY_ID`, `APNS_PRIVATE_KEY`, and `APNS_BUNDLE_ID`. Store the PEM value with literal `\n` separators in `/opt/paktly/.env`; never commit the key. The production Compose deployment starts a separate `notification-worker` from the same immutable image. Keep APNs disabled until the capability, provisioning profiles, and both sandbox and TestFlight delivery have been verified. See [NOTIFICATIONS.md](NOTIFICATIONS.md).

## Web

The public content is statically rendered, while `/api/waitlist` is a server route backed by PostgreSQL. Apply the consent-table migration before serving traffic:

```bash
pnpm --filter @pakt/web migrate:waitlist
pnpm --filter @pakt/web build
pnpm --filter @pakt/web start
```

Production requires `DATABASE_URL` and `NEXT_PUBLIC_SITE_URL`. Run Lighthouse and route tests in CI. A hosting choice must support the Next.js runtime route, TLS, edge abuse controls, secret injection, backups, and data-rights operations.

The legal pages accurately describe the prelaunch implementation but require operator identity, address, jurisdiction, and qualified legal review before a commercial or regulated launch.

## iOS

Generate the project with XcodeGen, archive with the production configuration, and distribute through App Store Connect. Associated domains, signing teams, privacy declarations, and production URLs require launch-specific values.

Invitation handoff requires the Associated Domains capability for
`applinks:paktly.io` on App ID `io.paktly.app`. Deploy
`apps/web/public/.well-known/apple-app-site-association` over HTTPS with
`Content-Type: application/json`, without a redirect, before device testing.
The app also registers `paktly://invite` as an installed-app fallback. After the
recipient authenticates with the invited email, the app consumes the pending
token and refreshes plans and notifications.

## Network separation

Testnet and mainnet values will be separate required configuration groups. Production financial flags default to disabled; a production build must never fall back to testnet.

## September 2026 App Store fixes: existing VPS rollout

Use these steps for an existing installation of the production Compose stack. For a new VPS, follow [first deployment](../infrastructure/production/README.md) first. No new migration files were added by this patch; the deployment script still applies any previously pending migrations.

1. Wait for the pushed commit’s GitHub Actions checks to pass. SSH into the VPS and enter the existing repository checkout. Ensure `git status --short` is clean before updating.

   ```bash
   git switch main
   git pull --ff-only origin main
   git log -1 --format='%h %s'
   ./scripts/backup-postgres.sh
   cat /opt/paktly/current-release
   ```

   Record the previous release tag for rollback. Check that the backup completed before proceeding.

2. Edit the existing `/opt/paktly/.env` privately; preserve database passwords and other existing settings. Verify all four Apple values:

   ```dotenv
   APPLE_CLIENT_ID=io.paktly.app
   APPLE_TEAM_ID=GC29BX444D
   APPLE_KEY_ID=YOUR_SIGN_IN_WITH_APPLE_KEY_ID
   APPLE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\nYOUR_KEY_CONTENT\n-----END PRIVATE KEY-----"
   ```

   Use a Sign in with Apple key associated with this App ID, not an APNs-only key. Keep the PEM on one line with literal `\n` separators. Do not commit or paste the real key into logs.

   ```bash
   chmod 600 /opt/paktly/.env
   ./scripts/deploy-production.sh
   curl --fail --show-error https://api.paktly.io/api/v1/ready
   ```

3. Inspect both services using the deployed tag:

   ```bash
   export PAKTLY_RELEASE="$(cat /opt/paktly/current-release)"
   docker compose --env-file /opt/paktly/.env -f infrastructure/production/compose.yml ps
   docker compose --env-file /opt/paktly/.env -f infrastructure/production/compose.yml logs --tail=100 api notification-worker
   ```

   Readiness confirms database connectivity; it does not verify Apple key validity. On a disposable account, complete fresh/returning Apple sign-in, confirm no forced name/email step, complete deletion, and verify re-signup. If deletion fails, capture the support request ID and sanitized `apple_deletion_failed` stage/reason. Do not resubmit based on readiness alone.

4. If rollback is necessary, use the recorded tag:

   ```bash
   ./scripts/rollback-production.sh PREVIOUS_RELEASE_TAG
   curl --fail --show-error https://api.paktly.io/api/v1/ready
   ```

   This restores the API and notification worker images, not database contents or environment changes.
