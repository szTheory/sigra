---
created: 2026-07-04T00:00:00.000Z
status: pending
title: admin-eval render matrix — 16 first-navigation goto flakes inflate admin_eval_render wall-clock
area: testing
resolves_phase: 217
files:
  - test/example/priv/playwright/tests/admin-eval.spec.ts
source: Phase 216-09 committed-HEAD SC-5 re-verification run (orchestrator). Evidence: .planning/phases/216-harness-foundation-award-gradient/216-09-harness-evidence.log
---

## What

During the authoritative committed-HEAD harness run (216-09, HEAD ae78b94f), the
render matrix produced **16 flaky tests** — every one a first-navigation
`page.goto('/users/register' | '/admin/_design')` that exceeded the 15s
`waiting until "load"` timeout, then **passed on the warm retry in ~3s**.

It hit `loading`, `error`, AND `populated` boards indiscriminately across all 3
projects (admin-eval / -mobile / -dark), so it is a first-load timing / first-paint
issue (LiveView initial render + local resource contention), **not** a board-state
or code defect. Playwright's retries absorbed every one and the harness still exited
0 with all 5 guards green — so it does NOT gate merges (the `admin_eval_render` job
is separate and non-merge-blocking per JUDGE-CI-01).

## Why it matters

Non-blocking for correctness, but on a loaded machine several single hangs ran
16–18 min each (fixed per-test timeout), inflating the local wall-clock to hours.
In CI the `admin_eval_render` job would burn the same retry time. Worth hardening so
the render job is fast and deterministic.

## Suggested fix

- In `registerUser` / the `beforeEach` navigation, use `page.goto(url, { waitUntil:
  'domcontentloaded' })` instead of the default `'load'`, then an explicit
  LiveView-ready wait (`waitForLiveViewReady` already exists) rather than blocking on
  the full `load` event.
- Consider lowering the per-nav timeout so a stuck first-nav fails fast into its
  retry instead of hanging ~16 min.
- Verify the fix by re-running `scripts/ci/admin-eval-harness.sh` and confirming zero
  (or near-zero) `flaky` count.
