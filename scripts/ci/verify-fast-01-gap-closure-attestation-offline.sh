#!/bin/bash
# Network-denied verifier for the sole FAST-01 gap-closure subject.
set -euo pipefail

SOURCE=${BASH_SOURCE[0]}
[[ $SOURCE == */* ]] || { echo unusable_script_path >&2; exit 1; }
SCRIPT_DIR=${SOURCE%/*}
ROOT=$(builtin cd -P -- "$SCRIPT_DIR/../.." && builtin pwd -P) || { echo unusable_script_root >&2; exit 1; }
PHASE="$ROOT/.planning/phases/235-terminal-ratification-measured-not-read"
RECEIPT="$PHASE/235-FAST-01-GAP-CLOSURE-REMEASUREMENT.json"
BUNDLE="$PHASE/235-FAST-01-GAP-CLOSURE-REMEASUREMENT.attestation.jsonl"
TRUSTED_ROOT="$PHASE/235-FAST-01-GAP-CLOSURE-REMEASUREMENT-TRUSTED-ROOT.jsonl"
REPO=szTheory/sigra
SIGNER=szTheory/sigra/.github/workflows/fast-01-gap-closure-evidence.yml
DIGEST=3bd77e529ddf1963302555febee3b30b66c4af383579a7992c2eb82691eac9f3
WORKFLOW_SHA=9b8a0344708fb829583e430b7ccd8b9359613de7

select_bin() { local candidate; for candidate in "$@"; do [[ -x $candidate && ! -L $candidate ]] && { printf '%s\n' "$candidate"; return; }; done; echo "missing_trusted_command:$1" >&2; exit 1; }
READLINK_BIN=$(select_bin /usr/bin/readlink /bin/readlink)
resolve_trusted() { local candidate link absolute; for candidate in "$@"; do [[ -x $candidate ]] || continue; if [[ -L $candidate ]]; then link=$($READLINK_BIN "$candidate") || continue; [[ $link == /* ]] || link="${candidate%/*}/$link"; absolute=$(builtin cd -P -- "${link%/*}" && builtin pwd -P)/${link##*/} || continue; [[ -x $absolute && ! -L $absolute ]] || continue; candidate=$absolute; fi; printf '%s\n' "$candidate"; return; done; echo "missing_trusted_command:$1" >&2; exit 1; }
GH_BIN=$(resolve_trusted /usr/bin/gh /opt/homebrew/bin/gh /usr/local/bin/gh)
JQ_BIN=$(resolve_trusted /usr/bin/jq /opt/homebrew/bin/jq /usr/local/bin/jq)
MKTEMP_BIN=$(resolve_trusted /usr/bin/mktemp /bin/mktemp)
UNAME_BIN=$(resolve_trusted /usr/bin/uname /bin/uname)
ENV_BIN=$(resolve_trusted /usr/bin/env /bin/env)
MKDIR_BIN=$(resolve_trusted /bin/mkdir /usr/bin/mkdir)
CP_BIN=$(resolve_trusted /bin/cp /usr/bin/cp)
RM_BIN=$(resolve_trusted /bin/rm /usr/bin/rm)
DD_BIN=$(resolve_trusted /bin/dd /usr/bin/dd)
SHASUM_BIN=$(resolve_trusted /usr/bin/shasum /bin/shasum)
AWK_BIN=$(resolve_trusted /usr/bin/awk /bin/awk)
STAT_BIN=$(resolve_trusted /usr/bin/stat /bin/stat)

case "$($UNAME_BIN -s)" in
  Darwin) FIXED_PARENT=/tmp; ISOLATION=(/usr/bin/sandbox-exec -p '(version 1) (allow default) (deny network*)'); [[ -x /usr/bin/sandbox-exec ]] || { echo network_isolation_unavailable:sandbox-exec >&2; exit 1; };;
  Linux) FIXED_PARENT=/tmp; /usr/bin/unshare --user --map-root-user --net /usr/bin/true >/dev/null 2>&1 || { echo network_isolation_unavailable:unshare >&2; exit 1; }; ISOLATION=(/usr/bin/unshare --user --map-root-user --net);;
  *) echo network_isolation_unavailable:unsupported_platform >&2; exit 1;;
esac

