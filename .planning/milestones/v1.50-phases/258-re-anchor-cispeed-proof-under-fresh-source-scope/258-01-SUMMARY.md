---
phase: re-anchor-cispeed-proof-under-fresh-source-scope
plan: "01"
subsystem: ci
tags: [phase258, source-refreeze, predecessor-accounting]
requires: []
provides:
  - Fresh source receipt binding the retained exact candidate/control pair to the current controller implementation.
  - Predecessor reconciliation with explicit unknown-workload and finite lifetime bounds.
affects: [258-02, CISPEED-01, CISPEED-02]
actuals:
  tasks: 2
  commits: 0
key-files:
  created:
    - .planning/execution/258/SOURCE-REFREEZE.json
    - .planning/execution/258/BUDGET-RECONCILIATION.json
  modified: []
requirements-completed: []
coverage: [CISPEED-01, CISPEED-02]
completed: 2026-11-06
status: complete
---

# Phase 258 Plan 01: Source and budget re-anchor

## Outcome

Plan01 completed as local-only work. It created a new source-refreeze receipt and independently rechecked all predecessor request and budget records. No network requests, mutations, claims, workloads, or samples were created.

## Source result

The production Phase256 source reader passed for the exact retained control `37f1b551d0cfb990a49e6b1b21e6cecaf538dfe0` and candidate `5effabe754c74fcd3086128ae9ce2e01ae07ab79` commits. Both clean Git archives were compared file-by-file with their exact tree blobs (3,268 entries each). The candidate-only treatment matched the approved semantics. The pair is explicitly reused from Phase256; no Phase257 source bytes or claim were reused.

The missing Phase257 controller SHA `b9f9beaf…` remains unavailable. A complete local Git object scan covered 10,844 commits and 29 versions of the pinned file path with no hash match. The current controller hash is recorded in `SOURCE-REFREEZE.json`. The reservation-ordering production regression passed.

## Budget result

The production Phase257 predecessor reader independently reproduced the blocked terminal receipt: 12 source-bound GETs, zero known mutations, zero known runner minutes, and workload `null`. The full counter reconciliation adds 143 read-only forensic GETs, for 155 prior transport GETs. Phase257 workload remains unknown and is bounded at one prior workload and up to 280 runner timeout-job minutes.

The unchanged experiment needs up to 24,503 new requests and 42 new workloads. Including all predecessor GETs and the unknown prior workload gives lifetime maxima of 24,658 requests and 43 workloads, respectively 144 requests and one possible workload above the former aggregate ceiling. Mutations remain at the former maximum of 83. This increase is recorded for the Phase258 proposal and requires its exact approval before any hosted action.

## Verification

- Production source verifier: passed; source/tree/treatment bindings re-read.
- Production predecessor verifier: blocked for the expected missing historical controller bytes; the unknown workload remains null.
- Focused reservation/intent ordering regression: 1 test passed with a 60-second timeout.
- Receipt integrity and every bound input hash: recomputed and passed.
- Hosted requests, mutations, claims, workloads, and acceptance samples: 0.

## Next action

Plan258-02 is the next local-only step. It must add and test the Phase258 proposal, exact-consent authorizer, bounded execution adapters, and independent readers. The user does not need to act until a complete proposal is produced for one exact approval.

## Bound artifacts

- Plan SHA-256: `232b239f6f09da8ae5d04765451c6ffd5e4772385eba995a2619df008b7f5b80`
- Source-refreeze integrity SHA-256: `c0c61de1b285aab0556d5ff974df9368ba6f828c864c58b2f959e26a51288670`
- Budget-reconciliation integrity SHA-256: `12e9b0a78f9398c4bf7c25a5b2aa34349894604aa163e9ea7b44a600317250d5`
