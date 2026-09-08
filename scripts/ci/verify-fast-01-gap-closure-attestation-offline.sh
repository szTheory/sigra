#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PHASE_DIR="$ROOT/.planning/phases/235-terminal-ratification-measured-not-read"
RECEIPT="$PHASE_DIR/235-FAST-01-GAP-CLOSURE-REMEASUREMENT.json"
BUNDLE="$PHASE_DIR/235-FAST-01-GAP-CLOSURE-REMEASUREMENT.attestation.jsonl"
TRUSTED_ROOT="$PHASE_DIR/235-FAST-01-GAP-CLOSURE-REMEASUREMENT-TRUSTED-ROOT.jsonl"
OLD_REMEASUREMENT="$PHASE_DIR/235-FAST-01-REMEASUREMENT.json"
TERMINAL_RATIFICATION="$PHASE_DIR/235-TERMINAL-RATIFICATION.json"
REPO="szTheory/sigra"
SIGNER_WORKFLOW="szTheory/sigra/.github/workflows/fast-01-gap-closure-evidence.yml"
SOURCE_REF="refs/heads/main"
SUBJECT_DIGEST="6186f17eae61373f714fda0dd98d4318362de62d7d571d6f05e2e015b26a75ee"
TRUSTED_ROOT_DIGEST="65ca537f6ed8a47fd0e560c421baa1f6c1efb8b25fc200d8c5c02c0e92eb2b9c"
EXPECTED_WORKFLOW_SHA="c6580d793710aaeef01a1f34d7000ead9ebcdcd2"
EXPECTED_CUTOFF_SHA="54c33e904155a454255952666711c882afdd06e4"
EXPECTED_CUTOFF="2026-08-03T21:37:08Z"
EXPECTED_ENDPOINT="2026-09-08T20:05:35Z"

for required_command in gh jq mktemp realpath shasum; do
  command -v "$required_command" >/dev/null || {
    echo "missing_required_command:$required_command" >&2
    exit 1
  }
done

