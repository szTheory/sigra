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
  local scenario="$1" id="$2" probe="$3" terminal="$4" out
  out="$TMP/input-${id}.json"
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
  if bash "$RECEIPT" --mode canary --expected-workflow-id 2024 --input "$input" --output "$TMP/rejected-${label}.json" >/dev/null 2>&1; then
    fail "$label was accepted"
  elif [[ -e "$TMP/rejected-${label}.json" ]]; then
    fail "$label left a receipt"
  else
    pass "$label rejected without a receipt"
  fi
}

expect_rejected_by_canary_mode() {
  local label="$1" input="$2"
  if bash "$RECEIPT" --mode canary --expected-workflow-id 2024 --input "$input" --output "$TMP/rejected-${label}.json" >/dev/null 2>&1; then
    fail "$label was accepted"
  else pass "$label rejected"; fi
}

echo "Test A: valid failure and cancellation receipts preserve a separate source identity"
FAILURE_INPUT="$(new_input failure 74123 0123456789abcdef failure)"
CANCEL_INPUT="$(new_input cancellation 74124 abcdef0123456789 cancelled)"
if bash "$RECEIPT" --mode canary --expected-workflow-id 2024 --input "$FAILURE_INPUT" --output "$TMP/failure.json" >/dev/null && \
   bash "$RECEIPT" --mode canary --expected-workflow-id 2024 --input "$CANCEL_INPUT" --output "$TMP/cancellation.json" >/dev/null && \
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
jq '.source_run.started_at="yesterday"' "$FAILURE_INPUT" > "$TMP/bad-timestamp.json"
expect_rejected "malformed-timestamp" "$TMP/bad-timestamp.json"

echo "Test C: production and canary receipt namespaces reject crossovers"
if bash "$RECEIPT" --input "$FAILURE_INPUT" --output "$TMP/production.json" >/dev/null 2>&1; then
  fail "production mode accepted a canary receipt"
else pass "production mode rejects a canary marker"; fi
jq '.source += {version:"1.6.0",tag:"v1.6.0"}' "$FAILURE_INPUT" > "$TMP/mixed-production.json"
expect_rejected "production-namespace-in-canary" "$TMP/mixed-production.json"
jq '.canary.probe_id="not-a-valid-probe-id"' "$FAILURE_INPUT" > "$TMP/bad-probe.json"
expect_rejected "malformed-probe" "$TMP/bad-probe.json"
  jq -S 'del(.recorded_at)' "$TMP/failure.json" > "$TMP/failure-before-retry.json"
if bash "$RECEIPT" --mode canary --expected-workflow-id 2024 --input "$FAILURE_INPUT" --output "$TMP/failure.json" >/dev/null 2>&1 && \
   jq -S 'del(.recorded_at)' "$TMP/failure.json" > "$TMP/failure-after-retry.json" && \
   cmp -s "$TMP/failure-before-retry.json" "$TMP/failure-after-retry.json"; then
  pass "same source/probe retry is idempotent"
else fail "same source/probe retry was not idempotent"; fi
jq --arg probe "$(jq -r '.probe_id' "$TMP/failure.json")" '.probe_id=$probe' "$TMP/cancellation.json" > "$TMP/repeated-probe-pair.json"
if bash "$CANARY" --validate-pair --failure-receipt "$TMP/failure.json" --cancellation-receipt "$TMP/repeated-probe-pair.json" >/dev/null 2>&1; then
  fail "repeated probe IDs were accepted as a dual-outcome pair"
else pass "repeated probe IDs fail closed"; fi

