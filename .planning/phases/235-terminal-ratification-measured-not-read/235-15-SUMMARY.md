---
phase: 235-terminal-ratification-measured-not-read
plan: 15
subsystem: ci
tags: [github-actions, sigstore, attestation, performance, tdd]

requires:
  - phase: 235-08
    provides: protected terminal measurement, 93-row ownership proof, and the honest FAST-01 miss
provides:
  - one attested 43-row derived post-remediation candidate with stored p50 466 seconds
  - hardened network-denied exact-subject verification with separate provenance and population mutations
  - durable diagnosis of the signed source-data gap preventing FAST-01 closure
affects: [phase-235-gap-closure, ci-performance, protected-evidence]

actuals:
  tokens: 28000
  tasks: 2
  commits: 9

tech-stack:
  added: []
  patterns: [fixed-path offline attestation verification, fail-closed evidence reconciliation]

key-files:
  created:
    - .planning/phases/235-terminal-ratification-measured-not-read/235-FAST-01-GAP-CLOSURE-REMEASUREMENT.json
    - .planning/phases/235-terminal-ratification-measured-not-read/235-FAST-01-GAP-CLOSURE-REMEASUREMENT.attestation.jsonl
    - .planning/phases/235-terminal-ratification-measured-not-read/235-FAST-01-GAP-CLOSURE-REMEASUREMENT-TRUSTED-ROOT.jsonl
    - scripts/ci/verify-fast-01-gap-closure-attestation-offline.sh
  modified:
    - test/sigra/planning/phase_235_fast_01_gap_closure_contract_test.exs
    - .planning/REQUIREMENTS.md
    - .planning/todos/pending/2026-08-02-fast-01-terminal-p50-miss.md

key-decisions:
  - "Did not complete FAST-01 from a derived 466-second p50 because the signed subject omitted timestamps and pagination/exhaustion data required for independent source-population verification."
  - "Preserved the 772- and 724-second misses plus the 692-to-148-second Library and 724-to-470-second wall remediation as immutable history."
  - "Made no second dispatch because this plan permits exactly one attempt and forbids rerolling an insufficient evidence result."

patterns-established:
  - "Retained trusted roots are digest-pinned before custom-root verification."
  - "Provenance mutations and semantic population mutations exercise separate validation gates."
  - "A statistically passing derived receipt remains non-authoritative when signed source rows cannot prove membership, chronology, duration, and pagination."

requirements-completed: [GATE-05]

coverage:
  - id: D1
    description: "The exact protected subject authenticates and its 43 derived rows canonically recompute to stored p50 466 seconds."
    requirement: FAST-01
    verification:
      - kind: integration
        ref: "scripts/ci/verify-fast-01-gap-closure-attestation-offline.sh"
        status: pass
      - kind: unit
        ref: "test/sigra/planning/phase_235_fast_01_gap_closure_contract_test.exs#independently derives canonical population, poles, and strict 719/720/721 verdicts"
        status: pass
    human_judgment: false
  - id: D2
    description: "FAST-01 remains open because the signed candidate lacks timestamps and authenticated pagination/exhaustion data needed for independent proof."
    requirement: FAST-01
    verification:
      - kind: other
        ref: ".planning/phases/235-terminal-ratification-measured-not-read/235-REVIEW.md#CR-02"
        status: fail
    human_judgment: false
  - id: D3
    description: "GATE-05 remains independently Complete with its original protected run, exact requirement records, verifier, and digest-pinned evidence unchanged."
    requirement: GATE-05
    verification:
      - kind: integration
        ref: "scripts/ci/verify-terminal-ratification-attestation-offline.sh"
        status: pass
      - kind: unit
        ref: "test/sigra/planning/phase_235_fast_01_gap_closure_contract_test.exs#derived pass stays open without signed source rows and leaves GATE-05 byte-exact"
        status: pass
    human_judgment: false

duration: 36 min
completed: 2026-09-08
status: halted
---

# Phase 235 Plan 15: FAST-01 Gap Closure Summary

**One protected candidate attests 43 derived rows and stored p50 466 seconds, but FAST-01 remains open because the signed subject cannot independently prove the source population.**

## Performance

- **Duration:** 36 min
- **Started:** 2026-09-08T20:00:31Z
- **Completed:** 2026-09-08T20:36:00Z
- **Tasks:** 2 attempted; designed halt reached after code review
- **Files modified:** 11

## Accomplishments

