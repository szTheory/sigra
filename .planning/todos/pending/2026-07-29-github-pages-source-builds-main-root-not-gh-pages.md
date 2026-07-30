---
created: 2026-07-29T00:00:00.000Z
status: pending
title: "GitHub Pages still builds main's repo root instead of the gh-pages publish branch — self-heal not yet observable pre-merge"
area: ci
files:
  - .github/workflows/playwright-github-pages.yml
  - scripts/ci/ensure-github-pages-legacy-branch.sh
severity: low
source: Phase 231 CONTEXT D-18 (owner-selected finding) + plan 231-10 Task 3 (live dispatch confirms the self-heal question is structurally unobservable before this phase's fix reaches main)
resolves_phase: 231
---

## What

`gh api repos/szTheory/sigra/pages` currently reports `source: {"branch": "main", "path": "/"}` —
GitHub Pages is building the repository root of `main` (rendering `AGENTS.md`, `CHANGELOG.md`,
`CLAUDE.md`, `brandbook/**` as a Jekyll site), not the `gh-pages` branch the
`playwright-github-pages.yml` publisher actually pushes reports to. `pages-build-deployment` has
failed on six consecutive pushes as a result (CONTEXT D-18: `30472014592`, `30466317343`,
`30461965393`, `30389698709`, `30387487782`, `30379433249`).

## Diagnosis

`scripts/ci/ensure-github-pages-legacy-branch.sh` is supposed to correct the Pages source to
`legacy` + `gh-pages` / after every successful publish, but two things had to both be true
before it could ever run once:

1. **D-17's fix (this phase, plan 231-10):** the publisher must produce a green
   `Publish Playwright site` job. It could not, because the workflow booted the example app
   without seeding it, so the checkpoint spec's pagination assertion failed daily. Fixed in
   this same plan (`Run demo seeds` step, guarded by `p15-pages-publisher-seeds-before-boot.test.mjs`).
2. **The `github.ref == 'refs/heads/main'` gate on both the `Publish to gh-pages branch` step
   and the downstream `Point GitHub Pages at gh-pages (REST API)` step** (the latter additionally
   requires `steps.gh_pages_push.outcome == 'success'`). Neither step can run on any ref other
   than `main`.

Those two conditions cannot both be satisfied from a phase branch before merge: `workflow_dispatch`
resolves the workflow definition from the dispatched ref, so dispatching from `main` would run
main's **pre-fix** copy (still missing the seeds step, still red at the same pagination
assertion — proving nothing new), while dispatching from the phase branch (to exercise the fix)
necessarily has `github.ref != 'refs/heads/main'`, which skips both the `gh-pages` push and the
ensure-script unconditionally, regardless of the job's own conclusion.

**Observed directly:** dispatched run `30529885885` (`workflow_dispatch`, ref
`worktree-discuss-231`, commit `8e9e7839`) concluded `success` — the checkpoint spec's
pagination assertion now passes in all three projects (chromium, mobile, dark), confirming
D-17's fix works. But `Publish to gh-pages branch` and `Point GitHub Pages at gh-pages (REST API)`
both concluded `skipped` on that run (job `90829454715`), exactly as this diagnosis predicts.
`ensure-github-pages-legacy-branch.sh` therefore still has never executed against a green
publish, and the live Pages source is unchanged (`branch: main, path: /`, re-confirmed
immediately after this run completed).

This is **not** a confirmed self-heal failure — the script has simply never had the
opportunity to run yet. It becomes observable at the first `push: main` (this phase's own PR
merge, since it touches `playwright-github-pages.yml` and matches that trigger's path filter)
or the next `schedule` run after merge (`45 6 * * *`), whichever comes first.

**Two candidate causes if it does not self-heal once it finally runs**, per D-18's original
framing — not yet distinguished:
1. The default `GITHUB_TOKEN`'s declared job permissions (`contents: write, pages: write`) are
   insufficient for the Pages REST API's `PUT /repos/{owner}/{repo}/pages` call. The script
   itself anticipates this (`ensure-github-pages-legacy-branch.sh:66-70`): a `403` /
   "Resource not accessible by integration" response is caught, logged, and the script exits 0
   without changing anything, non-fatally.
2. A Settings-level Pages configuration state that no workflow token, regardless of scope, can
   change via the REST API (would require a manual Settings → Pages change).

## Owner

Repo admin (`szTheory`) — this is explicitly fenced out of Phase 231's scope by CONTEXT D-18:
"in scope only insofar as D-17's fix lets that script finally run... do NOT expand the phase
into a repo-admin Pages reconfiguration." In the same human-gated class as the deferred Hex
retire (`.planning/todos/pending/2026-07-03-hex-retire-stray-1-20-0.md`).

## Suggested verification (post-merge)

1. After this phase's PR merges to `main`, watch the resulting `push`-triggered
   `Playwright reports (GitHub Pages)` run (or the next `45 6 * * *` scheduled run).
2. `gh run view <id> --json jobs -q '.jobs[] | {name, conclusion}'` — confirm `Publish to
   gh-pages branch` and `Point GitHub Pages at gh-pages (REST API)` are no longer `skipped`.
3. Read the `Point GitHub Pages at gh-pages (REST API)` step's log for
   `ensure-github-pages-legacy-branch: updated.` (success) vs the `403` warning path.
4. `gh api repos/szTheory/sigra/pages --jq '.source'` — if it now reads
   `{"branch": "gh-pages", "path": "/"}`, close this todo. If it still reads `main` / `/`, the
   candidate cause is narrowed by whichever log line appeared in step 3, and a manual
   Settings → Pages → Build and deployment → Branch change becomes the fix.
