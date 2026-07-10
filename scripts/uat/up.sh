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
#   scripts/uat/up.sh                  # DEFAULT: Dockerized demo behind shared Traefik,
#                                      #   live reload, health-gated, auto-opens /demo/credentials
#   scripts/uat/up.sh --proxy          # explicit alias of the default (shared Traefik)
#   scripts/uat/up.sh --dev / --host   # host-run Phoenix (fast live reload, no Docker app build)
#   scripts/uat/up.sh --attach / --iex # host-run in the foreground bound to an IEx shell
#   scripts/uat/up.sh --no-watch       # proxy mode without the bind-mount live-reload override
#   scripts/uat/up.sh --no-open        # do not auto-open the demo URL when ready
#   scripts/uat/up.sh --reset          # drop and recreate the database first
#   scripts/uat/up.sh --no-seed        # skip demo persona seeding
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
# New default-mode + UX flags (see Usage). The no-flag default is now the
# Dockerized shared-Traefik path WITH live reload, auto-open, and a readiness gate.
ENABLE_DEV_HOST=0
SIGRA_UAT_OPEN="${SIGRA_UAT_OPEN:-1}"
ENABLE_ATTACH=0
ENABLE_WATCH=1
# Readiness state — set by wait_for_http; print_status branches the PRIMARY URL
# line on it so a STARTING server is never advertised as live.
SIGRA_UAT_READY=0
# Host-run server PID + log paths (only written in --dev mode).
SIGRA_UAT_HOST_PID_FILE="${REPO_ROOT}/tmp/uat-phoenix.pid"
SIGRA_UAT_HOST_LOG_FILE="${REPO_ROOT}/tmp/uat-phoenix.log"
# Watch override file applied by default in proxy mode (disable with --no-watch).
WATCH_FILE="${REPO_ROOT}/scripts/uat/docker-compose.watch.yml"

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
SIGRA_UAT_READY=$(shell_quote "${SIGRA_UAT_READY:-0}")
SIGRA_UAT_HOST_PID_FILE=$(shell_quote "${SIGRA_UAT_HOST_PID_FILE:-}")
SIGRA_UAT_HOST_LOG_FILE=$(shell_quote "${SIGRA_UAT_HOST_LOG_FILE:-}")
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

  # When invoked via --status, re-probe liveness with a quick curl so a frozen
  # SIGRA_UAT_READY flag (written at boot time) doesn't lie about a server that
  # came up after the initial probe timed out, or that has since gone away.
  local probe_url="${SIGRA_UAT_RAW_URL:-${base}}"
  if curl -fsS --max-time 2 "${probe_url}" >/dev/null 2>&1; then
    SIGRA_UAT_READY=1
  else
    SIGRA_UAT_READY=0
  fi

  # Branch the primary-URL line on readiness so a STARTING server is never
  # advertised as live.
  local primary_line=" PRIMARY URL   ${base}"
  if [[ "${SIGRA_UAT_READY:-0}" != "1" ]]; then
    primary_line=" PRIMARY URL   ${base}   STARTING — not yet responding (see ${SIGRA_UAT_HOST_LOG_FILE:-tmp/uat-phoenix.log})"
  fi

  # Optional alias + raw-fallback lines, shown only when meaningful.
  local alias_line="" raw_line="" server_line=""
  case "${SIGRA_UAT_PROXY_MODE:-none}" in
    shared)
      if [[ -n "${SIGRA_UAT_ALIAS_HOST:-}" && "${SIGRA_UAT_ALIAS_HOST}" != "${SIGRA_UAT_PROXY_HOST}" ]]; then
        alias_line=" ALIAS         http://${SIGRA_UAT_ALIAS_HOST}            (primary checkout)"
      fi
      raw_line=" RAW FALLBACK  ${SIGRA_UAT_RAW_URL}            (use in Firefox/Safari/curl — they don't resolve *.localhost)"
      # Server is already running in the container — point at logs, not a run command.
      server_line=" Logs          docker compose -p ${SIGRA_UAT_PROJECT} -f ${compose_file} --profile proxy logs -f web"
      ;;
    private-traefik)
      raw_line=" RAW FALLBACK  ${SIGRA_UAT_RAW_URL}            (host Phoenix port ${SIGRA_EXAMPLE_PORT})"
      server_line=" Server        ${SIGRA_UAT_SERVER_COMMAND}"
      ;;
    *)
      # Host-run (--dev): the server is already started in the background.
      server_line=" Logs          tail -f ${SIGRA_UAT_HOST_LOG_FILE:-tmp/uat-phoenix.log}  ·  Attach IEx: ${SIGRA_UAT_SERVER_COMMAND}"
      ;;
  esac

  cat <<EOF

