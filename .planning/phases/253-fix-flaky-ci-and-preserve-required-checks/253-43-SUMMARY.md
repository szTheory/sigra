---
phase: 253-fix-flaky-ci-and-preserve-required-checks
plan: "43"
subsystem: ci-reliability
tags: [gsd-sdk, accepted-only, historical-disposition, load-recovery]
status: complete
requires:
  - phase: 253-42
    provides: strict completion verifier mode in scripts/ci/ci-hosted-gate-verify.py
provides:
  - phase-local accepted-only SDK reconciliation helper with an installed-SDK identity pin
  - reconciliation contract naming all 35 originals, 11 completed, 6 halted and 18 unstarted responsibilities
  - root-only write-ahead application path that cannot run without real strict completion acceptance
affects: [253-47, root whole-phase verification]
actuals:
  tokens: 40000
  tasks: 2
  commits: 4
plan_head_before: 7b9e3b844b3b3c188261eef03cdc93b89c292a9b
plan_head_after: c1ec712724d99b9ec7345eac1dc5c7d4dd433356
tech-stack:
  added: []
  patterns:
    - temporary committed-repository tests against the real gsd-tools subprocess
    - injected fixture verifier is API-only; the CLI always runs the real strict checker
key-files:
  created:
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-reconcile.mjs
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-reconcile.test.mjs
    - .planning/phases/253-fix-flaky-ci-and-preserve-required-checks/253-LOAD-RECOVERY-RECONCILIATION-CONTRACT.json
  modified: []
key-decisions:
  - "The CLI never accepts a verifier override; only in-process fixture tests can inject one, and such bundles carry verifier.kind injected-fixture and are refused without an explicit fixture flag."
  - "Routing follows the installed workflow's has_summary-first filtering; inherited blocked_by on summarized history is reported, not hidden."
requirements-completed: []
coverage:
  - id: D1
    description: "Installed SDK pairing for absent, blocked, halted and superseded summaries is executable and source-pinned"
    requirement: "CIREL-01"
    verification:
      - kind: integration
        ref: "253-LOAD-RECOVERY-reconcile.test.mjs#summary pairing through the real SDK"
        status: pass
    human_judgment: false
  - id: D2
    description: "Open or forged completion evidence creates zero disposition bytes"
    requirement: "CIREL-02"
    verification:
      - kind: integration
        ref: "253-LOAD-RECOVERY-reconcile.test.mjs#accepted-only predicate"
        status: pass
    human_judgment: false
  - id: D3
    description: "Eighteen responsibility mappings and root-only write-ahead application, tested against a copy of the real plan set"
    verification:
      - kind: integration
        ref: "253-LOAD-RECOVERY-reconcile.test.mjs#root-only write-ahead application"
        status: pass
      - kind: other
        ref: "node 253-LOAD-RECOVERY-reconcile.mjs --prepare-contract --output 253-LOAD-RECOVERY-RECONCILIATION-CONTRACT.json --check-only"
        status: pass
    human_judgment: false
  - id: D4
    description: "Real accepted completion, applied dispositions and the unfiltered whole-phase verification run"
    verification: []
    human_judgment: true
    rationale: "Not performed here. Needs live canary and PR proof from 253-44..47 plus root application; fixture acceptance is never live acceptance."
duration: 40min
completed: 2026-10-14
---

# Phase 253 Plan 43: Accepted-only SDK reconciliation Summary

**A phase-local helper and contract that can summarize the eighteen never-started old plans as `superseded` / `execution_performed: false` only after the real strict completion checker accepts every linked proof, with the installed gsd-core 1.16.0 pairing and execute-phase routing reproduced in tests.**

## Performance

- **Duration:** about 40 min
- **Started:** 2026-10-14T02:45:00Z (approximate)
- **Completed:** 2026-10-14T03:26:00Z
- **Tasks:** 2 (both TDD: RED then GREEN)
- **Files created:** 3

## Task Commits

1. **Task 1 (tracer): installed-SDK pairing, routing, accepted-only predicate**
   - RED `050f69188` (`RED_EVIDENCE_OK`, target `pins the observed package, version and every consulted source hash`; 10 of 11 failed on a null-answering skeleton)
   - GREEN `567f14c8a` (11 of 11 pass)
2. **Task 2: contract, bundle, write-ahead application**
   - RED `677376f5f` (`RED_EVIDENCE_OK`; 12 of 23 failed)
   - GREEN `c1ec71272` (23 of 23 pass; `--prepare-contract --check-only` exits 0)

The tracer gate ran in the default interactive `end-of-phase` mode with an automated-only verify: re-ran the tracer verify, it passed, expansion continued.

## What the real SDK does (observed, and pinned by tests)

