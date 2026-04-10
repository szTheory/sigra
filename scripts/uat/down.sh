#!/usr/bin/env bash
# Tear down the Sigra UAT environment.
#
# Usage:
#   scripts/uat/down.sh           # stop containers, keep postgres data volume
#   scripts/uat/down.sh --purge   # also remove the persistent volume

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
COMPOSE_FILE="${REPO_ROOT}/scripts/uat/docker-compose.yml"

if [ "${1:-}" = "--purge" ]; then
  echo "Stopping containers and removing volume sigra-uat-pgdata..."
  docker compose -f "${COMPOSE_FILE}" down -v
else
  echo "Stopping containers (volume preserved)..."
  docker compose -f "${COMPOSE_FILE}" down
fi