────────────────────────────────────────────────────────────
 Sigra UAT  ·  project: ${SIGRA_UAT_PROJECT}
────────────────────────────────────────────────────────────

${primary_line}
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

 ADMIN ROUTES  (sign in as admin@demo.vaultr.test)
   Dashboard   ${base}/admin
   Users       ${base}/admin/users
   Audit       ${base}/admin/audit
   Branding    ${base}/admin/auth-branding
   Design      ${base}/admin/_design
   Org-scoped  ${base}/admin/organizations/acme-corp

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

  # Wipe a stale example build whose frozen endpoint port differs from the target
  # host-run port BEFORE any mix task runs — otherwise validate_compile_env aborts
  # `mix ecto.migrate`/`mix phx.server` and the build can never self-heal.
  sync_host_compile_env_port

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
  # Compose -f args: base file, plus the live-reload override by default
  # (suppressed with --no-watch). The override bind-mounts the repo for hot
  # reload and shadows compiled artifacts with named volumes (compile-env safe).
  local -a compose_files=(-f "${COMPOSE_FILE}")
  if [ "${ENABLE_WATCH}" -eq 1 ]; then
    compose_files+=(-f "${WATCH_FILE}")
    cyan "==> Live reload ON (bind-mount override; disable with --no-watch)"
  else
    yellow "==> --no-watch: bind-mount live reload disabled (rebuild with --refresh-code)"
  fi

  cyan "==> Preparing Dockerized Vaultr example app"
  docker compose -p "${SIGRA_UAT_PROJECT}" "${compose_files[@]}" --profile proxy stop web >/dev/null 2>&1 || true
  docker compose -p "${SIGRA_UAT_PROJECT}" "${compose_files[@]}" --profile proxy build web

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

  docker compose -p "${SIGRA_UAT_PROJECT}" "${compose_files[@]}" --profile proxy run --rm web sh -lc "${setup_script}"

  if [ "${SEED_DEMO}" -ne 1 ]; then
    yellow "==> --no-seed requested: demo personas were not seeded"
  fi

  cyan "==> Starting Dockerized Vaultr example app"
  # --wait blocks on the web healthcheck so a STARTING container isn't advertised.
  # Non-fatal on purpose: a healthcheck quirk (e.g. a missing probe binary, or a
  # boot slower than start_period) must never abort a container that is actually
  # serving. The authoritative gate is the host-side wait_for_http below, which
  # probes the published 127.0.0.1 port directly.
  if ! docker compose -p "${SIGRA_UAT_PROJECT}" "${compose_files[@]}" --profile proxy up -d --wait web; then
    yellow "==> web container did not report healthy in time — falling back to the HTTP probe"
  fi

  SIGRA_UAT_WEB_HOST_PORT="$(docker compose -p "${SIGRA_UAT_PROJECT}" "${compose_files[@]}" port web 4000 | awk -F: 'END {print $NF}')"
  if [[ -n "${SIGRA_UAT_WEB_HOST_PORT}" ]]; then
    SIGRA_UAT_RAW_URL="http://127.0.0.1:${SIGRA_UAT_WEB_HOST_PORT}"
  fi

  # Final readiness gate on the raw 127.0.0.1 URL (resolves everywhere).
  wait_for_http "${SIGRA_UAT_RAW_URL}"
}

# Poll an HTTP URL until it answers 200 (or times out). Sets the SIGRA_UAT_READY
# global from the result and logs accordingly — never exits non-zero, so a slow
# boot degrades to a STARTING label in print_status instead of a hard failure.
# Always probe the RAW 127.0.0.1:<published-port> URL (resolves in every browser,
# bypasses *.localhost DNS).
wait_for_http() {
  local url="$1"
  local timeout="${2:-60}"
  local waited=0

  cyan "==> Waiting for ${url} to respond (up to ${timeout}s)"
  while [[ "${waited}" -lt "${timeout}" ]]; do
    if curl -fsS --max-time 2 "${url}" >/dev/null 2>&1; then
      SIGRA_UAT_READY=1
      green "    Up — ${url} responded after ${waited}s"
      return 0
    fi
    sleep 1
    waited=$((waited + 1))
  done

  SIGRA_UAT_READY=0
  yellow "    Not ready after ${timeout}s — ${url} is still starting (see ${SIGRA_UAT_HOST_LOG_FILE} for host-run logs)."
  return 0
}

