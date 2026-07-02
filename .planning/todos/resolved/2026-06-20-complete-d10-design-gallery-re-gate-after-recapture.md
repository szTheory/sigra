---
created: 2026-06-20T20:15:00.000Z
status: resolved
resolved_at: 2026-06-21
resolved_by: phase 198-02 (D-06 hard re-gate)
resolving_commit: 32d43bb5
title: Complete D-10 re-gate — remove design_gallery continue-on-error after ubuntu recapture lands
area: ci
files:
  - .github/workflows/ci.yml
source: phase 197 ship (v1.40) — bootstrap deadlock deferral; see 197-UAT.md Notes
---

## What

Phase 197 (D-10) hard-gated the `example_playwright_smoke` → `design_gallery`
step (removed `continue-on-error`). Shipping v1.40 surfaced a bootstrap
**deadlock**: the committed admin-design baselines are macOS-captured and
`playwright.config.ts` omits the OS suffix, so the very PR that delivers the
`admin_design_recapture` job cannot pass `design_gallery` on ubuntu — and
`Example Playwright smoke (full lifecycle)` is a REQUIRED merge check. Ubuntu
baselines only exist AFTER `admin_design_recapture` runs (push/schedule,
post-merge).

To ship v1.40, `continue-on-error: true` was **temporarily restored** on the
`design_gallery` step (`ci.yml` ~line 1044, marked `TEMP SOFT-GATE`).

## Sequence to complete D-10 (do these in order)

1. ✅ Merge the v1.40 ship PR (design_gallery soft) — fires `admin_design_recapture`
   on the push-to-main run.
2. ✅ Merge the `ci/recapture-admin-design-<run_id>` PR it opens (ubuntu-native
   PNGs land on `main`) — PR #60 / commit 9eed3474 merged 2026-06-19.
3. ✅ Open a follow-up PR that **removes the `TEMP SOFT-GATE` `continue-on-error: true`**
   from the `design_gallery` step (restoring the comment block to its pure
   HARD-GATING form). Confirm `design_gallery` runs **green** against the new
   ubuntu baselines and the aggregator hard-gates again.
   → Completed: phase 198-02 commit 32d43bb5 (2026-06-21).
4. ✅ Resume `/gsd-verify-work 197` → Test 1 (recapture PR) + Test 2 (hard gate
   green) can finally pass; phase 197 verification advances `human_needed` →
   `passed`.

## Why this is NOT a phase-197 regression

The re-gate mechanism is correct; only its *ordering relative to the first
ubuntu recapture* was wrong. The re-gate must land AFTER the ubuntu baselines
are on `main`, not in the same PR that introduces the recapture job.

## Resolution (2026-06-21 — Phase 198-02, D-06)

**All steps complete.** Phase 198-02 Task 2 (commit 32d43bb5) removed the
`TEMP SOFT-GATE continue-on-error: true` from the `design_gallery` step and
restored `steps.design_gallery.outcome` to the `Aggregate Playwright step outcomes`
loop. The design-gallery lane is now hard-gated again.

Confirmed green before re-gate (checkpoint verified):
- CI run 27884942846 (push) + 27895645329 (nightly): design-gallery / admin_design_recapture jobs = success
- snapshot-canary-guard.sh: 0 changed slugs
- OQ3 cross-lane: no pending oq3-cross-lane todo (clean)
