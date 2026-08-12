---
phase: 244-pat-and-advanced-jwt-truth-repair
plan: 06
subsystem: auth
tags: [jwt, refresh-token, postgres, ecto-multi, concurrency, audit]
requires:
  - phase: 244-pat-and-advanced-jwt-truth-repair
    provides: "Strict host-policy JWT issuance and generated refresh-token storage"
provides:
  - "One locked transaction for refresh classification, rotation, reuse revocation, and optional audit"
  - "Post-commit-only refresh credential responses with digest-only persistence"
  - "Barrier-controlled Postgres evidence for concurrent refresh serialization"
affects: [jwt-02, phase-245-app-sessions]
tech-stack:
  added: []
  patterns:
    - "Lock the digest-addressed refresh row with FOR UPDATE before lifecycle classification"
    - "Use an optional audit Multi step, never an alternate refresh transaction path"
key-files:
  created: []
  modified:
    - lib/sigra/jwt.ex
    - lib/sigra/jwt/refresh_token.ex
    - test/sigra/jwt_refresh_audit_cofate_test.exs
    - test/sigra/jwt_test.exs
    - priv/templates/sigra.install/core/auth.ex
    - lib/mix/tasks/sigra.install.ex
key-decisions:
  - "Refresh returns replacement credentials only after the locked transaction commits in both audit modes."
  - "JWT-only installation does not set the generated auth template's API binding or emit PAT schema configuration."
requirements-completed: [JWT-02]
coverage:
  - id: D1
    description: "Audit-on and audit-off refresh rotation, rollback, reuse-family revocation, and concurrent double refresh share one locked PostgreSQL transaction."
    requirement: JWT-02
    verification:
      - kind: integration
        ref: "MIX_ENV=test mix test test/sigra/jwt_refresh_audit_cofate_test.exs test/sigra/jwt/refresh_token_test.exs --trace"
        status: pass
      - kind: integration
        ref: "MIX_ENV=test mix test test/sigra/install/features/core_test.exs test/sigra/install/api_token_generator_test.exs test/sigra/api_token_test.exs test/sigra/api_token/scope_registry_test.exs test/sigra/jwt_test.exs test/sigra/jwt/refresh_token_test.exs test/sigra/jwt/signer_test.exs test/sigra/jwt_refresh_audit_cofate_test.exs test/sigra/planning/phase_244_generated_auth_runtime_proof_test.exs --trace"
        status: pass
    human_judgment: false
metrics:
  duration: 12min
  completed: 2026-08-12
  tasks: 1
  files: 10
status: complete
---

# Phase 244 Plan 06: Locked JWT Refresh Lifecycle Summary

**JWT refresh now serializes opaque digest-backed family rotation or reuse revocation inside one PostgreSQL transaction, returning replacement credentials only after commit.**

## Accomplishments

- Replaced separate audited and unaudited refresh branches with an authoritative `Ecto.Multi` lifecycle: `FOR UPDATE` lookup/classification, rotation or family revoke, then an optional audit step.
- Added real-Postgres audit-off rollback and explicit two-process barrier concurrency proof; one caller rotates and the other commits reuse revocation in both audit modes, with no timing sleeps.
- Preserved public refresh outcomes while making persistence faults return `:jwt_refresh_aborted` before access or raw refresh credentials are returned.
- Repaired milestone generator fallout: JWT-only bindings no longer cause PAT schema configuration, legacy/minimal template bindings compile, and post-install instructions describe host-policy JWT issuance rather than the removed password endpoint.

## Task Commits

1. **Task 1: Rotate and classify one refresh family inside a locked transaction (JWT-02)** — `209e786e` (RED), `533ea028` (GREEN), `7236f01e` (transaction-mock adaptation), `2ae5e969` (format)

## Additional Integration Fixes

- `e836c1dc` — corrected the JWT configuration injection marker assertion to Plan 05's generated marker.
- `edbbacbc` — applied authorized formatter-only CI changes to two existing generated-proof contracts.
- `7f0d488c` — repaired API-specific generated auth bindings and legacy template rendering.
- `a99c14ec` — replaced stale password-endpoint instruction coverage with host-policy coverage.

