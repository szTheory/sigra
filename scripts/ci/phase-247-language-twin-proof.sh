#!/usr/bin/env bash
# Credential-free, receipt-last proof for the bounded language-learning twin.
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
EVIDENCE_PATH="${ROOT_DIR}/.planning/phases/247-language-learning-digital-twin/247-EVIDENCE.json"
DB_ENV_PATH="${ROOT_DIR}/tmp/db.env"
SERVER_PID=""
SERVER_LOG=""

fail() { printf 'phase-247-language-twin-proof: %s\n' "$*" >&2; exit 1; }
sha256() { shasum -a 256 "$1" | awk '{print $1}'; }

cleanup() {
  local status=$?
  trap - EXIT INT TERM
  if [[ -n "$SERVER_PID" ]] && kill -0 "$SERVER_PID" 2>/dev/null; then
    kill "$SERVER_PID"
    wait "$SERVER_PID" 2>/dev/null || true
  fi
  if [[ -n "$SERVER_PID" ]] && kill -0 "$SERVER_PID" 2>/dev/null; then
    printf 'phase-247-language-twin-proof: Phoenix cleanup assertion failed\n' >&2
    status=1
  fi
  [[ -n "$SERVER_LOG" ]] && rm -f "$SERVER_LOG"
  exit "$status"
}
trap cleanup EXIT INT TERM

find_free_port() {
  python3 - <<'PY'
import socket
s = socket.socket()
s.bind(("127.0.0.1", 0))
print(s.getsockname()[1])
s.close()
PY
}

run_exunit() {
  (
    cd "${ROOT_DIR}/test/example"
    MIX_ENV=test PORT="$1" mix ecto.migrate --quiet
    MIX_ENV=test PORT="$1" mix test \
      test/example/learning_twin/learning_twin_test.exs \
      test/example_web/controllers/learning_twin_controller_test.exs \
      test/example_web/live/learning_twin_live_test.exs
  )
}

run_chromium() {
  local port="$1"
  SERVER_LOG="$(mktemp "${TMPDIR:-/tmp}/sigra-phase-247-server.XXXXXX")"
  (
    cd "${ROOT_DIR}/test/example"
    MIX_ENV=test SIGRA_BROWSER_PROOF=true PORT="$port" mix run priv/repo/seeds.exs >/dev/null 2>&1
    exec env PHX_SERVER=true MIX_ENV=test PORT="$port" mix phx.server
  ) >"$SERVER_LOG" 2>&1 &
  SERVER_PID=$!
  curl --fail --silent --show-error --retry 30 --retry-connrefused --retry-delay 0 "http://127.0.0.1:${port}/" >/dev/null || {
    grep -E '^\[error\]|^\*\* \(' "$SERVER_LOG" >&2 || true
    fail 'example host did not become ready'
  }
  (
    cd "${ROOT_DIR}/test/example/priv/playwright"
    SIGRA_EXAMPLE_URL="http://127.0.0.1:${port}" npm test -- twin-offline.spec.ts --project=chromium
  )
}

hash_sources() {
  jq -S -n \
    --arg migration "$(sha256 "${ROOT_DIR}/test/example/priv/repo/migrations/20260819000000_create_learning_twin_tables.exs")" \
    --arg host "$(sha256 "${ROOT_DIR}/test/example/lib/example/learning_twin.ex")" \
    --arg router "$(sha256 "${ROOT_DIR}/test/example/lib/example_web/router.ex")" \
    --arg javascript "$(sha256 "${ROOT_DIR}/test/example/priv/static/assets/js/learning_twin.js")" \
    --arg css "$(sha256 "${ROOT_DIR}/test/example/priv/static/assets/css/app.css")" \
    --arg exunit "$(sha256 "${ROOT_DIR}/test/example/test/example/learning_twin/learning_twin_test.exs")" \
    --arg controller_test "$(sha256 "${ROOT_DIR}/test/example/test/example_web/controllers/learning_twin_controller_test.exs")" \
    --arg live_test "$(sha256 "${ROOT_DIR}/test/example/test/example_web/live/learning_twin_live_test.exs")" \
    --arg playwright "$(sha256 "${ROOT_DIR}/test/example/priv/playwright/tests/twin-offline.spec.ts")" \
    --arg proof "$(sha256 "${ROOT_DIR}/scripts/ci/phase-247-language-twin-proof.sh")" \
    '{migration:$migration,host:$host,router:$router,javascript:$javascript,css:$css,exunit:$exunit,controller_test:$controller_test,live_test:$live_test,playwright:$playwright,proof:$proof}'
}

validate_flags() {
  local evidence="$1"
  jq -e '
    (keys | sort == ["accepted_once","account_isolation","cache_write_failure_denied","conflict_once","credential_boundary","duplicate_stable","lease_boundary","light_dark_system","manifest_integrity","no_sleep","offline_media_usable","rejected_once","result","schema","short_corrupt_denied","sources","ui_considerations"]) and
    .schema == "sigra.phase-247-language-twin/1" and .result == "pass" and
    ([.credential_boundary,.manifest_integrity,.short_corrupt_denied,.cache_write_failure_denied,.offline_media_usable,.lease_boundary,.account_isolation,.accepted_once,.rejected_once,.conflict_once,.duplicate_stable,.ui_considerations,.light_dark_system,.no_sleep] | all(. == true)) and
    (.sources | keys | sort == ["controller_test","css","exunit","host","javascript","live_test","migration","playwright","proof","router"]) and
    (.sources | all(.[]; type == "string" and test("^[0-9a-f]{64}$"))) and
    ([paths(scalars) | map(tostring) | join(".")] | all(test("(credential|cookie|token|user|account|partition|mutation|digest|media)") | not))
  ' "$evidence" >/dev/null
}

write_evidence_last() {
  local tmp
  tmp="$(mktemp "${EVIDENCE_PATH}.tmp.XXXXXX")"
  jq -S -n --argjson sources "$(hash_sources)" '
    {schema:"sigra.phase-247-language-twin/1",result:"pass",credential_boundary:true,manifest_integrity:true,short_corrupt_denied:true,cache_write_failure_denied:true,offline_media_usable:true,lease_boundary:true,account_isolation:true,accepted_once:true,rejected_once:true,conflict_once:true,duplicate_stable:true,ui_considerations:true,light_dark_system:true,no_sleep:true,sources:$sources}
  ' >"$tmp"
  validate_flags "$tmp" || { rm -f "$tmp"; fail 'evidence schema validation failed'; }
  mv -f "$tmp" "$EVIDENCE_PATH"
}

main() {
  [[ -f "$DB_ENV_PATH" ]] || "${ROOT_DIR}/scripts/db/up.sh"
  # shellcheck disable=SC1090
  source "$DB_ENV_PATH"
  local port
  port="${SIGRA_LANGUAGE_TWIN_PORT:-4002}"
  run_exunit "$port"
  run_chromium "$port"
  write_evidence_last
  validate_flags "$EVIDENCE_PATH"
  printf 'phase-247-language-twin-proof: passed\n'
}

main "$@"
