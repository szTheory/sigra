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

## Phases

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

### Next milestone

Planning not started — run `/gsd-new-milestone` to define requirements and phased work.

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
