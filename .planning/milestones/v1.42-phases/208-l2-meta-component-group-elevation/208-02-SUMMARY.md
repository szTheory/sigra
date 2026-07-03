---
phase: "208"
plan: "02"
subsystem: admin-design-system
tags: [admin-ui, playwright, ci-native, board-cfg, baseline-capture, design-gallery]
dependency_graph:
  requires:
    - phase: "208-01"
      provides: "CSS edited: no verdict — zero sg-* gaps, no board-mg-* recapture required; only 12 net-new board-cfg-* PNGs needed"
  provides:
    - "208-02-ci-trigger: push to main required to run admin_design_recapture on code with CONFIG_BOARDS"
    - "208-02-gate-status: both allowlists confirmed empty; monotonic guard passes vs FETCH_HEAD; board-notice byte-stable"
  affects: [208-03-PLAN, admin-quality-ledger, design-gallery-ci-gate]
tech_stack:
  added: []
  patterns: [ci-native-png-capture, admin-design-recapture-job]
key_files:
  created: []
  modified: []
key-decisions:
  - "Board-cfg PNGs must be captured CI-native via admin_design_recapture (ubuntu); darwin capture is prohibited per D-05; a push to main is the ONLY trigger for the CI job (workflow only fires on push: branches: [main] or schedule)"
  - "Local main is 289 commits ahead of origin/main; origin/main at 9eed3474 lacks CONFIG_BOARDS (added in local commit da980c7a feat(205-03)); CI scheduled runs and workflow_dispatch on origin/main cannot capture board-cfg PNGs"
  - "Both allowlists confirmed empty (0 non-comment/non-blank lines); monotonic guard passes vs FETCH_HEAD; board-notice PNG byte-identical to origin/main (md5 e42bff78...)"
  - "workflow_dispatch CI run (28396551657) fails at release_ref_guard (requires v* ref for workflow_dispatch events) — admin_design_recapture is blocked by that dependency"
  - "Push to non-main branch (phase-208-trigger-recapture) does not trigger CI (workflow triggers: push: branches: [main] only) — branch deleted after confirming this"
  - "Phase-205 baseline-debt todo item #1 NOT yet resolved — board-cfg PNGs do not exist until CI runs against code with CONFIG_BOARDS"

requirements-completed:
  - GROUP-02

coverage:
  - id: D1
    description: "12 board-cfg-* PNG baselines captured CI-native via admin_design_recapture (ubuntu) — 4 boards × 3 projects"
    requirement: GROUP-02
    verification: []
    human_judgment: true
    rationale: "CI push to main required to trigger admin_design_recapture; PNG files do not exist yet (0 board-cfg-* PNGs in working tree); capture is blocked pending user authorization of push to main"
  - id: D2
    description: "Both allowlists empty, monotonic guard green, canaries byte-stable"
    requirement: GROUP-02
    verification:
      - kind: automated
        ref: "grep -vcE '^#|^$' test/example/priv/playwright/snapshot-allowlist → 0"
        status: pass
      - kind: automated
        ref: "grep -vcE '^#|^$' test/example/priv/playwright/snapshot-allowlist-design → 0"
        status: pass
      - kind: automated
        ref: "bash scripts/ci/quality-ledger-monotonic.sh --base FETCH_HEAD → PASS (36 cells)"
        status: pass
      - kind: automated
        ref: "board-notice-admin-design-chromium.png md5 e42bff78... matches FETCH_HEAD (byte-stable)"
        status: pass
    human_judgment: false

duration: 15min
completed: "2026-06-29"
status: blocked
---

# Phase 208 Plan 02: CI-Native board-cfg-* Baseline Capture — BLOCKED: Push to Main Required

**Plan 02 is blocked at the CI trigger step: pushing local main to origin/main is required to fire the admin_design_recapture CI job, which is the ONLY permitted mechanism for capturing board-cfg-* PNG baselines (ubuntu/CI-native per D-05 prohibition).**

---

## Performance