- Retained exactly one protected-main candidate subject, attestation, and trusted root without rerolling the observed result.
- Hardened offline verification with a pinned trust-root digest, distinct provenance/semantic mutation gates, canonical ordering, historical disjointness, strict p50 recomputation, and complete terminal-conclusion support.
- Reopened FAST-01 and preserved its residual when review proved the signed subject lacks the raw fields required for independent window, wall-time, and completeness verification; GATE-05 remains byte/digest pinned.

## Task Commits

1. **Task 1 readiness:** `196cabe4` (chore)
2. **Task 1 prerequisite diagnostic:** `0814649d` (docs)
3. **Task 1 protected candidate and initial verification:** `b5fc9389` (feat)
4. **Task 2 RED reconciliation contract:** `db5511e8` (test)
5. **Task 2 attempted GREEN reconciliation:** `817e3033` (feat)
6. **Plan summary before review:** `252711fd` (docs)
7. **Offline validation hardening:** `9a5ced28` (fix)
8. **Immutable GATE-05 evidence pinning:** `5c5910fa` (test)
9. **Honest FAST-01 gap restoration:** `4f869877` (fix)

## Files Created/Modified

- `.planning/phases/235-terminal-ratification-measured-not-read/235-FAST-01-GAP-CLOSURE-READINESS.json` - Retains the single non-authoritative readiness probe.
- `.planning/phases/235-terminal-ratification-measured-not-read/235-FAST-01-GAP-CLOSURE-REMEASUREMENT.json` - Stores the attested candidate's derived rows and result.
- `.planning/phases/235-terminal-ratification-measured-not-read/235-FAST-01-GAP-CLOSURE-REMEASUREMENT.attestation.jsonl` - Retains exact-subject Sigstore provenance.
- `.planning/phases/235-terminal-ratification-measured-not-read/235-FAST-01-GAP-CLOSURE-REMEASUREMENT-TRUSTED-ROOT.jsonl` - Retains digest-pinned trust material.
- `scripts/ci/verify-fast-01-gap-closure-attestation-offline.sh` - Verifies available provenance and derived-row contracts without network access.
- `test/sigra/planning/phase_235_fast_01_gap_closure_contract_test.exs` - Recomputes derived-row semantics and enforces fail-closed requirement status.
- `.planning/REQUIREMENTS.md` - Keeps FAST-01 at Gaps Found and GATE-05 Complete.
- `.planning/todos/pending/2026-08-02-fast-01-terminal-p50-miss.md` - Records why the candidate cannot close the residual.

## Decisions Made

- Cryptographic provenance of derived output is insufficient for this plan's independent-source requirement when the signed bytes omit `created_at`, `updated_at`, page identities/counts, and exhaustion.
- A later gap plan must correct the protected evidence schema before dispatch; it must not reinterpret or replace this attempt.
- Erlang 28.4.1 was selected only through process-local ASDF overrides because repository-requested 28.5 is not installed; `.tool-versions` remains untouched.

## Deviations from Plan

### Auto-fixed Issues

1. The unavailable Erlang 28.5 prerequisite was resolved with a process-local 28.4.1 override; all focused planning tests passed.
2. Stale local `origin/main` prevented the planned pre/post set-difference selector from matching; no redispatch occurred, and the sole returned run was bound through its one structured summary and attestation.
3. Code review found an unpinned custom trust root, signature-only semantic mutations, an incomplete terminal-conclusion validator, and weak GATE-05 immutability checks; all four repairable issues were fixed and reverified.

**Impact on plan:** The remaining signed-source omission is not repairable from existing bytes and a second dispatch is prohibited. The plan halted without claiming FAST-01.

## Issues Encountered

- **Blocking:** The attested receipt discarded timestamps and pagination/exhaustion evidence. Offline consumers cannot independently prove membership, duration, chronology, or completeness. See `235-REVIEW.md` CR-02.
- Expected errors printed by adverse attestation cases are part of the passing verifier contract.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Blocked. A new gap plan must change the protected evidence subject to retain raw timestamps and authenticated pagination/exhaustion evidence, land that producer change on protected main, then perform one newly authorized measurement. This plan must not be resumed or redispatched.

## Self-Check

HALTED AS DESIGNED: one critical code-review finding remains durable; FAST-01 is unchecked/Gaps Found; GATE-05 and both historical misses are intact; no second dispatch occurred.

---
*Phase: 235-terminal-ratification-measured-not-read*
*Completed: 2026-09-08*
