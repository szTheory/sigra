#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
mkdir -p "$TMP_DIR/bin"
PASS=0
FAIL=0
REPOSITORY="szTheory/sigra"
SOURCE_RUN_ID=74123
OBSERVER_RUN_ID=98123
SOURCE_SHA="1111111111111111111111111111111111111111"

pass() { PASS=$((PASS + 1)); echo "  PASS: $*"; }
fail() { FAIL=$((FAIL + 1)); echo "  FAIL: $*" >&2; }

cat > "$TMP_DIR/bin/gh" <<'GH'
#!/usr/bin/env bash
set -euo pipefail
[[ "${1:-}" == api ]] || { echo "unexpected gh command" >&2; exit 2; }
endpoint="${2:-}"
case "$endpoint" in
  "repos/${GITHUB_REPOSITORY}/actions/runs/${TEST_SOURCE_RUN_ID}")
    cat "$TEST_RUN_JSON"
    ;;
  "repos/${GITHUB_REPOSITORY}/actions/workflows/release-please.yml")
    cat "$TEST_WORKFLOW_JSON"
    ;;
  "repos/${GITHUB_REPOSITORY}/actions/workflows/release-receipt-canary.yml")
    cat "$TEST_CANARY_WORKFLOW_JSON"
    ;;
  "repos/${GITHUB_REPOSITORY}/actions/workflows/release-run-observer.yml")
    jq -n '{id:2026,name:"Release Run Observer",path:".github/workflows/release-run-observer.yml",state:"active"}'
    ;;
  "repos/${GITHUB_REPOSITORY}/actions/runs/98123")
    jq -n '{id:98123,run_attempt:1,workflow_id:2026,path:".github/workflows/release-run-observer.yml",event:"workflow_dispatch",head_branch:"main",head_sha:"2222222222222222222222222222222222222222",status:"in_progress",conclusion:null,run_started_at:"2026-10-10T10:02:00Z",html_url:"https://github.com/szTheory/sigra/actions/runs/98123"}'
    ;;
  "repos/${GITHUB_REPOSITORY}/contents/.release-please-manifest.json?ref=${TEST_SOURCE_SHA}")
    if [[ "${TEST_MANIFEST_MISSING:-false}" == true ]]; then exit 1; fi
    base64 < "$TEST_MANIFEST_JSON" | tr -d '\n'
    ;;
  "repos/${GITHUB_REPOSITORY}/commits/${TEST_SOURCE_TAG}")
    [[ -n "${TEST_TAG_SHA:-}" ]] || exit 1
    jq -cn --arg sha "$TEST_TAG_SHA" '{sha:$sha}'
    ;;
  *) echo "unexpected gh API endpoint: $endpoint" >&2; exit 2 ;;
esac
GH
chmod +x "$TMP_DIR/bin/gh"

write_fixtures() {
  local event="${1:-push}" branch="${2:-main}" conclusion="${3:-cancelled}"
  local api_event="${4:-$event}" api_sha="${5:-$SOURCE_SHA}"
  local run_id="${6:-$SOURCE_RUN_ID}" repository="${7:-$REPOSITORY}" workflow_id="${8:-2024}"
  mkdir -p "$TMP_DIR/fixture"
  jq -n --arg repository "$repository" --arg event "$event" --arg sha "$SOURCE_SHA" \
    --arg branch "$branch" --arg conclusion "$conclusion" --arg name "Release Please" \
    --argjson id "$SOURCE_RUN_ID" --argjson workflow_id 2024 \
    '{repository:{full_name:$repository},workflow_run:{id:$id,name:$name,event:$event,head_branch:$branch,head_sha:$sha,conclusion:$conclusion,workflow_id:$workflow_id}}' \
    > "$TMP_DIR/fixture/event.json"
  jq -n --arg repository "$repository" --arg event "$api_event" --arg sha "$api_sha" \
    --arg branch "$branch" --arg conclusion "$conclusion" --arg name "Release Please" \
    --arg url "https://github.com/${REPOSITORY}/actions/runs/${run_id}" \
    --argjson id "$run_id" --argjson attempt 2 --argjson workflow_id "$workflow_id" \
    '{id:$id,name:$name,workflow_id:$workflow_id,path:".github/workflows/release-please.yml@main",event:$event,head_branch:$branch,head_sha:$sha,conclusion:$conclusion,run_attempt:$attempt,run_started_at:"2026-10-08T18:10:00.123Z",updated_at:"2026-10-08T18:20:00Z",html_url:$url,repository:{full_name:$repository}}' \
    > "$TMP_DIR/fixture/run.json"
  jq -n --argjson id "$workflow_id" '{id:$id,name:"Release Please",path:".github/workflows/release-please.yml",state:"active"}' \
    > "$TMP_DIR/fixture/workflow.json"
  printf '{".":"1.6.0"}\n' > "$TMP_DIR/fixture/manifest.json"
  export TEST_SOURCE_RUN_ID="$SOURCE_RUN_ID" TEST_SOURCE_SHA="$SOURCE_SHA" \
    TEST_SOURCE_TAG="v1.6.0" TEST_RUN_JSON="$TMP_DIR/fixture/run.json" \
    TEST_WORKFLOW_JSON="$TMP_DIR/fixture/workflow.json" \
    TEST_MANIFEST_JSON="$TMP_DIR/fixture/manifest.json" TEST_TAG_SHA="$SOURCE_SHA"
}

