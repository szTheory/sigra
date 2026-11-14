# GSD forensics: Phase 255.1 routing loop

**Problem:** Phase 255.1 kept being routed back into execution or discussion after its approved preparation stopped. The user reported repeated phase starts as a waste of time and money.

**Finding:** This was a routing metadata mismatch, not evidence that the performance phase had passed. The current execution had a real local blocker, but the project’s active route fields and recovery note kept offering another phase command. The GSD executor uses a different artifact as its source of truth.

## Evidence and anomalies

| Anomaly | Severity | Evidence |
|---|---|---|
| Stuck route | High | Before this correction, `.planning/STATE.md` and `.planning/HANDOFF.json` selected `$gsd-discuss-phase 255.1`; `.planning/state.json` also contained `$gsd-execute-phase 255.1`. `255.1-RECOVERY-RESET.md` ended by telling the next actor to execute the same phase. |
| Missing closeout artifact | High | Plan 06 had no matching summary even though tasks 14a and 14b were done and task 14c had stopped. The OpenGSD locator calculates incomplete plans from missing summaries. |
| State/locator disagreement | High | `~/.codex/gsd-core/bin/lib/phase-locator.cjs` builds `halted_plans` by parsing matching summary files with `status: halted`, then blocks dependent plans through their `depends_on` edges. The state/handoff halt flags are not read in that readiness path. `255.1-07-PLAN.md` depends on Plan 06. |
| Partial execution | High | `.planning/execution/255.1/protected-delivery-scope/prep-policy-20261102/PREP-VERIFY.json` records the stop before collector HTTP: the source commits were unavailable locally, and the request budget and acceptance sample count stayed at zero. The exact approved attempt cannot be retried. |
| Interruption/crash | Unconfirmed | The working tree has existing uncommitted material, and no `.planning/reports/SESSION_REPORT.md` was found. The available evidence does not attribute the stop to a crash. Older/prunable worktrees exist, but none was tied to this stop. |

## Root cause

GSD execution readiness does not honor `halted_plans` fields in `state.json` or `HANDOFF.json`. It uses a matching plan `SUMMARY.md` with `status: halted`, then propagates that halt to dependent plans. Plan 06 lacked that summary, so the executor still treated it as an unsummarized plan. Meanwhile stale active route fields and the recovery reset pointed back to the same phase. This made the earlier state edits ineffective for OpenGSD’s plan selection and encouraged the loop.

## Correction and deterministic check

- Added `.planning/phases/255.1-close-gap-cispeed-01-cispeed-02-prove-ci-performance-targets/255.1-06-SUMMARY.md` with `status: halted`, no completed requirements, and explicit stop evidence.
- Updated `AGENTS.md`, `255.1-LEARNINGS.md`, and `255.1-RECOVERY-RESET.md` with the native halt rule and the superseding current route.
- Cleared active automatic `next_command` and `resume_command` fields from the handoff/state; there is no phase command under the current approval. Exact dirty state bytes were preserved and read back at `.planning/execution/255.1/write-ahead-preservation/phase2551-loop-fix-before-refresh-20261103T041737Z/PRESERVATION-REF.json` before these edits (`git_ref` is null because `.git` is read-only).
- Ran `node ~/.codex/gsd-core/bin/gsd-tools.cjs query init.execute-phase 255.1`. It returned `halted_plans: [255.1-06-PLAN.md]`, `blocked_by: {255.1-07-PLAN.md: [255.1-06]}`, and `runnable_plans: []`.

## What remains

The phase is incomplete. CISPEED-01 and CISPEED-02 remain open; no exact warm-cache useful-work proof or performance samples exist. The approved source commits remain unavailable in this checkout, and the approval is exhausted for retry. No hosted actions were taken. Do not rerun or automatically discuss Phase 255.1; the user must choose a new scope if they want work to continue.
