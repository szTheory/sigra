---
phase: 253-fix-flaky-ci-and-preserve-required-checks
plan: "48"
subsystem: ci-reliability
tags: [ci-reliability, load-recovery, re-freeze, host-sleep, r2]
requires:
  - phase: 253
    provides: 253-39 four-slot load-recovery runner, 253-40 halted lineage, cf578a567 dual-clock watchdog fix
provides:
  - additive R2 revision of scripts/ci/ci-registration-recovery.mjs (carried ledger, slots, freeze/init/prepare/run/verify, approval record, host-sleep preflight, single infrastructure retry, terminal-evidence git binding)
  - committed 253-LOAD-RECOVERY-NATIVE-FREEZE-R2.json pinning the fixed runner and preserving 253-40 as spent lineage
affects: [253-51, 253-52]
actuals:
  tokens: 35400
  tasks: 3
  commits: 5
plan_head_before: d4d7c4e8fa605d84c249f92e7a44fe778c94bfc2
plan_head_after: b141f301383c1fae5d60bd760201b8a7c7c7db00
tech-stack:
  added: []
  patterns:
    - "R2 modes are routed by exact resolved path; the v1 Plan39 constants, schemas and functions are untouched"
    - "accepted R2 evidence binds frozen blobs through git ancestry and object reads; live run/init/prepare keep working-tree equality"
key-files:
  created:
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-NATIVE-FREEZE-R2.json
  modified:
    - scripts/ci/ci-registration-recovery.mjs
    - scripts/ci/ci-registration-recovery.test.mjs
key-decisions:
  - "Capacity is granted only by a committed 253-LOAD-RECOVERY-BUDGET-APPROVAL-R2.json bound to the R2 budget doc sha256 and the freeze file sha256; the freeze itself grants nothing (budget.grants_capacity=false)"
  - "The retry slot CR2-INFRA-RETRY is declared with no selection and resolves to the halted slot's exact frozen selection at use"
  - "Infrastructure cause is host_sleep (suspension), holder_lost (caffeinate holder dead at window end) or host_failure (spawn error before any test); an observed assertion failure is never infrastructure"
requirements-completed: []
coverage:
  - id: D1
    description: "R2 ledger builder accepts only the carried 2042596 ms / 6 launches / seven spent identities / 4398 ms preparation and the reviewed R2 caps (2687596 / 5027596 / 11 / 20 and the without-retry 2567596 / 4907596 / 10 / 19)"
    requirement: CIREL-01
    verification:
      - kind: unit
        ref: "scripts/ci/ci-registration-recovery.test.mjs#R2 ledger carries 2042596 ms, six launches and seven spent identities, with the reviewed R2 caps"
        status: pass
      - kind: unit
        ref: "scripts/ci/ci-registration-recovery.test.mjs#R2 ledger rejects any other carried input"
        status: pass
    human_judgment: false
  - id: D2
    description: "Identical 22-row selection (16+2+2+2) under CR2-DESKTOP-MOBILE-FIRST plus the three unused seconds; every spent identity incl. CR-DESKTOP-MOBILE-FIRST refused before any spawn"
    requirement: CIREL-01
    verification:
      - kind: unit
        ref: "scripts/ci/ci-registration-recovery.test.mjs#R2 slots keep the identical 22-row selection under CR2-DESKTOP-MOBILE-FIRST plus the three unused seconds and one retry declaration"
        status: pass
      - kind: unit
        ref: "scripts/ci/ci-registration-recovery.test.mjs#every spent identity, including CR-DESKTOP-MOBILE-FIRST, is refused by the R2 runner before any spawn"
        status: pass
    human_judgment: false
  - id: D3
    description: "Synthetic R2 first slot and full four-slot run write ledgers the R2 verifier accepts; v1 and R2 evidence are never accepted by the other revision"
    requirement: CIREL-01
    verification:
      - kind: unit
        ref: "scripts/ci/ci-registration-recovery.test.mjs#a synthetic R2 first slot writes an R2 ledger that the first-stage verifier accepts"
        status: pass
      - kind: unit
        ref: "scripts/ci/ci-registration-recovery.test.mjs#R2 runs all four regular slots once in order and verifies the complete 22-row proof"
        status: pass
    human_judgment: false
  - id: D4
    description: "Approval record (exclusive create, reject writes nothing, committed and hash-bound before any run), host-sleep preflight before predebit, host_awake receipt requirement, single bounded infrastructure retry, terminal-evidence git binding"
    requirement: CIREL-02
    verification:
      - kind: unit
        ref: "scripts/ci/ci-registration-recovery.test.mjs#recording a budget approval is exclusive, binds the budget and freeze hashes, and a reject writes nothing"
        status: pass
      - kind: unit
        ref: "scripts/ci/ci-registration-recovery.test.mjs#the host preflight refuses, and releases any holder, for battery power, a dead holder or missing assertions"
        status: pass
      - kind: unit
        ref: "scripts/ci/ci-registration-recovery.test.mjs#CR2-INFRA-RETRY runs once, needs a committed diagnostic and a granted retry, and re-runs the identical frozen selection"
        status: pass
      - kind: unit
        ref: "scripts/ci/ci-registration-recovery.test.mjs#accepted evidence verifies by git ancestry and object reads after a later committed runner change, while a live check still demands the working tree"
        status: pass
    human_judgment: false
  - id: D5
    description: "Committed R2 freeze on the real tree: check exits 0, frozen runner blob equals HEAD's, cf578a567 is an ancestor of checkout_head, halted 253-40 evidence/freeze bytes unchanged and the v1 verify of the halted evidence still exits 3"
    requirement: CIREL-01
    verification:
      - kind: other
        ref: "node scripts/ci/ci-registration-recovery.mjs --check-load-recovery-freeze <R2 freeze> && ! node ... --verify-load-recovery <halted evidence> --stage first (exit 0)"
        status: pass
    human_judgment: false
  - id: D6
    description: "Live behavior of the host-sleep preflight against a real macOS host (caffeinate holder plus pmset snapshot) is not exercised here; only the pmset listing format was read-only checked against real output"
    requirement: CIREL-02
    verification: []
    human_judgment: true
    rationale: "No caffeinate or native window was started by this plan; the first live use is plan 253-51 after Jon's budget decision."