## Verification

- `source tmp/db.env && MIX_ENV=test mix test test/sigra/jwt_refresh_audit_cofate_test.exs test/sigra/jwt/refresh_token_test.exs --trace` — passed, 14 tests / 0 failures.
- Phase 244 focused gate — passed after all fixes (generator, PAT, JWT, refresh, and fresh-host proof suites).
- `source tmp/db.env && MIX_ENV=test mix ci` — not green due to baseline failures outside Phase 244: 2 missing Phase 239 proof/COVERAGE artifacts, 2 missing Phase 235 todo-artifact assertions, and Phase 236 closeout assertions incompatible with current planning state. The initial CI run also exposed the Plan 244 generator binding and stale JWT instruction regressions; both were fixed above.

## Files Created/Modified

- `lib/sigra/jwt.ex` — orchestrates the one locked refresh lifecycle and post-commit response signing.
- `lib/sigra/jwt/refresh_token.ex` — performs digest lookup and classification under `FOR UPDATE`.
- `test/sigra/jwt_refresh_audit_cofate_test.exs` — provides audit-off rollback and deterministic concurrent-refresh evidence.
- `test/sigra/jwt_test.exs` — models the transactional refresh public contract.
- `priv/templates/sigra.install/core/auth.ex` and `lib/mix/tasks/sigra.install.ex` — keep PAT configuration API-only and legacy template bindings safe.

## Decisions Made

- Audit is an optional Multi step; it never selects a weaker refresh persistence path.
- A consumed token's family revoke commits before `:reuse_detected` returns.
- JWT-only generated hosts expose only host-policy issuance, never a password-to-JWT endpoint.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Regression] Adapted JWT refresh mocks to the transactional public contract**
- **Found during:** Task 1 phase gate
- **Issue:** Existing unit mocks assumed the removed `get_by` / `update!` / `insert` refresh sequence.
- **Fix:** Modeled successful and reuse transaction results while retaining public response assertions.
- **Files modified:** `test/sigra/jwt_test.exs`
- **Verification:** JWT unit suite and complete Phase 244 focused gate passed.
- **Committed in:** `7236f01e`

**2. [Rule 1 - Generator regression] Kept auth template API configuration independent from JWT selection**
- **Found during:** Required `mix ci`
- **Issue:** A missing legacy `api` template binding crashed EEx rendering, and JWT selection still set the auth-template API binding.
- **Fix:** Default missing binding to false and make install binding API-only.
- **Files modified:** `priv/templates/sigra.install/core/auth.ex`, `lib/mix/tasks/sigra.install.ex`, `test/mix/tasks/sigra.install_test.exs`
- **Verification:** generator MFA and install rendering suites passed.
- **Committed in:** `7f0d488c`

**3. [Rule 1 - Stale contract] Replaced removed password-endpoint guidance assertion**
- **Found during:** Required `mix ci`
- **Issue:** Post-install instructions test still required the deliberately removed `/api/auth/token` endpoint.
- **Fix:** Assert host-policy `Auth.JWT` instructions and endpoint absence.
- **Files modified:** `test/sigra/install/features/core_post_instructions_test.exs`
- **Verification:** post-instructions suite passed.
- **Committed in:** `a99c14ec`

**Total deviations:** 3 auto-fixed Rule 1 regressions. **Impact:** All changes preserve the locked JWT-only and atomic refresh contracts; no new credential authority surface was added.

## Known Stubs

None.

## Issues Encountered

- Full `mix ci` has baseline failures outside this plan after milestone-created regressions were fixed: six missing historical planning artifacts/assertions (Phases 235, 236, and 239). These are not waived; they remain durable cross-phase blockers for full-repository CI.

## Next Phase Readiness

Phase 244 has focused automated evidence for JWT-02. Phase 245 can reuse the locked opaque-family lifecycle pattern for app sessions.

## Self-Check: PASSED

All planned refresh source/test files and task commits exist; the refresh suites and the complete Phase 244 focused gate pass against PostgreSQL.
