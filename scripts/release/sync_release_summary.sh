#!/usr/bin/env bash
set -euo pipefail

VERSION="${1:?usage: sync_release_summary.sh <version> [tag]}"
TAG="${2:-v$VERSION}"
REPO="${GITHUB_REPOSITORY:?GITHUB_REPOSITORY is required}"
START_MARKER="<!-- sigra-release-summary:start -->"
END_MARKER="<!-- sigra-release-summary:end -->"

if ! command -v gh >/dev/null 2>&1; then
  echo "gh CLI is required" >&2
  exit 1
fi

summary="$(
  VERSION="$VERSION" perl -0ne '
    if (/^## \[\Q$ENV{VERSION}\E\][^\n]*\n(.*?)(?=^## \[|\z)/ms) {
      my $release = $1;
      if ($release =~ /(?:^|\n)### Summary\n(.*?)(?=^### |\z)/ms) {
        print $1;
        exit 0;
      }
    }
    exit 1;
  ' CHANGELOG.md
)"

summary="$(
  printf '%s' "$summary" |
    perl -0pe 's/\A\s+//; s/\s+\z//;'
)"

if [[ -z "$summary" ]]; then
  echo "No summary content found for CHANGELOG.md release $VERSION" >&2
  exit 1
fi

for _ in $(seq 1 12); do
  if gh release view "$TAG" --repo "$REPO" >/dev/null 2>&1; then
    break
  fi
  sleep 5
done

if ! gh release view "$TAG" --repo "$REPO" >/dev/null 2>&1; then
  gh release create "$TAG" \
    --repo "$REPO" \
    --title "$TAG" \
    --generate-notes \
    --verify-tag
fi

current_body="$(gh release view "$TAG" --repo "$REPO" --json body --jq .body)"

clean_body="$(
  printf '%s' "$current_body" |
    perl -0pe 's/\n?<!-- sigra-release-summary:start -->.*?<!-- sigra-release-summary:end -->\n?//ms;'
)"

tmp_notes="$(mktemp)"
{
  printf '%s\n' "$START_MARKER"
  printf '## Summary\n\n'
  printf '%s\n' "$summary"
  printf '%s\n' "$END_MARKER"

  if [[ -n "$clean_body" ]]; then
    printf '\n%s\n' "$clean_body"
  fi
} > "$tmp_notes"

gh release edit "$TAG" --repo "$REPO" --notes-file "$tmp_notes"

echo "Updated GitHub release $TAG with changelog summary."
