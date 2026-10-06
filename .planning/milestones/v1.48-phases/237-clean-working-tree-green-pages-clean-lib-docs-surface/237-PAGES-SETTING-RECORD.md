---
phase: 237-clean-working-tree-green-pages-clean-lib-docs-surface
plan: 02
requirement: GREEN-03
decision: D-07
kind: outward-facing-settings-change-record
---

# GitHub Pages source change — pre-change record and revert value

This file exists so the Pages settings change performed by plan `237-02` is reversible by a
**recorded, known value** rather than by a reconstruction. It is committed **before** the change
is performed.

The change itself is authorized by `237-CONTEXT.md` **D-07**: GitHub Pages is repointed from the
default branch (`main`) to the existing dedicated publish branch (`gh-pages`), because pointing
the legacy Jekyll builder at the source repository root is the root cause of eight consecutive
`pages build and deployment` failures — and because the rejected alternative (adding a root
`.nojekyll` to `main`) would publish the entire repository root, including agent-instruction
files, the brand book and the planning directory, as a public static site.

## What the site serves after the change

`.github/workflows/playwright-github-pages.yml` (job `Publish Playwright site`) assembles a
static Playwright report site into `_sigra_playwright_site` and force-publishes it to the
`gh-pages` branch on every green `push: main` / scheduled run. That branch root already contains
`.nojekyll`, `index.html` and `runs/` — so after the repoint, `https://sztheory.github.io/sigra/`
serves the Playwright report index that the publisher was always designed to serve, and the
legacy Jekyll builder never parses repository guides at all.

## PRE-CHANGE STATE — the value to revert to

Captured live at **2026-09-16T13:08:27Z**, before any mutation, with:

```bash
gh api repos/szTheory/sigra/pages
```

Full response payload, verbatim:

```json
{
    "url": "https://api.github.com/repos/szTheory/sigra/pages",
    "status": "errored",
    "cname": null,
    "custom_404": false,
    "html_url": "https://sztheory.github.io/sigra/",
    "build_type": "legacy",
    "source": {
        "branch": "main",
        "path": "/"
    },
    "public": true,
    "protected_domain_state": null,
    "pending_domain_unverified_at": null,
    "https_enforced": true
}
```

Note `"status": "errored"` — that is the red state this plan exists to clear, and it is part of
the recorded prior state rather than something the revert would need to reproduce deliberately.

### Literal revert command

Running this single command restores the exact `build_type` + `source` pair recorded above:

```bash
gh api repos/szTheory/sigra/pages --method PUT --input - <<<'{"build_type":"legacy","source":{"branch":"main","path":"/"}}'
```

Equivalent UI path: **Settings → Pages → Build and deployment → Branch → `main` / `(root)`**.

Reverting restores the broken state on purpose; it is recorded only so the change is not a
one-way door.

## History — why the workflow could not do this itself

`scripts/ci/ensure-github-pages-legacy-branch.sh` already attempts exactly this PUT after every
successful publish, but the Actions default token cannot perform it. From the first post-merge
scheduled publisher run (`30613728531`), step `Point GitHub Pages at gh-pages (REST API)`:

```text
ensure-github-pages-legacy-branch: updating Pages source -> gh-pages / (was: main /)
ensure-github-pages-legacy-branch: Pages API PUT returned 403 (default GITHUB_TOKEN often cannot change Pages source). gh-pages push already ran; set repo Pages → branch gh-pages / manually if needed.
```

The script **swallows that 403 and exits 0**, so the workflow reported success while the site
stayed broken. Repairing that swallowed 403 to fail loudly, and closing the related issue and
todo, are fenced to **Phase 240 (GREEN-05)** and are deliberately not touched here.

## THE CHANGE

Performed at **2026-09-16T13:09:13Z**, after the pre-change record above was committed
(`06169df2`):

```bash
gh api repos/szTheory/sigra/pages --method PUT --input - <<<'{"build_type":"legacy","source":{"branch":"gh-pages","path":"/"}}'
```

Result: **HTTP 204, no response body** (exit 0). No 403 — the local `gh` token, which
authenticates with repository `admin: true`, can perform what the Actions default token could
not.

A build was then requested explicitly:

```bash
gh api repos/szTheory/sigra/pages/builds --method POST
# 2026-09-16T13:09:36Z -> {"status":"queued","url":"…/pages/builds/latest"}
```

## POST-CHANGE OBSERVATIONS

Two independent live observations. Neither is the PUT's own response body — the PUT returned no
body at all, and would not have been acceptable evidence if it had.

### Observation 1 — live API read-back (`gh api`, not the PUT echo)

```bash
gh api repos/szTheory/sigra/pages --jq '{status,build_type,source}'
# 2026-09-16T13:11:21Z
{"build_type":"legacy","source":{"branch":"gh-pages","path":"/"},"status":"built"}
```

Status polling (up to 60 × 10s; `built` passes, `building`/`null` keeps polling, anything else
fails immediately) **settled on the first iteration**: the site reported `built`, not the prior
`errored`.

The build record for the explicitly-requested build confirms it completed cleanly with no error:

```bash
gh api repos/szTheory/sigra/pages/builds/latest --jq '{status,error,commit,created_at,updated_at,duration}'
{"commit":"29e6ad40bf3e892d7582e7c07ed1fa7cc7910ec1","created_at":"2026-09-16T13:09:38Z",
 "duration":25514,"error":{"message":null},"status":"built","updated_at":"2026-09-16T13:10:03Z"}
```

`commit` is a `gh-pages` tip, not a `main` commit — the builder is now sourcing the publish
branch.

### Observation 2 — real HTTP fetch of the published URL

```bash
curl -sSI https://sztheory.github.io/sigra/ | head -6
# 2026-09-16T13:11:03Z
HTTP/2 200
server: GitHub.com
content-type: text/html; charset=utf-8
last-modified: Wed, 16 Sep 2026 13:10:03 GMT
```

`last-modified` equals the build's `updated_at` exactly, so the bytes being served are the output
of the build observed above, not a stale cached artifact.

The 2xx assertion was run with a negative control in the same block, so the "it returned 2xx"
result is not an artifact of a check that cannot fail:

```bash
curl -sS -o /dev/null -w "%{http_code}" https://sztheory.github.io/sigra/ | grep -Eqx "2[0-9][0-9]"
# exit 0
curl -sS -o /dev/null -w "%{http_code}" https://sztheory.github.io/sigra/__definitely_not_a_real_path__ | grep -Eqx "2[0-9][0-9]"
# exit 1  <- control: the check does discriminate
```

### Prohibitions re-checked after the change

| Prohibition | Check | Result |
|---|---|---|
| No root Jekyll-bypass marker on the default branch | `git ls-files '.nojekyll' ':(glob)*.nojekyll'` (control: `git ls-files 'CLAUDE.md'` → `CLAUDE.md`, so the search ran) | no output — none exists |
| Publisher script untouched | `git diff --exit-code "$(git merge-base origin/main HEAD)" HEAD -- ":/scripts/ci/ensure-github-pages-legacy-branch.sh"` | exit 0 — byte-unchanged |
| Related issue stays open for Phase 240 | `gh issue view 231 --json state` | `OPEN` |

The pending todo `.planning/todos/pending/2026-07-29-github-pages-source-builds-main-root-not-gh-pages.md`
is likewise left in place. Its "Required owner action" is now performed, but moving or closing it
belongs to Phase 240 (GREEN-05) along with the swallowed-403 repair.
