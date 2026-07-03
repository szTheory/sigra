---
phase: 212-v1-42-integration-merge-canary-reconciliation-gate-the-perso
plan: "01"
subsystem: ci-snapshot-guards
tags:
  - ci
  - playwright
  - snapshot-canary
  - GATE-01
  - canary-reconciliation
dependency_graph:
  requires:
    - "origin/main as canary-guard base ref"
    - "ship branch WCAG-fixed canary bytes (c96749fa, blob 1f7aba5b)"
  provides:
    - "GATE-01 (D-04): both snapshot-canary-guard lanes exit 0 vs origin/main"
    - "impersonation-banner + board-notice canaries armed and byte-green"
    - "5 checkpoint + 14 design legit-drift slugs allowlisted-in-diff"
  affects:
    - "PR #63 fast_checks snapshot-drift steps (both lanes)"
    - "origin/main impersonation-banner mobile canary baseline (reconciled via PR #64)"
tech_stack:
  added: []
  patterns:
    - "Steady-state-empty allowlist: intended drifts declared in-diff, reset post-merge"
    - "Byte-only prerequisite recapture PR merged to origin/main to reconcile a non-allowlistable canary"
key_files:
  created: []
  modified:
    - "test/example/priv/playwright/snapshot-allowlist"
    - "test/example/priv/playwright/snapshot-allowlist-design"
decisions:
  - "D-02/D-15: 5 checkpoint slugs allowlisted (audit-explorer, user-audit, global-user-index, org-scoped-admin + user-sessions — user-sessions surfaced as added drift on clean checkout, so INCLUDED per D-15)"
  - "D-14: 15 design slugs allowlisted (4 board-cfg-* added + board-mg-1..11); board-notice canary never allowlisted"
  - "D-13 SUPERSEDED (human call 2026-07-02): the sanctioned admin_checkpoint_recapture job is mechanically infeasible against this topology (only triggers on push-to-main / v-tag which fires the whole non-PR suite; forks a 396-commit PR; origin/main is 396 commits behind the WCAG appearance so a self-consistent recapture PR is impossible). Reconciled instead via a byte-only prerequisite PR (#64) setting origin/main's impersonation-banner-mobile baseline to the reviewed WCAG bytes (c96749fa, blob 1f7aba5b) — canary stays ARMED, not waived/reverted/allowlisted."
metrics:
  completed: "2026-07-02T00:45:00Z"
  tasks_completed: 3
  tasks_total: 3
  files_changed: 2
status: complete
---

# Phase 212 Plan 01: GATE-01 Canary Reconciliation Summary

Closed GATE-01: both `snapshot-canary-guard.sh --base origin/main` lanes (checkpoint + design) now exit 0 on PR #63. The legit v1.41-backlog drifts are allowlisted in-diff, and the non-allowlistable `impersonation-banner` mobile canary was reconciled to `origin/main` via a byte-only prerequisite PR (#64) that preserves the Phase 204-03 WCAG contrast fix — the canary tripwire stays armed.

## Tasks Completed

| Task | Description | Commit / Action | Files |
|------|-------------|-----------------|-------|
| 1 | Declare legit v1.41-backlog drift slugs in both allowlists (D-02/D-14/D-15) | 6a3f5e19 | snapshot-allowlist (+5), snapshot-allowlist-design (+15) |
| 2 | Reconcile impersonation-banner canary (D-13, superseded → byte-only PR) | PR #64 admin-merged to origin/main | (origin/main baseline PNG) |
| 3 | Verify BOTH drift lanes exit 0 vs origin/main (D-04) | checkpoint-exit=0, design-exit=0 | (verification only) |

## What Was Built

