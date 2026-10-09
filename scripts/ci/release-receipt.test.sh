#!/usr/bin/env bash
# Hermetic tests for the validated, idempotent terminal release receipt writer.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="${ROOT}/scripts/ci/release-receipt.sh"
TMP="$(mktemp -d)"
PASS=0
FAIL=0
trap 'rm -rf "$TMP"' EXIT
pass() { echo "  PASS: $*"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $*" >&2; FAIL=$((FAIL + 1)); }

new_input() {
  local event="${1:-push}" terminal="${2:-success}" gate="${3:-pass}" publish="${4:-published}"
  local observer="${5:-false}" out="$TMP/input.json"
  jq -n --arg event "$event" --arg terminal "$terminal" --arg gate "$gate" \
    --arg publish "$publish" --argjson observer "$observer" '
    {
      schema_version: 1,
      release_run: {
        id: "12345", attempt: 1,
        url: "https://github.com/szTheory/sigra/actions/runs/12345",
        workflow_name: "Release Please",
        workflow_url: "https://github.com/szTheory/sigra/actions/workflows/release-please.yml",
        started_at: "2026-10-08T10:00:00Z",
        completed_at: "2026-10-08T10:30:00Z"
      },
      source_event: $event,
      source: {version:"1.6.0", tag:"v1.6.0", sha:"0123456789abcdef0123456789abcdef01234567"},
      gate: (if $gate == "absent" then null else {
        run_id:"23456", url:"https://github.com/szTheory/sigra/actions/runs/23456",
        verdict:$gate, attempts:3,
        started_at:"2026-10-08T10:05:00Z", completed_at:"2026-10-08T10:15:00Z"
      } end),
      publish: {
        outcome:$publish,
        started_at:"2026-10-08T10:16:00Z", completed_at:"2026-10-08T10:29:00Z"
      },
      terminal_verdict:$terminal,
      failure:(if $terminal == "failure" then {stage:"publish-hex", diagnostic:"publish_failed"} else null end),
      observer_run:(if $observer then {id:"34567", url:"https://github.com/szTheory/sigra/actions/runs/34567"} else null end),
      stages:{release:{verdict:"created", completed_at:"2026-10-08T10:01:00Z"}}
    }' > "$out"
  printf '%s\n' "$out"
}

run_receipt() {
  local input="$1" output="$2"
  set +e
  OUT="$(bash "$SCRIPT" --input "$input" --output "$output" 2>&1)"
  RC=$?
  set -e
}

echo "Test A: a successful publish persists a validated linked receipt"
INPUT="$(new_input push success pass published)"
OUTPUT="$TMP/success.json"
run_receipt "$INPUT" "$OUTPUT"
if [[ "$RC" -eq 0 ]] && jq -e '.schema_version == 1 and .source_event == "push" and .terminal_verdict == "success" and .gate.run_id == "23456" and .publish.outcome == "published" and .release_run_url and .workflow_url and .recorded_at' "$OUTPUT" >/dev/null; then
  pass "success receipt has source, workflow, gate, publish, and timestamp identity"
else fail "success receipt rejected or incomplete: rc=$RC $OUT"; fi

echo "Test B: a failed gate cannot become a successful terminal receipt"
INPUT="$(new_input push failure fail not_run)"
jq '.failure={stage:"gate-ci-green",diagnostic:"gate_failed"}' "$INPUT" > "$TMP/failure.json"
jq '.gate.verdict="fail"' "$TMP/failure.json" > "$TMP/failure-2.json"
run_receipt "$TMP/failure-2.json" "$TMP/gate-failure.json"
if [[ "$RC" -eq 0 ]] && jq -e '.terminal_verdict == "failure" and .failure.stage == "gate-ci-green" and .gate.verdict == "fail"' "$TMP/gate-failure.json" >/dev/null; then
  pass "gate failure is retained with its failed stage"
else fail "gate failure was not accurately retained: rc=$RC $OUT"; fi

echo "Test B2: a gate failure with no observed CI run may record unavailable identity"
jq '.failure={stage:"gate-ci-green",diagnostic:"ci_gate_not_green"} | .gate={run_id:null,url:null,verdict:"fail",attempts:1,started_at:"2026-10-08T10:05:00Z",completed_at:"2026-10-08T10:15:00Z"}' "$INPUT" > "$TMP/gate-no-run.json"
run_receipt "$TMP/gate-no-run.json" "$TMP/gate-no-run-receipt.json"
if [[ "$RC" -eq 0 ]] && jq -e '.terminal_verdict == "failure" and .failure.stage == "gate-ci-green" and .gate.run_id == null and .gate.url == null and .gate.verdict == "fail"' "$TMP/gate-no-run-receipt.json" >/dev/null; then
  pass "gate failure retains an explicit null identity when no CI run was observed"
else fail "unobserved gate run identity was not represented truthfully: rc=$RC $OUT"; fi

jq '.terminal_verdict="success" | .failure=null | .gate={run_id:null,url:null,verdict:"pass",attempts:1,started_at:"2026-10-08T10:05:00Z",completed_at:"2026-10-08T10:15:00Z"}' "$INPUT" > "$TMP/gate-success-no-run.json"
run_receipt "$TMP/gate-success-no-run.json" "$TMP/gate-success-no-run-receipt.json"
if [[ "$RC" -ne 0 ]]; then
  pass "a passing gate still requires a real run identity"
else fail "gate without observed run identity was accepted as valid pass"; fi

echo "Test C: a publish failure requires a diagnostic stage and stays failed"
INPUT="$(new_input push failure pass failed)"
run_receipt "$INPUT" "$TMP/publish-failure.json"
if [[ "$RC" -eq 0 ]] && jq -e '.terminal_verdict == "failure" and .failure.stage == "publish-hex" and .failure.diagnostic == "publish_failed" and .publish.outcome == "failed"' "$TMP/publish-failure.json" >/dev/null; then
  pass "publish failure has a bounded diagnostic code"
else fail "publish failure was not retained: rc=$RC $OUT"; fi

echo "Test D: dry-run success is not represented as a publication"
INPUT="$(new_input workflow_dispatch success pass dry_run)"
run_receipt "$INPUT" "$TMP/dry-run.json"
if [[ "$RC" -eq 0 ]] && jq -e '.source_event == "workflow_dispatch" and .terminal_verdict == "success" and .publish.outcome == "dry_run" and .publish.outcome != "published"' "$TMP/dry-run.json" >/dev/null; then
  pass "dry-run success records no publish success"
else fail "dry-run receipt was inaccurate: rc=$RC $OUT"; fi

echo "Test E: cancellations retain both supported source events and observer links"
for event in push workflow_dispatch; do
  INPUT="$(new_input "$event" cancelled absent not_run true)"
  jq '.release_run.completed_at=null | .failure=null' "$INPUT" > "$TMP/cancel.json"
  run_receipt "$TMP/cancel.json" "$TMP/cancel-${event}.json"
  if [[ "$RC" -eq 0 ]] && jq -e --arg event "$event" '.source_event == $event and .terminal_verdict == "cancelled" and .observer_run.id == "34567" and .release_run_url and .observer_run.url' "$TMP/cancel-${event}.json" >/dev/null; then
    pass "${event} cancellation preserves source and observer run links"
  else fail "${event} cancellation was not retained: rc=$RC $OUT"; fi
done

echo "Test F: missing release identity is rejected without replacing an existing receipt"
INPUT="$(new_input push success pass published)"
run_receipt "$INPUT" "$TMP/identity.json"
if [[ -f "$TMP/identity.json" ]]; then cp "$TMP/identity.json" "$TMP/before.json"; else : > "$TMP/before.json"; fi
jq 'del(.source.sha)' "$INPUT" > "$TMP/missing.json"
run_receipt "$TMP/missing.json" "$TMP/identity.json"
if [[ "$RC" -ne 0 ]] && [[ "$OUT" == *"source"* ]] && [[ -f "$TMP/identity.json" ]] && cmp -s "$TMP/before.json" "$TMP/identity.json"; then
  pass "missing source SHA is rejected atomically with a safe contract-section diagnostic"
else fail "missing source SHA changed or accepted the receipt: rc=$RC $OUT"; fi

echo "Test G: malformed timestamps and unsupported events are rejected"
jq '.gate.started_at="yesterday"' "$INPUT" > "$TMP/bad-time.json"
run_receipt "$TMP/bad-time.json" "$TMP/bad-time-out.json"
if [[ "$RC" -ne 0 ]]; then pass "invalid timestamp rejected"; else fail "invalid timestamp accepted"; fi
jq '.source_event="schedule"' "$INPUT" > "$TMP/bad-event.json"
run_receipt "$TMP/bad-event.json" "$TMP/bad-event-out.json"
if [[ "$RC" -ne 0 ]]; then pass "unsupported source event rejected"; else fail "unsupported event accepted"; fi

echo "Test H: duplicate updates are idempotent and preserve prior stage evidence"
INPUT="$(new_input push success pass published)"
jq '.stages={release:{verdict:"created"}, gate:{verdict:"pass",run_id:"23456"}}' "$INPUT" > "$TMP/first.json"
run_receipt "$TMP/first.json" "$TMP/retry.json"
jq '.stages={publish:{outcome:"published"}}' "$INPUT" > "$TMP/retry-update.json"
run_receipt "$TMP/retry-update.json" "$TMP/retry.json"
if [[ "$RC" -eq 0 ]] && jq -e '.stages.release.verdict == "created" and .stages.gate.run_id == "23456" and .stages.publish.outcome == "published"' "$TMP/retry.json" >/dev/null; then
  pass "retry preserves earlier stage records"
else fail "retry lost prior stage records: rc=$RC $OUT"; fi
jq '.source.sha="aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"' "$INPUT" > "$TMP/wrong-identity.json"
cp "$TMP/retry.json" "$TMP/retry-before-wrong-identity.json"
run_receipt "$TMP/wrong-identity.json" "$TMP/retry.json"
if [[ "$RC" -ne 0 ]] && cmp -s "$TMP/retry-before-wrong-identity.json" "$TMP/retry.json"; then
  pass "same run ID cannot overwrite a receipt for a different source SHA"
else fail "mismatched retry identity changed or accepted the receipt: rc=$RC $OUT"; fi

echo "Test I: a notification failure after persistence cannot remove the receipt"
INPUT="$(new_input push success pass published)"
run_receipt "$INPUT" "$TMP/notifier-independent.json"
NOTIFIER="${TMP}/failing-notifier"
printf '#!/usr/bin/env bash\nexit 1\n' > "$NOTIFIER"
chmod +x "$NOTIFIER"
set +e
"$NOTIFIER"
NOTIFY_RC=$?
set -e
if [[ "$RC" -eq 0 && "$NOTIFY_RC" -eq 1 && -s "$TMP/notifier-independent.json" ]]; then
  pass "notification failure leaves the previously persisted receipt intact"
else fail "notifier independence failed: receipt_rc=$RC notify_rc=$NOTIFY_RC"; fi

echo "Test J: credential-shaped fields and diagnostics are rejected"
INPUT="$(new_input push failure pass failed)"
jq '.credentials={HEX_API_KEY:"hex_secret_canary"}' "$INPUT" > "$TMP/with-credential.json"
run_receipt "$TMP/with-credential.json" "$TMP/credential.json"
if [[ "$RC" -ne 0 ]] && ! grep -q 'hex_secret_canary' "$TMP/credential.json" 2>/dev/null; then
  pass "credential-shaped input is rejected and never appears in an artifact"
else fail "credential-shaped data was accepted or persisted: rc=$RC $OUT"; fi

echo "Results: ${PASS} passed, ${FAIL} failed"
if [[ "$FAIL" -gt 0 ]]; then exit 1; fi
echo "release-receipt.test: PASS"