write_canary_fixtures() {
  local probe="0123456789abcdef0123456789abcdef" run_id=74124
  jq -n --arg sha "$SOURCE_SHA" --arg probe "$probe" \
    --arg url "https://github.com/${REPOSITORY}/actions/runs/${run_id}" \
    '{id:74124,name:"Release Receipt Canary",workflow_id:2025,path:".github/workflows/release-receipt-canary.yml@main",
      display_title:("release-receipt-canary-cancellation-"+$probe),event:"workflow_dispatch",head_branch:"main",head_sha:$sha,
      conclusion:"cancelled",run_attempt:1,run_started_at:"2026-10-10T10:00:00Z",updated_at:"2026-10-10T10:01:00Z",
      html_url:$url,repository:{full_name:"szTheory/sigra"}}' > "$TMP_DIR/fixture/canary-run.json"
  jq -n '{id:2025,name:"Release Receipt Canary",path:".github/workflows/release-receipt-canary.yml",state:"active"}' > "$TMP_DIR/fixture/canary-workflow.json"
  export TEST_SOURCE_RUN_ID="$run_id" TEST_SOURCE_SHA="$SOURCE_SHA" \
    TEST_RUN_JSON="$TMP_DIR/fixture/canary-run.json" TEST_CANARY_WORKFLOW_JSON="$TMP_DIR/fixture/canary-workflow.json"
}

run_dispatched_observer() {
  local output="$1"
  GITHUB_REPOSITORY="$REPOSITORY" GITHUB_RUN_ID="$OBSERVER_RUN_ID" GITHUB_RUN_ATTEMPT=1 \
    GITHUB_EVENT_NAME=workflow_dispatch GITHUB_SERVER_URL=https://github.com GH_TOKEN=fixture-token \
    TEST_SOURCE_RUN_ID="$TEST_SOURCE_RUN_ID" TEST_SOURCE_SHA="$TEST_SOURCE_SHA" TEST_RUN_JSON="$TEST_RUN_JSON" \
    TEST_CANARY_WORKFLOW_JSON="$TEST_CANARY_WORKFLOW_JSON" PATH="$TMP_DIR/bin:$PATH" \
    bash "$ROOT_DIR/scripts/ci/release-observer.sh" --source-run-id "$TEST_SOURCE_RUN_ID" \
      --output "$output" > "$TMP_DIR/stdout" 2> "$TMP_DIR/stderr"
}

run_observer() {
  local output="$1"
  GITHUB_REPOSITORY="$REPOSITORY" GITHUB_RUN_ID="$OBSERVER_RUN_ID" \
    GITHUB_RUN_ATTEMPT=1 GITHUB_SERVER_URL=https://github.com GH_TOKEN=fixture-token \
    TEST_SOURCE_RUN_ID="$TEST_SOURCE_RUN_ID" TEST_SOURCE_SHA="$TEST_SOURCE_SHA" \
    TEST_SOURCE_TAG="$TEST_SOURCE_TAG" TEST_RUN_JSON="$TEST_RUN_JSON" \
    TEST_WORKFLOW_JSON="$TEST_WORKFLOW_JSON" TEST_MANIFEST_JSON="$TEST_MANIFEST_JSON" \
    TEST_TAG_SHA="${TEST_TAG_SHA-$SOURCE_SHA}" TEST_MANIFEST_MISSING="${TEST_MANIFEST_MISSING:-false}" \
    EVENT_PATH="$TMP_DIR/fixture/event.json" OUTPUT_PATH="$output" \
    PATH="$TMP_DIR/bin:$PATH" bash "$ROOT_DIR/scripts/ci/release-observer.sh" \
      --event "$TMP_DIR/fixture/event.json" --output "$output" > "$TMP_DIR/stdout" 2> "$TMP_DIR/stderr"
}

