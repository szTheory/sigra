#!/usr/bin/env bash
# Retained fresh-host acceptance proof for generated Google OAuth routes.
# It intentionally accepts only --probe-oauth: later plans may add explicit,
# allowlisted specs without broadening this credential-free B2C contract.
set -euo pipefail

CI_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/ci/lib/free-port.sh
source "${CI_DIR}/lib/free-port.sh"

SIGRA_REPO="${GITHUB_WORKSPACE:-$(pwd)}"
TMP_PARENT="${TMPDIR:-/tmp}"
TMP_ROOT="$(mktemp -d "${TMP_PARENT%/}/sigra-generated-auth-runtime-proof.XXXXXX")"
readonly TMP_ROOT
APP_NAME="sigra_b2c_auth_proof"
APP_DIR="${TMP_ROOT}/${APP_NAME}"
SERVER_PID=""
PORT=""
SERVER_LOG="${APP_DIR}/server.log"

export PGUSER="${PGUSER:-postgres}"
export PGPASSWORD="${PGPASSWORD:-postgres}"
export PGHOST="${PGHOST:-localhost}"
export CLOAK_KEY="${CLOAK_KEY:-MDEyMzQ1Njc4OWFiY2RlZjAxMjM0NTY3ODlhYmNkZWY=}"
# Proof inputs are constants below. Inherited provider credentials must never
# become a substitute for the local OIDC double.
unset GOOGLE_CLIENT_ID GOOGLE_CLIENT_SECRET

cleanup() {
  if [[ -n "${SERVER_PID}" ]]; then
    kill "${SERVER_PID}" 2>/dev/null || true
    wait "${SERVER_PID}" 2>/dev/null || true
  fi

  case "${TMP_ROOT}" in
    "${TMP_PARENT%/}"/sigra-generated-auth-runtime-proof.*) rm -rf -- "${TMP_ROOT}" ;;
    *) echo "FAIL: refusing to remove unexpected temporary root: ${TMP_ROOT}" >&2; return 1 ;;
  esac
}
trap cleanup EXIT

fail() { echo "FAIL: $*" >&2; exit 1; }

patch_mix_exs() {
  export SIGRA_REPO
  elixir -e '
    path = "mix.exs"
    content = File.read!(path)
    anchor = "      {:phoenix,"
    replacement = "      {:sigra, path: System.get_env(\"SIGRA_REPO\")},\n" <> anchor
    content == String.replace(content, anchor, replacement, global: false) &&
      raise "mix phx.new output did not contain the Phoenix dependency anchor"
    File.write!(path, String.replace(content, anchor, replacement, global: false))
  '
}

add_cloak_ecto() {
  elixir -e '
    path = "mix.exs"
    content = File.read!(path)
    anchor = "      {:sigra, path: System.get_env(\"SIGRA_REPO\")},\n"
    String.contains?(content, anchor) || raise "missing Sigra path dependency anchor"
    unless String.contains?(content, "{:cloak_ecto,") do
      File.write!(path, String.replace(content, anchor, anchor <> "      {:cloak_ecto, \"~> 1.3\"},\n", global: false))
    end
  '
}