GH_BIN="$(realpath "$(command -v gh)")"
JQ_BIN="$(realpath "$(command -v jq)")"
MKTEMP_BIN="$(realpath "$(command -v mktemp)")"
case "$GH_BIN" in
  /usr/bin/gh|/opt/hostedtoolcache/gh/*/x64/gh|/opt/homebrew/Cellar/gh/*/bin/gh|/usr/local/Cellar/gh/*/bin/gh) ;;
  *) echo "untrusted_gh_executable:$GH_BIN" >&2; exit 1 ;;
esac
case "$JQ_BIN" in
  /usr/bin/jq|/opt/homebrew/Cellar/jq/*/bin/jq|/usr/local/Cellar/jq/*/bin/jq) ;;
  *) echo "untrusted_jq_executable:$JQ_BIN" >&2; exit 1 ;;
esac

for retained_input in "$RECEIPT" "$BUNDLE" "$TRUSTED_ROOT" "$OLD_REMEASUREMENT" "$TERMINAL_RATIFICATION"; do
  test -s "$retained_input" || {
    echo "missing_or_empty_retained_input:$retained_input" >&2
    exit 1
  }
done

actual_digest="$(shasum -a 256 "$RECEIPT" | awk '{print $1}')"
[[ "$actual_digest" == "$SUBJECT_DIGEST" ]] || {
  echo "subject_digest_mismatch" >&2
  exit 1
}
actual_trusted_root_digest="$(shasum -a 256 "$TRUSTED_ROOT" | awk '{print $1}')"
[[ "$actual_trusted_root_digest" == "$TRUSTED_ROOT_DIGEST" ]] || {
  echo "trusted_root_digest_mismatch" >&2
  exit 1
}

case "$(uname -s)" in
  Darwin)
    test -x /usr/bin/sandbox-exec || {
      echo "network_isolation_unavailable:sandbox-exec" >&2
      exit 1
    }
    isolation=(/usr/bin/sandbox-exec -p '(version 1) (allow default) (deny network*)')
    ;;
  Linux)
    if /usr/bin/unshare --user --map-root-user --net true >/dev/null 2>&1; then
      isolation=(/usr/bin/unshare --user --map-root-user --net)
    elif test -x /usr/bin/sudo && /usr/bin/sudo -n /usr/bin/unshare --net true >/dev/null 2>&1; then
      isolation=(/usr/bin/sudo -n /usr/bin/unshare --net)
    else
      echo "network_isolation_unavailable:unshare" >&2
      exit 1
    fi
    ;;
  *)
    echo "network_isolation_unavailable:unsupported_platform" >&2
    exit 1
    ;;
esac

work="$($MKTEMP_BIN -d)"
cleanup() {
  if [[ "${isolation[0]}" == "/usr/bin/sudo" ]]; then
    /usr/bin/sudo -n /usr/bin/rm -rf -- "$work"
  else
    rm -rf -- "$work"
  fi
}
trap cleanup EXIT
mkdir "$work/home"
cp "$RECEIPT" "$work/receipt.json"
cp "$BUNDLE" "$work/bundle.jsonl"
cp "$TRUSTED_ROOT" "$work/trusted-root.jsonl"

verify() {
  local output="$1"
  shift
  "${isolation[@]}" /usr/bin/env -i \
    PATH=/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:/opt/homebrew/bin \
    HOME="$work/home" \
    GH_TOKEN= GITHUB_TOKEN= HTTP_PROXY= HTTPS_PROXY= ALL_PROXY= NO_PROXY= \
    "$GH_BIN" attestation verify "$@" \
      --bundle "$work/bundle.jsonl" \
      --custom-trusted-root "$work/trusted-root.jsonl" \
      --repo "$REPO" \
      --signer-workflow "$SIGNER_WORKFLOW" \
      --source-ref "$SOURCE_REF" \
      --format json >"$output"
}

verify "$work/positive.json" "$work/receipt.json"
"$JQ_BIN" -e \
  --arg digest "$SUBJECT_DIGEST" \
  --arg workflow_sha "$EXPECTED_WORKFLOW_SHA" '
    length == 1 and
    .[0].verificationResult.statement.subject[0].digest.sha256 == $digest and
    .[0].verificationResult.signature.certificate.sourceRepositoryURI == "https://github.com/szTheory/sigra" and
    .[0].verificationResult.signature.certificate.sourceRepositoryRef == "refs/heads/main" and
    .[0].verificationResult.signature.certificate.githubWorkflowRepository == "szTheory/sigra" and
    .[0].verificationResult.signature.certificate.githubWorkflowRef == "refs/heads/main" and
    .[0].verificationResult.signature.certificate.githubWorkflowSHA == $workflow_sha
  ' "$work/positive.json" >/dev/null || {
  echo "positive_policy_binding_failed" >&2
  exit 1
}

expect_failure() {
  local name="$1"
  shift
  if verify "$work/$name.json" "$@"; then
    echo "adversarial_case_unexpectedly_verified:$name" >&2
    exit 1
  fi
}

cp "$RECEIPT" "$work/receipt-byte.json"
printf x >>"$work/receipt-byte.json"
expect_failure receipt_byte "$work/receipt-byte.json"

cp "$BUNDLE" "$work/bundle-pristine.jsonl"
printf x >>"$work/bundle.jsonl"
expect_failure bundle_byte "$work/receipt.json"
cp "$work/bundle-pristine.jsonl" "$work/bundle.jsonl"

cp "$TRUSTED_ROOT" "$work/root-pristine.jsonl"
printf x | dd of="$work/trusted-root.jsonl" bs=1 seek=0 conv=notrunc status=none
expect_failure trusted_root_byte "$work/receipt.json"
cp "$work/root-pristine.jsonl" "$work/trusted-root.jsonl"

if "${isolation[@]}" /usr/bin/env -i \
  PATH=/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:/opt/homebrew/bin HOME="$work/home" \
  GH_TOKEN= GITHUB_TOKEN= HTTP_PROXY= HTTPS_PROXY= ALL_PROXY= NO_PROXY= \
  "$GH_BIN" attestation verify "$work/receipt.json" \
    --bundle "$work/bundle.jsonl" \
    --custom-trusted-root "$work/trusted-root.jsonl" \
    --repo "$REPO" \
    --signer-workflow "szTheory/sigra/.github/workflows/not-fast-01-gap-closure.yml" \
    --source-ref "$SOURCE_REF" --format json >"$work/signer.json"; then
  echo "adversarial_case_unexpectedly_verified:signer_workflow" >&2
  exit 1
fi

if "${isolation[@]}" /usr/bin/env -i \
  PATH=/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:/opt/homebrew/bin HOME="$work/home" \
  GH_TOKEN= GITHUB_TOKEN= HTTP_PROXY= HTTPS_PROXY= ALL_PROXY= NO_PROXY= \
  "$GH_BIN" attestation verify "$work/receipt.json" \
    --bundle "$work/bundle.jsonl" \
    --custom-trusted-root "$work/trusted-root.jsonl" \
    --repo "$REPO" \
    --signer-workflow "$SIGNER_WORKFLOW" \
    --source-ref refs/heads/not-main --format json >"$work/source-ref.json"; then
  echo "adversarial_case_unexpectedly_verified:source_ref" >&2
  exit 1
fi

validate_population() {
  local input="$1"
  "$JQ_BIN" -e \
    --arg cutoff_sha "$EXPECTED_CUTOFF_SHA" \
    --arg cutoff "$EXPECTED_CUTOFF" \
    --arg endpoint "$EXPECTED_ENDPOINT" \
    --slurpfile old "$OLD_REMEASUREMENT" \
    --slurpfile terminal "$TERMINAL_RATIFICATION" '
    .schema_version == "sigra.fast-01-gap-closure-remeasurement/v1" and
    .authority == "protected_main_attestation" and
    .repository == "szTheory/sigra" and
    .workflow == "ci.yml" and
    .event == "pull_request" and
    .cutoff == {sha:$cutoff_sha,timestamp:$cutoff} and
    .window == {endpoint:$endpoint} and
    .status == "measured" and
    .statistics.mode == "wall" and
    .statistics.ordering == "{wall_seconds, run_id}" and
    (.runs | type == "array") and
    (.runs | length) == .eligible_pr_run_count and
    .eligible_pr_run_count >= 10 and
    ([.runs[].run_id] | length) == ([.runs[].run_id] | unique | length) and
    (all(.runs[];
      (.run_id | type) == "number" and
      (.wall_seconds | type) == "number" and .wall_seconds >= 0 and
      (.conclusion | IN("success", "failure", "cancelled", "timed_out", "neutral", "skipped", "stale", "action_required", "startup_failure")) and
      (.url | type) == "string" and (.url | length) > 0)) and
    ([.runs[] | {wall_seconds,run_id}] == ([.runs[] | {wall_seconds,run_id}] | sort_by(.wall_seconds,.run_id))) and
    ([.runs[].run_id] | any(. as $id | $old[0].runs[] | .run_id == $id) | not) and
    ([.runs[].run_id] | any(. as $id | $terminal[0].measurements.pull_request.run_ids[] | . == $id) | not) and
    (.runs[(.eligible_pr_run_count / 2 | floor)].wall_seconds) as $p50 |
    .statistics.p50_seconds == $p50 and
    .verdict == (if $p50 < 720 then "pass" else "miss" end)
  ' "$input" >/dev/null
}

validate_population "$RECEIPT" || {
  echo "protected_population_contract_failed" >&2
  exit 1
}

expect_population_failure() {
  local name="$1"
  local filter="$2"
  "$JQ_BIN" "$filter" "$RECEIPT" >"$work/$name-population.json"
  if validate_population "$work/$name-population.json"; then
    echo "adversarial_population_unexpectedly_valid:$name" >&2
    exit 1
  fi
}

expect_population_failure cutoff '.cutoff.timestamp = "2026-08-03T21:37:09Z"'
expect_population_failure endpoint '.window.endpoint = "2026-09-08T20:05:36Z"'
expect_population_failure historical_run_id '.runs[0].run_id = 30828457128'
expect_population_failure undersized '.runs = .runs[0:9] | .eligible_pr_run_count = 9'
expect_population_failure duplicate_run_id '.runs[1].run_id = .runs[0].run_id'
expect_population_failure empty_conclusion '.runs[0].conclusion = ""'
expect_population_failure noncanonical_order '.runs |= reverse'
expect_population_failure stored_p50 '.statistics.p50_seconds = 720'
expect_population_failure strict_verdict '.verdict = "miss"'

echo "fast_01_gap_closure_offline_attestation_verified"
