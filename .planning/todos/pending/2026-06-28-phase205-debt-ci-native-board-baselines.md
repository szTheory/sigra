---
created: 2026-06-28
source: phase 206 execution (206-03 remediation)
kind: debt
area: admin-design playwright baselines / CI
resolves_phase:
priority: high
---

# Phase 205 debt: CI-native board-* baselines + branch divergence

Surfaced while executing Phase 206 (206-03). None of this is Phase 206's scope —
the Phase 206 CSS change (`.sg-btn--danger.is-armed` token swap) renders on zero
design-gallery boards. Captured here so it is not lost.

## 1. Missing `board-cfg-*` baselines (Phase 205)
Phase 205 (commits 4ca6e537 / da980c7a) added 4 `board-cfg-*` page-composite boards
to `design_gallery_live.ex` + registered them in `admin-design.spec.ts`, but never
committed initial PNG baselines. The 206-03 executor tried to fill them by capturing
on **darwin** — reverted (43f5a3e4) because committed baselines must be **ubuntu/CI-native**.

**Fix:** generate the 12 `board-cfg-{overview,users-list,user-detail,audit}` ×
{chromium,mobile,dark} baselines via the dedicated `admin_design_recapture` CI job
(ci.yml:1379), not locally. The hard-gating `design_gallery` PR job (ci.yml:1044) will
otherwise fail on missing snapshots.

## 2. Local `main` is behind `origin/main` (#58–#60)
Local `main` forked before three merged PRs:
- #58 `36a04b90` v1.40 CI-PERF (partial)
- #59 `ee911ea4` SEED-005 CI/CD perf audit
- #60 `9eed3474` ci: recapture admin-design baselines in ubuntu CI

Consequence: `board-mg-{1,2,5}` baselines on this branch are older than origin/main's
ubuntu recaptures (9 PNGs differ vs origin/main, untouched by Phase 206). A PR from this
branch could fail the gallery gate on mg-1/2/5 until reconciled.

**Fix:** merge/rebase `origin/main` into this work before opening the PR (pulls #58–#60,
including the current ubuntu board-mg-1/2/5 baselines). Defer until Phase 206 work is
complete to avoid mid-execution conflicts (v1.40 CI-PERF is a large change set).

## 3. ~12 Phase-205 behavioral (non-snapshot) Playwright failures
The 206-03 executor noted ~12 behavioral failures introduced by Phase 205 (e.g.
`board-cfg-audit` table overflow at 320px, a filter-form GET test, MG-5/6 equivalence,
group-boards catalog). Out of scope for Phase 206. Triage under Phase 205/207.

## 4. NOW BLOCKS Phase 208 (paused 2026-06-29) — the blocker is bigger than a push

Phase 208 Plan 02 (capture the 12 net-new `board-cfg-*` PNG baselines) is blocked.
Phase 208 is **paused as tracked debt**: 208-01 is complete (audit: zero CSS gaps,
cite-and-flip); 208-02 + 208-03 remain incomplete.

### The real constraints (investigated 2026-06-29 — supersedes any "just push main" note)

- **`origin/main` is PR-protected** (ruleset 14941512): direct push is rejected (GH013).
  5 required status checks gate every merge, including **"Example Playwright smoke
  (full lifecycle)"** — the job that runs the hard-gating `design_gallery` step.
- **`admin_design_recapture` never runs on PRs** — `if: github.event_name != 'pull_request'`
  (ci.yml:1389). It runs only on push-to-main, the nightly `schedule`, or
  `workflow_dispatch` **from a `v*` tag** (`release_ref_guard` blocks any other dispatch
  ref; this is why `gh workflow run "CI" --ref main` red-fails in ~3 min).
- **Chicken-and-egg:** a PR adding the board-cfg code fails `design_gallery` on the
  *missing* board-cfg snapshots → required check red → cannot merge. But the snapshots can
  only be produced by `admin_design_recapture`, which only runs against code already on
  main (or a `v*` tag). Darwin/local capture is forbidden (D-05, reverted at 43f5a3e4).
- **Root cause is the un-shipped backlog:** local `main` is ~291 commits / 9 days ahead of
  `origin/main` (v1.38–v1.42). Scheduled CI on origin/main is already failing nightly.
  Shipping that backlog through branch protection is a strategic effort in its own right.
- **`v*` tagging is discouraged** by project policy (Hex version-collision risk; "default
  to NOT tagging at close"), which rules out the otherwise-obvious tag→dispatch escape.

### Decision (2026-06-29)
Per Jon: keep 208 paused; **tackle the 291-commit backlog migration as its own piece of
work**, not inside phase 208. Candidate approaches to evaluate when picked up:
  (a) milestone PR for the backlog + a baseline-bootstrap sequence, or
  (b) a controlled, reviewable CI change allowing a branch-ref `workflow_dispatch` of
      `admin_design_recapture` (no `v*` tag) so recapture can run against a feature branch
      and open a baselines PR.

### To resume Phase 208 (after the backlog + baselines are on origin/main)
- `/gsd-execute-phase 208` — re-runs 208-02 (the 12 board-cfg PNGs now exist) and then
  208-03 (ledger flip), then phase verification.
- Move this todo to `.planning/todos/resolved/`.