write_oidc_double() {
  local web_module="SigraB2cAuthProofWeb"
  local callback="http://127.0.0.1:${PORT}/auth/google/callback"

  mkdir -p "lib/${APP_NAME}_web/controllers"
  cat > "lib/${APP_NAME}_web/controllers/oidc_double_controller.ex" <<EOF
defmodule ${web_module}.OidcDoubleController do
  use ${web_module}, :controller

  @issuer "http://127.0.0.1:${PORT}/oidc"
  @callback "http://127.0.0.1:${PORT}/auth/google/callback"
  @client_id "sigra-oauth-proof-client"
  @client_secret "sigra-oauth-proof-secret"
  @subject "sigra-oauth-proof-subject"
  @email "oauth-collision@example.test"
  @proof_key {__MODULE__, :pkce_challenge}

  def discovery(conn, _params) do
    json(conn, %{
      "issuer" => @issuer,
      "authorization_endpoint" => @issuer <> "/authorize",
      "token_endpoint" => @issuer <> "/token",
      "token_endpoint_auth_methods_supported" => ["client_secret_post"]
    })
  end

  def authorize(conn, params) do
    with "code" <- params["response_type"],
         @client_id <- params["client_id"],
         state when is_binary(state) and byte_size(state) > 20 <- params["state"],
         challenge when is_binary(challenge) and byte_size(challenge) > 20 <- params["code_challenge"],
         "S256" <- params["code_challenge_method"],
         {:ok, callback} <- loopback_callback(params["redirect_uri"]) do
      :persistent_term.put(@proof_key, challenge)
      Logger.info("oidc-double authorize accepted generated state and PKCE")
      redirect(conn, external: callback <> "?" <> URI.encode_query(%{"code" => "sigra-oauth-proof-code", "state" => state}))
    else
      _ -> send_resp(conn, 400, "invalid generated authorization request")
    end
  end

  def token(conn, params) do
    with "authorization_code" <- params["grant_type"],
         "sigra-oauth-proof-code" <- params["code"],
         @client_id <- params["client_id"],
         @client_secret <- params["client_secret"],
         challenge when is_binary(challenge) <- :persistent_term.get(@proof_key, nil),
         verifier when is_binary(verifier) and byte_size(verifier) > 20 <- params["code_verifier"],
         ^challenge <- verifier |> :crypto.hash(:sha256) |> Base.url_encode64(padding: false),
         {:ok, id_token} <- id_token() do
      Logger.info("oidc-double token accepted matching PKCE verifier and returned HS256 ID token")
      json(conn, %{"access_token" => "sigra-oauth-proof-access", "token_type" => "Bearer", "id_token" => id_token})
    else
      _ -> send_resp(conn, 400, "invalid generated token request")
    end
  end

  defp id_token do
    now = System.system_time(:second)
    Assent.JWTAdapter.sign(%{"iss" => @issuer, "sub" => @subject, "aud" => @client_id, "exp" => now + 300, "iat" => now, "email" => @email, "email_verified" => true, "name" => "OIDC Proof User"}, "HS256", @client_secret)
  end

  defp loopback_callback(@callback), do: {:ok, @callback}

  defp loopback_callback(_), do: :error
end
EOF

  cat >> config/config.exs <<EOF

# Generated-auth-runtime-proof: loopback-only Assent 0.3.1 Google/OIDC double.
config :${APP_NAME}, :sigra,
  oauth: [
    enabled: true,
    providers: [
      google: [
        base_url: "http://127.0.0.1:${PORT}/oidc",
        client_id: "sigra-oauth-proof-client",
        client_secret: "sigra-oauth-proof-secret",
        redirect_uri: "${callback}",
        id_token_signed_response_alg: "HS256",
        code_verifier: true
      ]
    ]
  ]
EOF

  # `sigra.gen.oauth` writes provider values into application config, while
  # the generated Accounts context owns the struct passed to controllers.
  # Wire that generated-host seam explicitly for this disposable proof only.
  elixir -e '
    path = "lib/'"${APP_NAME}"'/accounts.ex"
    content = File.read!(path)
    anchor = "      audit: [\n"
    addition = "      oauth: Application.fetch_env!(:'"${APP_NAME}"', :sigra)[:oauth],\n"
    String.contains?(content, addition) && raise "proof OAuth config already wired"
    String.contains?(content, anchor) || raise "Accounts sigra_config audit anchor not found"
    File.write!(path, String.replace(content, anchor, addition <> anchor, global: false))
  '

  elixir -e '
    path = "lib/'"${APP_NAME}"'_web/router.ex"
    content = File.read!(path)
    insertion = """
    scope \"/oidc\", '"${web_module}"' do
      pipe_through :api
      get \"/.well-known/openid-configuration\", OidcDoubleController, :discovery
      get \"/authorize\", OidcDoubleController, :authorize
      post \"/token\", OidcDoubleController, :token
    end
    """
    String.contains?(content, "OidcDoubleController") && raise "OIDC double routes already exist"
    trimmed = String.trim_trailing(content)
    String.ends_with?(trimmed, "\nend") || raise "router did not end with its module terminator"
    File.write!(path, String.replace_suffix(trimmed, "\nend", "\n" <> insertion <> "end") <> "\n")
  '
}

