---
phase: 91
plan: "01"
status: complete
---

# Plan 91-01 — MFA policy persistence and orchestration

## Outcome

- Added `enforce_mfa_for_members` to generated organization schemas and install/upgrade migrations.
- Implemented `Sigra.Organizations.set_mfa_policy/5`, `count_members_without_mfa/3`, and the generated host delegators.
- Added the host-side `mfa_enabled?/1` helper path used by later plug and LiveView enforcement.

## Self-Check: PASSED

- `MIX_ENV=test mix test test/sigra/organizations/set_mfa_policy_test.exs`
- `MIX_ENV=test mix test test/sigra/organizations/schema_test.exs test/sigra/organizations/context_test.exs`

## Deviations

None.
