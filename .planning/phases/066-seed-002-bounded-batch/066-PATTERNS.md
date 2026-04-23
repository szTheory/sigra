# Phase 66 — Pattern map (`confirm_enrollment` / AUD-04-020..022)

## Canonical analog

| Target | Analog | Notes |
|--------|--------|-------|
| **`confirm_enrollment/5`** success **`Multi` + `log_multi_safe`** | Same function today (~lines 170–189) | Already T1 — docs were stale |
| Failure audit in dedicated transaction | **061** `061-01-PLAN.md` **`verify_backup`** failure **`Multi`** | Separate **`repo.transaction`** boundary; telemetry from **`changes`** |
| Atomicity tests with CHECK guard | **`mfa_audit_atomicity_test.exs`** enroll + verify_backup rollback tests | `ALTER TABLE ... ADD CONSTRAINT ... CHECK` in **`try/after`** |

## Files to touch

| File | Role |
|------|------|
| `lib/sigra/mfa.ex` | **`confirm_enrollment/5`** — **021** path |
| `test/sigra/mfa_audit_atomicity_test.exs` | New cases for **021** (+ optional **022** assertions) |
| `.planning/phases/44-mfa-account-api-atomic-batches/44-AUD-04-INVENTORY.md` | Rows **020–022** |
| `.planning/phases/09-audit-logging/09-VERIFICATION.md` | C-1 **AUD-04-020..022** |

## PATTERN MAPPING COMPLETE
