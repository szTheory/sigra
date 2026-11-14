---
phase: 256-repair-ci-diagnostics-and-complete-bounded-speed-comparison
plan: "06"
subsystem: ci
tags: [ci, source-proof, proposal, recovery]
requires:
  - phase: 256 Plan01
    provides: Reviewed diagnostics patch and Phase256 local policy boundaries
provides:
  - Actual candidate and control source roles in the scoped bare store
  - Production-verified Phase256 proposal, adoption, and persisted source proof
affects: [256 Plan03, 256 Plan04, 256 Plan05, CISPEED-01, CISPEED-02]
actuals:
  tokens: null
  tasks: 3
  commits: 0
tech-stack:
  added: []
  patterns:
    - Strict output namespaces keep temporary review/test receipts outside canonical producer roots
    - Dependency readiness, not numeric plan order, selects the next plan
key-files:
  created:
    - .planning/execution/256/objects.git
    - .planning/execution/256/source-recovery-01/CODE-REVIEW.json
    - .planning/execution/256/source-recovery-01/OFFLINE-RECOVERY.json
    - .planning/execution/256/source-recovery-01/LOCAL-VERIFICATION.json
    - .planning/execution/256/source-recovery-01/SOURCE-CHECK.json
    - .planning/execution/256/PREP-PROPOSAL.json
    - .planning/execution/256/PREP-CONTRACT.json
    - .planning/execution/256/PREP-REGISTRATIONS.json
    - .planning/execution/256/HISTORY.json
    - .planning/execution/256/CONTROL-ADOPTION.json
  modified:
    - scripts/ci/ci-repaired-comparison.py
    - scripts/ci/ci-repaired-comparison.test.py
    - scripts/ci/ci_metrics_security.py
key-decisions:
  - "Review the final code and proof-binding hashes before source materialization; preserve each created ref and archive rather than replacing it after a local error."
  - "Keep the Phase256 two-row preparation policy separate from the legacy Phase255.1 four-slot policy."
  - "Keep CISPEED-01/02 open until the bounded hosted comparison and independent phase verification prove the measured outcomes."
patterns-established:
  - "Compare exact treatment paths and added/deleted-line signatures; hunk-context bytes can differ across retained source trees."
  - "Keep temporary evidence outside strict production output roots."
requirements-completed: []
coverage: []
duration: "not recorded"
completed: 2026-11-05
status: complete
---

# Phase 256 Plan 06: Local source and proposal proof

**The reviewed two-role source proof, Phase256 proposal, adoption record, and persisted source readback now pass without hosted spend.**

## Accomplishments

- Added a Phase256-only history adapter and exact two-row preparation validation while preserving the Phase255.1 four-slot rule. The focused Phase256 suite passed 38 tests and the security policy suite passed 3 tests.
- A separate read-only code reviewer approved the final hashes for all three changed code/test files with no unresolved findings. The approval is recorded in `source-recovery-01/CODE-REVIEW.json`.
- Materialized the exact retained candidate and control source refs in `.planning/execution/256/objects.git`, checked both source roles against the same pinned base, verified the approved four-path treatment signatures, and bound both environment-helper results and archives.
- The production proposal producer completed successfully. Its five canonical outputs are `ready_for_consent`; the reciprocal contract hash and recovery receipt checksum were finalized once.
- The production source verifier wrote a `SOURCE-CHECK.json` with `status: passed`. The persisted `fresh-prep-verify` consumer returned `ready_for_consent` and independently checked the proposal, adoption, source, and readback evidence.
- The proof establishes one prospective PR368 preparation-ref update, zero control preparation requests/mutations/workloads, zero acceptance samples, and zero hosted actions or external spend. It does not authorize or perform the preparation itself.

## Verification and limitations

- Focused Phase256 and Plan10 boundary tests: 38 passed.
- Security policy regression: 3 passed.
- Production `fresh-prep-propose`: passed.
- Production `fresh-prep-verify-sources`: passed; candidate and control environment checks both passed.
- Production `fresh-prep-verify`: passed with `ready_for_consent`.
- The unchanged named Phase255.1 end-to-end regression stopped on its inherited expired preparation deadline. It was not retried or renewed. The legacy four-slot validator assertion passed, and the legacy production validator remains unchanged.
- No repository-level Git commits were made because the project `.git` directory is read-only in this execution context. Workspace changes and evidence remain present; no raw Git write was attempted.
- CISPEED-01 and CISPEED-02 remain open. No runner performance sample was collected.

## Issues resolved during execution

- Corrected a local materializer ancestry check to use the scoped bare store and continued from the existing immutable candidate/control refs.
- Compared the approved treatment by exact changed-line signatures and paths, not raw patch bytes whose hunk context differs between retained trees.
- Moved temporary review/test receipts outside the strict Phase256 output namespace before invoking canonical producers.
- Added a narrow Phase256 verifier branch for its two preparation rows while retaining the legacy four-slot check. The original failed verifier attempt wrote no `SOURCE-CHECK`; the corrected implementation was independently reviewed before the source verifier was run again.

## Next readiness

Plan06's actual source and proposal gates passed. The orchestrator must refresh `phase-plan-index 256` and dispatch only its `ready_plans` value; Plan02 remains terminally halted. Plans03–05 still depend on their declared predecessors. The existing user authorization covers the bounded in-scope CI without per-run approval, subject to the recorded timeouts and remaining caps. No merge or release is authorized.

---
*Phase: 256*
*Completed: 2026-11-05*
