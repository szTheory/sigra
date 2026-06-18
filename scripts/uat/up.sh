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
# shellcheck source=scripts/uat/lib/naming.sh
source "${REPO_ROOT}/scripts/uat/lib/naming.sh"
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

# slugify / default_project_name / default_proxy_host / alias_proxy_host /
# is_default_branch are provided by scripts/uat/lib/naming.sh (sourced above).

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
SIGRA_UAT_ALIAS_HOST=$(shell_quote "${SIGRA_UAT_ALIAS_HOST:-}")
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
    SIGRA_UAT_ALIAS_HOST \
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
  local base="${SIGRA_EXAMPLE_URL}"

  # Optional alias + raw-fallback lines, shown only when meaningful.
  local alias_line="" raw_line="" server_line=""
  case "${SIGRA_UAT_PROXY_MODE:-none}" in
    shared)
      if [[ -n "${SIGRA_UAT_ALIAS_HOST:-}" && "${SIGRA_UAT_ALIAS_HOST}" != "${SIGRA_UAT_PROXY_HOST}" ]]; then
        alias_line=" ALIAS         http://${SIGRA_UAT_ALIAS_HOST}            (primary checkout)"
      fi
      raw_line=" RAW FALLBACK  ${SIGRA_UAT_RAW_URL}            (use in Firefox/Safari/curl — they don't resolve *.localhost)"
      server_line=" Logs          ${SIGRA_UAT_SERVER_COMMAND}"
      ;;
    private-traefik)
      raw_line=" RAW FALLBACK  ${SIGRA_UAT_RAW_URL}            (host Phoenix port ${SIGRA_EXAMPLE_PORT})"
      server_line=" Server        ${SIGRA_UAT_SERVER_COMMAND}"
      ;;
    *)
      server_line=" Server        ${SIGRA_UAT_SERVER_COMMAND}"
      ;;
  esac

  cat <<EOF

────────────────────────────────────────────────────────────
 Sigra UAT  ·  project: ${SIGRA_UAT_PROJECT}
────────────────────────────────────────────────────────────

 PRIMARY URL   ${base}
${alias_line:+${alias_line}
}${raw_line:+${raw_line}
}
 AUTH ROUTES   (copy-paste)
   Register    ${base}/users/register
   Log in      ${base}/users/log_in
   Sessions    ${base}/users/sessions
   Settings    ${base}/users/settings
   MFA / TOTP  ${base}/users/settings/mfa
   Sudo        ${base}/users/sudo
   Reactivate  ${base}/users/reactivation

 OPS
   Mailbox     ${SIGRA_UAT_MAILBOX_URL}
   Demo creds  ${SIGRA_UAT_DEMO_URL}
   Postgres    ${PGHOST}:${PGPORT}  (user ${PGUSER} / pw ${PGPASSWORD} / db ${PGDATABASE})

 COMMANDS  (copy-paste)
${server_line}
   Playwright  ${SIGRA_UAT_PLAYWRIGHT_COMMAND}
   Env         scripts/uat/up.sh --print-env
   Runbook     scripts/uat/RUNBOOK.md
   Teardown    scripts/uat/down.sh
────────────────────────────────────────────────────────────
EOF

  if command -v docker >/dev/null 2>&1 && docker ps >/dev/null 2>&1; then
    warn_on_proxy_host_conflict
    docker compose -p "${SIGRA_UAT_PROJECT}" -f "${compose_file}" --profile proxy --profile private-traefik ps
  fi
}

proxy_host_claimants() {
  local host="$1"

  # Union the vendor-neutral dev.local.proxy-host (so we also see sibling libs
  # that adopt the same etiquette) AND the legacy dev.sigra.proxy-host (so we
  # still see older/other Sigra UAT containers that predate the neutral label).
  # --filter is AND within a query, so run one query per label and dedupe.
  {
    docker ps \
      --filter "label=dev.local.proxy-host=${host}" \
      --format '{{.Names}}\t{{.Label "com.docker.compose.project"}}\t{{.Status}}'
    docker ps \
      --filter "label=dev.sigra.proxy-host=${host}" \
      --format '{{.Names}}\t{{.Label "com.docker.compose.project"}}\t{{.Status}}'
  } | awk 'NF && !seen[$0]++'
}

# True when a DIFFERENT compose project currently claims the friendly alias host.
alias_claimed_by_other() {
  local claimants
  claimants="$(proxy_host_claimants "$(alias_proxy_host)" 2>/dev/null || true)"
  printf '%s\n' "${claimants}" \
    | awk -F '\t' -v project="${SIGRA_UAT_PROJECT}" 'NF && $2 != project {found=1} END{exit found?0:1}'
}

