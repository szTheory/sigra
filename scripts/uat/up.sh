#!/usr/bin/env bash
# Sigra UAT environment bring-up.
#
# Brings up dockerized Postgres and prepares the test/example Phoenix host app
# (which has Sigra installed via path: "../..") for manual server start, or
# starts the Dockerized Vaultr example app behind the shared local Traefik proxy.
#
# Walks the user through manual UAT for the 19 human verification items
# tracked in .planning/v1.0-MILESTONE-AUDIT.md § 4a. See scripts/uat/RUNBOOK.md
# for the per-item walkthrough.
#
# Usage:
#   scripts/uat/up.sh                  # postgres + host-run Phoenix URL/env
#   scripts/uat/up.sh --reset          # drop and recreate the database first
#   scripts/uat/up.sh --no-seed        # skip demo persona seeding
#   scripts/uat/up.sh --proxy          # Dockerized app via shared dev_proxy Traefik
#   scripts/uat/up.sh --private-traefik # host-run fallback via private Traefik on :18080
#   scripts/uat/up.sh --status         # reprint URLs/env for the last started stack
#   scripts/uat/up.sh --refresh-code   # recompile the Dockerized Sigra path dependency
#   scripts/uat/up.sh --print-env      # print export lines for the last started stack

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
EXAMPLE_DIR="${REPO_ROOT}/test/example"
COMPOSE_FILE="${REPO_ROOT}/scripts/uat/docker-compose.yml"
STATE_FILE="${REPO_ROOT}/tmp/uat.env"
SHARED_PROXY_UP="${SIGRA_UAT_SHARED_PROXY_UP:-scripts/dev-proxy/up.sh}"
# shellcheck source=scripts/ci/lib/free-port.sh
source "${REPO_ROOT}/scripts/ci/lib/free-port.sh"
RESET_DB=0
SEED_DEMO=1
STATUS_ONLY=0
PRINT_ENV_ONLY=0
REFRESH_CODE_ONLY=0
ENABLE_SHARED_PROXY=0
ENABLE_PRIVATE_TRAEFIK=0

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

shared_proxy_command() {
  local command="${SHARED_PROXY_UP}"

  if [[ "${SIGRA_UAT_PROXY_NETWORK:-proxy}" != "proxy" ]]; then
    command="SIGRA_DEV_PROXY_NETWORK=$(shell_quote "${SIGRA_UAT_PROXY_NETWORK}") ${command}"
  fi

  printf '%s' "${command}"
}

