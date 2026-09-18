#!/usr/bin/env bash
# Create or update GitHub Pages to publish from branch gh-pages at / (legacy).
# Run from Actions after gh-pages exists so Settings → Pages does not need a
# manual branch pick the first time.
#
# Env: GITHUB_REPOSITORY=owner/name, GH_TOKEN or GITHUB_TOKEN (pages:write).
# Skips if build_type is already workflow (Actions-sourced Pages).
#
# ---------------------------------------------------------------------------
# SC-3 ↔ D-19 reconciliation (Phase 240 / GREEN-05). Read this before changing
# the error posture below, or the implementation will look like it contradicts
# its own success criterion.
#
# ROADMAP SC-3 says this script must "fail loudly on a 403". D-19 keeps the
# **PUT**-403 tolerable. Both are right about different things. SC-3's real
# defect is that a 403 was **indistinguishable from every other failure** — the
# same grep arm swallowed a 500, a 422, a rate limit and a network blip. The
# fix makes the PUT-403 a single named, commented arm (justified: the caller
# declares `pages: write`, not repo-admin, at playwright-github-pages.yml:36-38)
# and makes **every other status** exit 1. The RED demonstration SC-3 asks for
# is therefore the `*)` arm firing on a 500/422, **plus** the GET-side 403 now
# exiting 1 instead of silently POST-creating — not the PUT-403 path.
#
# Response-shape source of truth: `240-RESEARCH.md §4` records the live-probed
# `gh api -i` behaviour at gh 2.95.0 (status line as stdout line 1 with the
# wire version literally `HTTP/2.0`; headers; a blank line; the JSON body on
# stdout; `gh: <msg> (HTTP <code>)` on stderr; exit 1 for ANY HTTP failure).
# There is no in-repo analog for that idiom — `grep -rn 'gh api -i' scripts/`
# returned nothing when this was written. The hermetic proof of every arm below
# lives in the sibling `ensure-github-pages-legacy-branch.test.sh`.
# ---------------------------------------------------------------------------

set -euo pipefail

REPO="${GITHUB_REPOSITORY:?GITHUB_REPOSITORY is required}"
export GH_TOKEN="${GH_TOKEN:-${GITHUB_TOKEN:-}}"
# D-22: no credential is not a failure -- the publisher must not redden for a
# reason unrelated to the diff.
if [[ -z "${GH_TOKEN}" ]]; then
  echo "ensure-github-pages-legacy-branch: no GH_TOKEN/GITHUB_TOKEN; skip."
  exit 0
fi

# D-16: on a PUBLIC repo GET /pages needs no admin, so 404 genuinely means
# "no Pages site configured" -- GitHub's 404-masking-403 policy covers private
# resources only. Live-probed across 8 public repos (240-RESEARCH.md §4):
# microsoft/TypeScript, rust-lang/rust and github/docs answer 404, while
# elixir-lang, phoenixframework/phoenix, twbs/bootstrap, facebook/react and
# jekyll/jekyll answer 200 to a non-admin prober.
# D-15: anything that is neither 200 nor 404 is a real failure and must be
# loud. The prior `if ! pages_json=$(gh api ... 2>/dev/null)` form treated
# 403/422/500/rate-limit/network-blip alike as "no site yet" and fell through
# to POST-create. `gh` exits 1 for every HTTP failure, so rc cannot
# discriminate; only the status line can.
get_out="$(gh api -i "repos/${REPO}/pages" 2>/dev/null || true)"
get_status="$(printf '%s' "${get_out}" | head -n 1 | awk '{print $2}')"
case "${get_status}" in
  200)
    # Split the body off after the header separator, tolerating a \r-terminated
    # blank line.
    pages_json="$(printf '%s' "${get_out}" | sed -n '/^\r\{0,1\}$/,$p' | tail -n +2)"
    ;;
  404)
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
    # D-22: build-trigger swallow #1 of 3 -- reddening the publisher on a
    # transient build-trigger failure is the opposite of this milestone's "no
    # red for a reason unrelated to the diff" posture, so all three stay
    # lenient. (CONTEXT D-22 cites :31/:52 for the first two; those are the
    # `exit 0` lines that follow -- the actual swallows were :30, :50 and :75
    # in the pre-rewrite file.)
    gh api "repos/${REPO}/pages/builds" --method POST >/dev/null 2>&1 || true
    exit 0
    ;;
  *)
    # An empty status means gh itself never ran: fail closed, never guess.
    echo "ensure-github-pages-legacy-branch: GET /pages returned '${get_status:-<no status line>}'; refusing to guess." >&2
    printf '%s\n' "${get_out}" >&2
    exit 1
    ;;
esac

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
  # D-22: build-trigger swallow #2 -- see the note at the create arm.
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
# D-18: `-i` is required, not stylistic -- a successful PUT /pages returns
# 204 No Content with an EMPTY body, so the status line is the only signal and
# there is no JSON to parse; `--jq` is bypassed entirely on an error response.
# `gh` exits 1 for ANY HTTP failure, so rc cannot discriminate 403 from 422
# from 500. D-17: the prior form captured `2>&1` into one blob and tested it
# with an unanchored regex for a bare 403, which matches inside a
# documentation_url, a request id, a rate-limit number or a 500 body --
# swallowing genuine unrelated failures as "expected 403, carry on".
put_out="$(gh api -i "repos/${REPO}/pages" --method PUT --input "${put_body}" 2>/dev/null || true)"
put_status="$(printf '%s' "${put_out}" | head -n 1 | awk '{print $2}')"
case "${put_status}" in
  204|200)
    echo "ensure-github-pages-legacy-branch: updated."
    ;;
  403)
    # D-19: the caller declares permissions {contents: write, pages: write}
    # (playwright-github-pages.yml:36-38). `pages: write` permits REQUESTING a
    # build but is not repo-admin, which is why a settings-source PUT
    # legitimately 403s. This one status stays tolerable; every other status is
    # now loud.
    echo "ensure-github-pages-legacy-branch: Pages API PUT returned 403 (pages:write is not repo-admin). gh-pages push already ran; set Settings → Pages → branch gh-pages path / manually if needed." >&2
    exit 0
    ;;
  *)
    # An empty status means gh itself never ran: fail closed, never guess.
    echo "ensure-github-pages-legacy-branch: PUT /pages returned '${put_status:-<no status line>}'." >&2
    printf '%s\n' "${put_out}" >&2
    exit 1
    ;;
esac
# D-22: build-trigger swallow #3 -- see the note at the create arm.
gh api "repos/${REPO}/pages/builds" --method POST >/dev/null 2>&1 || true