# Bring up the shared dev_proxy Traefik if it isn't already serving :80.
# Idempotent and sibling-safe: if a NON-dev_proxy container already owns :80
# (e.g. another project's Traefik on the proxy network), leave it alone — any
# Traefik on the proxy network routes Sigra's labels. Opt out with
# SIGRA_UAT_AUTO_PROXY=0.
ensure_shared_proxy() {
  [[ "${SIGRA_UAT_AUTO_PROXY:-1}" = "1" ]] || return 0

  local owners expected
  owners="$(port_80_owners || true)"
  expected="dev_proxy-traefik-1"

  if [[ -n "${owners}" ]]; then
    if printf '%s\n' "${owners}" | awk '{print $1}' | grep -qx "${expected}"; then
      return 0  # shared proxy already running — no-op
    fi
    yellow "    Note: 127.0.0.1:80 is owned by another container (not dev_proxy):"
    printf '%s\n' "${owners}" | sed 's/^/      /'
    yellow "    Leaving it as-is; any Traefik on the '${SIGRA_UAT_PROXY_NETWORK}' network will route Sigra's labels."
    return 0
  fi

  cyan "==> Starting shared dev_proxy Traefik (auto; set SIGRA_UAT_AUTO_PROXY=0 to skip)"
  local proxy_up="${SHARED_PROXY_UP}"
  [[ "${proxy_up}" = /* ]] || proxy_up="${REPO_ROOT}/${proxy_up}"
  if [[ "${SIGRA_UAT_PROXY_NETWORK}" != "proxy" ]]; then
    SIGRA_DEV_PROXY_NETWORK="${SIGRA_UAT_PROXY_NETWORK}" "${proxy_up}" || \
      yellow "    Warning: shared proxy bring-up failed; ${SIGRA_UAT_PROXY_URL} will route once it is up."
  else
    "${proxy_up}" || \
      yellow "    Warning: shared proxy bring-up failed; ${SIGRA_UAT_PROXY_URL} will route once it is up."
  fi
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

  # Cache-aware rebuild: Dockerfile.example layers recompile sigra only if lib/priv
  # changed and the example only if its source changed — deps are never re-fetched
  # for a source/style edit. Replaces the old unconditional deps.get + --force recompiles.
  cyan "==> Rebuilding Dockerized app image (cache-aware) for ${SIGRA_UAT_PROJECT}"
  docker compose -p "${SIGRA_UAT_PROJECT}" -f "${compose_file}" --profile proxy build web

  cyan "==> Restarting Dockerized Vaultr example app"
  docker compose -p "${SIGRA_UAT_PROJECT}" -f "${compose_file}" --profile proxy up -d web

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

  # Deps + sigra are already compiled into the image by Dockerfile.example, so the
  # one-time setup only prepares the database (no deps.get / no --force recompiles).
  local setup_script
  setup_script="set -e
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
# Per-checkout host, unique by construction (never collides across branches /
# worktrees / sibling libs, so Traefik never silently round-robins two backends).
SIGRA_UAT_PROXY_HOST="${SIGRA_UAT_PROXY_HOST:-$(default_proxy_host)}"
SIGRA_UAT_PROXY_NETWORK="${SIGRA_UAT_PROXY_NETWORK:-proxy}"
SIGRA_UAT_PROXY_ROUTER="${SIGRA_UAT_PROXY_ROUTER:-$(slugify "${SIGRA_UAT_PROJECT}")}"
# Friendly stable alias (sigra.localhost) attached only for the primary checkout
# (default branch, alias unclaimed). When not eligible it falls back to the
# primary host, making the alias router a harmless duplicate to the same backend.
SIGRA_UAT_ALIAS_HOST="${SIGRA_UAT_ALIAS_HOST:-${SIGRA_UAT_PROXY_HOST}}"
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
    # Publish a real host port so a 127.0.0.1:<port> raw URL works in Firefox /
    # Safari / curl, which don't resolve *.localhost the way Chrome does.
    SIGRA_UAT_WEB_PORT="${SIGRA_UAT_WEB_PORT:-$(find_free_port)}"
    SIGRA_UAT_RAW_URL="http://127.0.0.1:${SIGRA_UAT_WEB_PORT}"
    # Friendly alias only for the primary checkout: default branch AND nobody
    # else currently claims sigra.localhost. Otherwise the alias stays equal to
    # the (unique) primary host so its router is a harmless self-duplicate.
    if is_default_branch && ! alias_claimed_by_other; then
      SIGRA_UAT_ALIAS_HOST="$(alias_proxy_host)"
    else
      SIGRA_UAT_ALIAS_HOST="${SIGRA_UAT_PROXY_HOST}"
      if is_default_branch; then
        yellow "    Note: $(alias_proxy_host) is already claimed by another stack; using your unique host only."
      fi
    fi
    ensure_shared_proxy
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
export SIGRA_UAT_ALIAS_HOST
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
