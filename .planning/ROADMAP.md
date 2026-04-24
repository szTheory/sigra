# Roadmap: Sigra

## Milestones

- ✅ **v1.0 Phoenix Auth Library - Initial Release** - Phases 1-10 + 10.1 + 10.1.1 (shipped 2026-04-11). See [v1.0 archive](milestones/v1.0-ROADMAP.md) and [MILESTONES.md](MILESTONES.md).
- ✅ **v1.1 Foundations** - Phases 11-23 (shipped 2026-04-16). See [v1.1 archive](milestones/v1.1-ROADMAP.md), [v1.1 requirements](milestones/v1.1-REQUIREMENTS.md), and [MILESTONES.md](MILESTONES.md).
- ✅ **Post-v1.1 Closeout** - Phases 24-26 (completed 2026-04-16).
- ✅ **v1.2 Admin Dashboard** - Phases 27-31 + gap closure 32-35 (shipped 2026-04-17). See [v1.2 archive](milestones/v1.2-ROADMAP.md), [v1.2 requirements](milestones/v1.2-REQUIREMENTS.md), [v1.2 milestone audit](milestones/v1.2-MILESTONE-AUDIT.md), and [MILESTONES.md](MILESTONES.md).
- ✅ **v1.3 Cleanup & Hardening** — Phases 36-40 (shipped 2026-04-19). See [v1.3 archive](milestones/v1.3-ROADMAP.md), [v1.3 requirements](milestones/v1.3-REQUIREMENTS.md), [v1.3 milestone audit](milestones/v1.3-MILESTONE-AUDIT.md), and [MILESTONES.md](MILESTONES.md).
- ✅ **v1.4 GA readiness & audit trail completeness** — Phases **41–52** (shipped **2026-04-22**). See [v1.4 archive](milestones/v1.4-ROADMAP.md), [v1.4 requirements](milestones/v1.4-REQUIREMENTS.md), [v1.4 milestone audit](milestones/v1.4-MILESTONE-AUDIT.md), and [MILESTONES.md](MILESTONES.md).
- ✅ **v1.5 Public release narrative & community readiness** — Phases **53–56** (shipped **2026-04-22**). See [v1.5 archive](milestones/v1.5-ROADMAP.md), [v1.5 requirements](milestones/v1.5-REQUIREMENTS.md), and [MILESTONES.md](MILESTONES.md).
- ✅ **v1.6 Nyquist closure + OAuth audit depth** — Phases **57–59** (shipped **2026-04-23**). See [v1.6 archive](milestones/v1.6-ROADMAP.md), [v1.6 requirements](milestones/v1.6-REQUIREMENTS.md), [v1.6 milestone audit](milestones/v1.6-MILESTONE-AUDIT.md), and [MILESTONES.md](MILESTONES.md).
- ✅ **v1.7 Adoption readiness & audit durability** — Phases **60–62** (shipped **2026-04-23**). See [v1.7 archive](milestones/v1.7-ROADMAP.md), [v1.7 requirements](milestones/v1.7-REQUIREMENTS.md), [v1.7 milestone audit](milestones/v1.7-MILESTONE-AUDIT.md), and [MILESTONES.md](MILESTONES.md).
- ✅ **v1.8 Adopter polish (diminishing returns)** — Phases **63–65** (shipped **2026-04-23**). See [v1.8 archive](milestones/v1.8-ROADMAP.md), [v1.8 requirements](milestones/v1.8-REQUIREMENTS.md), and [MILESTONES.md](MILESTONES.md).
- ✅ **v1.9 Audit atomicity (bounded SEED-002)** — Phases **66–67** (shipped **2026-04-23**). See [v1.9 archive](milestones/v1.9-ROADMAP.md), [v1.9 requirements](milestones/v1.9-REQUIREMENTS.md), [v1.9 milestone audit](milestones/v1.9-MILESTONE-AUDIT.md), and [MILESTONES.md](MILESTONES.md).
- ✅ **v1.10 Adopter confidence for solo production** — Phases **68–70** (shipped **2026-04-23**). See [v1.10 archive](milestones/v1.10-ROADMAP.md), [v1.10 requirements](milestones/v1.10-REQUIREMENTS.md), [v1.10 milestone audit](milestones/v1.10-MILESTONE-AUDIT.md), and [MILESTONES.md](MILESTONES.md).
- ✅ **v1.11 Adoption stabilization** — Phases **71–72** (shipped **2026-04-23**). See [v1.11 archive](milestones/v1.11-ROADMAP.md), [v1.11 requirements](milestones/v1.11-REQUIREMENTS.md), and triage [v1.11-TRIAGE.md](v1.11-TRIAGE.md).
- ✅ **v1.12 Trust, evidence, and adoption polish** — Phases **73–75** (shipped **2026-04-24**). See [v1.12 archive](milestones/v1.12-ROADMAP.md), [v1.12 requirements](milestones/v1.12-REQUIREMENTS.md), and [MILESTONES.md](MILESTONES.md). Bounded **SEED-002** batch + **SEED-001** evidence index + triage-driven doc polish.

