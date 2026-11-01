# Phase 243 Plan 03 amendment — evidence-based candidate dispositions

**Authorized:** 2026-09-25 by the project owner’s request to clear the recorded Phase 243 blockers.

## Why the original batch stopped

The frozen eight-PR batch included both stale work and three evidence-bearing requests. The original plan correctly stopped before acting, but treating all eight as one all-or-nothing stale set left already-satisfied requests open and made the active Phase 248 proof lane block unrelated stale cleanup.

## Revised rule

Reconcile each frozen identity against current `main` and its exact request. Close only requests whose work is superseded, parked, or already proven; write an individual public close reason and retain every head branch. Keep active future proof work open and explicitly classify it as carryover. Do not delete branches.

## Frozen candidate decisions

| PR | Decision | Evidence and action |
|---|---|---|
| #211 | Close as superseded | Its three impersonation-banner snapshots are already present on current `main`; the PR’s images differ from the current baselines. Preserve the branch. |
| #172 | Close as superseded | Its baseline images are already present on current `main`, and its older Phase 231/232 changes have been superseded by later completed phase evidence. Preserve the branch. |
| #124 | Close as fulfilled | Current `main` already records Phase 230 complete in ROADMAP and STATE. Preserve the branch. |
| #174 | Close as superseded | Phase 235 has protected source-complete timing evidence (`n=52`, `p50=469s`); Phase 234 explicitly retired the old formatter path. Preserve the branch. |
| #219 | Keep open as active carryover | Draft body identifies the Phase 248 Android proof lane and says it exists to retain bounded provisioning evidence. No close or branch deletion. |
| #234 | Close as parked | Current ROADMAP documents the 235.1 line as parked, with remaining timing work filed as debt. Close the inactive PR but retain its branch and artifacts for a future explicit resumption. |
| #261 | Close as fulfilled | Exact PR head `d7d78eb85e4f8769172741d3682a0941bba25d5b` has successful full CI run `35937900338`, including required `ci-gate`; preserve the run receipt in this artifact. |
| #254 | Close as fulfilled | Exact Phase 241 final head has a passing receipt on the PR comment and Phase 241 VERIFICATION is `passed` at 43/43. Preserve the comment and branch. |

## Execution gates

1. Re-query each open PR and confirm its head has not changed since the frozen inventory.
2. Close the seven marked candidates individually with the evidence above; do not use `--delete-branch`.
3. Read back every closed state, public reason, and unchanged head ref. Confirm #219 remains open and every branch still exists.
4. Update `243-STALE-PR-EVIDENCE.json`, Plan 03’s summary, and the `QUEUE-03` wording to distinguish stale cleanup from retained active carryover.

## Completion condition

All superseded, parked, or fulfilled candidates are closed with evidence-linked reasons, active #219 remains open, and no branch is deleted. This amendment supersedes only the original all-eight-stale precondition; it does not alter Tier B ordering or the untouched status of #213.
