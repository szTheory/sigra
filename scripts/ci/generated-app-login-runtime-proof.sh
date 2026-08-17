#!/usr/bin/env bash
# Fresh-host proof for the first-party hosted and direct app-login ceremonies.
# It intentionally creates a disposable Phoenix host: no repository-private
# schemas, routes, or credentials are reused as evidence.
set -Eeuo pipefail

CI_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SIGRA_REPO="${GITHUB_WORKSPACE:-$(cd "${CI_DIR}/../.." && pwd)}"
TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/sigra-generated-app-login-runtime-proof.XXXXXX")"
ARTIFACT_DIR="${GENERATED_APP_LOGIN_RUNTIME_PROOF_ARTIFACT_DIR:-}"
APP_NAME="sigra_app_login_proof"
APP_DIR="${TMP_ROOT}/${APP_NAME}"
SERVER_PID=""
PORT="${GENERATED_APP_LOGIN_RUNTIME_PROOF_PORT:-4019}"
HOSTED_SUCCESS=false
DIRECT_SUCCESS=false
HOSTED_REPLAY_REJECTED=false
DIRECT_REPLAY_REJECTED=false
HOSTED_FETCH_APP_SESSION=false
DIRECT_FETCH_APP_SESSION=false
CONTROLLER_MFA_SESSION_UPGRADED=false
LIVEVIEW_MFA_SESSION_UPGRADED=false
APPROVAL_REPLAY_REJECTED=false
DIRECT_BACKUP_CODE_SUCCEEDED=false
BROWSER_REQUIRED_BEFORE_AUTHENTICATION=false
FETCH_APP_SESSION_EQUIVALENT=false
REFRESH_ROTATED=false
REFRESH_REUSE_FAMILY_REVOKED=false
REFRESH_REUSE_DENIED_NEXT_ACCESS=false
REVOKE_FAMILY_OWNER_ISOLATED=false
REVOKE_FAMILY_DENIED_NEXT_ACCESS=false
REVOKE_ALL_CURRENT_USER_ONLY=false
REVOKE_ALL_DENIED_NEXT_ACCESS=false
ROOT_TEST_DB_READY=false
CURRENT_STAGE="bootstrap"

export PGUSER="${PGUSER:-postgres}"
export PGPASSWORD="${PGPASSWORD:-postgres}"
export PGHOST="${PGHOST:-localhost}"
export PGPORT="${PGPORT:-5432}"
export PGDATABASE="${PGDATABASE:-sigra_test}"

set_stage() { CURRENT_STAGE="$1"; }

failure_diagnostic() {
  local rc="$1"
  local line="$2"
  printf 'generated host proof failed stage=%s line=%s exit=%s\n' "$CURRENT_STAGE" "$line" "$rc" >&2
}

cleanup() {
  local rc=$?
  trap - EXIT ERR INT TERM
  if [[ -n "${SERVER_PID}" ]]; then kill "${SERVER_PID}" 2>/dev/null || true; fi
  if [[ -n "${ARTIFACT_DIR}" ]]; then
    mkdir -p "${ARTIFACT_DIR}" || true
    [[ -f "${APP_DIR}/server.log" ]] && cp "${APP_DIR}/server.log" "${ARTIFACT_DIR}/server.log" || true
    [[ -f "${APP_DIR}/runtime-proof.json" ]] && cp "${APP_DIR}/runtime-proof.json" "${ARTIFACT_DIR}/runtime-proof.json" || true
  fi
  rm -rf "${TMP_ROOT}" || true
  exit "$rc"
}
trap 'failure_diagnostic "$?" "$LINENO"' ERR
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

require() { command -v "$1" >/dev/null || { echo "missing required command: $1" >&2; exit 69; }; }
run() { (cd "$1"; shift; "$@"); }

wait_for_http() {
  set_stage "server_readiness"
  local attempt=0
  until curl --fail --silent --show-error "http://127.0.0.1:${PORT}/" >/dev/null; do
    if ! kill -0 "$SERVER_PID" 2>/dev/null; then
      echo "generated host process exited before readiness; see ${APP_DIR}/server.log" >&2
      return 1
    fi

    attempt=$((attempt + 1))
    if (( attempt >= 30 )); then
      echo "generated host did not become ready within 30 bounded probes" >&2
      return 1
    fi
    # Bounded readiness polling, never a fixed proof delay.
    perl -e 'select undef, undef, undef, 0.2'
  done
}

csrf_token() {
  local page="$1"
  perl -0ne 'while (/<input\b(?=[^>]*\bname="_csrf_token")(?=[^>]*\bvalue="([^"]+)")[^>]*>/g) { print "$1\n"; last }' "$page"
}

mfa_response_diagnostic() {
  local response_kind="$1"
  local status="$2"
  local headers="$3"
  local page="$4"
  local content_type location_class body_class diagnostic_prefix

  content_type="$(sed -nE 's/^[Cc]ontent-[Tt]ype:[[:space:]]*([^;[:space:]]+).*/\1/p' "$headers" | head -n 1 | tr '[:upper:]' '[:lower:]')"
  case "$content_type" in
    text/html) content_type="html" ;;
    application/json) content_type="json" ;;
    "") content_type="missing" ;;
    *) content_type="other" ;;
  esac

  location_class="$(
    sed -nE 's/^[Ll]ocation:[[:space:]]*([^[:space:]]+).*/\1/p' "$headers" | head -n 1 | {
      read -r location || true
      case "$location" in
        /users/mfa*) printf '%s' "users_mfa" ;;
        /users/log_in*) printf '%s' "users_log_in" ;;
        "") printf '%s' "none" ;;
        *) printf '%s' "other" ;;
      esac
    }
  )"

  if grep -Fq 'id="mfa_totp_form"' "$page"; then
    body_class="mfa_form"
  elif grep -Fq 'name="_csrf_token"' "$page"; then
    body_class="csrf_input_only"
  elif grep -Fq 'name="csrf-token"' "$page"; then
    body_class="csrf_meta_only"
  elif grep -Fq 'FunctionClauseError' "$page"; then
    body_class="function_clause"
  elif grep -Fq 'CaseClauseError' "$page"; then
    body_class="case_clause"
  elif grep -Fq 'UndefinedFunctionError' "$page"; then
    body_class="undefined_function"
  elif grep -Fq 'Internal Server Error' "$page"; then
    body_class="server_error"
  else
    body_class="other"
  fi

  case "$response_kind" in
    completion) diagnostic_prefix="mfa completion response" ;;
    *) diagnostic_prefix="mfa response" ;;
  esac

  printf 'generated host proof %s status=%s redirect=%s content_type=%s body=%s\n' \
    "$diagnostic_prefix" "$status" "$location_class" "$content_type" "$body_class" >&2
  MFA_RESPONSE_BODY="$body_class"
}

direct_mfa_response_diagnostic() {
  local status="$1"
  local body="$2"
  local body_class="other"

  if grep -Fq '"error":"invalid_credentials"' "$body"; then
    body_class="invalid_credentials"
  elif grep -Eq '"(access_token|refresh_token|family_id)":"[^"]+"' "$body"; then
    body_class="credential_contract"
  elif grep -Fq '"error":"browser_required"' "$body"; then
    body_class="browser_required"
  fi

  printf 'generated host proof direct_mfa status=%s body=%s\n' "$status" "$body_class" >&2
}

