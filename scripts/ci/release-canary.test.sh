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
jq '.source_run_attempt=2' "$TMP/cancellation.json" > "$TMP/mismatched-attempt-pair.json"
if bash "$CANARY" --validate-pair --failure-receipt "$TMP/failure.json" --cancellation-receipt "$TMP/mismatched-attempt-pair.json" >/dev/null 2>&1; then
  fail "receipt pair with mismatched source attempts was accepted"
else pass "receipt pair requires matching source attempts"; fi

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
  "repos/${GITHUB_REPOSITORY}/actions/workflows/2024/runs?branch=main&event=workflow_dispatch&per_page=100")
    if [[ -n "${TEST_RUNS_SEQUENCE_DIR:-}" ]]; then
      count_file="${TEST_RUNS_COUNTER:?}"
      count=0
      [[ ! -f "$count_file" ]] || count="$(cat "$count_file")"
      count=$((count + 1))
      printf '%s\n' "$count" > "$count_file"
      cat "${TEST_RUNS_SEQUENCE_DIR}/${count}.json"
    else
      if [[ -n "${TEST_RUNS_COUNTER:-}" ]]; then
        count=0
        [[ ! -f "$TEST_RUNS_COUNTER" ]] || count="$(cat "$TEST_RUNS_COUNTER")"
        count=$((count + 1))
        printf '%s\n' "$count" > "$TEST_RUNS_COUNTER"
      fi
      cat "$TEST_RUNS_JSON"
    fi
    ;;
  "repos/${GITHUB_REPOSITORY}/actions/runs/74125") cat "$TEST_SOURCE_RUN_JSON" ;;
  "repos/${GITHUB_REPOSITORY}/actions/runs/74125/jobs") cat "$TEST_SOURCE_JOBS_JSON" ;;
  "repos/${GITHUB_REPOSITORY}/actions/runs/74124") cat "$TEST_RUN_JSON" ;;
  "repos/${GITHUB_REPOSITORY}/actions/runs/74124/jobs") cat "$TEST_JOBS_JSON" ;;
  "repos/${GITHUB_REPOSITORY}/actions/runs/74124/cancel") printf '%s\n' "$endpoint" >> "$CANCEL_LOG" ;;
  *) exit 2 ;;
esac
GH
cat > "$TMP/bin/sleep" <<'SLEEP'
#!/usr/bin/env bash
# Keep bounded polling deterministic and fast in the fixture suite.
exit 0
SLEEP
chmod +x "$TMP/bin/gh"
chmod +x "$TMP/bin/sleep"
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
   jq -e '.status == "ready" and .actions_enabled == true and .artifact_retention_days == 90 and .artifact_retention_maximum_days == 90 and (.target_sha | type == "string") and .default_workflow_permissions == "read" and .controller_authority == "actions:write; contents:read" and .source_authority == "actions:read; contents:read" and .observer_authority == "actions:read; contents:read" and .workflows.canary.id == 2024' "$TMP/ready-preflight.json" >/dev/null && \
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

echo "Test D0b: runner-supplied preflight is bounded, digest-bound, and still source-validated"
PREFLIGHT_PAYLOAD="$(cat "$TMP/ready-preflight.json")"
PREFLIGHT_BYTES="$(printf '%s' "$PREFLIGHT_PAYLOAD" | wc -c | tr -d ' ')"
PREFLIGHT_SHA="$(printf '%s' "$PREFLIGHT_PAYLOAD" | shasum -a 256 | awk '{print $1}')"
if RUNNER_TEMP="$TMP" CANARY_PREFLIGHT_JSON="$PREFLIGHT_PAYLOAD" CANARY_PREFLIGHT_SHA256="$PREFLIGHT_SHA" \
   bash "$CANARY" --prepare-preflight-input --output "$TMP/runner-preflight.json" --expected-sha256 "$PREFLIGHT_SHA" >/dev/null 2>&1 && \
   [[ "$(wc -c < "$TMP/runner-preflight.json" | tr -d ' ')" == "$PREFLIGHT_BYTES" ]] && \
   CANARY_PREFLIGHT_FILE="$TMP/runner-preflight.json" bash "$CANARY" --validate-preflight --output "$TMP/runner-validated-preflight.json" >/dev/null 2>&1; then
  pass "fresh supplied preflight reaches shared freshness, workflow, and source-blob validation"
else fail "fresh supplied preflight did not reach shared exact-source validation"; fi

if RUNNER_TEMP="$TMP" CANARY_PREFLIGHT_JSON="$PREFLIGHT_PAYLOAD" CANARY_PREFLIGHT_SHA256="$(printf '%064d' 0)" \
   bash "$CANARY" --prepare-preflight-input --output "$TMP/wrong-digest-preflight.json" --expected-sha256 "$(printf '%064d' 0)" >/dev/null 2>&1 || \
   [[ -e "$TMP/wrong-digest-preflight.json" ]]; then
  fail "preflight input with a mismatched expected digest was persisted"
else pass "mismatched preflight digest rejected before persistence"; fi
jq '.captured_at="2000-01-01T00:00:00Z"' "$TMP/ready-preflight.json" > "$TMP/runner-stale-preflight.json"
RUNNER_STALE_PAYLOAD="$(cat "$TMP/runner-stale-preflight.json")"
RUNNER_STALE_SHA="$(printf '%s' "$RUNNER_STALE_PAYLOAD" | shasum -a 256 | awk '{print $1}')"
if RUNNER_TEMP="$TMP" CANARY_PREFLIGHT_JSON="$RUNNER_STALE_PAYLOAD" CANARY_PREFLIGHT_SHA256="$RUNNER_STALE_SHA" \
   bash "$CANARY" --prepare-preflight-input --output "$TMP/runner-stale-preflight-copy.json" --expected-sha256 "$RUNNER_STALE_SHA" >/dev/null 2>&1 && \
   CANARY_PREFLIGHT_FILE="$TMP/runner-stale-preflight-copy.json" bash "$CANARY" --validate-preflight --output "$TMP/runner-stale-blocked.json" >/dev/null 2>&1; then
  fail "a digest-correct but stale supplied preflight passed validation"
