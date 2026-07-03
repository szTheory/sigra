#!/usr/bin/env bash
# scripts/ci/install-smoke.sh
#
# Installs a fresh Phoenix app, points it at the local Sigra dep, runs
# `mix sigra.install`, and compiles the result under --warnings-as-errors.
# Run from the repo root OR from any directory with GITHUB_WORKSPACE set.
#
# Used by the install_smoke CI job. Locally reproducible:
#     GITHUB_WORKSPACE=$(pwd) scripts/ci/install-smoke.sh
#
# Requires: elixir 1.18+, mix archive.install hex phx_new, postgres on
# localhost:5432 with user=postgres password=postgres.

set -euo pipefail

_ci_here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/ci/lib/mix-deps-get-retry.sh
source "${_ci_here}/lib/mix-deps-get-retry.sh"

SIGRA_REPO="${GITHUB_WORKSPACE:-$(pwd)}"
TMP_APP_DIR="${TMP_APP_DIR:-/tmp/tmp_app}"

export PGUSER="${PGUSER:-postgres}"
export PGPASSWORD="${PGPASSWORD:-postgres}"
export PGHOST="${PGHOST:-localhost}"

echo "==> install-smoke: using Sigra repo at ${SIGRA_REPO}"

# D-11: assert the resolved phx.new version matches the pin target before
# scaffolding. A stale cached 1.8.7 archive on a reused CI runner would
# otherwise produce a false-green against the wrong generator version.
PHX_NEW_PIN="1.8.8"
PHX_NEW_RESOLVED=$(mix phx.new --version 2>&1 || true)
if ! echo "${PHX_NEW_RESOLVED}" | grep -q "${PHX_NEW_PIN}"; then
  echo "FAIL: resolved phx.new version does not match pin target ${PHX_NEW_PIN}"
  echo "  resolved: ${PHX_NEW_RESOLVED}"
  echo "  expected: Phoenix installer v${PHX_NEW_PIN}"
  echo "  Fix: mix archive.install --force hex phx_new ${PHX_NEW_PIN}"
  exit 1
fi
echo "==> install-smoke: phx.new version OK (${PHX_NEW_RESOLVED})"

echo "==> install-smoke: generating fresh Phoenix app at ${TMP_APP_DIR}"

rm -rf "${TMP_APP_DIR}"
mkdir -p "$(dirname "${TMP_APP_DIR}")"
cd "$(dirname "${TMP_APP_DIR}")"

# mix archive.install phx_new MUST already be in place (installed by the CI
# step before this script runs).
mix phx.new "$(basename "${TMP_APP_DIR}")" \
  --no-install \
  --no-dashboard \
  --database postgres

cd "${TMP_APP_DIR}"

echo "==> install-smoke: patching mix.exs to add {:sigra, path: \"${SIGRA_REPO}\"}"
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

echo "==> install-smoke: fetching deps (hex + path dep; retries for transient GitHub git deps)"
mix_deps_get_with_retry

echo "==> install-smoke: running mix sigra.install --yes Accounts User users"
mix sigra.install --yes Accounts User users

echo "==> install-smoke: compiling with --warnings-as-errors"
mix compile --warnings-as-errors

echo "==> install-smoke: creating + migrating fresh DB"
mix ecto.create
mix ecto.migrate

# mix sigra.gen.oauth checks direct deps only — add cloak_ecto even though
# Sigra pulls it transitively, so the generator's check_cloak_ecto!/0 passes.
if ! grep -q '{:cloak_ecto' mix.exs; then
  echo "==> install-smoke: injecting {:cloak_ecto, \"~> 1.3\"} for mix sigra.gen.oauth"
  elixir -e '
    path = "mix.exs"
    content = File.read!(path)
    anchor = "      {:sigra, path: System.get_env(\"SIGRA_REPO\")},\n"
    unless String.contains?(content, anchor) do
      IO.puts(:stderr, "FAIL: expected sigra path dep anchor in mix.exs")
      System.halt(1)
    end
    cloak = "      {:cloak_ecto, \"~> 1.3\"},\n"
    new = String.replace(content, anchor, anchor <> cloak, global: false)
    File.write!(path, new)
  '
  mix_deps_get_with_retry
  mix compile --warnings-as-errors
fi

echo "==> install-smoke: mix sigra.gen.oauth (greenfield generator contract)"
mix sigra.gen.oauth --providers google,github
mix ecto.migrate
mix compile --warnings-as-errors

APP="$(basename "$(pwd)")"
WEB_LIB="lib/${APP}_web"
CTX="lib/${APP}/accounts"

oauth_paths=(
  "${CTX}/user_identity.ex"
  "${WEB_LIB}/controllers/oauth_controller.ex"
  "${WEB_LIB}/controllers/oauth_html.ex"
  "${WEB_LIB}/controllers/oauth_buttons.html.heex"
  "${CTX}/emails/provider_linked.ex"
  "${CTX}/emails/provider_unlinked.ex"
  "lib/${APP}/vault.ex"
  "lib/${APP}/encrypted/binary.ex"
  "${WEB_LIB}/controllers/oauth_settings.html.heex"
  "test/support/oauth_test_helpers.ex"
)

missing=0
for f in "${oauth_paths[@]}"; do
  if [[ ! -f "${f}" ]]; then
    echo "FAIL: expected generated file missing: ${f}"
    missing=1
  fi
done
[[ "${missing}" -eq 0 ]] || exit 1

shopt -s nullglob
migs=(priv/repo/migrations/*create_user_identities*.exs)
shopt -u nullglob
if [[ ${#migs[@]} -lt 1 ]]; then
  echo "FAIL: expected create_user_identities migration under priv/repo/migrations/"
  exit 1
fi

grep -q "# Sigra OAuth" "${WEB_LIB}/router.ex" || {
  echo "FAIL: OAuth route marker missing in router"
  exit 1
}

echo "==> install-smoke: oauth generator contract OK (>=11 generated paths + migration + router inject)"

echo "==> install-smoke: done; tmp_app generated + sigra-installed + compiled clean"
