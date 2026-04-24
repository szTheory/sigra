# Phase 73 — Pattern map

**Phase:** 73 — Bounded audit atomicity batch (MFA **AUD-04-023..032**)

## Files to create or modify

| File | Role | Closest analog |
|------|------|----------------|
| `.planning/phases/09-audit-logging/09-VERIFICATION.md` | C-1 matrix truth | **066** updates to same file for **020–022**; **061** for **067** |
| `.planning/phases/44-mfa-account-api-atomic-batches/44-AUD-04-INVENTORY.md` | Inventory table + grep log | Same file — rows **023–032** |
| `test/sigra/mfa_audit_atomicity_test.exs` | Postgres integration + **CHECK** guards | **066-01-PLAN** tasks 2 tone; existing **`mfa_disable_atomicity_guard`** / **`mfa_backup_verify_failure_guard`** blocks in this file |

## Code excerpts (reference)

**Verify success `Multi` + audit** (`lib/sigra/mfa.ex` ~291–310):

```elixir
multi =
  Multi.new()
  |> Multi.update_all(...)
  |> Sigra.Audit.log_multi_safe("mfa.verify.success", ...)
```

**Fault injection pattern** (`test/sigra/mfa_audit_atomicity_test.exs` ~200–233 — enrollment):

```elixir
Ecto.Adapters.SQL.query!(repo, "ALTER TABLE audit_events ADD CONSTRAINT ... CHECK (action <> 'mfa.enroll.success')", [])
# try / assert_raise ConstraintError / assert counts / after DROP CONSTRAINT
```

## PATTERN MAPPING COMPLETE
