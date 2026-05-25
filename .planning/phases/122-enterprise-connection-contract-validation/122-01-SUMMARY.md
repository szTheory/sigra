---
phase: 122-enterprise-connection-contract-validation
plan: 01
subsystem: auth
tags: [enterprise-sso, oidc, organizations, validation, installer]
requires: []
provides:
  - organization-bound enterprise connection schema and migration emission
  - library-owned enterprise connection lifecycle and OIDC validation service
  - Wave 0 schema, context, validation, and activation refusal coverage
affects: [enterprise-routing, generated-host-settings, installer-fixtures]
tech-stack:
  added: []
  patterns: [library-first org-scoped lifecycle, OIDC preflight before activation]
key-files:
  created:
    - lib/sigra/enterprise_connections.ex
    - lib/sigra/enterprise_connections/validation.ex
    - priv/templates/sigra.install/organizations/enterprise_connection.ex
    - priv/templates/sigra.install/organizations/enterprise_connection_oidc_settings.ex
    - priv/templates/sigra.install/organizations/enterprise_connections_migration.exs
    - test/sigra/enterprise_connections/schema_test.exs
    - test/sigra/enterprise_connections/context_test.exs
    - test/sigra/enterprise_connections/validation_test.exs
    - test/sigra/enterprise_connections/activation_test.exs
  modified:
    - lib/sigra/install/features/organizations.ex
key-decisions:
  - "Kept enterprise connections separate from global oauth provider config so org-bound runtime truth stays in the database."
  - "Used explicit draft/validation_failed/active/disabled lifecycle state and required OIDC discovery before activation."
patterns-established:
  - "Enterprise auth integrations follow the Organizations library-first split: host-owned schemas, Sigra-owned lifecycle."
  - "Activation truth is persisted and fails closed instead of inferring active state from saved fields."
requirements-completed: [SSO-01, SSO-02]
duration: 30 min
completed: 2026-05-25
---

# Phase 122 Plan 01 Summary

**Enterprise connection persistence, installer emission, and OIDC preflight validation now exist as an organization-bound Sigra subsystem instead of a global OAuth config stub.**

## Performance

- **Duration:** 30 min
- **Started:** 2026-05-25T14:26:42Z
- **Completed:** 2026-05-25T14:56:50Z
- **Tasks:** 2
- **Files modified:** 17

## Accomplishments

- Added host-owned enterprise connection schema, embedded OIDC settings, and migration emission under the organizations installer feature.
- Added `Sigra.EnterpriseConnections` plus a validation service that checks OIDC discovery and blocks invalid activation.
- Added Wave 0 unit coverage for schema shape, org-scope enforcement, validation semantics, and activation refusal.

## Task Commits

1. **Task 1: Add the org-scoped enterprise connection schema and installer emission** - `c5a0e1b` (feat)
2. **Task 2: Build the Sigra enterprise connection context and OIDC validation lifecycle** - `c5a0e1b` (feat)

## Files Created/Modified

- `lib/sigra/enterprise_connections.ex` - org-scoped CRUD and lifecycle truth for enterprise connections.
- `lib/sigra/enterprise_connections/validation.ex` - OIDC discovery and client-setting preflight validation.
- `priv/templates/sigra.install/organizations/enterprise_connection*.ex` - generated host schema and typed OIDC settings wrapper.
- `priv/templates/sigra.install/organizations/enterprise_connections_migration.exs` - enterprise connection table migration template.
- `test/example/lib/example/accounts/enterprise_connection*.ex` and `test/example/priv/repo/migrations/20260525010000_create_enterprise_connections.exs` - committed example-app mirror of the generated substrate.
- `test/sigra/enterprise_connections/*` - Wave 0 proof for schema, context, validation, and activation refusal behavior.

## Decisions Made

- Used a dedicated `enterprise_connections` table with nested OIDC settings so later enterprise protocol work can reuse the operator model.
- Kept successful validation non-active until an explicit activation call, while persisting `validation_failed` state and safe diagnostics on failure.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

- Elixir guard restrictions required a small refactor in the validation helpers before the new module compiled cleanly.

## Verification

- `mix test test/sigra/enterprise_connections/schema_test.exs test/sigra/enterprise_connections/context_test.exs test/sigra/enterprise_connections/validation_test.exs test/sigra/enterprise_connections/activation_test.exs test/sigra/oauth/assent_oidc_contract_test.exs` -> passed (`8 tests, 0 failures`).

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Generated and committed example host now has the enterprise connection substrate that Phase 122 Plan 02 can expose through the organization settings surface.
- The installer fixture already includes the new emitted schema and migration files, so host-surface work can extend those outputs without reintroducing install drift.

## Self-Check: PASSED
