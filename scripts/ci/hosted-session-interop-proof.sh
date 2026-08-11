#!/usr/bin/env bash
# Deterministic hosted Crosswake proof. The Phase 240.3 receipt is written only
# after every local command has completed successfully against PostgreSQL.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=scripts/ci/lib/free-port.sh
source "${ROOT_DIR}/scripts/ci/lib/free-port.sh"
PROOF_PATH="${ROOT_DIR}/.planning/phases/239-hosted-session-interop/239-CROSSWAKE-RELEASE-PROOF.json"
RELEASE_PATH="${ROOT_DIR}/.planning/phases/239-hosted-session-interop/239-CROSSWAKE-RELEASE.json"
EVIDENCE_PATH="${ROOT_DIR}/.planning/phases/240.3-close-gap-xw-01-xw-02-wire-hosted-crosswake-runtime-flow/240.3-HOSTED-RUNTIME-EVIDENCE.json"
DB_ENV_PATH="${ROOT_DIR}/tmp/db.env"
TIMEOUT_SECONDS="${SIGRA_INTEROP_TIMEOUT_SECONDS:-300}"
SERVER_PID=""
SERVER_LOG=""

fail() {
  printf 'hosted-session interop proof: %s\n' "$*" >&2
  exit 1
}

run_bounded() {
  local label="$1"
  shift
  printf '==> %s\n' "${label}"
  perl -e 'alarm shift; exec @ARGV' "${TIMEOUT_SECONDS}" "$@"
}

cleanup_browser_server() {
  local original_status="$?"

  if [[ -n "${SERVER_PID}" ]] && kill -0 "${SERVER_PID}" 2>/dev/null; then
    kill "${SERVER_PID}" 2>/dev/null || {
      printf 'hosted-session interop proof: failed to terminate browser proof server\n' >&2
      return 1
    }
    wait "${SERVER_PID}" 2>/dev/null || true
  fi

  if [[ -n "${SERVER_LOG}" ]]; then
    rm -f -- "${SERVER_LOG}"
  fi

  return "${original_status}"
}

redacted_server_diagnostics() {
  # The development logger includes request parameters and query bind values.
  # Failure diagnostics therefore retain only lifecycle lines, never callback
  # correlation values, session material, or seeded credentials.
  grep -E '^\[info\] (Running|Access|Sent)|^\[warning\]|^\[error\]|^\*\* \(' "${SERVER_LOG}" >&2 || true
}

browser_only() {
  [[ -f "${DB_ENV_PATH}" ]] || fail "configured PostgreSQL environment is missing: ${DB_ENV_PATH}"

  # shellcheck disable=SC1090
  source "${DB_ENV_PATH}"

  local port
  port="${SIGRA_INTEROP_BROWSER_PORT:-$(find_free_port)}"
  [[ "${port}" =~ ^[0-9]+$ ]] || fail "browser proof port must be numeric"
  ((port >= 1024 && port <= 65535)) || fail "browser proof port must be between 1024 and 65535"

  SERVER_LOG="$(mktemp "${TMPDIR:-/tmp}/sigra-hosted-session-interop-browser.XXXXXX")"
  trap cleanup_browser_server EXIT

  cd "${ROOT_DIR}/test/example"
  # The example endpoint reads PORT at compile time. Compile with the selected
  # port before migrating so Phoenix's runtime compile-env guard stays intact.
  run_bounded "compile example host for browser port" env MIX_ENV=dev PORT="${port}" mix compile --force
  run_bounded "migrate example development schema" env MIX_ENV=dev PORT="${port}" mix ecto.migrate --quiet
  # The seed helper prints demo credentials for interactive use. The browser
  # proof needs its fixture rows but must not emit those values into CI logs.
  if ! run_bounded "seed deterministic browser persona" \
    env MIX_ENV=dev PORT="${port}" mix run priv/repo/seeds.exs >/dev/null 2>&1; then
    fail "could not seed deterministic browser persona"
  fi
  PHX_SERVER=true MIX_ENV=dev PORT="${port}" mix phx.server >"${SERVER_LOG}" 2>&1 &
  SERVER_PID=$!

  if ! curl --fail --silent --show-error --retry 30 --retry-connrefused --retry-delay 0 \
    "http://127.0.0.1:${port}/" >/dev/null; then
    redacted_server_diagnostics
    fail "example host did not become ready"
  fi

  if ! SIGRA_EXAMPLE_URL="http://127.0.0.1:${port}" \
    run_bounded "run hosted Crosswake browser proof" \
      node "${ROOT_DIR}/test/example/priv/playwright/node_modules/@playwright/test/cli.js" test \
      tests/crosswake-hosted-runtime.spec.ts --project=crosswake-hosted-runtime --retries=0 \
      --config "${ROOT_DIR}/test/example/priv/playwright/playwright.config.ts"; then
    redacted_server_diagnostics
    fail "hosted Crosswake browser proof failed"
  fi

  printf 'hosted-session interop browser proof: passed\n'
}