fetch_mfa_form() {
  local base="$1"
  local cookie_jar="$2"
  local page="$3"
  local headers="$APP_DIR/hosted-mfa.headers"
  local content_type="$APP_DIR/hosted-mfa.content-type"
  local status

  if ! status="$(curl --silent --show-error --cookie "$cookie_jar" --cookie-jar "$cookie_jar" \
    -D "$headers" -o "$page" -w '%{http_code}' "$base/users/mfa")"; then
    printf 'generated host proof mfa response status=transport redirect=none content_type=missing body=other\n' >&2
    return 1
  fi

  sed -nE 's/^[Cc]ontent-[Tt]ype:[[:space:]]*([^;[:space:]]+).*/\1/p' "$headers" | head -n 1 > "$content_type"
  mfa_response_diagnostic "form" "$status" "$headers" "$page"
  [[ "$status" == "200" && "$MFA_RESPONSE_BODY" == "mfa_form" ]]
}

hosted_app_login_response_diagnostic() {
  local status="$1"
  local headers="$2"
  local page="$3"
  local content_type body_class undefined_function_signature

  content_type="$(sed -nE 's/^[Cc]ontent-[Tt]ype:[[:space:]]*([^;[:space:]]+).*/\1/p' "$headers" | head -n 1 | tr '[:upper:]' '[:lower:]')"
  case "$content_type" in
    text/html) content_type="html" ;;
    application/json) content_type="json" ;;
    "") content_type="missing" ;;
    *) content_type="other" ;;
  esac

  if grep -Fq 'data-testid="app-login-approval"' "$page"; then
    body_class="app_login_approval"
  elif grep -Fq 'name="_csrf_token"' "$page"; then
    body_class="csrf_input_only"
  elif grep -Fq '.AppLoginHTML.header/1' "$page"; then
    body_class="app_login_header"
  elif grep -Fq 'AppLoginContinuation.put/3' "$page"; then
    body_class="app_login_continuation_put"
  elif grep -Fq 'Plug.Conn.put_session/3' "$page"; then
    body_class="plug_put_session"
  elif grep -Fq 'Phoenix.Token.sign/3' "$page"; then
    body_class="phoenix_token_sign"
  elif grep -Fq '.Endpoint.config/1' "$page"; then
    body_class="endpoint_config"
  elif grep -Fq 'AppLoginContinuation.' "$page"; then
    body_class="app_login_continuation"
  elif grep -Fq 'AppLoginHTML.' "$page"; then
    body_class="app_login_html"
  elif grep -Fq 'Auth.AppSessions.' "$page"; then
    body_class="app_sessions_facade"
  elif grep -Fq 'Sigra.AppLogin.' "$page"; then
    body_class="sigra_app_login"
  elif grep -Fq 'Sigra.Branding.' "$page"; then
    body_class="sigra_branding"
  elif grep -Fq 'Phoenix.Token.' "$page"; then
    body_class="phoenix_token"
  elif grep -Fq 'FunctionClauseError' "$page"; then
    body_class="function_clause"
  elif grep -Fq 'CaseClauseError' "$page"; then
    body_class="case_clause"
  elif grep -Fq 'UndefinedFunctionError' "$page"; then
    body_class="undefined_function"
  else
    body_class="other"
  fi

  undefined_function_signature="$({ sed -nE 's/.*function ([[:alnum:]_.]+\/[[:digit:]]+) is undefined.*/\1/p' "$page" | head -n 1; } || true)"
  [[ -n "$undefined_function_signature" ]] || undefined_function_signature="none"

  printf 'generated host proof hosted app-login response status=%s content_type=%s body=%s undefined_function_signature=%s\n' \
    "$status" "$content_type" "$body_class" "$undefined_function_signature" >&2
  HOSTED_APP_LOGIN_BODY="$body_class"
}

hosted_exchange_response_diagnostic() {
  local status="$1"
  local headers="$2"
  local page="$3"
  local content_type body_class undefined_function_signature

  content_type="$(sed -nE 's/^[Cc]ontent-[Tt]ype:[[:space:]]*([^;[:space:]]+).*/\1/p' "$headers" | head -n 1 | tr '[:upper:]' '[:lower:]')"
  case "$content_type" in
    application/json) content_type="json" ;;
    text/html) content_type="html" ;;
    "") content_type="missing" ;;
    *) content_type="other" ;;
  esac

  if grep -Fq 'UndefinedFunctionError' "$page"; then
    body_class="undefined_function"
  elif grep -Fq 'FunctionClauseError' "$page"; then
    body_class="function_clause"
  elif grep -Fq 'CaseClauseError' "$page"; then
    body_class="case_clause"
  elif grep -Fq 'Internal Server Error' "$page"; then
    body_class="server_error"
  elif grep -Fq '"error"' "$page"; then
    body_class="error_response"
  else
    body_class="other"
  fi

  undefined_function_signature="$({ sed -nE 's/.*function ([[:alnum:]_.]+\/[[:digit:]]+) is undefined.*/\1/p' "$page" | head -n 1; } || true)"
  [[ -n "$undefined_function_signature" ]] || undefined_function_signature="none"

  printf 'generated host proof hosted exchange response status=%s content_type=%s body=%s undefined_function_signature=%s\n' \
    "$status" "$content_type" "$body_class" "$undefined_function_signature" >&2
}

json_field() {
  local field="$1"
  local path="$2"
  sed -nE "s/.*\"${field}\":\"([^\"]+)\".*/\\1/p" "$path" | head -n 1
}

install_proof_route() {
  local router="${APP_DIR}/lib/${APP_NAME}_web/router.ex"
  local controller="${APP_DIR}/lib/${APP_NAME}_web/controllers/app_login_proof_controller.ex"

  cat > "$controller" <<'EOF'
defmodule SigraAppLoginProofWeb.AppLoginProofController do
  use SigraAppLoginProofWeb, :controller

  def show(conn, _params) do
    scope = conn.assigns.current_scope
    auth = conn.private[:sigra_auth]

    json(conn, %{
      scope_user_id: scope.user.id,
      credential_kind: auth.credential_kind,
      credential_id: auth.credential_id,
      family_id: auth.family_id,
      scopes: auth.scopes,
      auth_method: auth.auth_method,
      assurance: auth.assurance
    })
  end
end
EOF

  perl -0pi -e 's/\nend\s*\z/\n  pipeline :app_session_proof do\n    plug Sigra.Plug.FetchAppSession,\n      config: \&SigraAppLoginProof.Accounts.Auth.AppSessions.sigra_config\/0,\n      scope_module: SigraAppLoginProof.Accounts.Scope\n    plug :require_app_session_proof\n  end\n\n  defp require_app_session_proof(%{assigns: %{current_scope: %{user: user}}} = conn) when not is_nil(user), do: conn\n\n  defp require_app_session_proof(conn) do\n    conn\n    |> Plug.Conn.send_resp(:unauthorized, ~s({\"error\":\"unauthenticated\"}))\n    |> Plug.Conn.halt()\n  end\n\n  scope "\/api", SigraAppLoginProofWeb do\n    pipe_through [:api, :app_session_proof]\n\n    get "\/app-login-proof", AppLoginProofController, :show\n  end\nend\n/' "$router"
  grep -Fq 'Sigra.Plug.FetchAppSession' "$router"
  grep -Fq 'require_app_session_proof' "$router"
  grep -Fq 'get "/app-login-proof", AppLoginProofController, :show' "$router"
}

