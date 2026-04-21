# Roadmap: Sigra

## Milestones

- ✅ **v1.0 Phoenix Auth Library - Initial Release** - Phases 1-10 + 10.1 + 10.1.1 (shipped 2026-04-11). See [v1.0 archive](milestones/v1.0-ROADMAP.md) and [MILESTONES.md](MILESTONES.md).
- ✅ **v1.1 Foundations** - Phases 11-23 (shipped 2026-04-16). See [v1.1 archive](milestones/v1.1-ROADMAP.md), [v1.1 requirements](milestones/v1.1-REQUIREMENTS.md), and [MILESTONES.md](MILESTONES.md).
- ✅ **Post-v1.1 Closeout** - Phases 24-26 (completed 2026-04-16).
- ✅ **v1.2 Admin Dashboard** - Phases 27-31 + gap closure 32-35 (shipped 2026-04-17). See [v1.2 archive](milestones/v1.2-ROADMAP.md), [v1.2 requirements](milestones/v1.2-REQUIREMENTS.md), [v1.2 milestone audit](milestones/v1.2-MILESTONE-AUDIT.md), and [MILESTONES.md](MILESTONES.md).
- ✅ **v1.3 Cleanup & Hardening** — Phases 36-40 (shipped 2026-04-19). See [v1.3 archive](milestones/v1.3-ROADMAP.md), [v1.3 requirements](milestones/v1.3-REQUIREMENTS.md), [v1.3 milestone audit](milestones/v1.3-MILESTONE-AUDIT.md), and [MILESTONES.md](MILESTONES.md).
- **v1.4 GA readiness & audit trail completeness** — Phases **41–50** (in progress; **46–50** are gap-closure phases from [.planning/v1.4-MILESTONE-AUDIT.md](v1.4-MILESTONE-AUDIT.md)). Requirements: [.planning/REQUIREMENTS.md](REQUIREMENTS.md).

## Phases (v1.4)

| Phase | Name | Goal | Requirements | Success criteria (observable) |
|-------|------|------|--------------|------------------------------|
| **41** ✅ (2026-04-20) | Backup codes & GA product closure | Ship and prove **backup-code rotation** so SEED-001 item 7 is a product fact, not a TODO | GA-01 | (1) User completes backup-code rotation in example or generated host. (2) Automated test fails if old codes work after rotation. (3) Audit rows (if configured) match success path. |
| **42** ✅ (2026-04-20) | Human GA matrix & evidence | Execute residual human checks and consolidate **GA-05** artifact | GA-02, GA-03, GA-04, GA-05 | (1) `v1.4-GA-UAT.md` exists with Executed/Waived/Blocked per row. (2) Each row links to evidence or waiver rationale. (3) `docs/uat-ci-coverage.md` cross-links updated if rows moved machine-side. |
| **43** ✅ (2026-04-20) | Audit inventory + Auth atomic batch | **AUD-04** inventory gates **AUD-05**; convert prioritized `Sigra.Auth` `log_safe/3` sites to audited `Ecto.Multi` | AUD-04, AUD-05 | (1) Inventory doc checked in under `.planning/phases/43-*` or `.planning/`. (2) Each converted Auth path has audit-aware test. (3) Full library CI green. |
| **44** | MFA + Account/API atomic batches | Close MFA and account-layer hybrid sites per inventory | AUD-06, AUD-07 | (1) Listed MFA success paths use Multi + tests. (2) Account + agreed API token paths converted with tests. (3) CI green. |
| **45** | OAuth, ops paths & C-1 sign-off | Remaining high-value sites or explicit deferrals; update Phase 9 C-1 narrative | AUD-08 | (1) `09-03-SUMMARY.md` / `09-VERIFICATION.md` reflect post-v1.4 reality. (2) Any deferred `log_safe/3` sites listed with trigger. (3) CI green. |
| **46** ✅ (2026-04-21) | Human GA matrix gap closure | Close **GA-02..GA-05** in the canonical matrix with dated evidence or waivers; reconcile ROADMAP / REQUIREMENTS vs `v1.4-GA-UAT.md` | GA-02, GA-03, GA-04, GA-05 | (1) Each GA row is **Executed / Waived / Blocked** with pointer under `.planning/uat-evidence/v1.4/` (or documented path). (2) `v1.4-GA-UAT.md` matches reality. (3) ROADMAP narrative matches matrix (no “complete” drift while rows stay Pending). |
| **47** | Phase 43 verification & AUD-04/05 closure | Publish **43** `*-VERIFICATION.md` and reconcile **AUD-04..AUD-05** with inventories + summaries | AUD-04, AUD-05 | (1) `43-VERIFICATION.md` exists and passes project gate. (2) REQUIREMENTS traceability updated when satisfied. (3) Phase 43 Nyquist run if required (`/gsd-validate-phase 43`). |
| **48** | Phase 44 verification & AUD-06/07 closure | Publish **44** `*-VERIFICATION.md` and reconcile **AUD-06..AUD-07** | AUD-06, AUD-07 | (1) `44-VERIFICATION.md` exists and passes gate. (2) REQUIREMENTS + ROADMAP updated when satisfied. (3) Phase 44 Nyquist run if required. |
| **49** | Phase 45 verification, AUD-08 & C-1 reconciliation | Publish **45** `*-VERIFICATION.md`; close **AUD-08**; reconcile **09-VERIFICATION.md** C-1 with **43/44/45** inventories | AUD-08 | (1) `45-VERIFICATION.md` exists and passes gate. (2) C-1 narrative explicitly ties to row-level inventories (no “representative only” ambiguity). (3) REQUIREMENTS + ROADMAP updated when satisfied. |
| **50** | Nyquist validation & CI gate hygiene | Run `/gsd-validate-phase` for **41–44** if Nyquist sign-off required; address long-budget / flake-class notes (e.g. full `golden_diff_test.exs`, installer golden `mix test`) with CI policy or docs | _(process)_ | (1) `41-44` validation artifacts updated per Nyquist policy. (2) Release/CI posture for expensive suites documented or wired. (3) No silent “green locally only” assumptions at milestone close. |

**Numbering:** continues from v1.3 phase **40** → **41** (no `--reset-phase-numbers`).

## Backlog (parking lot — not v1.4 unless promoted)

- **999.1** / **999.2** — historical parking-lot labels; shipped in v1.3 — keep directories under `.planning/phases/` as archaeology only.
- Items not mapped in [REQUIREMENTS.md](REQUIREMENTS.md) stay here until a future milestone selects them.
