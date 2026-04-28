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
GETTING_STARTED_DIR="${SIGRA_REPO}/.planning/uat-evidence/v1.20/getting-started-clean-machine"
GETTING_STARTED_REPORTS_DIR="${GETTING_STARTED_DIR}/reports"
GETTING_STARTED_TRANSCRIPT="${GETTING_STARTED_DIR}/transcript.log"
GETTING_STARTED_ENV="${GETTING_STARTED_DIR}/env.txt"
GETTING_STARTED_REPORT="${GETTING_STARTED_REPORTS_DIR}/generated-host-checks.json"

export PGUSER="${PGUSER:-postgres}"
export PGPASSWORD="${PGPASSWORD:-postgres}"
export PGHOST="${PGHOST:-localhost}"

mkdir -p "${GETTING_STARTED_REPORTS_DIR}"
: > "${GETTING_STARTED_TRANSCRIPT}"

record_getting_started() {
  printf '%s %s\n' "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" "$1" | tee -a "${GETTING_STARTED_TRANSCRIPT}"
}

record_getting_started "START generated-host getting-started contract"

{
  echo "# GAUAT-08 generated-host environment capture"
  echo "# Recorded: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  echo
  echo "$ uname -a"
  uname -a
  echo
  echo "$ elixir --version"
  elixir --version
  echo
  echo "$ mix phx.new --version"
  mix phx.new --version
  echo
  echo "$ psql --version"
  psql --version
} > "${GETTING_STARTED_ENV}"

echo "==> install-smoke: using Sigra repo at ${SIGRA_REPO}"
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
record_getting_started "SIGRA_INSTALL_OK"

echo "==> install-smoke: compiling with --warnings-as-errors"
mix compile --warnings-as-errors

echo "==> install-smoke: creating + migrating fresh DB"
mix ecto.drop --force 2>/dev/null || true
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

echo "==> install-smoke: creating + migrating test DB and running mix test"
MIX_ENV=test mix ecto.drop --force 2>/dev/null || true
MIX_ENV=test mix ecto.create
MIX_ENV=test mix ecto.migrate
MIX_ENV=test mix test
record_getting_started "BASE_TEST_SUITE_OK"

APP_MODULE="$(
  elixir -e 'System.argv() |> hd() |> Macro.camelize() |> IO.write()' "$(basename "${TMP_APP_DIR}")"
)"

cat > test/getting_started_generated_host_test.exs <<EOF
defmodule ${APP_MODULE}.GettingStartedGeneratedHostTest do
  use ${APP_MODULE}.DataCase, async: false

  alias ${APP_MODULE}.Accounts

  test "generated host happy path matches getting-started guide contract" do
    email = "generated-host-\#{System.unique_integer([:positive])}@example.test"
    password = "CorrectHorseBatteryStaple123!"

    assert {:ok, user} =
             Accounts.register_user(%{
               email: email,
               password: password
             })

    assert %{id: uid} = Accounts.get_user_by_email_and_password(email, password)
    assert uid == user.id

    token = Accounts.generate_user_session_token(user)
    assert is_binary(token)
    assert %{id: ^uid} = Accounts.get_user_by_session_token(token)

    Accounts.delete_user_session_token(token)
    refute Accounts.get_user_by_session_token(token)

    new_password = "RotatedPassword123!"

    assert {:ok, _updated} =
             Accounts.reset_user_password(user, %{
               password: new_password,
               password_confirmation: new_password
             })

    assert %{id: ^uid} = Accounts.get_user_by_email_and_password(email, new_password)
    refute Accounts.get_user_by_email_and_password(email, password)
  end
end
EOF

echo "==> install-smoke: running generated-host getting-started lifecycle test"
MIX_ENV=test mix test test/getting_started_generated_host_test.exs
record_getting_started "FIRST_SUCCESSFUL_REGISTER_LOGIN_RESET"

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

echo "==> install-smoke: booting generated host to verify guide routes respond"
PHX_SERVER=true MIX_ENV=test mix phx.server > /tmp/install-smoke-server.log 2>&1 &
SERVER_PID=$!
trap 'kill ${SERVER_PID} 2>/dev/null || true' EXIT

server_ready=false
for i in $(seq 1 30); do
  if curl -sf http://localhost:4000/ > /dev/null; then
    server_ready=true
    echo "generated host responded after ${i}s"
    record_getting_started "FIRST_SERVER_BOOT"
    break
  fi
  sleep 1
done

if [[ "${server_ready}" != "true" ]]; then
  echo "FAIL: generated host did not boot within 30 seconds"
  cat /tmp/install-smoke-server.log
  exit 1
fi

curl -sf http://localhost:4000/users/register > /dev/null
curl -sf http://localhost:4000/users/log_in > /dev/null

cat > "${GETTING_STARTED_REPORT}" <<EOF
{
  "generated_host_lifecycle": "pass",
  "server_boot": "pass",
  "register_page_http": 200,
  "login_page_http": 200,
  "notes": "Generated-host mechanical proof replaces human-timed walkthrough gating for GAUAT-08."
}
EOF

record_getting_started "END generated-host getting-started contract"

echo "==> install-smoke: oauth generator contract OK (>=11 generated paths + migration + router inject)"
echo "==> install-smoke: oauth-gen: 12/12 expected artifacts present, mix test green"

echo "==> install-smoke: done; tmp_app generated + sigra-installed + compiled clean"
