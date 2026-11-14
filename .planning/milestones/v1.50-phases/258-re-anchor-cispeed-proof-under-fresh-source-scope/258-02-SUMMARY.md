---
phase: re-anchor-cispeed-proof-under-fresh-source-scope
plan: "02"
subsystem: ci
tags: [phase258, proposal, source-proof, bounded-execution]
requires: [258-01]
provides:
  - Production Phase258 proposal builder and independent local verifier bound to the final source snapshot.
  - Isolated regressions for Phase256 closure schema, exact proposal source binding, and absent authority reporting.
  - Exact bounded proposal ready for explicit approval; no authority or claim created.
affects: [258-03, CISPEED-01, CISPEED-02]
actuals:
  tasks: 2
  commits: 0
key-files:
  created:
    - .planning/execution/258/PREP-CONTRACT.json
    - .planning/execution/258/PREP-PROPOSAL.json
    - .planning/recovery/opengsd-health-20261106/phase258-local-validation-04/LOCAL-CHECKS.json
    - .planning/recovery/opengsd-health-20261106/phase258-proposal-final-01/LOCAL-PROPOSAL-VERIFICATION.json
  modified:
    - scripts/ci/ci-repaired-comparison.py
    - scripts/ci/ci-repaired-comparison.test.py
    - .planning/execution/258/SOURCE-REFREEZE.json
    - .planning/execution/258/BUDGET-RECONCILIATION.json
requirements-completed: []
coverage: [CISPEED-01, CISPEED-02]
completed: 2026-11-06
status: complete
---

# Phase 258 Plan 02: Proposal and local execution safeguards

## Outcome

Plan02 is complete as local-only work. The Phase258 proposal is source-bound, passes its independent production verifier, and is ready for an exact approval decision. It created no approval, authorization, one-shot claim, request ledger, network request, mutation, workload, or measurement sample.

The exact proposal is [PREP-PROPOSAL.json](../../execution/258/PREP-PROPOSAL.json), SHA-256 `7d049f4b666431c84a47eb1f423c3b23f8317f7f663dd7ed1365336974889b94`. Its contract is [PREP-CONTRACT.json](../../execution/258/PREP-CONTRACT.json). The final production verifier receipt is [LOCAL-PROPOSAL-VERIFICATION.json](../../recovery/opengsd-health-20261106/phase258-proposal-final-01/LOCAL-PROPOSAL-VERIFICATION.json).

## Recovered defects

- Phase257's reservation timestamp was valid, but its validator required exact timestamp equality. The first request intent followed the persisted reservation by 769 microseconds. The validator now accepts `reservation <= first intent < fixed deadline` and rejects a backwards clock before I/O; its focused regression passes.
- The Phase258 preflight initially expected `status: complete`, which the real Phase256 object-closure schema does not contain. The check now verifies the actual schema, exact candidate/control commits and trees, local-only marker, positive object count, and zero workspace Git writes, then replays the production publisher source proof.
- The proposal builder omitted the source-snapshot digest required by its frozen-proposal verifier. The builder now includes it, with a producer regression.
- The local verifier used `bool([False, False, False])`, which reported authorization and claim as present even when all three files were absent. It now uses `any(present)` and has a zero-authority regression.

The failed local proposal output and the later superseded proposal were preserved byte-for-byte with integrity receipts under `.planning/recovery/opengsd-health-20261106/`. Neither created authority or incurred spend. The active proposal was rebuilt only after code and source receipts were frozen to the final implementation.

## Scope and limits

The proposal reuses the independently checked Phase256 source pair: candidate `5effabe754c74fcd3086128ae9ce2e01ae07ab79` and control `37f1b551d0cfb990a49e6b1b21e6cecaf538dfe0`. The fixed comparison remains 40 families and 20 pairs.

The bounded scope requests at most 503 preparation GETs and one preparation workload, then at most 24,000 comparison GETs and 41 comparison workflows. Including all 155 predecessor GETs and the possible prior Phase257 workload, the lifetime ceilings are 24,658 GETs, 83 mutations, 43 workloads, and 12,040 runner timeout-job minutes. This is 144 GETs and one possible workload above the former aggregate caps. Retries, reruns, and renewals are zero for preparation; preparation has a 45-minute window and a 2,700-second hard timeout. No merge or release is authorized.

Because this exceeds the previous aggregate request and workload ceilings, Plan258-03 remains gated on approval of this exact proposal. CISPEED-01 and CISPEED-02 remain open; no performance result has been measured.

## Verification

- Focused local suite: 26 tests passed under 60-second per-command timeouts; Python syntax checks passed.
- Production `phase258-propose`: passed and wrote the exact contract/proposal.
- Production `phase258-verify-local`: `ready_for_consent`; confirmed zero authorization, claims, requests, mutations, workloads, and samples.
- Candidate source proof: replayed through the production publisher against the retained object repository.
- No hosted action, remote ref update, CI dispatch, merge, or release occurred.

The detailed test receipt is [LOCAL-CHECKS.json](../../recovery/opengsd-health-20261106/phase258-local-validation-04/LOCAL-CHECKS.json). The current source and budget receipts bind the exact final controller and test hashes. The prior receipts remain recoverable from the recorded write-ahead preservation copies.

## Next action

No Phase258 execution command is active while the exact proposal awaits approval. If the user approves it, the conditional command is `$gsd-execute-phase 258 --wave 3`. Until then, Plan258-03 must not create authorization or perform hosted work. The phase requirements remain open.

No commit was created because `.git` is read-only in this workspace.
