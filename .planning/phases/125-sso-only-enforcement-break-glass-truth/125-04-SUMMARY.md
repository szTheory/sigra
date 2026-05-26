---
phase: 125-sso-only-enforcement-break-glass-truth
plan: 04
subsystem: installer-parity
tags: [enterprise-sso, installer, generated-host, golden, auth-policy]
requirements-completed: [ENF-01]
key-files:
  created:
    - priv/templates/sigra.install/organizations/organization_auth_policy.ex
    - priv/templates/sigra.install/organizations/organization_auth_policy_exemption.ex
    - priv/templates/sigra.install/organizations/organization_auth_policies_migration.exs
  modified:
    - lib/sigra/install/features/organizations.ex
    - priv/templates/sigra.install/organizations/organizations.ex
    - priv/templates/sigra.install/core/session_controller.ex
    - priv/templates/sigra.install/core/login_html.ex
    - test/sigra/install/features/organizations_test.exs
    - test/fixtures/install_golden/STDOUT.txt
completed: 2026-05-26
---

# Plan 125-04 Summary

## Outcome

Registered the new SSO-only policy templates and migration in the installer, updated generated auth/session/login templates to match the example app’s denial and recovery contract, and refreshed the install golden fixture so generated output stays locked to the Phase 125 behavior.

## Verification

- `mix test test/sigra/install/features/organizations_test.exs`
- `mix test test/sigra/install/golden_diff_test.exs`

## Deviations from Plan

None - plan executed exactly as written.