write_state_file() {
  mkdir -p "$(dirname "${STATE_FILE}")"
  cat > "${STATE_FILE}" <<EOF
SIGRA_UAT_PROJECT=$(shell_quote "${SIGRA_UAT_PROJECT}")
SIGRA_UAT_COMPOSE_FILE=$(shell_quote "${COMPOSE_FILE}")
SIGRA_UAT_PROXY_MODE=$(shell_quote "${SIGRA_UAT_PROXY_MODE:-none}")
SIGRA_UAT_PROXY_ENABLED=$(shell_quote "${SIGRA_UAT_PROXY_ENABLED:-0}")
SIGRA_UAT_PROXY_HOST=$(shell_quote "${SIGRA_UAT_PROXY_HOST:-}")
SIGRA_UAT_PROXY_NETWORK=$(shell_quote "${SIGRA_UAT_PROXY_NETWORK:-}")
SIGRA_UAT_PROXY_ROUTER=$(shell_quote "${SIGRA_UAT_PROXY_ROUTER:-}")
SIGRA_UAT_PROXY_PORT=$(shell_quote "${SIGRA_UAT_PROXY_PORT:-}")
SIGRA_UAT_PROXY_URL=$(shell_quote "${SIGRA_UAT_PROXY_URL:-}")
SIGRA_UAT_RAW_URL=$(shell_quote "${SIGRA_UAT_RAW_URL:-${SIGRA_EXAMPLE_URL}}")
SIGRA_UAT_WEB_HOST_PORT=$(shell_quote "${SIGRA_UAT_WEB_HOST_PORT:-}")
SIGRA_UAT_TRAEFIK_IMAGE=$(shell_quote "${SIGRA_UAT_TRAEFIK_IMAGE:-}")
SIGRA_UAT_TRAEFIK_DYNAMIC_DIR=$(shell_quote "${SIGRA_UAT_TRAEFIK_DYNAMIC_DIR:-}")
SIGRA_UAT_SHARED_PROXY_UP=$(shell_quote "${SHARED_PROXY_UP}")
PGHOST=$(shell_quote "${PGHOST}")
PGPORT=$(shell_quote "${PGPORT}")
PGUSER=$(shell_quote "${PGUSER}")
PGPASSWORD=$(shell_quote "${PGPASSWORD}")
PGDATABASE=$(shell_quote "${PGDATABASE}")
PORT=$(shell_quote "${SIGRA_EXAMPLE_PORT}")
SIGRA_EXAMPLE_PORT=$(shell_quote "${SIGRA_EXAMPLE_PORT}")
SIGRA_EXAMPLE_BIND=$(shell_quote "${SIGRA_EXAMPLE_BIND}")
SIGRA_EXAMPLE_URL=$(shell_quote "${SIGRA_EXAMPLE_URL}")
SIGRA_UAT_MAILBOX_URL=$(shell_quote "${SIGRA_UAT_MAILBOX_URL}")
SIGRA_UAT_DEMO_URL=$(shell_quote "${SIGRA_UAT_DEMO_URL}")
SIGRA_UAT_SERVER_COMMAND=$(shell_quote "${SIGRA_UAT_SERVER_COMMAND}")
SIGRA_UAT_PLAYWRIGHT_COMMAND=$(shell_quote "${SIGRA_UAT_PLAYWRIGHT_COMMAND}")
SIGRA_UAT_SHARED_PROXY_COMMAND=$(shell_quote "$(shared_proxy_command)")
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
    SIGRA_UAT_PROXY_MODE \
    SIGRA_UAT_PROXY_ENABLED \
    SIGRA_UAT_PROXY_HOST \
    SIGRA_UAT_PROXY_NETWORK \
    SIGRA_UAT_PROXY_ROUTER \
    SIGRA_UAT_PROXY_PORT \
    SIGRA_UAT_PROXY_URL \
    SIGRA_UAT_RAW_URL \
    SIGRA_UAT_WEB_HOST_PORT \
    SIGRA_UAT_TRAEFIK_IMAGE \
    SIGRA_UAT_TRAEFIK_DYNAMIC_DIR \
    SIGRA_UAT_SHARED_PROXY_UP \
    PGHOST \
    PGPORT \
    PGUSER \
    PGPASSWORD \
    PGDATABASE \
    PORT \
    SIGRA_EXAMPLE_PORT \
    SIGRA_EXAMPLE_BIND \
    SIGRA_EXAMPLE_URL
  do
    printf 'export %s=%s\n' "${key}" "$(shell_quote "${!key:-}")"
  done
}

print_status() {
  load_state_file
  local compose_file="${SIGRA_UAT_COMPOSE_FILE:-${COMPOSE_FILE}}"
  local proxy_status_lines=""
  local server_lines="Start the Phoenix server:"
  local server_note="  ${SIGRA_UAT_SERVER_COMMAND}
  (leave that running, then walk the runbook in your browser)"

  case "${SIGRA_UAT_PROXY_MODE:-none}" in
    shared)
      proxy_status_lines="  Raw app fallback:  ${SIGRA_UAT_RAW_URL}
  Proxy:            shared dev_proxy Traefik at ${SIGRA_UAT_PROXY_URL} -> Docker service web:4000
  Proxy network:    ${SIGRA_UAT_PROXY_NETWORK}"
      server_lines="Phoenix server:"
      server_note="  Running in Docker service 'web'.
  Logs: ${SIGRA_UAT_SERVER_COMMAND}"
      ;;
    private-traefik)
      proxy_status_lines="  Raw app fallback:  ${SIGRA_UAT_RAW_URL}
  Proxy:            private fallback Traefik at ${SIGRA_UAT_PROXY_URL} -> host Phoenix port ${SIGRA_EXAMPLE_PORT}"
      ;;
  esac

  cat <<EOF

--------------------------------------------------------------------
Sigra UAT environment.

  App:               ${SIGRA_EXAMPLE_URL}
${proxy_status_lines}
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

${server_lines}
${server_note}

Playwright:
  ${SIGRA_UAT_PLAYWRIGHT_COMMAND}

