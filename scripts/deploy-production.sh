#!/usr/bin/env bash
set -Eeuo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
compose_file="$repo_root/infrastructure/production/compose.yml"
env_file="${PAKTLY_ENV_FILE:-/opt/paktly/.env}"
release="${1:-$(git -C "$repo_root" rev-parse --short=12 HEAD)}"
image_name="paktly-api"
state_directory="/opt/paktly"
current_release_file="$state_directory/current-release"

for command in docker curl git; do command -v "$command" >/dev/null || { echo "$command is required" >&2; exit 1; }; done
[[ -f "$env_file" ]] || { echo "Missing production environment file: $env_file" >&2; exit 1; }
permissions="$(stat -c '%a' "$env_file")"
(( 10#$permissions % 100 == 0 )) || { echo "$env_file must not be group/world accessible (use chmod 600)" >&2; exit 1; }

mkdir -p "$state_directory/backups/postgres"
previous_release=""
[[ -f "$current_release_file" ]] && previous_release="$(<"$current_release_file")"

echo "Building $image_name:$release"
docker build --pull -f "$repo_root/services/api/Dockerfile" -t "$image_name:$release" "$repo_root"

export PAKTLY_RELEASE="$release" PAKTLY_ENV_FILE="$env_file"
compose=(docker compose --env-file "$env_file" -f "$compose_file")

"${compose[@]}" up -d postgres redis
for attempt in {1..30}; do
  if "${compose[@]}" exec -T postgres sh -c 'pg_isready -U "$POSTGRES_USER" -d "$POSTGRES_DB"' >/dev/null 2>&1; then break; fi
  [[ "$attempt" == 30 ]] && { echo "PostgreSQL did not become ready" >&2; exit 1; }
  sleep 2
done

echo "Applying database migrations"
"${compose[@]}" run --rm --no-deps api node scripts/migrate.mjs
"${compose[@]}" up -d --no-deps api
published_endpoint="$("${compose[@]}" port api 4000)"
[[ -n "$published_endpoint" ]] || { echo "Could not determine the published API port" >&2; exit 1; }

if ! PAKTLY_VERIFY_URL="http://$published_endpoint" "$repo_root/scripts/verify-production.sh"; then
  echo "Deployment verification failed" >&2
  if [[ -n "$previous_release" ]] && docker image inspect "$image_name:$previous_release" >/dev/null 2>&1; then
    echo "Rolling back application container to $previous_release"
    export PAKTLY_RELEASE="$previous_release"
    "${compose[@]}" up -d --no-deps api
  fi
  exit 1
fi

printf '%s\n' "$release" > "$current_release_file"
echo "Paktly API release $release is healthy"
