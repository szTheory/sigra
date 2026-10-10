#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
RECEIPT="${ROOT}/scripts/ci/release-receipt.sh"
CANARY="${ROOT}/scripts/ci/release-canary.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); echo "  PASS: $*"; }
fail() { FAIL=$((FAIL + 1)); echo "  FAIL: $*" >&2; }

new_input() {
  local scenario="$1" id="$2" probe="$3" terminal="$4" out="$TMP/input.json"
  jq -n --arg scenario "$scenario" --arg id "$id" --arg probe "$probe" --arg terminal "$terminal" \
    '{schema_version:1,receipt_kind:"canary",canary:{probe_id:$probe,scenario:$scenario},
      source_event:"workflow_dispatch",source:{repository:"szTheory/sigra",ref:"refs/heads/main",
      sha:"0123456789abcdef0123456789abcdef01234567"},source_run:{id:$id,attempt:1,workflow_id:2024,
      workflow_name:"Release Receipt Canary",workflow_path:".github/workflows/release-receipt-canary.yml",
      url:("https://github.com/szTheory/sigra/actions/runs/"+$id),started_at:"2026-10-10T10:00:00Z",
      observed_at:"2026-10-10T10:01:00Z"},terminal_verdict:$terminal,
      observer_run:(if $scenario == "cancellation" then {id:"34567",attempt:1,workflow_id:2025,
        url:"https://github.com/szTheory/sigra/actions/runs/34567",started_at:"2026-10-10T10:01:00Z",
        observed_at:"2026-10-10T10:02:00Z"} else null end)}' > "$out"
  printf '%s\n' "$out"
}

expect_rejected() {
  local label="$1" input="$2"
  if bash "$RECEIPT" --mode canary --input "$input" --output "$TMP/rejected-${label}.json" >/dev/null 2>&1; then
    fail "$label was accepted"
  elif [[ -e "$TMP/rejected-${label}.json" ]]; then
    fail "$label left a receipt"
  else
    pass "$label rejected without a receipt"
  fi
}

echo "Test A: valid failure and cancellation receipts preserve a separate source identity"
FAILURE_INPUT="$(new_input failure 74123 0123456789abcdef failure)"
CANCEL_INPUT="$(new_input cancellation 74124 abcdef0123456789 cancelled)"
if bash "$RECEIPT" --mode canary --input "$FAILURE_INPUT" --output "$TMP/failure.json" >/dev/null && \
   bash "$RECEIPT" --mode canary --input "$CANCEL_INPUT" --output "$TMP/cancellation.json" >/dev/null && \
   jq -e '.receipt_kind == "canary" and .source_run_id == "74123" and .scenario == "failure" and .terminal_verdict == "failure"' "$TMP/failure.json" >/dev/null && \
   jq -e '.receipt_kind == "canary" and .source_run_id == "74124" and .observer_run.id == "34567" and .terminal_verdict == "cancelled"' "$TMP/cancellation.json" >/dev/null; then
  pass "both canary terminal outcomes validate and retain observer identity"
else fail "valid canary receipt did not validate"; fi

echo "Test B: wrong repository, workflow, event, ref, attempt, SHA, and credentials fail closed"
for mutation in repository workflow_path workflow_id event ref attempt sha credentials; do
  jq --arg mutation "$mutation" '
    if $mutation == "repository" then .source.repository="other/repo"
    elif $mutation == "workflow_path" then .source_run.workflow_path=".github/workflows/release-please.yml"
    elif $mutation == "workflow_id" then .source_run.workflow_id=999
    elif $mutation == "event" then .source_event="push"
    elif $mutation == "ref" then .source.ref="refs/heads/feature"
    elif $mutation == "attempt" then .source_run.attempt=0
    elif $mutation == "sha" then .source.sha="bad-sha"
    else .credentials={HEX_API_KEY:"do-not-persist"} end
  ' "$FAILURE_INPUT" > "$TMP/${mutation}.json"
  expect_rejected "wrong-${mutation}" "$TMP/${mutation}.json"
done

echo "Test C: production and canary receipt namespaces reject crossovers"
if bash "$RECEIPT" --input "$FAILURE_INPUT" --output "$TMP/production.json" >/dev/null 2>&1; then
  fail "production mode accepted a canary receipt"
else pass "production mode rejects a canary marker"; fi
jq '.source += {version:"1.6.0",tag:"v1.6.0"}' "$FAILURE_INPUT" > "$TMP/mixed-production.json"
expect_rejected "production-namespace-in-canary" "$TMP/mixed-production.json"
jq '.canary.probe_id="not-a-valid-probe-id"' "$FAILURE_INPUT" > "$TMP/repeated-probe.json"
expect_rejected "malformed-or-repeated-probe" "$TMP/repeated-probe.json"

echo "Test D: exact-run cancellation and proof digests are guarded"
if rg -q 'actions/runs/\$\{cancel_id\}/cancel' "$CANARY" && \
   rg -q 'wait_for_cancellation_stage "\$cancel_id"' "$CANARY" && \
   rg -q 'length == 1 then \.\[0\]\.id else empty end' "$CANARY"; then
  pass "cancellation uses one exact source run after the explicit wait stage"
else fail "controller cancellation target is not exact and bounded"; fi

echo "Results: ${PASS} passed, ${FAIL} failed"
if [[ "$FAIL" -gt 0 ]]; then exit 1; fi
echo "release-canary.test: PASS"
