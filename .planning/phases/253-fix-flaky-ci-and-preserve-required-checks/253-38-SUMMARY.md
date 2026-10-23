---
phase: 253-fix-flaky-ci-and-preserve-required-checks
plan: "38"
subsystem: testing
tags: [ci-reliability, load-recovery, hermetic-fixtures, process-teardown]
requires:
  - phase: 253
    provides: registration native receipt verifier and runner (plans 15-37)
provides:
  - createRegistrationNativeTreeFixture (labeled synthetic committed-tree/native-receipt fixture)
  - clean-candidate runner contracts (node --test and shell) needing no .planning records, refs, server, DB, browser or network
  - read-only accepted-only --verify-saved-native audit mode
  - runLoggedTree that reaps SIGTERM-resistant descendants
affects: [253 native recovery plans, WINDOWS entry 11]
actuals:
  tokens: 21000
  tasks: 2
  commits: 4
plan_head_before: 3a965cae2aab623f7c217c50da0ba2d5f776ab03
plan_head_after: da586d13ffd7e5ada9a61bc98d6107830044c8c6
tech-stack:
  added: []
  patterns: ["temp committed-tree fixture with fixture-owned git identity", "injected connect/probe/clock seams", "directory-event readiness instead of sleeps"]
key-files:
  created:
    - scripts/ci/fixtures/registration-native-tree.mjs
  modified:
    - scripts/ci/ci-registration-recovery.mjs
    - scripts/ci/ci-registration-recovery.test.mjs
    - scripts/ci/ci-registration-repro.sh
    - scripts/ci/ci-registration-repro.test.sh
key-decisions:
  - "assertDirtyConfigPreserved applies its exact SHA-256/blob/ref rule only when the checkout carries a change to the config; the identity is injectable for fixtures. Run-mode checkout rules (assertRevisionCheckout) stay strict."
  - "Synthetic evidence is rejected by --verify-saved-native via the provenance marker and via the example.invalid Git identity of the frozen commit, so stripping the marker is not enough."
  - "Native project inventory must contain all three admin-eval projects; project/title comparisons are exact well-formed UTF-8."
  - "runLoggedTree no longer cancels SIGKILL when the leader exits first; it polls the owned group to ESRCH within a bounded limit."
requirements-completed: ["CIREL-01", "CIREL-02"]
coverage:
  - id: D1
    description: "Both inherited commands pass from a clean temporary candidate with .planning removed"
    requirement: CIREL-01
    verification:
      - kind: unit
        ref: "ASDF_NODEJS_VERSION=20.18.1 node --test scripts/ci/ci-registration-recovery.test.mjs (46/46, clean clone at da586d13f, no .planning)"
        status: pass
      - kind: integration
        ref: "bash scripts/ci/ci-registration-repro.test.sh (clean clone, exit 0)"
        status: pass
    human_judgment: false
  - id: D2
    description: "Cumulative/source/receipt corruption rejected for its own predicate; owned child and SIGTERM-resistant grandchild both gone"
    requirement: CIREL-02
    verification:
      - kind: unit
        ref: "scripts/ci/ci-registration-recovery.test.mjs#revision CLI rejects forged, mismatched, duplicated, and over-budget saved receipts"
        status: pass
      - kind: unit
        ref: "scripts/ci/ci-registration-recovery.test.mjs#abort escalates to SIGKILL for a SIGTERM-resistant grandchild after the child exits first"
        status: pass
    human_judgment: false
duration: 70min
completed: 2026-10-14
status: complete
---

# Phase 253 Plan 38: Hermetic registration runner contracts Summary

**Registration runner contracts now run from a temporary committed tree with labeled synthetic receipts and recording native-command stubs, and runLoggedTree escalates to SIGKILL until the whole owned process group is gone.**

## Task Commits

1. Task 1 RED: `0be001b7a` (test); GREEN: `09f0bd008` (feat)
2. Task 2 RED: `a1b630211` (test); GREEN: `da586d13f` (feat)

## Accomplishments

- Fixture builds a git repo (fixture identity `@example.invalid`), commits the real runner copies plus placeholder bound sources, and writes consistent synthetic freeze/evidence/logs/native reports with mutation helpers.
- Dirty-config requirement dropped for clean candidates; seams for port availability and readiness remove all sockets from ordinary tests (a global net guard asserts none).
- Corruption table (28 cases) covers blob/head/digest/monotonic/spent-slot/title/project/report/exit/preparation/launch/total-charge/historical-charge/inventory; each case asserts its own reason and a positive control.
- `--verify-saved-native` (read-only, accepted-only) declared in runner and shell; real saved receipt 253-15 still audits OK (2/2, 121680 ms); not invoked by any workflow or ordinary test.
- Clean-candidate run (clone at `da586d13ffd7e5ada9a61bc98d6107830044c8c6`, `.planning` removed, Node 20.18.1): node tests exit 0, 46 tests, 46 pass; shell test exit 0. Root may use this receipt to close WINDOWS entry 11; this plan did not edit WINDOWS.md.

## Deviations from Plan

- [Scope] The positive `--create-infrastructure-retry` CLI assertion (which read active phase records) was replaced by negative clean-candidate cases; positive history verification is covered by the audit mode run manually. 
- [Scope] `ci-registration-setup-diagnostic.test.mjs` (outside declared files) is still invoked by the shell test; its fake `mix phx.server` uses a loopback server inside that separate process. Left unchanged.
- [Rule 2] Added `signal` option, `pid`, `group_signals`, `descendants_reaped` to runLoggedTree results to make teardown provable without sleeps.

## Issues Encountered

A shell-test label assertion and one hang during parallel background runs were test-side; fixed. No native, GitHub or browser work performed.

## Known Stubs

None.

## Next Phase Readiness

Full Phase253 verification remains not_started until root runs the unfiltered phase gates.

## Self-Check: PASSED