echo "Test D: exact-run cancellation and proof digests are guarded"
mkdir -p "$TMP/bin"
cat > "$TMP/bin/gh" <<'GH'
#!/usr/bin/env bash
set -euo pipefail
[[ "${1:-}" == api ]] || exit 2
endpoint="${2:-}"
[[ "$endpoint" == --method ]] && endpoint="${4:-}"
case "$endpoint" in
  "repos/${GITHUB_REPOSITORY}") cat "$TEST_REPO_JSON" ;;
  "repos/${GITHUB_REPOSITORY}/actions/workflows/release-receipt-canary.yml") cat "$TEST_CANARY_WORKFLOW_JSON" ;;
  "repos/${GITHUB_REPOSITORY}/actions/workflows/release-receipt-canary-controller.yml") cat "$TEST_CONTROLLER_WORKFLOW_JSON" ;;
  "repos/${GITHUB_REPOSITORY}/actions/workflows/release-run-observer.yml") cat "$TEST_OBSERVER_WORKFLOW_JSON" ;;
  "repos/${GITHUB_REPOSITORY}/actions/permissions/workflow") cat "$TEST_WORKFLOW_PERMS_JSON" ;;
  "repos/${GITHUB_REPOSITORY}/actions/permissions") cat "$TEST_ACTIONS_PERMS_JSON" ;;
  "repos/${GITHUB_REPOSITORY}/actions/permissions/artifact-and-log-retention") cat "$TEST_RETENTION_JSON" ;;
  "repos/${GITHUB_REPOSITORY}/commits/main") jq -r .sha "$TEST_MAIN_COMMIT_JSON" ;;
  "repos/${GITHUB_REPOSITORY}/actions/workflows/2024/runs?branch=main&event=workflow_dispatch&per_page=100") cat "$TEST_RUNS_JSON" ;;
  "repos/${GITHUB_REPOSITORY}/actions/runs/74124") cat "$TEST_RUN_JSON" ;;
  "repos/${GITHUB_REPOSITORY}/actions/runs/74124/jobs") cat "$TEST_JOBS_JSON" ;;
  "repos/${GITHUB_REPOSITORY}/actions/runs/74124/cancel") printf '%s\n' "$endpoint" >> "$CANCEL_LOG" ;;
  *) exit 2 ;;
esac
GH
chmod +x "$TMP/bin/gh"
export GITHUB_REPOSITORY=szTheory/sigra PATH="$TMP/bin:$PATH" CANCEL_LOG="$TMP/cancel.log"

echo "Test D0: preflight reads authoritative retention and records an immutable main identity"
jq -n '{default_branch:"main"}' > "$TMP/repo.json"
jq -n '{id:2024,name:"Release Receipt Canary",path:".github/workflows/release-receipt-canary.yml"}' > "$TMP/canary-workflow.json"
jq -n '{id:2025,name:"Release Receipt Canary Controller",path:".github/workflows/release-receipt-canary-controller.yml"}' > "$TMP/controller-workflow.json"
jq -n '{id:2026,name:"Release Run Observer",path:".github/workflows/release-run-observer.yml"}' > "$TMP/observer-workflow.json"
jq -n '{default_workflow_permissions:"read"}' > "$TMP/workflow-perms.json"
jq -n '{enabled:true}' > "$TMP/actions-perms.json"
jq -n '{days:90,maximum_allowed_days:90}' > "$TMP/retention.json"
jq -n --arg sha "$(git -C "$ROOT" rev-parse HEAD)" '{sha:$sha}' > "$TMP/main-commit.json"
export TEST_REPO_JSON="$TMP/repo.json" TEST_CANARY_WORKFLOW_JSON="$TMP/canary-workflow.json"
export TEST_CONTROLLER_WORKFLOW_JSON="$TMP/controller-workflow.json" TEST_OBSERVER_WORKFLOW_JSON="$TMP/observer-workflow.json"
export TEST_WORKFLOW_PERMS_JSON="$TMP/workflow-perms.json" TEST_ACTIONS_PERMS_JSON="$TMP/actions-perms.json"
export TEST_RETENTION_JSON="$TMP/retention.json" TEST_MAIN_COMMIT_JSON="$TMP/main-commit.json"
if bash "$CANARY" --preflight --output "$TMP/ready-preflight.json" && \
   jq -e '.status == "ready" and .artifact_retention_days == 90 and .artifact_retention_maximum_days == 90 and (.target_sha | type == "string") and .workflows.canary.id == 2024' "$TMP/ready-preflight.json" >/dev/null && \
   CANARY_PREFLIGHT_FILE="$TMP/ready-preflight.json" bash "$CANARY" --validate-preflight --output "$TMP/validated-preflight.json"; then
  pass "retention and exact workflow identities are captured before dispatch"
