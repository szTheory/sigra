#!/usr/bin/env bash
# scripts/ci/http-smoke.sh
#
# Curls a list of critical routes against a running test/example app and
# fails if any returns HTTP 5xx. Assumes the app is already booted on
# localhost:4000 (or $HOST).
#
# Used by the example_http_smoke CI job. Locally reproducible:
#     cd test/example && MIX_ENV=dev mix phx.server &
#     sleep 3
#     scripts/ci/http-smoke.sh

set -euo pipefail

HOST="${HOST:-http://localhost:4000}"

ROUTES=(
  "/"
  "/users/register"
  "/users/log_in"
  "/users/sudo"
  "/dev/mailbox"
  "/users/sessions"
)

echo "==> http-smoke: waiting for ${HOST} to respond"
for i in $(seq 1 30); do
  if curl -sf -o /dev/null "${HOST}/"; then
    echo "==> http-smoke: app is up (attempt ${i})"
    break
  fi
  if [[ "${i}" -eq 30 ]]; then
    echo "FAIL: app did not respond within 30 seconds"
    exit 1
  fi
  sleep 1
done

fail=0
for path in "${ROUTES[@]}"; do
  code=$(curl -s -o /dev/null -w "%{http_code}" -L --max-redirs 5 "${HOST}${path}")
  if [[ "${code}" -ge 500 ]]; then
    echo "FAIL: ${path} returned ${code}"
    fail=1
  else
    echo "OK:   ${path} -> ${code}"
  fi
done

if [[ "${fail}" -eq 1 ]]; then
  echo "==> http-smoke: one or more routes returned 5xx; job failed"
  exit 1
fi

echo "==> http-smoke: all ${#ROUTES[@]} routes returned non-5xx"
