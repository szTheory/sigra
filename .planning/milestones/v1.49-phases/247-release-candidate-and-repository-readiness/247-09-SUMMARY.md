---
phase: 247-release-candidate-and-repository-readiness
plan: 09
subsystem: release-readiness
tags: [playwright, liveview, mobile-webkit, exact-source-ci]
requires:
  - phase: 247-08
    provides: Authenticated non-publishing dry run and final readiness baseline.
provides:
  - Both organization signup paths wait for the rendered Strong password result before role-based submission.
  - Exact-head mobile WebKit and ci-gate evidence for candidate 0e773d3614a242e4fbcdd34c418ecb8a307703d6.
  - Preserved diagnosis of the local macOS AppKit browser-startup limitation.
affects: [247-10, 247-11, READY-01]
actuals:
  tokens: 236
  tasks: 3
  commits: 1
  plan_head_before: d76d7f2306f6099063a80a420d2d8a4e04c7785f
  plan_head_after: 0e773d3614a242e4fbcdd34c418ecb8a307703d6
tech-stack:
  added: []
  patterns: [wait for server-rendered LiveView feedback before role-based form submission]
key-files:
  created:
    - .planning/phases/247-release-candidate-and-repository-readiness/247-09-LOCAL-RESULT.json
    - .planning/phases/247-release-candidate-and-repository-readiness/247-09-PLAYWRIGHT-RESULT.json
  modified:
    - test/example/priv/playwright/tests/organizations.spec.ts
key-decisions:
  - "Treat the local AppKit abort before page startup as a host limitation, not browser proof; require the exact-head mobile WebKit CI job."
  - "Keep READY-01 blocked until the separate exact-source evidence rebind and final readiness work complete."
requirements-completed: []
duration: not recorded in the recovered artifacts
completed: 2026-10-08
status: complete
---

# Phase 247 Plan 09 Summary

Both organization signup paths wait for the server-rendered Strong password result before submission; exact-head mobile WebKit CI passed while local browser startup remained blocked by the recorded AppKit host abort.

## Accomplishments

- Candidate commit `0e773d3614a242e4fbcdd34c418ecb8a307703d6` changed only `organizations.spec.ts` and added the Strong feedback wait to both registration paths.
- Local setup, compile, migrations, seeds, and the registration route passed. Playwright WebKit aborted during AppKit registration before a page or test started; the detailed diagnosis is in `247-09-LOCAL-RESULT.json`.
- Exact-head CI run `37819712610` passed on the candidate SHA, including the mobile WebKit job and `ci-gate`; zero retries are recorded.

## Approval and Evidence Boundary

Plan 09 required explicit approval before pushing the candidate to PR #224. The roadmap records that the exact-head CI run followed that approval, but the recovered project artifacts do not contain the verbatim approval response, so this summary does not reconstruct it. The machine-readable browser result is restored byte-for-byte from its scoped preservation ref and remains marked `blocked_by_stale_candidate_evidence`; Plan 09 does not claim READY-01 or phase verification.

## Next Phase Readiness

The exact-head result handed the candidate tuple to Plan 10 for a separate evidence-rebind checkpoint. Phase 247's requirement verdict remains subject to its independent verification and the later reconciliation recorded in Phase 250.

---
*Phase: 247-release-candidate-and-repository-readiness*
*Completed: 2026-10-08*
