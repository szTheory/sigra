# Roadmap: Sigra

## Milestones

- ✅ **v1.0 Phoenix Auth Library - Initial Release** - Phases 1-10 + 10.1 + 10.1.1 (shipped 2026-04-11). See [v1.0 archive](milestones/v1.0-ROADMAP.md) and [MILESTONES.md](MILESTONES.md).
- ✅ **v1.1 Foundations** - Phases 11-23 (shipped 2026-04-16). See [v1.1 archive](milestones/v1.1-ROADMAP.md), [v1.1 requirements](milestones/v1.1-REQUIREMENTS.md), and [MILESTONES.md](MILESTONES.md).
- ✅ **Post-v1.1 Closeout** - Phases 24-26 (completed 2026-04-16).
- ✅ **v1.2 Admin Dashboard** - Phases 27-31 + gap closure 32-35 (shipped 2026-04-17). See [v1.2 archive](milestones/v1.2-ROADMAP.md), [v1.2 requirements](milestones/v1.2-REQUIREMENTS.md), [v1.2 milestone audit](milestones/v1.2-MILESTONE-AUDIT.md), and [MILESTONES.md](MILESTONES.md).
- **v1.3 Cleanup & Hardening** — Phases 36-40 (active). Live [REQUIREMENTS.md](REQUIREMENTS.md) and **Next milestone** section below.

## Next milestone — v1.3 Cleanup & Hardening (active)

**Goal:** Close deferred validation, CI/supply-chain, human UAT, audit completeness, and tooling gaps — **no new product features**.

**Requirements:** `.planning/REQUIREMENTS.md`

| Phase | Name | Goal | REQ IDs |
|-------|------|------|---------|
| **36** | Retroactive Nyquist validation | Backfill or waive `*-VALIDATION.md` gaps (**999.1**) | VAL-01–VAL-03 |
| **37** | Actions & dependency hygiene | Land **999.2** Dependabot/Actions upgrades with green CI | CI-01–CI-03 |
| **38** | Human GA UAT gate | Execute or waive **SEED-001** eight items with evidence | UAT-01–UAT-02 |
| **39** | Audit trail completeness | **Done (2026-04-19):** `Sigra.Audit.Assertions`, atomic `api.token_create`, example login/MFA audit smoke + docs — see `39-VERIFICATION.md` | AUD-01–AUD-03 |
| **40** | Tooling & release ergonomics | `gsd-tools audit-open` + Hex/release maintainer checklist | TOOL-01, REL-01 |

**Success (milestone):** All REQ checkboxes in `REQUIREMENTS.md` satisfied or explicitly waived with owner/date; `MILESTONES.md` records v1.3 ship; seeds **999.1**/**999.2** satisfied or folded into archived rationale.

## Backlog (parking lot — not v1.3 unless promoted)

- Items not mapped above stay here until a future milestone selects them.
