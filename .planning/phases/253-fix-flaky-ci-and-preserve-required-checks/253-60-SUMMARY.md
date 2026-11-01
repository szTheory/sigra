---
phase: 253-fix-flaky-ci-and-preserve-required-checks
plan: "60"
subsystem: ci-reliability
tags: [ci-reliability, load-recovery, re-freeze, budget, r3, setup-phase, diagnostics]
requires:
  - phase: 253-fix-flaky-ci-and-preserve-required-checks
    provides: R2 runner and halted R2 lineage; preserveAttemptDiagnostics and verifyAttemptDiagnosticsR3 (253-59); R3 budget document
provides:
  - additive R3 load-recovery revision in scripts/ci/ci-registration-recovery.mjs (create/check/init/prepare/run/verify, R3 approval recorder and reader)
  - setup phase (mix ecto.setup) bounded at 60000 ms and charged separately before the browser command deadline starts
  - mandatory per-test diagnostics and per_test_rows on every attempt that launched the CLI
affects: [253-62, 253-63]
actuals:
  tokens: 35900
  tasks: 3
  commits: 6
plan_head_before: 06c5ae575
plan_head_after: e908d41fab8ea443af2d2a62155b7a9a3c86cb80
commits: 6
tech-stack:
  added: []
  patterns: ["additive revision beside frozen R2 code, routed by exact resolved path", "dual-clock phase windows that tile the slot so no time is uncharged", "injectable clocks, host probe, holders and process trees for offline native-path tests"]
key-files:
  created: []
  modified:
    - scripts/ci/ci-registration-recovery.mjs
    - scripts/ci/ci-registration-recovery.test.mjs
key-decisions:
  - "R3 history reader re-hashes R2 evidence, freeze, approval, budget and every R2 raw receipt against pinned sha256 values, and reuses readLoadHistoryR2 for the older lineage."
  - "A slot is charged setup max(monotonic, wall) plus command max(monotonic, wall); the two windows tile the slot (command starts at the exact setup end), so the sum can only be at or above the whole-window max."
  - "The infrastructure retry inherits the halted slot's own window sizes (the declared CR3-INFRA-RETRY row stays 240000 ms for cap sizing), so a re-run of a 135000 ms slot is never granted a larger window than the original."
  - "Only a suspension, a lost caffeinate holder, or a spawn-level setup error with zero rows is infrastructure; a setup failure, setup overrun or deadline kill without suspension is terminal."
requirements-completed: ["CIREL-01", "CIREL-02"]
coverage:
  - id: D1
    description: "R3 ledger carries 2150682 ms, 7 launches and eight spent identities; caps equal the R3 budget table; expired/retired identities cannot run"
    requirement: CIREL-01
    verification:
      - kind: unit
        ref: "scripts/ci/ci-registration-recovery.test.mjs#R3 ledger carries 2150682 ms, seven launches and eight spent identities, with the reviewed R3 caps"
        status: pass
      - kind: unit
        ref: "scripts/ci/ci-registration-recovery.test.mjs#every spent, expired and retired identity is refused by the R3 runner before any spawn"
        status: pass
    human_judgment: false
  - id: D2
    description: "R3 history reader and freeze create/check/init produce a ready ledger from re-hashed R2 lineage"
    requirement: CIREL-01
    verification:
      - kind: unit
        ref: "scripts/ci/ci-registration-recovery.test.mjs#R3 freeze creation, check and init produce a ready ledger whose caps equal the R3 budget document"
        status: pass
    human_judgment: false
  - id: D3
    description: "Setup bounded and charged separately from the browser deadline; slot charge is the setup plus command sum"
    requirement: CIREL-02
    verification:
      - kind: unit
        ref: "scripts/ci/ci-registration-recovery.test.mjs#a synthetic R3 first slot runs setup under its own 60000 ms deadline and leaves the full 165000 ms work deadline intact"
        status: pass
      - kind: unit
        ref: "scripts/ci/ci-registration-recovery.test.mjs#a setup failure or a setup overrun halts before any CLI launch, stays charged and still drops the owned database"
        status: pass
    human_judgment: false
  - id: D4
    description: "Per-test JSONL and error-context receipts preserved on pass, assertion failure and deadline kill; verifier rejects a launched attempt without them"
    requirement: CIREL-02
    verification:
      - kind: unit
        ref: "scripts/ci/ci-registration-recovery.test.mjs#diagnostics are preserved on an assertion failure and a deadline kill, and the verifier needs them"
        status: pass
    human_judgment: false
  - id: D5
    description: "R3 run needs a committed v2 approval bound to the R3 budget and freeze plus a passing host probe; retry gated and single-use"
    requirement: CIREL-01
    verification:
      - kind: unit
        ref: "scripts/ci/ci-registration-recovery.test.mjs#an R3 run needs a committed v2 approval bound to the R3 budget and freeze, and the R2 approval is refused"
        status: pass
      - kind: unit
        ref: "scripts/ci/ci-registration-recovery.test.mjs#CR3-INFRA-RETRY runs once, needs a committed diagnostic and a granted retry, and re-runs the identical frozen selection"
        status: pass
    human_judgment: false
duration: ~95min
completed: 2026-10-14
status: complete
---

# Phase 253 Plan 60: R3 Runner Revision Summary

**Additive R3 load-recovery runner: carries the spent 2150682 ms / 7 launches / eight identities from re-hashed R2 bytes, moves `mix ecto.setup` into a separately bounded and charged 60000 ms phase ahead of the browser deadline, and requires preserved per-test diagnostics on every launched attempt.**

## Performance

