---
phase: 83
plan: "01"
status: complete
---

# Plan 83-01 — MFA confirm_enrollment invalid-code audit (library)

## Outcome

- **`Sigra.MFA.confirm_enrollment/5`**: invalid TOTP branch calls **`commit_ad_hoc_mfa_audit/5`** with **`mfa.enroll.failure`** and **`:audit_mfa_enroll_invalid_code`** when **`:audit_schema`** is set; no audit-only transaction when audit is off.
- Module dispatch comment and **`@doc`** updated per **83-CONTEXT** (**D-83-01**, **D-83-02**).

## Self-Check: PASSED

- `MIX_ENV=test mix compile --warnings-as-errors`
- `awk '/def confirm_enrollment/,/^  @doc /' lib/sigra/mfa.ex | grep -c "Audit.log_safe"` → **0**

## Deviations

None.
