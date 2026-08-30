#!/usr/bin/env bash
set -Eeuo pipefail
umask 077

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
compose_file="$repo_root/infrastructure/production/compose.yml"
env_file="${PAKTLY_ENV_FILE:-/opt/paktly/.env}"
backup_directory="${PAKTLY_BACKUP_DIR:-/opt/paktly/backups/postgres}"
retention_days="${PAKTLY_BACKUP_RETENTION_DAYS:-14}"
[[ -f /opt/paktly/current-release ]] || { echo "No deployed release is recorded" >&2; exit 1; }
[[ -f "$env_file" ]] || { echo "Missing production environment file: $env_file" >&2; exit 1; }
release="$(< /opt/paktly/current-release)"
timestamp="$(date -u +'%Y%m%dT%H%M%SZ')"
temporary_file="$backup_directory/.paktly-$timestamp.dump.tmp"
backup_file="$backup_directory/paktly-$timestamp.dump"

mkdir -p "$backup_directory"
export PAKTLY_RELEASE="$release" PAKTLY_ENV_FILE="$env_file"
compose=(docker compose --env-file "$env_file" -f "$compose_file")

"${compose[@]}" exec -T postgres sh -c 'exec pg_dump -U "$POSTGRES_USER" -d "$POSTGRES_DB" --format=custom --no-owner --no-privileges' > "$temporary_file"
[[ -s "$temporary_file" ]] || { echo "Backup is empty" >&2; exit 1; }
mv "$temporary_file" "$backup_file"
sha256sum "$backup_file" > "$backup_file.sha256"
find "$backup_directory" -type f \( -name 'paktly-*.dump' -o -name 'paktly-*.dump.sha256' \) -mtime "+$retention_days" -delete
echo "Created $backup_file"