- **Duration:** ~95 min
- **Tasks:** 3 (each RED then GREEN)
- **Files modified:** 2 (`scripts/ci/ci-registration-recovery.mjs`, `scripts/ci/ci-registration-recovery.test.mjs`)
- **Tests:** recovery file 100 -> 132 (+32 R3 tests); with `ci-playwright-load.test.mjs` 148 pass, 0 fail, 0 skipped (Node 20.18.1)

## Accomplishments

- R3 ledger, slot table (CR3-DESKTOP-MOBILE-FIRST 240000 ms; three seconds 135000 ms; CR3-INFRA-RETRY declared 240000 ms) and cap table (910000 / 3060682 / 12 / 5400682 / 21, and 670000 / 2820682 / 11 / 5160682 / 20) with the identical 22-row selection, argv, ports and expected CLI exits.
- `readLoadHistoryR3` re-hashes R2 evidence (be47d624...), freeze (b26d5a0c...), approval (d5c85aaa...), budget (9bb278db...) and all R2 raw receipts, binds the root-cause record at its committed path, and builds the terminal non-infrastructure halt record. Run ad hoc against the real repository it returns the 2150682 ms ledger and 32 lineage artifacts.
- R3 freeze pins the R2 source list plus the eight product, diagnostics and audit blobs; `--create-load-recovery-r3`, `--check-load-recovery-freeze`, `--init-load-recovery`, `--prepare-load-recovery`, `--run-load-recovery`, `--verify-load-recovery` and `--record-budget-approval` route by exact resolved path (v1, R2, R3; anything else rejects).
- Run path: setup under its own dual-clock deadline from slot start; command clock starts at the exact setup end; a setup failure or overrun halts before any CLI launch and is charged; the CLI env carries `SIGRA_PLAYWRIGHT_FAILURE_JSONL`; diagnostics are preserved before temp removal on every outcome.
- Gates: committed v2 approval bound to the R3 budget document and freeze (R2 approval refused), host probe before predebit, `min(freeze caps, approval caps)` enforcement, single-use gated retry, `host_awake` proof, setup-plus-command charge recomputation, `per_test_rows` in every terminal stop record, and terminal evidence that still verifies by git objects after later committed runner changes.

## Task Commits

1. Task 1 RED `1c55ffa33` (test); GREEN `05f64723a` (feat): ledger, history reader, freeze, init
2. Task 2 RED `5c70e0249` (test); GREEN `990d60883` (feat): setup-phase run path and diagnostics
3. Task 3 RED `073bd8932` (test); GREEN `e908d41fa` (feat): approval, retry, host proof, halt rows

## Decisions Made

See `key-decisions`. No v1 or R2 literal, schema string or path check was altered: against the plan start (`06c5ae575`) the only removed lines are two `main()` routing expressions that now delegate to R3 first.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing critical] Charge floor on the whole window**
- **Found during:** Task 3 (verifier tests)
- **Issue:** The v1 predicates are judged on an adjusted copy (charge = max whole-window clocks), so a forged larger `wall_duration_ms` would not have been caught.
- **Fix:** The R3 accounting verifier also rejects a charge below max(total execution, total wall).
- **Files modified:** scripts/ci/ci-registration-recovery.mjs
- **Committed in:** e908d41fa

**2. [Rule 3 - Blocking] Test-only seams on the history reader and freeze**
- **Found during:** Task 1
- **Issue:** The pinned lineage hashes and `ci` guard "no ordinary contract reads active phase records" make a positive freeze/history test impossible against real records.
- **Fix:** `readLoadHistoryR3` and `createLoadRecoveryFreezeR3`/`validateLoadRecoveryFreezeR3` accept injected seams (`olderHistory`, `lineage`, `skipPreservedRevisions`, source list, runtime identity), defaulting to the real behavior; tests use synthetic committed temp repositories. The real reader was exercised once ad hoc instead.
- **Files modified:** both
- **Committed in:** 05f64723a

---

**Total deviations:** 2 auto-fixed (1 missing critical, 1 blocking). **Impact:** no scope creep; defaults are the production behavior.

## Issues Encountered

- Plan verify runs `--verify-load-recovery` on the halted R2 evidence: it exits 3 with `R2 native load recovery evidence rejected: frozen R2 source identity mismatch for scripts/ci/ci-registration-recovery.mjs` and no JavaScript crash text. This is the expected consequence the plan's execution contract names (253-58/59/60 change blobs pinned by the R2 freeze); R2 lineage is protected by byte identity instead.
- The retry inherits the halted slot's window sizes rather than a flat 240000 ms window (see key-decisions). Cap sizing still reserves 240000 ms.

## Remaining Gaps

- The R3 freeze itself is created in 253-62; Jon's R3 approval is 253-63. No native run, `psql`, `caffeinate`, Playwright CLI or GitHub request was made by this plan. Full Phase253 verification stays not_started.
- `scripts/ci/ci-hosted-gate-verify.py` still needs its LOAD_CHECKS pointed at the R3 evidence (outside this plan's declared files).

## Known Stubs

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Ready for 253-62 (offline gate on final product source, then create/check/commit the R3 freeze).

## Self-Check: PASSED

- Commits present: 1c55ffa33, 05f64723a, 5c70e0249, 990d60883, 073bd8932, e908d41fa.
- R2 freeze (b26d5a0c...) and R2 evidence (be47d624...) byte-identical; `.planning/config.json` untouched.
- `node --test scripts/ci/ci-registration-recovery.test.mjs scripts/ci/ci-playwright-load.test.mjs` under Node 20.18.1: 148 pass, 0 fail, 0 skipped.

---
*Phase: 253-fix-flaky-ci-and-preserve-required-checks*
*Completed: 2026-10-14*