duration: 45min
completed: 2026-10-14
status: complete
---

# Phase 253 Plan 48: R2 load-recovery re-freeze Summary

**Additive R2 revision of the registration runner (carried 2042596 ms / 6 launches / seven spent identities, committed-approval and host-sleep gates, one bounded infrastructure retry) plus a committed R2 freeze pinning the fixed runner; nothing is spendable until 253-51 records Jon's decision.**

## Performance

- **Tasks:** 3 (all offline; no native, Playwright CLI, psql, caffeinate or GitHub action)
- **Files modified:** 3 (runner, runner tests, new R2 freeze)
- **Commits:** 5 task commits plus this SUMMARY commit

## Execution performed (offline only)

- Node 20.18.1 (`ASDF_NODEJS_VERSION=20.18.1 asdf exec node`): `ci-registration-recovery.test.mjs` + `ci-playwright-load.test.mjs` = 105 tests, 105 pass, 0 skipped (baseline was 81; 24 new R2 contracts).
- All host, clock, process, database and git-remote seams are injected in tests. Approval and diagnostic gates are tested against throwaway temp git repositories.
- Read-only `pmset -g assertions` / `pmset -g batt` output on this host was used once to confirm the preflight's listing regex matches real `pid N(caffeinate): [0x..] hh:mm:ss PreventUserIdleSystemSleep named:` lines. No caffeinate was started.
- `scripts/ci/__pycache__` does not exist (no python test was run by this plan).

## Task Commits

1. Task 1 RED: `2bc2e89bf` test(253-48) failing R2 ledger, slot and runner contracts (9 new tests failed on missing exports)
2. Task 1 GREEN: `cd768b602` feat(253-48) additive R2 revision (ledger, slots, history reader, freeze/init/prepare/run/verify routed by exact path)
3. Task 2 RED: `3f9a505a8` test(253-48) failing approval, host-sleep, retry and terminal-binding contracts (12 new tests failed)
4. Task 2 GREEN: `f6a1ad99c` feat(253-48) approval record, host preflight, host_awake verifier, halted_infrastructure and CR2-INFRA-RETRY
5. Task 3: `b141f3013` feat(253-48) committed R2 freeze

## R2 freeze (Task 3)

