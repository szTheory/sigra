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
CURRENT_STAGE="bootstrap"

export PGUSER="${PGUSER:-postgres}"
export PGPASSWORD="${PGPASSWORD:-postgres}"
export PGHOST="${PGHOST:-localhost}"
export PGPORT="${PGPORT:-5432}"

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

  perl -0pi -e 's/\nend\s*\z/\n  pipeline :app_session_proof do\n    plug Sigra.Plug.FetchAppSession,\n      config: \&SigraAppLoginProof.Accounts.Auth.AppSessions.sigra_config\/0,\n      scope_module: SigraAppLoginProof.Accounts.Scope\n  end\n\n  scope "\/api", SigraAppLoginProofWeb do\n    pipe_through [:api, :app_session_proof]\n\n    get "\/app-login-proof", AppLoginProofController, :show\n  end\nend\n/' "$router"
  grep -Fq 'Sigra.Plug.FetchAppSession' "$router"
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

assert_one_family() {
  local label="$1"
  local expected_kind="$2"

  EXPECTED_KIND="$expected_kind" EXPECTED_LABEL="$label" run "$APP_DIR" mix run -e '
    alias SigraAppLoginProof.Accounts
    alias SigraAppLoginProof.Repo

    count = Repo.aggregate(Accounts.UserAppSessionFamily, :count, :id)
    if count != 1, do: raise("expected exactly one #{System.fetch_env!("EXPECTED_LABEL")} app-session family")

    kind = String.to_existing_atom(System.fetch_env!("EXPECTED_KIND"))
    attempts = Repo.all(Accounts.UserAppLoginAttempt)
    if Enum.count(attempts, &(&1.kind == kind)) != 1, do: raise("expected exactly one #{kind} attempt")
  '
}

