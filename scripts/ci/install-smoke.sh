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

SIGRA_REPO="${GITHUB_WORKSPACE:-$(pwd)}"
TMP_APP_DIR="${TMP_APP_DIR:-/tmp/tmp_app}"

export PGUSER="${PGUSER:-postgres}"
export PGPASSWORD="${PGPASSWORD:-postgres}"
export PGHOST="${PGHOST:-localhost}"

echo "==> install-smoke: using Sigra repo at ${SIGRA_REPO}"
echo "==> install-smoke: generating fresh Phoenix app at ${TMP_APP_DIR}"

rm -rf "${TMP_APP_DIR}"
mkdir -p "$(dirname "${TMP_APP_DIR}")"
cd "$(dirname "${TMP_APP_DIR}")"

# mix archive.install phx_new MUST already be in place (installed by the CI
# step before this script runs).
yes Y | mix phx.new "$(basename "${TMP_APP_DIR}")" \
  --no-install \
  --no-dashboard \
  --no-gettext \
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

echo "==> install-smoke: fetching deps (hex + path dep)"
mix deps.get

echo "==> install-smoke: running mix sigra.install --yes Accounts User users"
mix sigra.install --yes Accounts User users

echo "==> install-smoke: compiling with --warnings-as-errors"
mix compile --warnings-as-errors

echo "==> install-smoke: creating + migrating fresh DB"
mix ecto.create
mix ecto.migrate

echo "==> install-smoke: done; tmp_app generated + sigra-installed + compiled clean"