## Phases

<details>
<summary>✅ v1.12 Trust, evidence, and adoption polish (Phases 73–75) — SHIPPED 2026-04-24</summary>

Full phase table, goals, and success criteria are archived in [`milestones/v1.12-ROADMAP.md`](milestones/v1.12-ROADMAP.md).

**At a glance:** **73** bounded **C-1** **`Multi`** + **`log_multi_safe`** + **`mfa_audit_atomicity_test.exs`** (**AUD-11**); **74** **09-03-SUMMARY** + **v1.12-UAT-EVIDENCE** + **`docs/uat-ci-coverage.md`** (**AUD-12**, **UAT-01**, **UAT-02**); **75** **`upgrading-to-v1.12.md`** + trust-bundle surfacing + **`v1.11-TRIAGE.md`** reconciliation (**TRN-01**..**TRN-03**).

</details>

<details>
<summary>✅ v1.11 Adoption stabilization (Phases 71–72) — SHIPPED 2026-04-23</summary>

| Phase | Name | Goal | Requirements | Success criteria (observable) |
|-------|------|------|----------------|----------------------------|
| **71** | Triage + maintainer pause guidance | Record adoption signals; document when to pause GSD milestones. | STAB-01, STAB-03 | (1) **`.planning/v1.11-TRIAGE.md`** is complete and linked from **`upgrading-to-v1.11.md`**. (2) **`MAINTAINING.md`** contains **Milestone cadence and pause** with pause/resume criteria. |
| **72** | Upgrade stub + intro cross-links | Planning **v1.11** vs Hex is legible; intro docs surface upgrade pages. | STAB-02, STAB-04 | (1) **`guides/introduction/upgrading-to-v1.11.md`** ships and appears in **`mix.exs`** ExDoc extras after **v1.10** upgrade page. (2) **getting-started** faster path lists **v1.10** and **v1.11** upgrade links; **upgrading-to-v1.10** See also links **v1.11**. |

**Coverage:** 4 requirements → 2 phases. Phase numbering continues from **v1.10** (last phase **70**).

</details>

<details>
<summary>✅ v1.10 Adopter confidence for solo production (Phases 68–70) — SHIPPED 2026-04-23</summary>

Full phase table, goals, and success criteria are archived in [`milestones/v1.10-ROADMAP.md`](milestones/v1.10-ROADMAP.md).

**At a glance:** **68** deployment + mail confidence hub (**`068-VERIFICATION.md`**, **ACF-01** / **ACF-04**); **69** intermediate path + **`generator-options`** index (**`069-VERIFICATION.md`**, **ACF-02** / **ACF-03**); **70** **`upgrading-to-v1.10.md`** + non-goal attestation (**`070-VERIFICATION.md`**, **ACF-05** / **ACF-06**).

</details>

<details>
<summary>✅ v1.9 Audit atomicity (Phases 66–67) — SHIPPED 2026-04-23</summary>

Full phase table, goals, and success criteria are archived in [`milestones/v1.9-ROADMAP.md`](milestones/v1.9-ROADMAP.md).

**At a glance:** **66** **`confirm_enrollment/5`** **AUD-04-020..021** **`Multi`** + **`mfa_audit_atomicity_test.exs`** (**AUD-09**); **67** **`09-03-SUMMARY.md`** + **D-06** attestation (**AUD-10**).

