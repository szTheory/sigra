#!/usr/bin/env bash
set -euo pipefail

fail() {
  echo "release-exact-source: FAIL: $*" >&2
  exit 1
}

command -v git >/dev/null 2>&1 || fail 'git not found on PATH'

TAG="${RELEASE_TAG:-}"
EXPECTED_SHA="${RELEASE_SHA:-}"
[[ -n "$TAG" ]] || fail 'RELEASE_TAG is required'
[[ "$EXPECTED_SHA" =~ ^[0-9a-f]{40}$ ]] || fail 'RELEASE_SHA must be a full lowercase Git SHA'
git check-ref-format "refs/tags/${TAG}" >/dev/null 2>&1 || fail 'RELEASE_TAG is not a valid tag name'

TAG_SHA="$(git rev-parse --verify --quiet "refs/tags/${TAG}^{commit}")" \
  || fail "tag ${TAG} does not resolve to a commit"
HEAD_SHA="$(git rev-parse --verify --quiet 'HEAD^{commit}')" \
  || fail 'checked-out HEAD does not resolve to a commit'

if [[ "$TAG_SHA" != "$EXPECTED_SHA" || "$HEAD_SHA" != "$EXPECTED_SHA" ]]; then
  fail "source identity mismatch: tag=${TAG_SHA} release_sha=${EXPECTED_SHA} head=${HEAD_SHA}"
fi

printf 'release-exact-source: PASS tag=%s sha=%s head=%s\n' "$TAG" "$TAG_SHA" "$HEAD_SHA"
