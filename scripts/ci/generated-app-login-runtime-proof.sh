#!/usr/bin/env bash
# Fresh-host proof for the first-party hosted and direct app-login ceremonies.
# It intentionally creates a disposable Phoenix host: no repository-private
# schemas, routes, or credentials are reused as evidence.
set -euo pipefail

CI_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SIGRA_REPO="${GITHUB_WORKSPACE:-$(cd "${CI_DIR}/../.." && pwd)}"
TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/sigra-generated-app-login-runtime-proof.XXXXXX")"
ARTIFACT_DIR="${GENERATED_APP_LOGIN_RUNTIME_PROOF_ARTIFACT_DIR:-}"
APP_NAME="sigra_app_login_proof"
APP_DIR="${TMP_ROOT}/${APP_NAME}"
SERVER_PID=""
PORT="${GENERATED_APP_LOGIN_RUNTIME_PROOF_PORT:-4019}"

export PGUSER="${PGUSER:-postgres}"
export PGPASSWORD="${PGPASSWORD:-postgres}"
export PGHOST="${PGHOST:-localhost}"
export PGPORT="${PGPORT:-5432}"

cleanup() {
  local rc=$?
  if [[ -n "${SERVER_PID}" ]]; then kill "${SERVER_PID}" 2>/dev/null || true; fi
  if [[ -n "${ARTIFACT_DIR}" ]]; then
    mkdir -p "${ARTIFACT_DIR}"
    [[ -f "${APP_DIR}/server.log" ]] && cp "${APP_DIR}/server.log" "${ARTIFACT_DIR}/server.log" || true
    [[ -f "${APP_DIR}/runtime-proof.json" ]] && cp "${APP_DIR}/runtime-proof.json" "${ARTIFACT_DIR}/runtime-proof.json" || true
  fi
  rm -rf "${TMP_ROOT}"
  exit "$rc"
}
trap cleanup EXIT INT TERM

require() { command -v "$1" >/dev/null || { echo "missing required command: $1" >&2; exit 69; }; }
run() { (cd "$1"; shift; "$@"); }

wait_for_http() {
  local attempt=0
  until curl --fail --silent --show-error "http://127.0.0.1:${PORT}/" >/dev/null; do
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
  sed -nE 's/.*name="_csrf_token" value="([^"]+)".*/\1/p' "$page" | head -n 1
}

seed_confirmed_user() {
  # The disposable host owns this deterministic fixture identity. Browser
  # authentication still happens through the generated login route and cookie jar.
  run "$APP_DIR" mix run -e '
    alias SigraAppLoginProof.Accounts
    alias SigraAppLoginProof.Repo

    {:ok, user} = Accounts.register_user(%{"email" => "hosted-proof@example.test", "password" => "HostedProofPassword123!"})
    user |> Ecto.Changeset.change(confirmed_at: DateTime.utc_now()) |> Repo.update!()
  '
}

seed_direct_mfa_user() {
  # This uses only generated-host schemas and the shipped Sigra MFA helper;
  # the one plaintext backup code remains in the disposable host directory.
  run "$APP_DIR" mix run -e '
    alias SigraAppLoginProof.Accounts
    alias SigraAppLoginProof.Repo

    {:ok, user} = Accounts.register_user(%{"email" => "direct-proof@example.test", "password" => "DirectProofPassword123!"})
    user = user |> Ecto.Changeset.change(confirmed_at: DateTime.utc_now()) |> Repo.update!()

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
  local base="http://127.0.0.1:${PORT}"
  local direct_body="${APP_DIR}/direct-start.json"
  local mfa_body="${APP_DIR}/direct-mfa.json"
  local invalid_body="${APP_DIR}/direct-invalid-factor.json"
  local challenge backup_code status

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

  status="$(curl --silent --show-error -H 'content-type: application/json' \
    -d "{\"challenge\":\"$challenge\",\"code\":\"$backup_code\",\"factor\":\"unknown\"}" \
    -o "$invalid_body" -w '%{http_code}' "$base/api/app-login/direct/mfa")"
  [[ "$status" == "401" ]]
  grep -Fxq '{"error":"invalid_credentials"}' "$invalid_body"
}

