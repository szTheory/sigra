---
created: 2026-07-27T00:00:00.000Z
status: pending
title: "Playwright reports (GitHub Pages)" scheduled workflow is red (spec toBeVisible / element-not-found), reddens main history
area: ci
files:
  - .github/workflows/playwright-github-pages.yml
  - scripts/ci/assemble-playwright-gh-pages-site.sh
  - test/example/priv/playwright/tests
source: 2026-07-27 PR triage / green-main pass — found while diagnosing why main shows red
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
