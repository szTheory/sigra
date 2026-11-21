#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
GUARD="$SCRIPT_DIR/tracked-privacy-guard.pl"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
REPO="$TMP/repo"
MAINTAINER_TOKEN=jo
MAINTAINER_TOKEN+=n
USER_PATH_PREFIX=/Users
HOME_PATH_PREFIX=/home
mkdir -p "$REPO"
git -C "$REPO" init -q
git -C "$REPO" config user.name Tester
git -C "$REPO" config user.email tester@example.test
mkdir -p "$REPO/.planning/milestones/archive" "$REPO/.planning/execution"
printf 'Legacy public path: %s/%s/private/project/\n' "$USER_PATH_PREFIX" "$MAINTAINER_TOKEN" > "$REPO/legacy.txt"
perl -e 'print "x" x 65537' > "$REPO/.planning/milestones/archive/OLD-RECEIPTS.json"
git -C "$REPO" add legacy.txt .planning
git -C "$REPO" commit -qm base
BASE=$(git -C "$REPO" rev-parse HEAD)
BASELINE="$REPO/test/fixtures/ci/tracked-privacy-exceptions.tsv"
mkdir -p "$(dirname "$BASELINE")"
printf '# tracked-privacy-exceptions-v1 maintainer-token=%s\n' "$MAINTAINER_TOKEN" > "$BASELINE"

pass() {
  if ! perl "$GUARD" --root "$REPO" --base "$BASE" --baseline "$BASELINE" >/dev/null 2>&1; then
    perl "$GUARD" --root "$REPO" --base "$BASE" --baseline "$BASELINE" >"$TMP/out" 2>&1 || true
    echo "expected guard pass: $*" >&2; cat "$TMP/out" >&2; exit 1
  fi
}
fail() {
  if perl "$GUARD" --root "$REPO" --base "$BASE" --baseline "$BASELINE" >"$TMP/out" 2>&1; then
    echo "expected guard failure: $*" >&2; exit 1
  fi
}

# Bootstrap from findings and ledger sizes computed from the actual base tree.
perl "$GUARD" --root "$REPO" --base "$BASE" --baseline "$BASELINE" --print-base-baseline > "$TMP/generated-baseline.tsv"
cp "$TMP/generated-baseline.tsv" "$BASELINE"
pass 'merge-base-derived privacy and ledger baseline'
git -C "$REPO" add test
git -C "$REPO" commit -qm 'review base findings'
BASELINE_BASE=$(git -C "$REPO" rev-parse HEAD)

# Plain-name matching is boundary based; substring matches stay clean.
printf 'Jonathan conjunx\n' > "$REPO/clean.txt"
git -C "$REPO" add clean.txt
pass 'clean and unrelated substrings'

# New home paths are found in both ordinary text and arbitrary binary bytes.
printf 'new path %s/alice/private/\n' "$HOME_PATH_PREFIX" > "$REPO/new-home.txt"
git -C "$REPO" add new-home.txt
fail 'Linux home path in text'
printf '\211PNG\r\n\032\nmetadata %s/alice/secrets/\000tail' "$USER_PATH_PREFIX" > "$REPO/image.bin"
git -C "$REPO" add image.bin
fail 'macOS home path in binary'
printf 'Maintainer %s wrote this\n' "$MAINTAINER_TOKEN" > "$REPO/name.txt"
git -C "$REPO" add name.txt
fail 'boundary-delimited maintainer token'
rm "$REPO/new-home.txt" "$REPO/image.bin" "$REPO/name.txt"
git -C "$REPO" reset -q

# A PR-only finding cannot be blessed into a bootstrap baseline.
printf 'new path %s/alice/pr-only/\n' "$HOME_PATH_PREFIX" > "$REPO/pr-only.txt"
git -C "$REPO" add pr-only.txt
perl "$GUARD" --root "$REPO" --base "$BASELINE_BASE" --baseline "$BASELINE" --print-current-findings > "$TMP/current"
cp "$BASELINE" "$TMP/valid.tsv"
grep $'\tpr-only.txt$' "$TMP/current" | while IFS= read -r row; do printf 'finding\t%s\n' "$row"; done >> "$BASELINE"
if perl "$GUARD" --root "$REPO" --base "$BASELINE_BASE" --baseline "$BASELINE" >"$TMP/out" 2>&1; then
  echo 'PR-only baseline entry unexpectedly passed' >&2; exit 1
fi
grep -q 'baseline finding is not present in merge-base' "$TMP/out"
cp "$TMP/valid.tsv" "$BASELINE"
rm "$REPO/pr-only.txt"
git -C "$REPO" reset -q

# Malformed and duplicate baseline rows fail closed.
cp "$BASELINE" "$TMP/valid.tsv"
printf 'bogus\trow\n' >> "$BASELINE"
fail 'malformed baseline row'
cp "$TMP/valid.tsv" "$BASELINE"
first=$(sed -n '2p' "$BASELINE")
printf '%s\n' "$first" >> "$BASELINE"
fail 'duplicate fingerprint'
cp "$TMP/valid.tsv" "$BASELINE"

# Historical exact ledger exception is shrink-only; new files have a 64 KiB cap.
perl -e 'print "x" x 65536' > "$REPO/.planning/execution/within.json"
git -C "$REPO" add .planning/execution/within.json
pass '64 KiB ledger boundary'
perl -e 'print "x" x 65537' > "$REPO/.planning/execution/over.json"
git -C "$REPO" add .planning/execution/over.json
fail 'one byte over ledger boundary'
rm "$REPO/.planning/execution/over.json"
git -C "$REPO" reset -q
perl -e 'print "x" x 65536' > "$REPO/.planning/milestones/archive/OLD-RECEIPTS.json"
pass 'historical ledger shrank'
perl -e 'print "x" x 65538' > "$REPO/.planning/milestones/archive/OLD-RECEIPTS.json"
fail 'historical ledger growth'
perl -e 'print "x" x 65537' > "$REPO/.planning/milestones/archive/OLD-RECEIPTS.json"

# Baseline regeneration is deterministic and contains no duplicate rows.
perl "$GUARD" --root "$REPO" --base "$BASE" --baseline "$BASELINE" --print-base-baseline > "$TMP/regenerated"
cmp "$BASELINE" "$TMP/regenerated"
test "$(sort "$BASELINE" | uniq -d | wc -l | tr -d ' ')" = 0

echo 'tracked privacy guard controls passed'