elif jq -e '.status == "blocked" and .reason == "committed_preflight_stale" and .dispatch_attempted == false' "$TMP/runner-stale-blocked.json" >/dev/null 2>&1; then
  pass "stale supplied preflight remains blocked by the shared 900-second gate"
else fail "stale supplied preflight did not fail with a durable stale reason"; fi
jq '.captured_at="2999-01-01T00:00:00Z"' "$TMP/ready-preflight.json" > "$TMP/runner-future-preflight.json"
RUNNER_FUTURE_PAYLOAD="$(cat "$TMP/runner-future-preflight.json")"
RUNNER_FUTURE_SHA="$(printf '%s' "$RUNNER_FUTURE_PAYLOAD" | shasum -a 256 | awk '{print $1}')"
if RUNNER_TEMP="$TMP" CANARY_PREFLIGHT_JSON="$RUNNER_FUTURE_PAYLOAD" CANARY_PREFLIGHT_SHA256="$RUNNER_FUTURE_SHA" \
   bash "$CANARY" --prepare-preflight-input --output "$TMP/runner-future-preflight-copy.json" --expected-sha256 "$RUNNER_FUTURE_SHA" >/dev/null 2>&1 && \
   CANARY_PREFLIGHT_FILE="$TMP/runner-future-preflight-copy.json" bash "$CANARY" --validate-preflight --output "$TMP/runner-future-blocked.json" >/dev/null 2>&1; then
  fail "future-dated supplied preflight passed validation"
elif jq -e '.status == "blocked" and .reason == "committed_preflight_stale" and .dispatch_attempted == false' "$TMP/runner-future-blocked.json" >/dev/null 2>&1; then
  pass "future-dated supplied preflight rejected by the same age bound"
else fail "future-dated supplied preflight lacked a durable timestamp blocker"; fi
jq '.repository="other/repo"' "$TMP/ready-preflight.json" > "$TMP/runner-wrong-repo.json"
RUNNER_WRONG_REPO_PAYLOAD="$(cat "$TMP/runner-wrong-repo.json")"
RUNNER_WRONG_REPO_SHA="$(printf '%s' "$RUNNER_WRONG_REPO_PAYLOAD" | shasum -a 256 | awk '{print $1}')"
if RUNNER_TEMP="$TMP" CANARY_PREFLIGHT_JSON="$RUNNER_WRONG_REPO_PAYLOAD" CANARY_PREFLIGHT_SHA256="$RUNNER_WRONG_REPO_SHA" \
   bash "$CANARY" --prepare-preflight-input --output "$TMP/runner-wrong-repo-copy.json" --expected-sha256 "$RUNNER_WRONG_REPO_SHA" >/dev/null 2>&1 && \
   CANARY_PREFLIGHT_FILE="$TMP/runner-wrong-repo-copy.json" bash "$CANARY" --validate-preflight --output "$TMP/runner-wrong-repo-blocked.json" >/dev/null 2>&1; then
  fail "wrong-repository preflight passed validation"
else pass "wrong-repository preflight rejected"; fi
jq '.target_sha="0000000000000000000000000000000000000000"' "$TMP/ready-preflight.json" > "$TMP/runner-wrong-target.json"
RUNNER_WRONG_TARGET_PAYLOAD="$(cat "$TMP/runner-wrong-target.json")"
RUNNER_WRONG_TARGET_SHA="$(printf '%s' "$RUNNER_WRONG_TARGET_PAYLOAD" | shasum -a 256 | awk '{print $1}')"
if RUNNER_TEMP="$TMP" CANARY_PREFLIGHT_JSON="$RUNNER_WRONG_TARGET_PAYLOAD" CANARY_PREFLIGHT_SHA256="$RUNNER_WRONG_TARGET_SHA" \
   bash "$CANARY" --prepare-preflight-input --output "$TMP/runner-wrong-target-copy.json" --expected-sha256 "$RUNNER_WRONG_TARGET_SHA" >/dev/null 2>&1 && \
   CANARY_PREFLIGHT_FILE="$TMP/runner-wrong-target-copy.json" bash "$CANARY" --validate-preflight --output "$TMP/runner-wrong-target-blocked.json" >/dev/null 2>&1; then
  fail "preflight bound to an unrelated target SHA passed source validation"
elif jq -e '.status == "blocked" and .reason == "default_branch_rewound_after_preflight"' "$TMP/runner-wrong-target-blocked.json" >/dev/null 2>&1; then
  pass "unrelated target SHA rejected by the authoritative ancestry check"
else fail "unrelated target SHA lacked an ancestry blocker"; fi
jq '.workflows.canary.id=9999' "$TMP/ready-preflight.json" > "$TMP/runner-wrong-workflow.json"
RUNNER_WRONG_WORKFLOW_PAYLOAD="$(cat "$TMP/runner-wrong-workflow.json")"
RUNNER_WRONG_WORKFLOW_SHA="$(printf '%s' "$RUNNER_WRONG_WORKFLOW_PAYLOAD" | shasum -a 256 | awk '{print $1}')"
if RUNNER_TEMP="$TMP" CANARY_PREFLIGHT_JSON="$RUNNER_WRONG_WORKFLOW_PAYLOAD" CANARY_PREFLIGHT_SHA256="$RUNNER_WRONG_WORKFLOW_SHA" \
   bash "$CANARY" --prepare-preflight-input --output "$TMP/runner-wrong-workflow-copy.json" --expected-sha256 "$RUNNER_WRONG_WORKFLOW_SHA" >/dev/null 2>&1 && \
   CANARY_PREFLIGHT_FILE="$TMP/runner-wrong-workflow-copy.json" bash "$CANARY" --validate-preflight --output "$TMP/runner-wrong-workflow-blocked.json" >/dev/null 2>&1; then
  fail "preflight bound to a different canary workflow passed source validation"
