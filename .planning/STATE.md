---
gsd_state_version: 1.0
milestone: v1.20
milestone_name: GA Launch — SEED closure + public release
status: ready_to_plan
last_updated: "2026-04-25T00:00:00.000Z"
last_activity: 2026-04-25 -- ROADMAP.md drafted (6 phases, 21 requirements mapped); ready to plan Phase 85
progress:
  total_phases: 6
  completed_phases: 0
  total_plans: 0
  completed_plans: 0
  percent: 0
---

# Project State

## Project Reference

See: `.planning/PROJECT.md`

**Core value:** Authentication that works out of the box with great DX on the happy path and on the rough edges.

**North star (milestones):** Prefer work that moves **North Star (milestones)** in `.planning/PROJECT.md` — production trust, integration path, DX.

**Current focus:** **v1.20 GA Launch** — close SEED-001 (human UAT) + SEED-002 (OAuth audit atomicity remainder) gates, then execute public release per v1.5 `MAINT-01` checklist. Phase numbering continues from Phase 84 (last completed); v1.20 occupies Phases **85–90**.

## Current Position

Milestone: **v1.20** — GA Launch — SEED closure + public release

Phase: Not started (roadmap drafted; ready to plan first phase)

Plan: —

Status: Ready to plan

Last activity: 2026-04-25 — ROADMAP.md drafted with 6 phases (85–90); 21/21 requirements mapped; SEED-001 + SEED-002 closure mapped to Phases 85 and 88 respectively.

**Planned Phase:** **85 — OAuth audit atomicity closure (AUD-21)** (parallel-ready with Phases 86–88; can be picked first per maintainer judgment).

## Performance Metrics

_Velocity metrics populate during phase work._

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
- **Real consumer mail accounts** — Phase 86 email visual QA needs Gmail / Outlook / Apple Mail accounts. Acquisition trivial; flagged here so it's not forgotten when Phase 86 starts.
- **Hex.pm publish credentials + 2FA** — Phase 89 requires `mix hex.user auth` configured for the publishing maintainer. Verify before Phase 89 begins (ideally early in v1.20 so it's not the long-pole on launch day).
- **Clean-machine availability** — Phase 88 GAUAT-08 needs a fresh Phoenix 1.8 host environment ("clean-machine read-through"). Plan ahead for VM / fresh worktree provisioning.

## Session Continuity

**Next:** `/gsd-plan-phase 85 ${GSD_WS}` once the v1.20 ROADMAP is approved. Phases 86–88 may be planned in parallel (any order) since Leg 2 is parallel-ready with Leg 1.

**Resume file:** None

**Artifacts (active):** `.planning/REQUIREMENTS.md`, `.planning/ROADMAP.md`

**Last completed phase:** **84** (routing-honesty-reconciliation) — **2026-04-25**

**Planned Phase:** **85 — OAuth audit atomicity closure (AUD-21)**
