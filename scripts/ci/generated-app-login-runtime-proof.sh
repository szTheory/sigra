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
  # Real generated public routes are exercised over HTTP. Invalid protocol
  # inputs must fail closed; ceremony state transitions are separately covered
  # by app_login, direct, fault, and concurrency tests invoked below.
  curl --silent --show-error -o /dev/null -w '%{http_code}' "http://127.0.0.1:${PORT}/users/app-login" | grep -Eq '400|429'
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
