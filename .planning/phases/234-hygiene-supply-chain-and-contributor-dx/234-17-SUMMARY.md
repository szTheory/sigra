---
phase: 234-hygiene-supply-chain-and-contributor-dx
plan: 17
subsystem: ci-evidence
tags: [dependabot, github, supply-chain, exunit, evidence]
requires:
  - phase: 234-hygiene-supply-chain-and-contributor-dx
    provides: Exact Dependabot configuration and existing failed service-owned evidence residual
provides:
  - Strict successful Dependabot processed-job receipt contract
  - Current durable authenticated-browser access diagnostic for the unresolved service receipt
affects: [DX-03, GitHub Dependabot evidence]
tech-stack:
  added: []
  patterns: [exact tuple receipt validation, fail-closed managed-service evidence]
key-files:
  created: [.planning/phases/234-hygiene-supply-chain-and-contributor-dx/234-17-SUMMARY.md]
  modified:
    - test/sigra/planning/phase_234_evidence_contract_test.exs
    - .planning/phases/234-hygiene-supply-chain-and-contributor-dx/234-EVIDENCE.json
    - .planning/todos/pending/2026-08-01-phase-234-github-evidence-residual.md
decisions:
  - "Do not promote Dependabot evidence without an authenticated GitHub browser receipt for every exact tuple."
metrics:
  duration: 3m
  tasks_completed: 1
  tasks_blocked: 1
status: blocked
---

# Phase 234 Plan 17: Dependabot Receipt Hardening Summary

**The exact three-tuple receipt validator is green, while GitHub's browser authentication boundary keeps DX-03 explicitly failed and durably diagnosable.**

## Accomplishments

- Added a centralized successful-receipt validator for `github-actions:/`, `mix:/`, and `npm:/test/example/priv/playwright`.
- Pinned numeric job IDs, UTC timestamps, tuple-specific Dependabot job-log URLs, sanitized SHA-256 hashes, successful processing status, and an explicit no-update proof when no PR is associated.
- Added mutation coverage for duplicate, missing, extra, malformed, red, and configuration-mismatched receipt data.
- Rechecked the service boundary: GitHub CLI authentication is active and REST core had 4,121 remaining requests, but the isolated browser received GitHub's sign-in form rather than authenticated Dependabot job rows.

## Task Commits

1. **Task 1 RED: Add Dependabot processed receipt mutations** — `7fdf0994` (test)
2. **Task 1 GREEN: Enforce Dependabot processed receipts** — `76c59335` (feat)
3. **Task 2: Record Dependabot authentication boundary** — `0ea35ce0` (docs; blocked collection attempt)

## Verification

`mix test test/sigra/planning/phase_234_dependabot_contract_test.exs test/sigra/planning/phase_234_evidence_contract_test.exs --only dependabot` passed: 1 test, 0 failures. Local PostgreSQL connection-refused logs are pre-existing harness noise and do not affect this file-backed contract.

## Authentication Gate

The deterministic browser has no authenticated GitHub session. It was navigated once to the Dependabot job-log surface, which rendered the sign-in form. No cookies, session state, raw HTML, or logs were retained. The plan cannot capture or fabricate the three required job receipts until a maintainer supplies an authenticated browser session with repository access.

## Deviations from Plan

None. The plan explicitly requires a durable failed diagnostic and halt when authentication prevents any required tuple from being collected.

## Known Stubs

None.

## Next Step

Authenticate the deterministic browser to GitHub as a maintainer with repository access, then re-run Plan 234-17. Leave `dependabot.status` failed until all three exact processed-job receipts validate.

## Self-Check: PASSED

- Contract test and evidence/residual artifacts exist at the recorded paths.
- Commits `7fdf0994`, `76c59335`, and `0ea35ce0` exist in history.
