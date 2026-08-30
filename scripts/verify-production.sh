#!/usr/bin/env bash
set -Eeuo pipefail

base_url="${PAKTLY_VERIFY_URL:-http://127.0.0.1:${PAKTLY_HOST_API_PORT:-4000}}"
for attempt in {1..30}; do
  if curl --fail --silent --show-error --max-time 5 "$base_url/api/v1/ready" >/dev/null; then
    echo "Verified $base_url/api/v1/ready"
    exit 0
  fi
  sleep 2
done
echo "Readiness verification failed for $base_url" >&2
exit 1
