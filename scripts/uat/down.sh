#!/usr/bin/env bash
# Tear down the Sigra UAT environment.
#
# Usage:
#   scripts/uat/down.sh           # stop containers, keep postgres data volume
#   scripts/uat/down.sh --purge   # also remove the persistent volume

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
COMPOSE_FILE="${REPO_ROOT}/scripts/uat/docker-compose.yml"
STATE_FILE="${REPO_ROOT}/tmp/uat.env"

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

if [[ -z "${SIGRA_UAT_PROJECT:-}" && -z "${COMPOSE_PROJECT_NAME:-}" && -f "${STATE_FILE}" ]]; then
  # shellcheck disable=SC1090
  source "${STATE_FILE}"
fi

SIGRA_UAT_PROJECT="${SIGRA_UAT_PROJECT:-${COMPOSE_PROJECT_NAME:-$(default_project_name)}}"

if [ "${1:-}" = "--purge" ]; then
  echo "Stopping containers and removing volumes for Compose project ${SIGRA_UAT_PROJECT}..."
  docker compose -p "${SIGRA_UAT_PROJECT}" -f "${COMPOSE_FILE}" down -v --remove-orphans
  rm -f "${STATE_FILE}"
else
  echo "Stopping containers for Compose project ${SIGRA_UAT_PROJECT} (volumes preserved)..."
  docker compose -p "${SIGRA_UAT_PROJECT}" -f "${COMPOSE_FILE}" down --remove-orphans
fi
