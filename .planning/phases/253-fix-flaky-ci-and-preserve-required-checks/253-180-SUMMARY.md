---
phase: 253-fix-flaky-ci-and-preserve-required-checks
plan: "180"
status: complete
subsystem: testing
tags: [preserved-plan-amendment, local-routing]
requirements-completed: []
key-files:
  created: [253-180-BRIDGE-V2-RECORD.json, 253-180-CHECKS-V2.json]
  modified: [253-168-PLAN.md, 253-169-PLAN.md, 253-170-PLAN.md, 253-171-PLAN.md, 253-172-PLAN.md]
---

# Plan 180: preserved plan amendments verified

The two entry amendments and three completion amendments passed the V2 consumer. The original helper, original Plan180, Plan179 receipt/log/preflight, all original summaries and all limits remain unchanged. Seven original plans are recoverable at `refs/gsd/phase253-successor-180-v2-plan-originals`, commit `3197421e08f2af060c0a03f8b91cf6b298f641e1`. Their exact paths, Git blobs, bytes and SHA-256 values and the five amended hashes are in `253-180-BRIDGE-V2-RECORD.json`.

Entry bridge and actual179 receipt checks passed on a clean committed checkout before Task2. All five amended plans passed installed-GSD schema and structure validation. Existing warnings are retained verbatim in the record; none was represented as an error-free result. Original170/171 tasks and eight172 hosted/native links compare byte-for-byte with originals.176/177 remain original and unexecuted; all28 halts, including175/178/181/182/183, remain literal. No new freeze or dispositions were applied.

The actual installed SDK executed four queries in a disposable committed copy:168 runnable after180; simulated later chain183rows,155nonhalted summaries plus28halts,0incomplete. This is fixture evidence only. Actual state after this summary is183plans,77completed implementation plans,28halted,78without summaries. Whole-phase verification is not_started and both CIREL requirements remain open.

Final clean-checkout `verify-bridge --stage complete --sdk` passed, independently repeating actual SDK queries; `verify-receipt --consumer168` returned verified/count90. Fresh outputs and immutable source bindings are recorded in `253-180-CHECKS-V2.json`; raw results survive at `refs/gsd/phase253-180-v2-final-checks` (`a03b4cd73a70e6cbdcf29f216971280b4a79685c`). InitialSDK outputs survive at `refs/gsd/phase253-180-v2-sdk-evidence`. The firstSDK check refused two ignored inputs: `.planning/.DS_Store` and the stale milestone.lock (its PID was absent). Both were preserved exactly at `refs/gsd/phase253-180-ignored-input-preservation` and read back before removal. No helper weakening or input exclusion was added.

No179 acceptance rerun, browser launch, network request, CI launch, budget renewal or requirement completion occurred. No numbered repair plan was created.

## Self-Check: PASSED

Both required actual bridge/receipt checks exited0 after the last amendment/binding commit `5e6f9f33c6b2b403a0a12251cd071a43b55123e8`. Original pins, hosted tasks, exact28halts, exact73targets and183plan identities were checked by the versioned consumer. Root must inspect168 readiness via `$gsd-progress` before any continuation. No hosted continuation is authorized.
