---
phase: 91
plan: "05"
status: complete
requirements-completed: [B2B-01]
---

# Plan 91-05 — Organization settings MFA UX

## Outcome

- Added the generated `OrganizationSettingsLive` security section, admin pre-flight UX, confirm flow, and policy status copy.
- Wired the settings page to `Organizations.set_mfa_policy/2` and the unenrolled-member impact count.
- Added role-gating and state-reset behavior so the toggle is only actionable for org admins and owners.

## Self-Check: PASSED

- `MIX_ENV=test mix test test/sigra/install/features/organizations_test.exs test/sigra/install/generator_mfa_test.exs`

## Deviations

None.
