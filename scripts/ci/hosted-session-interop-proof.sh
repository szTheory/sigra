#!/usr/bin/env bash
# Deterministic Phase 239 seal. The receipt is written only after every local
# command has completed successfully against the configured PostgreSQL service.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PROOF_PATH="${ROOT_DIR}/.planning/phases/239-hosted-session-interop/239-CROSSWAKE-RELEASE-PROOF.json"
EVIDENCE_PATH="${ROOT_DIR}/.planning/phases/239-hosted-session-interop/239-INTEROP-EVIDENCE.json"
DB_ENV_PATH="${ROOT_DIR}/tmp/db.env"
TIMEOUT_SECONDS="${SIGRA_INTEROP_TIMEOUT_SECONDS:-300}"

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

write_evidence() {
  local sigra_sha proof_digest captured_at
  sigra_sha="$(git -C "${ROOT_DIR}" rev-parse HEAD)"
  proof_digest="$(shasum -a 256 "${PROOF_PATH}" | awk '{print $1}')"
  captured_at="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

  SIGRA_SHA="${sigra_sha}" PROOF_DIGEST="${proof_digest}" CAPTURED_AT="${captured_at}" \
    ROOT_DIR="${ROOT_DIR}" EVIDENCE_PATH="${EVIDENCE_PATH}" python3 - <<'PY'
import json
import os
from pathlib import Path

root = Path(os.environ["ROOT_DIR"])
proof_path = root / ".planning/phases/239-hosted-session-interop/239-CROSSWAKE-RELEASE-PROOF.json"
proof = json.loads(proof_path.read_text())

payload = {
    "schema": "sigra.phase239.hosted-session-interop-evidence.v1",
    "sigra_git_sha": os.environ["SIGRA_SHA"],
    "captured_at": os.environ["CAPTURED_AT"],
    "wave_0_proof": {
        "schema": proof["schema"],
        "sha256": os.environ["PROOF_DIGEST"],
        "commands": proof["commands"],
    },
    "crosswake_release": {
        key: proof[key]
        for key in ("repository", "package", "version", "requirement", "git_tag", "git_sha", "hex_checksum")
    },
    "local_commands": [
        {"command": "MIX_ENV=test mix format --check-formatted test/sigra/planning/phase_239_hosted_session_interop_test.exs", "exit_status": 0},
        {"command": "MIX_ENV=test mix test test/sigra/planning/phase_239_hosted_session_interop_test.exs", "exit_status": 0},
        {"command": "cd test/example && mix test test/example/accounts/crosswake_session_adapter_test.exs", "exit_status": 0},
    ],
    "test_categories": {
        "fast_source_release_scope_contract": "passed",
        "complete_database_backed_adapter_suite": "passed",
    },
    "requirements": {
        "XW-01": "proved by personal nil-org projection, opaque references, recipe, and smuggling denial matrix",
        "XW-02": "proved by fresh lookup, expiry/currentness, binding/account-switch, and evidence-only denial matrix",
    },
    "decisions": {
        "D-01": "personal org_id is nil; blank organization scope is denied",
        "D-02": "opaque host-owned references and fact-only lane do not expose credentials",
        "D-03": "fresh SIGRA session and user resolution precedes each evaluation",
        "D-04": "server-owned session/subject/version binding denies replay drift and account switches",
        "D-05": "AuthReturn is evidence/navigation only and cannot select authority",
        "D-06": "deterministic contract/evaluator matrix covers allow and denial boundaries",
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

main() {
  cd "${ROOT_DIR}"
  [[ -f "${PROOF_PATH}" ]] || fail "required Wave 0 proof is missing"
  [[ -f "${DB_ENV_PATH}" ]] || fail "configured PostgreSQL environment is missing: ${DB_ENV_PATH}"

  # shellcheck disable=SC1090
  source "${DB_ENV_PATH}"

  run_bounded "format contract" env MIX_ENV=test mix format --check-formatted test/sigra/planning/phase_239_hosted_session_interop_test.exs
  run_bounded "fast source/release/scope contract" env MIX_ENV=test mix test test/sigra/planning/phase_239_hosted_session_interop_test.exs
  run_bounded "complete database-backed adapter suite" bash -lc "cd '${ROOT_DIR}/test/example' && mix test test/example/accounts/crosswake_session_adapter_test.exs"

  write_evidence
  printf 'hosted-session interop proof: passed\n'
}

main "$@"
