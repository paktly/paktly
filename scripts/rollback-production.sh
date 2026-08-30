#!/usr/bin/env bash
set -Eeuo pipefail

[[ $# == 1 ]] || { echo "Usage: $0 <release>" >&2; exit 1; }
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
compose_file="$repo_root/infrastructure/production/compose.yml"
env_file="${PAKTLY_ENV_FILE:-/opt/paktly/.env}"
release="$1"

[[ -f "$env_file" ]] || { echo "Missing production environment file: $env_file" >&2; exit 1; }
docker image inspect "paktly-api:$release" >/dev/null
export PAKTLY_RELEASE="$release" PAKTLY_ENV_FILE="$env_file"
docker compose --env-file "$env_file" -f "$compose_file" up -d --no-deps api
"$repo_root/scripts/verify-production.sh"
printf '%s\n' "$release" > /opt/paktly/current-release
echo "Rolled back Paktly API to $release"
