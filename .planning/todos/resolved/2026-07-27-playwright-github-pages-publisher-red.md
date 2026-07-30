---
created: 2026-07-27T00:00:00.000Z
status: resolved
resolved: 2026-07-30T00:00:00.000Z
resolved_by: phase-231-10
title: "Playwright reports (GitHub Pages)" scheduled workflow is red (spec toBeVisible / element-not-found), reddens main history
area: ci
files:
  - .github/workflows/playwright-github-pages.yml
  - scripts/ci/assemble-playwright-gh-pages-site.sh
  - test/example/priv/playwright/tests
source: 2026-07-27 PR triage / green-main pass — found while diagnosing why main shows red
resolves_phase: 231
---

## What

The scheduled `Playwright reports (GitHub Pages)` workflow (cron `45 6 * * *`,
`playwright-github-pages.yml`) has its single `Publish Playwright site` job failing
daily. This is **separate** from the main `CI` workflow (it is a cosmetic HTML-report
publisher to the `gh-pages` branch, not a merge gate), but it still shows up as a red
run on `main` and contributed to the "is main broken?" confusion during the 2026-07-27
triage pass.

## Root cause (partial — needs confirmation)

The publisher first runs a Playwright spec (checkpoint/generated lanes) to produce the
reports. In run `30248030952` that spec step exited 1 with repeated:

```
Error: expect(locator).toBeVisible() failed
Error: element(s) not found
```

Unlike the admin-eval boot flake (fixed in the green-main pass — that was
`ERR_CONNECTION_REFUSED` from a compile-env `PORT` mismatch), here the app booted and
tests ran; some `toBeVisible` assertions genuinely failed with "element(s) not found."
That points at **real spec drift** — the published lane asserts DOM that no longer
renders (likely demo/admin surface changes that landed without updating this lane's
selectors). The site-assembly step still runs (`if: always()`-style) and writes the
61M site, so the artifact is produced; the job is red purely because the test step
exited 1.

## Fix direction (to confirm)

1. Pull the failing job log for the latest run and identify WHICH spec + which
   `toBeVisible` selectors fail (`gh run view <id> --log`).
2. Decide per selector: real drift (update the spec/selector to match current DOM) vs.
   flake (stabilize the wait).
3. Consider whether the publisher should hard-fail on spec failure at all — its job is
   to *publish reports*, and a failing spec is exactly what you'd want to see published.
   Option: let the test step be advisory (`continue-on-error`) so the site still
   publishes and the job goes green, mirroring the admin-eval `continue-on-error`
   reclassification — the report itself carries the red test detail.

## Scope

CI-only / cosmetic publisher. Not a merge gate, does not block PRs. Low urgency but
worth closing so `main`'s run history is clean. Pairs with the green-main triage
(2026-07-27) that fixed the `CI` workflow's advisory admin-eval lane.

## Resolution (2026-07-30, Phase 231 plan 231-10, D-17)

This todo's stated hypothesis was **wrong**. The failure was never real spec drift, and
the `continue-on-error` option floated above was correctly never applied — it would have
been both unnecessary and forbidden (230's D-15 posture: never mask a red, fix the cause
or file it with a diagnosis).

**Actual root cause:** `playwright-github-pages.yml` set up the dev DB (`Setup example
dev DB`) and then went straight into `Boot example app in background` with **no
demo-seeds step**, while all four example-booting jobs in `ci.yml` (`:1288`, `:1950`,
`:2258`, `:2506`) run one, seeding roughly thirty loadtest users. Without those seeded
users the admin users index never paginates, so the checkpoint spec's
`getByRole('link', { name: 'Next page' })` assertion never finds an element to become
visible — which is precisely the `toBeVisible` / "element(s) not found" failure this
todo originally observed, and precisely how scheduled run `30432494488` failed, in all
three checkpoint projects (`admin-checkpoints-chromium`, `admin-checkpoints-mobile`,
`admin-checkpoints-dark`), at `test/example/priv/playwright/tests/admin-checkpoints.spec.ts:230`.

**Fix:** a `Run demo seeds` step, copied from the `admin_eval_render` block at
`ci.yml:2506-2513` (the one seeds copy in the repo that carries no `docs_only` guard —
this workflow has no `changes` job, so a docs-only-guarded copy would have evaluated
empty and silently never run), inserted unconditionally between `Setup example dev DB`
and `Boot example app in background`. Guarded by
`scripts/ci/prohibitions/p15-pages-publisher-seeds-before-boot.test.mjs`, so the
regression cannot silently return.

The GitHub Pages source-building question this todo did not raise (D-18: whether
`ensure-github-pages-legacy-branch.sh` can finally run after this fix, and whether Pages
self-heals off `main`'s repo root) is tracked separately by Task 3 of the same plan, not
folded into this todo.
