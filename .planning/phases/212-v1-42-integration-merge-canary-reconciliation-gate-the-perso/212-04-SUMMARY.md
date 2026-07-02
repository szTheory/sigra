---
phase: 212-v1-42-integration-merge-canary-reconciliation-gate-the-perso
plan: "04"
subsystem: integration-merge
tags:
  - integration
  - merge
  - SC-4
  - GATE-01
  - FLOW-01
  - GATE-02
dependency_graph:
  requires:
    - "212-01 (GATE-01 canary + allowlists), 212-02 (FLOW-01), 212-03 (GATE-02)"
    - "prerequisite recapture PR #64 merged to origin/main"
  provides:
    - "v1.42 full backlog merged to origin/main via PR #63"
    - "v1.42 → shipped landed atomically with the merge (honest status, D-16)"
    - "both snapshot allowlists reset to comment-only (D-03/D-14)"
  affects:
    - "origin/main (388-commit v1.42 backlog + 6 test reconciliations)"
    - ".planning/STATE.md (reconciled to merged/shipped)"
key_files:
  created:
    - ".planning/phases/212-.../212-04-SUMMARY.md"
  modified:
    - ".planning/STATE.md"
    - "test/example/priv/playwright/snapshot-allowlist"
    - "test/example/priv/playwright/snapshot-allowlist-design"
  deleted:
    - ".planning/todos/pending/2026-06-28-phase205-debt-ci-native-board-baselines.md"
decisions:
  - "D-12: ship/v1.42-ci-gate-remediation updated to local main's tip so PR #63 carries the full 388-commit backlog (fast-forward — ship was an ancestor of main, so no force needed)"
  - "D-16: v1.42→shipped NOT re-flipped — it rode in the backlog (4a5dd5f7) and landed atomically with the merge; verified origin/main showed 'v1.40 in planning' pre-merge, 'v1.42 shipped' post-merge"
  - "D-03/D-14: both allowlists reset to comment-only AFTER merge (steady-state tripwire restored)"
  - "D-11: stale phase-205 board-baseline todo deleted (its board PNGs now exist on main)"
metrics:
  completed: "2026-07-02T21:05:00Z"
  tasks_completed: 5
  tasks_total: 5
  ci_cycles: 3
status: complete
---

# Phase 212 Plan 04: SC-4 Integration Merge Summary

Merged the full v1.42 backlog (388 commits, Phases 205–211 + the 212 gate wiring) to `origin/main` via PR #63 with every required lane green and both snapshot-drift lanes clean. The `v1.42 → shipped` flag landed atomically with the merge (honest status, D-16). Post-merge, both allowlists were reset to steady-state and the stale phase-205 todo deleted.

## Tasks Completed

| Task | Description | Result |
|------|-------------|--------|
| 1 | Confirm gates green + grow PR #63 to the full backlog (D-12) | ship fast-forwarded to main's tip (388 commits); base origin/main |
| — | Un-draft PR #63 + drive all required lanes green | 3 CI cycles (regressions surfaced + fixed); final run 28619792604 success |
| — | Merge PR #63 to origin/main (point of no return) | MERGED 2026-07-02T21:02:29Z |
| 2 | Reconcile STATE to merged/shipped (D-16, no re-flip) | STATE.md frontmatter + Current Position updated; shipped flag verified atomic |
| 3 | Reset both allowlists (D-03/D-14) + delete stale todo (D-11) | both allowlists comment-only; phase-205 todo removed |

## What Was Built

**Merge vehicle (D-12):** PR #63's `ship/v1.42-ci-gate-remediation` was at Phase 208.1 (314 commits) and did NOT contain the gate-closing 209/210/211 work. It was updated to local `main`'s tip. Notably this was a clean **fast-forward** (ship's tip `cbe0b928` was an ancestor of local main), so no force-push was required — the planning premise of a mandatory force-update did not hold against the real topology.

**Honest status (D-16):** The `v1.42 → shipped` flag (commit `4a5dd5f7`, Phase 211-05) was already committed in the backlog. It was NOT re-flipped. Verified `origin/main` showed "v1.40 CI-PERF in planning" immediately BEFORE the merge and "v1.42 ADMIN-DS-ELEVATION … shipped" immediately AFTER — the flag landed atomically with the merge, satisfying the audit's premature-flag guard (§81/§158).

**Post-merge steady state:** Both `snapshot-allowlist` and `snapshot-allowlist-design` reset to comment-only so the next PR's real drift on those slugs cannot pass silently. Stale phase-205 board-baseline todo deleted (its board PNGs now exist on main).

## Deviations from Plan

1. **Canary reconciliation mechanism (supersedes D-13, human-ratified 2026-07-02):** the sanctioned `admin_checkpoint_recapture` CI job was mechanically infeasible against the 396-commit-behind topology. Reconciled instead via a byte-only prerequisite PR (#64), admin-merged to origin/main, setting the canary baseline to the reviewed WCAG bytes — canary stayed armed, WCAG fix preserved, no waiver. (See 212-01-SUMMARY.)
2. **Force-update was a fast-forward (D-12):** ship was an ancestor of main, so a normal push sufficed; no `--force-with-lease` needed.
3. **Real backlog regressions surfaced (not in original scope):** the new gates (FLOW-01 wiring + full suite on the integration PR) exposed that Phase 209's admin-UI copy/IA polish had left **6 example-app tests stale** (1 ExUnit + 5 Playwright, incl. 4 never-run FLOW-01 specs). All 6 were reconciled to the current UI over CI cycles 2–3 — confirmed stale, not runtime bugs (see the debug session and the `test(212): reconcile …` commits). One (org-admin /admin denial) was a genuine 403-vs-graceful-redirect contract fork, resolved by human ruling (keep the example's redirect UX; reconcile the spec, preserve anti-enumeration).

## Verification Results

- Final CI run `28619792604`: **success**. All required lanes green — Fast checks (both snapshot lanes), Example unit smoke, Example Playwright smoke (full lifecycle), Generated admin Playwright smoke (RUNS+PASSES), Install smoke/golden, Library tests (all shards), Example HTTP smoke, ci-gate.
- PR #63: MERGED; origin/main mergeState CLEAN pre-merge.
- Gate-closing commits (272e187c / 3d129bb2 / 4fc936f8 / f5833b0b / 4a5dd5f7) all present on origin/main.
- Post-merge: both allowlists 0 non-comment lines; stale todo absent.

## Requirement Closure

- **SC-4 CLOSED:** full v1.42 backlog merged to origin/main via the reviewed PR #63; shipped flag atomic; STATE reconciled; allowlists reset. Honest status — no premature flag, no stale merge vehicle.
- **GATE-01 / FLOW-01 / GATE-02** all closed and proven green on the integration PR (see 212-01/02/03 summaries).

## Self-Check: PASSED

- [x] PR #63 merged to origin/main; shipped flag landed atomically (not re-flipped)
- [x] All required CI lanes + ci-gate green on the final run
- [x] Both allowlists reset to comment-only
- [x] Stale phase-205 todo deleted
- [x] STATE.md reconciled to merged/shipped
