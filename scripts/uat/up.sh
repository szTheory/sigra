#!/usr/bin/env bash
# Sigra UAT environment bring-up.
#
# Brings up dockerized Postgres and prepares the test/example Phoenix host app
# (which has Sigra installed via path: "../..") for manual server start.
#
# Walks the user through manual UAT for the 19 human verification items
# tracked in .planning/v1.0-MILESTONE-AUDIT.md § 4a. See scripts/uat/RUNBOOK.md
# for the per-item walkthrough.
#
# Usage:
#   scripts/uat/up.sh           # postgres + deps + migrate + seed + URLs
#   scripts/uat/up.sh --reset   # drop and recreate the database first
#   scripts/uat/up.sh --no-seed # skip demo persona seeding

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
EXAMPLE_DIR="${REPO_ROOT}/test/example"
COMPOSE_FILE="${REPO_ROOT}/scripts/uat/docker-compose.yml"
RESET_DB=0
SEED_DEMO=1

cyan() { printf '\033[36m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }
yellow() { printf '\033[33m%s\033[0m\n' "$*"; }
red() { printf '\033[31m%s\033[0m\n' "$*"; }

slugify() {
  printf '%s' "$1" \
    | tr '[:upper:]' '[:lower:]' \
    | sed -E 's/[^a-z0-9_-]+/-/g; s/^-+//; s/-+$//' \
    | cut -c1-56
}

default_project_name() {
  local branch user slug
  branch="$(git -C "${REPO_ROOT}" rev-parse --abbrev-ref HEAD 2>/dev/null || printf 'local')"
  user="${USER:-$(id -un 2>/dev/null || printf 'dev')}"
  slug="$(slugify "sigra-uat-${user}-${branch}")"
  printf '%s' "${slug:-sigra-uat-local}"
}

find_free_port() {
  elixir -e '
    {:ok, socket} = :gen_tcp.listen(0, [:binary, active: false, ip: {127, 0, 0, 1}])
    {:ok, {_ip, port}} = :inet.sockname(socket)
    :gen_tcp.close(socket)
    IO.write(port)
  '
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --reset)
      RESET_DB=1
      shift
      ;;
    --no-seed)
      SEED_DEMO=0
      shift
      ;;
    --help|-h)
      sed -n '2,18p' "${BASH_SOURCE[0]}"
      exit 0
      ;;
    *)
      red "unknown arg: $1"
      exit 1
      ;;
  esac
done

SIGRA_UAT_PROJECT="${SIGRA_UAT_PROJECT:-${COMPOSE_PROJECT_NAME:-$(default_project_name)}}"

cyan "==> sigra UAT environment bring-up"
cyan "==> Compose project: ${SIGRA_UAT_PROJECT}"

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

SIGRA_EXAMPLE_PORT="${SIGRA_EXAMPLE_PORT:-${PORT:-$(find_free_port)}}"

# 2. Bring up Postgres
cyan "==> Starting Postgres in Docker"
docker compose -p "${SIGRA_UAT_PROJECT}" -f "${COMPOSE_FILE}" up -d

# Wait for postgres healthcheck
cyan "==> Waiting for Postgres to be ready"
for i in {1..30}; do
  if docker compose -p "${SIGRA_UAT_PROJECT}" -f "${COMPOSE_FILE}" exec -T postgres pg_isready -U postgres >/dev/null 2>&1; then
    green "    Postgres is ready"
    break
  fi
  sleep 1
  if [ "$i" -eq 30 ]; then
    red "    Postgres did not become ready within 30s. Check: docker compose -p ${SIGRA_UAT_PROJECT} -f ${COMPOSE_FILE} logs"
    exit 1
  fi
done

PGPORT="$(docker compose -p "${SIGRA_UAT_PROJECT}" -f "${COMPOSE_FILE}" port postgres 5432 | awk -F: 'END {print $NF}')"
if [[ -z "${PGPORT}" ]]; then
  red "Could not discover Postgres host port. Check: docker compose -p ${SIGRA_UAT_PROJECT} -f ${COMPOSE_FILE} ps"
  exit 1
fi

export PGHOST="${PGHOST:-127.0.0.1}"
export PGPORT
export PGUSER="${PGUSER:-postgres}"
export PGPASSWORD="${PGPASSWORD:-postgres}"
export PGDATABASE="${PGDATABASE:-example_dev}"

# 3. Set up the example app
cd "${EXAMPLE_DIR}"

cyan "==> Fetching deps for test/example"
mix deps.get >/dev/null

if [ "${RESET_DB}" -eq 1 ]; then
  yellow "==> --reset requested: dropping database"
  mix ecto.drop --quiet || true
fi

cyan "==> Creating + migrating database"
mix ecto.create --quiet
mix ecto.migrate

if [ "${SEED_DEMO}" -eq 1 ]; then
  cyan "==> Seeding demo personas"
  mix run priv/repo/seeds.exs
else
  yellow "==> --no-seed requested: demo personas were not seeded"
fi

# 4. Print the runbook entrypoints
cat <<EOF

────────────────────────────────────────────────────────────────────
Sigra UAT environment is up.

  App:               http://127.0.0.1:${SIGRA_EXAMPLE_PORT}
  Email mailbox:     http://127.0.0.1:${SIGRA_EXAMPLE_PORT}/dev/mailbox
  Demo doorway:      http://127.0.0.1:${SIGRA_EXAMPLE_PORT}/demo/credentials
  Postgres:          ${PGHOST}:${PGPORT}  (user: ${PGUSER} / pw: ${PGPASSWORD} / db: ${PGDATABASE})
  Compose project:   ${SIGRA_UAT_PROJECT}

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
  cd test/example && PGHOST=${PGHOST} PGPORT=${PGPORT} PGUSER=${PGUSER} PGPASSWORD=${PGPASSWORD} PGDATABASE=${PGDATABASE} PORT=${SIGRA_EXAMPLE_PORT} iex -S mix phx.server
  (leave that running, then walk the runbook in your browser)

Playwright:
  cd test/example/priv/playwright && SIGRA_EXAMPLE_URL=http://127.0.0.1:${SIGRA_EXAMPLE_PORT} npx playwright test

Tear down:
  SIGRA_UAT_PROJECT=${SIGRA_UAT_PROJECT} scripts/uat/down.sh

────────────────────────────────────────────────────────────────────
EOF
