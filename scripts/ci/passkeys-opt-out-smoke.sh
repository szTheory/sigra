#!/usr/bin/env bash
# scripts/ci/passkeys-opt-out-smoke.sh
#
# Verifies the assets-enabled passkey opt-out path for the supported disabled combinations:
#   1. --no-passkeys
#   2. --no-organizations --no-passkeys
#   3. --no-admin --no-organizations --no-passkeys (the B2C Alpha profile)
#
# For each leg this script scaffolds a fresh Phoenix app with assets enabled,
# patches in the local Sigra path dep, runs `mix sigra.install`, and proves
# passkey-only assets, deps, config, and routes are omitted while the app still
# compiles, builds assets, migrates, and boots. The B2C Alpha leg also generates
# Google OAuth and asserts that the selected authentication boundary is present.
#
# Local reproduction:
#   GITHUB_WORKSPACE=$(pwd) scripts/ci/passkeys-opt-out-smoke.sh

set -euo pipefail

_ci_here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/ci/lib/free-port.sh
source "${_ci_here}/lib/free-port.sh"

SIGRA_REPO="${GITHUB_WORKSPACE:-$(pwd)}"
TMP_PARENT="${TMPDIR:-/tmp}"
TMP_ROOT="$(mktemp -d "${TMP_PARENT%/}/sigra-passkeys-opt-out.XXXXXX")"
readonly TMP_ROOT
SERVER_PID=""

export PGUSER="${PGUSER:-postgres}"
export PGPASSWORD="${PGPASSWORD:-postgres}"
export PGHOST="${PGHOST:-localhost}"
export CLOAK_KEY="${CLOAK_KEY:-MDEyMzQ1Njc4OWFiY2RlZjAxMjM0NTY3ODlhYmNkZWY=}"
# This fixed CLOAK_KEY is a disposable fixture for local generated hosts, never deployment credentials.
# This proof claims only generator shape, compile, boot; it does not prove host staging.
# Fresh generation must never inherit a developer or runner's provider credentials.
unset GOOGLE_CLIENT_ID GOOGLE_CLIENT_SECRET

cleanup_tmp_root() {
  case "${TMP_ROOT}" in
    "${TMP_PARENT%/}"/sigra-passkeys-opt-out.*) ;;
    *)
      echo "FAIL: refusing to remove unexpected temporary root: ${TMP_ROOT}" >&2
      return 1
      ;;
  esac

  [[ -d "${TMP_ROOT}" ]] && rm -rf -- "${TMP_ROOT}"
}

cleanup_server() {
  if [[ -n "${SERVER_PID}" ]]; then
    kill "${SERVER_PID}" 2>/dev/null || true
    wait "${SERVER_PID}" 2>/dev/null || true
    SERVER_PID=""
  fi
}

cleanup() {
  cleanup_server
  cleanup_tmp_root
}

cleanup_leg_dir() {
  local app_dir="$1"

  case "${app_dir}" in
    "${TMP_ROOT}"/sigra_no_passkeys | \
    "${TMP_ROOT}"/sigra_no_organizations_no_passkeys | \
    "${TMP_ROOT}"/sigra_b2c_alpha)
      rm -rf -- "${app_dir}"
      ;;
    *)
      echo "FAIL: refusing to remove unexpected leg directory: ${app_dir}" >&2
      exit 1
      ;;
  esac
}

trap cleanup EXIT

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

  if find_matches "${pattern}" "${path}" >/dev/null 2>&1; then
    echo "FAIL: unexpected match for pattern ${pattern} in ${path}"
    find_matches "${pattern}" "${path}" || true
    exit 1
  fi
}

assert_file_present() {
  local path="$1"

  if [[ ! -f "${path}" ]]; then
    echo "FAIL: expected file to exist: ${path}"
    exit 1
  fi
}

assert_glob_missing() {
  local pattern="$1"
  local matches

  matches=$(compgen -G "${pattern}" || true)
  if [[ -n "${matches}" ]]; then
    echo "FAIL: expected no files matching: ${pattern}"
    printf '%s\n' "${matches}"
    exit 1
  fi
}

assert_match() {
  local pattern="$1"
  local path="$2"

  if ! find_matches "${pattern}" "${path}" >/dev/null 2>&1; then
    echo "FAIL: expected match for pattern ${pattern} in ${path}"
    echo "Diagnostic matches:"
    find_matches 'Sigra OAuth|GOOGLE_CLIENT|OAuthController|Vault|SessionController|magic_link' "${path}" || true
    exit 1
  fi
}