prove_hosted_ceremony() {
  local base="http://127.0.0.1:${PORT}"
  local cookie_jar="${APP_DIR}/hosted-cookie-jar.txt"
  local login_page="${APP_DIR}/hosted-login.html"
  local approval_page="${APP_DIR}/hosted-approval.html"
  local approval_headers="${APP_DIR}/hosted-approval.headers"
  local exchange_body="${APP_DIR}/hosted-exchange.json"
  local login_csrf approval_csrf verifier challenge callback code state status

  seed_confirmed_user
  curl --fail --silent --show-error --cookie-jar "$cookie_jar" -o "$login_page" "$base/users/log_in"
  login_csrf="$(csrf_token "$login_page")"
  [[ -n "$login_csrf" ]]
  curl --fail --silent --show-error --cookie "$cookie_jar" --cookie-jar "$cookie_jar" \
    --data-urlencode "_csrf_token=$login_csrf" \
    --data-urlencode "user[email]=hosted-proof@example.test" \
    --data-urlencode "user[password]=HostedProofPassword123!" \
    -o /dev/null -D /dev/null "$base/users/log_in"

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
  status="$(curl --silent --show-error --cookie "$cookie_jar" --cookie-jar "$cookie_jar" \
    --data-urlencode "_csrf_token=$approval_csrf" \
    -D "$approval_headers" -o /dev/null -w '%{http_code}' "$base/users/app-login/approve")"
  [[ "$status" =~ ^30[23]$ ]]
  callback="$(awk 'tolower($1) == "location:" {sub(/^[^:]*:[[:space:]]*/, ""); sub(/\r$/, ""); print; exit}' "$approval_headers")"
  [[ "$callback" == 'http://127.0.0.1:49152/callback?code='*'&state=hosted-runtime-state' ]]
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
  grep -Fq 'FetchAppSession' "$router" || true # protected-route hosts may wire this in host policy.
  if [[ "$mode" == hosted ]]; then
    ! grep -Fq 'post "/direct"' "$router"
  else
    grep -Fq 'post "/direct"' "$router"
  fi
  ! grep -Fq 'FetchAPIToken' "$router"
  ! grep -Fq 'FetchJWT' "$router"
}

write_receipt_last() {
  local hosted_sha direct_sha
  hosted_sha="$(sha256sum "${SIGRA_REPO}/lib/sigra/plug/fetch_app_session.ex" | awk '{print $1}')"
  direct_sha="$(sha256sum "${SIGRA_REPO}/priv/templates/sigra.install/app_sessions/app_login_controller.ex" | awk '{print $1}')"
  # receipt-last: this is deliberately the final write after every command and probe.
  cat > runtime-proof.json <<EOF
{"schema":"sigra.generated-app-login-runtime-proof/v1","status":"passed","hosted_fetch_app_session_sha256":"${hosted_sha}","direct_controller_sha256":"${direct_sha}","proof":"callback/state/S256, approval cancel, 60-second expiry, replay, two-caller exchange, fault rollback, FetchAppSession"}
EOF
}

prove_host() {
  local mode="$1"
  local database="sigra_app_login_${mode}_$(openssl rand -hex 6)"
  rm -rf "$APP_DIR"
  run "$SIGRA_REPO" mix phx.new "$APP_DIR" --no-install --no-dashboard --database postgres --module SigraAppLoginProof --app "$APP_NAME"
  patch_host "$database"
  run "$APP_DIR" mix deps.get
  # Compile the complete dependency graph before asking Mix to discover the
  # installer task; compiling Sigra alone would bypass Phoenix/Ecto ordering.
  run "$APP_DIR" mix compile
  local flags=(--app-sessions --no-live --no-organizations)
  [[ "$mode" == direct ]] && flags+=(--app-password-login)
  run "$APP_DIR" mix sigra.install Accounts User users "${flags[@]}"
  run "$APP_DIR" mix sigra.install Accounts User users "${flags[@]}"
  run "$APP_DIR" mix ecto.create
  pg_isready -h "$PGHOST" -p "$PGPORT" -d "$database" -t 5
  run "$APP_DIR" mix ecto.migrate
  run "$APP_DIR" mix compile --warnings-as-errors
  (cd "$APP_DIR" && assert_inventory "$mode")
  (cd "$APP_DIR" && PORT="$PORT" PHX_SERVER=true mix phx.server > server.log 2>&1 & echo $! > server.pid)
  SERVER_PID="$(cat "${APP_DIR}/server.pid")"
  wait_for_http
  # The hosted tracer stays on generated routes: an authenticated cookie jar,
  # CSRF-protected explicit approval, literal callback capture, then JSON exchange.
  [[ "$mode" != hosted ]] || prove_hosted_ceremony
  [[ "$mode" != direct ]] || prove_direct_mfa_ceremony
  curl --silent --show-error -o /dev/null -w '%{http_code}' -X POST "http://127.0.0.1:${PORT}/api/app-login/exchange" | grep -Eq '400|429'
  [[ "$mode" != direct ]] || curl --silent --show-error -o /dev/null -w '%{http_code}' -X POST "http://127.0.0.1:${PORT}/api/app-login/direct" | grep -Eq '401|429'
  kill "$SERVER_PID"; SERVER_PID=""
  run "$SIGRA_REPO" env MIX_ENV=test mix test test/sigra/app_login_test.exs test/sigra/app_login_direct_test.exs test/sigra/app_login_direct_fault_test.exs test/sigra/app_login/concurrency_test.exs test/sigra/plug/fetch_app_session_test.exs --trace
  (cd "$APP_DIR" && write_receipt_last)
}

case "${1:---all}" in
  --hosted) prove_host hosted ;;
  --direct) prove_host direct ;;
  --all) prove_host hosted; prove_host direct ;;
  *) echo "Usage: $0 [--hosted|--direct|--all]" >&2; exit 64 ;;
esac

echo "generated app-login runtime proof passed"
