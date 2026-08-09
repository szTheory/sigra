---
phase: 239-hosted-session-interop
plan: "02"
subsystem: hosted-session-interop
tags: [crosswake, sigra, ecto, session, hmac, release-proof]
requires:
  - phase: 239-hosted-session-interop
    provides: "Validated Crosswake 0.1.3 release provenance and immutable command proof"
provides:
  - "Example-host-only crosswake_sigra 0.1.3 dependency and normalized release receipt"
  - "Fresh cookie-to-session Crosswake projection with host-keyed opaque bindings"
  - "Database-backed personal-session evaluator tracer"
affects: [239-03, 239-04, 239-05, 239-06, crosswake-consumption]
tech-stack:
  added: [crosswake_sigra 0.1.3, crosswake 0.2.0]
  patterns: ["Resolve the raw cookie through host storage on every evaluation, then pass fact-only authority to Crosswake"]
key-files:
  created:
    - .planning/phases/239-hosted-session-interop/239-CROSSWAKE-RELEASE.json
    - test/example/lib/example/accounts/crosswake_session_adapter.ex
    - test/example/test/example/accounts/crosswake_session_adapter_test.exs
  modified: [test/example/mix.exs, test/example/mix.lock]
key-decisions:
  - "Keep Crosswake confined to the example proof host and pin it to the validated proof requirement ~> 0.1.3."
  - "Derive session and subject references with domain-separated HMACs over host row IDs; use session inserted_at microseconds as the private version."
patterns-established:
  - "A persisted host binding is opaque only; each evaluation re-resolves the raw cookie and compares a newly derived binding before calling the pure evaluator."
requirements-completed: [XW-01, XW-02]
coverage:
  - id: D1
    description: "A real personal Ecto session is freshly resolved from its raw cookie and allowed through the released Crosswake evaluator with org_id nil."
    requirement: XW-01
    verification:
      - kind: integration
        ref: "test/example/test/example/accounts/crosswake_session_adapter_test.exs#freshly resolves a personal session"
        status: pass
    human_judgment: false
  - id: D2
    description: "The released contract accepts personal and nonblank organization scope, rejects blank scope, and the tracer asserts opaque secret-free results."
    requirement: XW-02
    verification:
      - kind: integration
        ref: "cd test/example && mix test test/example/accounts/crosswake_session_adapter_test.exs --only crosswake_tracer"
        status: pass
    human_judgment: false
duration: 2min
completed: 2026-08-09
status: complete
---

# Phase 239 Plan 02: Hosted Crosswake Session Adapter Summary

**A released Crosswake evaluator now receives freshly resolved, fact-only personal SIGRA session authority from the example host without token, digest, row-ID, or organization leakage.**

## Performance

- **Duration:** 2min
- **Started:** 2026-08-09T19:53:46Z
- **Completed:** 2026-08-09T19:54:23Z
- **Tasks:** 1 completed
- **Files modified:** 5

## Accomplishments

- Derived the normalized Crosswake release receipt strictly from the Wave 0 proof and pinned `crosswake_sigra ~> 0.1.3` only in `test/example`.
- Added a host-owned adapter that re-resolves the raw cookie for every evaluation, validates current session time limits, derives domain-separated HMAC references, and projects `org_id: nil`.
- Added deterministic Ecto-backed tracer coverage for a personal allow path, opaque/secret-free results, and released personal/nonblank/blank organization semantics.

## Task Commits

1. **Task 1: Project one freshly resolved personal session through Crosswake** - `4363bc18` (test), `69a6406a` (feat)

## Files Created/Modified

- `.planning/phases/239-hosted-session-interop/239-CROSSWAKE-RELEASE.json` - normalized immutable release coordinates from the validated proof.
- `test/example/mix.exs` and `test/example/mix.lock` - proof-host-only released companion dependency.
- `test/example/lib/example/accounts/crosswake_session_adapter.ex` - fresh host resolution, opaque projection, binding comparison, and evaluator boundary.
- `test/example/test/example/accounts/crosswake_session_adapter_test.exs` - database-backed tagged tracer proof.

## Decisions Made

- The adapter exposes only opaque continuation bindings and small safe allow/deny results; Crosswake never receives raw cookies, persisted digests, host IDs, provider data, OAuth credentials, or hydrated organization authority.
- It reuses SIGRA's default idle and absolute timeout configuration for the projected evaluator timestamps, with the injected `as_of` as server-owned testable time.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Test bug] Corrected unsupported ISO-8601 test construction and matched the released blank-org error shape.**
- **Found during:** Task 1 RED run
- **Issue:** `DateTime.from_iso8601!/1` is not an Elixir API and the released contract reports `:invalid_optional_string` for blank `org_id`.
- **Fix:** Used the supported `DateTime.from_iso8601/1` match helper and asserted the released validation result.
- **Files modified:** `test/example/test/example/accounts/crosswake_session_adapter_test.exs`
- **Verification:** The focused tagged tracer passes.

**2. [Rule 3 - Blocking] Started the repository-provided ephemeral PostgreSQL service for the database-backed tracer.**
- **Found during:** Task 1 RED run
- **Issue:** The configured local PostgreSQL port was unavailable, so ExUnit could not create the example database.
- **Fix:** Ran `scripts/db/up.sh` and sourced its generated `tmp/db.env` before test runs.
- **Files modified:** None tracked.
- **Verification:** The focused tagged tracer passes against the real Ecto store.

**3. [Rule 1 - Verification correction] Used the exact formatter command array in the authoritative proof and handoff.**
- **Found during:** Task 1 receipt validation
- **Issue:** Plan 02's inline verifier omitted the two required formatter file paths, conflicting with the Plan 00 proof and handoff.
- **Fix:** Compared the receipt against the proof's exact four command records, including both formatter paths.
- **Files modified:** None.
- **Verification:** Receipt/proof equality and ordered command validation pass.

## Known Stubs

None.

## User Setup Required

None - the test database is provided by the repository's deterministic Docker helper.

## Next Phase Readiness

Plans 03–06 can consume the immutable receipt and the host adapter as the personal-session projection seam; denial and return-evidence expansions remain for their planned tasks.

## Self-Check: PASSED

- Confirmed the receipt, adapter, and tracer files exist.
- Confirmed commits `4363bc18` and `69a6406a` exist in Git history.
