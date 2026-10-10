#!/usr/bin/env bash
# Bounded, source-bound Actions canary. Artifacts are parsed as JSON data only.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RECEIPT_HELPER="${SCRIPT_DIR}/release-receipt.sh"
REPOSITORY="${GITHUB_REPOSITORY:-szTheory/sigra}"
DISPATCH_ATTEMPTED=false
PROBE_ID="${PROBE_ID:-}"
OUTPUT=""
PROOF=""
MODE=""
WORKFLOW_ID=""
SCENARIO="${SCENARIO:-}"
FAILURE_RECEIPT=""
CANCELLATION_RECEIPT=""

fail() {
  echo "release-canary: FAIL: $*" >&2
  if [[ "${MODE:-}" == run && -n "${PROOF:-}" ]]; then
    local blocked_at proof_dir preflight_path reason_code
    blocked_at="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    reason_code="$(printf '%s' "$*" | tr '[:upper:] -' '[:lower:]__' | tr -cd 'a-z_')"
    proof_dir="$(dirname "$PROOF")"; mkdir -p "$proof_dir"
    preflight_path="${proof_dir}/250-CANARY-PREFLIGHT.json"
    jq -n --arg at "$blocked_at" --arg reason "$reason_code" --argjson dispatched "$DISPATCH_ATTEMPTED" \
      --slurpfile preflight "$preflight_path" \
      '{schema_version:1,status:"blocked",captured_at:$at,
        preflight:($preflight[0] // {schema_version:1,status:"blocked",reason:"preflight_unavailable"}),
        reason:$reason,dispatch_attempted:$dispatched,receipts:[],credential_values_recorded:false}' \
      | safe_write_json "$PROOF" || true
  fi
  exit 1
}
usage() {
  cat >&2 <<'USAGE'
Usage:
  release-canary.sh --self-test
  release-canary.sh --validate-proof <proof.json>
  release-canary.sh --write-failure-receipt --output <receipt.json>
  release-canary.sh --resolve-run --workflow-id <id> --scenario <failure|cancellation> --probe-id <id>
  release-canary.sh --cancel-canary-run <run-id> --workflow-id <id>
  release-canary.sh --validate-pair --failure-receipt <json> --cancellation-receipt <json>
  release-canary.sh --preflight --output <preflight.json>
  release-canary.sh --validate-preflight --output <validated-preflight.json>
  release-canary.sh --run --proof <proof.json>
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --self-test) MODE=self-test; shift ;;
    --validate-proof) MODE=validate-proof; [[ $# -ge 2 ]] || { usage; exit 2; }; PROOF="$2"; shift 2 ;;
    --write-failure-receipt) MODE=write-failure; shift ;;
    --resolve-run) MODE=resolve-run; shift ;;
    --cancel-canary-run) MODE=cancel-canary; [[ $# -ge 2 ]] || { usage; exit 2; }; PROOF="$2"; shift 2 ;;
    --validate-pair) MODE=validate-pair; shift ;;
    --preflight) MODE=preflight; shift ;;
    --validate-preflight) MODE=validate-preflight; shift ;;
    --run) MODE=run; shift ;;
    --output) [[ $# -ge 2 ]] || { usage; exit 2; }; OUTPUT="$2"; shift 2 ;;
    --proof) [[ $# -ge 2 ]] || { usage; exit 2; }; PROOF="$2"; shift 2 ;;
    --workflow-id) [[ $# -ge 2 ]] || { usage; exit 2; }; WORKFLOW_ID="$2"; shift 2 ;;
    --scenario) [[ $# -ge 2 ]] || { usage; exit 2; }; SCENARIO="$2"; shift 2 ;;
    --probe-id) [[ $# -ge 2 ]] || { usage; exit 2; }; PROBE_ID="$2"; shift 2 ;;
    --failure-receipt) [[ $# -ge 2 ]] || { usage; exit 2; }; FAILURE_RECEIPT="$2"; shift 2 ;;
    --cancellation-receipt) [[ $# -ge 2 ]] || { usage; exit 2; }; CANCELLATION_RECEIPT="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) fail "unknown argument" ;;
  esac
done

safe_write_json() {
  local path="$1"
  mkdir -p "$(dirname "$path")"
  local tmp
  tmp="$(mktemp "${path}.tmp.XXXXXX")"
  cat > "$tmp"
  jq -e . "$tmp" >/dev/null || { rm -f "$tmp"; fail "refusing to write invalid JSON"; }
  mv -f "$tmp" "$path"
}

valid_probe_id() { [[ "$1" =~ ^[a-f0-9-]{16,64}$ ]]; }

validate_receipt_pair() {
  local failure="$1" cancellation="$2"
  jq -e 'def timestamp: type == "string" and test("^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$");
    type == "object" and .receipt_kind == "canary" and .scenario == "failure" and
    .terminal_verdict == "failure" and .source_ref == "refs/heads/main" and
    (.source_repository == "szTheory/sigra") and (.source_run_id | type == "string") and (.source_run_attempt | type == "number" and . >= 1) and
    (.source_sha | test("^[0-9a-f]{40}$")) and (.probe_id | test("^[a-f0-9-]{16,64}$")) and
    .source_event == "workflow_dispatch" and .source_workflow_name == "Release Receipt Canary" and
    .source_workflow_path == ".github/workflows/release-receipt-canary.yml" and
    (.source_started_at | timestamp) and (.source_observed_at | timestamp) and
    ([.. | objects | keys[]? | select(test("(token|secret|credential|api.?key)";"i"))] | length == 0)' "$failure" >/dev/null 2>&1 || return 1
  jq -e 'def timestamp: type == "string" and test("^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$");
    type == "object" and .receipt_kind == "canary" and .scenario == "cancellation" and
    .terminal_verdict == "cancelled" and .source_ref == "refs/heads/main" and
    (.source_repository == "szTheory/sigra") and (.source_run_id | type == "string") and (.source_run_attempt | type == "number" and . >= 1) and
    (.source_sha | test("^[0-9a-f]{40}$")) and (.probe_id | test("^[a-f0-9-]{16,64}$")) and
    .source_event == "workflow_dispatch" and .source_workflow_name == "Release Receipt Canary" and
    .source_workflow_path == ".github/workflows/release-receipt-canary.yml" and
    (.source_started_at | timestamp) and (.source_observed_at | timestamp) and
    (.observer_run.id | type == "string") and (.observer_run.attempt | type == "number" and . >= 1) and
    (.observer_run.workflow_id | type == "number" and . > 0) and
    (.observer_run.started_at | timestamp) and (.observer_run.observed_at | timestamp) and
    ([.. | objects | keys[]? | select(test("(token|secret|credential|api.?key)";"i"))] | length == 0)' "$cancellation" >/dev/null 2>&1 || return 1
  [[ "$(jq -r .probe_id "$failure")" != "$(jq -r .probe_id "$cancellation")" ]] || return 1
  [[ "$(jq -r .source_run_id "$failure")" != "$(jq -r .source_run_id "$cancellation")" ]] || return 1
  [[ "$(jq -r .source_sha "$failure")" == "$(jq -r .source_sha "$cancellation")" ]] || return 1
}

write_failure_receipt() {
  [[ -n "${GITHUB_REPOSITORY:-}" && "$GITHUB_REPOSITORY" == "$REPOSITORY" ]] || fail "repository identity missing or mismatched"
  [[ "${GITHUB_EVENT_NAME:-}" == workflow_dispatch && "${GITHUB_REF:-}" == refs/heads/main ]] || fail "source must be workflow_dispatch on main"
  valid_probe_id "$PROBE_ID" || fail "probe ID is malformed"
  [[ "${SCENARIO:-}" == failure ]] || fail "source failure receipt requires the failure scenario"
  [[ -n "${GH_TOKEN:-}" ]] || fail "Actions read token is unavailable"
  [[ -n "$OUTPUT" ]] || fail "output path is required"
  local run workflow jobs id attempt sha branch event name path start observed title step_failure workflow_id
  run="$(gh api "repos/${REPOSITORY}/actions/runs/${GITHUB_RUN_ID}")" || fail "authoritative source run query failed"
  workflow="$(gh api "repos/${REPOSITORY}/actions/workflows/release-receipt-canary.yml")" || fail "authoritative canary workflow query failed"
  workflow_id="$(jq -er '.id | select(type == "number" and floor == . and . > 0)' <<<"$workflow")" || fail "canary workflow ID malformed"
  jobs="$(gh api "repos/${REPOSITORY}/actions/runs/${GITHUB_RUN_ID}/jobs")" || fail "source job identity query failed"
  id="$(jq -er '.id | numbers' <<<"$run")" || fail "source run ID unavailable"
  attempt="$(jq -er '.run_attempt | select(type == "number" and . >= 1 and floor == .)' <<<"$run")" || fail "source attempt unavailable"
  sha="$(jq -er '.head_sha | select(type == "string" and test("^[0-9a-f]{40}$"))' <<<"$run")" || fail "source SHA malformed"
  branch="$(jq -er '.head_branch' <<<"$run")" || fail "source branch unavailable"
  event="$(jq -er '.event' <<<"$run")" || fail "source event unavailable"
  name="$(jq -er '.name' <<<"$run")" || fail "source workflow name unavailable"
  path="$(jq -er '.path' <<<"$run")" || fail "source workflow path unavailable"
  title="$(jq -er '.display_title' <<<"$run")" || fail "source title unavailable"
  [[ "$id" == "$GITHUB_RUN_ID" && "$branch" == main && "$event" == workflow_dispatch ]] || fail "source run identity mismatch"
  [[ "$name" == "Release Receipt Canary" && "$path" =~ ^\.github/workflows/release-receipt-canary\.yml(@main)?$ ]] || fail "source workflow identity mismatch"
  [[ "$(jq -er '.id | numbers' <<<"$workflow")" == "$(jq -er '.workflow_id | numbers' <<<"$run")" ]] || fail "source workflow ID mismatch"
  [[ "$title" == "release-receipt-canary-failure-${PROBE_ID}" ]] || fail "source probe title mismatch"
  start="$(jq -er '.run_started_at' <<<"$run" | sed -E 's/\.[0-9]+Z$/Z/')"
  observed="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  step_failure="$(jq -r '[.jobs[]?.steps[]? | select(.name == "Controlled failure before release operations") | .conclusion == "failure"] | any' <<<"$jobs")"
  [[ "$step_failure" == true ]] || fail "controlled failure step is not authoritatively failed"
  jq -n --arg probe "$PROBE_ID" --arg id "$GITHUB_RUN_ID" --arg sha "$sha" --arg repository "$REPOSITORY" \
    --arg start "$start" --arg observed "$observed" \
    --arg run_url "https://github.com/${REPOSITORY}/actions/runs/${GITHUB_RUN_ID}" \
    --argjson attempt "$attempt" --argjson workflow_id "$workflow_id" \
    '{schema_version:1,receipt_kind:"canary",canary:{probe_id:$probe,scenario:"failure"},
      source_event:"workflow_dispatch",source:{repository:$repository,ref:"refs/heads/main",sha:$sha},
      source_run:{id:$id,attempt:$attempt,workflow_id:$workflow_id,
        workflow_name:"Release Receipt Canary",workflow_path:".github/workflows/release-receipt-canary.yml",
        url:$run_url,started_at:$start,observed_at:$observed},terminal_verdict:"failure",observer_run:null}' \
    > "${OUTPUT}.input"
  bash "$RECEIPT_HELPER" --mode canary --expected-workflow-id "$workflow_id" --input "${OUTPUT}.input" --output "$OUTPUT"
  rm -f "${OUTPUT}.input"
}

write_blocked_preflight() {
  [[ -n "$OUTPUT" ]] || fail "preflight output path is required"
  local captured reason="$1"
  captured="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  jq -n --arg captured "$captured" --arg repository "$REPOSITORY" --arg reason "$reason" \
    '{schema_version:1,status:"blocked",captured_at:$captured,repository:$repository,
      target_ref:"refs/heads/main",workflows:{
        canary:{id:null,path:".github/workflows/release-receipt-canary.yml"},
        controller:{id:null,path:".github/workflows/release-receipt-canary-controller.yml"},
        observer:{id:null,path:".github/workflows/release-run-observer.yml"}},
      reason:$reason,dispatch_attempted:false,credential_values_recorded:false}' | safe_write_json "$OUTPUT"
  echo "release-canary: preflight blocked (${reason})" >&2
}

run_preflight() {
  [[ -n "$OUTPUT" ]] || fail "preflight output path is required"
  command -v gh >/dev/null 2>&1 || { write_blocked_preflight gh_unavailable; return 0; }
  [[ "$REPOSITORY" == szTheory/sigra ]] || { write_blocked_preflight repository_identity_mismatch; return 0; }
  local repo workflow source controller observer workflow_perms actions_perms retention_policy retention retention_maximum captured main_sha
  repo="$(gh api "repos/${REPOSITORY}" 2>/dev/null)" || { write_blocked_preflight repository_metadata_unavailable; return 0; }
  workflow="$(gh api "repos/${REPOSITORY}/actions/workflows/release-receipt-canary.yml" 2>/dev/null)" || { write_blocked_preflight canary_workflow_not_visible; return 0; }
  controller="$(gh api "repos/${REPOSITORY}/actions/workflows/release-receipt-canary-controller.yml" 2>/dev/null)" || { write_blocked_preflight controller_workflow_not_visible; return 0; }
  observer="$(gh api "repos/${REPOSITORY}/actions/workflows/release-run-observer.yml" 2>/dev/null)" || { write_blocked_preflight observer_workflow_not_visible; return 0; }
  workflow_perms="$(gh api "repos/${REPOSITORY}/actions/permissions/workflow" 2>/dev/null)" || { write_blocked_preflight workflow_permissions_unreadable; return 0; }
  actions_perms="$(gh api "repos/${REPOSITORY}/actions/permissions" 2>/dev/null)" || { write_blocked_preflight actions_settings_unreadable; return 0; }
  retention_policy="$(gh api "repos/${REPOSITORY}/actions/permissions/artifact-and-log-retention" 2>/dev/null)" || { write_blocked_preflight artifact_retention_unreadable; return 0; }
  retention="$(jq -er '.days | select(type == "number" and . >= 30)' <<<"$retention_policy" 2>/dev/null)" || { write_blocked_preflight artifact_retention_below_30_days_or_unreadable; return 0; }
  retention_maximum="$(jq -er '.maximum_allowed_days | select(type == "number" and . >= 30)' <<<"$retention_policy" 2>/dev/null)" || { write_blocked_preflight artifact_retention_maximum_unreadable; return 0; }
  [[ "$(jq -r '.default_branch // empty' <<<"$repo")" == main ]] || { write_blocked_preflight default_branch_not_main; return 0; }
  [[ "$(jq -r '.enabled // false' <<<"$actions_perms")" == true ]] || { write_blocked_preflight actions_disabled; return 0; }
  [[ "$(jq -r '.name // empty' <<<"$workflow")" == "Release Receipt Canary" && "$(jq -r '.path // empty' <<<"$workflow")" == .github/workflows/release-receipt-canary.yml ]] || { write_blocked_preflight canary_identity_mismatch; return 0; }
  [[ "$(jq -r '.name // empty' <<<"$controller")" == "Release Receipt Canary Controller" && "$(jq -r '.path // empty' <<<"$controller")" == .github/workflows/release-receipt-canary-controller.yml ]] || { write_blocked_preflight controller_identity_mismatch; return 0; }
  [[ "$(jq -r '.name // empty' <<<"$observer")" == "Release Run Observer" && "$(jq -r '.path // empty' <<<"$observer")" == .github/workflows/release-run-observer.yml ]] || { write_blocked_preflight observer_identity_mismatch; return 0; }
  [[ "$(jq -r '.default_workflow_permissions // empty' <<<"$workflow_perms")" == read ]] || { write_blocked_preflight default_workflow_permissions_not_read; return 0; }
  main_sha="$(gh api "repos/${REPOSITORY}/commits/main" --jq .sha 2>/dev/null)" || { write_blocked_preflight default_branch_sha_unavailable; return 0; }
  [[ "$main_sha" =~ ^[0-9a-f]{40}$ ]] || { write_blocked_preflight default_branch_sha_malformed; return 0; }
  captured="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  jq -n --arg captured "$captured" --arg repo "$REPOSITORY" --arg main_sha "$main_sha" --argjson retention "$retention" \
    --argjson retention_maximum "$retention_maximum" \
    --argjson canary_id "$(jq -r '.id' <<<"$workflow")" \
    --argjson controller_id "$(jq -r '.id' <<<"$controller")" \
    --argjson observer_id "$(jq -r '.id' <<<"$observer")" \
    '{schema_version:1,status:"ready",captured_at:$captured,repository:$repo,default_branch:"main",target_sha:$main_sha,
      actions_enabled:true,
      artifact_retention_days:$retention,artifact_retention_maximum_days:$retention_maximum,required_retention_days:30,
      workflows:{canary:{id:$canary_id,path:".github/workflows/release-receipt-canary.yml"},
        controller:{id:$controller_id,path:".github/workflows/release-receipt-canary-controller.yml"},
        observer:{id:$observer_id,path:".github/workflows/release-run-observer.yml"}},
      default_workflow_permissions:"read",controller_authority:"actions:write; contents:read",
      source_authority:"actions:read; contents:read",observer_authority:"actions:read; contents:read",
      credential_values_recorded:false,dispatch_attempted:false}' | safe_write_json "$OUTPUT"
}

validate_committed_preflight() {
  local source_path="${CANARY_PREFLIGHT_FILE:-$ROOT/.planning/phases/250-close-v1-49-audit-gaps-reconcile-phase-247-248-249-verificat/250-CANARY-PREFLIGHT.json}"
  local target_path="$1" preflight captured captured_epoch now age repo canary controller observer main_sha current_sha
  OUTPUT="$target_path"
  [[ -f "$source_path" ]] || { write_blocked_preflight committed_preflight_missing; return 1; }
  cp "$source_path" "$target_path"
  preflight="$target_path"
  jq -e 'type == "object" and .schema_version == 1 and .status == "ready" and
    .repository == "szTheory/sigra" and .default_branch == "main" and
    (.target_sha | type == "string" and test("^[0-9a-f]{40}$")) and
    (.artifact_retention_days | type == "number" and . >= 30) and
    (.artifact_retention_maximum_days | type == "number" and . >= 30) and
    .actions_enabled == true and .default_workflow_permissions == "read" and
    .controller_authority == "actions:write; contents:read" and
    .source_authority == "actions:read; contents:read" and .observer_authority == "actions:read; contents:read" and
    .dispatch_attempted == false and .credential_values_recorded == false' \
    "$preflight" >/dev/null 2>&1 || { write_blocked_preflight committed_preflight_invalid; return 1; }
  captured="$(jq -er '.captured_at | select(type == "string" and test("^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$"))' "$preflight")" || { write_blocked_preflight committed_preflight_timestamp_invalid; return 1; }
  captured_epoch="$(date -u -j -f '%Y-%m-%dT%H:%M:%SZ' "$captured" '+%s' 2>/dev/null || date -u -d "$captured" '+%s' 2>/dev/null)" || { write_blocked_preflight committed_preflight_timestamp_invalid; return 1; }
  now="$(date -u '+%s')"; age=$((now - captured_epoch))
  (( age >= 0 && age <= 900 )) || { write_blocked_preflight committed_preflight_stale; return 1; }

  repo="$(gh api "repos/${REPOSITORY}" 2>/dev/null)" || { write_blocked_preflight repository_metadata_unavailable; return 1; }
  [[ "$(jq -r '.default_branch // empty' <<<"$repo")" == main ]] || { write_blocked_preflight default_branch_not_main; return 1; }
  canary="$(gh api "repos/${REPOSITORY}/actions/workflows/release-receipt-canary.yml" 2>/dev/null)" || { write_blocked_preflight canary_workflow_not_visible; return 1; }
  controller="$(gh api "repos/${REPOSITORY}/actions/workflows/release-receipt-canary-controller.yml" 2>/dev/null)" || { write_blocked_preflight controller_workflow_not_visible; return 1; }
  observer="$(gh api "repos/${REPOSITORY}/actions/workflows/release-run-observer.yml" 2>/dev/null)" || { write_blocked_preflight observer_workflow_not_visible; return 1; }
  [[ "$(jq -r '.id' <<<"$canary")" == "$(jq -r '.workflows.canary.id' "$preflight")" && "$(jq -r '.path' <<<"$canary")" == .github/workflows/release-receipt-canary.yml && "$(jq -r '.name' <<<"$canary")" == 'Release Receipt Canary' ]] || { write_blocked_preflight canary_identity_changed; return 1; }
  [[ "$(jq -r '.id' <<<"$controller")" == "$(jq -r '.workflows.controller.id' "$preflight")" && "$(jq -r '.path' <<<"$controller")" == .github/workflows/release-receipt-canary-controller.yml && "$(jq -r '.name' <<<"$controller")" == 'Release Receipt Canary Controller' ]] || { write_blocked_preflight controller_identity_changed; return 1; }
  [[ "$(jq -r '.id' <<<"$observer")" == "$(jq -r '.workflows.observer.id' "$preflight")" && "$(jq -r '.path' <<<"$observer")" == .github/workflows/release-run-observer.yml && "$(jq -r '.name' <<<"$observer")" == 'Release Run Observer' ]] || { write_blocked_preflight observer_identity_changed; return 1; }
  main_sha="$(gh api "repos/${REPOSITORY}/commits/main" --jq .sha 2>/dev/null)" || { write_blocked_preflight default_branch_sha_unavailable; return 1; }
  current_sha="$(git -C "$ROOT" rev-parse HEAD 2>/dev/null)" || { write_blocked_preflight controller_checkout_sha_unavailable; return 1; }
  [[ "$current_sha" == "$main_sha" ]] || { write_blocked_preflight controller_checkout_not_current_main; return 1; }
  local target_sha file target_blob current_blob
  target_sha="$(jq -r '.target_sha' "$preflight")"
  git -C "$ROOT" merge-base --is-ancestor "$target_sha" "$current_sha" 2>/dev/null || { write_blocked_preflight default_branch_rewound_after_preflight; return 1; }
  for file in \
    .github/workflows/release-receipt-canary.yml \
    .github/workflows/release-receipt-canary-controller.yml \
    .github/workflows/release-run-observer.yml \
    scripts/ci/release-canary.sh \
    scripts/ci/release-canary.test.sh \
    scripts/ci/release-observer.sh \
    scripts/ci/release-receipt.sh \
    test/sigra/planning/phase_248_release_observer_contract_test.exs \
    test/sigra/planning/phase_250_canary_contract_test.exs; do
    target_blob="$(git -C "$ROOT" rev-parse "${target_sha}:${file}" 2>/dev/null)" || { write_blocked_preflight preflight_source_blob_unavailable; return 1; }
    current_blob="$(git -C "$ROOT" rev-parse "${current_sha}:${file}" 2>/dev/null)" || { write_blocked_preflight current_source_blob_unavailable; return 1; }
    [[ "$target_blob" == "$current_blob" ]] || { write_blocked_preflight canary_source_changed_after_preflight; return 1; }
  done
}

find_exact_run() {
  local workflow_id="$1" title="$2" response matches count elapsed=0
  while (( elapsed <= 600 )); do
    response="$(gh api "repos/${REPOSITORY}/actions/workflows/${workflow_id}/runs?branch=main&event=workflow_dispatch&per_page=100")" || return 1
    count="$(jq -er --arg title "$title" '[.workflow_runs[]? | select(.display_title == $title)] | length' <<<"$response")" || return 1
    if (( count == 1 )); then
      matches="$(jq -er --arg title "$title" '[.workflow_runs[]? | select(.display_title == $title)][0].id | select(type == "number" and floor == . and . > 0)' <<<"$response")" || return 1
      printf '%s' "$matches"
      return 0
    fi
    # A repeated exact title is ambiguous and must fail immediately. Zero matches
    # can be GitHub's short dispatch-indexing delay, so poll for at most 10 minutes.
    (( count == 0 )) || return 1
    (( elapsed < 600 )) || return 1
    sleep 60
    elapsed=$((elapsed + 60))
  done
  return 1
}

dispatch_probe() {
  local scenario="$1" probe="$2" workflow_id="$3" response id
  response="$(gh api --method POST "repos/${REPOSITORY}/actions/workflows/${workflow_id}/dispatches" \
    -f ref=main -f "inputs[scenario]=${scenario}" -f "inputs[probe_id]=${probe}")" || return 1
  id="$(jq -r '.workflow_run_id // .run_id // empty' <<<"$response" 2>/dev/null || true)"
  if [[ "$id" =~ ^[1-9][0-9]*$ ]]; then printf '%s' "$id"; return 0; fi
  find_exact_run "$workflow_id" "release-receipt-canary-${scenario}-${probe}"
}

watch_run() {
  local id="$1"
  set +e
  gh run watch "$id" --repo "$REPOSITORY" --compact --interval 60 --exit-status >/dev/null
  local rc=$?
  set -e
  # A failure/cancellation exit code is expected only after its authoritative
  # conclusion is checked by the caller.
  return 0
}

run_metadata() {
  gh api "repos/${REPOSITORY}/actions/runs/$1"
}

run_jobs() {
  gh api "repos/${REPOSITORY}/actions/runs/$1/jobs"
}

get_unique_artifact() {
  local run_id="$1" expected_name="$2" listing
  listing="$(gh api "repos/${REPOSITORY}/actions/runs/${run_id}/artifacts")" || return 1
  jq -er --arg name "$expected_name" '
    [.artifacts[]? | select(.name == $name and .expired == false)] |
    if length == 1 then .[0] else error("artifact identity is absent or ambiguous") end
  ' <<<"$listing"
}

download_receipt_artifact() {
  local artifact_json="$1" target_dir="$2" artifact_id name expected_digest actual_digest zip
  artifact_id="$(jq -er '.id | select(type == "number" and floor == . and . > 0)' <<<"$artifact_json")" || return 1
  name="$(jq -er '.name | select(type == "string")' <<<"$artifact_json")" || return 1
  expected_digest="$(jq -er '.digest | select(type == "string" and test("^sha256:[0-9a-f]{64}$")) | sub("^sha256:"; "")' <<<"$artifact_json")" || return 1
  zip="${target_dir}/artifact-${artifact_id}.zip"
  mkdir -p "$target_dir"
  gh api "repos/${REPOSITORY}/actions/artifacts/${artifact_id}/zip" --output "$zip" >/dev/null || return 1
  actual_digest="$(shasum -a 256 "$zip" | awk '{print $1}')"
  [[ "$actual_digest" == "$expected_digest" ]] || return 1
  unzip -p "$zip" canary-receipt.json > "${target_dir}/receipt.json" || return 1
  jq -e 'type == "object" and .receipt_kind == "canary"' "${target_dir}/receipt.json" >/dev/null || return 1
  printf '%s\n' "$name"
}

wait_for_cancellation_stage() {
  local id="$1" jobs run elapsed=0
  while (( elapsed <= 600 )); do
    run="$(run_metadata "$id")" || return 1
    [[ "$(jq -r '.id | tostring' <<<"$run")" == "$id" && "$(jq -r '.head_branch' <<<"$run")" == main && "$(jq -r '.event' <<<"$run")" == workflow_dispatch && "$(jq -r '.status' <<<"$run")" == in_progress ]] || return 1
    jobs="$(run_jobs "$id")" || return 1
    if jq -e '[.jobs[]?.steps[]? | select(.name == "Bounded cancellation wait" and .status == "in_progress")] | length == 1' <<<"$jobs" >/dev/null; then return 0; fi
    sleep 60
    elapsed=$((elapsed + 60))
  done
  return 1
}

cancel_exact_canary_run() {
  local id="$1" expected_workflow_id="$2" expected_probe_id="$3" run jobs
  [[ "$id" =~ ^[1-9][0-9]*$ && "$expected_workflow_id" =~ ^[1-9][0-9]*$ ]] || return 1
  valid_probe_id "$expected_probe_id" || return 1
  run="$(run_metadata "$id")" || return 1
  [[ "$(jq -r '.id | tostring' <<<"$run")" == "$id" &&
     "$(jq -r '.workflow_id | tostring' <<<"$run")" == "$expected_workflow_id" &&
     "$(jq -r '.path | sub("@main$";"")' <<<"$run")" == .github/workflows/release-receipt-canary.yml &&
     "$(jq -r '.name' <<<"$run")" == "Release Receipt Canary" &&
     "$(jq -r '.event' <<<"$run")" == workflow_dispatch &&
     "$(jq -r '.head_branch' <<<"$run")" == main &&
     "$(jq -r '.display_title' <<<"$run")" == "release-receipt-canary-cancellation-${expected_probe_id}" &&
     "$(jq -r '.status' <<<"$run")" == in_progress ]] || return 1
  jobs="$(run_jobs "$id")" || return 1
  jq -e '[.jobs[]?.steps[]? | select(.name == "Bounded cancellation wait" and .status == "in_progress")] | length == 1' <<<"$jobs" >/dev/null || return 1
  gh api --method POST "repos/${REPOSITORY}/actions/runs/${id}/cancel" >/dev/null
}

wait_for_observer() {
  local source_id="$1" observer_workflow_id="$2" listing matches elapsed=0
  while (( elapsed <= 600 )); do
    listing="$(gh api "repos/${REPOSITORY}/actions/workflows/${observer_workflow_id}/runs?branch=main&event=workflow_run&per_page=100")" || return 1
    matches="$(jq -r --arg prefix "release-observer-${source_id}-" '[.workflow_runs[]? | select(.display_title | startswith($prefix))] | if length == 1 then .[0].id else empty end' <<<"$listing")"
    if [[ "$matches" =~ ^[1-9][0-9]*$ ]]; then printf '%s' "$matches"; return 0; fi
    sleep 60
    elapsed=$((elapsed + 60))
  done
  return 1
}

run_controller() {
  [[ "${GITHUB_EVENT_NAME:-}" == workflow_dispatch && "${GITHUB_REF:-}" == refs/heads/main ]] || fail "controller must run from workflow_dispatch on main"
  local proof_dir preflight_path rate core_remaining canary_wf_id observer_wf_id
  proof_dir="$(dirname "$PROOF")"; mkdir -p "$proof_dir"
  preflight_path="${proof_dir}/250-CANARY-PREFLIGHT.json"
  validate_committed_preflight "$preflight_path" || fail "fresh committed read-only Actions preflight is blocked"
  rate="$(gh api rate_limit)" || fail "GitHub rate-limit preflight unavailable"
  core_remaining="$(jq -er '.resources.core.remaining | select(type == "number")' <<<"$rate")" || fail "GitHub core rate budget unavailable"
  (( core_remaining > 250 )) || fail "GitHub core rate budget is at or below the 250-request stop threshold"
  canary_wf_id="$(jq -er '.workflows.canary.id' "$preflight_path")"
  observer_wf_id="$(jq -er '.workflows.observer.id' "$preflight_path")"
  local sha failure_probe cancel_probe failure_id cancel_id failure_run cancel_run failure_artifact cancel_artifact observer_id observer_run observer_artifact
  local tmp failure_name cancel_name expected_failure_name expected_cancel_name failure_receipt cancel_receipt
  sha="$(gh api "repos/${REPOSITORY}/commits/main" --jq .sha)" || fail "default-branch SHA unavailable"
  [[ "$sha" =~ ^[0-9a-f]{40}$ ]] || fail "default-branch SHA malformed"
  failure_probe="$(openssl rand -hex 16)"; cancel_probe="$(openssl rand -hex 16)"
  [[ "$failure_probe" != "$cancel_probe" ]] || fail "unique probe generation collided"
  expected_failure_name="release-canary-failure-"; expected_cancel_name="release-canary-cancellation-"

  DISPATCH_ATTEMPTED=true
  failure_id="$(dispatch_probe failure "$failure_probe" "$canary_wf_id")" || fail "failure probe dispatch could not be uniquely correlated"
  watch_run "$failure_id"
  failure_run="$(run_metadata "$failure_id")" || fail "failure run summary unavailable"
  [[ "$(jq -r '.id | tostring' <<<"$failure_run")" == "$failure_id" && "$(jq -r '.workflow_id | tostring' <<<"$failure_run")" == "$canary_wf_id" && "$(jq -r '.path | sub("@main$";"")' <<<"$failure_run")" == .github/workflows/release-receipt-canary.yml && "$(jq -r '.event' <<<"$failure_run")" == workflow_dispatch && "$(jq -r '.head_branch' <<<"$failure_run")" == main && "$(jq -r '.head_sha' <<<"$failure_run")" == "$sha" && "$(jq -r '.run_attempt' <<<"$failure_run")" == 1 && "$(jq -r '.display_title' <<<"$failure_run")" == "release-receipt-canary-failure-${failure_probe}" && "$(jq -r '.conclusion' <<<"$failure_run")" == failure ]] || fail "failure run exact identity or expected conclusion mismatch"
  expected_failure_name="${expected_failure_name}${failure_id}-1-${failure_probe}"
  failure_artifact="$(get_unique_artifact "$failure_id" "$expected_failure_name")" || fail "failure receipt artifact absent or ambiguous"

  cancel_id="$(dispatch_probe cancellation "$cancel_probe" "$canary_wf_id")" || fail "cancellation probe dispatch could not be uniquely correlated"
  [[ "$cancel_id" != "$failure_id" ]] || fail "probe runs unexpectedly share one run ID"
  wait_for_cancellation_stage "$cancel_id" || fail "exact cancellation probe did not reach its bounded wait stage"
  # Re-query the authoritative run and exact wait step immediately before cancel.
  cancel_exact_canary_run "$cancel_id" "$canary_wf_id" "$cancel_probe" || fail "ordinary exact-run cancellation request failed"
  watch_run "$cancel_id"
  cancel_run="$(run_metadata "$cancel_id")" || fail "cancellation run summary unavailable"
  [[ "$(jq -r '.id | tostring' <<<"$cancel_run")" == "$cancel_id" && "$(jq -r '.workflow_id | tostring' <<<"$cancel_run")" == "$canary_wf_id" && "$(jq -r '.path | sub("@main$";"")' <<<"$cancel_run")" == .github/workflows/release-receipt-canary.yml && "$(jq -r '.event' <<<"$cancel_run")" == workflow_dispatch && "$(jq -r '.head_branch' <<<"$cancel_run")" == main && "$(jq -r '.head_sha' <<<"$cancel_run")" == "$sha" && "$(jq -r '.run_attempt' <<<"$cancel_run")" == 1 && "$(jq -r '.display_title' <<<"$cancel_run")" == "release-receipt-canary-cancellation-${cancel_probe}" && "$(jq -r '.conclusion' <<<"$cancel_run")" == cancelled ]] || fail "cancellation run exact identity or expected conclusion mismatch"

  observer_id="$(wait_for_observer "$cancel_id" "$observer_wf_id")" || fail "exact cancellation observer run was not found"
  watch_run "$observer_id"
  observer_run="$(run_metadata "$observer_id")" || fail "observer run summary unavailable"
  [[ "$(jq -r '.id | tostring' <<<"$observer_run")" == "$observer_id" && "$(jq -r '.workflow_id | tostring' <<<"$observer_run")" == "$observer_wf_id" && "$(jq -r '.path' <<<"$observer_run")" == .github/workflows/release-run-observer.yml && "$(jq -r '.event' <<<"$observer_run")" == workflow_run && "$(jq -r '.head_branch' <<<"$observer_run")" == main && "$(jq -r '.conclusion' <<<"$observer_run")" == success ]] || fail "observer run exact identity or conclusion mismatch"
  expected_cancel_name="${expected_cancel_name}${cancel_id}-1"
  cancel_artifact="$(get_unique_artifact "$observer_id" "$expected_cancel_name")" || fail "observer cancellation artifact absent or ambiguous"

  tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' RETURN
  failure_name="$(download_receipt_artifact "$failure_artifact" "$tmp/failure")" || fail "failure receipt digest or JSON validation failed"
  cancel_name="$(download_receipt_artifact "$cancel_artifact" "$tmp/cancellation")" || fail "cancellation receipt digest or JSON validation failed"
  failure_receipt="$tmp/failure/receipt.json"; cancel_receipt="$tmp/cancellation/receipt.json"
  validate_receipt_pair "$failure_receipt" "$cancel_receipt" || fail "hosted receipt identities, namespaces, or outcomes disagree"
  [[ "$(jq -r '.source_run_id' "$failure_receipt")" == "$failure_id" && "$(jq -r '.source_run_attempt' "$failure_receipt")" == 1 && "$(jq -r '.source_workflow_id' "$failure_receipt")" == "$canary_wf_id" && "$(jq -r '.source_sha' "$failure_receipt")" == "$sha" && "$(jq -r '.probe_id' "$failure_receipt")" == "$failure_probe" ]] || fail "failure receipt source identity mismatch"
  [[ "$(jq -r '.source_run_id' "$cancel_receipt")" == "$cancel_id" && "$(jq -r '.source_run_attempt' "$cancel_receipt")" == 1 && "$(jq -r '.source_workflow_id' "$cancel_receipt")" == "$canary_wf_id" && "$(jq -r '.source_sha' "$cancel_receipt")" == "$sha" && "$(jq -r '.probe_id' "$cancel_receipt")" == "$cancel_probe" && "$(jq -r '.observer_run.id' "$cancel_receipt")" == "$observer_id" ]] || fail "cancellation receipt source/observer identity mismatch"

  local captured failure_artifact_id cancel_artifact_id failure_artifact_digest cancel_artifact_digest failure_expiry cancel_expiry
  captured="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  failure_artifact_id="$(jq -r '.id' <<<"$failure_artifact")"; cancel_artifact_id="$(jq -r '.id' <<<"$cancel_artifact")"
  failure_artifact_digest="$(jq -r '.digest' <<<"$failure_artifact")"; cancel_artifact_digest="$(jq -r '.digest' <<<"$cancel_artifact")"
  failure_expiry="$(jq -r '.expires_at' <<<"$failure_artifact")"; cancel_expiry="$(jq -r '.expires_at' <<<"$cancel_artifact")"
  jq -n --arg captured "$captured" --slurpfile preflight "$preflight_path" \
    --argjson failure_run "$failure_run" --argjson cancel_run "$cancel_run" --argjson observer_run "$observer_run" \
    --argjson failure_artifact "$failure_artifact" --argjson cancel_artifact "$cancel_artifact" \
    --slurpfile failure_receipt "$failure_receipt" --slurpfile cancel_receipt "$cancel_receipt" \
    '{schema_version:1,status:"pass",captured_at:$captured,preflight:$preflight[0],
      source_failure:{run_id:($failure_run.id|tostring),attempt:$failure_run.run_attempt,workflow_id:$failure_run.workflow_id,
        workflow_path:$failure_run.path,event:$failure_run.event,ref:("refs/heads/"+$failure_run.head_branch),sha:$failure_run.head_sha,
        conclusion:$failure_run.conclusion,created_at:$failure_run.created_at,updated_at:$failure_run.updated_at,
        artifact:{id:$failure_artifact.id,name:$failure_artifact.name,digest:$failure_artifact.digest,expires_at:$failure_artifact.expires_at},
        receipt:$failure_receipt[0]},
      source_cancellation:{run_id:($cancel_run.id|tostring),attempt:$cancel_run.run_attempt,workflow_id:$cancel_run.workflow_id,
        workflow_path:$cancel_run.path,event:$cancel_run.event,ref:("refs/heads/"+$cancel_run.head_branch),sha:$cancel_run.head_sha,
        conclusion:$cancel_run.conclusion,created_at:$cancel_run.created_at,updated_at:$cancel_run.updated_at,
        artifact:{id:$cancel_artifact.id,name:$cancel_artifact.name,digest:$cancel_artifact.digest,expires_at:$cancel_artifact.expires_at},
        observer_run_id:($observer_run.id|tostring),observer_attempt:$observer_run.run_attempt,
        observer_workflow_id:$observer_run.workflow_id,observer_workflow_path:$observer_run.path,
        observer_event:$observer_run.event,observer_ref:("refs/heads/"+$observer_run.head_branch),
        observer_conclusion:$observer_run.conclusion,receipt:$cancel_receipt[0]},
      retrieval:{failure_artifact_name:$failure_artifact.name,cancellation_artifact_name:$cancel_artifact.name,
        retrieved_at:$captured,failure_zip_sha256:($failure_artifact.digest|sub("^sha256:";"")),
        cancellation_zip_sha256:($cancel_artifact.digest|sub("^sha256:";""))},
      credential_values_recorded:false}' | safe_write_json "$PROOF"
  bash "$0" --validate-proof "$PROOF"
}

case "$MODE" in
  resolve-run)
    [[ "$WORKFLOW_ID" =~ ^[1-9][0-9]*$ ]] || fail "workflow ID is malformed"
    [[ "$SCENARIO" == failure || "$SCENARIO" == cancellation ]] || fail "scenario is invalid"
    valid_probe_id "$PROBE_ID" || fail "probe ID is malformed"
    exact_title="release-receipt-canary-${SCENARIO}-${PROBE_ID}"
    exact_run="$(find_exact_run "$WORKFLOW_ID" "$exact_title")" || fail "probe run match is zero or ambiguous"
    printf '%s\n' "$exact_run"
    ;;
  cancel-canary)
    [[ "$PROOF" =~ ^[1-9][0-9]*$ ]] || fail "run ID is malformed"
    [[ "$WORKFLOW_ID" =~ ^[1-9][0-9]*$ ]] || fail "workflow ID is malformed"
    valid_probe_id "$PROBE_ID" || fail "probe ID is malformed"
    cancel_exact_canary_run "$PROOF" "$WORKFLOW_ID" "$PROBE_ID" || fail "refusing to cancel a non-canary or non-waiting run"
    echo "release-canary: cancelled exact canary run ${PROOF}"
    ;;
  validate-pair)
    [[ -n "$FAILURE_RECEIPT" && -f "$FAILURE_RECEIPT" && -n "$CANCELLATION_RECEIPT" && -f "$CANCELLATION_RECEIPT" ]] || fail "both receipt files are required"
    validate_receipt_pair "$FAILURE_RECEIPT" "$CANCELLATION_RECEIPT" || fail "receipt pair identity or outcome mismatch"
    echo "release-canary: receipt pair PASS"
    ;;
  self-test)
    command -v jq >/dev/null 2>&1 || fail "jq is required"
    tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
    probe_a=0123456789abcdef; probe_b=abcdef0123456789; sha=0123456789abcdef0123456789abcdef01234567
    jq -n --arg probe "$probe_a" --arg sha "$sha" '{schema_version:1,receipt_kind:"canary",canary:{probe_id:$probe,scenario:"failure"},source_event:"workflow_dispatch",source:{repository:"szTheory/sigra",ref:"refs/heads/main",sha:$sha},source_run:{id:"1001",attempt:1,workflow_id:10,workflow_name:"Release Receipt Canary",workflow_path:".github/workflows/release-receipt-canary.yml",url:"https://github.com/szTheory/sigra/actions/runs/1001",started_at:"2026-10-10T00:00:00Z",observed_at:"2026-10-10T00:01:00Z"},terminal_verdict:"failure",observer_run:null}' > "$tmp/failure-input.json"
    jq -n --arg probe "$probe_b" --arg sha "$sha" '{schema_version:1,receipt_kind:"canary",canary:{probe_id:$probe,scenario:"cancellation"},source_event:"workflow_dispatch",source:{repository:"szTheory/sigra",ref:"refs/heads/main",sha:$sha},source_run:{id:"1002",attempt:1,workflow_id:10,workflow_name:"Release Receipt Canary",workflow_path:".github/workflows/release-receipt-canary.yml",url:"https://github.com/szTheory/sigra/actions/runs/1002",started_at:"2026-10-10T00:00:00Z",observed_at:"2026-10-10T00:01:00Z"},terminal_verdict:"cancelled",observer_run:{id:"1003",attempt:1,workflow_id:11,url:"https://github.com/szTheory/sigra/actions/runs/1003",started_at:"2026-10-10T00:01:00Z",observed_at:"2026-10-10T00:02:00Z"}}' > "$tmp/cancellation-input.json"
    bash "$RECEIPT_HELPER" --mode canary --expected-workflow-id 10 --input "$tmp/failure-input.json" --output "$tmp/failure.json" >/dev/null
    bash "$RECEIPT_HELPER" --mode canary --expected-workflow-id 10 --input "$tmp/cancellation-input.json" --output "$tmp/cancellation.json" >/dev/null
    validate_receipt_pair "$tmp/failure.json" "$tmp/cancellation.json" || fail "local dual-outcome contract failed"
    if bash "$RECEIPT_HELPER" --input "$tmp/failure-input.json" --output "$tmp/production-rejected.json" >/dev/null 2>&1; then fail "production mode accepted a canary envelope"; fi
    echo "release-canary: self-test PASS"
    ;;
  validate-proof)
    [[ -n "$PROOF" && -f "$PROOF" ]] || fail "proof JSON file is required"
    jq -e 'def no_credential_keys:
      [.. | objects | to_entries[] |
        select((.key | test("(token|secret|credential|api.?key)";"i")) and
          (.key != "credential_values_recorded" or .value != false))] | length == 0;
      type == "object" and .schema_version == 1 and .status == "pass" and
      .credential_values_recorded == false and .preflight.status == "ready" and
      .preflight.credential_values_recorded == false and .source_failure.receipt.receipt_kind == "canary" and
      .source_failure.receipt.terminal_verdict == "failure" and .source_cancellation.receipt.receipt_kind == "canary" and
      .source_cancellation.receipt.terminal_verdict == "cancelled" and .source_failure.run_id != .source_cancellation.run_id and
      .source_failure.run_id == .source_failure.receipt.source_run_id and
      .source_cancellation.run_id == .source_cancellation.receipt.source_run_id and
      .source_failure.attempt == .source_failure.receipt.source_run_attempt and
      .source_cancellation.attempt == .source_cancellation.receipt.source_run_attempt and
      .source_failure.receipt.source_repository == "szTheory/sigra" and
      .source_cancellation.receipt.source_repository == "szTheory/sigra" and
      .source_failure.workflow_id == .source_failure.receipt.source_workflow_id and
      .source_cancellation.workflow_id == .source_cancellation.receipt.source_workflow_id and
      (.source_failure.workflow_path | sub("@main$";"")) == .source_failure.receipt.source_workflow_path and
      (.source_cancellation.workflow_path | sub("@main$";"")) == .source_cancellation.receipt.source_workflow_path and
      .source_failure.event == "workflow_dispatch" and .source_cancellation.event == "workflow_dispatch" and
      .source_failure.ref == "refs/heads/main" and .source_cancellation.ref == "refs/heads/main" and
      (.source_failure.sha | test("^[0-9a-f]{40}$")) and .source_failure.sha == .source_cancellation.sha and
      .source_cancellation.observer_run_id == .source_cancellation.receipt.observer_run.id and
      .source_cancellation.observer_workflow_path == ".github/workflows/release-run-observer.yml" and
      .source_cancellation.observer_event == "workflow_run" and .source_cancellation.observer_ref == "refs/heads/main" and
      .source_cancellation.observer_conclusion == "success" and
      (.source_failure.artifact.id | type == "number" and . > 0) and
      (.source_cancellation.artifact.id | type == "number" and . > 0) and
      (.source_failure.artifact.digest | test("^sha256:[0-9a-f]{64}$")) and
      (.source_cancellation.artifact.digest | test("^sha256:[0-9a-f]{64}$")) and
      .source_failure.artifact.name == ("release-canary-failure-" + .source_failure.run_id + "-" + (.source_failure.attempt|tostring) + "-" + .source_failure.receipt.probe_id) and
      .source_cancellation.artifact.name == ("release-canary-cancellation-" + .source_cancellation.run_id + "-" + (.source_cancellation.attempt|tostring)) and
      (.source_failure.artifact.expires_at | type == "string") and (.source_cancellation.artifact.expires_at | type == "string") and
      (.source_failure.created_at | type == "string") and (.source_failure.updated_at | type == "string") and
      (.source_cancellation.created_at | type == "string") and (.source_cancellation.updated_at | type == "string") and
      .retrieval.failure_zip_sha256 == (.source_failure.artifact.digest | sub("^sha256:";"")) and
      .retrieval.cancellation_zip_sha256 == (.source_cancellation.artifact.digest | sub("^sha256:";"")) and
      no_credential_keys' "$PROOF" >/dev/null || fail "proof is blocked, incomplete, misbound, or contains credential-shaped keys"
    echo "release-canary: proof PASS"
    ;;
  write-failure) write_failure_receipt ;;
  preflight)
    run_preflight
    [[ "$(jq -r '.status' "$OUTPUT")" == ready ]] || exit 1
    ;;
  validate-preflight)
    [[ -n "$OUTPUT" ]] || fail "validated preflight output path is required"
    validate_committed_preflight "$OUTPUT" || fail "committed Actions preflight is not fresh or source-bound"
    echo "release-canary: preflight PASS"
    ;;
  run)
    [[ -n "$PROOF" ]] || fail "controller proof output path is required"
    run_controller
    ;;
  *) usage; exit 2 ;;
esac