Export env for ad-hoc commands:
  scripts/uat/up.sh --print-env

Tear down:
  scripts/uat/down.sh

--------------------------------------------------------------------
EOF

  if command -v docker >/dev/null 2>&1 && docker ps >/dev/null 2>&1; then
    warn_on_proxy_host_conflict
    docker compose -p "${SIGRA_UAT_PROJECT}" -f "${compose_file}" --profile proxy --profile private-traefik ps
  fi
}

proxy_host_claimants() {
  local host="$1"

  docker ps \
    --filter "label=dev.sigra.stack=uat" \
    --filter "label=dev.sigra.role=demo-web" \
    --filter "label=dev.sigra.proxy-host=${host}" \
    --format '{{.Names}}\t{{.Label "com.docker.compose.project"}}\t{{.Status}}'
}

proxy_host_conflicts() {
  local claimants

  claimants="$(proxy_host_claimants "${SIGRA_UAT_PROXY_HOST}" || true)"
  printf '%s\n' "${claimants}" | awk -F '\t' -v project="${SIGRA_UAT_PROJECT}" 'NF && $2 != project {print $0}'
}

warn_on_proxy_host_conflict() {
  local conflicts

  conflicts="$(proxy_host_conflicts)"
  if [[ -z "${conflicts}" ]]; then
    return
  fi

  yellow "    Warning: other running Sigra UAT web services also claim ${SIGRA_UAT_PROXY_HOST}:"
  printf '%s\n' "${conflicts}" | sed 's/^/      /'
}

fail_on_proxy_host_conflict() {
  local conflicts

  conflicts="$(proxy_host_conflicts)"

  if [[ -z "${conflicts}" ]]; then
    return
  fi

  red "Another running Sigra UAT web service already claims ${SIGRA_UAT_PROXY_HOST}:"
  printf '%s\n' "${conflicts}" | sed 's/^/  /'
  red "Stop the other stack or choose a different SIGRA_UAT_PROXY_HOST before starting --proxy."
  exit 1
}

refresh_proxy_code() {
  load_state_file

  if [[ "${SIGRA_UAT_PROXY_MODE:-none}" != "shared" ]]; then
    red "The last UAT stack was not started with --proxy; --refresh-code only applies to the Dockerized shared-proxy app."
    exit 1
  fi

  local compose_file="${SIGRA_UAT_COMPOSE_FILE:-${COMPOSE_FILE}}"

  fail_on_proxy_host_conflict

  cyan "==> Recompiling Sigra path dependency for ${SIGRA_UAT_PROJECT}"
  docker compose -p "${SIGRA_UAT_PROJECT}" -f "${compose_file}" --profile proxy run --rm --no-deps web sh -lc \
    "mix deps.get && mix deps.compile sigra --force && mix compile --force"

  cyan "==> Restarting Dockerized Vaultr example app"
  docker compose -p "${SIGRA_UAT_PROJECT}" -f "${compose_file}" --profile proxy restart web

  green "==> Refreshed Dockerized Sigra code for ${SIGRA_UAT_PROXY_URL}"
  print_status
}

port_80_owners() {
  docker ps --format '{{.Names}}\t{{.Ports}}' |
    awk -F '\t' '$2 ~ /(^|, )((127\.0\.0\.1|0\.0\.0\.0):80|\[::\]:80)->80\/tcp/ {print $0}'
}

traefik_containers_on_proxy() {
  local network="$1"
  docker network inspect "${network}" --format '{{range .Containers}}{{printf "%s\n" .Name}}{{end}}' 2>/dev/null |
    awk 'tolower($0) ~ /traefik/ {print $0}'
}

warn_about_port_80_owner() {
  local owners
  owners="$(port_80_owners || true)"
  if [[ -z "${owners}" ]]; then
    yellow "    Warning: no container currently owns 127.0.0.1:80. Start the shared proxy for ${SIGRA_UAT_PROXY_HOST}."
    yellow "    $(shared_proxy_command)"
    return
  fi

  if ! printf '%s\n' "${owners}" | awk -F '\t' '{print $1}' | grep -qx 'dev_proxy-traefik-1'; then
    yellow "    Warning: 127.0.0.1:80 is not owned by dev_proxy-traefik-1:"
    printf '%s\n' "${owners}" | sed 's/^/      /'
    yellow "    Sigra will not start a port-80 Traefik. Start or restore the shared proxy when ready:"
    yellow "    $(shared_proxy_command)"
  fi
}

