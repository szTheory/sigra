---
phase: 234-hygiene-supply-chain-and-contributor-dx
plan: 17
subsystem: ci-evidence
tags: [dependabot, github, supply-chain, exunit, evidence]
requires:
  - phase: 234-hygiene-supply-chain-and-contributor-dx
    provides: Exact Dependabot configuration and fail-closed receipt contract
provides:
  - Authenticated GitHub-processed receipts for every locked Dependabot tuple
  - Resolved DX-03 evidence residual with retained diagnostic history
affects: [DX-03, GitHub Dependabot evidence, 234-18 validation ratification]
tech-stack:
  added: []
  patterns: [exact tuple receipt validation, sanitized managed-service evidence]
key-files:
  created: [.planning/phases/234-hygiene-supply-chain-and-contributor-dx/234-17-SUMMARY.md]
  modified:
    - test/sigra/planning/phase_234_evidence_contract_test.exs
    - .planning/phases/234-hygiene-supply-chain-and-contributor-dx/234-EVIDENCE.json
    - .planning/todos/pending/2026-08-01-phase-234-github-evidence-residual.md
decisions:
  - "A successful processed Dependabot job is authoritative even when no pull request is associated."
  - "Receipt validation anchors to the SHA of current default branch at collection time while retaining the decoded configuration hash."
metrics:
  tasks_completed: 2
  completed_date: 2026-08-02
status: complete
---

# Phase 234 Plan 17: Dependabot Receipt Hardening Summary

**DX-03 now has authenticated, strict-contract-validated Dependabot processing receipts for Actions, Mix, and Playwright npm dependencies.**

## Accomplishments

- Kept the exact ordered receipt validator for `github-actions:/`, `mix:/`, and `npm:/test/example/priv/playwright` fail-closed against missing, duplicate, malformed, red, or inferred rows.
- Captured current GitHub-processed receipts: Actions job `1499842989` (successful no-update), Mix job `1500015096` (PR #184), and npm job `1499842994` (PR #177).
- Re-anchored the authenticated default-branch assertion to `4935fe65aa80b69fffd3f0efc02911a8515a86f5`; the decoded Dependabot configuration SHA-256 remains unchanged.
- Resolved the DX-03 residual only after the complete exact tuple contract passed, retaining the earlier authentication and open-PR-limit diagnostics.

## Task Commits

1. **Task 1 RED: Add Dependabot processed receipt mutations** — `7fdf0994` (test)
2. **Task 1 GREEN: Enforce Dependabot processed receipts** — `76c59335` (feat)
3. **Task 1 REFACTOR: Format Dependabot receipt contract** — `84c6d154` (refactor)
4. **Task 2: Record initial authentication boundary** — `0ea35ce0` (docs)
5. **Task 2: Record deterministic open-PR-limit diagnostic** — `12d8d91a` (docs)
6. **Task 2: Capture authenticated processed receipts** — `fa32a9a5` (feat)
7. **Task 2: Link the resolved residual to its evidence commit** — `1e42c091` (docs)

## Verification

- `mix format --check-formatted test/sigra/planning/phase_234_evidence_contract_test.exs` — passed.
- `mix test test/sigra/planning/phase_234_dependabot_contract_test.exs test/sigra/planning/phase_234_evidence_contract_test.exs --only dependabot` — passed (1 test, 0 failures).
- `mix test test/sigra/planning/phase_234_dependabot_contract_test.exs test/sigra/planning/phase_234_evidence_contract_test.exs` — passed (12 tests, 0 failures).

The focused file-backed tests emit pre-existing PostgreSQL connection-refused harness noise; it does not affect their 0-failure result.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Re-anchored stale default-branch SHA assertions**
- **Found during:** Task 2
- **Issue:** The authorized merge of PR #176 advanced `main`, making the previous hard-coded default-branch SHA incompatible with a new authenticated receipt even though the decoded Dependabot configuration hash was unchanged.
- **Fix:** Updated the successful-receipt fixture, validator assertion, and final evidence state to the collected current `main` SHA.
- **Files modified:** `test/sigra/planning/phase_234_evidence_contract_test.exs`, `234-EVIDENCE.json`
- **Commit:** `fa32a9a5`

## Authentication Gates

The earlier unauthenticated-browser gate was cleared by the maintainer-provided session. The continuation used one REST core preflight (`4906/5000`) and serial, read-only browser navigation. No raw authenticated material was persisted.

## Known Stubs

None.

## Self-Check: PASSED

- Evidence, residual, contract test, and this summary exist at their recorded paths.
- Task commits `7fdf0994`, `76c59335`, `84c6d154`, `0ea35ce0`, `12d8d91a`, `fa32a9a5`, and `1e42c091` exist in history.