elif jq -e '.status == "blocked" and .reason == "canary_identity_changed"' "$TMP/runner-wrong-workflow-blocked.json" >/dev/null 2>&1; then
  pass "wrong canary workflow identity rejected by the live Actions check"
else fail "wrong canary workflow identity lacked a durable blocker"; fi
if RUNNER_TEMP="$TMP" CANARY_PREFLIGHT_JSON="${PREFLIGHT_PAYLOAD} " CANARY_PREFLIGHT_SHA256="$PREFLIGHT_SHA" \
   bash "$CANARY" --prepare-preflight-input --output "$TMP/tampered-preflight.json" --expected-sha256 "$PREFLIGHT_SHA" >/dev/null 2>&1 || \
   [[ -e "$TMP/tampered-preflight.json" ]]; then
  fail "preflight bytes changed after digest capture were persisted"
else pass "tampered preflight bytes rejected by digest binding"; fi
if RUNNER_TEMP="$TMP" CANARY_PREFLIGHT_JSON="$(printf '%032769s' x)" CANARY_PREFLIGHT_SHA256="$(printf '%064d' 0)" \
   bash "$CANARY" --prepare-preflight-input --output "$TMP/oversized-preflight.json" --expected-sha256 "$(printf '%064d' 0)" >/dev/null 2>&1 || \
   [[ -e "$TMP/oversized-preflight.json" ]]; then
  fail "oversized preflight input was persisted"
else pass "oversized preflight input rejected before persistence"; fi
jq '.api_key="never persist credential-shaped keys"' "$TMP/ready-preflight.json" > "$TMP/runner-secret-key.json"
RUNNER_SECRET_KEY_PAYLOAD="$(cat "$TMP/runner-secret-key.json")"
RUNNER_SECRET_KEY_SHA="$(printf '%s' "$RUNNER_SECRET_KEY_PAYLOAD" | shasum -a 256 | awk '{print $1}')"
if RUNNER_TEMP="$TMP" CANARY_PREFLIGHT_JSON="$RUNNER_SECRET_KEY_PAYLOAD" CANARY_PREFLIGHT_SHA256="$RUNNER_SECRET_KEY_SHA" \
   bash "$CANARY" --prepare-preflight-input --output "$TMP/runner-secret-key-copy.json" --expected-sha256 "$RUNNER_SECRET_KEY_SHA" >/dev/null 2>&1 || \
   [[ -e "$TMP/runner-secret-key-copy.json" ]]; then
  fail "secret-shaped preflight field was persisted"
else pass "secret-shaped preflight field rejected before persistence"; fi
if RUNNER_TEMP="$TMP" CANARY_PREFLIGHT_JSON='{"schema_version":' CANARY_PREFLIGHT_SHA256="$(printf '%064d' 0)" \
   bash "$CANARY" --prepare-preflight-input --output "$TMP/malformed-preflight.json" --expected-sha256 "$(printf '%064d' 0)" >/dev/null 2>&1 || \
   [[ -e "$TMP/malformed-preflight.json" ]]; then
  fail "malformed preflight JSON was persisted"
else pass "malformed preflight JSON rejected before persistence"; fi

echo "Test D1: the failure receipt builder preserves the workflow scenario environment"
jq -n '{id:74125,workflow_id:2024,path:".github/workflows/release-receipt-canary.yml@main",name:"Release Receipt Canary",
  display_title:"release-receipt-canary-failure-0123456789abcdef",event:"workflow_dispatch",head_branch:"main",
  head_sha:"0123456789abcdef0123456789abcdef01234567",run_attempt:1,run_started_at:"2026-10-10T10:00:00Z"}' > "$TMP/source-run.json"
jq -n '{jobs:[{steps:[{name:"Controlled failure before release operations",conclusion:"failure"}]}]}' > "$TMP/source-jobs.json"
export TEST_SOURCE_RUN_JSON="$TMP/source-run.json" TEST_SOURCE_JOBS_JSON="$TMP/source-jobs.json"
if SCENARIO= PROBE_ID=0123456789abcdef GITHUB_RUN_ID=74125 GITHUB_EVENT_NAME=workflow_dispatch \
   GITHUB_REF=refs/heads/main GH_TOKEN=fixture-token bash "$CANARY" --write-failure-receipt --scenario failure --output "$TMP/source-receipt.json" >/dev/null && \
   jq -e '.scenario == "failure" and .terminal_verdict == "failure" and .source_run_id == "74125"' "$TMP/source-receipt.json" >/dev/null; then
  pass "workflow-provided failure scenario reaches the sanitized receipt"
else fail "workflow-provided failure scenario was lost before receipt validation"; fi

jq -n '{workflow_runs:[{id:74123,workflow_id:2024,path:".github/workflows/release-receipt-canary.yml@main",name:"Release Receipt Canary",display_title:"release-receipt-canary-failure-0123456789abcdef",event:"workflow_dispatch",head_branch:"main",head_sha:"0123456789abcdef0123456789abcdef01234567",run_attempt:1}]}' > "$TMP/one-run.json"
if TEST_RUNS_JSON="$TMP/one-run.json" bash "$CANARY" --resolve-run --workflow-id 2024 --scenario failure --probe-id 0123456789abcdef --expected-sha 0123456789abcdef0123456789abcdef01234567 | grep -qx 74123; then
  pass "one exact probe title and source identity resolve to its single run ID"
