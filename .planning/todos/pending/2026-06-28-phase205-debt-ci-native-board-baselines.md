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

## 4. NOW BLOCKS Phase 208 (paused 2026-06-29)
Phase 208 Plan 02 (capture the 12 net-new `board-cfg-*` PNG baselines) is blocked on
exactly items #1 + #2 above: the board-cfg board code (`da980c7a`) is not on `origin/main`
(local `main` is 291 commits ahead), so the `admin_design_recapture` CI job cannot produce
the baselines, and darwin/local capture is forbidden (D-05, reverted at 43f5a3e4).

Phase 208 is **paused as tracked debt**: 208-01 is complete (audit: zero CSS gaps,
cite-and-flip); 208-02 + 208-03 remain incomplete.

**To unblock + resume:**
1. `git push origin main` (lands the board-cfg code + 291 commits on origin/main)
2. Wait for the `admin_design_recapture` CI job (~15 min); it opens a `recapture-admin-design` PR
3. Review the PR: exactly 12 `board-cfg-*` PNGs, no `board-cfg-org` (D-06), `board-mg-*` unchanged
   (Plan 01 verdict was "CSS edited: no"); confirm `board-notice` shows as *added* in the canary guard
4. Merge the PR into main
5. Resume: `/gsd-execute-phase 208` — re-runs 208-02 (now the 12 PNGs exist) and then 208-03 (ledger flip)
6. Move this todo to `.planning/todos/resolved/`