# Background host-run Phoenix in test/example with the same PG*/PORT/SIGRA_EXAMPLE_*
# env the SIGRA_UAT_SERVER_COMMAND uses; log to tmp/uat-phoenix.log, PID to
# tmp/uat-phoenix.pid so --status and down.sh can find it.
start_host_server() {
  mkdir -p "$(dirname "${SIGRA_UAT_HOST_LOG_FILE}")"
  cyan "==> Starting host-run Phoenix (logs: ${SIGRA_UAT_HOST_LOG_FILE})"
  # `exec` so the recorded $! is the process that becomes the BEAM, not a bash
  # subshell wrapper that would leave Phoenix orphaned (and holding the port)
  # when down.sh signals the pidfile. The mix→elixir→erl launchers each exec the
  # next, so on success $! resolves to beam.smp and SIGTERM stops Phoenix cleanly.
  (
    cd "${EXAMPLE_DIR}"
    exec env PGHOST="${PGHOST}" PGPORT="${PGPORT}" PGUSER="${PGUSER}" PGPASSWORD="${PGPASSWORD}" \
      PGDATABASE="${PGDATABASE}" PORT="${SIGRA_EXAMPLE_PORT}" \
      SIGRA_EXAMPLE_BIND="${SIGRA_EXAMPLE_BIND}" SIGRA_EXAMPLE_URL="${SIGRA_EXAMPLE_URL}" \
      mix phx.server
  ) >"${SIGRA_UAT_HOST_LOG_FILE}" 2>&1 &
  printf '%s' "$!" >"${SIGRA_UAT_HOST_PID_FILE}"
}

# The host-run example freezes ExampleWeb.Endpoint — the http port included — into
# a compile-time invariant: it reads `Application.compile_env!(:example,
# ExampleWeb.Endpoint)` (for secret_key_base). Elixir validates that invariant at
# the START of every mix task (ecto.migrate, compile, phx.server) and ABORTS on a
# mismatch *before* it would recompile — so a _build/dev that was last compiled at a
# different port (e.g. a plain `mix compile` defaulting to 4000, or a prior bumped
# run) cannot self-heal; it hard-fails with a validate_compile_env error. Detect the
# port frozen into the compiled example.app and, on mismatch with the target
# host-run port, wipe the stale example build so the next mix invocation recompiles
# cleanly at the target port (no prior value left to validate against). Only the
# example app is wiped (deps stay compiled), and only when it actually diverges, so
# the common case stays fast.
sync_host_compile_env_port() {
  local app_file="${EXAMPLE_DIR}/_build/dev/lib/example/ebin/example.app"
  [ -f "${app_file}" ] || return 0
  local frozen
  frozen="$(grep -oE '\{port,[0-9]+\}' "${app_file}" 2>/dev/null | grep -oE '[0-9]+' | head -1)"
  if [ -n "${frozen}" ] && [ "${frozen}" != "${SIGRA_EXAMPLE_PORT}" ]; then
    yellow "    Example _build was compiled for port ${frozen}; wiping for a clean recompile at ${SIGRA_EXAMPLE_PORT} (compile-env invariant)."
    rm -rf "${EXAMPLE_DIR}/_build/dev/lib/example"
  fi
}

# Cheap TOCTOU guard: if the chosen host-run port got taken during setup, grab a
# fresh free port and re-derive the dependent URLs. The bumped port no longer
# matches the port the example was just compiled at, so re-sync the compile-env
# build (wipe + clean recompile happens on the subsequent `mix phx.server`). Only
# meaningful in none mode.
ensure_port_free() {
  if lsof -iTCP:"${SIGRA_EXAMPLE_PORT}" -sTCP:LISTEN >/dev/null 2>&1; then
    yellow "    Port ${SIGRA_EXAMPLE_PORT} got taken during setup; selecting another."
    SIGRA_EXAMPLE_PORT="$(find_free_port)"
    SIGRA_UAT_RAW_URL="http://127.0.0.1:${SIGRA_EXAMPLE_PORT}"
    SIGRA_EXAMPLE_URL="${SIGRA_UAT_RAW_URL}"
    export PORT="${SIGRA_EXAMPLE_PORT}"
    export SIGRA_EXAMPLE_URL
    sync_host_compile_env_port
  fi
}

