---
created: 2026-07-28T00:00:00.000Z
status: pending
title: "admin_eval_render burns ~17m on every PR to produce a red artifact that nothing reads, and its first-phase failure means the harness guards b1-b6 have never executed in CI"
area: ci
files:
  - .github/workflows/ci.yml
  - scripts/ci/admin-eval-harness.sh
  - test/example/priv/playwright/playwright.config.ts
  - test/example/priv/playwright/tests/admin-eval.spec.ts
severity: high
source: 2026-07-28 CI fan-out investigation that scoped the v1.47 CI-EFFICIENCY milestone
resolves_phase: 231
---

## What

`admin_eval_render` (`ci.yml:2102-2237`) runs on **every PR with no `if:` gate**, takes **~17m**,
and failed **6 of 6** sampled runs. Nothing consumes the result:

- it is `continue-on-error: true` (`ci.yml:2110`);
- it is **not** in `ci-gate.needs` (`ci.yml:1464-1473`);
- it is **not** one of the 5 required contexts in ruleset `14941512`;
- and there is **no `download-artifact` anywhere in the repo** that reads its bundles — they
  expire unread after 7 days.

So the repo pays ~17m of runner time per PR for output no human and no job ever sees.

## Evidence — two root causes

Both from job log `90369119561` (`76 failed, 116 passed (16.1m)`):

1. **Configuration bug.** The `admin-eval-mobile` project uses the `iPhone 13` device preset,
   which is **WebKit**, but the job installs **chromium only** (`ci.yml:2177-2179`, whose own
   step name asserts "admin-eval uses chromium" — factually wrong for one of the three projects
   it launches). All **64** `admin-eval-mobile` tests fail in ~2ms with
   `browserType.launch: Executable doesn't exist at /home/runner/.cache/ms-playwright/webkit-2272/pw_run.sh`,
   each retrying once, producing **128 failure lines**. Every other Playwright job in this repo
   installs `chromium webkit`.
2. **Probe bug.** `el.className.includes is not a function` — on an SVG element `className` is an
   `SVGAnimatedString`, not a string. It fires inside a `page.evaluate` on boards `board-mg-2`
   (all 4 states), `board-task_card`, `board-summary_chip`, `board-applied_chip`,
   `board-field_help`, `board-skeleton`, and `board-audit_row`.

## Why this is structural, not bad luck — the silent part

Because harness phase (a) fails under `set -euo pipefail`, `scripts/ci/admin-eval-harness.sh`
**aborts before phases (a2) and (b1)-(b6)**, so **those guards have never executed in CI** for as
long as this lane has been red.

Four of them — `quality-findings-monotonic.sh`, `award-guard.mjs`, `settled-findings-lint.sh`,
`evidence-anchor-check.mjs` — are independently wired into `fast_checks` and are green there, so
the real exposure is narrow but not zero: **`stale-render-guard.sh` runs nowhere else.**
`fast_checks` runs only that guard's *unit self-test* (`stale-render-guard.test.sh`,
`ci.yml:147-149`), never the guard itself; the sole real invocation is
`admin-eval-harness.sh:94`, which is downstream of the abort.

## Recommended fix (NOT implemented by this todo)

This todo records the diagnosis only. Nothing in `.github/` or `scripts/` was changed.

1. **Demote** the job to non-PR (nightly/main), removing ~17m from every PR.
2. **Then fix both bugs:** install `chromium webkit`, and read the class list via
   `getAttribute('class')` or `el.classList` rather than `className`.
3. **Confirm that phases b1-b6 actually run afterward** — in particular that
   `stale-render-guard.sh` executes and passes. Demoting without fixing leaves the only
   invocation of that guard permanently unreached.

Cross-reference the **v1.47 CI-EFFICIENCY** scope, where this is a locked demote-then-fix
decision, and the SEED-005 2026-07-28 addendum
(`.planning/seeds/SEED-005-ci-cd-pipeline-performance-audit.md`).
