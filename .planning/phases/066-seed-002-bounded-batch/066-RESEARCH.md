# Phase 66 — Technical research (SEED-002 / `confirm_enrollment`)

**Phase:** 66 — SEED-002 bounded batch  
**Requirement:** AUD-09  
**Question:** What must change in code, tests, and C-1 artifacts for **`Sigra.MFA.confirm_enrollment/5`** rows **AUD-04-020..022**?

---

## Code truth (2026-04-23)

### Success path — AUD-04-020

`lib/sigra/mfa.ex` **`confirm_enrollment/5`** (after TOTP verifies):

- Builds **`Ecto.Multi`** with **`Multi.insert(:credential, ...)`**, **`Multi.insert_all(:backup_codes, ...)`**, then **`Sigra.Audit.log_multi_safe("mfa.enroll.success", ...)`**.
- Runs **`repo.transaction(multi)`** once.
- On **`{:ok, changes}`** calls **`Sigra.Audit.emit_telemetry_from_changes(changes)`**.

This is **T1** per `docs/audit-semantics.md` (audit insert co-fated with domain writes in the same transaction).

**Gap:** `.planning/phases/44-mfa-account-api-atomic-batches/44-AUD-04-INVENTORY.md` still describes **020** as `log_safe` (post-transaction). **`09-VERIFICATION.md`** C-1 table matches that stale wording. **Executor:** align docs/inventory with code; no forced production change unless tests reveal a hole.

### Transaction failure path — AUD-04-021

On **`{:error, _step, changeset, _changes}`** from the enrollment **`Multi`**, the code calls **`Sigra.Audit.log_safe("mfa.enroll.failure", ...)`** with **`metadata: %{reason: "insert_failed"}`** and returns **`{:error, changeset}`**.

- Domain effects from the failed **`Multi`** are rolled back — consistent with “no partial credential”.
- Audit uses **`log_safe`** (separate **`repo.insert`**, best-effort / telemetry on failure).

**CONTEXT D-02** flags **021** as the **primary T1-class target**: same *narrative* as phase **61** / **067** — auditors want a **named, `Multi`-shaped** audit path where a **`Repo.transaction/1`** boundary exists, avoiding “silent” post-rollback **`log_safe`** for events that are security-relevant.

**Recommendation:** For **`reason: "insert_failed"`** only, replace **`log_safe`** with:

```elixir
repo.transaction(
  Multi.new()
  |> Sigra.Audit.log_multi_safe("mfa.enroll.failure", opts_with_failure_metadata)
)
```

…and **`emit_telemetry_from_changes/1`** on **`{:ok, changes}`**, mirroring success-path discipline. Preserve **`{:error, changeset}`** as the public return; if the audit-only transaction fails, document behavior (raise vs return — match **`verify_backup`** / **061** precedent: transaction failure surfaces **`Ecto`** error or controlled handling).

**Risk:** **`log_safe`** swallows insert errors; **`repo.transaction`** does not. **Mitigation:** executor reads **`do_log_safe`** vs **`log_multi_safe`** and phase **061** failure branches for parity.

### Invalid TOTP before DB — AUD-04-022

**`{:error, _reason}`** from **`verify_totp`** → **`log_safe("mfa.enroll.failure", ..., metadata: %{reason: "invalid_code"})`** → **`{:error, :invalid_code}`**.

No DB mutation in this branch. **CONTEXT D-02** default: keep **documented T2** / **EX-44-02** unless a new **EX-*** is approved in-repo. **Planner:** matrix + inventory honesty only unless discuss-phase unlocks a fake **`Multi`**.

---

## Test surface

**`test/sigra/mfa_audit_atomicity_test.exs`** already has:

- Success co-fate + **`mfa.enroll.success`** count.
- **`mfa_atomicity_guard`** rejecting **`mfa.enroll.success`** → full rollback.

**Gaps for 066:**

1. **021:** Deterministic path into **`insert_failed`** (e.g. force **`insert_all`** or a child step to fail after a hypothetical partial state — **note:** **`Multi`** rolls back all steps; use constraint or invalid FK on **`backup_codes`** / oversized batch to trigger **`{:error, ...}`** on **`backup_codes`** or **`credential`** step, then assert **`mfa.enroll.failure`** with **`insert_failed`** and DB empty).
2. **Optional:** Assert **`invalid_code`** branch leaves **no** **`user_mfa_credentials`** rows and optional audit row policy (today **`log_safe`** inserts when audit_schema set).

---

## Documentation merge policy (D-07 / D-08)

Same PR as production/tests:

- **`.planning/phases/09-audit-logging/09-VERIFICATION.md`** — update **AUD-04-020..022** mechanism / tier / verdict columns to match merged code + honest T2 for **022** if unchanged.
- **`.planning/phases/44-mfa-account-api-atomic-batches/44-AUD-04-INVENTORY.md`** — sync mechanism column and add **Phase 66** closure note (mirror **061-02** pattern).

No substantive **`09-03-SUMMARY.md`** edits (**phase 67**).

---

## Validation Architecture

| Dimension | Strategy |
|-----------|----------|
| **1 — Correctness** | `mix test test/sigra/mfa_audit_atomicity_test.exs` green; enrollment paths return same tuples as today except documented audit-txn behavior change for **021**. |
| **2 — Regression** | `MIX_ENV=test mix compile --warnings-as-errors`; scoped **`mfa.ex`** grep invariants from **CONTEXT** ( **`log_multi_safe`** on success **`Multi`**; failure **`Multi`** for **021** after change). |
| **3 — Security / audit** | C-1 rows for **020..022** match mechanism in **`lib/sigra/mfa.ex`**; no phantom **T1** claims for **022** if code stays **`log_safe`**. |
| **4 — Performance** | Audit-only transaction for **021** is single-row insert — negligible vs enrollment path. |
| **5 — DX** | Preserve **`confirm_enrollment/5`** `@doc` and option keys; fault messages remain **`Ecto.Changeset`**-driven on domain failure. |
| **6 — Compatibility** | Public function arity and **`{:ok, _}` / {:error, _}`** shapes preserved. |
| **7 — Observability** | **`emit_telemetry_from_changes`** invoked when audit-only **`Multi`** succeeds for **021**. |
| **8 — Nyquist / feedback** | After each task: atomicity test file; after wave: full library tests if CI contract requires (see **066-VALIDATION.md**). |

---

## RESEARCH COMPLETE

Findings are sufficient for **`066-*-PLAN.md`** tasks: doc alignment for **020**, optional production tightening for **021**, honest **022** labeling, tests + C-1 merge.
