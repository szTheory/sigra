# Phase 47 — Technical research

**Question:** What do we need to know to plan **Phase 43 verification & AUD-04/05 closure** well?

**Sources:** `47-CONTEXT.md`, `43-CONTEXT.md`, `43-VALIDATION.md`, `43-AUD-04-INVENTORY.md`, `43-01`..`43-04-SUMMARY.md`, `46-VERIFICATION.md`, `REQUIREMENTS.md`, `ROADMAP.md`.

---

## 1. Evidence model (two-file pattern)

- **`43-VALIDATION.md`** — Living Nyquist-style map: per-task rows, sampling policy, command *patterns*. During execution it can lag; phase **47** must bring row **Status** and **Automated Command** cells in line with **actual** plan artifacts (`43-02`..`43-04-PLAN.md`) and merged code/tests.
- **`43-VERIFICATION.md`** (new) — **Dated snapshot** like `46-VERIFICATION.md`: YAML frontmatter (`status`, `phase: "43"`, `verified`), **Must-haves** table keyed to inventory row IDs / AUD-05 boundaries, **Automated checks run** with **verbatim** shell commands and exit-0 receipts, **Notes** for Nyquist deferral to phase **50** (per D-47-01).
- **Authority rule (D-47-02):** At sign-off, verification file owns canonical command strings for the merge gate; validation file cross-links and avoids unsynchronized drift.

---

## 2. AUD-05 merge-gate command set (from phase 43 execution)

Concrete test modules proving Auth atomicity (DB-backed, Postgres per `CLAUDE.md`):

| Boundary | Test path |
|----------|-----------|
| Register + audit | `test/sigra/auth/register_audit_atomicity_test.exs` |
| Magic link + password reset request + audit | `test/sigra/auth/magic_link_and_reset_request_audit_atomicity_test.exs` |
| Login success + lockout reset + audit | `test/sigra/auth/login_and_lockout_audit_atomicity_test.exs` |
| Regression guard (plain map / auth) | `test/sigra/auth_test.exs` (cited in `43-04-PLAN.md` verify) |

**Merge gate (D-47-03):** Minimum: `mix compile` with repo warnings policy **if** already enforced on `main`; plus **enumerated** `mix test` on the four paths above (single compound command acceptable). Use env prefix: `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test`.

**Release attestation (optional but recommended):** Full root `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test` — record in verification **Notes** with date/hostname or CI job URL when run.

**Mix alias (discretion):** Root `mix.exs` has **no** `aliases:` today. Optional `mix ci.audit_43` wrapping the compound test list reduces drift; if added, verification doc must cite the alias verbatim.

---

## 3. AUD-04 inventory as scope truth

- **`43-AUD-04-INVENTORY.md`** remains the canonical list of `log_safe/3` sites, exclusions, and row IDs.
- **Verification Must-haves** should reference **row IDs** (or section anchors) the merge gate proves, not vague “grep clean” language alone.
- **43-01-PLAN** inventory task used `rg "Sigra\.Audit\.log_safe" lib/sigra` as ground truth — acceptable **supplemental** grep line in verification under merge gate or Notes.

---

## 4. REQUIREMENTS / ROADMAP reconciliation (D-47-04)

- Flip **AUD-04** and **AUD-05** checkboxes and traceability rows **only** in the same change-set as **`43-VERIFICATION.md`** (same PR).
- Refresh **traceability table** and any phase **47–49** prose in the **same edit** as checkbox flips.
- **ROADMAP** line for phase **47**: adjust only if narrative drifts vs. delivered verification (optional micro-edit).

---

## 5. Nyquist boundary (D-47-01)

- Do **not** set `nyquist_compliant: true` on `43-VALIDATION.md` frontmatter unless project explicitly escalates from phase **50**.
- **`43-VERIFICATION.md`** should contain a short factual paragraph: full Nyquist batch **41–44** remains **phase 50**; phase **47** delivers falsifiable **43** evidence only.

---

## Validation Architecture

Phase **47** validates **documentation integrity** and **traceability** — not new product code. Sampling and dimensions:

| Dimension | Approach |
|-----------|----------|
| **1. Correctness** | `43-VERIFICATION.md` Must-haves align with `43-AUD-04-INVENTORY.md` rows and merged `lib/sigra/auth.ex` / `lib/sigra/audit.ex` behavior described in `43-0x-SUMMARY.md`. |
| **2. Automated proof** | Every merge-gate command in verification was executed at recorded SHA; exit 0 logged or CI URL cited. |
| **3. Completeness** | `43-VALIDATION.md` per-task map covers plans **01–04** with non-placeholder commands; Status reflects ✅/⚠️ honestly. |
| **4. Security / abuse** | No invented test results; no flipping REQ checkboxes without verification file present (tampering / repudiation). Plans include `<threat_model>`. |
| **5. Maintainability** | Prefer stable `mix` alias or fixed file list over vague “auth subset”. |
| **6. Performance** | Scoped tests first; full suite as attestation — wall-clock noted in Notes if relevant. |
| **7. Operability** | Commands copy-paste from `CLAUDE.md` Postgres one-liner. |
| **8. Nyquist alignment** | `47-VALIDATION.md` maps each plan task to automated verify; Dimension 8 satisfied by cross-reference to phase **50** for global Nyquist, not by false `nyquist_compliant` on **43**. |

**Sampling:** After each documentation edit task — grep acceptance; after full **47-01** wave — run merge-gate compound `mix test` once; optional full suite before REQ flip (**47-02**).

---

## Open questions (resolved in CONTEXT)

- Nyquist vs verification → **Deferred to 50**; evidence-first in **47**.
- UI-SPEC → **N/A** (no frontend phase).

---

## RESEARCH COMPLETE