else fail "single exact probe title did not resolve"; fi
mkdir -p "$TMP/delayed-runs"
jq -n '{workflow_runs:[]}' > "$TMP/delayed-runs/1.json"
cp "$TMP/one-run.json" "$TMP/delayed-runs/2.json"
if TEST_RUNS_SEQUENCE_DIR="$TMP/delayed-runs" TEST_RUNS_COUNTER="$TMP/delayed-run-count" \
   bash "$CANARY" --resolve-run --workflow-id 2024 --scenario failure --probe-id 0123456789abcdef --expected-sha 0123456789abcdef0123456789abcdef01234567 | grep -qx 74123 && \
   [[ "$(cat "$TMP/delayed-run-count")" == 2 ]]; then
  pass "delayed exact probe visibility is correlated by bounded polling"
else fail "delayed exact probe visibility was not retried"; fi
jq -n '{workflow_runs:[]}' > "$TMP/no-runs.json"
if TEST_RUNS_JSON="$TMP/no-runs.json" TEST_RUNS_COUNTER="$TMP/empty-run-count" \
   bash "$CANARY" --resolve-run --workflow-id 2024 --scenario failure --probe-id 0123456789abcdef --expected-sha 0123456789abcdef0123456789abcdef01234567 >/dev/null 2>&1; then
  fail "zero probe matches were accepted"
elif [[ "$(cat "$TMP/empty-run-count")" == 11 ]]; then
  pass "zero probe matches fail closed after the bounded lookup window"
else fail "zero probe matches did not stop at the bounded lookup limit"; fi
jq -n '{workflow_runs:[{id:74123,workflow_id:2024,path:".github/workflows/release-receipt-canary.yml@main",name:"Release Receipt Canary",display_title:"release-receipt-canary-failure-0123456789abcdef",event:"workflow_dispatch",head_branch:"main",head_sha:"0123456789abcdef0123456789abcdef01234567",run_attempt:1},{id:74125,workflow_id:2024,path:".github/workflows/release-receipt-canary.yml@main",name:"Release Receipt Canary",display_title:"release-receipt-canary-failure-0123456789abcdef",event:"workflow_dispatch",head_branch:"main",head_sha:"0123456789abcdef0123456789abcdef01234567",run_attempt:1}]}' > "$TMP/two-runs.json"
if TEST_RUNS_JSON="$TMP/two-runs.json" TEST_RUNS_COUNTER="$TMP/ambiguous-run-count" \
   bash "$CANARY" --resolve-run --workflow-id 2024 --scenario failure --probe-id 0123456789abcdef --expected-sha 0123456789abcdef0123456789abcdef01234567 >/dev/null 2>&1; then
  fail "two matching probe runs were accepted"
elif [[ "$(cat "$TMP/ambiguous-run-count")" == 1 ]]; then
  pass "ambiguous probe matches fail closed without retrying";
else fail "ambiguous probe lookup did not stop immediately"; fi

jq -n '{workflow_runs:[{id:74123,workflow_id:2024,path:".github/workflows/release-receipt-canary.yml@main",name:"Release Receipt Canary",display_title:"release-receipt-canary-failure-0123456789abcdef",event:"workflow_dispatch",head_branch:"main",head_sha:"ffffffffffffffffffffffffffffffffffffffff",run_attempt:1}]}' > "$TMP/wrong-source-run.json"
if TEST_RUNS_JSON="$TMP/wrong-source-run.json" bash "$CANARY" --resolve-run --workflow-id 2024 --scenario failure --probe-id 0123456789abcdef --expected-sha 0123456789abcdef0123456789abcdef01234567 >/dev/null 2>&1; then
  fail "matching title with a different source SHA was accepted"
else pass "exact-title run with a mismatched source SHA is rejected"; fi

jq -n '{id:74124,workflow_id:2024,path:".github/workflows/release-receipt-canary.yml@main",name:"Release Receipt Canary",display_title:"release-receipt-canary-cancellation-abcdef0123456789",event:"workflow_dispatch",head_branch:"main",head_sha:"0123456789abcdef0123456789abcdef01234567",run_attempt:1,status:"in_progress"}' > "$TMP/canary-run.json"
jq -n '{jobs:[{steps:[{name:"Bounded cancellation wait",status:"in_progress"}]}]}' > "$TMP/waiting-jobs.json"
TEST_RUN_JSON="$TMP/canary-run.json" TEST_JOBS_JSON="$TMP/waiting-jobs.json" bash "$CANARY" --cancel-canary-run 74124 --workflow-id 2024 --probe-id abcdef0123456789 --expected-sha 0123456789abcdef0123456789abcdef01234567 >/dev/null
if [[ "$(cat "$CANCEL_LOG")" == "repos/${GITHUB_REPOSITORY}/actions/runs/74124/cancel" ]]; then
  pass "controller cancels only the exact authorized run at the wait stage"
else fail "controller sent cancellation to another run"; fi
: > "$CANCEL_LOG"
for mutation in workflow_id path name event branch sha attempt status title; do
  jq --arg mutation "$mutation" '
    if $mutation == "workflow_id" then .workflow_id=999
    elif $mutation == "path" then .path=".github/workflows/release-please.yml@main"
    elif $mutation == "name" then .name="Release Please"
    elif $mutation == "event" then .event="push"
    elif $mutation == "branch" then .head_branch="release/1.6.0"
    elif $mutation == "sha" then .head_sha="ffffffffffffffffffffffffffffffffffffffff"
    elif $mutation == "attempt" then .run_attempt=2
    elif $mutation == "status" then .status="completed"
    else .display_title="release-receipt-canary-cancellation-elsewhere" end
  ' "$TMP/canary-run.json" > "$TMP/wrong-$mutation-run.json"
  if TEST_RUN_JSON="$TMP/wrong-$mutation-run.json" TEST_JOBS_JSON="$TMP/waiting-jobs.json" \
     bash "$CANARY" --cancel-canary-run 74124 --workflow-id 2024 --probe-id abcdef0123456789 --expected-sha 0123456789abcdef0123456789abcdef01234567 >/dev/null 2>&1 || [[ -s "$CANCEL_LOG" ]]; then
    fail "mismatched $mutation run was cancellable"
  else pass "mismatched $mutation run cannot be cancelled"; fi
  : > "$CANCEL_LOG"