prove_fetch_app_session() {
  local label="$1"
  local access_token="$2"
  local expected_family_id="$3"
  local body="${APP_DIR}/${label}-fetch-app-session.json"
  local status

  status="$(curl --silent --show-error -H "authorization: Bearer ${access_token}" \
    -o "$body" -w '%{http_code}' "http://127.0.0.1:${PORT}/api/app-login-proof")"
  [[ "$status" == "200" ]]
  [[ "$(json_field family_id "$body")" == "$expected_family_id" ]]
  [[ -n "$(json_field scope_user_id "$body")" ]]
  [[ -n "$(json_field credential_id "$body")" ]]
  grep -Fq '"credential_kind":"app_session"' "$body"
  grep -Fq '"auth_method":"app_session"' "$body"
  grep -Fq '"scopes":[]' "$body"
  grep -Fq '"assurance":[]' "$body"
  ! grep -Eq '"(access_token|refresh_token|digest|callback|state|challenge|client_ref|email|password)"' "$body"
  printf '%s\n' '{"credential_kind":"app_session","auth_method":"app_session","scopes":[],"assurance":[]}' > "${TMP_ROOT}/${label}-fetch-app-session-shape.json"
}

assert_access_denied() {
  local label="$1"
  local access_token="$2"
  local body="${APP_DIR}/${label}-access-denied.json"
  local status

  status="$(curl --silent --show-error -H "authorization: Bearer ${access_token}" \
    -o "$body" -w '%{http_code}' "http://127.0.0.1:${PORT}/api/app-login-proof")"
  [[ "$status" == "401" ]]
  ! grep -Eq '"(access_token|refresh_token|family_id|digest|callback|state|challenge|client_ref|email|password)"' "$body"
}

issue_refresh_control_family() {
  set_stage "refresh_control_fixture"
  run "$APP_DIR" mix run -e '
    alias SigraAppLoginProof.Accounts

    user = Accounts.get_user_by_email("hosted-proof@example.test")
    {:ok, credentials} = Sigra.AppSession.issue(Accounts.Auth.AppSessions.sigra_config(), user, "refresh-control")
    File.write!("refresh-control.json", Jason.encode!(credentials))
  '
}

assert_family_state() {
  local label="$1"
  local family_id="$2"
  local expected="$3"

  set_stage "${label}_typed_family_state"
  EXPECTED_FAMILY_ID="$family_id" EXPECTED_STATE="$expected" run "$APP_DIR" mix run -e '
    import Ecto.Query
    alias SigraAppLoginProof.Accounts
    alias SigraAppLoginProof.Repo

    family_id = System.fetch_env!("EXPECTED_FAMILY_ID")
    expected = System.fetch_env!("EXPECTED_STATE")
    family = Repo.get!(Accounts.UserAppSessionFamily, family_id)
    tokens = Repo.all(from token in Accounts.UserAppSessionToken, where: token.family_id == ^family_id)

    case expected do
      "revoked" ->
        if is_nil(family.revoked_at) or tokens == [] or Enum.any?(tokens, &is_nil(&1.revoked_at)), do: raise("family not terminal")
      "active" ->
        if not is_nil(family.revoked_at) or tokens == [] or Enum.any?(tokens, &(not is_nil(&1.revoked_at))), do: raise("control family not active")
    end
  '
}

prove_refresh_rotation() {
  local original_access_token="$1"
  local original_refresh_token="$2"
  local expected_family_id="$3"
  local response="${APP_DIR}/refresh-rotation.json"
  local status replacement_access_token replacement_refresh_token replacement_family_id

  set_stage "refresh_rotation"
  status="$(curl --silent --show-error -H 'content-type: application/json' \
    -d "{\"refresh_token\":\"${original_refresh_token}\"}" \
    -o "$response" -w '%{http_code}' "http://127.0.0.1:${PORT}/api/app-login/refresh")"
  [[ "$status" == "200" ]]
  [[ "$(grep -oE '\"(access_token|refresh_token|family_id|expires_in)\"' "$response" | sort | uniq -c | wc -l | tr -d ' ')" == "4" ]] || {
    echo "refresh response was not the exact credential shape" >&2
    return 1
  }
  replacement_access_token="$(json_field access_token "$response")"
  replacement_refresh_token="$(json_field refresh_token "$response")"
  replacement_family_id="$(json_field family_id "$response")"
  [[ -n "$replacement_access_token" && -n "$replacement_refresh_token" && -n "$replacement_family_id" ]]
  [[ "$replacement_access_token" != "$original_access_token" ]]
  [[ "$replacement_refresh_token" != "$original_refresh_token" ]]
  [[ "$replacement_family_id" == "$expected_family_id" ]]
  prove_fetch_app_session refresh "$replacement_access_token" "$expected_family_id" || {
    echo "replacement access token did not authenticate" >&2
    return 1
  }
  REFRESH_ROTATED=true
  status="$(curl --silent --show-error -H "authorization: Bearer ${original_refresh_token}" \
    -o "${APP_DIR}/refresh-as-access.json" -w '%{http_code}' "http://127.0.0.1:${PORT}/api/app-login-proof")"
  [[ "$status" == "401" ]] || {
    echo "refresh credential authenticated as an access credential" >&2
    return 1
  }
}

prove_refresh_reuse_revocation() {
  local original_refresh_token="$1"
  local replacement_access_token="$2"
  local replayed_family_id="$3"
  local control_body="${APP_DIR}/refresh-control.json"
  local response="${APP_DIR}/refresh-reuse.json"
  local status control_access_token control_family_id

  set_stage "refresh_reuse_replay"
  status="$(curl --silent --show-error -H 'content-type: application/json' \
    -d "{\"refresh_token\":\"${original_refresh_token}\"}" \
    -o "$response" -w '%{http_code}' "http://127.0.0.1:${PORT}/api/app-login/refresh")"
  [[ "$status" == "401" ]]
  grep -Fxq '{"error":"invalid_refresh"}' "$response"
  printf '%s\n' 'refresh_replay=unauthenticated family=revoked control_family=active next_access=denied' >&2

  assert_family_state refresh-reuse "$replayed_family_id" revoked
  control_access_token="$(json_field access_token "$control_body")"
  control_family_id="$(json_field family_id "$control_body")"
  [[ -n "$control_access_token" && -n "$control_family_id" ]]
  assert_family_state refresh-control "$control_family_id" active
  REFRESH_REUSE_FAMILY_REVOKED=true

  assert_access_denied refresh "$replacement_access_token"
  prove_fetch_app_session refresh-control "$control_access_token" "$control_family_id"
  REFRESH_REUSE_DENIED_NEXT_ACCESS=true
}