- **Duration:** ~15 min investigation + gate verification
- **Started:** 2026-06-29T19:10:00Z
- **Completed:** 2026-06-29T19:25:00Z
- **Tasks:** 0 of 2 fully complete (Task 2 gates verified; Task 1 blocked at CI trigger)
- **Files modified:** 0 (plan's artifacts are CI-produced PNGs, not local edits)

---

## Accomplishments

- Confirmed: both allowlists (snapshot-allowlist, snapshot-allowlist-design) have 0 non-comment/non-blank lines — PASS
- Confirmed: monotonic guard passes vs FETCH_HEAD — 36 cells, 0 regressions — PASS
- Confirmed: board-notice PNG byte-identical between local working tree and origin/main (md5 e42bff78bfda66f3b66536d649deff82) — PASS
- Confirmed: Plan 01 verdict "CSS edited: no" — board-mg-* baselines are byte-stable; only 12 cfg PNGs needed
- Diagnosed CI trigger mechanism: admin_design_recapture only fires on `push: branches: [main]` or schedule — not on push to non-main branches or workflow_dispatch (release_ref_guard blocks dispatch)
- Confirmed: origin/main (9eed3474) lacks CONFIG_BOARDS (added in local commit da980c7a); scheduled CI on origin/main cannot produce board-cfg PNGs

---

## Task Commits

No task commits — plan produces only CI-generated PNG artifacts; zero code changes required.

---

## Files Created/Modified

None — the plan's artifacts are 12 CI-generated PNGs that must be committed from the admin_design_recapture CI job's PR branch.

---

## Decisions Made

- Push to main is the only path to trigger admin_design_recapture; workflow_dispatch requires a `v*` ref (blocked by release_ref_guard); push to non-main branches does not fire the CI workflow
- workflow_dispatch run 28396551657 was attempted; failed at release_ref_guard step (not a v* ref), blocking admin_design_recapture
- The pre-existing board-notice canary failure on origin/main's scheduled CI runs is unrelated to this plan's scope; it is a CI infrastructure issue pre-dating Phase 208

---

## Deviations from Plan

None — plan execution proceeded exactly as designed up to the CI trigger step. The blocking step (push to main) was correctly identified in the plan's action step 2 but requires user authorization for the push.

---

## Gate Verification Results (Task 2 pre-flight)

```
snapshot-allowlist non-comment lines:         0    PASS
snapshot-allowlist-design non-comment lines:  0    PASS
monotonic guard vs FETCH_HEAD:               PASS  (36 cells, 0 regressions)
board-notice md5 vs FETCH_HEAD:              PASS  (e42bff78... byte-stable)
board-cfg-org count:                          0    PASS (D-06)
board-cfg PNG count:                          0    BLOCKED (requires CI capture)
```

---

## Blocking Gate: Push to Main Required

**Blocker:** The `admin_design_recapture` CI job (ci.yml:1386) fires only on:
- `push: branches: [main]` — pushing local main to origin/main
- `schedule` — nightly run on origin/main (but origin/main lacks CONFIG_BOARDS, so scheduled runs produce 0 board-cfg PNGs)

**Why push is required:** Local main (HEAD: 0e788ebb) is 289 commits ahead of origin/main (9eed3474). The board-cfg boards were added in local commit `da980c7a` (feat(205-03): register CONFIG_BOARDS in admin-design.spec.ts). Until this code is on origin/main, the CI job cannot capture the board-cfg-* PNGs.

**After user pushes main to origin:**
1. The admin_design_recapture job runs, captures 12 board-cfg-* PNGs (ubuntu-native)
2. It commits PNGs to a `ci/recapture-admin-design-<run_id>` branch and opens a PR
3. Merge the PR (review confirms: exactly 12 cfg PNGs, no board-cfg-org, board-notice as 'added', mg baselines byte-stable)
4. Move phase-205 baseline-debt todo to resolved/
5. Run final verification commands from plan's `<verification>` block

---

## Phase-205 Baseline-Debt Todo Status

**NOT resolved yet** — item #1 (missing board-cfg-* baselines) remains pending until the CI job produces and the PR merges the 12 PNGs. The todo at `.planning/todos/pending/2026-06-28-phase205-debt-ci-native-board-baselines.md` should be moved to resolved AFTER the PR merges.

---

## Threat Flags

None — no new security surface introduced. This plan touches only Playwright PNG baselines.

---

## Known Stubs

None — this plan produces only PNG baselines (CI-generated). No code stubs.

---

## Self-Check: PASSED (partial — blocked before artifacts exist)

- SUMMARY.md created at `.planning/phases/208-l2-meta-component-group-elevation/208-02-SUMMARY.md` ✓
- No code changes committed (CI-trigger plan; artifacts are CI-produced) ✓
- Allowlists confirmed empty ✓
- Monotonic guard confirmed passing vs FETCH_HEAD ✓
- Board-notice byte-stable vs origin/main ✓
- Board-cfg PNG count: 0 (BLOCKED — requires CI capture after push to main) ✗
- Phase-205 todo NOT moved to resolved (blocker: PNGs not yet committed) ✗
