#!/usr/bin/env bash
# Tear down the Sigra local TEST/DEV Postgres.
#
# Usage:
#   scripts/db/down.sh           # stop + remove the container (no volume to keep)
#   scripts/db/down.sh --purge   # same, and prune any anonymous volume + remove tmp/db.env
#
# The test DB has no named volume, so a plain `down` already discards its data.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
COMPOSE_FILE="${REPO_ROOT}/scripts/db/docker-compose.yml"
STATE_FILE="${REPO_ROOT}/tmp/db.env"

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
  slug="$(slugify "sigra-db-${user}-${branch}-${hash}")"
  printf '%s' "${slug:-sigra-db-local}"
}

if [[ -z "${SIGRA_DB_PROJECT:-}" && -f "${STATE_FILE}" ]]; then
  # shellcheck disable=SC1090
  source "${STATE_FILE}"
fi

SIGRA_DB_PROJECT="${SIGRA_DB_PROJECT:-$(default_project_name)}"

if [ "${1:-}" = "--purge" ]; then
  echo "Stopping + removing test Postgres for Compose project ${SIGRA_DB_PROJECT} (purging volumes)..."
  docker compose -p "${SIGRA_DB_PROJECT}" -f "${COMPOSE_FILE}" down -v --remove-orphans
  rm -f "${STATE_FILE}"
else
  echo "Stopping + removing test Postgres for Compose project ${SIGRA_DB_PROJECT}..."
  docker compose -p "${SIGRA_DB_PROJECT}" -f "${COMPOSE_FILE}" down --remove-orphans
fi
