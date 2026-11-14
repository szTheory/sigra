---
phase: 257-fix-candidate-source-publication-and-complete-the-bounded-ci
plan: "01"
subsystem: ci
tags: [ci, source-publication, process-groups, bounded-authorization]
requires: []
provides:
  - Production single-ref publisher proved with a local bare remote
  - Phase257 candidate-only request, one-shot claim, timeout and terminal-receipt controls
  - Candidate-bound run, job and artifact route checks
  - Independent local review and final source hashes for proposal freeze
affects: [257-02, 257-03, CISPEED-01, CISPEED-02]
actuals:
  tokens: null
  tasks: 2
  commits: 0
tech-stack:
  added: []
  patterns:
    - Reuse the production leased publisher against temporary local bare remotes
    - Reconcile nested process groups through one shared, path-bound receipt
    - Bind dynamic API routes to a verified candidate workflow and IDs observed from it
key-files:
  created:
    - scripts/ci/ci_candidate_publication.py
    - scripts/ci/ci-candidate-publication.test.py
    - .planning/debug/phase257-local/PLAN01-REVIEW.json
  modified:
    - scripts/ci/ci-repaired-comparison.py
    - scripts/ci/ci-repaired-comparison.test.py
    - scripts/ci/ci_repaired_driver.py
    - scripts/ci/ci-repaired-driver.test.py
    - scripts/ci/ci_metrics_security.py
key-decisions:
  - "The collector and outer wrapper share the exact nested process-group registry; uncertain cleanup halts the one-shot attempt."
  - "Run, job, and artifact reads require candidate-bound IDs; a reversed run/artifact download route is rejected before ledger reservation or transport."
  - "Failed or incomplete launch receipts remain blocked with unknown spend when evidence is unavailable; they cannot pass or renew the claim."
  - "Phase256 evidence remains unchanged and its 11 prior requests stay charged in the new scope."
patterns-established:
  - "Validate persisted producer outcomes before the later verification record exists, while requiring full outer-process success for any pass."
  - "Keep blocked reports tied to exact source, method, workflow, control-adoption and spend identities."
requirements-completed: []
coverage: [CISPEED-01, CISPEED-02]
duration: "not recorded"
completed: 2026-11-05
status: complete
---

# Phase 257 Plan 01: Local publisher and preparation controls

**The production publisher and Phase257 preparation boundaries pass focused offline checks. The one-shot claim remains unused; no hosted operation occurred.**

## Accomplishments

- Proved missing-object transfer to a temporary bare remote using the production publisher and one exact leased branch update. Refusal and ambiguity cases remain single-attempt and fail closed.
- Fixed the mismatch between the wrapper's timeout cleanup and the collector's nested process-group receipt. If cleanup cannot be proven, the outer attempt halts.
- Bound run, job, artifact and typed download routes to the verified candidate workflow. The wrong run/artifact ID order now fails before any ledger reservation or transport.
- Made early launch failures and final-receipt replacement errors produce a blocked terminal record when the output store can still be written. Missing spend evidence stays unknown rather than being reported as zero.
- Added persisted terminal checks for wrapper success, ledger chains, candidate postconditions, collection-ledger file types, measurement windows and source-bound blocked reports.
- Recorded final implementation hashes and independent review results in [PLAN01-REVIEW.json](~/projects/sigra/.planning/debug/phase257-local/PLAN01-REVIEW.json).

## Verification and limits

- Phase257 scope tests: 20 passed; Phase257 driver preparation tests: 3 passed.
- Production publisher tests against local bare remotes: 6 passed; nested collector process-group tests: 2 passed.
- The three required Phase256 readiness compatibility tests passed. A byte snapshot of the 566-file Phase256 execution and phase artifact tree was identical before and after the final checks.
- Python compilation and whitespace checks passed. The full exploratory Phase256 test class still contains stale fixture and expectation failures; those historical tests and artifacts were not changed.
- No GitHub request, Git network operation, cache operation, workflow, merge, or release occurred. CISPEED-01/02 remain open, and measured performance is still unproved.

## Next readiness

Proceed to Plan02's local proposal freeze and independent readback. Plan03 is the only later step that can consume the prepared claim; it remains one bounded invocation under the already recorded limits. No new approval is needed for the authorized development and bounded CI work.

---
*Phase: 257*
*Completed: 2026-11-05*