warn_about_shared_proxy() {
  local network="${SIGRA_UAT_PROXY_NETWORK}"
  if ! docker network inspect "${network}" >/dev/null 2>&1; then
    red "Shared proxy network '${network}' does not exist."
    red "Create and start the shared proxy first:"
    red "  $(shared_proxy_command)"
    exit 1
  fi

  local traefik_names
  traefik_names="$(traefik_containers_on_proxy "${network}" || true)"
  if [[ -z "${traefik_names}" ]]; then
    yellow "    Warning: no running Traefik container is attached to Docker network '${network}'."
    yellow "    ${SIGRA_UAT_PROXY_URL} will route only after the shared proxy is running:"
    yellow "    $(shared_proxy_command)"
  fi

  warn_about_port_80_owner
}

write_private_traefik_config() {
  mkdir -p "${SIGRA_UAT_TRAEFIK_DYNAMIC_DIR}"
  cat > "${SIGRA_UAT_TRAEFIK_DYNAMIC_DIR}/sigra-example.yml" <<EOF
http:
  routers:
    sigra-example:
      rule: "Host(\`${SIGRA_UAT_PROXY_HOST}\`)"
      entryPoints:
        - web
      service: sigra-example
  services:
    sigra-example:
      loadBalancer:
        servers:
          - url: "http://host.docker.internal:${SIGRA_EXAMPLE_PORT}"
EOF
}

wait_for_postgres() {
  cyan "==> Waiting for Postgres to be ready"
  for i in {1..30}; do
    if docker compose -p "${SIGRA_UAT_PROJECT}" -f "${COMPOSE_FILE}" exec -T postgres pg_isready -U postgres >/dev/null 2>&1; then
      green "    Postgres is ready"
      return
    fi
    sleep 1
  done

  red "    Postgres did not become ready within 30s. Check: docker compose -p ${SIGRA_UAT_PROJECT} -f ${COMPOSE_FILE} logs"
  exit 1
}

discover_pg_port() {
  PGPORT="$(docker compose -p "${SIGRA_UAT_PROJECT}" -f "${COMPOSE_FILE}" port postgres 5432 | awk -F: 'END {print $NF}')"
  if [[ -z "${PGPORT}" ]]; then
    red "Could not discover Postgres host port. Check: docker compose -p ${SIGRA_UAT_PROJECT} -f ${COMPOSE_FILE} ps"
    exit 1
  fi
}

setup_host_example() {
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
}

setup_docker_example() {
  cyan "==> Preparing Dockerized Vaultr example app"
  docker compose -p "${SIGRA_UAT_PROJECT}" -f "${COMPOSE_FILE}" --profile proxy stop web >/dev/null 2>&1 || true
  docker compose -p "${SIGRA_UAT_PROJECT}" -f "${COMPOSE_FILE}" --profile proxy build web

  local setup_script
  setup_script="set -e
mix deps.get
mix deps.compile sigra --force
if [ '${RESET_DB}' = '1' ]; then
  mix ecto.drop --quiet || true
fi
mix ecto.create --quiet
mix ecto.migrate
if [ '${SEED_DEMO}' = '1' ]; then
  mix run priv/repo/seeds.exs
fi"

  docker compose -p "${SIGRA_UAT_PROJECT}" -f "${COMPOSE_FILE}" --profile proxy run --rm web sh -lc "${setup_script}"

  if [ "${SEED_DEMO}" -ne 1 ]; then
    yellow "==> --no-seed requested: demo personas were not seeded"
  fi

  cyan "==> Starting Dockerized Vaultr example app"
  docker compose -p "${SIGRA_UAT_PROJECT}" -f "${COMPOSE_FILE}" --profile proxy up -d web

  SIGRA_UAT_WEB_HOST_PORT="$(docker compose -p "${SIGRA_UAT_PROJECT}" -f "${COMPOSE_FILE}" port web 4000 | awk -F: 'END {print $NF}')"
  if [[ -n "${SIGRA_UAT_WEB_HOST_PORT}" ]]; then
    SIGRA_UAT_RAW_URL="http://127.0.0.1:${SIGRA_UAT_WEB_HOST_PORT}"
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
    --proxy)
      ENABLE_SHARED_PROXY=1
      shift
      ;;
    --private-traefik)
      ENABLE_PRIVATE_TRAEFIK=1
      shift
      ;;
    --status)
      STATUS_ONLY=1
      shift
      ;;
    --refresh-code)
      REFRESH_CODE_ONLY=1
      shift
      ;;
    --print-env)
      PRINT_ENV_ONLY=1
      shift
      ;;
    --help|-h)
      sed -n '2,22p' "${BASH_SOURCE[0]}"
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