**Task 1 — allowlists (commit 6a3f5e19):**
- `snapshot-allowlist` (checkpoint lane): `audit-explorer`, `user-audit`, `global-user-index`, `org-scoped-admin`, and `user-sessions`. Per D-15, `user-sessions` was verified on a clean checkout — it surfaces as an `added` drift (3 net-new PNGs absent from origin/main), so it was INCLUDED as the 5th slug. `impersonation-banner` deliberately absent (canary never allowlistable).
- `snapshot-allowlist-design` (design lane): `board-cfg-audit`, `board-cfg-overview`, `board-cfg-user-detail`, `board-cfg-users-list` (added) + `board-mg-1`..`board-mg-11` (modified). `board-notice` canary deliberately absent.

**Task 2 — canary reconciliation (PR #64):** See the D-13 deviation below. `origin/main`'s `impersonation-banner-admin-checkpoints-mobile.png` was advanced to the reviewed WCAG-fixed bytes (blob `1f7aba5b`, from `c96749fa`), so PR #63's canary diff reads byte-green.

**Task 3 — verification:** Both guard lanes run exactly as `fast_checks` invokes them:
- Checkpoint lane: `PASS (5 changed slug(s), all within allowlist)`, exit 0. Canary byte-green.
- Design lane: `PASS (14 changed slug(s), all within allowlist)`, exit 0. Canary byte-green. (14 of the 15 allowlisted slugs actually drifted; `board-mg-3` was byte-stable — allowlisting an unchanged slug is harmless.)

## Deviations from Plan

**D-13 mechanism superseded (human-ratified 2026-07-02).** The plan mandated reconciling the canary via the sanctioned `admin_checkpoint_recapture` CI job (recapture PR merged to origin/main first, gate = human visual review). Investigation during execution proved this mechanically infeasible against the real topology:
- The job only triggers on `push`-to-`main` (blocked — that's the gated merge), nightly `schedule` (runs on origin/main, which lacks the job), or `workflow_dispatch` on a `v*` tag (which fires the entire non-PR job suite and forks a 396-commit PR — not a focused recapture).
- `origin/main` is **396 commits behind** the demo-app CSS/brand state the WCAG canary appearance depends on, so a *self-consistent* recapture PR to origin/main is impossible until the backlog lands (cherry-picking `c96749fa` conflicts and still wouldn't render the WCAG appearance).

Resolution (ratified by developer): a **byte-only prerequisite PR (#64)** off origin/main setting the canary baseline to the reviewed WCAG bytes (`1f7aba5b`, already proven CI-valid — they pass `example_playwright_smoke`'s ubuntu re-render on PR #63), admin-merged (main ruleset requires `Example Playwright smoke`, which is intentionally red on #64 baseline-ahead-of-code and self-heals when #63 lands the CSS ~1 CI cycle later). This honors D-01/D-13's intent — canary stays **armed**, WCAG fix preserved, no waiver, no revert, not allowlisted — only the plumbing changed. Documented in PR #64's body and commit.

## Verification Results

```
bash scripts/ci/snapshot-canary-guard.sh --base origin/main
  → PASS (5 changed slug(s), all within allowlist); checkpoint-exit=0
SNAP_DIR=...admin-design... bash scripts/ci/snapshot-canary-guard.sh --base origin/main \
  --allowlist snapshot-allowlist-design --canary board-notice
  → PASS (14 changed slug(s), all within allowlist); design-exit=0
origin/main:impersonation-banner-...-mobile.png blob == local main blob (1f7aba5b) ✓
```

## Requirement Closure

- **GATE-01 CLOSED (D-04):** both `snapshot-canary-guard.sh --base origin/main` lanes exit 0. Both canaries armed and byte-green; all legit drifts allowlisted-in-diff; the impersonation-banner canary reconciled via merged PR #64 preserving the WCAG fix.

## Self-Check: PASSED

- [x] Both allowlists carry the declared slugs (commit 6a3f5e19); neither canary allowlisted
- [x] PR #64 merged to origin/main; origin/main canary blob == 1f7aba5b (WCAG-fixed)
- [x] Checkpoint lane exit 0; Design lane exit 0
- [x] D-13 deviation documented (byte-only PR, human-ratified)