prepare_revocation_fixtures() {
  set_stage "revocation_fixtures"
  run "$APP_DIR" mix run -e '
    alias SigraAppLoginProof.Accounts
    alias SigraAppLoginProof.Repo

    owner = Accounts.get_user_by_email("hosted-proof@example.test")
    {:ok, foreign} = Accounts.register_user(%{"email" => "foreign-proof@example.test", "password" => "ForeignProofPassword123!"})
    foreign = foreign |> Ecto.Changeset.change(confirmed_at: DateTime.utc_now() |> DateTime.truncate(:second)) |> Repo.update!()
    config = Accounts.Auth.AppSessions.sigra_config()
    {:ok, owned} = Sigra.AppSession.issue(config, owner, "revoke-owned")
    {:ok, remaining} = Sigra.AppSession.issue(config, owner, "revoke-remaining")
    {:ok, foreign_control} = Sigra.AppSession.issue(config, foreign, "revoke-foreign")
    File.write!("revocation-fixtures.json", Jason.encode!(%{
      owned_access_token: owned.access_token, owned_family_id: owned.family_id,
      remaining_access_token: remaining.access_token, remaining_family_id: remaining.family_id,
      foreign_access_token: foreign_control.access_token, foreign_family_id: foreign_control.family_id
    }))
  '
}

prove_revoke_family_owner_isolation() {
  local base="$1" cookie_jar="$2" csrf="$3"
  local fixture="${APP_DIR}/revocation-fixtures.json"
  local foreign_id owned_id foreign_access owned_access remaining_access remaining_id status

  prepare_revocation_fixtures
  foreign_id="$(json_field foreign_family_id "$fixture")"
  owned_id="$(json_field owned_family_id "$fixture")"
  foreign_access="$(json_field foreign_access_token "$fixture")"
  owned_access="$(json_field owned_access_token "$fixture")"
  remaining_access="$(json_field remaining_access_token "$fixture")"
  remaining_id="$(json_field remaining_family_id "$fixture")"

  status="$(curl --silent --show-error -H 'content-type: application/json' -d "{\"family_id\":\"${foreign_id}\"}" -o "${APP_DIR}/revoke-foreign.json" -w '%{http_code}' "$base/users/app-sessions/revoke")"
  [[ "$status" != "200" ]]
  status="$(curl --silent --show-error --cookie "$cookie_jar" -H 'content-type: application/json' -d "{\"family_id\":\"${owned_id}\"}" -o "${APP_DIR}/revoke-missing-csrf.json" -w '%{http_code}' "$base/users/app-sessions/revoke")"
  [[ "$status" != "200" ]]
  status="$(curl --silent --show-error --cookie "$cookie_jar" -H 'content-type: application/json' -H "x-csrf-token: ${csrf}" -d "{\"family_id\":\"${foreign_id}\"}" -o "${APP_DIR}/revoke-foreign.json" -w '%{http_code}' "$base/users/app-sessions/revoke")"
  [[ "$status" == "404" ]] && grep -Fxq '{"error":"not_found"}' "${APP_DIR}/revoke-foreign.json"
  assert_family_state revoke-foreign "$foreign_id" active
  prove_fetch_app_session revoke-foreign "$foreign_access" "$foreign_id"

  status="$(curl --silent --show-error --cookie "$cookie_jar" -H 'content-type: application/json' -H "x-csrf-token: ${csrf}" -d "{\"family_id\":\"${owned_id}\"}" -o "${APP_DIR}/revoke-owned.json" -w '%{http_code}' "$base/users/app-sessions/revoke")"
  [[ "$status" == "200" ]] && grep -Fxq '{"ok":true}' "${APP_DIR}/revoke-owned.json"
  assert_family_state revoke-owned "$owned_id" revoked
  assert_access_denied revoke-owned "$owned_access"
  prove_fetch_app_session revoke-remaining "$remaining_access" "$remaining_id"
  REVOKE_FAMILY_OWNER_ISOLATED=true
  REVOKE_FAMILY_DENIED_NEXT_ACCESS=true
  printf '%s\n' 'revoke_family_owner_isolated=true revoke_family_denied_next_access=true' >&2
}

prove_revoke_all() {
  local base="$1" cookie_jar="$2" csrf="$3"
  local fixture="${APP_DIR}/revocation-fixtures.json"
  local remaining_access remaining_id foreign_access foreign_id status

  remaining_access="$(json_field remaining_access_token "$fixture")"
  remaining_id="$(json_field remaining_family_id "$fixture")"
  foreign_access="$(json_field foreign_access_token "$fixture")"
  foreign_id="$(json_field foreign_family_id "$fixture")"
  status="$(curl --silent --show-error --cookie "$cookie_jar" -H 'content-type: application/json' -H "x-csrf-token: ${csrf}" -d '{}' -o "${APP_DIR}/revoke-all.json" -w '%{http_code}' "$base/users/app-sessions/revoke-all")"
  [[ "$status" == "200" ]] && grep -Fxq '{"ok":true}' "${APP_DIR}/revoke-all.json"
  assert_family_state revoke-remaining "$remaining_id" revoked
  assert_family_state revoke-foreign "$foreign_id" active
  assert_access_denied revoke-all "$remaining_access"
  prove_fetch_app_session revoke-foreign "$foreign_access" "$foreign_id"
  REVOKE_ALL_CURRENT_USER_ONLY=true
  REVOKE_ALL_DENIED_NEXT_ACCESS=true
  printf '%s\n' 'revoke_all_current_user_only=true revoke_all_denied_next_access=true' >&2
}

assert_one_family() {
  local label="$1"
  local expected_kind="$2"

  set_stage "${label}_family_count_aggregate"
  EXPECTED_KIND="$expected_kind" EXPECTED_LABEL="$label" run "$APP_DIR" mix run -e '
    alias SigraAppLoginProof.Accounts
    alias SigraAppLoginProof.Repo

    expected_kind = System.fetch_env!("EXPECTED_KIND")
    count = Repo.aggregate(Accounts.UserAppSessionFamily, :count, :id)
    attempts = Repo.all(Accounts.UserAppLoginAttempt)
    attempt_count = Enum.count(attempts, fn attempt ->
      is_atom(attempt.kind) and Atom.to_string(attempt.kind) == expected_kind
    end)
    family_class = case count do zero when zero <= 0 -> "zero"; 1 -> "one"; _ -> "many" end
    attempt_class = case attempt_count do zero when zero <= 0 -> "zero"; 1 -> "one"; _ -> "many" end
    :ok = IO.puts(:stderr, :io_lib.format("generated host proof family_count family=~s attempt=~s~n", [family_class, attempt_class]))
    if count != 1, do: raise("unexpected app-session family count class")
    if attempt_count != 1, do: raise("unexpected app-login attempt count class")
  '
}

ensure_root_test_db() {
  [[ "$ROOT_TEST_DB_READY" == true ]] && return 0
  set_stage "root_test_db_uuid_ossp"
  run "$SIGRA_REPO" env MIX_ENV=test mix run --no-start -r test/support/postgres_test_repo.ex -r test/support/root_app_session_schema.ex -e '
    config = Sigra.Test.PostgresRepo.default_config()

    case Ecto.Adapters.Postgres.storage_up(config) do
      :ok -> :ok
      {:error, :already_up} -> :ok
      other -> raise "could not provision root test database: #{inspect(other)}"
    end

    bootstrap_config = Keyword.put(config, :pool, DBConnection.ConnectionPool)
    {:ok, pid} = Sigra.Test.PostgresRepo.start_link(bootstrap_config)
    Ecto.Adapters.SQL.query!(Sigra.Test.PostgresRepo, ~s(CREATE EXTENSION IF NOT EXISTS "uuid-ossp"), [])
    Ecto.Migrator.up(
      Sigra.Test.PostgresRepo,
      Sigra.Test.RootAppSessionSchema.version(),
      Sigra.Test.RootAppSessionSchema,
      log: false
    )
    GenServer.stop(pid)
  ' >/dev/null
  ROOT_TEST_DB_READY=true
}