else fail "fresh read-only preflight failed to capture repository settings"; fi
jq '.captured_at="2000-01-01T00:00:00Z"' "$TMP/ready-preflight.json" > "$TMP/stale-preflight.json"
if CANARY_PREFLIGHT_FILE="$TMP/stale-preflight.json" bash "$CANARY" --validate-preflight --output "$TMP/stale-preflight-output.json" >/dev/null 2>&1 || \
   jq -e '.status == "blocked" and .reason == "committed_preflight_stale" and .dispatch_attempted == false' "$TMP/stale-preflight-output.json" >/dev/null; then
  pass "stale preflight blocks dispatch"
else fail "stale preflight was accepted"; fi
jq -n '{days:29,maximum_allowed_days:90}' > "$TMP/retention-low.json"
if TEST_RETENTION_JSON="$TMP/retention-low.json" bash "$CANARY" --preflight --output "$TMP/blocked-preflight.json" >/dev/null 2>&1 || \
   jq -e '.status == "blocked" and .dispatch_attempted == false and .reason == "artifact_retention_below_30_days_or_unreadable"' "$TMP/blocked-preflight.json" >/dev/null; then
  pass "insufficient retention blocks preflight without dispatch"
else fail "insufficient artifact retention did not fail closed"; fi

jq -n '{workflow_runs:[{id:74123,display_title:"release-receipt-canary-failure-0123456789abcdef"}]}' > "$TMP/one-run.json"
if TEST_RUNS_JSON="$TMP/one-run.json" bash "$CANARY" --resolve-run --workflow-id 2024 --scenario failure --probe-id 0123456789abcdef | grep -qx 74123; then
  pass "one exact probe title resolves to its single run ID"
else fail "single exact probe title did not resolve"; fi
jq -n '{workflow_runs:[]}' > "$TMP/no-runs.json"
if TEST_RUNS_JSON="$TMP/no-runs.json" bash "$CANARY" --resolve-run --workflow-id 2024 --scenario failure --probe-id 0123456789abcdef >/dev/null 2>&1; then
  fail "zero probe matches were accepted"
else pass "zero probe matches fail closed"; fi
jq -n '{workflow_runs:[{id:74123,display_title:"release-receipt-canary-failure-0123456789abcdef"},{id:74125,display_title:"release-receipt-canary-failure-0123456789abcdef"}]}' > "$TMP/two-runs.json"
if TEST_RUNS_JSON="$TMP/two-runs.json" bash "$CANARY" --resolve-run --workflow-id 2024 --scenario failure --probe-id 0123456789abcdef >/dev/null 2>&1; then
  fail "two matching probe runs were accepted"
else pass "ambiguous probe matches fail closed"; fi

jq -n '{id:74124,workflow_id:2024,path:".github/workflows/release-receipt-canary.yml@main",name:"Release Receipt Canary",display_title:"release-receipt-canary-cancellation-abcdef0123456789",event:"workflow_dispatch",head_branch:"main",status:"in_progress"}' > "$TMP/canary-run.json"
jq -n '{jobs:[{steps:[{name:"Bounded cancellation wait",status:"in_progress"}]}]}' > "$TMP/waiting-jobs.json"
TEST_RUN_JSON="$TMP/canary-run.json" TEST_JOBS_JSON="$TMP/waiting-jobs.json" bash "$CANARY" --cancel-canary-run 74124 --workflow-id 2024 --probe-id abcdef0123456789 >/dev/null
if [[ "$(cat "$CANCEL_LOG")" == "repos/${GITHUB_REPOSITORY}/actions/runs/74124/cancel" ]]; then
  pass "controller cancels only the exact authorized run at the wait stage"
else fail "controller sent cancellation to another run"; fi
: > "$CANCEL_LOG"
jq '.workflow_id=999' "$TMP/canary-run.json" > "$TMP/wrong-workflow-run.json"
if TEST_RUN_JSON="$TMP/wrong-workflow-run.json" TEST_JOBS_JSON="$TMP/waiting-jobs.json" bash "$CANARY" --cancel-canary-run 74124 --workflow-id 2024 --probe-id abcdef0123456789 >/dev/null 2>&1 || [[ -s "$CANCEL_LOG" ]]; then
  fail "unrelated workflow run was cancellable"
