---
phase: 91
plan: "04"
status: complete
---

# Plan 91-04 — LiveView org-MFA enforcement

## Outcome

- Added `Sigra.LiveView.RequireOrgMfa` and wired it into generated organization-scoped LiveView sessions.
- Added LiveView guard tests covering unenforced, enrolled, and redirecting org-member paths.

## Self-Check: PASSED

- `MIX_ENV=test mix test test/sigra/live_view/require_org_mfa_test.exs`

## Deviations

None.
