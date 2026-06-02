#!/usr/bin/env bash
# Tear down the Sigra UAT environment.
#
# Usage:
#   scripts/uat/down.sh           # stop containers, keep postgres data volume
#   scripts/uat/down.sh --purge   # also remove the persistent volume

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
COMPOSE_FILE="${REPO_ROOT}/scripts/uat/docker-compose.yml"

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

SIGRA_UAT_PROJECT="${SIGRA_UAT_PROJECT:-${COMPOSE_PROJECT_NAME:-$(default_project_name)}}"

if [ "${1:-}" = "--purge" ]; then
  echo "Stopping containers and removing volumes for Compose project ${SIGRA_UAT_PROJECT}..."
  docker compose -p "${SIGRA_UAT_PROJECT}" -f "${COMPOSE_FILE}" down -v
else
  echo "Stopping containers for Compose project ${SIGRA_UAT_PROJECT} (volumes preserved)..."
  docker compose -p "${SIGRA_UAT_PROJECT}" -f "${COMPOSE_FILE}" down
fi