FIXED_PARENT=$(builtin cd -P -- "$FIXED_PARENT" && builtin pwd -P) || { echo trusted_staging_failed:fixed_parent >&2; exit 1; }
[[ $FIXED_PARENT == /* && -d $FIXED_PARENT && ! -L $FIXED_PARENT ]] || { echo trusted_staging_failed:fixed_parent >&2; exit 1; }
case "$($UNAME_BIN -s)" in
  Darwin) [[ $($STAT_BIN -f %u "$FIXED_PARENT") == 0 && $($STAT_BIN -f %Lp "$FIXED_PARENT") == 1777 ]] || { echo trusted_staging_failed:fixed_parent >&2; exit 1; };;
  Linux) [[ $($STAT_BIN -c %u "$FIXED_PARENT") == 0 ]] || { echo trusted_staging_failed:fixed_parent >&2; exit 1; };;
esac

for input in "$RECEIPT" "$BUNDLE" "$TRUSTED_ROOT"; do [[ -s $input ]] || { echo "missing_or_empty_retained_input:$input" >&2; exit 1; }; done
work=$(TMPDIR= TMP= TEMP= "$ENV_BIN" -i PATH=/usr/bin:/bin TMPDIR= TMP= TEMP= "$MKTEMP_BIN" -d "$FIXED_PARENT/sigra-fast-01.XXXXXX") || { echo trusted_staging_failed:mktemp >&2; exit 1; }
work=$(builtin cd -P -- "$work" && builtin pwd -P) || { echo trusted_staging_failed:canonical_work >&2; exit 1; }
[[ $work == "$FIXED_PARENT"/* && $work != "$FIXED_PARENT" && -d $work && ! -L $work && -O $work ]] || { echo trusted_staging_failed:work >&2; exit 1; }
case "$($UNAME_BIN -s)" in Darwin) [[ $($STAT_BIN -f %Lp "$work") == 700 ]] || { echo trusted_staging_failed:mode >&2; exit 1; };; Linux) [[ $($STAT_BIN -c %a "$work") == 700 ]] || { echo trusted_staging_failed:mode >&2; exit 1; };; esac
cleanup() { "$RM_BIN" -rf -- "$work"; }
trap cleanup EXIT
"$MKDIR_BIN" "$work/home"
"$CP_BIN" "$RECEIPT" "$work/receipt.json"; "$CP_BIN" "$BUNDLE" "$work/bundle.jsonl"; "$CP_BIN" "$TRUSTED_ROOT" "$work/root.jsonl"
verify() { local output=$1; shift; "${ISOLATION[@]}" "$ENV_BIN" -i PATH=/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:/opt/homebrew/bin HOME="$work/home" GH_TOKEN= GITHUB_TOKEN= HTTP_PROXY= HTTPS_PROXY= ALL_PROXY= NO_PROXY= "$GH_BIN" attestation verify "$@" --bundle "$work/bundle.jsonl" --custom-trusted-root "$work/root.jsonl" --repo "$REPO" --signer-workflow "$SIGNER" --source-ref refs/heads/main --format json >"$output"; }
verify "$work/positive.json" "$work/receipt.json"
"$JQ_BIN" -e --arg digest "$DIGEST" --arg sha "$WORKFLOW_SHA" 'length == 1 and .[0].verificationResult.statement.subject[0].digest.sha256 == $digest and .[0].verificationResult.signature.certificate.sourceRepositoryURI == "https://github.com/szTheory/sigra" and .[0].verificationResult.signature.certificate.sourceRepositoryRef == "refs/heads/main" and .[0].verificationResult.signature.certificate.githubWorkflowRepository == "szTheory/sigra" and .[0].verificationResult.signature.certificate.githubWorkflowRef == "refs/heads/main" and .[0].verificationResult.signature.certificate.githubWorkflowSHA == $sha' "$work/positive.json" >/dev/null || { echo positive_policy_binding_failed >&2; exit 1; }
expect_failure() { local name=$1; shift; if verify "$work/$name.json" "$@"; then echo "adversarial_case_unexpectedly_verified:$name" >&2; exit 1; fi; }
"$CP_BIN" "$RECEIPT" "$work/changed-receipt.json"; printf x >> "$work/changed-receipt.json"; expect_failure receipt_byte "$work/changed-receipt.json"
"$CP_BIN" "$BUNDLE" "$work/bundle-pristine.jsonl"; printf x >> "$work/bundle.jsonl"; expect_failure bundle_byte "$work/receipt.json"; "$CP_BIN" "$work/bundle-pristine.jsonl" "$work/bundle.jsonl"
"$CP_BIN" "$TRUSTED_ROOT" "$work/root-pristine.jsonl"; printf x | "$DD_BIN" of="$work/root.jsonl" bs=1 seek=0 conv=notrunc status=none; expect_failure trusted_root_byte "$work/receipt.json"; "$CP_BIN" "$work/root-pristine.jsonl" "$work/root.jsonl"
"${ISOLATION[@]}" "$ENV_BIN" -i PATH=/usr/bin:/bin HOME="$work/home" "$GH_BIN" attestation verify "$work/receipt.json" --bundle "$work/bundle.jsonl" --custom-trusted-root "$work/root.jsonl" --repo "$REPO" --signer-workflow "szTheory/sigra/.github/workflows/not-fast-01-gap-closure.yml" --source-ref refs/heads/main --format json >"$work/signer.json" && { echo adversarial_case_unexpectedly_verified:signer >&2; exit 1; }
"${ISOLATION[@]}" "$ENV_BIN" -i PATH=/usr/bin:/bin HOME="$work/home" "$GH_BIN" attestation verify "$work/receipt.json" --bundle "$work/bundle.jsonl" --custom-trusted-root "$work/root.jsonl" --repo "$REPO" --signer-workflow "$SIGNER" --source-ref refs/heads/not-main --format json >"$work/ref.json" && { echo adversarial_case_unexpectedly_verified:source_ref >&2; exit 1; }
[[ $("$SHASUM_BIN" -a 256 "$RECEIPT" | "$AWK_BIN" '{print $1}') == "$DIGEST" ]] || { echo subject_digest_invalid >&2; exit 1; }
"$JQ_BIN" -e '(.runs|sort_by(.wall_seconds,.run_id)) as $ordered | .schema_version == "sigra.fast-01-gap-closure-remeasurement/v1" and .authority == "protected_main_attestation" and .repository == "szTheory/sigra" and .workflow == "ci.yml" and .event == "pull_request" and .cutoff.sha == "54c33e904155a454255952666711c882afdd06e4" and .window.endpoint == "2026-08-04T00:19:10Z" and .eligible_pr_run_count == 15 and (.runs|length) == 15 and ([.runs[].run_id]|unique|length) == 15 and $ordered[7].wall_seconds == 486 and .statistics == {mode:"wall",ordering:"{wall_seconds, run_id}",p50_seconds:486} and .verdict == "pass" and .status == "measured"' "$RECEIPT" >/dev/null || { echo population_or_verdict_invalid >&2; exit 1; }
echo offline_fast_01_gap_closure_attestation_verified
