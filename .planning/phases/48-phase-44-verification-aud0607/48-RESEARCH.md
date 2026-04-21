# Phase 48 — Technical research

**Question:** What do we need to know to plan **Phase 44 verification & AUD-06/07 closure** well?

**Sources:** `48-CONTEXT.md`, `44-CONTEXT.md`, `44-VALIDATION.md`, `44-AUD-04-INVENTORY.md`, `44-01`..`44-05-SUMMARY.md`, `43-VERIFICATION.md`, `47-CONTEXT.md`, `47-01-PLAN.md`, `REQUIREMENTS.md`, `ROADMAP.md`.

---

## 1. Evidence model (two-file pattern, same as 47 / 43)

- **`44-VALIDATION.md`** — Living map: per-plan rows for **44-01..44-05**, honest **File Exists** / **Status**, and **Automated Command** cells bound to real paths. Phase **48** must fix drift (e.g. rows still showing ❌ for `mfa_audit_atomicity_test.exs` when the file exists on `main`).
- **`44-VERIFICATION.md`** (new) — Dated snapshot like **`43-VERIFICATION.md`**: YAML (`status`, `phase: "44"`, `verified`), **Must-haves** with **separate subsections or tables for AUD-06 vs AUD-07** (**D-48-02**), verbatim **Merge gate** commands, **Automated checks run** with PASS/FAIL receipts, **Notes** with `git rev-parse HEAD` and **phase 50** Nyquist ownership (**D-48-03**).
- **Authority:** At sign-off, **`44-VERIFICATION.md`** owns canonical merge-gate strings; **`44-VALIDATION.md`** stays aligned but may evolve later (**D-48-02**).

---

## 2. AUD-06 / AUD-07 merge-gate command set (from merged phase 44 work)

| REQ | Role | Test paths (Postgres-backed, per `CLAUDE.md`) |
|-----|------|-----------------------------------------------|
| **AUD-06** | MFA `log_safe` → Multi + audit-aware tests | `test/sigra/mfa_audit_atomicity_test.exs` |
| **AUD-07** | Account + API token remainder | `test/sigra/account_audit_atomicity_test.exs`, `test/sigra/api_token_audit_atomic_test.exs` |
| **Foundation** | Plan **44-02** audit Multi step / telemetry | `test/sigra/audit_multi_step_test.exs` |

**Merge gate (D-48-01 / D-47-03 ladder):**

1. `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix compile`
2. Single compound:

   `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/mfa_audit_atomicity_test.exs test/sigra/account_audit_atomicity_test.exs test/sigra/api_token_audit_atomic_test.exs test/sigra/audit_multi_step_test.exs`

**Release attestation (optional):** Full root `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test` — record **Executed** or **Not run in this closure** honestly.

**Mix alias (discretion):** Optional `mix ci.audit_44` wrapping the compound line; if skipped, **Notes** must say raw compound is canonical (same pattern as **43** closure).

---

## 3. Inventory and summaries as scope truth

- **`44-AUD-04-INVENTORY.md`** — Row IDs **AUD-04-020+** for MFA / Account / API; Must-haves should cite rows or section anchors the merge gate supports, not vague “grep clean only.”
- **`44-0x-SUMMARY.md`** — Narrative evidence for each plan; verification tables should point to the right summary file per boundary.

---

## 4. REQUIREMENTS / ROADMAP reconciliation (D-48-02 / D-48-04)

- Flip **AUD-06** and **AUD-07** only in the **same** change-set as **`44-VERIFICATION.md`** with `status: passed` (**D-48-04**).
- Traceability table: **Complete** dates aligned with `verified:` in **`44-VERIFICATION.md`**.
- **ROADMAP** row **48** or **44**: micro-edit only if narrative drifts; criterion (3) “Nyquist run if required” satisfied by explicit **phase 50** deferral + falsifiable scoped verification — not by setting **`nyquist_compliant: true`** on **`44-VALIDATION.md`** early (**D-48-03**).

---

## 5. Nyquist boundary (D-48-03)

- Do **not** set **`nyquist_compliant: true`** on **`44-VALIDATION.md`** unless **`STATE.md`** records an explicit escalation (same discipline as **47** / **43**).
- **`44-VALIDATION.md` sign-off checklist** must not *require* `nyquist_compliant: true` for phase **48** closure; replace with honest “deferred to phase **50**” language where templates default to true.

---

## Validation Architecture

Phase **48** validates **documentation integrity**, **traceability**, and **command-backed audit evidence** for phase **44** — not new product auth features (those are phase **44**).

| Dimension | Approach |
|-----------|----------|
| **1. Correctness** | `44-VERIFICATION.md` Must-haves align with **`44-AUD-04-INVENTORY.md`**, **`44-VALIDATION.md`**, and merged **`lib/sigra/mfa.ex`**, **`account.ex`**, **`api_token.ex`** / **`audit.ex`** per summaries. |
| **2. Automated proof** | Merge-gate `mix compile` + compound `mix test` executed at recorded SHA; exit 0 logged in **Automated checks run**. |
| **3. Completeness** | Per-task map covers plans **44-01..44-05**; **File Exists** ✅ matches repo; **Status** reflects ✅ / ⚠️ honestly. |
| **4. Security / abuse** | No invented test results; no REQ checkbox flips without **`status: passed`** verification (**T-48-xx** in plans). |
| **5. Maintainability** | Stable file list or optional **`mix ci.audit_44`** — avoid hand-maintained globs that drift (**D-48-01**). |
| **6. Performance** | Scoped compound tests as merge gate; full suite as optional attestation. |
| **7. Operability** | Commands copy-paste with **`CLAUDE.md`** Postgres env vars. |
| **8. Nyquist alignment** | **`48-VALIDATION.md`** maps plan tasks to greps / merge gate; Dimension **8** satisfied by cross-reference to **phase 50** for batch **41–44**, not by false **`nyquist_compliant: true`** on **`44-VALIDATION.md`**. |

**Sampling:** After **`44-VALIDATION.md`** edits — acceptance greps; after **`44-VERIFICATION.md`** creation — run merge gate once; before **`48-02`** — confirm **`status: passed`**.

---

## RESEARCH COMPLETE

Ready for **`48-01` / `48-02` plans**: align **`44-VALIDATION.md`**, publish **`44-VERIFICATION.md`**, run merge gate, reconcile **REQUIREMENTS.md** + **ROADMAP.md**.
