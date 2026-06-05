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
#   scripts/uat/up.sh             # postgres + deps + migrate + seed + URLs
#   scripts/uat/up.sh --reset     # drop and recreate the database first
#   scripts/uat/up.sh --no-seed   # skip demo persona seeding
#   scripts/uat/up.sh --status    # reprint URLs/env for the last started stack
#   scripts/uat/up.sh --print-env # print export lines for the last started stack

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
EXAMPLE_DIR="${REPO_ROOT}/test/example"
COMPOSE_FILE="${REPO_ROOT}/scripts/uat/docker-compose.yml"
STATE_FILE="${REPO_ROOT}/tmp/uat.env"
# shellcheck source=scripts/ci/lib/free-port.sh
source "${REPO_ROOT}/scripts/ci/lib/free-port.sh"
RESET_DB=0
SEED_DEMO=1
STATUS_ONLY=0
PRINT_ENV_ONLY=0

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
  local branch user hash slug
  branch="$(git -C "${REPO_ROOT}" rev-parse --abbrev-ref HEAD 2>/dev/null || printf 'local')"
  user="${USER:-$(id -un 2>/dev/null || printf 'dev')}"
  hash="$(printf '%s' "${REPO_ROOT}" | shasum 2>/dev/null | awk '{print substr($1,1,8)}')"
  if [[ -z "${hash}" ]]; then
    hash="$(printf '%s' "${REPO_ROOT}" | cksum | awk '{print $1}')"
  fi
  slug="$(slugify "sigra-uat-${user}-${branch}-${hash}")"
  printf '%s' "${slug:-sigra-uat-local}"
}

shell_quote() {
  printf "'%s'" "$(printf '%s' "$1" | sed "s/'/'\\\\''/g")"
}

write_state_file() {
  mkdir -p "$(dirname "${STATE_FILE}")"
  cat > "${STATE_FILE}" <<EOF
SIGRA_UAT_PROJECT=$(shell_quote "${SIGRA_UAT_PROJECT}")
SIGRA_UAT_COMPOSE_FILE=$(shell_quote "${COMPOSE_FILE}")
PGHOST=$(shell_quote "${PGHOST}")
PGPORT=$(shell_quote "${PGPORT}")
PGUSER=$(shell_quote "${PGUSER}")
PGPASSWORD=$(shell_quote "${PGPASSWORD}")
PGDATABASE=$(shell_quote "${PGDATABASE}")
PORT=$(shell_quote "${SIGRA_EXAMPLE_PORT}")
SIGRA_EXAMPLE_PORT=$(shell_quote "${SIGRA_EXAMPLE_PORT}")
SIGRA_EXAMPLE_URL=$(shell_quote "${SIGRA_EXAMPLE_URL}")
SIGRA_UAT_MAILBOX_URL=$(shell_quote "${SIGRA_UAT_MAILBOX_URL}")
SIGRA_UAT_DEMO_URL=$(shell_quote "${SIGRA_UAT_DEMO_URL}")
SIGRA_UAT_SERVER_COMMAND=$(shell_quote "${SIGRA_UAT_SERVER_COMMAND}")
SIGRA_UAT_PLAYWRIGHT_COMMAND=$(shell_quote "${SIGRA_UAT_PLAYWRIGHT_COMMAND}")
EOF
}

load_state_file() {
  if [[ ! -f "${STATE_FILE}" ]]; then
    red "No UAT state file found at ${STATE_FILE}. Run scripts/uat/up.sh first."
    exit 1
  fi

  # shellcheck disable=SC1090
  source "${STATE_FILE}"
}

print_export_env() {
  load_state_file
  for key in \
    SIGRA_UAT_PROJECT \
    PGHOST \
    PGPORT \
    PGUSER \
    PGPASSWORD \
    PGDATABASE \
    PORT \
    SIGRA_EXAMPLE_PORT \
    SIGRA_EXAMPLE_URL
  do
    printf 'export %s=%s\n' "${key}" "$(shell_quote "${!key:-}")"
  done
}

print_status() {
  load_state_file

  cat <<EOF

--------------------------------------------------------------------
Sigra UAT environment.

  App:               ${SIGRA_EXAMPLE_URL}
  Email mailbox:     ${SIGRA_UAT_MAILBOX_URL}
  Demo doorway:      ${SIGRA_UAT_DEMO_URL}
  Postgres:          ${PGHOST}:${PGPORT}  (user: ${PGUSER} / pw: ${PGPASSWORD} / db: ${PGDATABASE})
  Compose project:   ${SIGRA_UAT_PROJECT}
  State file:        ${STATE_FILE}

Runbook (step-by-step):
  scripts/uat/RUNBOOK.md

Key entry points:
  /users/register      - registration flow (UAT items 04, 05, 06)
  /users/log_in        - login + remember-me (UAT items 04)
  /users/sessions      - active session management (UAT item 04)
  /users/settings      - account settings, email change, password change, delete (UAT item 08)
  /users/settings/mfa  - TOTP enrollment + backup codes (UAT item 06)
  /users/sudo          - sudo re-auth (UAT item 04, 08)
  /users/reactivation  - grace-period reactivation (UAT item 08)

Start the Phoenix server:
  ${SIGRA_UAT_SERVER_COMMAND}
  (leave that running, then walk the runbook in your browser)

Playwright:
  ${SIGRA_UAT_PLAYWRIGHT_COMMAND}

Export env for ad-hoc commands:
  scripts/uat/up.sh --print-env

Tear down:
  scripts/uat/down.sh

--------------------------------------------------------------------
EOF

  if command -v docker >/dev/null 2>&1 && docker ps >/dev/null 2>&1; then
    docker compose -p "${SIGRA_UAT_PROJECT}" -f "${COMPOSE_FILE}" ps
  fi
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
    --status)
      STATUS_ONLY=1
      shift
      ;;
    --print-env)
      PRINT_ENV_ONLY=1
      shift
      ;;
    --help|-h)
      sed -n '2,20p' "${BASH_SOURCE[0]}"
      exit 0
      ;;
    *)
      red "unknown arg: $1"
      exit 1
      ;;
  esac
done

if [ "${PRINT_ENV_ONLY}" -eq 1 ]; then
  print_export_env
  exit 0
fi

if [ "${STATUS_ONLY}" -eq 1 ]; then
  print_status
  exit 0
fi

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
SIGRA_EXAMPLE_URL="http://127.0.0.1:${SIGRA_EXAMPLE_PORT}"
SIGRA_UAT_MAILBOX_URL="${SIGRA_EXAMPLE_URL}/dev/mailbox"
SIGRA_UAT_DEMO_URL="${SIGRA_EXAMPLE_URL}/demo/credentials"

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
SIGRA_UAT_SERVER_COMMAND="cd test/example && PGHOST=${PGHOST} PGPORT=${PGPORT} PGUSER=${PGUSER} PGPASSWORD=${PGPASSWORD} PGDATABASE=${PGDATABASE} PORT=${SIGRA_EXAMPLE_PORT} SIGRA_EXAMPLE_URL=${SIGRA_EXAMPLE_URL} iex -S mix phx.server"
SIGRA_UAT_PLAYWRIGHT_COMMAND="cd test/example/priv/playwright && SIGRA_EXAMPLE_URL=${SIGRA_EXAMPLE_URL} npx playwright test"

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

write_state_file
green "==> Wrote UAT env to ${STATE_FILE}"
print_status
