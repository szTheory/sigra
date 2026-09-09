#!/usr/bin/env bash
# Plan 235-16 installs the fail-closed verifier. Plan 235-17 replaces the
# capture-specific pins only after retaining the protected subject and bundle.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PHASE_DIR="$ROOT/.planning/phases/235-terminal-ratification-measured-not-read"
RECEIPT="$PHASE_DIR/235-FAST-01-SOURCE-COMPLETE-REMEASUREMENT.json"
BUNDLE="$PHASE_DIR/235-FAST-01-SOURCE-COMPLETE-REMEASUREMENT.attestation.jsonl"
TRUSTED_ROOT="$PHASE_DIR/235-FAST-01-SOURCE-COMPLETE-REMEASUREMENT-TRUSTED-ROOT.jsonl"
REPO="szTheory/sigra"
SIGNER_WORKFLOW="szTheory/sigra/.github/workflows/fast-01-gap-closure-evidence.yml"
SOURCE_REF="refs/heads/main"
SUBJECT_DIGEST="a5f4f6d5335755fcac14e9de8827f47f2b04ad3a143df4b6f283ebfc20853594"
TRUSTED_ROOT_DIGEST="65ca537f6ed8a47fd0e560c421baa1f6c1efb8b25fc200d8c5c02c0e92eb2b9c"
EXPECTED_WORKFLOW_SHA="158aca14b11de13cbc5ab2fdea1bff790cc7ab29"
EXPECTED_CUTOFF_SHA="54c33e904155a454255952666711c882afdd06e4"
EXPECTED_CUTOFF="2026-08-03T21:37:08Z"
EXPECTED_ENDPOINT="2026-09-09T12:22:29Z"

fail() { echo "verify-fast-01-source-complete-attestation-offline: FAIL: $*" >&2; exit 1; }

validate_source_first_semantics() {
  local subject="$1"

  "$JQ_BIN" -e --arg cutoff "$EXPECTED_CUTOFF" --arg endpoint "$EXPECTED_ENDPOINT" --arg cutoff_sha "$EXPECTED_CUTOFF_SHA" '
    .schema_version=="sigra.fast-01-source-complete-remeasurement/1" and
    .authority=="protected_main_attestation" and .cutoff=={sha:$cutoff_sha,timestamp:$cutoff} and
    .window.endpoint==$endpoint and .instrument_receipt.mode=="wall" and
    (.instrument_receipt.command|contains("scripts/ci/ci-run-metrics.sh")) and
    .source_collection.resource=="GET /repos/szTheory/sigra/actions/workflows/ci.yml/runs" and
    .source_collection.query=={created:($cutoff+".."+$endpoint),per_page:100} and
    .source_collection.exhausted==true and
    [.source_collection.pages[].page]==.source_collection.requested_pages and
    .source_collection.requested_pages==[range(1;(.source_collection.pages|length)+1)] and
    .source_collection.terminal_page==.source_collection.requested_pages[-1] and
    all(.source_collection.pages[]; .returned_count==(.runs|length)) and
    all(.source_collection.pages[0:-1][];.returned_count>0) and .source_collection.pages[-1].returned_count==0 and
    ([.source_collection.pages[].runs[].run_id]|length)==([.source_collection.pages[].runs[].run_id]|unique|length) and
    ([.source_collection.pages[].runs[] |
      select(.event=="pull_request" and (.conclusion|type)=="string" and (.conclusion|length)>0 and .created_at>=$cutoff and .created_at<=$endpoint) |
      ((.created_at|fromdateiso8601) as $created | (.updated_at|fromdateiso8601) as $updated |
        if $updated<$created then error("run_chronology_invalid") else .+{wall_seconds:($updated-$created)} end)]
      | sort_by(.wall_seconds,.run_id)) as $oracle_runs |
    ($oracle_runs|length) as $n | $n>=10 and
    ($oracle_runs[($n/2|floor)]) as $median | ($oracle_runs[-1]) as $maximum |
    ($oracle_runs|map(.wall_seconds)|add/$n) as $mean |
    ($oracle_runs|group_by(.conclusion)|map({key:.[0].conclusion,value:length})|from_entries) as $outcomes |
    {mode:"wall",ordering:"{wall_seconds, run_id}",mean_seconds:$mean,p50_seconds:$median.wall_seconds,max_seconds:$maximum.wall_seconds,outcomes:$outcomes} as $oracle_statistics |
    (if $median.wall_seconds<720 then "pass" else "miss" end) as $verdict |
    .runs==$oracle_runs and .eligible_pr_run_count==$n and .verdict==$verdict and .status=="measured" and
    .statistics==$oracle_statistics and
    .selected_poles=={median_run_id:$median.run_id,maximum_run_id:$maximum.run_id} and
    .instrument_receipt.output.runs==$oracle_runs and
    .instrument_receipt.output.eligible_pr_run_count==$n and
    .instrument_receipt.output.statistics==$oracle_statistics and
    .instrument_receipt.output.selected_poles==.selected_poles and
    .instrument_receipt.output.verdict==$verdict and .instrument_receipt.output.status=="measured" and
    (if $verdict=="pass" then .binding_poles==null else
      all([.binding_poles.median,.binding_poles.maximum][]; . as $pole |
        .exhausted==true and .requested_pages==[range(1;(.pages|length)+1)] and .terminal_page==.requested_pages[-1] and
        all(.pages[];.returned_count==(.jobs|length)) and all(.pages[0:-1][];.returned_count>0) and .pages[-1].returned_count==0 and
        all(.pages[].jobs[]; . as $job | .run_id==$pole.run_id and .completed_at>=.started_at and
          ([.steps[].number]==([.steps[].number]|sort)) and
          ([.steps[].number]|length)==([.steps[].number]|unique|length) and
          all(.steps[];.status=="completed" and .started_at >= $job.started_at and
            .completed_at>=.started_at and .completed_at <= $job.completed_at))) and
      .binding_poles.median.run_id==$median.run_id and .binding_poles.maximum.run_id==$maximum.run_id end)
  ' "$subject" >/dev/null || fail "source_first_semantic_validation_failed"
}