prove_hosted_replay() {
  local code="$1"
  local verifier="$2"
  local access_token="$3"
  local family_id="$4"
  local status

  status="$(curl --silent --show-error -H 'content-type: application/json' \
    -d "{\"code\":\"$code\",\"code_verifier\":\"$verifier\",\"profile_id\":\"ios-primary\",\"callback\":\"http://127.0.0.1:49152/callback\"}" \
    -D "${APP_DIR}/hosted-replay.headers" -o "${APP_DIR}/hosted-replay.json" -w '%{http_code}' "http://127.0.0.1:${PORT}/api/app-login/exchange")"
  hosted_exchange_response_diagnostic "$status" "${APP_DIR}/hosted-replay.headers" "${APP_DIR}/hosted-replay.json"
  [[ "$status" == "400" ]]
  prove_fetch_app_session hosted "$access_token" "$family_id" || {
    echo "hosted credential did not remain valid after replay" >&2
    return 1
  }
  assert_one_family hosted hosted_code
}

prove_direct_replay() {
  local challenge="$1"
  local backup_code="$2"
  local access_token="$3"
  local family_id="$4"
  local status

  status="$(curl --silent --show-error -H 'content-type: application/json' \
    -d "{\"challenge\":\"$challenge\",\"code\":\"$backup_code\",\"factor\":\"backup_code\"}" \
    -o "${APP_DIR}/direct-replay.json" -w '%{http_code}' "http://127.0.0.1:${PORT}/api/app-login/direct/mfa")"
  [[ "$status" == "401" ]]
  grep -Fxq '{"error":"invalid_credentials"}' "${APP_DIR}/direct-replay.json"
  prove_fetch_app_session direct "$access_token" "$family_id" || {
    echo "direct credential did not remain valid after replay" >&2
    return 1
  }
  assert_one_family direct direct_mfa
}

seed_confirmed_user() {
  set_stage "hosted_fixture_seed"
  # The disposable host owns this deterministic fixture identity. Browser
  # authentication still happens through the generated login route and cookie jar.
  run "$APP_DIR" mix run -e '
    alias SigraAppLoginProof.Accounts
    alias SigraAppLoginProof.Repo

    {:ok, user} = Accounts.register_user(%{"email" => "hosted-proof@example.test", "password" => "HostedProofPassword123!"})
    user = user |> Ecto.Changeset.change(confirmed_at: DateTime.utc_now() |> DateTime.truncate(:second)) |> Repo.update!()

    %{backup_codes: [backup_code]} =
      Sigra.Testing.setup_totp(user,
        config: Accounts.sigra_config(),
        mfa_credential_schema: Accounts.UserMFACredential,
        backup_code_schema: Accounts.UserBackupCode,
        backup_code_count: 1
      )

    File.write!("hosted-backup-code", backup_code)
  '
}

seed_direct_mfa_user() {
  set_stage "direct_fixture_seed"
  # This uses only generated-host schemas and the shipped Sigra MFA helper;
  # the one plaintext backup code remains in the disposable host directory.
  run "$APP_DIR" mix run -e '
    alias SigraAppLoginProof.Accounts
    alias SigraAppLoginProof.Repo

    {:ok, user} = Accounts.register_user(%{"email" => "direct-proof@example.test", "password" => "DirectProofPassword123!"})
    user = user |> Ecto.Changeset.change(confirmed_at: DateTime.utc_now() |> DateTime.truncate(:second)) |> Repo.update!()

    %{backup_codes: [backup_code]} =
      Sigra.Testing.setup_totp(user,
        config: Accounts.sigra_config(),
        mfa_credential_schema: Accounts.UserMFACredential,
        backup_code_schema: Accounts.UserBackupCode,
        backup_code_count: 1
      )

    File.write!("direct-backup-code", backup_code)
  '
}

