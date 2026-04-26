---
gsd_state_version: 1.0
milestone: v1.20
milestone_name: — active
status: ready_to_plan
last_updated: "2026-04-26T23:00:00.000Z"
last_activity: 2026-04-26 -- Phase 86 wave 3 complete (CI wiring + Phase 04/08 evidence bundles, awaiting verifier)
progress:
  total_phases: 6
  completed_phases: 2
  total_plans: 6
  completed_plans: 2
  percent: 33
---

# Project State

## Project Reference

See: `.planning/PROJECT.md`

**Core value:** Authentication that works out of the box with great DX on the happy path and on the rough edges.

**North star (milestones):** Prefer work that moves **North Star (milestones)** in `.planning/PROJECT.md` — production trust, integration path, DX.

**Current focus:** Phase 86 — gauat-email-visual-qa-phase-04-phase-08-templates

## Current Position

Milestone: **v1.20** — GA Launch — SEED closure + public release

Phase: 87

Plan: Not started

Status: Ready to plan

Last activity: 2026-04-26

**Completed Phase:** **85 — OAuth audit atomicity closure (AUD-21)**

## Performance Metrics

| Phase | Plans | Duration | Tasks | Files |
| --- | --- | --- | --- | --- |
| 85 | 2 | session | 5 | 13 |

## Decisions

- Use optional `SessionStore` multi callbacks only on adapters that support them.
- Return `:impersonation_aborted` on transactional audit failure.
- Mark Phase 9 C-1 as PASS for the AUD-21 slice.
- Validate SEED-002 and publish a phase merge-gate artifact.

## Accumulated Context

**v1.19 (shipped 2026-04-24)** — Phases 82–83 closed JWT refresh persistence + audit co-fate (AUD-19) and MFA invalid-TOTP enrollment audit (AUD-20). **Phase 84** (routing-honesty-reconciliation) closed 2026-04-25. After v1.20, the only known live audit-atomicity gap is the Phase 45 T2 OAuth/ops cluster (052–056, 058, 063) — explicitly in v1.20 scope.

**v1.20 framing:** This is the inflection-point milestone where Sigra goes from "evidence-capable on disk" to "publicly available." All three legs (SEED-002 OAuth audit closure, SEED-001 human UAT execution, public launch sequence) are interdependent: legs 1 and 2 give the launch defensible evidence; the launch is the only reason to spend the engineering hours on legs 1 and 2 right now.

**v1.20 phase shape:** 6 phases.

- **Leg 1 (parallel-ready, single phase):** Phase 85 — AUD-21 OAuth audit atomicity closure → downgrades Phase 9 C-1 caveat to PASS; flips SEED-002 to `validated`.
- **Leg 2 (parallel-ready, three phases):** Phase 86 (email visual QA Phase 04 + Phase 08), Phase 87 (OAuth gen smoke + live Google + linking + email-match), Phase 88 (backup-code rotation + clean-machine getting-started + results filing + SEED-001 closure). 86 and 87 are independent; 88 depends on 86 and 87 (consolidates evidence into `v1.20-GA-UAT-RESULTS.md`).
- **Leg 3 (sequential, two phases):** Phase 89 (Hex publish + README promotion + CHANGELOG/ExDoc — depends on Phase 85 + Phase 88), then Phase 90 (announcement + HN + community soft-launch + MAINTAINING monitoring lane — depends on Phase 89).

**Selected seeds for this milestone:** SEED-001 (closes in Phase 88), SEED-002 (closes in Phase 85). Both will close (status → `validated`) when v1.20 ships.

**Explicit non-goals:** `sigra_lockspire` / ADR 001 glue (still awaiting companion-app trigger); 999.x archaeology; responding to week-one launch feedback (deferred to a follow-up patch milestone if signal warrants); marketing site / paid promotion.

### Pending Todos

_None as of milestone open. Will populate during phase planning._

### Blockers/Concerns

- **Live Google OAuth credentials** — Phase 87 requires real Google developer credentials for register/login/link/unlink cycle. Acquisition is part of phase scope; not blocking start of Phase 85 or Phase 86.
- **Phase 86 evidence environment** — The Phase 86 harness is automation-only (`0 human MUA passes required`), but it still depends on the repo CI/browser environment staying reproducible: Chromium + WebKit available in Playwright, deterministic snapshot generation, and tag-time release-asset upload wiring for the same evidence bundle.
- **Hex.pm publish credentials + 2FA** — Phase 89 requires `mix hex.user auth` configured for the publishing maintainer. Verify before Phase 89 begins (ideally early in v1.20 so it's not the long-pole on launch day).
- **Clean-machine availability** — Phase 88 GAUAT-08 needs a fresh Phoenix 1.8 host environment ("clean-machine read-through"). Plan ahead for VM / fresh worktree provisioning.

## Session Continuity

**Next:** Phase 86 — GAUAT email visual QA (or `/gsd-plan-phase 86 ${GSD_WS}` when ready).

**Resume file:** --resume-file

**Artifacts (active):** `.planning/REQUIREMENTS.md`, `.planning/ROADMAP.md`

**Last completed phase:** **85** (oauth-audit-atomicity-closure-aud-21) — **2026-04-25**

**Planned Phase:** **86 — GAUAT email visual QA (Phase 04 + Phase 08 templates)**