write_evidence() {
  local sigra_sha captured_at
  sigra_sha="$(git -C "${ROOT_DIR}" rev-parse HEAD)"
  captured_at="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

  SIGRA_SHA="${sigra_sha}" CAPTURED_AT="${captured_at}" \
    ROOT_DIR="${ROOT_DIR}" EVIDENCE_PATH="${EVIDENCE_PATH}" python3 - <<'PY'
import json
import os
from pathlib import Path

root = Path(os.environ["ROOT_DIR"])
release_path = root / ".planning/phases/239-hosted-session-interop/239-CROSSWAKE-RELEASE.json"
release = json.loads(release_path.read_text())

payload = {
    "schema": "sigra.phase240_3.hosted-crosswake-runtime-evidence.v1",
    "sigra_git_sha": os.environ["SIGRA_SHA"],
    "captured_at": os.environ["CAPTURED_AT"],
    "crosswake_release": {
        key: release[key]
        for key in ("repository", "package", "version", "requirement", "git_tag", "git_sha", "hex_checksum")
    },
    "local_commands": [
        {"command": "cd test/example && MIX_ENV=test mix ecto.migrate --quiet", "exit_status": 0, "outcome": "passed"},
        {"command": "cd test/example && mix test test/example/accounts/crosswake_session_adapter_test.exs", "exit_status": 0, "outcome": "passed"},
        {"command": "cd test/example && mix test test/example/accounts/crosswake_continuations_test.exs", "exit_status": 0, "outcome": "passed"},
        {"command": "cd test/example && mix test test/example_web/controllers/crosswake_controller_test.exs --include example_app", "exit_status": 0, "outcome": "passed"},
        {"command": "scripts/ci/hosted-session-interop-proof.sh --browser-only", "exit_status": 0, "outcome": "passed"},
        {"command": "MIX_ENV=test mix test test/sigra/planning/phase_240_3_hosted_crosswake_runtime_test.exs", "exit_status": 0, "outcome": "passed"},
    ],
    "test_categories": {
        "historical_release_scope_contract": "passed",
        "database_backed_adapter_suite": "passed",
        "continuation_security_suite": "passed",
        "router_security_suite": "passed",
        "browser_cookie_jar_suite": "passed",
        "phase240_3_recipe_source_contract": "passed",
    },
    "requirements": {
        "XW-01": "proved by personal nil-org projection, opaque references, recipe, and smuggling denial matrix",
        "XW-02": "proved by fresh lookup, expiry/currentness, binding/account-switch, and evidence-only denial matrix",
    },
    "decisions": {
        "D-01": "example-host composition reuses the already-present in-process dependency",
        "D-02": "thin controllers delegate to explicit host context operations",
        "D-03": "authenticated POST start and browser-only return keep authority server-side",
        "D-04": "short-lived one-time continuations bind the departure session",
        "D-05": "only digests and narrow server-owned fields are persisted",
        "D-06": "atomic claim precedes evidence, binding, and evaluator work",
        "D-07": "return evidence cannot replace session resolution or authority",
        "D-08": "the host fixes the Crosswake route and final local destination",
        "D-09": "the completed return uses a 303 navigation without sensitive URL material",
        "D-10": "terminal failures use generic restart or sign-in recovery",
        "D-11": "logs, telemetry, and this receipt retain redacted outcome-only material",
        "D-12": "adapter and continuation denial matrices both run before evidence",
        "D-13": "the focused controller suite exercises the real router boundary",
        "D-14": "the serial browser project exercises one real cookie-jar journey",
        "D-15": "this bounded runner applies schemas and writes its receipt last",
        "D-16": "the recipe is host-owned and distinguishes local proof from deployment evidence",
        "D-17": "no public Sigra abstraction, generator output, or external service is added",
    },
    "unresolved_assumptions": [
        {"requirement_id": "XW-01", "category": "unclassified", "status": "unresolved", "flagged": True},
        {"requirement_id": "XW-02", "category": "unclassified", "status": "unresolved", "flagged": True},
    ],
    "flagged_unverified_prohibitions": [
        {"requirement_id": "XW-01", "category": "authority-integrity", "status": "unverified", "flagged": True},
        {"requirement_id": "XW-01", "category": "secret-boundary", "status": "unverified", "flagged": True},
        {"requirement_id": "XW-02", "category": "authority-smuggling", "status": "unverified", "flagged": True},
    ],
    "api_detector": {
        "detected": False,
        "reason": "crosswake_sigra is an in-process Elixir dependency; no Crosswake network endpoint, SDK client, webhook, hosted API, or remote authentication is introduced",
        "rerun_trigger": "introducing a Crosswake network endpoint, SDK client, webhook, hosted API, or remote authentication",
    },
}

Path(os.environ["EVIDENCE_PATH"]).write_text(json.dumps(payload, indent=2) + "\n")
PY
}