expect_rejected() {
  local label="$1"
  local output="$TMP_DIR/${label}.json"
  if run_observer "$output"; then
    fail "$label was accepted"
  elif [[ -e "$output" ]]; then
    fail "$label left a receipt behind"
  else
    pass "$label rejected without a receipt"
  fi
}

echo "Test A: both supported main-branch cancellation events retain linked receipts"
for event in push workflow_dispatch; do
  write_fixtures "$event"
  output="$TMP_DIR/${event}.json"
  if run_observer "$output" && jq -e --arg event "$event" --arg sha "$SOURCE_SHA" \
    --arg source_url "https://github.com/${REPOSITORY}/actions/runs/${SOURCE_RUN_ID}" \
    --arg observer_url "https://github.com/${REPOSITORY}/actions/runs/${OBSERVER_RUN_ID}" \
    '.source_event == $event and .terminal_verdict == "cancelled" and .source_sha == $sha and
     .release_run_url == $source_url and .observer_run.url == $observer_url and
     .release_run_id == "74123" and .version == "1.6.0" and .tag == "v1.6.0" and
     .stages.source_tag.resolves_to_source == true' "$output" >/dev/null; then
    pass "$event cancellation is source-linked and preserves source_event"
  else cat "$TMP_DIR/stderr" >&2; fail "$event cancellation receipt missing or malformed"; fi
done

echo "Test A2: explicit workflow_dispatch observes only an exact cancelled canary source"
write_canary_fixtures
output="$TMP_DIR/manual-canary.json"
if run_dispatched_observer "$output" && jq -e --arg sha "$SOURCE_SHA" \
  '.receipt_kind == "canary" and .scenario == "cancellation" and .probe_id == "0123456789abcdef0123456789abcdef" and
   .source_run_id == "74124" and .source_run_attempt == 1 and .source_workflow_id == 2025 and
   .source_sha == $sha and .observer_run.id == "98123"' "$output" >/dev/null; then
  pass "workflow_dispatch re-queries and records an exact cancelled canary"
else cat "$TMP_DIR/stderr" >&2; fail "manual canary cancellation receipt missing or malformed"; fi
jq '.conclusion="failure"' "$TEST_RUN_JSON" > "$TMP_DIR/fixture/canary-failed.json"
TEST_RUN_JSON="$TMP_DIR/fixture/canary-failed.json" export TEST_RUN_JSON
if run_dispatched_observer "$TMP_DIR/manual-canary-failure.json"; then
  fail "manual dispatch accepted a non-cancelled canary source"
elif [[ -e "$TMP_DIR/manual-canary-failure.json" ]]; then
  fail "rejected manual dispatch left a receipt behind"
else pass "manual dispatch rejects a non-cancelled canary without a receipt"; fi

echo "Test B: source run must be an authoritative cancelled Release Please run on main"
write_fixtures pull_request
expect_rejected unsupported-source-event
write_fixtures push feature/candidate
expect_rejected non-main-source-branch
write_fixtures push main success
expect_rejected non-cancelled-source-run
write_fixtures push
jq '.name="Unexpected workflow"' "$TMP_DIR/fixture/run.json" > "$TMP_DIR/run-mutated.json" && mv "$TMP_DIR/run-mutated.json" "$TMP_DIR/fixture/run.json"
expect_rejected wrong-source-workflow-name
write_fixtures push
jq '.path=".github/workflows/other.yml@main"' "$TMP_DIR/fixture/run.json" > "$TMP_DIR/run-mutated.json" && mv "$TMP_DIR/run-mutated.json" "$TMP_DIR/fixture/run.json"
expect_rejected wrong-source-workflow-path
write_fixtures push
jq '.id=999' "$TMP_DIR/fixture/workflow.json" > "$TMP_DIR/workflow-mutated.json" && mv "$TMP_DIR/workflow-mutated.json" "$TMP_DIR/fixture/workflow.json"
expect_rejected wrong-source-workflow-id
write_fixtures push
jq '.repository.full_name="other/repo"' "$TMP_DIR/fixture/run.json" > "$TMP_DIR/run-mutated.json" && mv "$TMP_DIR/run-mutated.json" "$TMP_DIR/fixture/run.json"
expect_rejected wrong-authoritative-repository
write_fixtures push
jq '.repository.full_name="other/repo"' "$TMP_DIR/fixture/event.json" > "$TMP_DIR/event-mutated.json" && mv "$TMP_DIR/event-mutated.json" "$TMP_DIR/fixture/event.json"
expect_rejected wrong-event-repository
write_fixtures push
jq '.id=74124' "$TMP_DIR/fixture/run.json" > "$TMP_DIR/run-mutated.json" && mv "$TMP_DIR/run-mutated.json" "$TMP_DIR/fixture/run.json"
expect_rejected source-run-id-mismatch
write_fixtures push
jq '.head_sha="2222222222222222222222222222222222222222"' "$TMP_DIR/fixture/run.json" > "$TMP_DIR/run-mutated.json" && mv "$TMP_DIR/run-mutated.json" "$TMP_DIR/fixture/run.json"
expect_rejected source-sha-mismatch
write_fixtures push
jq '.event="workflow_dispatch"' "$TMP_DIR/fixture/run.json" > "$TMP_DIR/run-mutated.json" && mv "$TMP_DIR/run-mutated.json" "$TMP_DIR/fixture/run.json"
expect_rejected source-event-mismatch

