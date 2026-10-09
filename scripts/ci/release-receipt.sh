#!/usr/bin/env bash
# Validate and atomically persist one terminal Release Please/Hex receipt.
set -euo pipefail

INPUT=""
OUTPUT=""
usage() {
  echo "Usage: release-receipt.sh --input <receipt-input.json> --output <receipt.json>" >&2
}
fail() { echo "release-receipt: FAIL: $*" >&2; exit 1; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --input) [[ $# -ge 2 ]] || { usage; exit 2; }; INPUT="$2"; shift 2;;
    --output) [[ $# -ge 2 ]] || { usage; exit 2; }; OUTPUT="$2"; shift 2;;
    -h|--help) usage; exit 0;;
    *) echo "release-receipt: FAIL: unknown argument: $1" >&2; usage; exit 2;;
  esac
done

[[ -n "$INPUT" && -f "$INPUT" ]] || fail "input JSON file is required"
[[ -n "$OUTPUT" ]] || fail "output path is required"
command -v jq >/dev/null 2>&1 || fail "jq is required"
jq -e 'type == "object"' "$INPUT" >/dev/null 2>&1 || fail "input must be a JSON object"

# Diagnostic text is deliberately an enum-like code rather than arbitrary logs.
# This prevents runner output or accidentally interpolated credentials from being
# persisted in the durable evidence artifact.
if ! jq -e '
  def timestamp: type == "string" and test("^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$");
  def run_url: type == "string" and test("^https://github\\.com/[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+/actions/runs/[0-9]+$");
  def workflow_url: type == "string" and test("^https://github\\.com/[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+/actions/workflows/[A-Za-z0-9_.-]+$");
  def safe_id: type == "string" and test("^[1-9][0-9]*$");
  def safe_diag: type == "string" and test("^[a-z][a-z0-9_]{1,63}$");
  def no_credential_keys:
    [.. | objects | keys[]? | select(test("(token|secret|credential|api.?key)"; "i"))] | length == 0;
  def release_run_valid:
    (.release_run | type == "object") and
    (.release_run.id | safe_id) and
    (.release_run.attempt | type == "number" and floor == . and . >= 1) and
    (.release_run.url | run_url) and
    (.release_run.workflow_name | type == "string" and length > 0 and length <= 128) and
    (.release_run.workflow_url | workflow_url) and
    (.release_run.started_at | timestamp) and
    ((.release_run.completed_at == null) or (.release_run.completed_at | timestamp));
  def source_valid:
    (.source_event == "push" or .source_event == "workflow_dispatch") and
    (.source | type == "object") and
    (.source.version | type == "string" and test("^[0-9]+\\.[0-9]+\\.[0-9]+([-.][0-9A-Za-z.-]+)?$")) and
    (.source.tag == ("v" + .source.version)) and
    (.source.sha | type == "string" and test("^[0-9a-f]{40}$"));
  def gate_valid:
    if .gate == null then .terminal_verdict == "cancelled"
    else (.gate | type == "object") and
      (((.gate.run_id | safe_id) and (.gate.url | run_url)) or
       (.terminal_verdict == "failure" and .failure.stage == "gate-ci-green" and
        .gate.verdict == "fail" and .gate.run_id == null and .gate.url == null)) and
      (.gate.verdict == "pass" or .gate.verdict == "fail" or .gate.verdict == "skipped") and
      (.gate as $gate | ($gate.attempts | type == "number" and floor == . and . >= (if $gate.verdict == "fail" then 0 else 1 end) and . <= 120)) and
      (.gate.started_at | timestamp) and (.gate.completed_at | timestamp)
    end;
  def publish_valid:
    (.publish | type == "object") and
    (.publish.outcome == "published" or .publish.outcome == "already_published" or
     .publish.outcome == "dry_run" or .publish.outcome == "failed" or .publish.outcome == "not_run") and
    ((.publish.started_at == null) or (.publish.started_at | timestamp)) and
    ((.publish.completed_at == null) or (.publish.completed_at | timestamp)) and
    ((.publish.outcome == "not_run") or ((.publish.started_at | timestamp) and (.publish.completed_at | timestamp)));
  def failure_valid:
    if .terminal_verdict == "failure" then
      (.failure | type == "object") and
      (.failure.stage == "release-please" or .failure.stage == "gate-ci-green" or .failure.stage == "manual-validation" or .failure.stage == "publish-hex" or .failure.stage == "post-publish-verify") and
      (.failure.diagnostic | safe_diag)
    else .failure == null end;
  def observer_valid:
    if .terminal_verdict == "cancelled" then
      (.observer_run | type == "object") and (.observer_run.id | safe_id) and (.observer_run.url | run_url)
    else .observer_run == null end;
  def consistency:
    if .terminal_verdict == "success" then
      (.gate.verdict == "pass") and
      (.publish.outcome == "published" or .publish.outcome == "already_published" or .publish.outcome == "dry_run") and
      (.release_run.completed_at | timestamp)
    elif .terminal_verdict == "failure" then
      (.release_run.completed_at | timestamp) and
      (if .failure.stage == "release-please" then .gate.verdict == "skipped" and .publish.outcome == "not_run"
       elif .failure.stage == "gate-ci-green" or .failure.stage == "manual-validation" then .gate.verdict == "fail" and .publish.outcome == "not_run"
       elif .failure.stage == "publish-hex" then .gate.verdict == "pass" and .publish.outcome == "failed"
       elif .failure.stage == "post-publish-verify" then .gate.verdict == "pass" and (.publish.outcome == "published" or .publish.outcome == "already_published")
       else true end)
    else .release_run.completed_at == null and .observer_run.id != .release_run.id end;
  type == "object" and .schema_version == 1 and
  no_credential_keys and release_run_valid and source_valid and gate_valid and publish_valid and
  (.terminal_verdict == "success" or .terminal_verdict == "failure" or .terminal_verdict == "cancelled") and
  failure_valid and observer_valid and consistency and
  ((.stages == null) or (.stages | type == "object"))
' "$INPUT" >/dev/null 2>&1; then
  fail "input does not satisfy the release receipt contract"
fi

RUN_ID="$(jq -r '.release_run.id' "$INPUT")"
if [[ -e "$OUTPUT" ]]; then
  OLD_ID="$(jq -r '.release_run_id // empty' "$OUTPUT" 2>/dev/null || true)"
  OLD_SHA="$(jq -r '.source_sha // empty' "$OUTPUT" 2>/dev/null || true)"
  INPUT_SHA="$(jq -r '.source.sha' "$INPUT")"
  OLD_TAG="$(jq -r '.tag // empty' "$OUTPUT" 2>/dev/null || true)"
  INPUT_TAG="$(jq -r '.source.tag' "$INPUT")"
  OLD_VERSION="$(jq -r '.version // empty' "$OUTPUT" 2>/dev/null || true)"
  INPUT_VERSION="$(jq -r '.source.version' "$INPUT")"
  OLD_EVENT="$(jq -r '.source_event // empty' "$OUTPUT" 2>/dev/null || true)"
  INPUT_EVENT="$(jq -r '.source_event' "$INPUT")"
  OLD_WORKFLOW="$(jq -r '.workflow_name // empty' "$OUTPUT" 2>/dev/null || true)"
  INPUT_WORKFLOW="$(jq -r '.release_run.workflow_name' "$INPUT")"
  [[ "$OLD_ID" == "$RUN_ID" && "$OLD_SHA" == "$INPUT_SHA" && "$OLD_TAG" == "$INPUT_TAG" && "$OLD_VERSION" == "$INPUT_VERSION" && "$OLD_EVENT" == "$INPUT_EVENT" && "$OLD_WORKFLOW" == "$INPUT_WORKFLOW" ]] || fail "existing receipt belongs to a different release identity"
fi

RECORDED_AT="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
OUTPUT_DIR="$(dirname "$OUTPUT")"
mkdir -p "$OUTPUT_DIR"
TEMP_OUTPUT="$(mktemp "${OUTPUT}.tmp.XXXXXX")"
PREVIOUS_FILE=""
trap 'rm -f "$TEMP_OUTPUT" "$PREVIOUS_FILE"' EXIT
PREVIOUS_FILE="$(mktemp "${OUTPUT}.previous.XXXXXX")"
if [[ -f "$OUTPUT" ]]; then cp "$OUTPUT" "$PREVIOUS_FILE"; else printf '{}\n' > "$PREVIOUS_FILE"; fi

jq -n --arg recorded_at "$RECORDED_AT" --slurpfile input "$INPUT" \
  --slurpfile previous "$PREVIOUS_FILE" '
  ($input[0]) as $r |
  ($previous[0] // {}) as $old |
  {
    schema_version: $r.schema_version,
    release_run_id: $r.release_run.id,
    release_run_attempt: $r.release_run.attempt,
    release_run_url: $r.release_run.url,
    workflow_name: $r.release_run.workflow_name,
    workflow_url: $r.release_run.workflow_url,
    source_event: $r.source_event,
    version: $r.source.version,
    tag: $r.source.tag,
    source_sha: $r.source.sha,
    release_started_at: $r.release_run.started_at,
    release_completed_at: $r.release_run.completed_at,
    gate: $r.gate,
    publish: $r.publish,
    terminal_verdict: $r.terminal_verdict,
    failure: $r.failure,
    observer_run: $r.observer_run,
    stages: (($old.stages // {}) * ($r.stages // {})),
    recorded_at: $recorded_at
  }
' > "$TEMP_OUTPUT" || fail "could not encode receipt JSON"
jq -e . "$TEMP_OUTPUT" >/dev/null || { sed -n '1,80p' "$TEMP_OUTPUT" >&2; fail "encoded receipt is not valid JSON"; }
mv -f "$TEMP_OUTPUT" "$OUTPUT"
rm -f "$PREVIOUS_FILE"
trap - EXIT
TERMINAL_VERDICT="$(jq -r '.terminal_verdict' "$OUTPUT")"
echo "release-receipt: recorded ${RUN_ID} (${TERMINAL_VERDICT})"