else pass "unrelated workflow run cannot be cancelled"; fi
: > "$CANCEL_LOG"
if TEST_RUN_JSON="$TMP/canary-run.json" TEST_JOBS_JSON="$TMP/waiting-jobs.json" bash "$CANARY" --cancel-canary-run 74124 --workflow-id 2024 --probe-id 0123456789abcdef >/dev/null 2>&1 || [[ -s "$CANCEL_LOG" ]]; then
  fail "another canary probe could be cancelled by this controller"
else pass "a different canary probe cannot be cancelled"; fi

echo "Test E: retained artifact identity and digest are required for proof acceptance"
SHA="$(jq -r '.source_sha' "$TMP/failure.json")"
FAIL_PROBE="$(jq -r '.probe_id' "$TMP/failure.json")"
CANCEL_PROBE="$(jq -r '.probe_id' "$TMP/cancellation.json")"
jq -n --slurpfile failure "$TMP/failure.json" --slurpfile cancellation "$TMP/cancellation.json" \
  --arg sha "$SHA" --arg fail_probe "$FAIL_PROBE" --arg cancel_probe "$CANCEL_PROBE" \
  '{schema_version:1,status:"pass",preflight:{status:"ready"},
    source_failure:{run_id:"74123",attempt:1,workflow_id:2024,workflow_path:".github/workflows/release-receipt-canary.yml@main",
      event:"workflow_dispatch",ref:"refs/heads/main",sha:$sha,conclusion:"failure",created_at:"2026-10-10T10:00:00Z",updated_at:"2026-10-10T10:01:00Z",
      artifact:{id:901,name:("release-canary-failure-74123-1-"+$fail_probe),digest:"sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",expires_at:"2026-11-09T10:00:00Z"},receipt:$failure[0]},
    source_cancellation:{run_id:"74124",attempt:1,workflow_id:2024,workflow_path:".github/workflows/release-receipt-canary.yml@main",
      event:"workflow_dispatch",ref:"refs/heads/main",sha:$sha,conclusion:"cancelled",created_at:"2026-10-10T10:00:00Z",updated_at:"2026-10-10T10:01:00Z",
      artifact:{id:902,name:"release-canary-cancellation-74124-1",digest:"sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",expires_at:"2026-11-09T10:00:00Z"},
      observer_run_id:"34567",observer_attempt:1,observer_workflow_id:2025,observer_workflow_path:".github/workflows/release-run-observer.yml",
      observer_event:"workflow_run",observer_ref:"refs/heads/main",observer_conclusion:"success",receipt:$cancellation[0]},
    retrieval:{failure_zip_sha256:"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",cancellation_zip_sha256:"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"}}' > "$TMP/proof.json"
if bash "$CANARY" --validate-proof "$TMP/proof.json" >/dev/null; then pass "exact identities and downloaded artifact digests validate"; else fail "valid exact proof was rejected"; fi
jq '.source_failure.artifact.digest="sha256:bad"' "$TMP/proof.json" > "$TMP/bad-digest.json"
if bash "$CANARY" --validate-proof "$TMP/bad-digest.json" >/dev/null 2>&1; then fail "malformed artifact digest was accepted"; else pass "malformed or mismatched artifact digest rejected"; fi
jq '.source_failure.artifact.id=0' "$TMP/proof.json" > "$TMP/bad-artifact-id.json"
if bash "$CANARY" --validate-proof "$TMP/bad-artifact-id.json" >/dev/null 2>&1; then fail "invalid artifact ID was accepted"; else pass "invalid artifact ID rejected"; fi
jq '.source_cancellation.observer_run_id="99999"' "$TMP/proof.json" > "$TMP/wrong-observer-run.json"
if bash "$CANARY" --validate-proof "$TMP/wrong-observer-run.json" >/dev/null 2>&1; then fail "wrong observer run ID was accepted"; else pass "wrong observer run ID rejected"; fi

echo "Results: ${PASS} passed, ${FAIL} failed"
if [[ "$FAIL" -gt 0 ]]; then exit 1; fi
echo "release-canary.test: PASS"