# Reap stale UAT compose stacks that were leaked by a prior run (e.g. a tab
# close, a Ctrl-C before down.sh, or an old invocation whose compose project
# name changed). Mirrors the stale-build wipe precedent at sync_host_compile_env_port.
#
# Safety invariant: NEVER reap the project the current invocation is about to use
# (guarded by the "!= current project" check). Opt out with SIGRA_UAT_REAP=0.
reap_stale_uat_stacks() {
  [[ "${SIGRA_UAT_REAP:-1}" = "1" ]] || return 0
  command -v docker >/dev/null 2>&1 || return 0
  docker ps >/dev/null 2>&1 || return 0

  # List all compose projects that carry a sigra UAT label (either the
  # vendor-neutral dev.local.proxy-host or the legacy dev.sigra.proxy-host).
  # --filter is AND within a single `docker ps` query, so — mirroring the
  # proxy_host_claimants dual-label union — run one query per label and
  # dedupe with sort -u. Each leg tolerates its own failure via `|| true` so
  # one bad leg never aborts the reaper.
  local stale_projects
  stale_projects="$({
    docker ps -a \
      --filter 'label=com.docker.compose.project' \
      --filter 'label=dev.sigra.proxy-host' \
      --format '{{.Label "com.docker.compose.project"}}' 2>/dev/null || true
    docker ps -a \
      --filter 'label=com.docker.compose.project' \
      --filter 'label=dev.local.proxy-host' \
      --format '{{.Label "com.docker.compose.project"}}' 2>/dev/null || true
  } | sort -u)"

  if [[ -z "${stale_projects}" ]]; then
    return 0
  fi

  local reaped=0
  while IFS= read -r project; do
    [[ -n "${project}" ]] || continue
    # Never touch the project we are about to start.
    [[ "${project}" = "${SIGRA_UAT_PROJECT}" ]] && continue

    # Only reap if the project has no running (Up) containers — we don't want
    # to tear down a peer's actively-used stack.
    local running
    running="$(docker ps \
      --filter "label=com.docker.compose.project=${project}" \
      --filter 'status=running' \
      --format '{{.Names}}' 2>/dev/null | head -1 || true)"
    if [[ -n "${running}" ]]; then
      continue  # project has live containers — leave it alone
    fi

    yellow "    Reaping stale UAT stack: ${project} (no running containers)"
    docker compose -p "${project}" -f "${COMPOSE_FILE}" --profile proxy --profile private-traefik \
      down -v --remove-orphans >/dev/null 2>&1 || \
      docker compose -p "${project}" -f "${COMPOSE_FILE}" down -v --remove-orphans >/dev/null 2>&1 || true
    reaped=$((reaped + 1))
  done <<< "${stale_projects}"

  if [[ "${reaped}" -gt 0 ]]; then
    green "    Reaped ${reaped} stale UAT stack(s)."
  fi
}

# Open the demo URL once the readiness probe has passed. Tolerant of a missing
# opener (headless / CI) and of --no-open.
maybe_open_browser() {
  [[ "${SIGRA_UAT_OPEN}" = "1" && "${SIGRA_UAT_READY}" = "1" ]] || return 0
  if command -v open >/dev/null 2>&1; then
    open "${SIGRA_UAT_DEMO_URL}" >/dev/null 2>&1 || true
  elif command -v xdg-open >/dev/null 2>&1; then
    xdg-open "${SIGRA_UAT_DEMO_URL}" >/dev/null 2>&1 || true
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
    --dev|--host)
      ENABLE_DEV_HOST=1
      shift
      ;;
    --attach|--iex)
      ENABLE_ATTACH=1
      shift
      ;;
    --no-watch)
      ENABLE_WATCH=0
      shift
      ;;
    --no-open)
      SIGRA_UAT_OPEN=0
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
      sed -n '2,26p' "${BASH_SOURCE[0]}"
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

# --attach/--iex only makes sense for the host-run path; imply --dev so a user
# asking for a foreground IEx shell doesn't silently get a backgrounded container.
if [[ "${ENABLE_ATTACH}" = "1" && "${ENABLE_PRIVATE_TRAEFIK}" != "1" ]]; then
  ENABLE_DEV_HOST=1
fi

# Mode selection. The no-flag default is now the Dockerized shared-Traefik path
# (was `none`). --private-traefik keeps its dedicated path; --dev/--host opts into
# the host-run (`none`) path; --proxy is an explicit alias of the new default.
if [[ "${ENABLE_PRIVATE_TRAEFIK}" = "1" ]]; then
  SIGRA_UAT_PROXY_MODE="private-traefik"