done
if TEST_RUN_JSON="$TMP/canary-run.json" TEST_JOBS_JSON="$TMP/waiting-jobs.json" bash "$CANARY" --cancel-canary-run 74124 --workflow-id 2024 --probe-id 0123456789abcdef --expected-sha 0123456789abcdef0123456789abcdef01234567 >/dev/null 2>&1 || [[ -s "$CANCEL_LOG" ]]; then
  fail "another canary probe could be cancelled by this controller"
else pass "a different canary probe cannot be cancelled"; fi

echo "Test E: retained artifact identity and digest are required for proof acceptance"
SHA="$(jq -r '.source_sha' "$TMP/failure.json")"
FAIL_PROBE="$(jq -r '.probe_id' "$TMP/failure.json")"
CANCEL_PROBE="$(jq -r '.probe_id' "$TMP/cancellation.json")"
jq -n --slurpfile failure "$TMP/failure.json" --slurpfile cancellation "$TMP/cancellation.json" \
  --arg sha "$SHA" --arg fail_probe "$FAIL_PROBE" --arg cancel_probe "$CANCEL_PROBE" \
  '{schema_version:1,status:"pass",preflight:{status:"ready",credential_values_recorded:false},credential_values_recorded:false,
    source_failure:{run_id:"74123",attempt:1,workflow_id:2024,workflow_path:".github/workflows/release-receipt-canary.yml@main",
      event:"workflow_dispatch",ref:"refs/heads/main",sha:$sha,conclusion:"failure",created_at:"2026-10-10T10:00:00Z",updated_at:"2026-10-10T10:01:00Z",
      artifact:{id:901,name:("release-canary-failure-74123-1-"+$fail_probe),digest:"sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",expires_at:"2026-11-09T10:00:00Z"},receipt:$failure[0]},
    source_cancellation:{run_id:"74124",attempt:1,workflow_id:2024,workflow_path:".github/workflows/release-receipt-canary.yml@main",
      event:"workflow_dispatch",ref:"refs/heads/main",sha:$sha,conclusion:"cancelled",created_at:"2026-10-10T10:00:00Z",updated_at:"2026-10-10T10:01:00Z",
      artifact:{id:902,name:"release-canary-cancellation-74124-1",digest:"sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",expires_at:"2026-11-09T10:00:00Z"},
      observer_run_id:"34567",observer_attempt:1,observer_workflow_id:2025,observer_workflow_path:".github/workflows/release-run-observer.yml",
      observer_event:"workflow_run",observer_ref:"refs/heads/main",observer_conclusion:"success",receipt:$cancellation[0]},
    retrieval:{failure_zip_sha256:"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",cancellation_zip_sha256:"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"}}' > "$TMP/proof.json"
if bash "$CANARY" --validate-proof "$TMP/proof.json" >/dev/null; then pass "exact identities, safe credential metadata, and downloaded artifact digests validate"; else fail "valid exact proof with real preflight metadata was rejected"; fi
jq '.preflight.credentials={HEX_API_KEY:"must-not-be-recorded"}' "$TMP/proof.json" > "$TMP/proof-with-credential-key.json"
if bash "$CANARY" --validate-proof "$TMP/proof-with-credential-key.json" >/dev/null 2>&1; then fail "credential-shaped preflight fields were accepted"; else pass "credential-shaped preflight fields remain rejected"; fi
jq '.credential_values_recorded=true' "$TMP/proof.json" > "$TMP/proof-with-recorded-credentials.json"
if bash "$CANARY" --validate-proof "$TMP/proof-with-recorded-credentials.json" >/dev/null 2>&1; then fail "proof marked as recording credential values was accepted"; else pass "proof marked as recording credential values is rejected"; fi
jq '.source_failure.artifact.digest="sha256:bad"' "$TMP/proof.json" > "$TMP/bad-digest.json"
if bash "$CANARY" --validate-proof "$TMP/bad-digest.json" >/dev/null 2>&1; then fail "malformed artifact digest was accepted"; else pass "malformed or mismatched artifact digest rejected"; fi
jq '.source_failure.artifact.id=0' "$TMP/proof.json" > "$TMP/bad-artifact-id.json"
if bash "$CANARY" --validate-proof "$TMP/bad-artifact-id.json" >/dev/null 2>&1; then fail "invalid artifact ID was accepted"; else pass "invalid artifact ID rejected"; fi
jq '.source_cancellation.observer_run_id="99999"' "$TMP/proof.json" > "$TMP/wrong-observer-run.json"
if bash "$CANARY" --validate-proof "$TMP/wrong-observer-run.json" >/dev/null 2>&1; then fail "wrong observer run ID was accepted"; else pass "wrong observer run ID rejected"; fi

