#!/usr/bin/env bash
# scripts/ci/passkeys-manual-fallback-smoke.sh
#
# Verifies the Phase 20 manual fallback path for passkey hook wiring:
# 1. Scaffold a fresh Phoenix app with assets enabled
# 2. Make app.js non-standard enough that sigra.install refuses auto-injection
# 3. Assert the installer prints the expected manual instructions
# 4. Apply those instructions programmatically
# 5. Prove the app still compiles, builds assets, migrates, and boots
#
# Local reproduction:
#   GITHUB_WORKSPACE=$(pwd) scripts/ci/passkeys-manual-fallback-smoke.sh

set -euo pipefail

_ci_here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/ci/lib/free-port.sh
source "${_ci_here}/lib/free-port.sh"

SIGRA_REPO="${GITHUB_WORKSPACE:-$(pwd)}"
TMP_APP_DIR="${TMP_APP_DIR:-/tmp/tmp_app_passkeys_manual}"

export PGUSER="${PGUSER:-postgres}"
export PGPASSWORD="${PGPASSWORD:-postgres}"
export PGHOST="${PGHOST:-localhost}"
export CLOAK_KEY="${CLOAK_KEY:-MDEyMzQ1Njc4OWFiY2RlZjAxMjM0NTY3ODlhYmNkZWY=}"

echo "==> passkeys-manual-fallback: using Sigra repo at ${SIGRA_REPO}"
echo "==> passkeys-manual-fallback: generating fresh Phoenix app at ${TMP_APP_DIR}"

rm -rf "${TMP_APP_DIR}"
mkdir -p "$(dirname "${TMP_APP_DIR}")"
cd "$(dirname "${TMP_APP_DIR}")"

mix phx.new "$(basename "${TMP_APP_DIR}")" \
  --no-install \
  --no-dashboard \
  --database postgres

cd "${TMP_APP_DIR}"

echo "==> passkeys-manual-fallback: patching mix.exs with local Sigra path dep"
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

echo "==> passkeys-manual-fallback: fetching deps"
mix deps.get

APP_JS="assets/js/app.js"

echo "==> passkeys-manual-fallback: converting app.js to a non-standard multiline hook layout"
perl -0pi -e '
  s/hooks:\s*\{\s*\.\.\.colocatedHooks\s*\},/hooks: {\n    ...colocatedHooks,\n    \/\/ custom host app hook ordering\n  },/s
' "${APP_JS}"

grep -q 'hooks: {' "${APP_JS}" || {
  echo "FAIL: custom hook block patch did not land in ${APP_JS}"
  exit 1
}

echo "==> passkeys-manual-fallback: running sigra.install --passkeys"
INSTALL_OUT=$(MIX_ENV=dev mix sigra.install Accounts User users --passkeys --yes 2>&1)
printf '%s\n' "${INSTALL_OUT}"

grep -Fq 'Passkeys generated `assets/js/passkey_hooks.js`, but Sigra could not safely edit `assets/js/app.js`.' <<<"${INSTALL_OUT}" || {
  echo "FAIL: installer did not emit manual fallback banner"
  exit 1
}

PASSKEY_IMPORT='import { PasskeyHooks } from "./passkey_hooks"'
PASSKEY_HOOKS_LINE='hooks: { ...colocatedHooks, ...PasskeyHooks }'

grep -Fq "${PASSKEY_IMPORT}" <<<"${INSTALL_OUT}" || {
  echo "FAIL: installer did not print passkey import instruction"
  exit 1
}

grep -Fq "${PASSKEY_HOOKS_LINE}" <<<"${INSTALL_OUT}" || {
  echo "FAIL: installer did not print merged hooks instruction"
  exit 1
}

if grep -Fq '// Sigra passkeys:start' "${APP_JS}"; then
  echo "FAIL: installer should not auto-inject markers in manual fallback mode"
  exit 1
fi

echo "==> passkeys-manual-fallback: applying printed instructions"
perl -0pi -e '
  s/(import\s+\{\s*hooks\s+as\s+colocatedHooks\s*\}\s+from\s+["'\''][^"'\'']+["'\'']\s*\n)/$1import { PasskeyHooks } from ".\/passkey_hooks"\n/s
' "${APP_JS}"

perl -0pi -e '
  s/hooks:\s*\{\s*\n\s*\.\.\.colocatedHooks,\s*\n\s*\/\/ custom host app hook ordering\s*\n\s*\}/hooks: { ...colocatedHooks, ...PasskeyHooks }/s
' "${APP_JS}"

grep -Fq "${PASSKEY_IMPORT}" "${APP_JS}" || {
  echo "FAIL: passkey import was not applied to ${APP_JS}"
  exit 1
}

grep -Fq "${PASSKEY_HOOKS_LINE}" "${APP_JS}" || {
  echo "FAIL: merged hooks line was not applied to ${APP_JS}"
  exit 1
}

echo "==> passkeys-manual-fallback: compiling and building assets"
MIX_ENV=dev mix compile --warnings-as-errors
# sigra.install adds `@simplewebauthn/browser` to `assets/package.json`; run the
# same `assets.setup` step as the default passkeys smoke harness so esbuild can
# resolve the WebAuthn client before `assets.deploy`.
MIX_ENV=dev mix assets.setup
MIX_ENV=dev mix assets.deploy

echo "==> passkeys-manual-fallback: creating + migrating DB"
MIX_ENV=dev mix ecto.drop || true
MIX_ENV=dev mix ecto.create
MIX_ENV=dev mix ecto.migrate

echo "==> passkeys-manual-fallback: booting app and checking root responds"
PORT="${SIGRA_PASSKEYS_MANUAL_FALLBACK_PORT:-$(find_free_port)}"
PHX_SERVER=true MIX_ENV=dev PORT="${PORT}" mix phx.server > /tmp/passkeys-manual-fallback-server.log 2>&1 &
SERVER_PID=$!
trap 'kill ${SERVER_PID} 2>/dev/null || true' EXIT

for i in $(seq 1 30); do
  if curl -sf "http://127.0.0.1:${PORT}/" > /dev/null; then
    echo "==> passkeys-manual-fallback: app responded at http://127.0.0.1:${PORT}/ after ${i}s"
    break
  fi
  if [[ "${i}" -eq 30 ]]; then
    echo "FAIL: app did not boot within 30 seconds"
    cat /tmp/passkeys-manual-fallback-server.log
    exit 1
  fi
  sleep 1
done

echo "==> passkeys-manual-fallback: success"
