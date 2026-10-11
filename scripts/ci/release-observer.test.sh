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
  "repos/${GITHUB_REPOSITORY}/actions/runs/${TEST_CANARY_SOURCE_RUN_ID:-unset}")
    cat "$TEST_CANARY_RUN_JSON"
    ;;
  "repos/${GITHUB_REPOSITORY}/actions/runs/${GITHUB_RUN_ID}")
    cat "$TEST_OBSERVER_RUN_JSON"
    ;;
  "repos/${GITHUB_REPOSITORY}/actions/workflows/release-please.yml")
    cat "$TEST_WORKFLOW_JSON"
    ;;
  "repos/${GITHUB_REPOSITORY}/actions/workflows/release-receipt-canary.yml")
    cat "$TEST_CANARY_WORKFLOW_JSON"
    ;;
  "repos/${GITHUB_REPOSITORY}/actions/workflows/release-run-observer.yml")
    cat "$TEST_OBSERVER_WORKFLOW_JSON"
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

run_observer() {
  local output="$1"
  GITHUB_REPOSITORY="$REPOSITORY" GITHUB_RUN_ID="$OBSERVER_RUN_ID" \
    GITHUB_RUN_ATTEMPT=1 GITHUB_SERVER_URL=https://github.com GH_TOKEN=fixture-token \
    TEST_SOURCE_RUN_ID="$TEST_SOURCE_RUN_ID" TEST_SOURCE_SHA="$TEST_SOURCE_SHA" \
    TEST_SOURCE_TAG="$TEST_SOURCE_TAG" TEST_RUN_JSON="$TEST_RUN_JSON" \
    TEST_WORKFLOW_JSON="$TEST_WORKFLOW_JSON" TEST_MANIFEST_JSON="$TEST_MANIFEST_JSON" \
    TEST_TAG_SHA="${TEST_TAG_SHA-$SOURCE_SHA}" TEST_MANIFEST_MISSING="${TEST_MANIFEST_MISSING:-false}" \
    TEST_CANARY_SOURCE_RUN_ID="${TEST_CANARY_SOURCE_RUN_ID:-unset}" \
    TEST_CANARY_RUN_JSON="${TEST_CANARY_RUN_JSON:-}" \
    TEST_CANARY_WORKFLOW_JSON="${TEST_CANARY_WORKFLOW_JSON:-}" \
    TEST_OBSERVER_RUN_JSON="${TEST_OBSERVER_RUN_JSON:-}" \
    TEST_OBSERVER_WORKFLOW_JSON="${TEST_OBSERVER_WORKFLOW_JSON:-}" \
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

echo "Test B: source run must be an authoritative cancelled Release Please run on main"
write_fixtures pull_request
expect_rejected unsupported-source-event
write_fixtures push feature/candidate
expect_rejected non-main-source-branch
write_fixtures push main success
expect_rejected non-cancelled-source-run
write_fixtures push
jq '.name="Unexpected workflow"' "$TMP_DIR/fixture/workflow.json" > "$TMP_DIR/workflow-mutated.json" && mv "$TMP_DIR/workflow-mutated.json" "$TMP_DIR/fixture/workflow.json"
expect_rejected wrong-authoritative-workflow-name
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

echo "Test F: canary run titles are dynamic; workflow identity comes from workflow metadata"
mkdir -p "$TMP_DIR/canary-fixture"
CANARY_SOURCE_RUN_ID=74124
CANARY_PROBE_ID=90ce59a45440406631d927e636e94eb6
CANARY_OBSERVER_RUN_ID="$OBSERVER_RUN_ID"
jq -n --arg repository "$REPOSITORY" --arg sha "$SOURCE_SHA" \
  --argjson id "$CANARY_SOURCE_RUN_ID" --argjson workflow_id 380517407 \
  '{repository:{full_name:$repository},workflow_run:{id:$id,event:"workflow_dispatch",head_sha:$sha,workflow_id:$workflow_id}}' \
  > "$TMP_DIR/canary-fixture/event.json"
jq -n --arg repository "$REPOSITORY" --arg sha "$SOURCE_SHA" \
  --arg probe "$CANARY_PROBE_ID" --arg url "https://github.com/${REPOSITORY}/actions/runs/${CANARY_SOURCE_RUN_ID}" \
  --argjson id "$CANARY_SOURCE_RUN_ID" --argjson workflow_id 380517407 \
  '{id:$id,name:("release-receipt-canary-cancellation-"+$probe),display_title:("release-receipt-canary-cancellation-"+$probe),workflow_id:$workflow_id,path:".github/workflows/release-receipt-canary.yml@main",event:"workflow_dispatch",head_branch:"main",head_sha:$sha,conclusion:"cancelled",run_attempt:1,run_started_at:"2026-10-11T11:18:34Z",html_url:$url,repository:{full_name:$repository}}' \
  > "$TMP_DIR/canary-fixture/run.json"
jq -n '{id:380517407,name:"Release Receipt Canary",path:".github/workflows/release-receipt-canary.yml",state:"active"}' \
  > "$TMP_DIR/canary-fixture/workflow.json"
jq -n --argjson id "$CANARY_OBSERVER_RUN_ID" \
  '{id:$id,run_attempt:1,run_started_at:"2026-10-11T11:20:41Z"}' \
  > "$TMP_DIR/canary-fixture/observer-run.json"
jq -n '{id:379162190,name:"Release Run Observer",path:".github/workflows/release-run-observer.yml",state:"active"}' \
  > "$TMP_DIR/canary-fixture/observer-workflow.json"
jq -n --arg sha "$SOURCE_SHA" --arg probe "$CANARY_PROBE_ID" \
  --argjson source_id "$CANARY_SOURCE_RUN_ID" --argjson observer_id "$CANARY_OBSERVER_RUN_ID" \
  '{sha:$sha,probe:$probe,source_id:$source_id,observer_id:$observer_id}' \
  > "$TMP_DIR/canary-fixture/identity.json"
export TEST_CANARY_SOURCE_RUN_ID="$CANARY_SOURCE_RUN_ID" \
  TEST_CANARY_RUN_JSON="$TMP_DIR/canary-fixture/run.json" \
  TEST_CANARY_WORKFLOW_JSON="$TMP_DIR/canary-fixture/workflow.json" \
  TEST_OBSERVER_RUN_JSON="$TMP_DIR/canary-fixture/observer-run.json" \
  TEST_OBSERVER_WORKFLOW_JSON="$TMP_DIR/canary-fixture/observer-workflow.json"
GITHUB_REPOSITORY="$REPOSITORY" GITHUB_RUN_ID="$CANARY_OBSERVER_RUN_ID" \
  GITHUB_RUN_ATTEMPT=1 GITHUB_SERVER_URL=https://github.com GH_TOKEN=fixture-token \
  PATH="$TMP_DIR/bin:$PATH" bash "$ROOT_DIR/scripts/ci/release-observer.sh" \
    --event "$TMP_DIR/canary-fixture/event.json" --output "$TMP_DIR/canary-receipt.json" \
    > "$TMP_DIR/canary-stdout" 2> "$TMP_DIR/canary-stderr"
if jq -e --slurpfile id "$TMP_DIR/canary-fixture/identity.json" \
  '.receipt_kind == "canary" and .scenario == "cancellation" and
   .source_run_id == ($id[0].source_id|tostring) and .source_sha == $id[0].sha and
   .probe_id == $id[0].probe and .source_workflow_name == "Release Receipt Canary" and
   .source_workflow_id == 380517407 and .terminal_verdict == "cancelled" and
   .observer_run.id == ($id[0].observer_id|tostring)' "$TMP_DIR/canary-receipt.json" >/dev/null; then
  pass "dynamic canary run title is accepted while static workflow metadata stays exact"
else cat "$TMP_DIR/canary-stderr" >&2; fail "canary cancellation receipt rejected a dynamic run title"; fi

echo "Results: ${PASS} passed, ${FAIL} failed"
if [[ "$FAIL" -gt 0 ]]; then exit 1; fi