</details>

<details>
<summary>✅ v1.8 Adopter polish (Phases 63–65) — SHIPPED 2026-04-23</summary>

Full phase table, goals, and success criteria are archived in [`milestones/v1.8-ROADMAP.md`](milestones/v1.8-ROADMAP.md).

**At a glance:** **63** **`upgrading-to-v1.8.md`** + ExDoc extras + SemVer framing (**ADOPT-04**); **64** cross-links among getting-started, first-hour, troubleshooting, and upgrade paths (**ADOPT-05**); **65** companion recipe prerequisite / when-not-to-use / See also polish (**INTG-02**).

</details>

<details>
<summary>✅ v1.7 Adoption readiness & audit durability (Phases 60–62) — SHIPPED 2026-04-23</summary>

Full phase table, success criteria, and Phase **60** directory note are archived in [`milestones/v1.7-ROADMAP.md`](milestones/v1.7-ROADMAP.md).

**At a glance:** **60** adoption + companion recipe (**ADOPT-01..03**, **INTG-01**); **61** bounded **SEED-002** batch — `verify_backup/4` failure **`Multi`** + **`mfa_audit_atomicity_test.exs`** + **AUD-04-067** (**AUD-01**); **62** **`09-03-SUMMARY.md`** + **AUD-02** closure.

</details>

<details>
<summary>✅ v1.4 GA readiness & audit trail completeness (Phases 41–52) — SHIPPED 2026-04-22</summary>

The live phase table, success criteria, and the **44/45 vs 47–49** reader note are archived in [`milestones/v1.4-ROADMAP.md`](milestones/v1.4-ROADMAP.md).

At a glance: **41** backup-code rotation (**GA-01**); **42** GA matrix scaffold; **43–45** audit inventory + Auth / MFA–Account–API / OAuth–ops batches (**AUD-04..AUD-08** implementation); **46** GA matrix gap closure (**GA-02..GA-05**); **47–49** formal `*-VERIFICATION.md` gates + requirements reconciliation; **50** Nyquist policy + **`mix ci.install_golden`** / **`install_golden_contract`**; **51** CI path coupling for installer golden; **52** roadmap and milestone-honesty contract tests.

</details>

<details>
<summary>✅ v1.5 Public release narrative & community readiness (Phases 53–56) — SHIPPED 2026-04-22</summary>

Full phase table, goals, and canonical refs are archived in [`milestones/v1.5-ROADMAP.md`](milestones/v1.5-ROADMAP.md).

At a glance: **53** Hex / `mix.exs` metadata (**PUB-01**); **54** `CHANGELOG.md` milestone anchors (**PUB-02**); **55** README + ExDoc GA entry paths (**DOC-01**, **DOC-02**); **56** maintainer **First public launch** checklist in `MAINTAINING.md` (**MAINT-01**).

</details>

<details>
<summary>✅ v1.6 Nyquist closure + OAuth audit depth (Phases 57–59) — SHIPPED 2026-04-23</summary>

Full phase table, goals, success criteria, and reader note are archived in [`milestones/v1.6-ROADMAP.md`](milestones/v1.6-ROADMAP.md).

**At a glance:** **57** canonical **41–44** posture matrix + contract test (**NYQ-01**, **NYQ-02**); **58** **`Sigra.OAuthCeremonyAuditTest`** + CI coupling contract (**OA-01**); **59** **OA-02** alignment across **`docs/uat-ci-coverage.md`**, **GA-03** / waiver / evidence **INDEX**, and **`docs/ga-evidence.md`**.

**Reader note:** Phases **41–44** shipped under v1.4; v1.6 makes **Nyquist posture** and **OAuth↔audit machine proof** legible — honest disposition is mandatory.

</details>

## Backlog (parking lot — not in the active roadmap until promoted)

- **999.1** / **999.2** — historical parking-lot labels; shipped in v1.3 — keep directories under `.planning/phases/` as archaeology only.
- **SEED-002** — broad `log_safe/3` → `Ecto.Multi` conversion; trigger when audit-aware refactors are scheduled or compliance demands it.
- Items not mapped in archived requirements stay here until a future milestone selects them.
