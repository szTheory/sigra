---
created: 2026-06-18
source: phase-192 independent GATE-01 verification (orchestrator re-run)
severity: blocker-for-gate-01-ratification
scope: pre-existing (NOT caused by phase 192)
area: test/example admin-design Playwright
---

# admin-design.spec.ts:601 "help states open and close with Escape" fails in compare-mode

## What

An independent live-server run of the 6 admin Playwright projects (compare mode, no
`--update-snapshots`) during phase 192 terminal-ratification verification produced
**104 passed / 1 failed** (exit non-zero), NOT the 105-passed/exit-0 result the 192-04
executor self-reported.

- Failing test: `test/example/priv/playwright/tests/admin-design.spec.ts:601`
  — "help states open and close with Escape without trapping focus" (admin-design-chromium).
- Assertion: after pressing `Escape`, `#board-summary_chip [data-sg-metric-help-root]`
  still has `data-help-open="true"` and the panel stays visible.
- The field-help half of the same test passes; only the metric-help half fails.
- Snapshot drift was ZERO (both snapshot dirs clean) — the idempotency-of-baselines
  property holds; this is a behavior failure, not a snapshot regression.
- MG-5/6 quarantine (`test.fail()`) behaved correctly (expected-failure, did not count).

## Provenance (why this is NOT a phase-192 defect)

- Phase 192's only edits to `admin-design.spec.ts` were axe-tag widening (192-01) and the
  MG-5/6 `test.fail()` (192-02). The line-601 test predates 192 (last structural touches
  187-05 / 188-05).
- `test/example/assets/js/admin_hooks.js` (metric-help focus/Escape model) was last touched
  in phase 190-01; the served `priv/static/assets/js/app.js` was propagated in the same 190
  window. Source and served both contain the `closeRootWhenIdle` / `closeAll(null)` Escape
  handler — so this is NOT the "stale served bundle" drift hazard.
- Root cause (per independent run): focus-to-open model — root has `tabindex=0`, `focusin`
  opens it; Escape calls `closeAll(null)` but focus remains on the root, so the panel
  re-opens / stays open. Likely focus/timing-sensitive (executor's full-suite run passed it;
  isolated rerun fails deterministically).

## Why it matters

GATE-01 requires the 6 admin Playwright projects to pass compare-mode with exit 0. The
192-04 ledger "Terminal Ratification" note claims this. The independent run contradicts the
exit-0 claim, so the ratification cannot be honestly asserted until this is resolved.

## Fix direction (options, to be decided)

1. Investigate/fix the metric-help Escape behavior in `admin_hooks.js` (and re-propagate to
   served `app.js`) so the test passes — the clean fix if the behavior is genuinely wrong.
2. If the test itself encodes an incorrect expectation of the focus-to-open model, fix the
   test.
3. If it is an intractable focus/headless-timing flake, quarantine it consistently with the
   D-11/D-12 executable-quarantine pattern this phase established (NOT to be done silently
   just to green the gate).

Do NOT close GATE-01 ratification as fully proven until one of the above lands and an
independent compare-mode run exits 0.
