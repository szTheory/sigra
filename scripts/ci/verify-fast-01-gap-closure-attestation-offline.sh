#!/usr/bin/env bash
# Network-denied verifier for the sole FAST-01 gap-closure subject.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PHASE="$ROOT/.planning/phases/235-terminal-ratification-measured-not-read"
RECEIPT="$PHASE/235-FAST-01-GAP-CLOSURE-REMEASUREMENT.json"
BUNDLE="$PHASE/235-FAST-01-GAP-CLOSURE-REMEASUREMENT.attestation.jsonl"
TRUSTED_ROOT="$PHASE/235-FAST-01-GAP-CLOSURE-REMEASUREMENT-TRUSTED-ROOT.jsonl"
REPO="szTheory/sigra"
SIGNER="szTheory/sigra/.github/workflows/fast-01-gap-closure-evidence.yml"
DIGEST="3bd77e529ddf1963302555febee3b30b66c4af383579a7992c2eb82691eac9f3"
WORKFLOW_SHA="9b8a0344708fb829583e430b7ccd8b9359613de7"
for command in gh jq mktemp realpath; do command -v "$command" >/dev/null || { echo "missing_required_command:$command" >&2; exit 1; }; done
GH_BIN="$(realpath "$(command -v gh)")"; JQ_BIN="$(realpath "$(command -v jq)")"
case "$GH_BIN" in /usr/bin/gh|/opt/homebrew/Cellar/gh/*/bin/gh|/usr/local/Cellar/gh/*/bin/gh) ;; *) echo "untrusted_gh_executable:$GH_BIN" >&2; exit 1;; esac
for file in "$RECEIPT" "$BUNDLE" "$TRUSTED_ROOT"; do test -s "$file" || { echo "missing_or_empty_retained_input:$file" >&2; exit 1; }; done
case "$(uname -s)" in
  Darwin) test -x /usr/bin/sandbox-exec || { echo "network_isolation_unavailable:sandbox-exec" >&2; exit 1; }; isolation=(/usr/bin/sandbox-exec -p '(version 1) (allow default) (deny network*)');;
  Linux) /usr/bin/unshare --user --map-root-user --net true >/dev/null 2>&1 || { echo "network_isolation_unavailable:unshare" >&2; exit 1; }; isolation=(/usr/bin/unshare --user --map-root-user --net);;
  *) echo "network_isolation_unavailable:unsupported_platform" >&2; exit 1;;
esac
work="$(mktemp -d)"; trap 'rm -rf "$work"' EXIT; mkdir "$work/home"
cp "$RECEIPT" "$work/receipt.json"; cp "$BUNDLE" "$work/bundle.jsonl"; cp "$TRUSTED_ROOT" "$work/root.jsonl"
verify() {
  local output="$1"; shift
  "${isolation[@]}" /usr/bin/env -i PATH=/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:/opt/homebrew/bin HOME="$work/home" GH_TOKEN= GITHUB_TOKEN= HTTP_PROXY= HTTPS_PROXY= ALL_PROXY= NO_PROXY= \
    "$GH_BIN" attestation verify "$@" --bundle "$work/bundle.jsonl" --custom-trusted-root "$work/root.jsonl" --repo "$REPO" --signer-workflow "$SIGNER" --source-ref refs/heads/main --format json >"$output"
}
verify "$work/positive.json" "$work/receipt.json"
"$JQ_BIN" -e --arg digest "$DIGEST" --arg sha "$WORKFLOW_SHA" 'length == 1 and .[0].verificationResult.statement.subject[0].digest.sha256 == $digest and .[0].verificationResult.signature.certificate.sourceRepositoryURI == "https://github.com/szTheory/sigra" and .[0].verificationResult.signature.certificate.sourceRepositoryRef == "refs/heads/main" and .[0].verificationResult.signature.certificate.githubWorkflowRepository == "szTheory/sigra" and .[0].verificationResult.signature.certificate.githubWorkflowRef == "refs/heads/main" and .[0].verificationResult.signature.certificate.githubWorkflowSHA == $sha' "$work/positive.json" >/dev/null || { echo positive_policy_binding_failed >&2; exit 1; }
expect_failure() { local name="$1"; shift; if verify "$work/$name.json" "$@"; then echo "adversarial_case_unexpectedly_verified:$name" >&2; exit 1; fi; }
cp "$RECEIPT" "$work/changed-receipt.json"; printf x >> "$work/changed-receipt.json"; expect_failure receipt_byte "$work/changed-receipt.json"
cp "$BUNDLE" "$work/bundle-pristine.jsonl"; printf x >> "$work/bundle.jsonl"; expect_failure bundle_byte "$work/receipt.json"; cp "$work/bundle-pristine.jsonl" "$work/bundle.jsonl"
cp "$TRUSTED_ROOT" "$work/root-pristine.jsonl"; printf x | dd of="$work/root.jsonl" bs=1 seek=0 conv=notrunc status=none; expect_failure trusted_root_byte "$work/receipt.json"; cp "$work/root-pristine.jsonl" "$work/root.jsonl"
if "${isolation[@]}" /usr/bin/env -i PATH=/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:/opt/homebrew/bin HOME="$work/home" "$GH_BIN" attestation verify "$work/receipt.json" --bundle "$work/bundle.jsonl" --custom-trusted-root "$work/root.jsonl" --repo "$REPO" --signer-workflow "szTheory/sigra/.github/workflows/not-fast-01-gap-closure.yml" --source-ref refs/heads/main --format json >"$work/signer.json"; then echo adversarial_case_unexpectedly_verified:signer >&2; exit 1; fi
if "${isolation[@]}" /usr/bin/env -i PATH=/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:/opt/homebrew/bin HOME="$work/home" "$GH_BIN" attestation verify "$work/receipt.json" --bundle "$work/bundle.jsonl" --custom-trusted-root "$work/root.jsonl" --repo "$REPO" --signer-workflow "$SIGNER" --source-ref refs/heads/not-main --format json >"$work/ref.json"; then echo adversarial_case_unexpectedly_verified:source_ref >&2; exit 1; fi
[[ "$(shasum -a 256 "$RECEIPT" | awk '{print $1}')" == "$DIGEST" ]] || { echo subject_digest_invalid >&2; exit 1; }
"$JQ_BIN" -e '
  (.runs|sort_by(.wall_seconds,.run_id)) as $ordered | .schema_version == "sigra.fast-01-gap-closure-remeasurement/v1" and .authority == "protected_main_attestation" and .repository == "szTheory/sigra" and .workflow == "ci.yml" and .event == "pull_request" and .cutoff.sha == "54c33e904155a454255952666711c882afdd06e4" and .window.endpoint == "2026-08-04T00:19:10Z" and .eligible_pr_run_count == 15 and (.runs|length) == 15 and ([.runs[].run_id]|unique|length) == 15 and ([.runs[]|select(.conclusion == null or .conclusion == "")]|length) == 0 and ([.runs[]|select(.conclusion == "failure")]|length) == 3 and ([.runs[]|select(.run_id == 30828457128)]|length) == 0 and $ordered[7].wall_seconds == 486 and .statistics == {mode:"wall",ordering:"{wall_seconds, run_id}",p50_seconds:486} and .verdict == "pass" and .status == "measured"' "$RECEIPT" >/dev/null || { echo population_or_verdict_invalid >&2; exit 1; }
echo offline_fast_01_gap_closure_attestation_verified
