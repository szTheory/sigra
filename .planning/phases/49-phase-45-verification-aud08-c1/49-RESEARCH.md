# Phase 49 — Technical research

**Question:** What do we need to know to plan **Phase 45 verification**, **AUD-08** closure, and **Phase 9 C-1** reconciliation well?

**Sources:** `49-CONTEXT.md`, `47-CONTEXT.md`, `48-CONTEXT.md`, `43-VERIFICATION.md`, `44-VERIFICATION.md`, `45-VALIDATION.md`, `45-06-SUMMARY.md`, `09-VERIFICATION.md`, `mix.exs`, `REQUIREMENTS.md`.

---

## 1. Frozen vs living artifacts

- **`45-VALIDATION.md`** is the **living** Nyquist-style map from phase **45** execution (`nyquist_compliant: true` there reflects **implementation** sign-off, not global batch **41–44**).
- **`45-VERIFICATION.md`** (to be created in phase **49**) is the **frozen** snapshot: verbatim `mix` commands, exit status, test counts, `git rev-parse HEAD`, and explicit deferral of full Nyquist **41–44** to **phase 50** — same split as **D-47-02** / **D-48-02**.

---

## 2. Merge gate and Mix alias (`D-49-03`)

- **`mix.exs`** today has **no** `aliases/0`; **43** and **44** closures used raw compound `mix test` lines. Phase **49** introduces **`mix ci.audit_45`** (rename only on collision) as the **single cited** merge gate in **`45-VERIFICATION.md`**, implemented as one `mix test` invocation with an **explicit file/directory list** (not bare `--only` tags without a guard).
- **45-06-SUMMARY.md** already documents a green scoped set: `test/sigra/oauth/`, worker + deletion + account audit + lockout + impersonation + suspicious_login + lockout + mfa + api_token tests. The alias should expand `test/sigra/oauth/` to explicit `*_test.exs` under that directory **or** keep the directory path if the team accepts directory loading (ExUnit loads all); for **reviewability**, prefer listing the same paths **45-06** used where they are files, and `test/sigra/oauth/` as one argument for the subtree.
- **Vacuous pass:** If the alias ever uses `--only some_tag`, pair with a minimum test count or manifest check. Default for **49**: explicit paths only — ExUnit fails if a path is missing.

---

## 3. C-1 reconciliation (`D-49-02`)

- Current **`09-VERIFICATION.md`** uses **“Matrix (representative; full detail in inventories)”** — fails ROADMAP criterion (2) for phase **49** (“no representative only ambiguity”).
- Replacement structure: short **completeness preamble** (expected ID ranges + mechanical check instructions), then **three subsections** keyed to **`43-AUD-04-INVENTORY.md`**, **`44-AUD-04-INVENTORY.md`**, **`45-AUD-04-INVENTORY.md`**, each table **ID → mechanism → tier → verdict → evidence pointer** (test path or plan summary). Canonical requirement text stays in inventory files.

---

## 4. REQ / ROADMAP ordering (`D-49-04`)

- Flip **`REQUIREMENTS.md`** **AUD-08** checkbox and traceability row to **Complete** only when **`45-VERIFICATION.md`** reads **`status: passed`** in the **same** change-set as C-1 updates (atomic default).
- **`09-03-SUMMARY.md`** should already reflect post-v1.4 pointers; adjust prose only if C-1 edits create drift.

---

## 5. Nyquist boundary

- **Do not** claim global Nyquist **41–44** completion in **49** artifacts; defer to **phase 50** in **`45-VERIFICATION.md` Notes** and keep **`49-VALIDATION.md`** `nyquist_compliant: false` unless `STATE.md` gains `nyquist_escalation_authorized`.

---

## Validation Architecture

Phase **49** validates **documentation**, **merge-gate reproducibility**, and **traceability** — not new auth product code.

| Dimension | Approach |
|-----------|----------|
| **1. Correctness** | **`45-VERIFICATION.md`** Must-haves cite **`45-AUD-04-INVENTORY.md`** slices and **`45-0x-SUMMARY.md`** evidence; commands match **`45-06-SUMMARY.md`** scoped proof set. |
| **2. Automated proof** | Merge gate (`mix compile` + **`mix ci.audit_45`**) executed at recorded SHA; PASS lines with test counts in **Automated checks run**. |
| **3. Completeness** | **`49-VALIDATION.md`** maps **49-01** / **49-02** tasks to greps + merge gate; C-1 subsections cover **all three** inventories exhaustively. |
| **4. Security / abuse** | No secrets in markdown; no **AUD-08** `[x]` before **`status: passed`**; plans carry `<threat_model>`. |
| **5. Maintainability** | Stable **`mix ci.audit_45`** name + pinned paths; link to **`docs/audit-semantics.md`**. |
| **6. Performance** | Scoped gate only; full root `mix test` optional attestation per **`CLAUDE.md`**. |
| **7. Operability** | Postgres env vars per **`CLAUDE.md`** (`PGUSER=postgres` …). |
| **8. Nyquist alignment** | **`49-VALIDATION.md`** Per-Task map ties each plan task to automated verify; global Nyquist explicitly **phase 50**. |

**Sampling:** After doc edits — acceptance greps; after **49-01** — merge gate once; **49-02** preflight requires **`status: passed`** before REQ edits.

---

## RESEARCH COMPLETE
