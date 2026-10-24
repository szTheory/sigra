---
phase: 253-fix-flaky-ci-and-preserve-required-checks
plan: "179"
status: complete
subsystem: testing
tags: [ci-reliability, offline-acceptance, once-only]
requirements-completed: []
key-files:
  created: [253-179-PERMISSION-PREFLIGHT.json, 253-179-REGRESSION.log, 253-179-RECOVERY-RECEIPT.json, 253-179-EXECUTION-RECORD.json]
  modified: []
metrics:
  duration_seconds: 7472
  completed_tasks: 2
  unittest_tests: 673
  suites: 10
---

# Plan179: actual offline acceptance passed

One root-owned elevated acceptance ran from `3197421e08f2af060c0a03f8b91cf6b298f641e1` between `2026-10-21T01:10:18Z` and `2026-10-21T03:14:50Z`. Its first and only exit was0, with terminal `VERIFY-EXIT 0`. No acceptance rerun, product edit, hosted CI launch or budget renewal occurred. Both original CI requirements and whole-phase verification remain open.

| Task | Result | Commit |
|---|---|---|
| 1: actual elevated acceptance and complete output | Passed; same-process PID61419 Git write/readback | e0f54e795 |
| 2: actual receipt and independent reopening | Passed on clean committed checkout | e33460e9b68d4b6a7c205caa01177a6c433332e2 |

## Actual validation

| hermetic-live-audit | 66 |
| git-publication | 124 |
| hosted-transport | 85 |
| shape-probe | 19 |
| pr-proof | 110 |
| hosted-gate-verify | 151 |
| gate-canary-flow | 23 |
| full-dryrun | 90 |
| gate-canary-shell | native shell success |
| gate-canary-recovery | 5 |

Nine unittest suites passed673 tests, plus the shell suite. The unfiltered full-dryrun suite ran90 tests in5907.914s and endedOK. Projection used17 requests; largest serialized body2093852 bytes left3300 bytes under2097152. The historical full-paged `attempt_jobs7/7` stop remains unchanged and was not rerun.

`verify-receipt` exited0 at `e33460e9b68d4b6a7c205caa01177a6c433332e2` and printed `253-179 successor receipt verified`. The checkout was clean and all four shared source files still matched acceptance. This verification preceded the root's permitted post-plan routing updates; original shared bytes remain bound to the receipt and retained source ref. The actual launch arguments, session16381, result chunk1dedd5, exact generated script/PLAN hashes and probe object are saved. The tool exposes a session and result chunk, not a separate opaque call ID; the preflight states that explicitly.

## Preservation and remaining work

Raw external diagnostics: `refs/gsd/phase253-179-offline-acceptance-diagnostics` at `05126069c8512d1187a62fdeecebb64eff73c4ad`;26 paths were read back byte-for-byte. Exact acceptance/shared source: `refs/gsd/phase253-179-acceptance-source` at `3197421e08f2af060c0a03f8b91cf6b298f641e1`. Full path/blob/hash manifest:253-179-EXECUTION-RECORD.json. Native log whitespace was retained unchanged; `git diff --check` flags its one original progress line.

All28 earlier halts, including181/182/183, remain halted.176/177 remain unexecuted. No Phase252 evidence, frozen limits or requirement status changed. CIREL-01 still lacks a reproduced registration failure; CIREL-02 still lacks the real hosted required-gate proof.

Plan180 has not run. Its old simulation assumes successful183/27 halts and must account for actual halted183/28 halts before execution. No numbered repair plan was created.

## Self-Check: PASSED

Real native output, same-process permission probe, original source bindings and committed receipt were independently reopened. This completes Plan179's local implementation/acceptance only, not Phase253 verification.

Next command: `$gsd-progress`.
