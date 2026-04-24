# Phase 73: Bounded audit atomicity batch — Research

**Gathered:** 2026-04-23  
**Question:** What is needed to plan AUD-11 closure for MFA **AUD-04-023..032**?

## Executive summary

**Production (`lib/sigra/mfa.ex`) already implements** `Ecto.Multi` + `Sigra.Audit.log_multi_safe/3` for **023–025** (verify TOTP success / failure / bundled lockout), **028–029** (`cleanup_mfa/6` disable audit on the same `Multi` as deletes + trust revoke), **030** (regenerate success), and **031–032** (regenerate wrong-TOTP failure + bundled lockout). The **D-26** header comment (~lines 35–43) matches shipped code.

**Drift is planning-side:** `.planning/phases/09-audit-logging/09-VERIFICATION.md` C-1 table and `.planning/phases/44-mfa-account-api-atomic-batches/44-AUD-04-INVENTORY.md` (table + stale `rg` log) still label **023–025**, **028–029**, **031–032** as `log_safe` / “target Multi (phase 44 closure)”.

**AUD-11 satisfaction path (no code fiction):** Same merge gate updates **C-1 + inventory** to **T1** where `lib/` already proves **Multi**-co-fated audit, and extends **`test/sigra/mfa_audit_atomicity_test.exs`** with **CHECK**-constraint fault injection for **Multi** compositions that lack rollback receipts today (verify success, verify failure/lockout bundle, regenerate success, regenerate failure/lockout bundle). **AUD-04-022**, **033**, **034** remain **EX-44-02..04** per **073-CONTEXT**.

## Row-by-row mechanism (authoritative: `lib/sigra/mfa.ex`)

| Row | Action(s) | Lines (approx) | Mechanism |
|-----|-----------|----------------|-----------|
| AUD-04-023 | `mfa.verify.success` | 291–310 | `Multi.update_all` + `log_multi_safe` → one `repo.transaction/1` |
| AUD-04-024 | `mfa.verify.failure` | 325–341 | `Multi` + `Lockout.increment` + `log_multi_safe` |
| AUD-04-025 | `mfa.lockout` | 342–360 | `Multi.merge` appends second `log_multi_safe` when `inc.locked` |
| AUD-04-026–027 | backup success | 424–453 | Dual `log_multi_safe` on consume `Multi` |
| AUD-04-028–029 | `mfa.disable` | 1007–1033 `cleanup_mfa` | `log_multi_safe` on same `Multi` as `delete_all` / `revoke_trust` |
| AUD-04-030 | `mfa.backup_codes_regenerate` | 691–726 | `BackupCodes.append_replace_steps` + `sync_credential` + `log_multi_safe` |
| AUD-04-031 | `mfa.verify.failure` (regen) | 741–757 | Same pattern as **024** |
| AUD-04-032 | `mfa.lockout` (regen) | 758–776 | Same pattern as **025** |

## Exclusions (unchanged this phase)

- **AUD-04-022** — invalid enroll code, **`log_safe`**, **EX-44-02**.
- **AUD-04-033** / **034** — legacy / trust observability, **EX-44-03** / **EX-44-04**.

## Risk notes

- **Inventory grep block** in **44-AUD-04-INVENTORY.md** is historically stale (line numbers + `log_safe` references); refresh must be **machine-regenerated** from current `rg` or manually reconciled to avoid new drift.
- **`disable/4`** calls **`verify/4`** first — tests must not assume a single transaction spans verify + cleanup; existing disable atomicity test already targets **`cleanup_mfa`** audit only.

## Validation Architecture

| Dimension | Strategy |
|-----------|----------|
| **1 — Correctness** | Scoped `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/mfa_audit_atomicity_test.exs` green; no change to public MFA return tuples except any fix if review finds a stray **`log_safe`** hot path in **023–032** (not expected). |
| **2 — Regression** | `MIX_ENV=test mix compile --warnings-as-errors`; greps in **073-01-PLAN** prove **09-VERIFICATION** / **44-AUD-04-INVENTORY** cells match **`lib/sigra/mfa.ex`**. |
| **3 — Security / audit** | C-1 rows **023–032** verdict **T1 (Multi-bound)** align with **`docs/audit-semantics.md`**; no **T1** claim for **022** / **033** / **034**. |
| **4 — Performance** | No new transactions beyond tests’ temporary **CHECK** constraints. |
| **5 — DX** | Doc edits only in planning matrices + optional one-line cross-links; tests follow **061**/**066** fault-injection style. |
| **6 — Compatibility** | No breaking API changes planned. |
| **7 — Observability** | Existing **`emit_telemetry_from_changes`** call sites unchanged unless a production bug is found. |
| **8 — Nyquist / feedback** | Per **073-VALIDATION.md** — run atomicity file after each test task; wave close re-runs full scoped file. |

---

## RESEARCH COMPLETE

Findings support **073-*-PLAN.md**: documentation reconciliation + targeted **`mfa_audit_atomicity_test.exs`** extensions; **no** mandatory **`mfa.ex`** edit unless reconciliation discovers a live **`log_safe`** path in the **023–032** band.