find_matches() {
  local pattern="$1"
  local path="$2"

  if command -v rg >/dev/null 2>&1; then
    rg -n -- "${pattern}" "${path}"
  else
    grep -En -- "${pattern}" "${path}"
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

add_cloak_ecto() {
  elixir -e '
    path = "mix.exs"
    content = File.read!(path)
    anchor = "      {:sigra, path: System.get_env(\"SIGRA_REPO\")},\n"

    unless String.contains?(content, anchor) do
      IO.puts(:stderr, "FAIL: expected Sigra path dependency anchor in mix.exs")
      System.halt(1)
    end

    unless String.contains?(content, "{:cloak_ecto,") do
      File.write!(path, String.replace(content, anchor, anchor <> "      {:cloak_ecto, \"~> 1.3\"},\n", global: false))
    end
  '
}

install_generated_rate_limit_probe() {
  # This probe lives only in the disposable B2C host. It exercises the real
  # generated POST route synchronously: attempt N + 1 is denied in the same
  # limiter window, with no clock manipulation or delay.
  # Retry-After ceiling boundaries remain library-covered: 1_000ms -> 1,
  # 1_001ms -> 2, and 30_500ms -> 31.
  cat > "test/generated_rate_limit_probe_test.exs" <<'EOF'
defmodule SigraB2cAlpha.GeneratedRateLimitProbeTest do
  use SigraB2cAlphaWeb.ConnCase, async: false

  @limit 2

  test "generated login limiter allows N attempts then denies attempt N + 1", %{conn: conn} do
    conn = get(conn, "/users/log_in")
    csrf_token = csrf_token(conn.resp_body)

    Enum.reduce(1..@limit, conn, fn _attempt, request_conn ->
      response =
        request_conn
        |> recycle()
        |> post("/users/log_in", login_params(csrf_token))

      assert response.status in [302, 303]
      response
    end)
    |> recycle()
    |> post("/users/log_in", login_params(csrf_token))
    |> then(fn response ->
      assert response.status == 429
      assert response.resp_body == "Too many requests. Please try again later."
      assert [retry_after] = Plug.Conn.get_resp_header(response, "retry-after")
      assert {seconds, ""} = Integer.parse(retry_after)
      assert seconds > 0
    end)
  end

  defp login_params(csrf_token) do
    %{
      "_csrf_token" => csrf_token,
      "user" => %{"email" => "missing@example.test", "password" => "not-a-password"}
    }
  end

  defp csrf_token(body) do
    [_, token] = Regex.run(~r/name="_csrf_token"[^>]*value="([^"]+)"/, body)
    token
  end
end
EOF

  cat >> "config/test.exs" <<'EOF'

# Generated rate-limit probe: inject a bounded integer test limit before boot.
config :sigra, login_rate_limit: 2, login_rate_limit_window: 60_000
EOF
}

