# Paktly API production deployment

The default production stack runs the API on `127.0.0.1:4000`. PostgreSQL and Redis have no host ports and communicate with the API on a private Docker network. This is designed to coexist with other applications on one VPS.

## First deployment

Install Docker Engine with the Compose plugin, then point the `api.paktly.io` DNS A/AAAA record at the VPS.

From the cloned repository:

```bash
sudo install -d -m 700 -o "$USER" -g "$USER" /opt/paktly /opt/paktly/backups/postgres
sudo cp infrastructure/production/env.example /opt/paktly/.env
sudo chown "$USER":"$USER" /opt/paktly/.env
chmod 600 /opt/paktly/.env
openssl rand -hex 32
openssl rand -hex 32
```

Edit `/opt/paktly/.env`, replace both password placeholders, and configure the server-only SocketFi client secret. Keep real secrets out of Git and never copy `SOCKETFI_CLIENT_SECRET` into Xcode.

Deploy the checked-out commit:

```bash
./scripts/deploy-production.sh
curl --fail https://api.paktly.io/api/v1/ready
```

The deployment script builds an immutable image tagged with the Git commit, starts private dependencies, applies migrations, replaces the API container, checks readiness, and automatically restores the previous API image if verification fails.

If port `4000` is already used by another application, set an unused loopback port in `/opt/paktly/.env`, for example `PAKTLY_HOST_API_PORT=4010`. The deployment verifier discovers the published port from Compose automatically. Point the host reverse proxy at that same port.

## Reverse proxy

If the VPS already has Nginx, adapt `nginx-api.paktly.io.conf.example`, obtain the TLS certificate, validate with `sudo nginx -t`, and reload Nginx. Do not launch the included Caddy service because both proxies would compete for ports 80 and 443.

If the VPS has no reverse proxy, run Caddy with:

```bash
export PAKTLY_RELEASE="$(cat /opt/paktly/current-release)"
docker compose --env-file /opt/paktly/.env \
  -f infrastructure/production/compose.yml \
  -f infrastructure/production/compose.caddy.yml up -d caddy
```

Caddy provisions and renews TLS automatically after DNS reaches the VPS and ports 80/443 are reachable.

## Updating and rolling back

```bash
git pull --ff-only
./scripts/deploy-production.sh
```

List retained images and roll back to a known release:

```bash
docker image ls paktly-api
./scripts/rollback-production.sh <release-tag>
```

Only the application image is rolled back. Database migrations must remain backward-compatible with the previous application release.

## Backups

Test a backup manually:

```bash
./scripts/backup-postgres.sh
ls -lh /opt/paktly/backups/postgres
```

The included systemd unit assumes the repository is `/home/deploy/paktly` and the service user is `deploy`. Adjust both values if needed, then install it:

```bash
sudo cp infrastructure/production/systemd/paktly-backup.* /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now paktly-backup.timer
systemctl list-timers paktly-backup.timer
```

The job writes compressed custom-format PostgreSQL dumps, creates SHA-256 checksums, and retains 14 days by default. Copy encrypted backups off the VPS and regularly test restoration; a backup stored only beside the live database is not disaster recovery.

## Authentication launch gate

`POST /api/v1/auth/dev-session` is disabled whenever `NODE_ENV=production`. Production authentication uses `POST /api/v1/auth/socketfi`. Before deploying it, register Paktly with SocketFi, configure `SOCKETFI_PROJECT_SECRETS` on SocketFi, place the matching secret only in `/opt/paktly/.env`, publish the SocketFi RP-domain Apple association, and deploy both APIs. Keep `SOCKETFI_NETWORK=TESTNET` until the account and contract paths complete security review.

## Firewall

Do not blindly enable UFW on an established multi-service VPS. First run `sudo ufw status verbose` and inventory every public port in use. The Paktly containers expose only the API on loopback; PostgreSQL and Redis need no firewall openings. Your existing reverse proxy needs inbound 80/443, and SSH must be allowed before enabling UFW.
