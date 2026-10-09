#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="${SCRIPT_DIR}/release-exact-source.sh"
WORKFLOW="${SCRIPT_DIR}/../../.github/workflows/release-please.yml"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

REPO="${TMP}/repo"
mkdir -p "$REPO"
git -C "$REPO" init -q
git -C "$REPO" config user.name fixture
git -C "$REPO" config user.email fixture@example.invalid
printf 'release source one\n' >"$REPO/source.txt"
git -C "$REPO" add source.txt
git -C "$REPO" commit -qm 'fixture release source'
SOURCE_SHA="$(git -C "$REPO" rev-parse HEAD)"
git -C "$REPO" tag -a v1.0.0 -m v1.0.0 "$SOURCE_SHA"
printf 'release source two\n' >"$REPO/source.txt"
git -C "$REPO" commit -qam 'different checkout source'
OTHER_SHA="$(git -C "$REPO" rev-parse HEAD)"
git -C "$REPO" tag -a v2.0.0 -m v2.0.0 "$OTHER_SHA"
git -C "$REPO" checkout -q --detach "$SOURCE_SHA"

if [[ ! -f "$SCRIPT" ]]; then
  echo "FAIL: exact-source helper missing at $SCRIPT" >&2
  exit 1
fi

run_check() {
  (cd "$REPO" && RELEASE_TAG="$1" RELEASE_SHA="$2" bash "$SCRIPT")
}

MATCHING="$(run_check v1.0.0 "$SOURCE_SHA")"
grep -q 'PASS' <<<"$MATCHING"
grep -q "$SOURCE_SHA" <<<"$MATCHING"

if run_check v1.0.0 "$OTHER_SHA" >"$TMP/sha-mismatch.out" 2>&1; then
  echo 'FAIL: mismatched Release Please SHA was accepted' >&2
  exit 1
fi

if run_check v2.0.0 "$SOURCE_SHA" >"$TMP/tag-mismatch.out" 2>&1; then
  echo 'FAIL: tag resolving to another commit was accepted' >&2
  exit 1
fi

git -C "$REPO" checkout -q --detach "$OTHER_SHA"
if (cd "$REPO" && RELEASE_TAG=v1.0.0 RELEASE_SHA="$SOURCE_SHA" bash "$SCRIPT" >"$TMP/head-mismatch.out" 2>&1); then
  echo 'FAIL: checkout HEAD mismatch was accepted' >&2
  exit 1
fi

# The GitHub expression is intentionally a literal pattern in the workflow contract.
# shellcheck disable=SC2016
TAG_CHECKOUT_LINE="$(grep -nF 'ref: ${{ needs.release-please.outputs.tag_name }}' "$WORKFLOW" | head -1 | cut -d: -f1)"
SOURCE_CHECK_LINE="$(grep -nF 'bash scripts/ci/release-exact-source.sh' "$WORKFLOW" | head -1 | cut -d: -f1)"
BEAM_SETUP_LINE="$(grep -nF 'uses: erlef/setup-beam@' "$WORKFLOW" | head -1 | cut -d: -f1)"
if [[ -z "$TAG_CHECKOUT_LINE" || -z "$SOURCE_CHECK_LINE" || -z "$BEAM_SETUP_LINE" ]] \
  || ! (( TAG_CHECKOUT_LINE < SOURCE_CHECK_LINE && SOURCE_CHECK_LINE < BEAM_SETUP_LINE )); then
  echo 'FAIL: exact-source assertion must follow tag checkout and precede Beam/package setup' >&2
  exit 1
fi

echo 'release-exact-source.test: PASS (matching annotated tag, SHA/tag/HEAD mismatches, workflow ordering)'
