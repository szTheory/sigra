# Nyquist posture matrix (phases 41–44)

This file is the **canonical** maintainer grid for Nyquist **honesty** across GA phases **41–44**. If anything in **`MAINTAINING.md`** disagrees with this matrix, **this file wins** (see phase **57** context **D-03**).

**Hex / tarball honesty:** paths under **`.planning/`** are **not** assumed to ship in the Hex package unless they are explicitly listed in **`mix.exs` `:files`** / ExDoc extras. Treat this matrix as **clone / GitHub tag** evidence, not something consumers can rely on from **hexdocs.pm** alone (**D-08**).

**ref:**

- **tag:** `v1.5`
- **commit:** `7b1001d05a2a749ca744bdcde28aee9d189828d2`
- **date:** 2026-04-22

Primary **`nyquist_compliant:`** and waiver narrative remain authoritative in each phase’s **`*-PLAN.md` / `*-VALIDATION.md` frontmatter**; this table is a maintainer-facing summary plus pointers (**D-09**, **D-10**).

| Phase slug | Primary disposition | Nyquist / waiver mode | `VERIFICATION.md` path | `VALIDATION.md` path | Reopen trigger | Optional tag-scoped URL |
|------------|---------------------|------------------------|-------------------------|------------------------|----------------|-------------------------|
| `41-backup-codes-ga-product-closure` | **UNCHANGED** | Waiver + superseding evidence | `.planning/phases/41-backup-codes-ga-product-closure/41-VERIFICATION.md` | `.planning/phases/41-backup-codes-ga-product-closure/41-VALIDATION.md` | Changes under **`priv/templates/sigra.install/`** or **`lib/sigra/install/`** → **`PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix ci.install_golden`**; GA-01 map edits in **`41-VALIDATION.md`** → re-verify per that file. | ([`41-VERIFICATION` @ v1.5](https://github.com/szTheory/sigra/blob/v1.5/.planning/phases/41-backup-codes-ga-product-closure/41-VERIFICATION.md)) |
| `42-human-ga-matrix-evidence` | **UNCHANGED** | Waiver + superseding evidence | `.planning/phases/42-human-ga-matrix-evidence/42-VERIFICATION.md` | `.planning/phases/42-human-ga-matrix-evidence/42-VALIDATION.md` | Human GA rows **GA-02..GA-05** in **`.planning/v1.4-GA-UAT.md`** flip from **Pending** / protocol text changes → refresh human evidence and this row. | ([`v1.4-GA-UAT` @ v1.5](https://github.com/szTheory/sigra/blob/v1.5/.planning/v1.4-GA-UAT.md)) |
| `43-audit-inventory-auth-atomic-batch` | **UNCHANGED** | Waiver + superseding evidence | `.planning/phases/43-audit-inventory-auth-atomic-batch/43-VERIFICATION.md` | `.planning/phases/43-audit-inventory-auth-atomic-batch/43-VALIDATION.md` | Same installer path rule as **41** → **`mix ci.install_golden`**; AUD-04/05 map edits → re-run scoped merge gate in **`43-VERIFICATION.md`**. | ([`43-VERIFICATION` @ v1.5](https://github.com/szTheory/sigra/blob/v1.5/.planning/phases/43-audit-inventory-auth-atomic-batch/43-VERIFICATION.md)) |
| `44-mfa-account-api-atomic-batches` | **UNCHANGED** | Waiver + superseding evidence | `.planning/phases/44-mfa-account-api-atomic-batches/44-VERIFICATION.md` | `.planning/phases/44-mfa-account-api-atomic-batches/44-VALIDATION.md` | Same installer path rule as **41** → **`mix ci.install_golden`**; atomicity test bundle touched → re-run scoped merge gate in **`44-VERIFICATION.md`**. | ([`44-VERIFICATION` @ v1.5](https://github.com/szTheory/sigra/blob/v1.5/.planning/phases/44-mfa-account-api-atomic-batches/44-VERIFICATION.md)) |

### Rationale for **UNCHANGED** (all four rows)

- **41:** **`nyquist_compliant: false`** in **`41-VALIDATION.md`** — GA-01 scope uses installer CI + waiver narrative; matrix records intentional non-elevation with superseding CI evidence.
- **42:** **`nyquist_compliant: false`** in **`42-VALIDATION.md`** — human GA matrix evidence is waived with pointer to **`.planning/v1.4-GA-UAT.md`**; formal elevation deferred.
- **43:** **`nyquist_compliant: false`** in **`43-VALIDATION.md`** — audit inventory + auth atomicity batch ships under waiver + **`43-VERIFICATION.md`** scoped checks.
- **44:** **`nyquist_compliant: false`** in **`44-VALIDATION.md`** — MFA + account API atomic batches documented under waiver + **`44-VERIFICATION.md`** merge gate.

Cross-check: **`.planning/v1.4-GA-UAT.md`** is cited from **42** as primary human-evidence spine alongside **`42-VERIFICATION.md`**.
