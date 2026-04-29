---
phase: 91
plan: "03"
status: complete
---

# Plan 91-03 — HTTP org-MFA enforcement

## Outcome

- Added `Sigra.Plug.RequireOrgMfa` with request-boundary enforcement and return-path persistence.
- Wired the generated auth error handler and `:org_scoped` router pipeline to enforce org MFA automatically.
- Added plug-level unit coverage for pass-through, redirect, and path-safety behavior.

## Self-Check: PASSED

- `MIX_ENV=test mix test test/sigra/plug/require_org_mfa_test.exs`
- `MIX_ENV=test mix test test/sigra/install/golden_diff_test.exs`

## Deviations

None.
