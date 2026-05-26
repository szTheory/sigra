---
phase: 125-sso-only-enforcement-break-glass-truth
slug: sso-only-enforcement-break-glass-truth
status: passed
created: 2026-05-26
updated: 2026-05-26
requirements: [ENF-01]
score: 4/4 closeout goals verified
verified_at: 2026-05-26T10:01:00-04:00
---

# Phase 125 — Verification

Supersedes the `125-0x-SUMMARY.md` files as the authoritative `ENF-01` proof surface.

## Closeout Goals

| Goal | Result | Evidence |
|------|--------|----------|
| Org-owned auth policy and explicit break-glass exemptions are modeled separately from enterprise connection state | Pass | Example-host settings coverage and generated template parity both passed on current HEAD. |
| Non-exempt password login and password reset are denied before success audit or session creation | Pass | Root auth rerun covers `Sigra.EnterpriseAuthPolicy`, login denial, and reset gating. |
| Example-host recovery routes denied users back to enterprise sign-in without advertising unsupported bypasses | Pass | Current-head example rerun covers session, enterprise SSO, and passkey-session controllers. |
| Installer output and committed golden fixture stay aligned with the current SSO-only contract | Pass | Installer suite and refreshed golden diff proof passed on current HEAD. |

## Evidence

- Root enforcement proof:
  `mix test test/sigra/enterprise_routing/discovery_test.exs test/sigra/oauth/oauth_test.exs test/sigra/oauth/enterprise_callback_test.exs test/sigra/oauth/enterprise_reconciliation_test.exs test/sigra/auth_org_selection_test.exs test/sigra/auth_enterprise_session_metadata_test.exs test/sigra/auth_test.exs test/sigra/auth/login_and_lockout_audit_atomicity_test.exs`
  Result: passed (`116 tests, 0 failures`).
- Example-host denial and recovery proof:
  `cd test/example && MIX_ENV=test mix test --include example_app test/example_web/controllers/session_controller_test.exs test/example_web/controllers/enterprise_sso_controller_test.exs test/example_web/controllers/passkey_session_controller_test.exs test/example_web/integration/enterprise_sso_routing_flow_test.exs test/example_web/integration/enterprise_sso_reconciliation_flow_test.exs test/example_web/live/organization_settings_live_test.exs`
  Result: passed (`32 tests, 0 failures`).
- Installer parity proof:
  `mix test test/sigra/install/features/organizations_test.exs test/sigra/install/golden_diff_test.exs test/sigra/admin/live/enterprise_connection_live_test.exs`
  Result: passed (`70 tests, 0 failures`) after refreshing the committed golden fixture to match current generated output.

## Proved / Did Not Prove

**Proved**

- SSO-only password denial happens before a normal login success path can create a session or success audit row.
- Break-glass exemptions remain explicit and organization-scoped.
- Generated and example hosts steer denied local-auth users back to enterprise sign-in when org context is known.
- Installer output, example behavior, and committed golden files now agree on the current enforcement and recovery contract.

**Did Not Prove**

- SCIM, deprovisioning, or any broader enterprise lifecycle automation.
- Hosted policy consoles or opinionated authorization behavior beyond the bounded SSO-only contract.

## Status

Passed — Phase 125 now has an authoritative current-head `ENF-01` verification artifact.
