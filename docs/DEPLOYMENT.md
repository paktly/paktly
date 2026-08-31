# Deployment

## API

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

## Network separation

Testnet and mainnet values will be separate required configuration groups. Production financial flags default to disabled; a production build must never fall back to testnet.