- File: `.planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-NATIVE-FREEZE-R2.json`
- File sha256: `b26d5a0cbfca38cbdc3fbf4931ce2fd0ba0cfc35df295e4fe820a259eaab43b1`; internal `freeze_sha256`: `0e8d0146879cb9aaaae7579a923966af5b8ffd53e0c026a8ef1854354014b1bb`
- `checkout_head` `f6a1ad99c1fcfa069faf09416f08bcef75fc352a`; frozen runner blob `de8912201e93dcd0f43731b24a6969617b0fc8fd` equals `git rev-parse HEAD:scripts/ci/ci-registration-recovery.mjs`; fixed runner `cf578a567e4c01e6e9e904c2ca8c01bec85345d0` is an ancestor.
- Binds the R2 budget doc sha256 `9bb278db0f990c6bf251118bf8ccb60764ed74e9b99742dbec2be65b7d186461`; `grants_capacity: false`.
- Old lineage unchanged: NATIVE-EVIDENCE.json `ec63a241...` and NATIVE-FREEZE.json `98030037...` re-hashed OK; `--verify-load-recovery` on the halted evidence still exits 3 ("frozen load recovery source identity mismatch"), as does the v1 freeze check.
- Not created here (belong to 253-51 after Jon decides): `253-LOAD-RECOVERY-BUDGET-APPROVAL-R2.json`, `253-LOAD-RECOVERY-NATIVE-EVIDENCE-R2.json`.

## Deviations from Plan

None requiring a rule 1-4 action. Notes for the verifier:

1. **[TDD ordering] Task 2 RED was partial.** Task 1 had to introduce the injectable `readApproval`/`probeHost` hooks (shipped fail-closed) and `verifyFrozenSourceBindingR2`, so three Task 2 contracts (refusal before predebit on missing approval or failed host proof, approval-decides-ceilings, terminal git binding) already passed when written. The other 12 Task 2 tests failed first (observed) and pass now.
2. **[Existing contract] No ordinary test reads real phase records.** An existing test forbids `scripts/ci/ci-registration-recovery.test.mjs` from naming active phase-253 records, so the real-lineage assertions (history reader on the real 253-40 files, v1 reject of the halted evidence) were verified by live CLI/Node commands in Task 3 instead of in the test file. The test file proves the same predicates on synthetic fixtures and temp git repos.
3. **[Routing] Four lines of `main()` were replaced** (the v1 `check/prepare/run/verify-load-recovery` dispatch) with path-routing equivalents; v1 constants, schema literals and functions are byte-identical (diff shows only those four removed lines).
4. `requirements-completed` is left empty: the orchestrator owns requirement tracking and full Phase253 verification stays not_started (same convention as 253-50).

**Total deviations:** 0 auto-fixed. **Impact:** none on scope; no PLAN, STATE, ROADMAP, REQUIREMENTS, config.json or halted-evidence byte touched.

## Known Stubs

None. The Task 1 fail-closed placeholders for the approval and host gates were replaced in Task 2.

## Threat Flags

None beyond the plan's register: T-253-95 (history reader re-hashes the 253-40 evidence, freeze, raw receipts and preserved refs before freeze creation) and T-253-96 (run needs the committed hash-bound approval; reject writes nothing; retry gated by `retry_granted` and single use) are mitigated and tested.

## Remaining gaps

- No native capacity exists: 253-51 must first present the `checkpoint:decision` to Jon (approve / approve-without-retry / reject), record `253-LOAD-RECOVERY-BUDGET-APPROVAL-R2.json`, commit it, then init, prepare and run. Jon's budget approval has NOT been given or recorded here.
- The host-sleep preflight (AC power, caffeinate holder, pmset snapshot) is verified offline with injected pmset output only; its first live execution is the 253-51 native window.
- `readLoadHistoryR2` and `validateLoadRecoveryFreezeR2` depend on the working-tree 253-40 raw receipts and `refs/gsd/phase253-load-recovery-native-evidence/*` preservation refs; terminal verification of accepted evidence uses git objects only.
- Full Phase253 verification: not_started.

## Self-Check: PASSED

- Created freeze file present and committed; runner and test files modified and committed.
- All five task commit hashes are ancestors of HEAD; working tree clean except the byte-pinned `.planning/config.json` (sha256 `8e312f6c...` unchanged).
