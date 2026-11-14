---
phase: 254-speed-up-the-measured-slow-jobs
plan: "06"
subsystem: ci-measurement
tags: [github-actions, comparison, provenance, native-coverage, request-budget]

requires:
  - phase: 254-02
    provides: Source-bound native coverage comparator and owner inventory
provides:
  - Frozen comparison schedule and early outcome-blind registration checks
  - Raw attempt/job cost and required-check wait derivation
  - Shared bounded request accounting for comparison collection
  - Independent registered-family origin verification and native parity evaluation
affects: [254-07, hosted-comparison-acceptance]

actuals:
  tokens: 31267
  tasks: 3
  commits: 6

tech-stack:
  added: []
  patterns: [append-only request budget, raw-family metric derivation, source-bound parity]

key-files:
  created: []
  modified:
    - scripts/ci/ci-run-metrics.sh
    - scripts/ci/ci_metrics_security.py
    - scripts/ci/ci-metrics-security.test.py
    - scripts/ci/ci-run-metrics-comparison.test.sh
    - scripts/ci/ci-hosted-gate-verify.py
    - scripts/ci/ci-hosted-gate-verify.test.py

key-decisions:
  - "Collection stops before network access until the frozen contract points to a hash-checked 108-row native coverage map for all five owners."
  - "Historical Phase252 replay keeps its prior output shape; comparison-only identities are emitted only for explicitly marked comparison snapshots."
  - "A comparison can be accepted only after all forty family origins and all one hundred pair-owner parity comparisons validate."

patterns-established:
  - "Derive every family cost from hash-bound raw attempt jobs and check runs; unknown timestamps remain unknown."
  - "Keep archive-relative native report paths while retaining a confined legacy lookup for Phase252 artifacts that were flattened."

requirements-completed: []
requirements-supported: [CISPEED-01, CISPEED-02]

coverage:
  - id: D1
    description: "The existing comparison CLI enforces the frozen twenty-pair schedule, balanced order, pair proximity, and early registrations."
    requirement: CISPEED-01
    verification:
      - kind: unit
        ref: scripts/ci/ci-metrics-security.test.py
        status: pass
      - kind: integration
        ref: scripts/ci/ci-run-metrics-comparison.test.sh
        status: pass
    human_judgment: false
  - id: D2
    description: "Comparison waits and runner totals are derived from every retained attempt, including failed work, and threshold outcomes distinguish pass, miss, and insufficient data."
    requirement: CISPEED-02
    verification:
      - kind: integration
        ref: scripts/ci/ci-run-metrics-comparison.test.sh
        status: pass
    human_judgment: false
  - id: D3
    description: "Synthetic raw families traverse the collector-shaped replay, independent origin verifier, all five native owners, exact parity comparator, and evaluator."
    requirement: CISPEED-01
    verification:
      - kind: integration
        ref: scripts/ci/ci-run-metrics-comparison.test.sh
        status: pass
      - kind: unit
        ref: scripts/ci/ci-hosted-gate-verify.test.py
        status: pass
    human_judgment: false

estimate:
  tokens: 23018
  raw_tokens: 32000
  tasks: 3
  confidence: high
commits: 6
plan_head_before: 0e937358cf1cbb08999dca55b6d1e511ea854919
plan_head_after: 162b8e5444db96405fc1fd2e3ae4a9ebf258d184
duration: 40min
completed: 2026-10-23
status: complete
---

# Phase 254 Plan 06: Measured comparison collection Summary

**The existing comparison path now binds scheduled families to raw run evidence, accounts for all attempt costs, and checks origin plus exact native work before it can report a speed result.**

## Accomplishments

- Added frozen-order schedule validation and strict pair-start proximity checks. Each of the twenty pairs has one baseline and one candidate family, with alternating order and outcome-blind registration before final results are read.
- Derived required-check wait and runner seconds from retained run, check, and all-attempt job files. Failed and cancelled jobs count; missing or malformed timestamps produce unknown costs with the known subtotal and missing job IDs.
- Added durable shared HTTP request accounting with a 600-request and sixty-minute ceiling, core stop at 250, hard stop on 403/429, and one counted transient retry. The collector acquires only registered run IDs through the existing collection path.
- Added `comparison-family` mode to the existing hosted-gate verifier. It binds each raw run to its registration, PR head/base, all attempt job receipts, the five required successful checks, and digest-verified artifacts.
- Connected evaluation to the existing native coverage comparator. It checks all twenty pairs across five owners, preserves nested native report paths, and refuses to accept missing maps or descriptors.
- Kept Phase252 replay output byte-compatible while adding comparison-only source identities to marked comparison snapshots.

## Verification

- `python3 -B scripts/ci/ci-metrics-security.test.py` — 19 tests passed.
- `bash scripts/ci/ci-run-metrics-comparison.test.sh` — passed. The end-to-end fixture ran forty origin checks and one hundred pair-owner parity comparisons; it covered a passing result, median-only miss, nearest-rank p95-only miss, runner-cost-only miss, exact median threshold equality, and insufficient data.
- `node --test scripts/ci/ci-run-metrics-replay.test.mjs scripts/ci/ci-browser-records.test.mjs` — 34 tests passed.
- `python3 -B scripts/ci/ci-hosted-gate-verify.test.py` — 152 tests passed.
- `bash scripts/ci/ci-run-metrics.test.sh` — 48 tests passed.
- The immutable Phase252 baseline verifier returned `ready` with no diagnostics.
- No hosted acceptance runs or live GitHub acquisition were performed.

## Integration Gate for Plan 07

The committed Phase254 workload inventory is selection-only and uses a different schema from the comparator input. It does not contain the five-part native identities and executed candidate outcomes needed for a valid `sigra.browser-coverage-map/v1` map. The comparison collector therefore stops before network access unless the contract supplies a hash-matched map with all 108 identities across the five owners. Plan 07 must generate or update the owned workload map from actual source-bound native reports and add its path and digest to the execution contract. CISPEED-01 and CISPEED-02 are supported by the tooling but remain uncompleted until that map exists and the authorized hosted comparison passes.

## Deviations from Plan

**1. Added a Phase254 raw-family mode to `ci-hosted-gate-verify.py` and its tests.**

- **Found during:** Task 3
- **Issue:** The existing hosted verifier only accepted Phase253 proof documents and could not independently verify Phase254 raw run/attempt/check/artifact origins.
- **Fix:** Added a separate `comparison-family` CLI mode and focused positive and mutation-rejection fixtures; existing Phase253 modes remain covered by the full verifier suite.
- **Files modified:** `scripts/ci/ci-hosted-gate-verify.py`, `scripts/ci/ci-hosted-gate-verify.test.py`
- **Commit:** `93dfa8c30`

## Task Commits

1. `d60022dac` — reject unordered comparison pair starts
2. `4503e2a6e` — validate frozen comparison schedules
3. `0045a19f2` — retain costs from every attempt
4. `c78a38b7d` — derive costs from raw run attempts
5. `93dfa8c30` — authenticate collected comparison families
6. `162b8e544` — cover independent comparison verdicts

## Self-Check: PASSED

- Summary file exists at the declared plan output path.
- All six task commits are ancestors of the current plan branch head.
- Measured plan commit count is six from `plan_head_before` through `plan_head_after`.