run_leg() {
  local flags="$1"
  local label="$2"
  local app_dir="${TMP_ROOT}/${label}"

  echo "==> passkeys-opt-out: leg=${label} flags=${flags}"

  cleanup_leg_dir "${app_dir}"
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
  # shellcheck disable=SC2086 # flags are fixed literals supplied below.
  MIX_ENV=dev mix sigra.install Accounts User users ${flags} --yes

  # `mix sigra.install` may inject dependencies into the fresh host (for
  # example Hammer for generated rate limiting). Refresh after installation,
  # before any generated-host assertion, probe, or compilation can load them.
  echo "==> passkeys-opt-out: fetching dependencies injected by sigra.install"
  MIX_ENV=dev mix deps.get

  echo "==> passkeys-opt-out: asserting omitted passkey assets, deps, config, and routes"
  assert_file_missing "assets/js/passkey_hooks.js"
  assert_file_missing "assets/js/passkey_browser.js"
  assert_no_match '@simplewebauthn/browser' "assets/package.json"
  assert_no_match '\{:wax_, "~> 0\.7"\}' "mix.exs"
  assert_no_match '^[[:space:]]*passkeys:[[:space:]]*\[' "config/config.exs"
  assert_no_match '/users/log_in/passkey' "lib/${label}_web/router.ex"
  assert_no_match '/users/settings/mfa/passkeys' "lib/${label}_web/router.ex"
  assert_no_match '/users/mfa/passkey' "lib/${label}_web/router.ex"

  if [[ "${label}" == "sigra_b2c_alpha" ]]; then
    echo "==> passkeys-opt-out: generating Google OAuth for B2C Alpha"
    add_cloak_ecto
    mix deps.get
    MIX_ENV=dev mix sigra.gen.oauth --providers google
    # OAuth generation may add a provider dependency as well. Keep every
    # generated dependency checked before the request probe and compilation.
    MIX_ENV=dev mix deps.get

    assert_file_present "lib/${label}/accounts/user_identity.ex"
    assert_file_present "lib/${label}/vault.ex"
    assert_file_present "lib/${label}/encrypted/binary.ex"
    assert_file_present "lib/${label}_web/controllers/oauth_controller.ex"
    assert_file_present "lib/${label}_web/controllers/oauth_html.ex"
    assert_file_present "lib/${label}_web/controllers/oauth_buttons.html.heex"
    assert_glob_missing "priv/repo/migrations/*_create_platform_admin_grants.exs"
    assert_glob_missing "priv/repo/migrations/*_create_organizations.exs"
    assert_glob_missing "priv/repo/migrations/*_create_user_passkeys.exs"
    if ! compgen -G "priv/repo/migrations/*_create_user_identities.exs" >/dev/null; then
      echo "FAIL: expected OAuth identity migration"
      exit 1
    fi

    router="lib/${label}_web/router.ex"
    config="config/config.exs"
    application="lib/${label}/application.ex"
    session_controller="lib/${label}_web/controllers/session_controller.ex"

    assert_match 'get "/log_in", SessionController, :new' "${router}"
    assert_match 'post "/log_in", SessionController, :create' "${router}"
    assert_match 'get "/log_in/:token", SessionController, :magic_link' "${router}"
    assert_match 'Auth.authenticate_user' "${session_controller}"
    assert_match 'def create\(conn, %\{"_action" => "magic_link"' "${session_controller}"
    assert_match 'Auth.deliver_user_magic_link_instructions' "${session_controller}"
    assert_match 'def magic_link\(conn, %\{"token" => token\}\)' "${session_controller}"
    assert_match 'Auth.verify_magic_link' "${session_controller}"

    assert_match '# Sigra OAuth' "${router}"
    assert_match 'get "/:provider", OAuthController, :request' "${router}"
    assert_match 'get "/:provider/callback", OAuthController, :callback' "${router}"
    assert_match '# Sigra OAuth providers' "${config}"
    assert_match 'GOOGLE_CLIENT_ID' "${config}"
    assert_match 'GOOGLE_CLIENT_SECRET' "${config}"
    assert_match 'Vault' "${application}"

    assert_file_missing "lib/${label}_web/components/admin_shell.ex"
    assert_file_missing "lib/${label}/sigra_admin_access.ex"
    assert_file_missing "priv/static/assets/sigra_admin.css"
    assert_file_missing "priv/static/images/sigra-logo-primary.svg"
    assert_file_missing "lib/${label}/accounts/organization.ex"
    assert_file_missing "lib/${label}/organizations.ex"
    assert_file_missing "lib/${label}/accounts/user_passkey.ex"
    assert_no_match '# Sigra admin' "${router}"
    assert_no_match '/admin' "lib/${label}_web/router.ex"
    assert_no_match '# Sigra organizations' "${router}"
    assert_no_match '/organizations' "lib/${label}_web/router.ex"
    assert_no_match '# Sigra passkeys' "${router}"
    assert_no_match 'passkey' "config/config.exs"

    assert_file_present "lib/${label}/rate_limit.ex"
    assert_match '\{:hammer, "~> 7\.4"\}' "mix.exs"
    assert_match 'SigraB2cAlpha.RateLimit' "${application}"
    assert_match 'hammer_module: SigraB2cAlpha.RateLimit' "${config}"
    assert_match 'Sigra.Plug.RateLimit' "${router}"
    assert_match 'limiter: Sigra.RateLimiters.Hammer' "${router}"

    echo "==> passkeys-opt-out: exercising bounded generated B2C login limiter"
    install_generated_rate_limit_probe
    MIX_ENV=test mix ecto.create
    MIX_ENV=test mix ecto.migrate
    MIX_ENV=test mix test test/generated_rate_limit_probe_test.exs
  fi

  echo "==> passkeys-opt-out: compiling and building assets"
  MIX_ENV=dev mix compile --warnings-as-errors
  MIX_ENV=dev mix assets.deploy

  echo "==> passkeys-opt-out: creating + migrating DB"
  MIX_ENV=dev mix ecto.drop || true
  MIX_ENV=dev mix ecto.create
  MIX_ENV=dev mix ecto.migrate

  echo "==> passkeys-opt-out: booting app and checking root responds"
  local env_name="SIGRA_PASSKEYS_${label^^}_PORT"
  local port="${!env_name:-$(find_free_port)}"
  local server_log="${app_dir}/server.log"
  PHX_SERVER=true MIX_ENV=dev PORT="${port}" mix phx.server > "${server_log}" 2>&1 &
  SERVER_PID=$!

  if curl --fail --silent --show-error --retry 30 --retry-connrefused --retry-delay 0 \
      "http://127.0.0.1:${port}/" > /dev/null; then
    echo "==> passkeys-opt-out: ${label} responded at http://127.0.0.1:${port}/"
    cleanup_server
    return 0
  fi

  echo "FAIL: ${label} did not become ready"
  cat "${server_log}"
  exit 1
}

echo "==> passkeys-opt-out: using Sigra repo at ${SIGRA_REPO}"

run_leg "--no-passkeys" "sigra_no_passkeys"
run_leg "--no-organizations --no-passkeys" "sigra_no_organizations_no_passkeys"
run_leg "--no-admin --no-organizations --no-passkeys" "sigra_b2c_alpha"

echo "==> passkeys-opt-out: success"
