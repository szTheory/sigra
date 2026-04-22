# Roadmap: Sigra

## Milestones

- ✅ **v1.0 Phoenix Auth Library - Initial Release** - Phases 1-10 + 10.1 + 10.1.1 (shipped 2026-04-11). See [v1.0 archive](milestones/v1.0-ROADMAP.md) and [MILESTONES.md](MILESTONES.md).
- ✅ **v1.1 Foundations** - Phases 11-23 (shipped 2026-04-16). See [v1.1 archive](milestones/v1.1-ROADMAP.md), [v1.1 requirements](milestones/v1.1-REQUIREMENTS.md), and [MILESTONES.md](MILESTONES.md).
- ✅ **Post-v1.1 Closeout** - Phases 24-26 (completed 2026-04-16).
- ✅ **v1.2 Admin Dashboard** - Phases 27-31 + gap closure 32-35 (shipped 2026-04-17). See [v1.2 archive](milestones/v1.2-ROADMAP.md), [v1.2 requirements](milestones/v1.2-REQUIREMENTS.md), [v1.2 milestone audit](milestones/v1.2-MILESTONE-AUDIT.md), and [MILESTONES.md](MILESTONES.md).
- ✅ **v1.3 Cleanup & Hardening** — Phases 36-40 (shipped 2026-04-19). See [v1.3 archive](milestones/v1.3-ROADMAP.md), [v1.3 requirements](milestones/v1.3-REQUIREMENTS.md), [v1.3 milestone audit](milestones/v1.3-MILESTONE-AUDIT.md), and [MILESTONES.md](MILESTONES.md).
- ✅ **v1.4 GA readiness & audit trail completeness** — Phases **41–52** (shipped **2026-04-22**). See [v1.4 archive](milestones/v1.4-ROADMAP.md), [v1.4 requirements](milestones/v1.4-REQUIREMENTS.md), [v1.4 milestone audit](milestones/v1.4-MILESTONE-AUDIT.md), and [MILESTONES.md](MILESTONES.md).
- **v1.5 Public release narrative & community readiness** — Phases **53–56** (in progress). Requirements: [.planning/REQUIREMENTS.md](REQUIREMENTS.md).

## Phases

<details>
<summary>✅ v1.4 GA readiness & audit trail completeness (Phases 41–52) — SHIPPED 2026-04-22</summary>

The live phase table, success criteria, and the **44/45 vs 47–49** reader note are archived in [`milestones/v1.4-ROADMAP.md`](milestones/v1.4-ROADMAP.md).

At a glance: **41** backup-code rotation (**GA-01**); **42** GA matrix scaffold; **43–45** audit inventory + Auth / MFA–Account–API / OAuth–ops batches (**AUD-04..AUD-08** implementation); **46** GA matrix gap closure (**GA-02..GA-05**); **47–49** formal `*-VERIFICATION.md` gates + requirements reconciliation; **50** Nyquist policy + **`mix ci.install_golden`** / **`install_golden_contract`**; **51** CI path coupling for installer golden; **52** roadmap and milestone-honesty contract tests.

</details>

## Phases (v1.5)

| Phase | Name | Goal | Requirements | Success criteria (observable) |
|-------|------|------|--------------|------------------------------|
| ✅ **53** | Package & Hex metadata | Align **Hex / mix.exs** public surface with shipped **v1.0–v1.4** reality | PUB-01 | **Complete 2026-04-22** — `mix.exs` description + links; see [`phases/053-package-hex-metadata/053-01-SUMMARY.md`](phases/053-package-hex-metadata/053-01-SUMMARY.md). (3) Maintainer sign-off via PR or `/gsd-verify-work`. |
| **54** | Changelog & milestone anchors | **`CHANGELOG.md`** tells a coherent version story through **v1.4** | PUB-02 | (1) Entries or explicit pointers for v1.3 / v1.4 ship boundaries. (2) No contradictory claims vs `MILESTONES.md`. (3) CI/docs unchanged or greener. |
| **55** | README & ExDoc entry paths | Readers find **GA / audit posture** from repo + docs home | DOC-01, DOC-02 | (1) README links v1.4 evidence bundle with honest **Executed/Waived** framing. (2) `mix docs` landing path documented in phase summary. (3) `mix docs --warnings-as-errors` clean if touched. |
| **56** | Maintainer announcement checklist | **`MAINTAINING.md`** runbook for first loud public push | MAINT-01 | (1) Ordered checklist with owners. (2) References install-golden / GA matrix where relevant. (3) Optional human rows clearly marked optional. |

## Backlog (parking lot — not v1.5 unless promoted)

- **999.1** / **999.2** — historical parking-lot labels; shipped in v1.3 — keep directories under `.planning/phases/` as archaeology only.
- Items not mapped in the [v1.4 requirements archive](milestones/v1.4-REQUIREMENTS.md) stay here until a future milestone selects them.