elif [[ "${ENABLE_DEV_HOST}" = "1" ]]; then
  SIGRA_UAT_PROXY_MODE="none"
else
  # Default, or explicit --proxy.
  SIGRA_UAT_PROXY_MODE="shared"
fi
SIGRA_UAT_PROXY_ENABLED=0

# Post-parse validity pass: emit a warning for flags that are no-ops in the
# resolved mode, mirroring the --proxy/--private-traefik mutual-exclusion check
# above. These warnings are informational only — the script continues.
#
# --no-watch only affects shared (proxy) mode; passing it in dev/host-run mode
# or private-traefik mode has no effect.
if [[ "${ENABLE_WATCH}" = "0" && "${SIGRA_UAT_PROXY_MODE}" != "shared" ]]; then
  yellow "    Note: --no-watch is ignored in ${SIGRA_UAT_PROXY_MODE} mode (only applies to the shared proxy path)."
fi
# --attach/--iex in private-traefik mode: the flag was parsed but ENABLE_DEV_HOST
# was NOT implied (the `if` above guards on != "1" for private-traefik), so it
# would be a silent no-op.
if [[ "${ENABLE_ATTACH}" = "1" && "${SIGRA_UAT_PROXY_MODE}" = "private-traefik" ]]; then
  yellow "    Note: --attach/--iex is ignored in private-traefik mode (use --dev for a host-run IEx shell)."
fi

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
    # Friendly alias is claim-based (NOT default-branch-only): the first stack to
    # claim sigra.localhost on ANY branch gets it, so a feature branch still earns
    # the clean URL. If another stack already holds it, fall back to the (unique)
    # primary host so this alias router is a harmless self-duplicate.
    if ! alias_claimed_by_other; then
      SIGRA_UAT_ALIAS_HOST="$(alias_proxy_host)"
    else
      SIGRA_UAT_ALIAS_HOST="${SIGRA_UAT_PROXY_HOST}"
      yellow "    Note: $(alias_proxy_host) is already claimed by another stack; using your unique host only."
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
    SIGRA_EXAMPLE_PORT="${SIGRA_EXAMPLE_PORT:-${PORT:-4011}}"
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

# 2. Reap stale leaked UAT stacks from prior runs (before we boot our own stack).
# This mirrors the stale-build wipe precedent and is guarded: the current project
# is excluded so we never tear down what we're about to start.
reap_stale_uat_stacks

# 3. Bring up Docker services.
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

  # Host-run path (--dev / mode none): actually start + health-gate Phoenix.
  if [[ "${SIGRA_UAT_PROXY_MODE}" = "none" ]]; then
    if [ "${ENABLE_ATTACH}" -eq 1 ]; then
      # Foreground, terminal-bound IEx: hand the terminal to the server directly.
      cyan "==> --attach: starting Phoenix in the foreground (IEx); Ctrl-C twice to stop"
      cd "${EXAMPLE_DIR}"
      exec env PGHOST="${PGHOST}" PGPORT="${PGPORT}" PGUSER="${PGUSER}" PGPASSWORD="${PGPASSWORD}" \
        PGDATABASE="${PGDATABASE}" PORT="${SIGRA_EXAMPLE_PORT}" \
        SIGRA_EXAMPLE_BIND="${SIGRA_EXAMPLE_BIND}" SIGRA_EXAMPLE_URL="${SIGRA_EXAMPLE_URL}" \
        iex -S mix phx.server
    else
      ensure_port_free
      SIGRA_UAT_MAILBOX_URL="${SIGRA_EXAMPLE_URL}/dev/mailbox"
      SIGRA_UAT_DEMO_URL="${SIGRA_EXAMPLE_URL}/demo/credentials"
      start_host_server
      # Use 120s for the host-run boot: a cold first-run compiles example + sigra
      # from scratch (~70-90s) and would falsely print STARTING with the default
      # 60s timeout. The extended budget is only for this call site; the default
      # 60s in wait_for_http stays for the Docker probe path (which already has
      # the container-side healthcheck as a prior gate).
      wait_for_http "${SIGRA_UAT_RAW_URL}" 120
    fi
  fi
fi

SIGRA_UAT_PLAYWRIGHT_COMMAND="cd test/example/priv/playwright && SIGRA_EXAMPLE_URL=${SIGRA_EXAMPLE_URL} npx playwright test"

write_state_file
green "==> Wrote UAT env to ${STATE_FILE}"
print_status
maybe_open_browser
