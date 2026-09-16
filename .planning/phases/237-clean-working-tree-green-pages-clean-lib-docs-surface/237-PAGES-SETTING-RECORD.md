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

## POST-CHANGE OBSERVATIONS

_Appended after the change is performed. See the section below._
