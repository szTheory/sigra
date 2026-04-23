# Phase 61 — Technical Research

**Question:** What do we need to know to plan **AUD-01** (one bounded MFA subsystem batch toward `Ecto.Multi` + audit-aware tests) well?

## Current code state (MFA)

- **`confirm_enrollment/5`**, **`verify/4`** (success + failure + lockout), **`verify_backup/4`** (success only), **`regenerate_backup_codes/4`**, and **`cleanup_mfa/5`** already use **`Sigra.Audit.log_multi_safe/3`** inside **`Repo.transaction/1`** where audit schema is enabled.
- **`verify_backup/4`** on **`{:error, :consume, :invalid_backup_code}`** runs **`Lockout.increment/4`** in a **separate** DB round-trip **without** any **`mfa.verify.failure`** or **`mfa.lockout`** audit — unlike **`verify/4`**, which bundles counter + audit in **`Ecto.Multi`**.
- **`Sigra.MFA.audit_trust_browser/2`** and **`audit_backup_codes_regenerate/3`** remain **`log_safe/3`** helpers; inventory marks **AUD-04-034** / **EX-44-04** as intentional deferral unless paired with a domain write. **No in-repo callers** of **`audit_trust_browser/2`** today — poor primary batch target per **061-CONTEXT D-01**.

## Subsystem choice (locked for planning)

**Primary batch:** **`verify_backup/4` — invalid backup code + lockout cluster** (same user-facing command as success path, bounded scope).

- Aligns with **061-CONTEXT D-01** (MFA vertical, one cluster, not “all MFA”).
- Closes a real **co-fate / observability gap**: failed-attempt counter can commit without a matching audit trail when `:audit_schema` is set.
- Mirrors the established **`verify/4`** failure **`Multi`** pattern (`Lockout.increment` → **`log_multi_safe("mfa.verify.failure", …)`** → **`Multi.merge`** for **`mfa.lockout`** when threshold reached).
- Traceability: extend **AUD-04** narrative (new or updated row for backup-code verify failure); update **C-1** matrix cells touched by this behavior in **`09-VERIFICATION.md`** in the same merge (**D-08**).

## Fallback (not used unless executor discovers a blocker)

**061-CONTEXT D-02:** **API token revoke** — only if **`verify_backup`** change would violate product invariants; inventory **AUD-04-047** text may still say `log_safe` but **`lib/sigra/api_token.ex`** already uses **`log_multi_safe`** for revoke — verify before any fallback plan.

## Testing patterns

- Reuse **`test/sigra/mfa_audit_atomicity_test.exs`**: Postgres minimal schemas, **`Sigra.Test.AuditEvent`**, **`ALTER TABLE … ADD CONSTRAINT … CHECK`** to force audit insert failure and assert rollback (**D-06**).
- Success path for **`verify_backup`** already asserts ordered **`mfa.verify.success`** + **`mfa.backup_code_used`** — extend with **failure** assertions: after wrong code, expect **`mfa.verify.failure`** row with **`metadata->>'method' = 'backup_code'`** (or equivalent stable shape from **`log_multi_safe`**).
- Add **one** rollback test: transaction that includes lockout increment + audit must roll back when audit insert is rejected (guard on failure action name).

## Risk notes

- **`Multi.run(:consume, …)`** returning **`{:error, :invalid_backup_code}`** must transition to a **new** **`Multi`** for the failure branch (do not reuse partial `backup_ok_multi` changes — `repo.transaction` already rolled back).
- **`Lockout.increment`** return shape must match **`verify/4`** failure branch for telemetry keys (**`emit_telemetry_from_changes`** step names).

## Validation Architecture

Phase verification is **ExUnit + Ecto SQL Sandbox** against disposable Postgres DDL in the MFA atomicity module (existing pattern).

| Dimension | Approach |
|-----------|----------|
| **Automated proof** | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/mfa_audit_atomicity_test.exs` |
| **Co-fate** | Constraint on `audit_events.action` forces rollback; assert credential row count / absence of partial audit |
| **Audit completeness** | `SELECT count(*) … WHERE action = '…'` with stable action strings |
| **Regression** | Full `mix test` before merge (CI parity) |

Nyquist Dimension 8 (validation in plans): every implementation task references the MFA atomicity test file and a concrete `mix test` path.

---

## RESEARCH COMPLETE
