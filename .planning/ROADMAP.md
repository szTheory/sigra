# Roadmap: Sigra

## Milestones

- ✅ **v1.0 Phoenix Auth Library - Initial Release** - Phases 1-10 + 10.1 + 10.1.1 (shipped 2026-04-11). See [v1.0 archive](milestones/v1.0-ROADMAP.md) and [MILESTONES.md](MILESTONES.md).
- ✅ **v1.1 Foundations** - Phases 11-23 (shipped 2026-04-16). See [v1.1 archive](milestones/v1.1-ROADMAP.md), [v1.1 requirements](milestones/v1.1-REQUIREMENTS.md), and [MILESTONES.md](MILESTONES.md).
- ✅ **Post-v1.1 Closeout** - Phases 24-26 (completed 2026-04-16).
- ✅ **v1.2 Admin Dashboard** - Phases 27-31 + gap closure 32-35 (shipped 2026-04-17). See [v1.2 archive](milestones/v1.2-ROADMAP.md), [v1.2 requirements](milestones/v1.2-REQUIREMENTS.md), [v1.2 milestone audit](milestones/v1.2-MILESTONE-AUDIT.md), and [MILESTONES.md](MILESTONES.md).
- ✅ **v1.3 Cleanup & Hardening** — Phases 36-40 (shipped 2026-04-19). See [v1.3 archive](milestones/v1.3-ROADMAP.md), [v1.3 requirements](milestones/v1.3-REQUIREMENTS.md), [v1.3 milestone audit](milestones/v1.3-MILESTONE-AUDIT.md), and [MILESTONES.md](MILESTONES.md).
- ✅ **v1.4 GA readiness & audit trail completeness** — Phases **41–52** (shipped **2026-04-22**). See [v1.4 archive](milestones/v1.4-ROADMAP.md), [v1.4 requirements](milestones/v1.4-REQUIREMENTS.md), [v1.4 milestone audit](milestones/v1.4-MILESTONE-AUDIT.md), and [MILESTONES.md](MILESTONES.md).
- ✅ **v1.5 Public release narrative & community readiness** — Phases **53–56** (shipped **2026-04-22**). See [v1.5 archive](milestones/v1.5-ROADMAP.md), [v1.5 requirements](milestones/v1.5-REQUIREMENTS.md), and [MILESTONES.md](MILESTONES.md).
- **v1.6 Nyquist closure + OAuth audit depth** — Phases **57–59** (active). Requirements: [REQUIREMENTS.md](REQUIREMENTS.md).

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

### v1.6 Nyquist closure + OAuth audit depth (Phases 57–59) — ACTIVE

| Phase | Name | Goal | Requirements | Success criteria (observable) |
|-------|------|------|----------------|------------------------------|
| **57** | Nyquist 41–44 posture matrix | Single maintainer-facing source of truth for historical GA-phase Nyquist debt | NYQ-01, NYQ-02 | (1) Matrix exists in `MAINTAINING.md` or linked doc per **NYQ-01**. (2) All four rows have explicit disposition per **NYQ-02**. (3) `mix compile --warnings-as-errors` unchanged green. |
| **58** | OAuth ceremony + audit smoke | Automated proof that OAuth ceremonies emit expected audit (or documented substitute) | OA-01 | (1) New or extended test module(s) run in an existing required CI job (or a new job wired into required checks). (2) At least one ceremony path + assertion satisfies **OA-01**. (3) No live-provider secrets in repo. |
| **59** | UAT + GA narrative alignment | Docs point at machine proof; humans know residual gap | OA-02 | (1) `docs/uat-ci-coverage.md` updated per **OA-02**. (2) GA-03 / AUD-03 wording does not over-claim vs tests. (3) Link from `.planning/v1.4-GA-UAT.md` or `uat-evidence` index if a pointer row is needed. |

### Phase 57: Nyquist 41–44 posture matrix

**Goal:** Single maintainer-facing source of truth for historical GA-phase Nyquist debt (phases **41–44**).

**Requirements:** NYQ-01, NYQ-02

**Success Criteria:**

1. Matrix exists in **`MAINTAINING.md`** or one linked maintainer doc under **`.planning/`** referenced from it per **NYQ-01** (phase slug, disposition, canonical evidence paths, reopen trigger per row).
2. Each **41–44** row has explicit milestone disposition per **NYQ-02** — no silent blank cells.
3. `mix compile --warnings-as-errors` remains green.

**Canonical refs:** `.planning/REQUIREMENTS.md`, `.planning/phases/57-nyquist-41-44-posture-matrix/57-CONTEXT.md`, `MAINTAINING.md`, `.planning/phases/41-backup-codes-ga-product-closure/`, `.planning/phases/42-human-ga-matrix-evidence/`, `.planning/phases/43-audit-inventory-auth-atomic-batch/`, `.planning/phases/44-mfa-account-api-atomic-batches/`, `.planning/v1.4-GA-UAT.md`

### Phase 58: OAuth ceremony + audit smoke

**Goal:** Automated proof that OAuth ceremonies emit expected audit (or documented substitute) per **OA-01**.

**Requirements:** OA-01

**Success Criteria:**

1. New or extended test module(s) run in an existing required CI job (or a new job wired into required checks).
2. At least one ceremony path plus assertion satisfies **OA-01**.
3. No live-provider secrets in repo.

**Canonical refs:** `.planning/REQUIREMENTS.md`, `.planning/PROJECT.md`, `.github/workflows/ci.yml`

### Phase 59: UAT + GA narrative alignment

**Goal:** Docs point at machine proof; humans know residual gap (**OA-02**).

**Requirements:** OA-02

**Success Criteria:**

1. `docs/uat-ci-coverage.md` updated per **OA-02**.
2. GA-03 / AUD-03 wording does not over-claim vs tests.
3. Link from `.planning/v1.4-GA-UAT.md` or `uat-evidence` index if a pointer row is needed.

**Canonical refs:** `.planning/REQUIREMENTS.md`, `docs/uat-ci-coverage.md`, `.planning/v1.4-GA-UAT.md`, `docs/ga-evidence.md`

## Reader note: phases 41–44 vs v1.6

Phases **41–44** shipped implementation and verification **artifacts** under v1.4; **v1.6** does **not** re-litigate those releases — it makes **Nyquist posture** and **OAuth↔audit machine proof** legible for maintainers going forward. Formal `nyquist_compliant: true` for a row is optional; **honest disposition** is mandatory.

## Backlog (parking lot — not in the active roadmap until promoted)

- **999.1** / **999.2** — historical parking-lot labels; shipped in v1.3 — keep directories under `.planning/phases/` as archaeology only.
- **SEED-002** — broad `log_safe/3` → `Ecto.Multi` conversion; trigger when audit-aware refactors are scheduled or compliance demands it.
- Items not mapped in archived requirements stay here until a future milestone selects them.
