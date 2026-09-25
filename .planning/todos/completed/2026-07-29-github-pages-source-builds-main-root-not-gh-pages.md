---
created: 2026-07-29T00:00:00.000Z
status: completed
title: "GitHub Pages still builds main's repo root instead of the gh-pages publish branch — workflow token receives 403"
area: ci
files:

  - .github/workflows/playwright-github-pages.yml
  - scripts/ci/ensure-github-pages-legacy-branch.sh

severity: low
source: Phase 231 CONTEXT D-18 (owner-selected finding) + plan 231-10 Task 3 (live dispatch confirms the self-heal question is structurally unobservable before this phase's fix reaches main)
resolves_phase: 237
audit_acknowledged:
  milestone: v1.47
  at: 2026-09-15
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

## Post-merge verification (2026-07-31)

The first post-merge scheduled publisher run, `30613728531`, used merge SHA
`4bba9c71ae95a51bc2c3586010518a1c3439ab5f` and concluded `success`. Its `Publish Playwright
site` job executed all of the previously-unobservable steps:

- `Run demo seeds`: `success`
- `Publish to gh-pages branch`: `success` (force-pushed deploy commit `a8df83a`)
- `Point GitHub Pages at gh-pages (REST API)`: `success` at the step level because the script's
  expected permission failure is non-fatal

The step log identifies the operative cause precisely:

```text
ensure-github-pages-legacy-branch: updating Pages source -> gh-pages / (was: main /)
ensure-github-pages-legacy-branch: Pages API PUT returned 403 (default GITHUB_TOKEN often cannot change Pages source). gh-pages push already ran; set repo Pages → branch gh-pages / manually if needed.
```

The live Pages API still reports `source: {"branch":"main","path":"/"}` and `status: errored`.
Candidate cause 1 is therefore confirmed: the workflow's default token cannot perform the source
update. A repo admin must set Settings → Pages → Build and deployment → Branch to `gh-pages` /.

## Owner

Repo admin (`szTheory`) — this is explicitly fenced out of Phase 231's scope by CONTEXT D-18:
"in scope only insofar as D-17's fix lets that script finally run... do NOT expand the phase
into a repo-admin Pages reconfiguration." In the same human-gated class as the deferred Hex
retire (`.planning/todos/pending/2026-07-03-hex-retire-stray-1-20-0.md`).

## Required owner action

1. In repository Settings → Pages → Build and deployment, select branch `gh-pages` and path `/`.
2. Confirm `gh api repos/szTheory/sigra/pages --jq '.source'` returns
   `{"branch":"gh-pages","path":"/"}`.
3. Trigger or await the next Pages build, confirm the deployment succeeds, then move this todo to
   `resolved/` with the run ID and final API response.

## Owner action confirmed done — 2026-09-18 (Phase 240, plan 240-05)

`gh api repos/szTheory/sigra/pages`, re-read live at issue-#231 closure time:

```json
{"url":"https://api.github.com/repos/szTheory/sigra/pages","status":"built","cname":null,"custom_404":false,"html_url":"https://sztheory.github.io/sigra/","build_type":"legacy","source":{"branch":"gh-pages","path":"/"},"public":true,"protected_domain_state":null,"pending_domain_unverified_at":null,"https_enforced":true}
```

`source` is now `{"branch":"gh-pages","path":"/"}` and `status` is `built` — not the
`{"branch":"main","path":"/"}` / `errored` recorded in the 2026-07-31 post-merge verification
above. Steps 1 and 2 of **Required owner action** are therefore satisfied: the repo admin has set
Settings → Pages → Build and deployment to branch `gh-pages`, path `/`, and the site builds. This
is a point-in-time read and expires; re-read it rather than quoting this block later.

**Frontmatter correction.** Phase 237 moved this file into `.planning/todos/completed/` without
updating its `status:` field, which still read `pending` at line 3 until this append. It now reads
`completed`. Per Phase 240 **D-25** this closure is a verification plus evidence-append **in
place** — the file was already under `completed/`, so no move was performed and none was needed.

**The publisher can no longer report success while the site stays broken.** The half of this todo
that was ours rather than the repo admin's — a script that swallowed the failure it was supposed
to surface — is fixed. `scripts/ci/ensure-github-pages-legacy-branch.sh` previously treated any
failure of `GET /repos/{repo}/pages` as "no Pages site configured" and fell through to the create
arm, and matched the PUT-side 403 with an unanchored regex that could match a bare `403` anywhere
in an unrelated error body. It now exits `1`, naming the status, on every non-2xx Pages response
except the one documented case where the workflow's `pages: write` token is not repo-admin and the
PUT legitimately 403s — that single arm stays tolerable and is commented as such
(`ensure-github-pages-legacy-branch.sh:139-145`). Four stubbed RED transcripts —
`FAKE_MODE=get_403`, `FAKE_MODE=get_500`, `FAKE_MODE=put_422`, `FAKE_MODE=put_500`, each exiting
`1` — are recorded in `240-01-SUMMARY.md` and in the `AFTER-PAGES-LOUD-RED` slot of
`.planning/phases/240-green-main-evidence-honest-pages-script/240-EVIDENCE.md`. The `get_500` body
carries the bare digits `403` twice, once in the request id and once in the message; the old
unanchored match would have read it as "expected 403, carry on".

The script's hermetic self-test (`scripts/ci/ensure-github-pages-legacy-branch.test.sh`) is wired
into `fast_checks` as the step `Pages legacy-branch script self-test`, green on PR run
`35376244993` and on the `main` push run `35377012499` at HEAD `abec92c4`.
