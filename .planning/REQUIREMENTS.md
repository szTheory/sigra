# Requirements: Sigra — v1.33 POST-1.0-MAINTENANCE-AND-STRATEGIC-BETS

**Defined:** 2026-06-01
**Core Value:** Authentication that works out of the box with great DX on the happy path and on the rough edges.

**Milestone goal:** Manage the long-term viability of the hybrid lib+generator architecture through issue triage, ecosystem sync, and establishing a formal gate for strategic bets based on adopter demand. Transition Sigra from a phase of active feature construction into a phase of stewardship and stability.

**Research basis:** `.planning/research/SUMMARY.md` (HIGH confidence). The ecosystem standard for post-1.0 libraries dictates that maintenance, operator trust, and security supersede greenfield feature development.

## v1 Requirements

Requirements for this milestone. Each maps to exactly one roadmap phase (phases continue from 150).

### Issue Triage & Bugfix Cadence (MAINT)

- [x] **MAINT-01**: Maintainer runbook includes a clear, repeatable process for monitoring adopter feedback, triaging issues, and prioritizing bug fixes without accumulating technical debt.
- [x] **MAINT-02**: Known high-priority bugs and adopter-reported friction points are diagnosed and patched in the codebase.
- [x] **MAINT-03**: A documented process exists for communicating generated-host template updates to adopters who have already run `mix sigra.install` prior to minor/patch bumps.

### Ecosystem Sync & Hex Dependency Management (ECO)

- [x] **ECO-01**: CI pipeline verifies compatibility with the latest minor versions of Elixir and Phoenix, ensuring zero deprecation warnings on the latest OTP.
- [x] **ECO-02**: Hex dependencies (including those managed by Dependabot) are routinely bumped to their latest secure and compatible versions.
- [x] **ECO-03**: Supply-chain security and framework alignment are confirmed via a passing CI suite and, if necessary, a minor/patch Hex release.

### Strategic Bet Evaluation Gate (STRAT)

- [x] **STRAT-01**: A formal evaluation document is created to assess if accumulated adopter demand warrants beginning work on `SCIM`, `sigra_lockspire`, or `Threadline` correlation.
- [x] **STRAT-02**: The evaluation explicitly defines the threshold of adopter demand required to override the maintenance-first default and violate the Diminishing Returns Wall.
- [x] **STRAT-03**: Any approved strategic bet includes deeper research scoping (e.g., `ex_scim` vs custom implementations for directory sync) to prepare for future implementation phases.

## Out of Scope

Explicitly excluded. Documented to prevent scope creep.

| Feature | Reason |
|---------|--------|
| Greenfield Feature Implementation | The baseline must be stable before expanding the surface area. Building "nice-to-have" capabilities without concrete adopter demand violates the Diminishing Returns Wall. |
| Opinionated RBAC or Generic Admin UI | Feature creep that is out of scope for a post-1.0 authentication library. |

## Traceability

Which phases cover which requirements. Populated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| MAINT-01 | Phase 150 | Complete |
| MAINT-02 | Phase 150 | Complete |
| MAINT-03 | Phase 150 | Complete |
| ECO-01 | Phase 151 | Complete |
| ECO-02 | Phase 151 | Complete |
| ECO-03 | Phase 151 | Complete |
| STRAT-01 | Phase 152 | Complete |
| STRAT-02 | Phase 152 | Complete |
| STRAT-03 | Phase 152 | Complete |

**Coverage:**
- v1 requirements: 9 total
- Mapped to phases: 9 (roadmap complete)
- Unmapped: 0 ✓