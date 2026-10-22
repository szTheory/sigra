# Phase253: direct review after Plan172

The `gsd-progress` handoff was an unnecessary status detour. Current state and evidence were available. This review was performed directly, without new GitHub requests, browser launches, acceptance attempts or budget changes.

**The actual blocker is the original registration failure.** Its strict evidence checker returns exit3. The recorded `not_reproduced` decision is valid (its separate checker returns0), but that decision explicitly leaves CIREL-01 unsatisfied. It cannot be called a fixed flake or a no-flake result.

The missing items are an original preceding-order log, the original database/control state for the selected collision, and a failing counterexample on the preserved affected source tied to a registration-harness condition. The22 deterministic readiness/isolation controls passed; they do not supply those missing facts. All nine post-fix acceptance slots are expired. No old slot or approval can be restarted.

The required-gate evidence is available and verifies: all five normal browser groups and native required checks; the actual docs-only PR344 run and independently accepted records; the retained six hosted canary scenarios and separate verifier; unchanged gate inputs and canary-code comparison. Failure, missing-seam, unexpected-skip and cancellation cases remain non-green. The normal recovery and docs collection keep separate ledgers; the original single-ledger pair verifier is not claimed.

Fresh local checks passed:21 shell cases and5 unit-owner tests,57 browser/manifest/workflow/report tests, and151 hosted-verifier contract tests. Five read-only evidence commands are captured directly in `.planning/execution/253-direct-requirement-review/`, including the strict registration rejection. These checks are not a new native acceptance or a full phase signoff. Both requirement checkboxes remain unchanged.

No command is needed from the user now. The next meaningful step is obtaining the missing original failure evidence or establishing a specifically permitted reproduction path on the preserved source. Once that blocker changes, the exact phase recheck is `$gsd-verify-work 253`. Until then it is conditional, not a request to run another status command, create a numbered repair plan, repeat hosted CI or start Phase254.

Machine-readable findings and input hashes: `.planning/execution/253-direct-requirement-review/review.json`.
