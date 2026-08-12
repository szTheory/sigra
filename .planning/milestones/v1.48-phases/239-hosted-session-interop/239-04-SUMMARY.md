---
phase: 239-hosted-session-interop
plan: "04"
subsystem: hosted-session-interop
tags: [crosswake, sigra, ecto, session, replay, account-switch]
requires:
  - phase: 239-hosted-session-interop
    provides: "Fresh cookie-to-session resolution and evaluator isolation for current host state"
provides:
  - "Host-owned expected binding with opaque session and subject refs plus a server-derived session version"
  - "Fail-closed mismatch and account-switch denial before Crosswake evaluation"
affects: [239-05, 239-06, crosswake-consumption]
tech-stack:
  added: []
  patterns: ["Accept the host-issued ExpectedBinding type only after fresh current-row validation", "Compare opaque references with Plug.Crypto.secure_compare and normalize all binding mismatches"]
key-files:
  created: []
  modified:
    - test/example/lib/example/accounts/crosswake_session_adapter.ex
    - test/example/test/example/accounts/crosswake_session_adapter_test.exs
key-decisions:
  - "Expected bindings use a dedicated host adapter struct containing only session_ref, subject_ref, and session_version."
  - "Malformed, stale, and switched bindings all return the same categorical :binding_mismatch denial without evaluator invocation or identifier details."
patterns-established:
  - "A fresh session lookup precedes expected-binding comparison, preserving current-state denial precedence while preventing any replacement authority from reaching Crosswake."
requirements-completed: [XW-02]
coverage:
  - id: D1
    description: "A complete host-owned session, subject, and version binding is required before the evaluator can run; altered or malformed inputs fail closed."
    requirement: XW-02
    verification:
      - kind: integration
        ref: "cd test/example && mix test test/example/accounts/crosswake_session_adapter_test.exs --only crosswake_binding"
        status: pass
    human_judgment: false
  - id: D2
    description: "A valid account or session selected after the continuation began cannot replace the original authority tuple."
    requirement: XW-02
    verification:
      - kind: integration
        ref: "cd test/example && mix test test/example/accounts/crosswake_session_adapter_test.exs --only crosswake_account_switch"
        status: pass
    human_judgment: false
duration: 6min
completed: 2026-08-10
status: complete
---

# Phase 239 Plan 04: Host-Owned Binding and Account-Switch Denial Summary

**Crosswake replay is now tied to the original server-owned session, subject, and microsecond-derived version, rejecting altered or switched authority before the evaluator is called.**

## Performance

- **Duration:** 6min
- **Started:** 2026-08-10T00:35:18Z
- **Completed:** 2026-08-10T00:41:18Z
- **Tasks:** 2 completed
- **Files modified:** 2

## Accomplishments

- Replaced the loose expected-binding map with a minimal `ExpectedBinding` host type containing only opaque session and subject refs plus the server-derived session version.
- Added constant-time comparison of opaque refs and exact version comparison after fresh canonical session/user validation.
- Added real-row mismatch and account-switch proofs showing no evaluator calls and identifier-free categorical denials.

## Task Commits

1. **Tasks 1–2 TDD RED: add binding mismatch matrix** - `89d79a23` (test)
2. **Tasks 1–2 TDD GREEN: bind Crosswake replay to host session** - `6e42028f` (feat)

## Files Created/Modified

- `test/example/lib/example/accounts/crosswake_session_adapter.ex` - issues and validates the host-owned binding tuple before constructing Crosswake authority facts.
- `test/example/test/example/accounts/crosswake_session_adapter_test.exs` - proves the stale/malformed binding and account/session-switch denial matrix against real Ecto rows.

## Decisions Made

- The continuation contract is a dedicated host binding type, not a caller-supplied map; map-shaped and incomplete inputs fail closed after current session validation.
- Binding failures are deliberately normalized to `:binding_mismatch`, so denial details expose neither expected nor replacement account/session identifiers.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Started the repository-provided ephemeral PostgreSQL service.**
- **Found during:** Task 1 GREEN verification
- **Issue:** The configured local PostgreSQL port was unavailable for the real Ecto binding matrix.
- **Fix:** Ran `scripts/db/up.sh` and sourced `tmp/db.env` before the focused and complete adapter test runs.
- **Files modified:** None tracked.
- **Verification:** Both focused tags and the complete adapter test file pass.

**Total deviations:** 1 auto-fixed (1 Rule 3).
**Impact on plan:** The repository-supported test database was required for deterministic real-row verification; implementation scope was unchanged.

## Issues Encountered

The red test correctly failed because `ExpectedBinding` did not yet exist. The first green verification exposed only an unavailable ephemeral database, which was restored using the repository helper.

## Known Stubs

None.

## User Setup Required

None - the repository's ephemeral PostgreSQL helper provides the required test store.

## Next Phase Readiness

Plans 05 and 06 can rely on a fresh host binding check that rejects stale, malformed, and replaced authority before Crosswake evaluation.

## Self-Check: PASSED

- Confirmed both modified adapter files exist.
- Confirmed commits `89d79a23` and `6e42028f` exist in Git history.
- Confirmed both focused tags, the complete adapter test file, formatter check, no-sleep guard, and whitespace check pass.
