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

Edit `/opt/paktly/.env` and replace both password placeholders with the generated URL-safe hexadecimal values. Keep real secrets out of Git.

Deploy the checked-out commit:

```bash
./scripts/deploy-production.sh
curl --fail https://api.paktly.io/api/v1/ready
```

The deployment script builds an immutable image tagged with the Git commit, starts private dependencies, applies migrations, replaces the API container, checks readiness, and automatically restores the previous API image if verification fails.

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

`POST /api/v1/auth/dev-session` is disabled whenever `NODE_ENV=production`. The public API can be deployed now for infrastructure validation, but authenticated product flows remain intentionally closed until SocketFi supplies a documented production identity assertion and server-verification contract. Do not enable the development session route in production.

## Firewall

Do not blindly enable UFW on an established multi-service VPS. First run `sudo ufw status verbose` and inventory every public port in use. The Paktly containers expose only the API on loopback; PostgreSQL and Redis need no firewall openings. Your existing reverse proxy needs inbound 80/443, and SSH must be allowed before enabling UFW.
