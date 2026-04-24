# Requirements: Sigra v1.12

**Defined:** 2026-04-23  
**Core value (from PROJECT.md):** Authentication that works out of the box with great DX on the happy path **and** on the rough edges — with **credible audit completeness** where we claim it, **honest machine vs human UAT** boundaries before a loud launch, and **adoption-facing docs** that match reality.

**Milestone framing:** **Trust, evidence, and adoption polish** — one more **bounded SEED-002** audit-atomicity batch (library + audit-aware tests + planning truth), a **SEED-001**-aligned **evidence and doc hub** so residual human checks are explicit (not implied), and **small triage-driven** trust/docs updates (upgrade continuity, maintainer pointers). **Research:** skipped (extends v1.9–v1.11 patterns; no new integration domain).

---

## Audit durability — bounded SEED-002 (AUD)

- [ ] **AUD-11**: At least **one** additional bounded subsystem batch from the Phase **9** **C-1** deferral set (canonical disposition in **`.planning/phases/09-audit-logging/09-VERIFICATION.md`**; row IDs trace to **43-/44-/45-** inventories) moves hybrid **`log_safe/3`** post-commit audit to **`Ecto.Multi`**-co-fated writes using **`Sigra.Audit.log_multi_safe/3`** (or an explicitly documented substitute approved in phase planning), with **audit-aware** regression tests merged under the **same** phase gate as the production change. **Phase 73**

- [ ] **AUD-12**: **`.planning/phases/09-audit-logging/09-03-SUMMARY.md`** reflects the **post-phase-73** batch (planning trace, “Recent bounded batches”, pointers). **`09-VERIFICATION.md`** is updated **only** when a **C-1** row’s mechanism, tier, or verdict materially changes; otherwise carry an explicit “no **`09-VERIFICATION.md`** edit required” rationale (**D-06** class). **Phase 74**

---

## Launch readiness — SEED-001 evidence (UAT)

- [ ] **UAT-01**: **`.planning/v1.12-UAT-EVIDENCE.md`** (or equivalently named canonical file under **`.planning/`**) records the **eight SEED-001** rows with: machine substitute pointer (test/job/doc), **residual human** note, and **outcome** per row (**Executed**, **Waived with substitute**, **Deferred** with owner/date/trigger) so a **loud public launch** has a single auditable index without claiming humans ran what CI already proves. **Phase 74**

- [ ] **UAT-02**: **`docs/uat-ci-coverage.md`** stays aligned with that evidence story: **v1.12** scope called out where posture changes, cross-links to the evidence file, and **no contradictions** with **`MAINTAINING.md`** / GA matrix pointers introduced this milestone. **Phase 74**

---

## Adoption / trust / docs (TRN)

- [ ] **TRN-01**: **`guides/introduction/upgrading-to-v1.12.md`** exists, explains planning **v1.12** vs Hex SemVer, links prior upgrade pages and **`.planning/v1.12-UAT-EVIDENCE.md`** (or the chosen canonical evidence path), and is listed in **`mix.exs`** ExDoc **`extras`** after **`upgrading-to-v1.11.md`** (with **`skip_undefined_reference_warnings_on`** updated if needed). **Phase 75**

- [ ] **TRN-02**: **Intro / maintainer discovery:** **`guides/introduction/getting-started.md`** (or the agreed faster-path surface) links **v1.12** upgrade + evidence where an integrator would look first; **`MAINTAINING.md`** (or **`CHANGELOG.md`**) mentions **v1.12** trust bundle (audit batch + UAT evidence) so operators know what shipped. **Phase 75**

- [ ] **TRN-03**: **Triage-driven polish:** At least **one** concrete outcome from **`.planning/v1.11-TRIAGE.md`** follow-ups **or** new GitHub-issue-derived doc/comment fix (link issue or triage row in phase summary); if no applicable items remain, phase plan documents **“no triage deltas”** with date and pointer to triage file state. **Phase 75**

---

## Future (not v1.12)

- **Full SEED-002** conversion of all remaining hybrid sites in one milestone.
- **Optional `sigra_lockspire`** — per **ADR 001** revisit triggers only.
- **Net-new auth features**, SAML/SCIM/IdP, or authorization product — out of scope.

---

## Out of scope (v1.12)

| Item | Reason |
|------|--------|
| **Whole-library SEED-002** | Bounded batches only; same policy as **v1.9** / **v1.10**. |
| **Mandatory live Google / full MUA matrix** | Residual human checks are **documented and optional** unless you explicitly schedule them; CI substitutes remain merge-blocking per existing policy. |
| **Lockspire glue package** | **ADR 001** — unchanged. |

---

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| AUD-11 | 73 | Pending |
| AUD-12 | 74 | Pending |
| UAT-01 | 74 | Pending |
| UAT-02 | 74 | Pending |
| TRN-01 | 75 | Pending |
| TRN-02 | 75 | Pending |
| TRN-03 | 75 | Pending |

**Coverage:** v1.12 requirements **7** total · mapped **7** · unmapped **0**

---

*Requirements defined: 2026-04-23 — `/gsd-new-milestone` (**v1.12** Trust, evidence, and adoption polish).*