if [ "${REFRESH_CODE_ONLY}" -eq 1 ]; then
  refresh_proxy_code
  exit 0
fi

if [ "${STATUS_ONLY}" -eq 1 ]; then
  print_status
  exit 0
fi

if [[ "${ENABLE_SHARED_PROXY}" = "1" && "${ENABLE_PRIVATE_TRAEFIK}" = "1" ]]; then
  red "--proxy and --private-traefik are mutually exclusive."
  exit 1
fi

SIGRA_UAT_PROJECT="${SIGRA_UAT_PROJECT:-${COMPOSE_PROJECT_NAME:-$(default_project_name)}}"
SIGRA_UAT_PROXY_HOST="${SIGRA_UAT_PROXY_HOST:-sigra.localhost}"
SIGRA_UAT_PROXY_NETWORK="${SIGRA_UAT_PROXY_NETWORK:-proxy}"
SIGRA_UAT_PROXY_ROUTER="${SIGRA_UAT_PROXY_ROUTER:-$(slugify "${SIGRA_UAT_PROJECT}")}"
SIGRA_UAT_TRAEFIK_IMAGE="${SIGRA_UAT_TRAEFIK_IMAGE:-traefik:v3.7.1}"
SIGRA_UAT_TRAEFIK_DYNAMIC_DIR="${SIGRA_UAT_TRAEFIK_DYNAMIC_DIR:-${REPO_ROOT}/tmp/uat-traefik}"

if [[ "${ENABLE_SHARED_PROXY}" = "1" ]]; then
  SIGRA_UAT_PROXY_MODE="shared"
elif [[ "${ENABLE_PRIVATE_TRAEFIK}" = "1" ]]; then
  SIGRA_UAT_PROXY_MODE="private-traefik"
else
  SIGRA_UAT_PROXY_MODE="none"
fi
SIGRA_UAT_PROXY_ENABLED=0

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

if [[ "${SIGRA_UAT_PROXY_MODE}" != "shared" ]] && ! command -v mix >/dev/null 2>&1; then
  red "mix (Elixir) not found in PATH. Install Elixir 1.19+."
  exit 1
fi

case "${SIGRA_UAT_PROXY_MODE}" in
  shared)
    SIGRA_UAT_PROXY_ENABLED=1
    SIGRA_UAT_PROXY_PORT=80
    SIGRA_UAT_PROXY_URL="http://${SIGRA_UAT_PROXY_HOST}"
    SIGRA_EXAMPLE_URL="${SIGRA_UAT_PROXY_URL}"
    SIGRA_EXAMPLE_PORT=4000
    SIGRA_EXAMPLE_BIND="0.0.0.0"
    SIGRA_UAT_RAW_URL=""
    warn_about_shared_proxy
    fail_on_proxy_host_conflict
    ;;
  private-traefik)
    SIGRA_UAT_PROXY_ENABLED=1
    SIGRA_UAT_PROXY_PORT="${SIGRA_UAT_PROXY_PORT:-18080}"
    if [[ "${SIGRA_UAT_PROXY_PORT}" = "80" ]]; then
      red "Project-private Traefik is not allowed to bind 127.0.0.1:80. Use --proxy for shared dev_proxy routing or choose a nonstandard SIGRA_UAT_PROXY_PORT."
      exit 1
    fi
    SIGRA_EXAMPLE_PORT="${SIGRA_EXAMPLE_PORT:-${PORT:-$(find_free_port)}}"
    SIGRA_UAT_RAW_URL="http://127.0.0.1:${SIGRA_EXAMPLE_PORT}"
    SIGRA_UAT_PROXY_URL="http://${SIGRA_UAT_PROXY_HOST}:${SIGRA_UAT_PROXY_PORT}"
    SIGRA_EXAMPLE_URL="${SIGRA_UAT_PROXY_URL}"
    SIGRA_EXAMPLE_BIND="0.0.0.0"
    ;;
  none)
    SIGRA_EXAMPLE_PORT="${SIGRA_EXAMPLE_PORT:-${PORT:-$(find_free_port)}}"
    SIGRA_UAT_RAW_URL="http://127.0.0.1:${SIGRA_EXAMPLE_PORT}"
    SIGRA_UAT_PROXY_PORT=""
    SIGRA_UAT_PROXY_URL=""
    SIGRA_EXAMPLE_URL="${SIGRA_UAT_RAW_URL}"
    SIGRA_EXAMPLE_BIND="${SIGRA_EXAMPLE_BIND:-127.0.0.1}"
    ;;
