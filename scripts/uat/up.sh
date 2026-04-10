#!/usr/bin/env bash
# Sigra UAT environment bring-up.
#
# Brings up a dockerized Postgres + the test/example/ Phoenix host app
# (which has Sigra installed via path: "../..") and tails the server logs.
#
# Walks the user through manual UAT for the 19 human verification items
# tracked in .planning/v1.0-MILESTONE-AUDIT.md § 4a. See scripts/uat/RUNBOOK.md
# for the per-item walkthrough.
#
# Usage:
#   scripts/uat/up.sh           # full bring-up: postgres + deps + migrate + server
#   scripts/uat/up.sh --reset   # drop and recreate the database first

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
EXAMPLE_DIR="${REPO_ROOT}/test/example"
COMPOSE_FILE="${REPO_ROOT}/scripts/uat/docker-compose.yml"

cyan() { printf '\033[36m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }
yellow() { printf '\033[33m%s\033[0m\n' "$*"; }
red() { printf '\033[31m%s\033[0m\n' "$*"; }

cyan "==> sigra UAT environment bring-up"

# 1. Sanity-check prerequisites
if ! command -v docker >/dev/null 2>&1; then
  red "docker not found in PATH. Install Docker Desktop and start it."
  exit 1
fi

if ! docker ps >/dev/null 2>&1; then
  red "Docker daemon not responsive. Start Docker Desktop and wait for the whale icon in your menu bar to settle."
  exit 1
fi

if ! command -v mix >/dev/null 2>&1; then
  red "mix (Elixir) not found in PATH. Install Elixir 1.18+."
  exit 1
fi

# 2. Bring up Postgres
cyan "==> Starting Postgres in Docker"
docker compose -f "${COMPOSE_FILE}" up -d

# Wait for postgres healthcheck
cyan "==> Waiting for Postgres to be ready"
for i in {1..30}; do
  if docker compose -f "${COMPOSE_FILE}" exec -T postgres pg_isready -U postgres >/dev/null 2>&1; then
    green "    Postgres is ready"
    break
  fi
  sleep 1
  if [ "$i" -eq 30 ]; then
    red "    Postgres did not become ready within 30s. Check: docker compose -f ${COMPOSE_FILE} logs"
    exit 1
  fi
done

# 3. Set up the example app
cd "${EXAMPLE_DIR}"

cyan "==> Fetching deps for test/example"
mix deps.get >/dev/null

if [ "${1:-}" = "--reset" ]; then
  yellow "==> --reset requested: dropping database"
  mix ecto.drop --quiet || true
fi

cyan "==> Creating + migrating database"
mix ecto.create --quiet
mix ecto.migrate

# 4. Print the runbook entrypoints
cat <<'EOF'

────────────────────────────────────────────────────────────────────
Sigra UAT environment is up.

  App:               http://localhost:4000
  Email mailbox:     http://localhost:4000/dev/mailbox
  Postgres:          localhost:5432  (user: postgres / pw: postgres / db: example_dev)

Runbook (step-by-step):
  scripts/uat/RUNBOOK.md

Key entry points:
  /users/register      — registration flow (UAT items 04, 05, 06)
  /users/log_in        — login + remember-me (UAT items 04)
  /users/sessions      — active session management (UAT item 04)
  /users/settings      — account settings, email change, password change, delete (UAT item 08)
  /users/settings/mfa  — TOTP enrollment + backup codes (UAT item 06)
  /users/sudo          — sudo re-auth (UAT item 04, 08)
  /users/reactivation  — grace-period reactivation (UAT item 08)

Tail server logs:
  cd test/example && iex -S mix phx.server
  (leave that running, then walk the runbook in your browser)

Tear down:
  scripts/uat/down.sh

────────────────────────────────────────────────────────────────────
EOF