echo "Test F: a 204 dispatch reaches an exact failure receipt and retrieved artifact"
FLOW="$TMP/flow"
mkdir -p "$FLOW/bin" "$FLOW/preflight-dir"
FLOW_SHA="$(git -C "$ROOT" rev-parse HEAD)"
FLOW_CAPTURED="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
jq -n --arg sha "$FLOW_SHA" --arg captured "$FLOW_CAPTURED" \
  '{schema_version:1,status:"ready",captured_at:$captured,repository:"szTheory/sigra",default_branch:"main",target_sha:$sha,
    actions_enabled:true,artifact_retention_days:90,artifact_retention_maximum_days:90,required_retention_days:30,
    workflows:{canary:{id:2024,path:".github/workflows/release-receipt-canary.yml"},
      controller:{id:2025,path:".github/workflows/release-receipt-canary-controller.yml"},
      observer:{id:2026,path:".github/workflows/release-run-observer.yml"}},
    default_workflow_permissions:"read",controller_authority:"actions:write; contents:read",
    source_authority:"actions:read; contents:read",observer_authority:"actions:read; contents:read",
    credential_values_recorded:false,dispatch_attempted:false}' > "$FLOW/preflight.json"
jq '.captured_at="2000-01-01T00:00:00Z"' "$FLOW/preflight.json" > "$FLOW/committed-preflight.json"
FLOW_PREFLIGHT_PAYLOAD="$(cat "$FLOW/preflight.json")"
FLOW_PREFLIGHT_SHA="$(printf '%s' "$FLOW_PREFLIGHT_PAYLOAD" | shasum -a 256 | awk '{print $1}')"
if RUNNER_TEMP="$FLOW" CANARY_PREFLIGHT_JSON="$FLOW_PREFLIGHT_PAYLOAD" CANARY_PREFLIGHT_SHA256="$FLOW_PREFLIGHT_SHA" \
   bash "$CANARY" --prepare-preflight-input --output "$FLOW/runner-preflight.json" --expected-sha256 "$FLOW_PREFLIGHT_SHA" >/dev/null 2>&1; then
  pass "controller input preparation accepts exact fresh packet bytes"
else fail "fresh controller preflight input could not be prepared"; fi
if CANARY_PREFLIGHT_FILE="$FLOW/committed-preflight.json" bash "$CANARY" --validate-preflight --output "$FLOW/stale-committed-blocked.json" >/dev/null 2>&1; then
  fail "stale committed preflight unexpectedly passed the standard path"
elif jq -e '.status == "blocked" and .reason == "committed_preflight_stale"' "$FLOW/stale-committed-blocked.json" >/dev/null 2>&1; then
  pass "stale committed preflight is blocked while a fresh runner payload is available"
else fail "stale committed preflight did not retain its stale reason"; fi
cat > "$FLOW/bin/gh" <<'GH_FLOW'
#!/usr/bin/env bash
set -euo pipefail
[[ "${1:-}" == api ]] || { [[ "${1:-}" == run && "${2:-}" == watch ]] || exit 2; }
if [[ "${1:-}" == run ]]; then
  run_id="${3:-}"
  printf '%s\n' "$run_id" >> "$FLOW_WATCH_LOG"
  [[ "$run_id" == 74125 ]] || exit 0
  probe="$(cat "$FLOW/failure-probe")"
  jq -n --arg probe "$probe" --arg sha "$FLOW_SHA" \
    '{id:74125,workflow_id:2024,path:".github/workflows/release-receipt-canary.yml@main",name:"Release Receipt Canary",
      display_title:("release-receipt-canary-failure-"+$probe),event:"workflow_dispatch",head_branch:"main",head_sha:$sha,
      run_attempt:1,run_started_at:"2026-10-10T10:00:00Z",status:"completed",conclusion:"failure",
      created_at:"2026-10-10T10:00:00Z",updated_at:"2026-10-10T10:01:00Z"}' > "$FLOW/source-run.json"
  jq -n '{jobs:[{steps:[{name:"Controlled failure before release operations",conclusion:"failure"}]}]}' > "$FLOW/source-jobs.json"
  GITHUB_REPOSITORY=szTheory/sigra GITHUB_RUN_ID=74125 GITHUB_EVENT_NAME=workflow_dispatch GITHUB_REF=refs/heads/main \
    GH_TOKEN=fixture-token PROBE_ID="$probe" \
    bash "$FLOW_CANARY" --write-failure-receipt --scenario failure --output "$FLOW/failure-receipt.json" >/dev/null
  mkdir -p "$FLOW/failure-zip-dir"
  cp "$FLOW/failure-receipt.json" "$FLOW/failure-zip-dir/canary-receipt.json"
  (cd "$FLOW/failure-zip-dir" && zip -q "$FLOW/failure.zip" canary-receipt.json)
  exit 0
fi