SEMANTIC_FIXTURE=""
if (( $# > 0 )); then
  [[ "$1" == "--semantic-fixture" ]] || fail "unknown_argument:$1"
  (( $# >= 2 )) || fail "missing_semantic_fixture_path"
  (( $# == 2 )) || fail "extra_arguments_after_semantic_fixture"
  [[ -n "$2" ]] || fail "empty_semantic_fixture_path"
  SEMANTIC_FIXTURE="$2"
fi

command -v jq >/dev/null || fail "missing_required_command:jq"
JQ_BIN="$(realpath "$(command -v jq)")"
case "$JQ_BIN" in /usr/bin/jq|/opt/homebrew/Cellar/jq/*/bin/jq|/usr/local/Cellar/jq/*/bin/jq) ;; *) fail "untrusted_jq_executable:$JQ_BIN";; esac

if [[ -n "$SEMANTIC_FIXTURE" ]]; then
  [[ -s "$SEMANTIC_FIXTURE" ]] || fail "missing_or_empty_semantic_fixture:$SEMANTIC_FIXTURE"
  validate_source_first_semantics "$SEMANTIC_FIXTURE"
  echo "source_complete_semantic_fixture_verified"
  exit 0
fi

for pin in "$SUBJECT_DIGEST" "$TRUSTED_ROOT_DIGEST" "$EXPECTED_WORKFLOW_SHA" "$EXPECTED_ENDPOINT"; do
  [[ "$pin" != UNSET_PLAN_17_* ]] || fail "capture_specific_pins_unset"
done
for command in gh mktemp realpath shasum; do command -v "$command" >/dev/null || fail "missing_required_command:$command"; done
for input in "$RECEIPT" "$BUNDLE" "$TRUSTED_ROOT"; do [[ -s "$input" ]] || fail "missing_or_empty_retained_input:$input"; done

[[ "$(shasum -a 256 "$RECEIPT" | awk '{print $1}')" == "$SUBJECT_DIGEST" ]] || fail "subject_digest_mismatch"
[[ "$(shasum -a 256 "$TRUSTED_ROOT" | awk '{print $1}')" == "$TRUSTED_ROOT_DIGEST" ]] || fail "trusted_root_digest_mismatch"

GH_BIN="$(realpath "$(command -v gh)")"; MKTEMP_BIN="$(realpath "$(command -v mktemp)")"
case "$GH_BIN" in /usr/bin/gh|/opt/hostedtoolcache/gh/*/x64/gh|/opt/homebrew/Cellar/gh/*/bin/gh|/usr/local/Cellar/gh/*/bin/gh) ;; *) fail "untrusted_gh_executable:$GH_BIN";; esac

case "$(uname -s)" in
  Darwin) isolation=(/usr/bin/sandbox-exec -p '(version 1) (allow default) (deny network*)');;
  Linux)
    if /usr/bin/unshare --user --map-root-user --net true >/dev/null 2>&1; then isolation=(/usr/bin/unshare --user --map-root-user --net)
    elif [[ -x /usr/bin/sudo ]] && /usr/bin/sudo -n /usr/bin/unshare --net true >/dev/null 2>&1; then isolation=(/usr/bin/sudo -n /usr/bin/unshare --net)
    else fail "network_isolation_unavailable:unshare"; fi;;
  *) fail "network_isolation_unavailable:unsupported_platform";;
esac

work="$($MKTEMP_BIN -d)"; trap 'rm -rf -- "$work"' EXIT; mkdir "$work/home"
cp "$RECEIPT" "$work/receipt.json"; cp "$BUNDLE" "$work/bundle.jsonl"; cp "$TRUSTED_ROOT" "$work/trusted-root.jsonl"
"${isolation[@]}" /usr/bin/env -i PATH=/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:/opt/homebrew/bin HOME="$work/home" \
  GH_TOKEN= GITHUB_TOKEN= HTTP_PROXY= HTTPS_PROXY= ALL_PROXY= NO_PROXY= \
  "$GH_BIN" attestation verify "$work/receipt.json" --bundle "$work/bundle.jsonl" \
  --custom-trusted-root "$work/trusted-root.jsonl" --repo "$REPO" --signer-workflow "$SIGNER_WORKFLOW" \
  --source-ref "$SOURCE_REF" --format json >"$work/provenance.json"

"$JQ_BIN" -e --arg digest "$SUBJECT_DIGEST" --arg workflow_sha "$EXPECTED_WORKFLOW_SHA" '
  length==1 and .[0].verificationResult.statement.subject[0].digest.sha256==$digest and
  .[0].verificationResult.signature.certificate.sourceRepositoryRef=="refs/heads/main" and
  .[0].verificationResult.signature.certificate.githubWorkflowSHA==$workflow_sha
' "$work/provenance.json" >/dev/null || fail "positive_policy_binding_failed"

# Independent source-first comparison oracle. The authoritative result remains
# the exact scripts/ci/ci-run-metrics.sh wall-mode output in instrument_receipt.
validate_source_first_semantics "$RECEIPT"

echo "source_complete_offline_attestation_verified"
