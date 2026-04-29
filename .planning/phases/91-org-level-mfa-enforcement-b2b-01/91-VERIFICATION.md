status: pass
---

# Phase 91 verification

**Phase:** 91 — org-level-mfa-enforcement-b2b-01 (**B2B-01**)  
**Goal:** Org admins can require MFA for every member of an organization with an atomic `organization.mfa_policy_change` audit row, and unenrolled members are blocked at the HTTP and LiveView boundaries until they enroll.

## Merge gate checklist

| Check | Evidence | Status |
|-------|----------|--------|
| Focused core/library MFA policy tests green | `MIX_ENV=test mix test test/sigra/organizations/set_mfa_policy_test.exs test/sigra/organizations_mfa_policy_audit_atomicity_test.exs test/sigra/plug/require_org_mfa_test.exs test/sigra/live_view/require_org_mfa_test.exs` exited `0` on `2026-04-29` (`24 tests, 0 failures`) | passed |
| Generator-host org MFA integration green | `CLOAK_KEY=MDEyMzQ1Njc4OWFiY2RlZjAxMjM0NTY3ODlhYmNkZWY= MIX_ENV=test mix test test/example_web/integration/org_mfa_enforcement_test.exs` exited `0` on `2026-04-29` in `test/example` (`1 test, 0 failures`) | passed |
| Template/golden drift coverage green | `MIX_ENV=test mix test test/sigra/organizations/schema_test.exs test/sigra/organizations/context_test.exs test/sigra/install/features/organizations_test.exs test/sigra/install/generator_mfa_test.exs test/sigra/templates/installer_drift_test.exs` exited `0` on `2026-04-29` (`204 tests, 0 failures`) | passed |
| Install-path regression coverage green | `MIX_ENV=test mix test test/sigra/install/vault_promotion_test.exs test/sigra/install/features/organizations_test.exs` exited `0` on `2026-04-29` after the router/template binding fixes (`63 tests, 0 failures`) | passed |
| Installer render/syntax coverage green | `MIX_ENV=test mix test test/sigra/install/template_render_test.exs test/sigra/install/template_syntax_test.exs test/sigra/install/features/coverage_test.exs` exited `0` on `2026-04-29` (`88 tests, 0 failures`) | passed |
| Full library suite green | `MIX_ENV=test mix test` exited `0` on `2026-04-29` (`33 doctests, 3 properties, 2214 tests, 0 failures`) | passed |
| Planning truth aligned | `.planning/ROADMAP.md` uses canonical action name `organization.mfa_policy_change`; `CHANGELOG.md` documents the phase surface and verification pointer | passed |
| No new `log_safe/3` debt | The new policy-change audit path is emitted via `Sigra.Audit.log_multi_safe/3` from `Sigra.Organizations.set_mfa_policy/5` | passed |

## Code pointers

- `lib/sigra/organizations.ex`
- `lib/sigra/plug/require_org_mfa.ex`
- `lib/sigra/live_view/require_org_mfa.ex`
- `priv/templates/sigra.install/organizations/router_injection.ex`
- `priv/templates/sigra.install/organizations/live/organization_settings_live.ex`
- `test/example/test/example_web/integration/org_mfa_enforcement_test.exs`

## Notes

- Phase 91 corrected a repo-truth mismatch during implementation: the generated host already shipped `mfa_enabled?/1`, but its `sigra_config/0` lacked the MFA credential schema. The helper now augments config with `UserMFACredential` before delegating to `Sigra.MFA.enabled?/2`.
- The generated router wiring uses `&<App>.Accounts.mfa_enabled?/1` for both the plug and LiveView guard so the template binding stays valid in installer feature tests and the generated example app.
- A fresh root `MIX_ENV=test mix test` rerun completed cleanly after the golden-fixture drift was aligned for the org-MFA generator output.

## Self-check

```bash
MIX_ENV=test mix test \
  test/sigra/organizations/set_mfa_policy_test.exs \
  test/sigra/organizations_mfa_policy_audit_atomicity_test.exs \
  test/sigra/plug/require_org_mfa_test.exs \
  test/sigra/live_view/require_org_mfa_test.exs

MIX_ENV=test mix test \
  test/sigra/organizations/schema_test.exs \
  test/sigra/organizations/context_test.exs \
  test/sigra/install/features/organizations_test.exs \
  test/sigra/install/generator_mfa_test.exs \
  test/sigra/templates/installer_drift_test.exs

MIX_ENV=test mix test \
  test/sigra/install/template_render_test.exs \
  test/sigra/install/template_syntax_test.exs \
  test/sigra/install/features/coverage_test.exs

cd test/example && \
  CLOAK_KEY=MDEyMzQ1Njc4OWFiY2RlZjAxMjM0NTY3ODlhYmNkZWY= MIX_ENV=test mix test \
    test/example_web/integration/org_mfa_enforcement_test.exs
```
