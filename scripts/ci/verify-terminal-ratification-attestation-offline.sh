#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PHASE_DIR="$ROOT/.planning/phases/235-terminal-ratification-measured-not-read"
RECEIPT="$PHASE_DIR/235-PROTECTED-RECEIPTS.json"
BUNDLE="$PHASE_DIR/235-PROTECTED-RECEIPTS.attestation.jsonl"
TRUSTED_ROOT="$PHASE_DIR/235-TRUSTED-ROOT.jsonl"
REPO="szTheory/sigra"
SIGNER_WORKFLOW="szTheory/sigra/.github/workflows/terminal-ratification-evidence.yml"
SOURCE_REF="refs/heads/main"
SUBJECT_DIGEST="022a03a03a440643871d19afe12cc7c8220b23e7d709d00e072d240e065b8244"
EXPECTED_WORKFLOW_SHA="83ef9f5d7b00a99aa945cf9839c056283c3e6c65"

for command in gh jq mktemp realpath; do
  command -v "$command" >/dev/null || { echo "missing_required_command:$command" >&2; exit 1; }
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

for input in "$RECEIPT" "$BUNDLE" "$TRUSTED_ROOT"; do
  test -s "$input" || { echo "missing_or_empty_retained_input:$input" >&2; exit 1; }
done

case "$(uname -s)" in
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

cp "$RECEIPT" "$work/receipt-byte.json"
printf x >> "$work/receipt-byte.json"
expect_failure receipt_byte "$work/receipt-byte.json"

cp "$BUNDLE" "$work/bundle-pristine.jsonl"
printf x >> "$work/bundle.jsonl"
expect_failure bundle_byte "$work/receipt.json"
cp "$work/bundle-pristine.jsonl" "$work/bundle.jsonl"

cp "$TRUSTED_ROOT" "$work/root-pristine.jsonl"
printf x | dd of="$work/trusted-root.jsonl" bs=1 seek=0 conv=notrunc status=none
expect_failure trusted_root_byte "$work/receipt.json"
cp "$work/root-pristine.jsonl" "$work/trusted-root.jsonl"

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
