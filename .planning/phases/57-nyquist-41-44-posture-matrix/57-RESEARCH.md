# Phase 57 — Technical Research

**Question:** What do we need to know to plan the Nyquist **41–44** posture matrix well?

## Findings

### Maintainer surface (current)

- **`MAINTAINING.md`** already has **`## Nyquist policy (phases 41-44)`** with a four-row table using **tag-scoped GitHub blob URLs** (`v0.2.0`) for evidence. **57-CONTEXT D-05–D-07** require **repo-relative paths** as authority in the canonical matrix, with optional tag URLs as convenience.
- **`test/sigra/planning/phase_50_nyquist_docs_contract_test.exs`** asserts that heading string, **`41-backup-codes`**, **`44-mfa-account-api`**, and that each of **41–44** `*-VALIDATION.md` files match `nyquist_compliant:|phase 50|waiver`. Any MAINTAINING edit must **not** break **`50-01-05`** unless that test is updated in the same phase.

### Authoritative Nyquist posture per phase

Frontmatter on each `*-VALIDATION.md` (source for literal `nyquist_compliant`, per **D-09**):

| Phase | Slug directory | `nyquist_compliant` (VALIDATION frontmatter) |
|-------|----------------|-----------------------------------------------|
| 41 | `41-backup-codes-ga-product-closure` | `false` |
| 42 | `42-human-ga-matrix-evidence` | `false` |
| 43 | `43-audit-inventory-auth-atomic-batch` | `false` |
| 44 | `44-mfa-account-api-atomic-batches` | `false` |

**Milestone disposition (NYQ-02 vocabulary from 57-CONTEXT D-12):** All four shipped under v1.4 with **waiver + superseding evidence**; honest primary label is **`UNCHANGED`** (intentional non-elevation with recorded rationale in phase artifacts), not **`COMPLIANT`** and not **`DEFERRED`** unless roadmap explicitly reopens work.

### Evidence paths (canonical relative)

- **41:** `.planning/phases/41-backup-codes-ga-product-closure/41-VERIFICATION.md`, `41-VALIDATION.md`
- **42:** `.planning/phases/42-human-ga-matrix-evidence/42-VERIFICATION.md`, `.planning/v1.4-GA-UAT.md` (human GA matrix); **42-VALIDATION.md** exists
- **43:** `.planning/phases/43-audit-inventory-auth-atomic-batch/43-VERIFICATION.md`, `43-VALIDATION.md`
- **44:** `.planning/phases/44-mfa-account-api-atomic-batches/44-VERIFICATION.md`, `44-VALIDATION.md`

### Hex / tarball honesty

Per **D-08**: state once that deep `.planning/` paths are **not** assumed in the Hex package unless listed in **`mix.exs` `:files`** / ExDoc extras — same lesson as phase **56**.

### Optional automation (D-11)

Extend **`phase_50_nyquist_docs_contract_test.exs`** or add **`test/sigra/planning/phase_57_nyquist_matrix_contract_test.exs`** to assert: canonical matrix file exists, contains disposition tokens, contains `ref:` block, and links from `MAINTAINING.md` — without duplicating full matrix content in code.

## Validation Architecture

**Nyquist dimension:** Honest maintainer-facing disposition + evidence pointers; machine checks are **grep / ExUnit** on markdown structure, not product runtime behavior.

| Dimension | How this phase validates |
|-----------|---------------------------|
| 1–7 | N/A or doc-only — no new auth surface |
| 8 (maintainer truth) | `mix compile --warnings-as-errors`; `mix test test/sigra/planning/phase_50_nyquist_docs_contract_test.exs` unchanged green; optional **`phase_57_*`** contract if Plan 02 executes |
| Sign-off | Matrix file + `MAINTAINING.md` satisfy **NYQ-01** / **NYQ-02** grep criteria in plan acceptance |

**Feedback sampling:**

- After doc edits: scoped **`mix test`** on planning contract tests touched.
- Before phase close: full **`phase_50`** doc contract + compile.

---

## RESEARCH COMPLETE

Research sufficient to author **57-VALIDATION.md**, canonical **`.planning/nyquist-phases-41-44-matrix.md`**, and **`57-*-PLAN.md`** tasks with concrete grep acceptance.
