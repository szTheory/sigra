#!/bin/bash
set -euo pipefail

SOURCE=${BASH_SOURCE[0]}
[[ $SOURCE == */* ]] || { echo unusable_script_path >&2; exit 1; }
ROOT="$(builtin cd -P -- "${SOURCE%/*}/../.." && builtin pwd -P)" || { echo unusable_script_root >&2; exit 1; }
PHASE_DIR="$ROOT/.planning/phases/235-terminal-ratification-measured-not-read"
RECEIPT="$PHASE_DIR/235-PROTECTED-RECEIPTS.json"
BUNDLE="$PHASE_DIR/235-PROTECTED-RECEIPTS.attestation.jsonl"
TRUSTED_ROOT="$PHASE_DIR/235-TRUSTED-ROOT.jsonl"
REPO="szTheory/sigra"
SIGNER_WORKFLOW="szTheory/sigra/.github/workflows/terminal-ratification-evidence.yml"
SOURCE_REF="refs/heads/main"
SUBJECT_DIGEST="022a03a03a440643871d19afe12cc7c8220b23e7d709d00e072d240e065b8244"
EXPECTED_WORKFLOW_SHA="83ef9f5d7b00a99aa945cf9839c056283c3e6c65"

select_bin() { local candidate; for candidate in "$@"; do [[ -x $candidate && ! -L $candidate ]] && { printf '%s\n' "$candidate"; return; }; done; echo "missing_trusted_command:$1" >&2; exit 1; }
READLINK_BIN=$(select_bin /usr/bin/readlink /bin/readlink)
resolve_trusted() { local candidate link absolute; for candidate in "$@"; do [[ -x $candidate ]] || continue; if [[ -L $candidate ]]; then link=$($READLINK_BIN "$candidate") || continue; [[ $link == /* ]] || link="${candidate%/*}/$link"; absolute=$(builtin cd -P -- "${link%/*}" && builtin pwd -P)/${link##*/} || continue; [[ -x $absolute && ! -L $absolute ]] || continue; candidate=$absolute; fi; printf '%s\n' "$candidate"; return; done; echo "missing_trusted_command:$1" >&2; exit 1; }
GH_BIN=$(resolve_trusted /usr/bin/gh /opt/homebrew/bin/gh /usr/local/bin/gh /opt/hostedtoolcache/gh/*/x64/gh)
JQ_BIN=$(resolve_trusted /usr/bin/jq /opt/homebrew/bin/jq /usr/local/bin/jq)
MKTEMP_BIN=$(resolve_trusted /usr/bin/mktemp /bin/mktemp)
UNAME_BIN=$(resolve_trusted /usr/bin/uname /bin/uname)
ENV_BIN=$(resolve_trusted /usr/bin/env /bin/env)
MKDIR_BIN=$(resolve_trusted /bin/mkdir /usr/bin/mkdir)
CP_BIN=$(resolve_trusted /bin/cp /usr/bin/cp)
RM_BIN=$(resolve_trusted /bin/rm /usr/bin/rm)
DD_BIN=$(resolve_trusted /bin/dd /usr/bin/dd)
STAT_BIN=$(resolve_trusted /usr/bin/stat /bin/stat)

for input in "$RECEIPT" "$BUNDLE" "$TRUSTED_ROOT"; do
  test -s "$input" || { echo "missing_or_empty_retained_input:$input" >&2; exit 1; }
done

case "$("$UNAME_BIN" -s)" in
  Darwin)
    test -x /usr/bin/sandbox-exec || { echo "network_isolation_unavailable:sandbox-exec" >&2; exit 1; }
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

FIXED_PARENT=$(builtin cd -P -- /tmp && builtin pwd -P) || { echo trusted_staging_failed:fixed_parent >&2; exit 1; }
[[ -d $FIXED_PARENT && ! -L $FIXED_PARENT ]] || { echo trusted_staging_failed:fixed_parent >&2; exit 1; }
case "$("$UNAME_BIN" -s)" in Darwin) [[ $($STAT_BIN -f %u "$FIXED_PARENT") == 0 && $($STAT_BIN -f %Lp "$FIXED_PARENT") =~ ^(777|1777)$ ]] || { echo trusted_staging_failed:fixed_parent >&2; exit 1; };; Linux) [[ $($STAT_BIN -c %u "$FIXED_PARENT") == 0 ]] || { echo trusted_staging_failed:fixed_parent >&2; exit 1; };; esac
work=$(TMPDIR= TMP= TEMP= "$ENV_BIN" -i PATH=/usr/bin:/bin TMPDIR= TMP= TEMP= "$MKTEMP_BIN" -d "$FIXED_PARENT/sigra-terminal-ratification.XXXXXX") || { echo trusted_staging_failed:mktemp >&2; exit 1; }
work=$(builtin cd -P -- "$work" && builtin pwd -P) || { echo trusted_staging_failed:canonical_work >&2; exit 1; }
[[ $work == "$FIXED_PARENT"/* && $work != "$FIXED_PARENT" && -d $work && ! -L $work && -O $work ]] || { echo trusted_staging_failed:work >&2; exit 1; }
case "$("$UNAME_BIN" -s)" in Darwin) [[ $($STAT_BIN -f %Lp "$work") == 700 ]] || { echo trusted_staging_failed:mode >&2; exit 1; };; Linux) [[ $($STAT_BIN -c %a "$work") == 700 ]] || { echo trusted_staging_failed:mode >&2; exit 1; };; esac
cleanup() {
  if [[ "${isolation[0]}" == "/usr/bin/sudo" ]]; then
    /usr/bin/sudo -n /usr/bin/rm -rf -- "$work"
  else
    "$RM_BIN" -rf -- "$work"
  fi
}
trap cleanup EXIT
"$MKDIR_BIN" "$work/home"
"$CP_BIN" "$RECEIPT" "$work/receipt.json"
"$CP_BIN" "$BUNDLE" "$work/bundle.jsonl"
"$CP_BIN" "$TRUSTED_ROOT" "$work/trusted-root.jsonl"

verify() {
  local output="$1"
  shift
  "${isolation[@]}" "$ENV_BIN" -i \
    PATH=/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:/opt/homebrew/bin HOME="$work/home" \
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
"$JQ_BIN" -e --arg digest "$SUBJECT_DIGEST" --arg workflow_sha "$EXPECTED_WORKFLOW_SHA" '
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

if "$JQ_BIN" -e --arg workflow_sha "0000000000000000000000000000000000000000" \
  '.[0].verificationResult.signature.certificate.githubWorkflowSHA == $workflow_sha' \
  "$work/positive.json" >/dev/null; then
  echo "adversarial_case_unexpectedly_verified:workflow_sha" >&2
  exit 1
fi

expect_failure() {
  local name="$1"
  shift
  if verify "$work/$name.json" "$@"; then
    echo "adversarial_case_unexpectedly_verified:$name" >&2
    exit 1
  fi
}

"$CP_BIN" "$RECEIPT" "$work/receipt-byte.json"
printf x >> "$work/receipt-byte.json"
expect_failure receipt_byte "$work/receipt-byte.json"

"$CP_BIN" "$BUNDLE" "$work/bundle-pristine.jsonl"
printf x >> "$work/bundle.jsonl"
expect_failure bundle_byte "$work/receipt.json"
"$CP_BIN" "$work/bundle-pristine.jsonl" "$work/bundle.jsonl"

"$CP_BIN" "$TRUSTED_ROOT" "$work/root-pristine.jsonl"
printf x | "$DD_BIN" of="$work/trusted-root.jsonl" bs=1 seek=0 conv=notrunc status=none
expect_failure trusted_root_byte "$work/receipt.json"
"$CP_BIN" "$work/root-pristine.jsonl" "$work/trusted-root.jsonl"

if "${isolation[@]}" /usr/bin/env -i PATH=/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:/opt/homebrew/bin HOME="$work/home" GH_TOKEN= GITHUB_TOKEN= HTTP_PROXY= HTTPS_PROXY= ALL_PROXY= NO_PROXY= \
  "$GH_BIN" attestation verify "$work/receipt.json" --bundle "$work/bundle.jsonl" --custom-trusted-root "$work/trusted-root.jsonl" --repo "$REPO" \
  --signer-workflow "szTheory/sigra/.github/workflows/not-terminal-ratification.yml" --source-ref "$SOURCE_REF" --format json >"$work/signer.json"; then
  echo "adversarial_case_unexpectedly_verified:signer_workflow" >&2
  exit 1
fi

if "${isolation[@]}" /usr/bin/env -i PATH=/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:/opt/homebrew/bin HOME="$work/home" GH_TOKEN= GITHUB_TOKEN= HTTP_PROXY= HTTPS_PROXY= ALL_PROXY= NO_PROXY= \
  "$GH_BIN" attestation verify "$work/receipt.json" --bundle "$work/bundle.jsonl" --custom-trusted-root "$work/trusted-root.jsonl" --repo "$REPO" \
  --signer-workflow "$SIGNER_WORKFLOW" --source-ref refs/heads/not-main --format json >"$work/source-ref.json"; then
  echo "adversarial_case_unexpectedly_verified:source_ref" >&2
  exit 1
fi

echo "offline_attestation_verified"