prove_direct_mfa_ceremony() {
  set_stage "direct_ceremony"
  local base="http://127.0.0.1:${PORT}"
  local direct_body="${APP_DIR}/direct-start.json"
  local mfa_body="${APP_DIR}/direct-mfa.json"
  local invalid_body="${APP_DIR}/direct-invalid-factor.json"
  local challenge backup_code status access_token family_id

  seed_direct_mfa_user
  backup_code="$(<"${APP_DIR}/direct-backup-code")"
  [[ -n "$backup_code" ]]

  status="$(curl --silent --show-error -H 'content-type: application/json' \
    -d '{"profile_id":"android-primary","email":"direct-proof@example.test","password":"DirectProofPassword123!"}' \
    -o "$direct_body" -w '%{http_code}' "$base/api/app-login/direct")"
  [[ "$status" =~ ^2[0-9][0-9]$ ]]
  challenge="$(sed -nE 's/.*"mfa_challenge":"([^"]+)".*/\1/p' "$direct_body")"
  [[ -n "$challenge" ]]
  ! grep -Eq '"(access_token|refresh_token|family_id)":' "$direct_body"

  status="$(curl --silent --show-error -H 'content-type: application/json' \
    -d "{\"challenge\":\"$challenge\",\"code\":\"$backup_code\",\"factor\":\"backup_code\"}" \
    -o "$mfa_body" -w '%{http_code}' "$base/api/app-login/direct/mfa")"
  direct_mfa_response_diagnostic "$status" "$mfa_body"
  [[ "$status" =~ ^2[0-9][0-9]$ ]]
  grep -Eq '"access_token":"[^"]+"' "$mfa_body"
  grep -Eq '"refresh_token":"[^"]+"' "$mfa_body"
  grep -Eq '"family_id":"[^"]+"' "$mfa_body"
  access_token="$(json_field access_token "$mfa_body")"
  family_id="$(json_field family_id "$mfa_body")"
  [[ -n "$access_token" && -n "$family_id" ]]
  prove_fetch_app_session direct "$access_token" "$family_id"

  DIRECT_CHALLENGE="$challenge" DIRECT_BACKUP_CODE="$backup_code" run "$APP_DIR" mix run -e '
    alias SigraAppLoginProof.Accounts
    alias SigraAppLoginProof.Repo

    challenge = System.fetch_env!("DIRECT_CHALLENGE")
    backup_code = System.fetch_env!("DIRECT_BACKUP_CODE")
    attempt = Repo.one!(Accounts.UserAppLoginAttempt)
    backup = Repo.one!(Accounts.UserBackupCode)

    if is_nil(attempt.consumed_at), do: raise("direct-mfa challenge was not consumed")
    if is_nil(backup.used_at), do: raise("backup code was not consumed")
    if attempt.digest == challenge, do: raise("raw challenge persisted in ceremony row")
    if backup.hashed_code == backup_code, do: raise("raw backup code persisted")
  '

  prove_direct_replay "$challenge" "$backup_code" "$access_token" "$family_id"
  status="$(curl --silent --show-error -H 'content-type: application/json' \
    -d '{"profile_id":"ios-primary","email":"not-a-real-user@example.test","password":"not-a-password"}' \
    -o "${APP_DIR}/direct-browser-required.json" -w '%{http_code}' "$base/api/app-login/direct")"
  [[ "$status" == "403" ]]
  grep -Fxq '{"error":"browser_required"}' "${APP_DIR}/direct-browser-required.json"
  # Do not compare captured `mix run` output: generated-host logger configuration
  # can emit non-deterministic lines around an otherwise identical aggregate.
  # The typed assertion verifies that browser-required returned before creating
  # another family or altering the direct MFA attempt.
  assert_one_family direct direct_mfa
  DIRECT_SUCCESS=true
  DIRECT_REPLAY_REJECTED=true
  DIRECT_FETCH_APP_SESSION=true
  DIRECT_BACKUP_CODE_SUCCEEDED=true
  BROWSER_REQUIRED_BEFORE_AUTHENTICATION=true
}

prove_hosted_ceremony() {
  set_stage "hosted_ceremony"
  local base="http://127.0.0.1:${PORT}"
  local cookie_jar="${APP_DIR}/hosted-cookie-jar.txt"
  local login_page="${APP_DIR}/hosted-login.html"
  local approval_page="${APP_DIR}/hosted-approval.html"
  local approval_headers="${APP_DIR}/hosted-approval.headers"
  local app_login_headers="${APP_DIR}/hosted-app-login.headers"
  local exchange_body="${APP_DIR}/hosted-exchange.json"
  local login_csrf mfa_csrf approval_csrf sudo_csrf verifier challenge callback code state status access_token refresh_token family_id backup_code
  local mfa_completion_headers="${APP_DIR}/hosted-mfa-completion.headers"
  local mfa_completion_body="${APP_DIR}/hosted-mfa-completion.html"

  seed_confirmed_user
  set_stage "hosted_login_form"
  curl --fail --silent --show-error --cookie-jar "$cookie_jar" -o "$login_page" "$base/users/log_in"
  login_csrf="$(csrf_token "$login_page")"
  [[ -n "$login_csrf" ]]
  curl --fail --silent --show-error --cookie "$cookie_jar" --cookie-jar "$cookie_jar" \
    --data-urlencode "_csrf_token=$login_csrf" \
    --data-urlencode "user[email]=hosted-proof@example.test" \
    --data-urlencode "user[password]=HostedProofPassword123!" \
    -o /dev/null -D /dev/null "$base/users/log_in"
  set_stage "hosted_mfa_form"
  fetch_mfa_form "$base" "$cookie_jar" "$APP_DIR/hosted-mfa.html"
  mfa_csrf="$(csrf_token "${APP_DIR}/hosted-mfa.html")"
  backup_code="$(<"${APP_DIR}/hosted-backup-code")"
  [[ -n "$mfa_csrf" && -n "$backup_code" ]]
  status="$(curl --silent --show-error --cookie "$cookie_jar" --cookie-jar "$cookie_jar" \
    --data-urlencode "_csrf_token=$mfa_csrf" \
    --data-urlencode 'mfa[method]=backup' \
    --data-urlencode "mfa[code]=$backup_code" \
    -D "$mfa_completion_headers" -o "$mfa_completion_body" -w '%{http_code}' "$base/users/mfa")"
  mfa_response_diagnostic "completion" "$status" "$mfa_completion_headers" "$mfa_completion_body"
  [[ "$status" =~ ^30[23]$ ]]
  curl --fail --silent --show-error --cookie "$cookie_jar" --cookie-jar "$cookie_jar" -o "${APP_DIR}/hosted-sudo.html" "$base/users/sudo?return_to=/"
  sudo_csrf="$(csrf_token "${APP_DIR}/hosted-sudo.html")"
  [[ -n "$sudo_csrf" ]]
  curl --fail --silent --show-error --cookie "$cookie_jar" --cookie-jar "$cookie_jar" --data-urlencode "_csrf_token=$sudo_csrf" --data-urlencode 'sudo[password]=HostedProofPassword123!' --data-urlencode 'sudo[return_to]=/' -o /dev/null "$base/users/sudo"

  verifier="$(openssl rand -base64 48 | tr '+/' '-_' | tr -d '=\n')"
  challenge="$(printf '%s' "$verifier" | openssl dgst -binary -sha256 | openssl base64 -A | tr '+/' '-_' | tr -d '=')"
  status="$(curl --silent --show-error --cookie "$cookie_jar" --cookie-jar "$cookie_jar" --get \
    --data-urlencode 'profile_id=ios-primary' \
    --data-urlencode 'callback=http://127.0.0.1:49152/callback' \
    --data-urlencode 'state=hosted-runtime-state' \
    --data-urlencode "code_challenge=$challenge" \
    --data-urlencode 'code_challenge_method=S256' \
    -D "$app_login_headers" -o "$approval_page" -w '%{http_code}' "$base/users/app-login")"
  hosted_app_login_response_diagnostic "$status" "$app_login_headers" "$approval_page"
  [[ "$status" == "200" && "$HOSTED_APP_LOGIN_BODY" == "app_login_approval" ]]
  approval_csrf="$(csrf_token "$approval_page")"
  [[ -n "$approval_csrf" ]]
  cp "$cookie_jar" "${APP_DIR}/hosted-approval-cookie-jar.txt"
  status="$(curl --silent --show-error --cookie "${APP_DIR}/hosted-approval-cookie-jar.txt" \
    --data-urlencode "_csrf_token=$approval_csrf" \
    -D "$approval_headers" -o /dev/null -w '%{http_code}' "$base/users/app-login/approve")"
  [[ "$status" =~ ^30[23]$ ]]
  callback="$(awk 'tolower($1) == "location:" {sub(/^[^:]*:[[:space:]]*/, ""); sub(/\r$/, ""); print; exit}' "$approval_headers")"
  [[ "$callback" == 'http://127.0.0.1:49152/callback?code='*'&state=hosted-runtime-state' ]]
  status="$(curl --silent --show-error --cookie "${APP_DIR}/hosted-approval-cookie-jar.txt" \
    --data-urlencode "_csrf_token=$approval_csrf" \
    -o "${APP_DIR}/hosted-approval-replay.html" -w '%{http_code}' "$base/users/app-login/approve")"
  [[ "$status" == "400" ]]
  code="$(printf '%s' "$callback" | sed -nE 's|.*[?&]code=([^&]+).*|\1|p')"
  state="$(printf '%s' "$callback" | sed -nE 's|.*[?&]state=([^&]+).*|\1|p')"
  [[ -n "$code" && "$state" == 'hosted-runtime-state' ]]
  run "$APP_DIR" mix run -e '
    attempt = SigraAppLoginProof.Repo.one!(SigraAppLoginProof.Accounts.UserAppLoginAttempt)
    unless attempt.kind == :hosted_code, do: raise("hosted attempt kind was not persisted")
  '
  status="$(curl --silent --show-error -H 'content-type: application/json' \
    -d "{\"code\":\"$code\",\"code_verifier\":\"$verifier\",\"profile_id\":\"ios-primary\",\"callback\":\"http://127.0.0.1:49152/callback\"}" \
    -D "$APP_DIR/hosted-exchange.headers" -o "$exchange_body" -w '%{http_code}' "$base/api/app-login/exchange")"
  hosted_exchange_response_diagnostic "$status" "$APP_DIR/hosted-exchange.headers" "$exchange_body"
  [[ "$status" =~ ^2[0-9][0-9]$ ]]
  grep -Eq '"access_token":"[^"]+"' "$exchange_body"
  grep -Eq '"refresh_token":"[^"]+"' "$exchange_body"
  grep -Eq '"family_id":"[^"]+"' "$exchange_body"
  access_token="$(json_field access_token "$exchange_body")"
  refresh_token="$(json_field refresh_token "$exchange_body")"
  family_id="$(json_field family_id "$exchange_body")"
  [[ -n "$access_token" && -n "$refresh_token" && -n "$family_id" ]]
  prove_fetch_app_session hosted "$access_token" "$family_id"
  issue_refresh_control_family
  prove_refresh_rotation "$access_token" "$refresh_token" "$family_id"
  prove_refresh_reuse_revocation "$refresh_token" "$(json_field access_token "${APP_DIR}/refresh-rotation.json")" "$family_id"
  prove_revoke_family_owner_isolation "$base" "$cookie_jar" "$sudo_csrf"
  prove_revoke_all "$base" "$cookie_jar" "$sudo_csrf"

  prove_hosted_replay "$code" "$verifier" "$access_token" "$family_id"
  HOSTED_SUCCESS=true
  HOSTED_REPLAY_REJECTED=true
  HOSTED_FETCH_APP_SESSION=true
  CONTROLLER_MFA_SESSION_UPGRADED=true
  APPROVAL_REPLAY_REJECTED=true
}

patch_host() {
  local database="$1"
  (
    cd "$APP_DIR"
    perl -0pi -e 's/(\{:\s*phoenix,)/{:sigra, path: "'"${SIGRA_REPO//\//\\/}"'"},\n      $1/' mix.exs
    perl -0pi -e 's/database: "sigra_app_login_proof_dev",/database: "'"${database}"'",/' config/dev.exs
    perl -0pi -e 's/database: "sigra_app_login_proof_test#\{System\.get_env\("MIX_TEST_PARTITION"\)\}",/database: "'"${database}"'",/' config/test.exs
    perl -0pi -e 's/hostname: "localhost",/hostname: System.fetch_env!("PGHOST"),/' config/test.exs
    perl -0pi -e 's/pool: Ecto\.Adapters\.SQL\.Sandbox/port: String.to_integer(System.fetch_env!("PGPORT")),\n  pool: Ecto.Adapters.SQL.Sandbox/' config/test.exs
  )
}

assert_inventory() {
  local router="lib/${APP_NAME}_web/router.ex"
  local mode="$1"
  grep -Fq 'AppLoginController' "$router"
  # Generated router must retain the app_login_public rate-limited boundary.
  grep -Fq 'app_login_public' "$router"
  grep -Fq 'FetchAppSession' "$router"
  if [[ "$mode" == hosted ]]; then
    ! grep -Fq 'post "/direct"' "$router"
  else
    grep -Fq 'post "/direct"' "$router"
  fi
  ! grep -Fq 'FetchAPIToken' "$router"
  ! grep -Fq 'FetchJWT' "$router"
}

write_receipt_last() {
  local app_login_sha fetch_app_session_sha controller_sha continuation_sha attempt_schema_sha migration_sha facade_sha router_sha mfa_controller_sha mfa_live_sha script_sha workflow_sha source_test_sha evidence_test_sha mfa_upgrade_test_sha concurrency_test_sha receipt_tmp receipt

  [[ "$HOSTED_SUCCESS" == true && "$DIRECT_SUCCESS" == true ]]
  [[ "$HOSTED_REPLAY_REJECTED" == true && "$DIRECT_REPLAY_REJECTED" == true ]]
  [[ "$HOSTED_FETCH_APP_SESSION" == true && "$DIRECT_FETCH_APP_SESSION" == true ]]
  [[ "$CONTROLLER_MFA_SESSION_UPGRADED" == true && "$LIVEVIEW_MFA_SESSION_UPGRADED" == true ]]
  [[ "$APPROVAL_REPLAY_REJECTED" == true && "$DIRECT_BACKUP_CODE_SUCCEEDED" == true ]]
  [[ "$BROWSER_REQUIRED_BEFORE_AUTHENTICATION" == true && "$FETCH_APP_SESSION_EQUIVALENT" == true ]]
  [[ "$REFRESH_ROTATED" == true && "$REFRESH_REUSE_FAMILY_REVOKED" == true && "$REFRESH_REUSE_DENIED_NEXT_ACCESS" == true ]]
  [[ "$REVOKE_FAMILY_OWNER_ISOLATED" == true && "$REVOKE_FAMILY_DENIED_NEXT_ACCESS" == true && "$REVOKE_ALL_CURRENT_USER_ONLY" == true && "$REVOKE_ALL_DENIED_NEXT_ACCESS" == true ]]

  app_login_sha="$(sha256sum "${SIGRA_REPO}/lib/sigra/app_login.ex" | awk '{print $1}')"
  fetch_app_session_sha="$(sha256sum "${SIGRA_REPO}/lib/sigra/plug/fetch_app_session.ex" | awk '{print $1}')"
  controller_sha="$(sha256sum "${SIGRA_REPO}/priv/templates/sigra.install/app_sessions/app_login_controller.ex" | awk '{print $1}')"
  continuation_sha="$(sha256sum "${SIGRA_REPO}/priv/templates/sigra.install/app_sessions/app_login_continuation.ex" | awk '{print $1}')"
  attempt_schema_sha="$(sha256sum "${SIGRA_REPO}/priv/templates/sigra.install/app_sessions/user_app_login_attempt.ex" | awk '{print $1}')"
  migration_sha="$(sha256sum "${SIGRA_REPO}/priv/templates/sigra.install/app_sessions/app_sessions_migration.exs" | awk '{print $1}')"
  facade_sha="$(sha256sum "${SIGRA_REPO}/priv/templates/sigra.install/app_sessions/auth_app_sessions.ex" | awk '{print $1}')"
  router_sha="$(sha256sum "${SIGRA_REPO}/priv/templates/sigra.install/app_sessions/router_injection.ex" | awk '{print $1}')"
  mfa_controller_sha="$(sha256sum "${SIGRA_REPO}/priv/templates/sigra.install/core/mfa_challenge_controller.ex" | awk '{print $1}')"
  mfa_live_sha="$(sha256sum "${SIGRA_REPO}/priv/templates/sigra.install/core/mfa_challenge_live.ex" | awk '{print $1}')"
  script_sha="$(sha256sum "${SIGRA_REPO}/scripts/ci/generated-app-login-runtime-proof.sh" | awk '{print $1}')"
  workflow_sha="$(sha256sum "${SIGRA_REPO}/.github/workflows/generated-app-login-runtime-proof.yml" | awk '{print $1}')"
  source_test_sha="$(sha256sum "${SIGRA_REPO}/test/sigra/planning/phase_246_generated_app_login_runtime_test.exs" | awk '{print $1}')"
  evidence_test_sha="$(sha256sum "${SIGRA_REPO}/test/sigra/planning/phase_246_runtime_evidence_contract_test.exs" | awk '{print $1}')"
  mfa_upgrade_test_sha="$(sha256sum "${SIGRA_REPO}/test/sigra/install/app_sessions_mfa_session_upgrade_test.exs" | awk '{print $1}')"
  concurrency_test_sha="$(sha256sum "${SIGRA_REPO}/test/sigra/app_login/concurrency_test.exs" | awk '{print $1}')"
  receipt_tmp="${APP_DIR}/runtime-proof.json.tmp"
  receipt="${APP_DIR}/runtime-proof.json"

  # receipt-last: every transition must pass before this final atomic publish.
  printf '%s\n' "{\"schema\":\"sigra.generated-app-login-runtime-proof/v4\",\"status\":\"passed\",\"controller_mfa_session_upgraded\":true,\"liveview_mfa_session_upgraded\":true,\"approval_replay_rejected\":true,\"direct_backup_code_succeeded\":true,\"hosted_replay_rejected\":true,\"direct_replay_rejected\":true,\"fetch_app_session_equivalent\":true,\"browser_required_before_authentication\":true,\"refresh_rotated\":true,\"refresh_reuse_family_revoked\":true,\"refresh_reuse_denied_next_access\":true,\"revoke_family_owner_isolated\":true,\"revoke_family_denied_next_access\":true,\"revoke_all_current_user_only\":true,\"revoke_all_denied_next_access\":true,\"sources\":{\"app_login\":\"${app_login_sha}\",\"fetch_app_session\":\"${fetch_app_session_sha}\",\"app_login_controller\":\"${controller_sha}\",\"app_login_continuation\":\"${continuation_sha}\",\"app_login_attempt_schema\":\"${attempt_schema_sha}\",\"app_sessions_migration\":\"${migration_sha}\",\"auth_app_sessions\":\"${facade_sha}\",\"router_injection\":\"${router_sha}\",\"mfa_challenge_controller\":\"${mfa_controller_sha}\",\"mfa_challenge_live\":\"${mfa_live_sha}\",\"runtime_script\":\"${script_sha}\",\"workflow\":\"${workflow_sha}\",\"runtime_source_contract_test\":\"${source_test_sha}\",\"runtime_evidence_contract_test\":\"${evidence_test_sha}\",\"mfa_session_upgrade_test\":\"${mfa_upgrade_test_sha}\",\"approval_concurrency_test\":\"${concurrency_test_sha}\"}}" > "$receipt_tmp"
  mv "$receipt_tmp" "$receipt"
}

prove_host() {
  local mode="$1"
  local database="sigra_app_login_${mode}_$(openssl rand -hex 6)"
  local CLOAK_KEY
  set_stage "${mode}_host_scaffold"
  rm -rf "$APP_DIR"
  run "$SIGRA_REPO" mix phx.new "$APP_DIR" --no-install --no-dashboard --database postgres --module SigraAppLoginProof --app "$APP_NAME"
  patch_host "$database"
  set_stage "${mode}_dependency_fetch"
  run "$APP_DIR" mix deps.get
  # Compile the complete dependency graph before asking Mix to discover the
  # installer task; compiling Sigra alone would bypass Phoenix/Ecto ordering.
  set_stage "${mode}_initial_compile"
  run "$APP_DIR" mix compile
  local flags=(--app-sessions --no-live --no-organizations)
  [[ "$mode" == direct ]] && flags+=(--app-password-login)
  set_stage "${mode}_installer"
  run "$APP_DIR" mix sigra.install Accounts User users "${flags[@]}"
  # The installer may add host-owned dependencies (for example, Hammer). Fetch
  # them before the idempotent installer reruns Mix or any later proof task.
  set_stage "${mode}_installer_dependency_fetch"
  run "$APP_DIR" mix deps.get
  set_stage "${mode}_installer_idempotency"
  run "$APP_DIR" mix sigra.install Accounts User users "${flags[@]}"
  install_proof_route
  set_stage "${mode}_database_setup"
  run "$APP_DIR" mix ecto.create
  pg_isready -h "$PGHOST" -p "$PGPORT" -d "$database" -t 5
  run "$APP_DIR" mix ecto.migrate
  set_stage "${mode}_generated_compile"
  run "$APP_DIR" mix compile --warnings-as-errors
  (cd "$APP_DIR" && assert_inventory "$mode")
  CLOAK_KEY="$(openssl rand -base64 32)"
  # This is a backend-only HTTP proof; disable only the disposable dev endpoint's
  # asset watchers so its transient host never needs frontend binaries.
  run "$APP_DIR" perl -0pi -e 's/watchers: \[.*?\],\n  live_reload:/watchers: [],\n  live_reload:/s' config/dev.exs
  export CLOAK_KEY
  set_stage "${mode}_server_start"
  pushd "$APP_DIR" >/dev/null
  PORT="$PORT" PHX_SERVER=true mix phx.server > server.log 2>&1 &
  SERVER_PID=$!
  popd >/dev/null
  wait_for_http
  # The hosted tracer stays on generated routes: an authenticated cookie jar,
  # CSRF-protected explicit approval, literal callback capture, then JSON exchange.
  [[ "$mode" != hosted ]] || prove_hosted_ceremony
  [[ "$mode" != direct ]] || prove_direct_mfa_ceremony
  curl --silent --show-error -o /dev/null -w '%{http_code}' -X POST "http://127.0.0.1:${PORT}/api/app-login/exchange" | grep -Eq '400|429'
  [[ "$mode" != direct ]] || curl --silent --show-error -o /dev/null -w '%{http_code}' -X POST "http://127.0.0.1:${PORT}/api/app-login/direct" | grep -Eq '401|429'
  kill "$SERVER_PID"; SERVER_PID=""
  unset CLOAK_KEY
  ensure_root_test_db
  for contract in app_login app_login_direct app_login_direct_fault app_login_concurrency fetch_app_session; do
    set_stage "${mode}_post_ceremony_${contract}"
    case "$contract" in
      app_login)
        for scenario in 77 103 144 175 209 251 287; do
          set_stage "${mode}_app_login_scenario_${scenario}"
          run "$SIGRA_REPO" env MIX_ENV=test mix test "test/sigra/app_login_test.exs:${scenario}" --trace
        done
        ;;
      app_login_direct) run "$SIGRA_REPO" env MIX_ENV=test mix test test/sigra/app_login_direct_test.exs --trace ;;
      app_login_direct_fault) run "$SIGRA_REPO" env MIX_ENV=test mix test test/sigra/app_login_direct_fault_test.exs --trace ;;
      app_login_concurrency) run "$SIGRA_REPO" env MIX_ENV=test mix test test/sigra/app_login/concurrency_test.exs --trace ;;
      fetch_app_session) run "$SIGRA_REPO" env MIX_ENV=test mix test test/sigra/plug/fetch_app_session_test.exs --trace ;;
    esac
  done
}

case "${1:---all}" in
  --hosted) prove_host hosted ;;
  --direct) prove_host direct ;;
  --all)
    prove_host hosted
    prove_host direct
    set_stage "all_cross_ceremony_contracts"
    run "$SIGRA_REPO" env MIX_ENV=test mix test test/sigra/install/app_sessions_mfa_session_upgrade_test.exs test/sigra/app_login/concurrency_test.exs --trace
    LIVEVIEW_MFA_SESSION_UPGRADED=true
    cmp "${TMP_ROOT}/hosted-fetch-app-session-shape.json" "${TMP_ROOT}/direct-fetch-app-session-shape.json"
    FETCH_APP_SESSION_EQUIVALENT=true
    write_receipt_last
    ;;
  *) echo "Usage: $0 [--hosted|--direct|--all]" >&2; exit 64 ;;
esac

echo "generated app-login runtime proof passed"
