# Requirements: Sigra v1.7

**Defined:** 2026-04-23  
**Core Value (from PROJECT.md):** Authentication that works out of the box with great DX on the happy path **and** on the rough edges — including **credible adoption paths** and continued **audit-trail durability** work (**SEED-002**) in bounded, merge-gated batches.

This milestone **does not** ship Sigra as an OAuth/OIDC **identity provider** (that remains out of scope for the core library). It **does** document how hosts combine Sigra with a **separate** embedded authorization-server library when they need developer-facing OAuth.

---

## Adoption & documentation (ADOPT)

- [x] **ADOPT-01**: A **first-hour** guide exists under `guides/introduction/` and is linked from `getting-started.md` / ExDoc extras so a new adopter can complete a minimal happy path without tribal knowledge.
- [x] **ADOPT-02**: **`guides/introduction/upgrading-to-v1.7.md`** documents post-**v1.6** maintainer-facing changes (Nyquist/OA narrative, CI expectations) and points to archives under `.planning/milestones/`.
- [x] **ADOPT-03**: **`guides/introduction/troubleshooting-install.md`** lists the top install / compile / test failures with fixes (Postgres, env, optional deps, install golden pointers).

---

## Companion OAuth provider (INTG)

- [x] **INTG-01**: **`guides/recipes/companion-oauth-provider.md`** explains the **clean boundary**: Sigra = end-user / RP login; companion = embedded OAuth/OIDC **authorization server** for third-party clients; **no** Hex dependency between the two cores; host-owned `AccountResolver` seam.

---

## Audit durability — SEED-002 continuation (AUD)

- [x] **AUD-01**: At least **one** bounded subsystem batch from the Phase **9** **C-1** deferral set moves from hybrid `log_safe/3` post-commit audit to **`Ecto.Multi`-atomic** audit writes (or an explicitly documented substitute), with **audit-aware** tests merged under the same phase gate as the production change. **Shipped Phase 61 (2026-04-23):** `verify_backup/4` invalid-backup path + **`mfa_audit_atomicity_test.exs`** + **AUD-04-067** / C-1 updates.
- [ ] **AUD-02**: **`.planning/phases/09-audit-logging/09-03-SUMMARY.md`** (and, if applicable, **09-VERIFICATION.md** caveat rows) reflects the **post-batch** reality so C-1 narrative cannot silently drift.

---

## Out of scope (v1.7)

- Full **SEED-002** conversion across **all** remaining sites in one milestone.
- **Live Google** (or other real IdP) OAuth in CI; new Assent providers.
- SAML, SCIM, Sigra-shipped IdP mode, or **mandatory** dependency on any companion OAuth server library.
- Optional Hex package **`sigra_lockspire`** (see `.planning/decisions/001-defer-sigra-lockspire-glue-package.md`).

---

## Future (post-v1.7)

- Further **SEED-002** batches until C-1 is honestly downgraded or closed.
- **SEED-001** human rows when a milestone explicitly targets **public launch / loud marketing**.
- Optional **example app** repo (Sigra + companion) once companion install DX is stable.

---

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| ADOPT-01 | 60 | Complete |
| ADOPT-02 | 60 | Complete |
| ADOPT-03 | 60 | Complete |
| INTG-01 | 60 | Complete |
| AUD-01 | 61 | Complete |
| AUD-02 | 62 | Pending |

**Coverage**

- v1.7 requirements: **6** total  
- Mapped to phases: **6**  
- Unmapped: **0**  
- **Complete:** 5 (**ADOPT***, **INTG-01**, **AUD-01**) — **Pending:** **AUD-02** (Phase **62**)

---

*Requirements defined: 2026-04-23 after trajectory + Lockspire integration plan implementation.*
