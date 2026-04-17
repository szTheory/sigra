#!/usr/bin/env bash
# scripts/ci/http-smoke.sh
#
# Curls a list of critical routes against a running test/example app and
# fails if any returns HTTP 5xx. Assumes the app is already booted on
# localhost:4000 (or $HOST).
#
# Phase 31 D-08/D-09/D-12/D-16: this smoke exists to prove runtime wiring
# seams ExUnit cannot see (real boot, route reachability, cookie/session
# continuity across real HTTP, and a few admin-critical denial/success
# responses). It stays intentionally narrow. Broad authorization matrices,
# rich LiveView interaction, and presentation assertions belong in ExUnit
# or Playwright per D-13/D-18.
#
# Used by the example_http_smoke CI job. Locally reproducible:
#     cd test/example && MIX_ENV=dev mix phx.server &
#     sleep 3
#     scripts/ci/http-smoke.sh

set -euo pipefail

HOST="${HOST:-http://localhost:4000}"
COOKIE_JAR="${COOKIE_JAR:-$(mktemp -t sigra-http-smoke-cookies.XXXXXX)}"
cleanup_cookie_jar() {
  rm -f "${COOKIE_JAR}" 2>/dev/null || true
}
trap cleanup_cookie_jar EXIT

# Routes that MUST render (non-5xx) for an unauthenticated caller. These
# anchor real boot + public route reachability without asserting content.
PUBLIC_ROUTES=(
  "/"
  "/users/register"
  "/users/log_in"
  "/users/sudo"
  "/dev/mailbox"
  "/users/sessions"
)

# Admin-critical routes that MUST be reachable (non-5xx) for an
# unauthenticated caller. The Phase 31 boundary (D-12/D-13) keeps
# authorization policy truth in ExUnit; this layer only proves that the
# routes are mounted, reachable, and do not 500.
ADMIN_ROUTES_UNAUTH=(
  "/admin"
  "/admin/users"
  "/admin/audit"
  "/admin/audit/export.csv"
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

check_non_5xx() {
  local path="$1"
  local code
  code=$(curl -s -o /dev/null -w "%{http_code}" -L --max-redirs 5 "${HOST}${path}")
  if [[ "${code}" -ge 500 ]]; then
    echo "FAIL: ${path} returned ${code}"
    fail=1
  else
    echo "OK:   ${path} -> ${code}"
  fi
}

for path in "${PUBLIC_ROUTES[@]}"; do
  check_non_5xx "${path}"
done

for path in "${ADMIN_ROUTES_UNAUTH[@]}"; do
  check_non_5xx "${path}"
done

# --- Cookie/session continuity probe ---------------------------------------
# Prove that a single curl session can hit the login page, receive a
# session cookie, and reuse it on a follow-up request without the app
# returning 5xx. This catches real-HTTP wiring regressions (session
# plug order, cookie attributes, CSRF token generation) that cannot be
# seen from ExUnit alone.
echo "==> http-smoke: probing session-cookie continuity"

first_code=$(curl -s -o /dev/null -w "%{http_code}" \
  -c "${COOKIE_JAR}" -L --max-redirs 5 "${HOST}/users/log_in")
if [[ "${first_code}" -ge 500 ]]; then
  echo "FAIL: initial cookie-jar fetch returned ${first_code}"
  fail=1
else
  echo "OK:   cookie-jar warmup /users/log_in -> ${first_code}"
fi

if [[ ! -s "${COOKIE_JAR}" ]]; then
  echo "FAIL: session cookie was not set on /users/log_in"
  fail=1
else
  echo "OK:   session cookie present in jar"
fi

second_code=$(curl -s -o /dev/null -w "%{http_code}" \
  -b "${COOKIE_JAR}" -c "${COOKIE_JAR}" -L --max-redirs 5 "${HOST}/")
if [[ "${second_code}" -ge 500 ]]; then
  echo "FAIL: cookie reuse GET / returned ${second_code}"
  fail=1
else
  echo "OK:   cookie reuse GET / -> ${second_code}"
fi

# --- Admin denial semantic probe -------------------------------------------
# Per D-08/D-12/D-13, assert one explicit admin denial case through real
# HTTP so the thin smoke notices if the admin pipeline is wired such that
# public callers could ever reach a 200 on a global admin LiveView. The
# full denial matrix stays in ExUnit.
echo "==> http-smoke: probing unauthenticated /admin denial semantics"
denial_code=$(curl -s -o /dev/null -w "%{http_code}" "${HOST}/admin")
if [[ "${denial_code}" == "200" ]]; then
  echo "FAIL: /admin returned 200 without authentication; admin pipeline is misrouted"
  fail=1
else
  echo "OK:   /admin (unauthenticated, no redirects) -> ${denial_code}"
fi

if [[ "${fail}" -eq 1 ]]; then
  echo "==> http-smoke: one or more runtime seam checks failed; job failed"
  exit 1
fi

total_checks=$(( ${#PUBLIC_ROUTES[@]} + ${#ADMIN_ROUTES_UNAUTH[@]} + 4 ))
echo "==> http-smoke: all ${total_checks} runtime seam checks passed"