echo "Test C: malformed webhook identity and invalid manifest cannot create receipts"
write_fixtures push
jq 'del(.workflow_run.id)' "$TMP_DIR/fixture/event.json" > "$TMP_DIR/event-bad.json"
cp "$TMP_DIR/event-bad.json" "$TMP_DIR/fixture/event.json"
expect_rejected missing-event-run-id
write_fixtures push
jq 'del(.workflow_run.workflow_id)' "$TMP_DIR/fixture/event.json" > "$TMP_DIR/event-bad.json"
cp "$TMP_DIR/event-bad.json" "$TMP_DIR/fixture/event.json"
expect_rejected missing-event-workflow-id
write_fixtures push
jq '.workflow_run.workflow_id="bad-id"' "$TMP_DIR/fixture/event.json" > "$TMP_DIR/event-bad.json"
cp "$TMP_DIR/event-bad.json" "$TMP_DIR/fixture/event.json"
expect_rejected malformed-event-workflow-id
write_fixtures push
jq '.workflow_run.head_sha="bad-sha"' "$TMP_DIR/fixture/event.json" > "$TMP_DIR/event-bad.json"
cp "$TMP_DIR/event-bad.json" "$TMP_DIR/fixture/event.json"
expect_rejected malformed-event-sha
write_fixtures push
printf '{not-json\n' > "$TMP_DIR/fixture/manifest.json"
expect_rejected malformed-source-manifest

echo "Test D: missing or mismatched tags remain diagnostic cancellation evidence"
write_fixtures push
TEST_TAG_SHA=""; export TEST_TAG_SHA
output="$TMP_DIR/tag-missing.json"
if run_observer "$output" && jq -e '.terminal_verdict == "cancelled" and .stages.source_tag.diagnostic == "tag_not_found"' "$output" >/dev/null; then
  pass "missing tag is a cancellation diagnostic, never success"
else cat "$TMP_DIR/stderr" >&2; fail "missing tag was omitted or changed cancellation into success"; fi
write_fixtures push
TEST_TAG_SHA="2222222222222222222222222222222222222222"; export TEST_TAG_SHA
output="$TMP_DIR/tag-mismatch.json"
if run_observer "$output" && jq -e '.terminal_verdict == "cancelled" and .stages.source_tag.diagnostic == "tag_sha_mismatch"' "$output" >/dev/null; then
  pass "mismatched tag is a cancellation diagnostic, never success"
else cat "$TMP_DIR/stderr" >&2; fail "mismatched tag was omitted or changed cancellation into success"; fi
write_fixtures push
TEST_TAG_SHA="bad-sha"; export TEST_TAG_SHA
output="$TMP_DIR/tag-invalid.json"
if run_observer "$output" && jq -e '.terminal_verdict == "cancelled" and .stages.source_tag.diagnostic == "tag_invalid_response"' "$output" >/dev/null; then
  pass "malformed tag lookup is a cancellation diagnostic, never success"
else cat "$TMP_DIR/stderr" >&2; fail "malformed tag lookup was omitted or changed cancellation into success"; fi

echo "Test E: repeated observer delivery is idempotent by source run identity"
write_fixtures workflow_dispatch
output="$TMP_DIR/repeated.json"
if run_observer "$output" && cp "$output" "$TMP_DIR/repeated-before.json" && run_observer "$output" && \
  jq -e --slurpfile before "$TMP_DIR/repeated-before.json" '.release_run_id == $before[0].release_run_id and .source_sha == $before[0].source_sha and .source_event == $before[0].source_event and .terminal_verdict == $before[0].terminal_verdict and .observer_run.id == $before[0].observer_run.id' "$output" >/dev/null; then
  pass "duplicate delivery keeps the same terminal identity and source event"
else fail "duplicate delivery changed cancellation identity"; fi

echo "Results: ${PASS} passed, ${FAIL} failed"
if [[ "$FAIL" -gt 0 ]]; then exit 1; fi