assert_locked_contract() {
  rg -q -- '--probe-oauth' "$0" || fail "focused probe entry point missing"
  rg -q 'base_url: "http://127\.0\.0\.1:' "config/config.exs" || fail "Google base_url is not loopback"
  rg -q 'id_token_signed_response_alg: "HS256"' "config/config.exs" || fail "HS256 contract missing"
  rg -q 'code_verifier: true' "config/config.exs" || fail "PKCE contract missing"
  rg -q 'oauth: Application.fetch_env!' "lib/${APP_NAME}/accounts.ex" || fail "generated config is not wired into Accounts"
  ! rg -q 'userinfo|jwks_uri|nonce:' "lib/${APP_NAME}_web/controllers/oidc_double_controller.ex" || fail "double grew an excluded OIDC dependency"
}

boot_and_run_probe() {
  PORT="${SIGRA_GENERATED_AUTH_PROOF_PORT:-$(find_free_port)}"
  [[ "${PORT}" =~ ^[0-9]+$ ]] || fail "proof port must be numeric"
  cd "${TMP_ROOT}"
  mix phx.new "${APP_NAME}" --no-install --no-dashboard --database postgres
  cd "${APP_DIR}"
  patch_mix_exs
  mix deps.get
  MIX_ENV=dev mix sigra.install Accounts User users --no-admin --no-organizations --no-passkeys --yes
  add_cloak_ecto
  mix deps.get
  MIX_ENV=dev mix sigra.gen.oauth --providers google
  write_oidc_double
  assert_locked_contract
  MIX_ENV=dev mix compile --warnings-as-errors
  MIX_ENV=dev mix assets.deploy
  MIX_ENV=dev mix ecto.drop || true
  MIX_ENV=dev mix ecto.create
  MIX_ENV=dev mix ecto.migrate
  PHX_SERVER=true MIX_ENV=dev PORT="${PORT}" mix phx.server >"${SERVER_LOG}" 2>&1 &
  SERVER_PID=$!
  for _ in $(seq 1 30); do
    curl -sf "http://127.0.0.1:${PORT}/" >/dev/null && break
    [[ -d "/proc/${SERVER_PID}" || "$(uname)" == "Darwin" ]] || { cat "${SERVER_LOG}"; fail "server exited before readiness"; }
    sleep 1
  done
  curl -sf "http://127.0.0.1:${PORT}/" >/dev/null || { cat "${SERVER_LOG}"; fail "generated host did not become ready"; }
  SIGRA_EXAMPLE_URL="http://127.0.0.1:${PORT}" node "${SIGRA_REPO}/test/example/priv/playwright/node_modules/@playwright/test/cli.js" test tests/generated-auth-oauth-probe.spec.ts --project=chromium --retries=0 --config "${SIGRA_REPO}/test/example/priv/playwright/playwright.config.ts"
  rg -q 'oidc-double authorize accepted generated state and PKCE' "${SERVER_LOG}" || fail "authorization double did not receive generated state/PKCE"
  rg -q 'oidc-double token accepted matching PKCE verifier' "${SERVER_LOG}" || fail "token double did not receive matching PKCE verifier"
}

[[ $# -eq 1 && "$1" == "--probe-oauth" ]] || { echo "Usage: $0 --probe-oauth" >&2; exit 64; }
echo "==> generated-auth-runtime-proof: using ${SIGRA_REPO}"
boot_and_run_probe
echo "==> generated-auth-runtime-proof: success"
