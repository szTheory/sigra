#!/usr/bin/env bash
# Start the generic shared local Traefik proxy used by Sigra and sibling apps.
#
# Usage:
#   scripts/dev-proxy/up.sh
#
# Environment:
#   SIGRA_DEV_PROXY_PROJECT=dev_proxy
#   SIGRA_DEV_PROXY_NETWORK=proxy
#   SIGRA_DEV_PROXY_BIND=127.0.0.1
#   SIGRA_DEV_PROXY_HTTP_PORT=80
#   SIGRA_DEV_PROXY_TRAEFIK_IMAGE=traefik:v3.7.1

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
COMPOSE_FILE="${REPO_ROOT}/scripts/dev-proxy/docker-compose.yml"

SIGRA_DEV_PROXY_PROJECT="${SIGRA_DEV_PROXY_PROJECT:-dev_proxy}"
SIGRA_DEV_PROXY_NETWORK="${SIGRA_DEV_PROXY_NETWORK:-proxy}"
SIGRA_DEV_PROXY_BIND="${SIGRA_DEV_PROXY_BIND:-127.0.0.1}"
SIGRA_DEV_PROXY_HTTP_PORT="${SIGRA_DEV_PROXY_HTTP_PORT:-80}"

cyan() { printf '\033[36m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }
red() { printf '\033[31m%s\033[0m\n' "$*"; }

port_owners() {
  docker ps --format '{{.Names}}\t{{.Ports}}' |
    awk -F '\t' -v port="${SIGRA_DEV_PROXY_HTTP_PORT}" \
      '$2 ~ ("(^|, )((127\\.0\\.0\\.1|0\\.0\\.0\\.0):" port "|\\[::\\]:" port ")->") {print $0}'
}

if ! command -v docker >/dev/null 2>&1; then
  red "docker not found in PATH. Install Docker Desktop and start it."
  exit 1
fi

if ! docker ps >/dev/null 2>&1; then
  red "Docker daemon not responsive. Start Docker Desktop and try again."
  exit 1
fi

owners="$(port_owners || true)"
expected_name="${SIGRA_DEV_PROXY_PROJECT}-traefik-1"
if [[ -n "${owners}" ]] && ! printf '%s\n' "${owners}" | awk -F '\t' '{print $1}' | grep -qx "${expected_name}"; then
  red "Port ${SIGRA_DEV_PROXY_HTTP_PORT} is already owned by another container:"
  printf '%s\n' "${owners}" | sed 's/^/  /'
  red "Stop that container or choose SIGRA_DEV_PROXY_HTTP_PORT before starting the shared proxy."
  exit 1
fi

cyan "==> Ensuring Docker network '${SIGRA_DEV_PROXY_NETWORK}' exists"
docker network create "${SIGRA_DEV_PROXY_NETWORK}" >/dev/null 2>&1 || true

export SIGRA_DEV_PROXY_NETWORK
export SIGRA_DEV_PROXY_BIND
export SIGRA_DEV_PROXY_HTTP_PORT

cyan "==> Starting shared local Traefik proxy"
docker compose -p "${SIGRA_DEV_PROXY_PROJECT}" -f "${COMPOSE_FILE}" up -d

green "==> Shared proxy ready"
printf '    HTTP:    http://localhost'
if [[ "${SIGRA_DEV_PROXY_HTTP_PORT}" != "80" ]]; then
  printf ':%s' "${SIGRA_DEV_PROXY_HTTP_PORT}"
fi
printf '\n'
printf '    Network: %s\n' "${SIGRA_DEV_PROXY_NETWORK}"
printf '    Project: %s\n' "${SIGRA_DEV_PROXY_PROJECT}"
