#!/usr/bin/env bash
# Tear down the Sigra UAT environment.
#
# Usage:
#   scripts/uat/down.sh           # stop containers, keep postgres data volume
#   scripts/uat/down.sh --purge   # also remove the persistent volume

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
COMPOSE_FILE="${REPO_ROOT}/scripts/uat/docker-compose.yml"
WATCH_FILE="${REPO_ROOT}/scripts/uat/docker-compose.watch.yml"
STATE_FILE="${REPO_ROOT}/tmp/uat.env"

# Include the watch override so `down -v` also reaps its named volumes
# (build_root/deps_root/build_example/deps_example) — they're declared ONLY in
# the watch file, so a base-file-only `down -v` would leak them per project.
COMPOSE_FILES=(-f "${COMPOSE_FILE}")
[[ -f "${WATCH_FILE}" ]] && COMPOSE_FILES+=(-f "${WATCH_FILE}")

# `--profile '*'` enables every profile so `down` actually stops the profile-gated
# services (web → proxy, traefik → private-traefik). Without it, `docker compose
# down` skips profiled services and leaks their containers + named volumes.
COMPOSE_PROFILE_ARGS=(--profile '*')

# slugify / default_project_name shared with up.sh so teardown derives the same
# Compose project name it brought up.
# shellcheck source=scripts/uat/lib/naming.sh
source "${REPO_ROOT}/scripts/uat/lib/naming.sh"

if [[ -z "${SIGRA_UAT_PROJECT:-}" && -z "${COMPOSE_PROJECT_NAME:-}" && -f "${STATE_FILE}" ]]; then
  # shellcheck disable=SC1090
  source "${STATE_FILE}"
fi

SIGRA_UAT_PROJECT="${SIGRA_UAT_PROJECT:-${COMPOSE_PROJECT_NAME:-$(default_project_name)}}"

# Stop any host-run Phoenix started by `up.sh --dev`. Proxy-default runs never
# create these files, so every step is tolerant (|| true). Same ${REPO_ROOT}-
# anchored paths up.sh writes.
stop_host_run_phoenix() {
  local pid_file="${REPO_ROOT}/tmp/uat-phoenix.pid"
  local log_file="${REPO_ROOT}/tmp/uat-phoenix.log"

  if [[ -f "${pid_file}" ]]; then
    local pid
    pid="$(cat "${pid_file}" 2>/dev/null || true)"
    # Guard against PID reuse: only signal if the live process still looks like
    # our host-run Phoenix (a stale pidfile's number may have been recycled).
    if [[ -n "${pid}" ]] && kill -0 "${pid}" >/dev/null 2>&1 \
      && ps -p "${pid}" -o command= 2>/dev/null | grep -Eq 'beam\.smp|phx\.server|mix'; then
      echo "Stopping host-run Phoenix (pid ${pid})..."
      kill "${pid}" >/dev/null 2>&1 || true
    fi
  fi
  rm -f "${pid_file}" "${log_file}" || true
}

if [ "${1:-}" = "--purge" ]; then
  echo "Stopping containers and removing volumes for Compose project ${SIGRA_UAT_PROJECT}..."
  docker compose -p "${SIGRA_UAT_PROJECT}" "${COMPOSE_FILES[@]}" "${COMPOSE_PROFILE_ARGS[@]}" down -v --remove-orphans
  stop_host_run_phoenix
  rm -f "${STATE_FILE}"
else
  echo "Stopping containers for Compose project ${SIGRA_UAT_PROJECT} (volumes preserved)..."
  docker compose -p "${SIGRA_UAT_PROJECT}" "${COMPOSE_FILES[@]}" "${COMPOSE_PROFILE_ARGS[@]}" down --remove-orphans
  stop_host_run_phoenix
fi
