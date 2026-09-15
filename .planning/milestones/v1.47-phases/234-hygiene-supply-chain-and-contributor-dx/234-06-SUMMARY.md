---
phase: 234-hygiene-supply-chain-and-contributor-dx
plan: "06"
subsystem: infra
tags: [github-actions, supply-chain, release-please, exunit]
requires:
  - phase: 231-gate-honesty-nightly-revival
    provides: release workflow integrity and release-lane conventions
provides:
  - Release Please pinned to its reviewed dereferenced v5.0.0 commit
  - Fail-closed ExUnit inventory for release-critical third-party Actions
affects: [release-workflows, supply-chain-security, DX-02]
tech-stack:
  added: []
  patterns: [scoped workflow source contracts, immutable action SHA validation]
key-files:
  created: [test/sigra/planning/phase_234_action_pinning_contract_test.exs]
  modified: [.github/workflows/release-please.yml]
key-decisions:
  - "Scope immutable-action enforcement to the explicit release-please and manual Hex-publish workflows."
  - "Reject the annotated v5 tag object explicitly, even though it has the shape of a lowercase 40-character SHA."
patterns-established:
  - "Release-critical third-party uses lines must carry a lowercase 40-character commit SHA and same-line semantic-version comment."
requirements-completed: [DX-02]
coverage:
  - id: D1
    description: "Release Please is pinned to the reviewed dereferenced v5.0.0 commit without changing privileged workflow boundaries."
    requirement: DX-02
    verification:
      - kind: unit
        ref: "mix test test/sigra/planning/phase_234_action_pinning_contract_test.exs"
        status: pass
    human_judgment: false
  - id: D2
    description: "Release-critical third-party action inventory rejects mutable, malformed, undocumented, and annotated-tag-object refs."
    requirement: DX-02
    verification:
      - kind: unit
        ref: "test/sigra/planning/phase_234_action_pinning_contract_test.exs#synthetic mutable or undocumented third-party actions fail with workflow and line diagnostics"
        status: pass
    human_judgment: false
duration: 3min
completed: 2026-08-01
status: complete
---

# Phase 234 Plan 06: Immutable Release Action Pins Summary

**Release Please now executes the reviewed dereferenced v5.0.0 commit, protected by a fail-closed release-workflow action inventory with mutation coverage.**

## Performance

- **Duration:** 3 min
- **Started:** 2026-08-01T01:47:00Z
- **Completed:** 2026-08-01T01:49:30Z
- **Tasks:** 2/2
- **Files modified:** 2

## Accomplishments

- Replaced the mutable Release Please v5 tag with commit `45996ed1f6d02564a971a2fa1b5860e934307cf7 # v5.0.0` while preserving trigger, permissions, token source, release condition, and outputs.
- Added an explicit live release-critical workflow universe covering automated release and manual Hex publishing paths.
- Added non-vacuous, hermetic mutation coverage for tags, short/uppercase SHAs, missing comments, the forbidden annotated tag object, and repository-local action exclusion.

## Task Commits

1. **Task 1: Pin Release Please to the locked dereferenced commit (D-05)** - `2c9848ab` (test RED), `32028d49` (feat GREEN)
2. **Task 2: Prove the action policy is non-vacuous and workflow-valid (D-06)** - `f4c530db` (test)

## Files Created/Modified

- `.github/workflows/release-please.yml` - Uses the exact immutable Release Please commit and version comment.
- `test/sigra/planning/phase_234_action_pinning_contract_test.exs` - Validates release workflow scope, immutable third-party Action refs, privileged boundary invariants, and mutation failures.

## Decisions Made

- The release-critical policy covers `release-please.yml` and `hex-publish.yml`, the workflows that execute release authority or publish with `HEX_API_KEY`.
- The annotated v5 tag-object SHA is rejected as a known unsafe alternative even though it matches the generic SHA shape.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

- The focused source contract passed despite local Postgrex connection-refused log noise from the application test bootstrap; its six ExUnit assertions completed with zero failures and do not require database access.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Future release-critical third-party action drift is mechanically rejected. The next Wave 1 supply-chain plan can add Dependabot coverage independently.

## Self-Check: PASSED

- Found `.github/workflows/release-please.yml` and `test/sigra/planning/phase_234_action_pinning_contract_test.exs`.
- Found task commits `2c9848ab`, `32028d49`, and `f4c530db` in git history.

---
*Phase: 234-hygiene-supply-chain-and-contributor-dx*
*Completed: 2026-08-01*
