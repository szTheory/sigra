#!/usr/bin/env bash
# scripts/ci/upgrade-smoke.sh
#
# Proves upgrade posture: selected published Hex series -> local candidate source.
# Fails on deps, compile, migration, or runtime regressions.

set -euo pipefail

_ci_here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/ci/lib/mix-deps-get-retry.sh
source "${_ci_here}/lib/mix-deps-get-retry.sh"

SIGRA_REPO="${GITHUB_WORKSPACE:-$(pwd)}"
TMP_APP_DIR="${TMP_APP_DIR:-/tmp/tmp_app_upgrade}"
START_VERSION_OVERRIDE="${SIGRA_UPGRADE_SMOKE_START_VERSION:-}"
SOURCE_SERIES="${SIGRA_UPGRADE_SOURCE_SERIES:-0.3}"

export PGUSER="${PGUSER:-postgres}"
export PGPASSWORD="${PGPASSWORD:-postgres}"
export PGHOST="${PGHOST:-localhost}"
export CLOAK_KEY="${CLOAK_KEY:-MDEyMzQ1Njc4OWFiY2RlZjAxMjM0NTY3ODlhYmNkZWY=}"

validate_source_series() {
  if [[ ! "${SOURCE_SERIES}" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
    echo "FAIL: SIGRA_UPGRADE_SOURCE_SERIES must be a major or major.minor series; got '${SOURCE_SERIES}'" >&2
    exit 1
  fi
}

series_regex() {
  if [[ "${SOURCE_SERIES}" == *.* ]]; then
    printf '^%s\\.[0-9]+$' "${SOURCE_SERIES//./\\.}"
  else
    printf '^%s\\.[0-9]+\\.[0-9]+$' "${SOURCE_SERIES}"
  fi
}

resolve_latest_sigra_source() {
  local info versions selected

  validate_source_series
  info="$(mix hex.info sigra)"
  versions="$(printf '%s\n' "${info}" | sed -n 's/^  \([0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\).*/\1/p' | grep -E "$(series_regex)" || true)"

  if [[ -z "${versions}" ]]; then
    echo "FAIL: no published sigra release found on Hex for series ${SOURCE_SERIES}" >&2
    exit 1
  fi

  selected="$(printf '%s\n' "${versions}" | sort -V | tail -n1)"
  printf '%s' "${selected}"
}

validate_override_version() {
  local override="${1}"
  local info

  validate_source_series
  if ! printf '%s\n' "${override}" | grep -Eq "$(series_regex)"; then
    echo "FAIL: SIGRA_UPGRADE_SMOKE_START_VERSION must match configured series ${SOURCE_SERIES}; got '${override}'" >&2
    exit 1
  fi

  info="$(mix hex.info sigra)"
  if ! printf '%s\n' "${info}" | grep -Eq "^  ${override}( |\()"; then
    echo "FAIL: override '${override}' is not a published sigra release on Hex" >&2
    exit 1
  fi
}

SIGRA_START_VERSION="$(resolve_latest_sigra_source)"
if [[ -n "${START_VERSION_OVERRIDE}" ]]; then
  validate_override_version "${START_VERSION_OVERRIDE}"
  SIGRA_START_VERSION="${START_VERSION_OVERRIDE}"
  echo "==> upgrade-smoke: using override published start version ${SIGRA_START_VERSION}"
else
  echo "==> upgrade-smoke: resolved latest published ${SOURCE_SERIES}.x series as ${SIGRA_START_VERSION}"
fi

echo "==> upgrade-smoke: using Sigra repo at ${SIGRA_REPO}"
echo "==> upgrade-smoke: generating fresh Phoenix app at ${TMP_APP_DIR}"

rm -rf "${TMP_APP_DIR}"
mkdir -p "$(dirname "${TMP_APP_DIR}")"
cd "$(dirname "${TMP_APP_DIR}")"

mix phx.new "$(basename "${TMP_APP_DIR}")" \
  --no-install \
  --no-dashboard \
  --database postgres

cd "${TMP_APP_DIR}"

echo "==> upgrade-smoke: patching mix.exs to start from {:sigra, \"~> ${SIGRA_START_VERSION}\"}"
export SIGRA_START_VERSION
elixir -e '
  path = "mix.exs"
  content = File.read!(path)
  sigra_dep = "      {:sigra, \"~> " <> System.get_env("SIGRA_START_VERSION") <> "\"},\n      {:phoenix,"
  new_content = String.replace(content, "      {:phoenix,", sigra_dep, global: false)
  if new_content == content do
    IO.puts(:stderr, "FAIL: anchor       {:phoenix, not found in mix.exs; mix phx.new output shape changed")
    System.halt(1)
  end
  File.write!(path, new_content)
'

echo "==> upgrade-smoke: fetching deps from published start version"
mix_deps_get_with_retry

echo "==> upgrade-smoke: running mix sigra.install --yes Accounts User users"
mix sigra.install --yes Accounts User users

echo "==> upgrade-smoke: proving published posture compiles and migrates"
mix compile --warnings-as-errors
mix ecto.drop --force || true
mix ecto.create
mix ecto.migrate
if [[ -f assets/package.json ]]; then
  echo "==> upgrade-smoke: installing generated frontend deps for runtime boot check"
  npm --prefix assets install --no-audit --no-fund
fi

echo "==> upgrade-smoke: switching sigra dep to local candidate path ${SIGRA_REPO}"
export SIGRA_REPO
elixir -e '
  path = "mix.exs"
  content = File.read!(path)

  start_version = System.get_env("SIGRA_START_VERSION")
  pattern = Regex.compile!("\\{:sigra,\\s*\"~>\\s*" <> Regex.escape(start_version) <> "\"\\}")
  replacement = "{:sigra, path: System.get_env(\"SIGRA_REPO\")}"
  new_content = Regex.replace(pattern, content, replacement, global: false)

  if new_content == content do
    IO.puts(:stderr, "FAIL: could not find published sigra dep to replace in mix.exs")
    System.halt(1)
  end

  File.write!(path, new_content)
'

echo "==> upgrade-smoke: fetching deps after local candidate switch"
mix_deps_get_with_retry

echo "==> upgrade-smoke: running mix sigra.upgrade --allow-dirty --yes"
mix sigra.upgrade --allow-dirty --yes

echo "==> upgrade-smoke: compile + migrate + runtime boot checks"
mix compile --warnings-as-errors
mix ecto.drop --force || true
mix ecto.create
mix ecto.migrate

# Keep this runner stable even if port 4000 is occupied.
PORT="${SIGRA_UPGRADE_SMOKE_PORT:-4000}"

MIX_ENV=dev PORT="${PORT}" mix phx.server > /tmp/upgrade-smoke-server.log 2>&1 &
SERVER_PID=$!
trap 'kill "${SERVER_PID}" 2>/dev/null || true' EXIT

for i in $(seq 1 180); do
  code="$(curl -s -o /dev/null -w "%{http_code}" "http://127.0.0.1:${PORT}/users/log_in" || true)"
  if [[ "${code}" == "200" || "${code}" == "301" || "${code}" == "302" || "${code}" == "303" || "${code}" == "307" || "${code}" == "308" ]]; then
    echo "==> upgrade-smoke: runtime route check passed at /users/log_in"
    exit 0
  fi
  sleep 1
done

echo "FAIL: upgrade-smoke route check failed at http://127.0.0.1:${PORT}/users/log_in" >&2
echo "--- /tmp/upgrade-smoke-server.log ---" >&2
cat /tmp/upgrade-smoke-server.log >&2 || true
exit 1