esac

SIGRA_UAT_MAILBOX_URL="${SIGRA_EXAMPLE_URL}/dev/mailbox"
SIGRA_UAT_DEMO_URL="${SIGRA_EXAMPLE_URL}/demo/credentials"

export SIGRA_UAT_PROXY_HOST
export SIGRA_UAT_PROXY_NETWORK
export SIGRA_UAT_PROXY_ROUTER
export SIGRA_UAT_PROXY_BIND="${SIGRA_UAT_PROXY_BIND:-127.0.0.1}"
export SIGRA_UAT_PROXY_PORT
export SIGRA_UAT_TRAEFIK_IMAGE
export SIGRA_UAT_TRAEFIK_DYNAMIC_DIR
export SIGRA_UAT_WEB_BIND="${SIGRA_UAT_WEB_BIND:-127.0.0.1}"
export SIGRA_UAT_WEB_PORT="${SIGRA_UAT_WEB_PORT:-}"

# 2. Bring up Docker services.
cyan "==> Starting Postgres in Docker"
case "${SIGRA_UAT_PROXY_MODE}" in
  private-traefik)
    write_private_traefik_config
    docker compose -p "${SIGRA_UAT_PROJECT}" -f "${COMPOSE_FILE}" --profile private-traefik up -d postgres traefik
    ;;
  *)
    docker compose -p "${SIGRA_UAT_PROJECT}" -f "${COMPOSE_FILE}" up -d postgres
    ;;
esac

wait_for_postgres
discover_pg_port

export PGHOST="${PGHOST:-127.0.0.1}"
export PGPORT
export PGUSER="${PGUSER:-postgres}"
export PGPASSWORD="${PGPASSWORD:-postgres}"
export PGDATABASE="${PGDATABASE:-example_dev}"
export PORT="${SIGRA_EXAMPLE_PORT}"
export SIGRA_EXAMPLE_BIND
export SIGRA_EXAMPLE_URL

if [[ "${SIGRA_UAT_PROXY_MODE}" = "shared" ]]; then
  setup_docker_example
  SIGRA_UAT_MAILBOX_URL="${SIGRA_EXAMPLE_URL}/dev/mailbox"
  SIGRA_UAT_DEMO_URL="${SIGRA_EXAMPLE_URL}/demo/credentials"
  SIGRA_UAT_SERVER_COMMAND="docker compose -p ${SIGRA_UAT_PROJECT} -f ${COMPOSE_FILE} --profile proxy logs -f web"
else
  SIGRA_UAT_SERVER_COMMAND="cd test/example && PGHOST=${PGHOST} PGPORT=${PGPORT} PGUSER=${PGUSER} PGPASSWORD=${PGPASSWORD} PGDATABASE=${PGDATABASE} PORT=${SIGRA_EXAMPLE_PORT} SIGRA_EXAMPLE_BIND=${SIGRA_EXAMPLE_BIND} SIGRA_EXAMPLE_URL=${SIGRA_EXAMPLE_URL} iex -S mix phx.server"
  setup_host_example
fi

SIGRA_UAT_PLAYWRIGHT_COMMAND="cd test/example/priv/playwright && SIGRA_EXAMPLE_URL=${SIGRA_EXAMPLE_URL} npx playwright test"

write_state_file
green "==> Wrote UAT env to ${STATE_FILE}"
print_status
