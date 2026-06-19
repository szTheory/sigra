#!/usr/bin/env bash
# Sigra local TEST/DEV Postgres bring-up.
#
# Boots an ephemeral, Sigra-namespaced Postgres in Docker on a DYNAMIC host port
# (never reserves global 5432, never contends with Homebrew or sibling libs),
# discovers the assigned port, and writes tmp/db.env so `mix test` and the
# test/example app find it with zero manual port juggling.
#
# Usage:
#   scripts/db/up.sh              # boot PG, write tmp/db.env, print how to use it
#   scripts/db/up.sh --reset      # recreate the container from scratch (drops data)
#   scripts/db/up.sh --status     # reprint the current connection info
#   scripts/db/up.sh --print-env  # print the export lines (eval-friendly)
#   scripts/db/up.sh --down       # delegate to scripts/db/down.sh
#
# After bring-up, make `mix test` discover the port (pick one):
#   source tmp/db.env && mix test          # current shell
#   direnv allow                           # one-time; auto-loads on every cd
#
# When tmp/db.env is absent (CI, or before this script runs), every reader falls
# back to localhost:5432, so nothing breaks.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
COMPOSE_FILE="${REPO_ROOT}/scripts/db/docker-compose.yml"
STATE_FILE="${REPO_ROOT}/tmp/db.env"

RESET_DB=0
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

# Same derivation as scripts/uat/* (user + branch + repo-path hash) so multiple
# checkouts/branches/worktrees each get their own isolated test-DB container.
default_project_name() {
  local branch user hash slug
  branch="$(git -C "${REPO_ROOT}" rev-parse --abbrev-ref HEAD 2>/dev/null || printf 'local')"
  user="${USER:-$(id -un 2>/dev/null || printf 'dev')}"
  hash="$(printf '%s' "${REPO_ROOT}" | shasum 2>/dev/null | awk '{print substr($1,1,8)}')"
  if [[ -z "${hash}" ]]; then
    hash="$(printf '%s' "${REPO_ROOT}" | cksum | awk '{print $1}')"
  fi
  slug="$(slugify "sigra-db-${user}-${branch}-${hash}")"
  printf '%s' "${slug:-sigra-db-local}"
}

shell_quote() {
  printf "'%s'" "$(printf '%s' "$1" | sed "s/'/'\\\\''/g")"
}

compose() {
  docker compose -p "${SIGRA_DB_PROJECT}" -f "${COMPOSE_FILE}" "$@"
}

wait_for_postgres() {
  cyan "==> Waiting for Postgres to be ready"
  local i
  for i in {1..30}; do
    if compose exec -T postgres pg_isready -U postgres >/dev/null 2>&1; then
      green "    Postgres is ready"
      return
    fi
    sleep 1
  done
  red "    Postgres did not become ready within 30s. Check: docker compose -p ${SIGRA_DB_PROJECT} -f ${COMPOSE_FILE} logs"
  exit 1
}

discover_pg_port() {
  PGPORT="$(compose port postgres 5432 | awk -F: 'END {print $NF}')"
  if [[ -z "${PGPORT}" ]]; then
    red "Could not discover Postgres host port. Check: docker compose -p ${SIGRA_DB_PROJECT} -f ${COMPOSE_FILE} ps"
    exit 1
  fi
}

write_state_file() {
  mkdir -p "$(dirname "${STATE_FILE}")"
  # Export BOTH conventions: SIGRA_TEST_PG_* (library suite via
  # Sigra.Test.PostgresRepo) and PG* (test/example app + install fixtures).
  cat > "${STATE_FILE}" <<EOF
export SIGRA_DB_PROJECT=$(shell_quote "${SIGRA_DB_PROJECT}")
export SIGRA_TEST_PG_HOSTNAME=$(shell_quote "${PGHOST}")
export SIGRA_TEST_PG_PORT=$(shell_quote "${PGPORT}")
export SIGRA_TEST_PG_USERNAME=$(shell_quote "${PGUSER}")
export SIGRA_TEST_PG_PASSWORD=$(shell_quote "${PGPASSWORD}")
export SIGRA_TEST_PG_DATABASE=$(shell_quote "${PGDATABASE}")
export PGHOST=$(shell_quote "${PGHOST}")
export PGPORT=$(shell_quote "${PGPORT}")
export PGUSER=$(shell_quote "${PGUSER}")
export PGPASSWORD=$(shell_quote "${PGPASSWORD}")
export PGDATABASE=$(shell_quote "${PGDATABASE}")
EOF
}

print_status() {
  cat <<EOF

────────────────────────────────────────────────────────────
 Sigra test Postgres ready
────────────────────────────────────────────────────────────
 Host:     ${PGHOST}:${PGPORT}   (user ${PGUSER} / pw ${PGPASSWORD} / db ${PGDATABASE})
 Project:  ${SIGRA_DB_PROJECT}
 Env file: ${STATE_FILE}   (ephemeral — no volume, max_connections=200)

 Make mix test discover it — pick one:
   source tmp/db.env && mix test          # current shell
   direnv allow                           # one-time; auto-loads on every cd

 Tear down:  scripts/db/down.sh   (--purge to also drop the container)
────────────────────────────────────────────────────────────
EOF
}

# ---- arg parsing ----------------------------------------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --reset) RESET_DB=1 ;;
    --status) STATUS_ONLY=1 ;;
    --print-env) PRINT_ENV_ONLY=1 ;;
    --down) exec "${REPO_ROOT}/scripts/db/down.sh" ;;
    -h|--help)
      sed -n '2,30p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) red "Unknown argument: $1"; exit 1 ;;
  esac
  shift
done

SIGRA_DB_PROJECT="${SIGRA_DB_PROJECT:-$(default_project_name)}"

# --status / --print-env just replay the state file without touching Docker.
if [[ "${STATUS_ONLY}" = "1" || "${PRINT_ENV_ONLY}" = "1" ]]; then
  if [[ ! -f "${STATE_FILE}" ]]; then
    red "No test-DB state file at ${STATE_FILE}. Run scripts/db/up.sh first."
    exit 1
  fi
  if [[ "${PRINT_ENV_ONLY}" = "1" ]]; then
    cat "${STATE_FILE}"
    exit 0
  fi
  # shellcheck disable=SC1090
  source "${STATE_FILE}"
  print_status
  exit 0
fi

# ---- preflight ------------------------------------------------------------
if ! command -v docker >/dev/null 2>&1; then
  red "docker not found in PATH. Install Docker Desktop and start it."
  exit 1
fi
if ! docker ps >/dev/null 2>&1; then
  red "Docker daemon not responsive. Start Docker Desktop and wait for the whale icon to settle."
  exit 1
fi

cyan "==> Sigra test Postgres bring-up"
cyan "==> Compose project: ${SIGRA_DB_PROJECT}"

if [[ "${RESET_DB}" = "1" ]]; then
  yellow "==> --reset requested: removing existing container + data"
  compose down -v --remove-orphans >/dev/null 2>&1 || true
fi

cyan "==> Starting Postgres in Docker"
compose up -d postgres

wait_for_postgres
discover_pg_port

PGHOST="127.0.0.1"
PGUSER="postgres"
PGPASSWORD="postgres"
PGDATABASE="sigra_test"

write_state_file
green "==> Wrote test-DB env to ${STATE_FILE}"
print_status