endpoint=""
output=""
if [[ "${2:-}" == --method ]]; then endpoint="${4:-}"; else endpoint="${2:-}"; fi
printf '%s\t%s\n' "$endpoint" "$*" >> "$FLOW/api.log"
for ((i=2; i<=$#; i++)); do
  arg="${!i}"
  if [[ "$arg" == --output ]]; then j=$((i+1)); output="${!j}"; fi
done
case "$endpoint" in
  "rate_limit") jq -n '{resources:{core:{remaining:500}}}' ;;
  "repos/${GITHUB_REPOSITORY}") jq -n '{default_branch:"main"}' ;;
  "repos/${GITHUB_REPOSITORY}/actions/workflows/release-receipt-canary.yml") jq -n '{id:2024,name:"Release Receipt Canary",path:".github/workflows/release-receipt-canary.yml"}' ;;
  "repos/${GITHUB_REPOSITORY}/actions/workflows/release-receipt-canary-controller.yml") jq -n '{id:2025,name:"Release Receipt Canary Controller",path:".github/workflows/release-receipt-canary-controller.yml"}' ;;
  "repos/${GITHUB_REPOSITORY}/actions/workflows/release-run-observer.yml") jq -n '{id:2026,name:"Release Run Observer",path:".github/workflows/release-run-observer.yml"}' ;;
  "repos/${GITHUB_REPOSITORY}/actions/permissions/workflow") jq -n '{default_workflow_permissions:"read"}' ;;
  "repos/${GITHUB_REPOSITORY}/actions/permissions") jq -n '{enabled:true}' ;;
  "repos/${GITHUB_REPOSITORY}/actions/permissions/artifact-and-log-retention") jq -n '{days:90,maximum_allowed_days:90}' ;;
  "repos/${GITHUB_REPOSITORY}/commits/main") jq -rn --arg sha "$FLOW_SHA" '$sha' ;;
  "repos/${GITHUB_REPOSITORY}/actions/workflows/2024/runs?branch=main&event=workflow_dispatch&per_page=100")
    scenario=""; probe=""
    for arg in "$@"; do case "$arg" in inputs\[scenario\]=*) scenario="${arg#*=}" ;; inputs\[probe_id\]=*) probe="${arg#*=}" ;; esac; done
    if [[ "$endpoint" == *dispatches ]]; then exit 0; fi
    if [[ -n "$scenario" ]]; then
      printf '%s\n' "$scenario" > "$FLOW/scenario"
      printf '%s\n' "$probe" > "$FLOW/probe"
      exit 0
    fi
    current_scenario="$(cat "$FLOW/scenario")"; current_probe="$(cat "$FLOW/probe")"
    query_count=0; [[ ! -f "$FLOW/run-list-count" ]] || query_count="$(cat "$FLOW/run-list-count")"
    query_count=$((query_count + 1)); printf '%s\n' "$query_count" > "$FLOW/run-list-count"
    if [[ "$current_scenario" == failure && "$query_count" == 1 ]]; then jq -n '{workflow_runs:[]}'; else
      id=74125; [[ "$current_scenario" != cancellation ]] || id=74126
      jq -n --arg probe "$current_probe" --arg sha "$FLOW_SHA" --arg scenario "$current_scenario" --argjson id "$id" \
        '{workflow_runs:[{id:$id,workflow_id:2024,path:".github/workflows/release-receipt-canary.yml@main",name:"Release Receipt Canary",
          display_title:("release-receipt-canary-"+$scenario+"-"+$probe),event:"workflow_dispatch",head_branch:"main",head_sha:$sha,run_attempt:1}]}'
    fi ;;
  "repos/${GITHUB_REPOSITORY}/actions/workflows/2024/dispatches")
    scenario=""; probe=""
    for arg in "$@"; do case "$arg" in inputs\[scenario\]=*) scenario="${arg#*=}" ;; inputs\[probe_id\]=*) probe="${arg#*=}" ;; esac; done
    printf '%s\n' "$scenario" > "$FLOW/scenario"
    printf '%s\n' "$probe" > "$FLOW/probe"
    [[ "$scenario" != failure ]] || printf '%s\n' "$probe" > "$FLOW/failure-probe"
    exit 0 ;;
  "repos/${GITHUB_REPOSITORY}/actions/runs/74125")
    if [[ -f "$FLOW/source-run.json" ]]; then cat "$FLOW/source-run.json"; else
      probe="$(cat "$FLOW/failure-probe")"
      jq -n --arg probe "$probe" --arg sha "$FLOW_SHA" '{id:74125,workflow_id:2024,path:".github/workflows/release-receipt-canary.yml@main",name:"Release Receipt Canary",display_title:("release-receipt-canary-failure-"+$probe),event:"workflow_dispatch",head_branch:"main",head_sha:$sha,run_attempt:1,run_started_at:"2026-10-10T10:00:00Z",status:"completed",conclusion:"failure",created_at:"2026-10-10T10:00:00Z",updated_at:"2026-10-10T10:01:00Z"}'; fi ;;
  "repos/${GITHUB_REPOSITORY}/actions/runs/74125/jobs") cat "$FLOW/source-jobs.json" ;;
  "repos/${GITHUB_REPOSITORY}/actions/runs/74126")
    probe="$(cat "$FLOW/probe")"
    if [[ -f "$FLOW/cancelled" ]]; then status=completed; conclusion=cancelled; else status=in_progress; conclusion=null; fi
    jq -n --arg probe "$probe" --arg sha "$FLOW_SHA" --arg status "$status" --arg conclusion "$conclusion" \
      '{id:74126,workflow_id:2024,path:".github/workflows/release-receipt-canary.yml@main",name:"Release Receipt Canary",display_title:("release-receipt-canary-cancellation-"+$probe),event:"workflow_dispatch",head_branch:"main",head_sha:$sha,run_attempt:1,run_started_at:"2026-10-10T10:00:00Z",status:$status,conclusion:(if $conclusion == "null" then null else $conclusion end),created_at:"2026-10-10T10:00:00Z",updated_at:"2026-10-10T10:01:00Z"}' > "$FLOW/cancel-run.json"
    cat "$FLOW/cancel-run.json" ;;
  "repos/${GITHUB_REPOSITORY}/actions/runs/74126/jobs") jq -n '{jobs:[{steps:[{name:"Bounded cancellation wait",status:"in_progress"}]}]}' > "$FLOW/cancel-jobs.json"; cat "$FLOW/cancel-jobs.json" ;;
  "repos/${GITHUB_REPOSITORY}/actions/runs/74126/cancel") touch "$FLOW/cancelled" ;;
  "repos/${GITHUB_REPOSITORY}/actions/runs/74125/artifacts")
    [[ -f "$FLOW/failure.zip" ]] || exit 1
    digest="$(shasum -a 256 "$FLOW/failure.zip" | awk '{print $1}')"
    probe="$(cat "$FLOW/failure-probe")"
    jq -n --arg probe "$probe" --arg digest "sha256:$digest" '{artifacts:[{id:901,name:("release-canary-failure-74125-1-"+$probe),expired:false,workflow_run:{id:74125},digest:$digest,expires_at:"2026-11-09T10:00:00Z"}]}' ;;
  "repos/${GITHUB_REPOSITORY}/actions/workflows/2026/runs?branch=main&event=workflow_run&per_page=100") jq -n '{workflow_runs:[{id:34567,display_title:"release-observer-74126-34567-1"}]}' ;;
  "repos/${GITHUB_REPOSITORY}/actions/runs/34567") jq -n '{id:34567,run_attempt:1,workflow_id:2026,path:".github/workflows/release-run-observer.yml",event:"workflow_run",head_branch:"main",head_sha:"0000000000000000000000000000000000000000",status:"completed",conclusion:"success",created_at:"2026-10-10T10:02:00Z",updated_at:"2026-10-10T10:03:00Z"}' ;;
  "repos/${GITHUB_REPOSITORY}/actions/runs/34567/artifacts")
    if [[ ! -f "$FLOW/cancellation.zip" ]]; then
      cancel_probe="$(cat "$FLOW/probe")"
      jq -n --arg probe "$cancel_probe" --arg sha "$FLOW_SHA" \
        '{schema_version:1,receipt_kind:"canary",canary:{probe_id:$probe,scenario:"cancellation"},source_event:"workflow_dispatch",
          source:{repository:"szTheory/sigra",ref:"refs/heads/main",sha:$sha},source_run:{id:"74126",attempt:1,workflow_id:2024,
            workflow_name:"Release Receipt Canary",workflow_path:".github/workflows/release-receipt-canary.yml",url:"https://github.com/szTheory/sigra/actions/runs/74126",
            started_at:"2026-10-10T10:00:00Z",observed_at:"2026-10-10T10:01:00Z"},terminal_verdict:"cancelled",
          observer_run:{id:"34567",attempt:1,workflow_id:2026,url:"https://github.com/szTheory/sigra/actions/runs/34567",
            started_at:"2026-10-10T10:02:00Z",observed_at:"2026-10-10T10:03:00Z"}}' > "$FLOW/cancellation-input.json"
      bash "$FLOW_RECEIPT" --mode canary --expected-workflow-id 2024 --input "$FLOW/cancellation-input.json" --output "$FLOW/cancellation-receipt.json" >/dev/null
      mkdir -p "$FLOW/cancellation-zip-dir"
      cp "$FLOW/cancellation-receipt.json" "$FLOW/cancellation-zip-dir/canary-receipt.json"
      (cd "$FLOW/cancellation-zip-dir" && zip -q "$FLOW/cancellation.zip" canary-receipt.json)
    fi
    digest="$(shasum -a 256 "$FLOW/cancellation.zip" | awk '{print $1}')"
    jq -n --arg digest "sha256:$digest" '{artifacts:[{id:902,name:"release-canary-cancellation-74126-1",expired:false,workflow_run:{id:34567},digest:$digest,expires_at:"2026-11-09T10:00:00Z"}]}' ;;
  "repos/${GITHUB_REPOSITORY}/actions/artifacts/901/zip") cp "$FLOW/failure.zip" "$output" ;;
  "repos/${GITHUB_REPOSITORY}/actions/artifacts/902/zip") cp "$FLOW/cancellation.zip" "$output" ;;
  *) exit 2 ;;
