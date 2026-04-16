---
phase: 23-docs-ci-smoke-upgrade-guide
plan: 02
subsystem: testing
tags: [organizations, passkeys, fixtures, audit, dx]
requires:
  - phase: 13-org-schemas-contexts
    provides: organization and membership schemas plus scope shape
  - phase: 19-passkey-schema-contexts
    provides: passkey credential schemas and controller/test seams
  - phase: 15-audit-integration
    provides: audit assertion helpers and audit event schema contract
provides:
  - generated AuthFixtures org/passkey helper surface
  - mirrored example and install-golden fixture contracts
  - org-aware Sigra.Testing assertions for scope, membership, and audit checks
affects: [docs, ci-smoke, install-golden, testing]
tech-stack:
  added: []
  patterns: [narrow explicit test helpers, mirrored generated fixture contracts, audit helper delegation]
key-files:
  created: [.planning/phases/23-docs-ci-smoke-upgrade-guide/23-02-SUMMARY.md]
  modified:
    - lib/sigra/testing.ex
    - priv/templates/sigra.install/core/auth_fixtures.ex
    - test/example/test/support/fixtures/auth_fixtures.ex
    - test/fixtures/install_golden/tree/test/support/fixtures/auth_fixtures.ex
    - test/sigra/testing_test.exs
    - test/sigra/testing/assert_audit_logged_test.exs
    - test/sigra/auth_fixtures_scenario_test.exs
key-decisions:
  - "Kept org and passkey helpers on the existing AuthFixtures surface and mirrored that contract in the example and install-golden fixtures."
  - "Implemented assert_membership/3 as a narrow keyword-driven assertion instead of introducing a generic matcher DSL."
  - "Implemented assert_audit_logged_for_org/2 as a thin wrapper over assert_audit_logged/2 so org audit checks stay on the existing query path."
patterns-established:
  - "Generated helper contracts should be pinned in template-content tests and mirrored in example plus install-golden fixtures."
  - "Org-aware test assertions should raise direct field-level ExUnit errors rather than hiding intent behind a generic DSL."
requirements-completed: [DX-01, DX-02]
duration: 5m
completed: 2026-04-16
---

# Phase 23 Plan 02: Testing Helper Surface Summary

**Org/passkey fixture helpers on AuthFixtures plus narrow Sigra.Testing org assertions locked by focused contract tests**

## Performance

- **Duration:** 5 min
- **Started:** 2026-04-16T16:06:35Z
- **Completed:** 2026-04-16T16:11:15Z
- **Tasks:** 2
- **Files modified:** 8

## Accomplishments
- Extended the generated `AuthFixtures` template with `create_organization/1`, `create_membership/3`, `log_in_user_with_org/3`, `register_passkey/2`, and `authenticate_with_passkey/2`.
- Mirrored the same helper surface in the example fixture and the install-golden fixture so DX-01 stays visible in both local usage and generated snapshot coverage.
- Added `assert_scope_has_org/2`, `assert_membership/3`, and `assert_audit_logged_for_org/2` to `Sigra.Testing` with focused mismatch messages and tests.

## Task Commits

Each task was committed atomically through TDD:

1. **Task 1: Add org and passkey helper primitives to the generated fixture surface**
   - `af14d74` `test(23-02): add failing org fixture helper contract tests`
   - `625c32f` `feat(23-02): add org and passkey auth fixture helpers`
2. **Task 2: Add narrow org-aware assertions to `Sigra.Testing` and pin them with focused tests**
   - `6716cad` `test(23-02): add failing org-aware testing helper tests`
   - `e04bb30` `feat(23-02): add org-aware testing assertions`

## Files Created/Modified

- `lib/sigra/testing.ex` - added scope, membership, and org-audit assertions while delegating org audit checks through the existing audit helper path
- `priv/templates/sigra.install/core/auth_fixtures.ex` - added org/passkey helper functions and explicit caveat docs about bypassed boundaries
- `test/example/test/support/fixtures/auth_fixtures.ex` - mirrored the generated helper shape in the example app fixture surface
- `test/fixtures/install_golden/tree/test/support/fixtures/auth_fixtures.ex` - kept the install-golden snapshot aligned with the generated helper contract
- `test/sigra/testing_test.exs` - added focused scope and membership assertion tests
- `test/sigra/testing/assert_audit_logged_test.exs` - added org-specific audit assertion tests
- `test/sigra/auth_fixtures_scenario_test.exs` - pinned helper names, mirror coverage, and caveat strings in the template contract test
- `.planning/phases/23-docs-ci-smoke-upgrade-guide/23-02-SUMMARY.md` - recorded execution results for this plan

## Decisions Made

- Kept the org and passkey fixture surface on `AuthFixtures` instead of introducing a second helper module.
- Required the generated template docs to use explicit caveat language about bypassing real controller, LiveView, and session boundaries.
- Used keyword options for `assert_membership/3` so the helper stays narrow while still checking organization and role explicitly.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

- `mix format` cannot parse ERB-style template syntax in `priv/templates/sigra.install/core/auth_fixtures.ex`, so formatting was applied only to the concrete Elixir files.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- The generated helper contract is now pinned across template, example, and install-golden fixtures for downstream docs and smoke work.
- `Sigra.Testing` now exposes the org-aware assertions Phase 23 docs can reference directly.

## Self-Check: PASSED

- Summary file exists at `.planning/phases/23-docs-ci-smoke-upgrade-guide/23-02-SUMMARY.md`.
- Commits `af14d74`, `625c32f`, `6716cad`, and `e04bb30` exist in git history.

---
*Phase: 23-docs-ci-smoke-upgrade-guide*
*Completed: 2026-04-16*