- `plan-scan` and `phase-plan-index` drop `status: blocked` summaries from pairing (plan stays incomplete); `halted` and `superseded` summaries pair. A superseded disposition is not `halted`.
- Halt propagation is untouched by a disposition: a summarized plan keeps its inherited `blocked_by` (for example `253-08` keeps `["253-02","253-07"]`), and the six halted plans stay literally `halted`.
- SDK discrepancy found: `init.execute-phase` counts a `status: blocked` summary as summarized (not in `incomplete_plans`) while `phase-plan-index` does not. Recorded as `init_disagrees` in `pairingReport`; no disposition here uses `blocked`, so it does not affect the route.
- Installed `execute-phase.md` filters `has_summary` first. With no unsummarized plan the route is `verification status` route `execute-phase`, i.e. `resume_phase_gates` with `$gsd-execute-phase 253`. Before dispositions the same filter yields `phase_stuck`. A filtered run (`--gaps-only` or wave) never reaches verification. The workflow text it reproduces is pinned by 9 literal fragments plus its SHA-256.
- SDK identity pinned: `@opengsd/gsd-core` 1.16.0 and 7 source hashes, all matching the planning audit.

## Contract

`253-LOAD-RECOVERY-RECONCILIATION-CONTRACT.json` (sha256 `5eba0fad1a70ae70d073ac4d4c1d4cc4ab09d1c919e8f3a7f9b6e0daf5c1dfd5`):
all 35 original PLAN SHA-256s cross-checked against the audit inventory and the planning capture blobs (read back via `git cat-file`), 11 completed and 6 halted summaries with receipt hashes, and the mapping
08/13/21/30/34 to 42+46, 24 to 46, 10/17/28/29 to 36-41, 14/25/31/35 to 43+47, 22/32 to 44, 23/33 to 45; halted 02/09/16/27 proof to 36-41 and 07/12 proof to 18-20, 42, 44, 45.

## Application path (root only, not run)

`--dry-run`, `--prepare-dispositions`, `--apply-bundle`, `--check-index 253` all take `--root`. The bundle is built only when the real `ci-hosted-gate-verify.py --mode completion --require-accepted` exits 0 with eight links and both requirements accepted; each required link is re-opened by hash. Apply re-derives the bundle byte for byte, requires proof-owner summaries (including 253-47), snapshots dirty tracking, writes a journal before any write, creates files exclusive-create with readback, rolls back only its own files on failure, and rechecks originals, halted summaries and pre-existing dirty paths.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Supplied project-root pin guard cannot pass verbatim**
- **Found during:** pre-write guard
- **Issue:** the orchestrator substituted the real root into the guard's `pin-unbound` sentinel arm, so the guard fails closed on a correct checkout.
- **Fix:** ran an otherwise identical guard whose sentinel is the literal `{PINNED_ROOT}`; same root equality check against the supplied pin. Result `PIN_OK` before every write and commit.
- **Files modified:** none (scratch script outside the repository)

**2. [Rule 3 - Blocking] RED evidence uses a skeleton module**
- **Found during:** Task 1 and Task 2 RED
- **Issue:** a missing import would be `fixture_or_load_failure`, not valid RED.
- **Fix:** RED commits include a null-answering skeleton of the helper so tests fail on assertions; GREEN replaces it.
- **Commit:** `050f69188`, `677376f5f`

**Total deviations:** 2 (both Rule 3, process only). **Impact:** none on product behavior.

## Authentication Gates

None.

## Known Stubs

None. No placeholder text or hardcoded empty data in the delivered files.

## Issues Encountered

- `execute-phase.md` is prose. The `has_summary`-first reading is the one the plan specified, but an agent that reports skipped plans independently could list summarized plans with inherited `blocked_by` as blocked and stop at "Phase stuck". `routeExecutePhase` exposes `inherited_blocked_on_summarized` so root can see this. If root's real run reports stuck, treat it as a durable SDK blocker; do not edit old plans or fake summaries.

## Remaining Gaps

- No live acceptance exists. The fixture verifier proves the application mechanics only; it is never evidence for CIREL-01 or CIREL-02.
- The eighteen dispositions are not generated and not applied. Root runs them after 253-47's SUMMARY and a real accepted completion record exists.
- The real `--check-index 253` currently reports `ok:false` (27 unsummarized plans, 18 of them old) as expected.
- Native and GitHub work: none performed (0 commands, 0 requests). Full Phase 253 verification stays `not_started`.
- Shared tracking (STATE, state.json, ROADMAP, REQUIREMENTS) was not touched; `.planning/config.json` stays the pinned uncommitted edit.

## Next Phase Readiness

Ready for 253-47 to call `--prepare-dispositions` once its completion evidence is accepted, then root applies the bundle, commits, re-runs `--check-index 253`, and runs the unfiltered `$gsd-execute-phase 253`.

## Self-Check: PASSED

- Files exist: the helper, its test file and the contract (checked after commit).
- Commits `050f69188`, `567f14c8a`, `677376f5f`, `c1ec71272` are ancestors of HEAD; measured count 4 from the plan ledger base `7b9e3b844`.
- `node --test` 23 of 23 pass; `--prepare-contract --check-only` exits 0.

---
*Phase: 253-fix-flaky-ci-and-preserve-required-checks*
*Completed: 2026-10-14*
