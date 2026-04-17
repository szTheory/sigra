#!/usr/bin/env bash
# scripts/ci/passkeys-default-smoke.sh
#
# Verifies the assets-enabled default install path with passkeys enabled.
#
# This script scaffolds a fresh Phoenix app with assets enabled, patches in the
# local Sigra path dep, runs `mix sigra.install` without `--no-passkeys`, and
# proves the passkey summary, files, deps, config, and routes are present while
# the app still compiles, builds assets, migrates, and boots.
#
# Local reproduction:
#   GITHUB_WORKSPACE=$(pwd) scripts/ci/passkeys-default-smoke.sh

set -euo pipefail

SIGRA_REPO="${GITHUB_WORKSPACE:-$(pwd)}"
TMP_ROOT="${TMP_ROOT:-/tmp/sigra-passkeys-default}"

export PGUSER="${PGUSER:-postgres}"
export PGPASSWORD="${PGPASSWORD:-postgres}"
export PGHOST="${PGHOST:-localhost}"
export CLOAK_KEY="${CLOAK_KEY:-MDEyMzQ1Njc4OWFiY2RlZjAxMjM0NTY3ODlhYmNkZWY=}"

assert_file_exists() {
  local path="$1"

  if [[ ! -e "${path}" ]]; then
    echo "FAIL: expected file to exist: ${path}"
    exit 1
  fi
}

assert_match() {
  local pattern="$1"
  local path="$2"

  if ! rg -n "${pattern}" "${path}" >/dev/null 2>&1; then
    echo "FAIL: expected match for pattern ${pattern} in ${path}"
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

run_smoke() {
  local label="sigra_passkeys_default"
  local app_dir="${TMP_ROOT}/${label}"
  local install_log="${TMP_ROOT}/${label}-install.log"

  echo "==> passkeys-default: preparing ${label}"

  rm -rf "${app_dir}"
  mkdir -p "${TMP_ROOT}"
  cd "${TMP_ROOT}"

  mix phx.new "${label}" \
    --no-install \
    --no-dashboard \
    --database postgres

  cd "${app_dir}"

  echo "==> passkeys-default: patching mix.exs with local Sigra path dep"
  patch_mix_exs

  echo "==> passkeys-default: fetching deps"
  mix deps.get

  echo "==> passkeys-default: running mix sigra.install for ${label}"
  MIX_ENV=dev mix sigra.install Accounts User users --yes | tee "${install_log}"

  echo "==> passkeys-default: asserting enabled summary, files, deps, config, routes, and assets"
  assert_match 'Passkeys: enabled \(default\)' "${install_log}"
  assert_file_exists "assets/js/passkey_hooks.js"
  assert_file_exists "assets/js/passkey_browser.js"
  assert_match '\{:wax_, "~> 0\.7"\}' "mix.exs"
  assert_match '^[[:space:]]*passkeys:\s*\[' "config/config.exs"
  assert_match 'scope "/users"' "lib/${label}_web/router.ex"
  assert_match 'post "/log_in/passkey"' "lib/${label}_web/router.ex"
  assert_match 'post "/settings/mfa/passkeys"' "lib/${label}_web/router.ex"
  assert_match 'post "/mfa/passkey"' "lib/${label}_web/router.ex"
  assert_match 'import \{ PasskeyHooks \} from "\./passkey_hooks"' "assets/js/app.js"
  assert_match 'hooks: \{ \.\.\.colocatedHooks, \.\.\.PasskeyHooks \}' "assets/js/app.js"
  assert_match '@simplewebauthn/browser' "assets/js/passkey_browser.js"

  if [[ -f "assets/package.json" ]]; then
    assert_match '@simplewebauthn/browser' "assets/package.json"
  fi

  echo "==> passkeys-default: compiling and building assets"
  MIX_ENV=dev mix compile --warnings-as-errors
  MIX_ENV=dev mix assets.setup
  MIX_ENV=dev mix assets.deploy

  echo "==> passkeys-default: creating + migrating DB"
  MIX_ENV=dev mix ecto.drop || true
  MIX_ENV=dev mix ecto.create
  MIX_ENV=dev mix ecto.migrate

  echo "==> passkeys-default: booting app and checking root responds"
  PHX_SERVER=true MIX_ENV=dev mix phx.server > "/tmp/${label}-server.log" 2>&1 &
  local server_pid=$!
  trap 'kill ${server_pid} 2>/dev/null || true' RETURN

  for i in $(seq 1 30); do
    if curl -sf http://localhost:4000/ > /dev/null; then
      echo "==> passkeys-default: ${label} responded after ${i}s"
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

echo "==> passkeys-default: using Sigra repo at ${SIGRA_REPO}"
rm -rf "${TMP_ROOT}"
mkdir -p "${TMP_ROOT}"

run_smoke

echo "==> passkeys-default: success"
