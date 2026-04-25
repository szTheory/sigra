---
gsd_state_version: 1.0
milestone: v1.20
milestone_name: GA Launch — SEED closure + public release
status: defining_requirements
last_updated: "2026-04-25T00:00:00.000Z"
last_activity: 2026-04-25 -- /gsd-new-milestone v1.20 opened (defining requirements)
progress:
  total_phases: 0
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

**Current focus:** **v1.20 GA Launch** — close SEED-001 (human UAT) + SEED-002 (OAuth audit atomicity remainder) gates, then execute public release per v1.5 `MAINT-01` checklist. Phase numbering continues from Phase 84 (last completed).

## Current Position

Milestone: **v1.20** — GA Launch — SEED closure + public release

Phase: Not started (defining requirements)

Plan: —

Status: Defining requirements

Last activity: 2026-04-25 — Milestone v1.20 started

## Performance Metrics

_Velocity metrics populate during phase work._

## Accumulated Context

**v1.19 (shipped 2026-04-24)** — Phases 82–83 closed JWT refresh persistence + audit co-fate (AUD-19) and MFA invalid-TOTP enrollment audit (AUD-20). **Phase 84** (routing-honesty-reconciliation) closed 2026-04-25. After v1.20, the only known live audit-atomicity gap is the Phase 45 T2 OAuth/ops cluster (052–056, 058, 063) — explicitly in v1.20 scope.

**v1.20 framing:** This is the inflection-point milestone where Sigra goes from "evidence-capable on disk" to "publicly available." All three legs (SEED-002 OAuth audit closure, SEED-001 human UAT execution, public launch sequence) are interdependent: legs 1 and 2 give the launch defensible evidence; the launch is the only reason to spend the engineering hours on legs 1 and 2 right now.

**Selected seeds for this milestone:** SEED-001, SEED-002. Both will close (status → validated) when v1.20 ships.

**Explicit non-goals:** `sigra_lockspire` / ADR 001 glue (still awaiting companion-app trigger); 999.x archaeology; responding to week-one launch feedback (deferred to a follow-up patch milestone if signal warrants).

### Pending Todos

_None as of milestone open. Will populate during phase planning._

### Blockers/Concerns

- **Live Google OAuth credentials** — SEED-001 leg requires real Google developer credentials for register/login/link/unlink cycle. Acquisition is part of the milestone scope; not blocking start.
- **Real consumer mail accounts** — SEED-001 email visual QA needs Gmail / Outlook / Apple Mail accounts. Acquisition trivial; flagged here so it's not forgotten when the relevant phase starts.
- **Hex.pm publish credentials + 2FA** — launch leg requires `mix hex.user auth` configured for the publishing maintainer. Verify before the launch phase begins.

## Session Continuity

**Next:** `/gsd-plan-phase [N] ${GSD_WS}` once the v1.20 ROADMAP is approved.

**Resume file:** None

**Artifacts (active):** `.planning/REQUIREMENTS.md`, `.planning/ROADMAP.md` (both being rewritten by this workflow)

**Last completed phase:** **84** (routing-honesty-reconciliation) — **2026-04-25**

**Planned Phase:** None — defined by the upcoming v1.20 ROADMAP
