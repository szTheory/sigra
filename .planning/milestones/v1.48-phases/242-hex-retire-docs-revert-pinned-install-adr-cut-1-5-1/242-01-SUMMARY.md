---
phase: 242-hex-retire-docs-revert-pinned-install-adr-cut-1-5-1
plan: "01"
subsystem: release-automation
tags: [hex, github-actions, evidence, resolver, prohibition]
requires:
  - phase: 240
    provides: green-gate evidence conventions
  - phase: 238
    provides: release namespace protections
provides:
  - fixed-target Hex remediation workflow and public evidence receipt verifier
  - hermetic resolver proof for broad and safe requirements
  - p22 structural guard with attributable known-bad fixtures
affects: [242-02, 242-03, 242-04, release-automation, Hex]
tech-stack:
  added: [bash, jq, node:test]
  patterns: [fixed-scope mutation lane, sanitized public evidence, no-blind-retry writes]
key-files:
  created:
    - .github/workflows/hex-remediate-phantom.yml
    - scripts/ci/hex-remediation-verify.sh
    - scripts/ci/prohibitions/p22-hex-remediation.test.mjs
  modified:
    - scripts/ci/hex-remediation-verify.test.sh
decisions:
  - "The remediation lane is dispatch-only with fixed sigra 1.20.0 literals and secrets scoped solely to the two Hex writes."
  - "Public observations are projected to a secret-free schema and resolver cases use separate fresh homes."
actuals:
  tokens: 7648
  tasks: 2
  commits: 3
plan_head_before: 1244831c3c0b7e36487cc171f2cfbbef927f7e14
requirements-completed: []
coverage:
  - id: D1
    description: Fixed-target remediation workflow and validated public receipt schema.
    requirement: REL-03
    verification:
      - kind: integration
        ref: bash scripts/ci/hex-remediation-verify.test.sh
        status: pass
      - kind: unit
        ref: node --test --test-reporter=tap scripts/ci/prohibitions/p22-hex-remediation.test.mjs
        status: pass
    human_judgment: true
    rationale: The planned safe-to-land tracer is complete, but the intentionally unexecuted external Hex mutation remains a later evidence obligation.
  - id: D2
    description: Docs-only revert command class and current-root classifier.
    requirement: REL-04
    verification:
      - kind: integration
        ref: bash scripts/ci/hex-remediation-verify.test.sh
        status: pass
    human_judgment: true
    rationale: Live HexDocs root state is intentionally not claimed before the dedicated workflow is dispatched.
  - id: D3
    description: Separate broad and safe fresh-home resolver receipts.
    requirement: REL-05
    verification:
      - kind: integration
        ref: bash scripts/ci/hex-remediation-verify.test.sh
        status: pass
    human_judgment: false
duration: 40min
completed: 2026-09-20
status: complete
---

# Phase 242 Plan 01: Fixed Hex Remediation Tracer Summary

**A dispatch-only, least-privilege Hex remediation lane that records secret-free causal evidence and proves the advisory retirement resolver behavior offline.**

## Performance

- **Duration:** 40 min
- **Started:** 2026-09-20T13:43:07Z
- **Completed:** 2026-09-20T14:22:56Z
- **Tasks:** 2/2
- **Files modified:** 7

## Accomplishments

- Added a fixed `sigra` `1.20.0` remediation workflow with read-before-write, read-after-error, docs-only revert, non-cancelling concurrency, and step-scoped key access.
- Added a hermetic verifier that fails closed for empty/malformed public responses, absent releases, unsafe root classification, incomplete receipts, resolver drift, shared resolver homes, and credential-shaped evidence.
- Added p22 with non-vacuity floors and attributable fixtures for target/permission/concurrency drift and unsafe key/command behavior.

## Task Commits

1. **Task 1: End-to-end fixed-target remediation lane** - `bce10546` (test), `8116c3ac` (feat)
2. **Task 2: Make target, authority, command, and evidence drift permanently red** - `1737a9c2` (test)

## Verification

- `bash scripts/ci/hex-remediation-verify.test.sh` — passed.
- `node --test --test-reporter=tap scripts/ci/prohibitions/*.test.mjs` — 116 passed.
- `MIX_ENV=test mix test test/sigra/planning/phase_234_action_pinning_contract_test.exs` — 13 passed.
- `git diff --check` — passed.

## Decisions Made

- Keep the mutation target and retirement message literal in the workflow; the verifier deliberately exposes no package, version, reason, message, or command override.
- Preserve the Phase 234 two-publisher inventory; p22 owns this non-publisher remediation workflow.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

The Phase 234 Mix regression test initially could not open its local Mix PubSub socket inside the sandbox. It passed unchanged when rerun with the required local runtime permission; this was an environment restriction, not a product failure.

## Next Phase Readiness

The tracer is safe to land without dispatching a public mutation. A later authorized workflow run must produce the live Hex and HexDocs evidence before REL-03 and REL-04 are marked complete.

## Self-Check: PASSED

- Confirmed all seven planned implementation and fixture files exist.
- Confirmed `bce10546`, `8116c3ac`, and `1737a9c2` exist in Git history.

---
*Phase: 242-hex-retire-docs-revert-pinned-install-adr-cut-1-5-1*
*Completed: 2026-09-20*
