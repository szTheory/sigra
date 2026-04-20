#!/usr/bin/env bash
# scripts/ci/passkeys-opt-out-smoke.sh
#
# Verifies the assets-enabled passkey opt-out path for both disabled combinations:
#   1. --no-passkeys
#   2. --no-organizations --no-passkeys
#
# For each leg this script scaffolds a fresh Phoenix app with assets enabled,
# patches in the local Sigra path dep, runs `mix sigra.install`, and proves
# passkey-only assets, deps, config, and routes are omitted while the app still
# compiles, builds assets, migrates, and boots.
#
# Local reproduction:
#   GITHUB_WORKSPACE=$(pwd) scripts/ci/passkeys-opt-out-smoke.sh

set -euo pipefail

SIGRA_REPO="${GITHUB_WORKSPACE:-$(pwd)}"
TMP_ROOT="${TMP_ROOT:-/tmp/sigra-passkeys-opt-out}"

export PGUSER="${PGUSER:-postgres}"
export PGPASSWORD="${PGPASSWORD:-postgres}"
export PGHOST="${PGHOST:-localhost}"
export CLOAK_KEY="${CLOAK_KEY:-MDEyMzQ1Njc4OWFiY2RlZjAxMjM0NTY3ODlhYmNkZWY=}"

assert_file_missing() {
  local path="$1"

  if [[ -e "${path}" ]]; then
    echo "FAIL: expected file to be absent: ${path}"
    exit 1
  fi
}

assert_no_match() {
  local pattern="$1"
  local path="$2"

  if rg -n "${pattern}" "${path}" >/dev/null 2>&1; then
    echo "FAIL: unexpected match for pattern ${pattern} in ${path}"
    rg -n "${pattern}" "${path}" || true
    exit 1
  fi
}

patch_mix_exs() {
  export SIGRA_REPO
  elixir -e '
    path = "mix.exs"
    content = File.read!(path)
    sigra_dep = "      {:sigra, path: System.get_env(\"SIGRA_REPO\")},\n      {:phoenix,"
    new_content = String.replace(content, "      {:phoenix,", sigra_dep, global: false)

    if new_content == content do
      IO.puts(:stderr, "FAIL: anchor '"'"'      {:phoenix,'"'"' not found in mix.exs; mix phx.new output shape changed")
      System.halt(1)
    end

    File.write!(path, new_content)
  '
}

run_leg() {
  local flags="$1"
  local label="$2"
  local app_dir="${TMP_ROOT}/${label}"

  echo "==> passkeys-opt-out: leg=${label} flags=${flags}"

  rm -rf "${app_dir}"
  mkdir -p "${TMP_ROOT}"
  cd "${TMP_ROOT}"

  mix phx.new "${label}" \
    --no-install \
    --no-dashboard \
    --database postgres

  cd "${app_dir}"

  echo "==> passkeys-opt-out: patching mix.exs with local Sigra path dep"
  patch_mix_exs

  echo "==> passkeys-opt-out: fetching deps"
  mix deps.get

  echo "==> passkeys-opt-out: running mix sigra.install for ${label}"
  if [[ "${flags}" == "--no-passkeys" ]]; then
    MIX_ENV=dev mix sigra.install Accounts User users --no-passkeys --yes
  else
    MIX_ENV=dev mix sigra.install Accounts User users --no-organizations --no-passkeys --yes
  fi

  echo "==> passkeys-opt-out: asserting omitted passkey assets, deps, config, and routes"
  assert_file_missing "assets/js/passkey_hooks.js"
  assert_file_missing "assets/js/passkey_browser.js"
  assert_no_match '@simplewebauthn/browser' "assets/package.json"
  assert_no_match '\{:wax_, "~> 0\.7"\}' "mix.exs"
  assert_no_match '^[[:space:]]*passkeys:\s*\[' "config/config.exs"
  assert_no_match '/users/log_in/passkey' "lib/${label}_web/router.ex"
  assert_no_match '/users/settings/mfa/passkeys' "lib/${label}_web/router.ex"
  assert_no_match '/users/mfa/passkey' "lib/${label}_web/router.ex"

  echo "==> passkeys-opt-out: compiling and building assets"
  MIX_ENV=dev mix compile --warnings-as-errors
  MIX_ENV=dev mix assets.deploy

  echo "==> passkeys-opt-out: creating + migrating DB"
  MIX_ENV=dev mix ecto.drop || true
  MIX_ENV=dev mix ecto.create
  MIX_ENV=dev mix ecto.migrate

  echo "==> passkeys-opt-out: booting app and checking root responds"
  PHX_SERVER=true MIX_ENV=dev mix phx.server > "/tmp/${label}-server.log" 2>&1 &
  local server_pid=$!
  trap 'kill ${server_pid} 2>/dev/null || true' RETURN

  for i in $(seq 1 30); do
    if curl -sf http://localhost:4000/ > /dev/null; then
      echo "==> passkeys-opt-out: ${label} responded after ${i}s"
      kill "${server_pid}" 2>/dev/null || true
      wait "${server_pid}" 2>/dev/null || true
      trap - RETURN
      return 0
    fi

    if [[ "${i}" -eq 30 ]]; then
      echo "FAIL: ${label} did not boot within 30 seconds"
      cat "/tmp/${label}-server.log"
      exit 1
    fi

    sleep 1
  done
}

echo "==> passkeys-opt-out: using Sigra repo at ${SIGRA_REPO}"
rm -rf "${TMP_ROOT}"
mkdir -p "${TMP_ROOT}"

run_leg "--no-passkeys" "sigra_no_passkeys"
run_leg "--no-organizations --no-passkeys" "sigra_no_organizations_no_passkeys"

echo "==> passkeys-opt-out: success"