prove_hosted_replay() {
  local code="$1"
  local verifier="$2"
  local access_token="$3"
  local family_id="$4"
  local status

  status="$(curl --silent --show-error -H 'content-type: application/json' \
    -d "{\"code\":\"$code\",\"code_verifier\":\"$verifier\",\"profile_id\":\"ios-primary\",\"callback\":\"http://127.0.0.1:49152/callback\"}" \
    -o "${APP_DIR}/hosted-replay.json" -w '%{http_code}' "http://127.0.0.1:${PORT}/api/app-login/exchange")"
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
  local families_before_browser_required
  families_before_browser_required="$(run "$APP_DIR" mix run -e 'IO.write(SigraAppLoginProof.Repo.aggregate(SigraAppLoginProof.Accounts.UserAppSessionFamily, :count, :id))')"
  status="$(curl --silent --show-error -H 'content-type: application/json' \
    -d '{"profile_id":"ios-primary","email":"not-a-real-user@example.test","password":"not-a-password"}' \
    -o "${APP_DIR}/direct-browser-required.json" -w '%{http_code}' "$base/api/app-login/direct")"
  [[ "$status" == "403" ]]
  grep -Fxq '{"error":"browser_required"}' "${APP_DIR}/direct-browser-required.json"
  [[ "$(run "$APP_DIR" mix run -e 'IO.write(SigraAppLoginProof.Repo.aggregate(SigraAppLoginProof.Accounts.UserAppSessionFamily, :count, :id))')" == "$families_before_browser_required" ]]
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
  local exchange_body="${APP_DIR}/hosted-exchange.json"
  local login_csrf mfa_csrf approval_csrf verifier challenge callback code state status access_token family_id backup_code

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
  curl --fail --silent --show-error --cookie "$cookie_jar" --cookie-jar "$cookie_jar" -o "${APP_DIR}/hosted-mfa.html" "$base/users/mfa"
  mfa_csrf="$(csrf_token "${APP_DIR}/hosted-mfa.html")"
  backup_code="$(<"${APP_DIR}/hosted-backup-code")"
  [[ -n "$mfa_csrf" && -n "$backup_code" ]]
  status="$(curl --silent --show-error --cookie "$cookie_jar" --cookie-jar "$cookie_jar" \
    --data-urlencode "_csrf_token=$mfa_csrf" \
    --data-urlencode 'mfa[method]=backup' \
    --data-urlencode "mfa[code]=$backup_code" \
    -o /dev/null -D /dev/null -w '%{http_code}' "$base/users/mfa")"
  [[ "$status" =~ ^30[23]$ ]]

  verifier="$(openssl rand -base64 48 | tr '+/' '-_' | tr -d '=\n')"
  challenge="$(printf '%s' "$verifier" | openssl dgst -binary -sha256 | openssl base64 -A | tr '+/' '-_' | tr -d '=')"
  curl --fail --silent --show-error --cookie "$cookie_jar" --cookie-jar "$cookie_jar" --get \
    --data-urlencode 'profile_id=ios-primary' \
    --data-urlencode 'callback=http://127.0.0.1:49152/callback' \
    --data-urlencode 'state=hosted-runtime-state' \
    --data-urlencode "code_challenge=$challenge" \
    --data-urlencode 'code_challenge_method=S256' \
    -o "$approval_page" "$base/users/app-login"
  grep -Fq 'data-testid="app-login-approval"' "$approval_page"
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
    -o "$exchange_body" -w '%{http_code}' "$base/api/app-login/exchange")"
  [[ "$status" =~ ^2[0-9][0-9]$ ]]
  grep -Eq '"access_token":"[^"]+"' "$exchange_body"
  grep -Eq '"refresh_token":"[^"]+"' "$exchange_body"
  grep -Eq '"family_id":"[^"]+"' "$exchange_body"
  access_token="$(json_field access_token "$exchange_body")"
  family_id="$(json_field family_id "$exchange_body")"
  [[ -n "$access_token" && -n "$family_id" ]]
  prove_fetch_app_session hosted "$access_token" "$family_id"

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
  local app_login_sha fetch_app_session_sha controller_sha attempt_schema_sha migration_sha facade_sha router_sha mfa_controller_sha mfa_live_sha script_sha workflow_sha source_test_sha evidence_test_sha mfa_upgrade_test_sha concurrency_test_sha receipt_tmp receipt

  [[ "$HOSTED_SUCCESS" == true && "$DIRECT_SUCCESS" == true ]]
  [[ "$HOSTED_REPLAY_REJECTED" == true && "$DIRECT_REPLAY_REJECTED" == true ]]
  [[ "$HOSTED_FETCH_APP_SESSION" == true && "$DIRECT_FETCH_APP_SESSION" == true ]]
  [[ "$CONTROLLER_MFA_SESSION_UPGRADED" == true && "$LIVEVIEW_MFA_SESSION_UPGRADED" == true ]]
  [[ "$APPROVAL_REPLAY_REJECTED" == true && "$DIRECT_BACKUP_CODE_SUCCEEDED" == true ]]
  [[ "$BROWSER_REQUIRED_BEFORE_AUTHENTICATION" == true && "$FETCH_APP_SESSION_EQUIVALENT" == true ]]

  app_login_sha="$(sha256sum "${SIGRA_REPO}/lib/sigra/app_login.ex" | awk '{print $1}')"
  fetch_app_session_sha="$(sha256sum "${SIGRA_REPO}/lib/sigra/plug/fetch_app_session.ex" | awk '{print $1}')"
  controller_sha="$(sha256sum "${SIGRA_REPO}/priv/templates/sigra.install/app_sessions/app_login_controller.ex" | awk '{print $1}')"
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
  printf '%s\n' "{\"schema\":\"sigra.generated-app-login-runtime-proof/v3\",\"status\":\"passed\",\"controller_mfa_session_upgraded\":true,\"liveview_mfa_session_upgraded\":true,\"approval_replay_rejected\":true,\"direct_backup_code_succeeded\":true,\"hosted_replay_rejected\":true,\"direct_replay_rejected\":true,\"fetch_app_session_equivalent\":true,\"browser_required_before_authentication\":true,\"sources\":{\"app_login\":\"${app_login_sha}\",\"fetch_app_session\":\"${fetch_app_session_sha}\",\"app_login_controller\":\"${controller_sha}\",\"app_login_attempt_schema\":\"${attempt_schema_sha}\",\"app_sessions_migration\":\"${migration_sha}\",\"auth_app_sessions\":\"${facade_sha}\",\"router_injection\":\"${router_sha}\",\"mfa_challenge_controller\":\"${mfa_controller_sha}\",\"mfa_challenge_live\":\"${mfa_live_sha}\",\"runtime_script\":\"${script_sha}\",\"workflow\":\"${workflow_sha}\",\"runtime_source_contract_test\":\"${source_test_sha}\",\"runtime_evidence_contract_test\":\"${evidence_test_sha}\",\"mfa_session_upgrade_test\":\"${mfa_upgrade_test_sha}\",\"approval_concurrency_test\":\"${concurrency_test_sha}\"}}" > "$receipt_tmp"
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
  run "$SIGRA_REPO" env MIX_ENV=test mix test test/sigra/app_login_test.exs test/sigra/app_login_direct_test.exs test/sigra/app_login_direct_fault_test.exs test/sigra/app_login/concurrency_test.exs test/sigra/plug/fetch_app_session_test.exs --trace
}

case "${1:---all}" in
  --hosted) prove_host hosted ;;
  --direct) prove_host direct ;;
  --all)
    prove_host hosted
    prove_host direct
    run "$SIGRA_REPO" env MIX_ENV=test mix test test/sigra/install/app_sessions_mfa_session_upgrade_test.exs test/sigra/app_login/concurrency_test.exs --trace
    LIVEVIEW_MFA_SESSION_UPGRADED=true
    cmp "${TMP_ROOT}/hosted-fetch-app-session-shape.json" "${TMP_ROOT}/direct-fetch-app-session-shape.json"
    FETCH_APP_SESSION_EQUIVALENT=true
    write_receipt_last
    ;;
  *) echo "Usage: $0 [--hosted|--direct|--all]" >&2; exit 64 ;;
esac

echo "generated app-login runtime proof passed"