verify_scoped_paths_are_committed() {
  local scoped_paths=(
    "guides/recipes/b2c-alpha.md"
    "scripts/ci/hosted-session-interop-proof.sh"
    "test/sigra/planning/phase_240_3_hosted_crosswake_runtime_test.exs"
    ".planning/phases/240.3-close-gap-xw-01-xw-02-wire-hosted-crosswake-runtime-flow/COVERAGE.md"
    "test/example/priv/repo/migrations/20260811170000_create_crosswake_continuations.exs"
    "test/example/lib/example/accounts/crosswake_continuation.ex"
    "test/example/lib/example/accounts/crosswake_continuations.ex"
    "test/example/lib/example_web/controllers/crosswake_controller.ex"
    "test/example/lib/example_web/router.ex"
    "test/example/test/example/accounts/crosswake_continuations_test.exs"
    "test/example/test/example_web/controllers/crosswake_controller_test.exs"
    "test/example/priv/playwright/tests/crosswake-hosted-runtime.spec.ts"
    "test/example/priv/playwright/playwright.config.ts"
  )

  git -C "${ROOT_DIR}" diff --quiet HEAD -- "${scoped_paths[@]}" ||
    fail "scoped Phase 240.3 paths must be committed before writing evidence"

  if git -C "${ROOT_DIR}" ls-files --others --exclude-standard -- "${scoped_paths[@]}" | grep -q .; then
    fail "scoped Phase 240.3 paths must not be untracked before writing evidence"
  fi
}

main() {
  cd "${ROOT_DIR}"

  if [[ "${1:-}" == "--browser-only" ]]; then
    browser_only
    return
  fi

  [[ $# -eq 0 ]] || fail "usage: $0 [--browser-only]"
  [[ -f "${PROOF_PATH}" ]] || fail "required Wave 0 proof is missing"
  [[ -f "${RELEASE_PATH}" ]] || fail "required immutable Crosswake release receipt is missing"
  [[ -f "${DB_ENV_PATH}" ]] || fail "configured PostgreSQL environment is missing: ${DB_ENV_PATH}"

  # shellcheck disable=SC1090
  source "${DB_ENV_PATH}"

  run_bounded "apply example test schema" bash -lc "cd '${ROOT_DIR}/test/example' && MIX_ENV=test mix ecto.migrate --quiet"
  run_bounded "validate immutable Crosswake release proof" env MIX_ENV=test mix test test/sigra/planning/phase_239_hosted_session_interop_test.exs
  run_bounded "complete database-backed adapter suite" bash -lc "cd '${ROOT_DIR}/test/example' && mix test test/example/accounts/crosswake_session_adapter_test.exs"
  run_bounded "continuation security suite" bash -lc "cd '${ROOT_DIR}/test/example' && mix test test/example/accounts/crosswake_continuations_test.exs"
  run_bounded "controller security suite" bash -lc "cd '${ROOT_DIR}/test/example' && mix test test/example_web/controllers/crosswake_controller_test.exs --include example_app"
  run_bounded "browser cookie-jar proof" "${ROOT_DIR}/scripts/ci/hosted-session-interop-proof.sh" --browser-only
  run_bounded "phase 240.3 recipe/source contract" env MIX_ENV=test mix test test/sigra/planning/phase_240_3_hosted_crosswake_runtime_test.exs

  verify_scoped_paths_are_committed
  write_evidence
  printf 'hosted-session interop proof: passed\n'
}

main "$@"