esac
GH_FLOW
cat > "$FLOW/bin/sleep" <<'SLEEP_FLOW'
#!/usr/bin/env bash
exit 0
SLEEP_FLOW
chmod +x "$FLOW/bin/gh" "$FLOW/bin/sleep"
if CANARY_PREFLIGHT_FILE="$FLOW/runner-preflight.json" GITHUB_REPOSITORY=szTheory/sigra GITHUB_EVENT_NAME=workflow_dispatch \
   GITHUB_REF=refs/heads/main GH_TOKEN=fixture-token FLOW="$FLOW" FLOW_SHA="$FLOW_SHA" FLOW_WATCH_LOG="$FLOW/watch.log" \
   FLOW_CANARY="$CANARY" FLOW_RECEIPT="$RECEIPT" PATH="$FLOW/bin:$PATH" \
   bash "$CANARY" --run --proof "$FLOW/proof.json" > "$FLOW/stdout.log" 2> "$FLOW/stderr.log"; then
  if jq -e --arg sha "$FLOW_SHA" '.status == "pass" and .source_failure.receipt.source_sha == $sha and
      .source_failure.receipt.terminal_verdict == "failure" and .source_cancellation.receipt.terminal_verdict == "cancelled" and
      .retrieval.failure_zip_sha256 == (.source_failure.artifact.digest | sub("^sha256:";"")) and
      .retrieval.cancellation_zip_sha256 == (.source_cancellation.artifact.digest | sub("^sha256:";""))' "$FLOW/proof.json" >/dev/null && \
     [[ "$(wc -l < "$FLOW/watch.log" | tr -d ' ')" == 3 ]]; then
    pass "204 dispatch, eventual exact-source correlation, paired receipts, artifact ZIP digests, and retrieved JSON validate end to end"
  else
    fail "controller proof omitted exact receipt and retrieval evidence"
  fi
else
  cat "$FLOW/stderr.log" >&2
  [[ ! -f "$FLOW/api.log" ]] || tail -n 25 "$FLOW/api.log" >&2
  [[ ! -f "$FLOW/cancel-run.json" ]] || jq '{id,workflow_id,path,name,display_title,event,head_branch,head_sha,run_attempt,status}' "$FLOW/cancel-run.json" >&2
  [[ ! -f "$FLOW/proof.json" ]] || jq '{status,reason,source_failure,source_cancellation}' "$FLOW/proof.json" >&2
  fail "failure tracer did not reach exact artifact retrieval"
fi

echo "Results: ${PASS} passed, ${FAIL} failed"
if [[ "$FAIL" -gt 0 ]]; then exit 1; fi
echo "release-canary.test: PASS"
