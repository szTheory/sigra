#!/usr/bin/env bash
# Create or update GitHub Pages to publish from branch gh-pages at / (legacy).
# Run from Actions after gh-pages exists so Settings → Pages does not need a
# manual branch pick the first time.
#
# Env: GITHUB_REPOSITORY=owner/name, GH_TOKEN or GITHUB_TOKEN (pages:write).
# Skips if build_type is already workflow (Actions-sourced Pages).

set -euo pipefail

REPO="${GITHUB_REPOSITORY:?GITHUB_REPOSITORY is required}"
export GH_TOKEN="${GH_TOKEN:-${GITHUB_TOKEN:-}}"
if [[ -z "${GH_TOKEN}" ]]; then
  echo "ensure-github-pages-legacy-branch: no GH_TOKEN/GITHUB_TOKEN; skip."
  exit 0
fi

if ! pages_json=$(gh api "repos/${REPO}/pages" 2>/dev/null); then
  echo "ensure-github-pages-legacy-branch: no Pages site yet; creating legacy gh-pages / ..."
  gh api "repos/${REPO}/pages" --method POST --input - <<'JSON'
{
  "build_type": "legacy",
  "source": {
    "branch": "gh-pages",
    "path": "/"
  }
}
JSON
  echo "ensure-github-pages-legacy-branch: created."
  gh api "repos/${REPO}/pages/builds" --method POST >/dev/null 2>&1 || true
  exit 0
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "ensure-github-pages-legacy-branch: jq not found; cannot inspect Pages config." >&2
  exit 1
fi

bt=$(echo "$pages_json" | jq -r '.build_type // empty')
branch=$(echo "$pages_json" | jq -r '.source.branch // empty')
path=$(echo "$pages_json" | jq -r '.source.path // "/"')

if [[ "$bt" == "workflow" ]]; then
  echo "ensure-github-pages-legacy-branch: build_type=workflow; not changing."
  exit 0
fi

if [[ "$branch" == "gh-pages" && "$path" == "/" ]]; then
  echo "ensure-github-pages-legacy-branch: already gh-pages /"
  gh api "repos/${REPO}/pages/builds" --method POST >/dev/null 2>&1 || true
  exit 0
fi

echo "ensure-github-pages-legacy-branch: updating Pages source -> gh-pages / (was: ${branch} ${path})"
put_body="$(mktemp)"
trap 'rm -f "${put_body}"' EXIT
cat >"${put_body}" <<'JSON'
{
  "build_type": "legacy",
  "source": {
    "branch": "gh-pages",
    "path": "/"
  }
}
JSON
if ! put_out=$(gh api "repos/${REPO}/pages" --method PUT --input "${put_body}" 2>&1); then
  if echo "${put_out}" | grep -qE '403|Resource not accessible by integration'; then
    echo "ensure-github-pages-legacy-branch: Pages API PUT returned 403 (default GITHUB_TOKEN often cannot change Pages source). gh-pages push already ran; set repo Pages → branch gh-pages / manually if needed." >&2
    exit 0
  fi
  echo "${put_out}" >&2
  exit 1
fi
echo "ensure-github-pages-legacy-branch: updated."
gh api "repos/${REPO}/pages/builds" --method POST >/dev/null 2>&1 || true
