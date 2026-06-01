# Roadmap: Sigra — v1.33 POST-1.0-MAINTENANCE-AND-STRATEGIC-BETS

**Core Value**: Authentication that works out of the box with great DX on the happy path and on the rough edges.
**Status**: Active planning

## Phases

- [x] **Phase 150: Issue Triage & Bugfix Cadence** - Establish a repeatable process for monitoring adopter feedback, diagnosing friction, and patching bugs. (completed 2026-06-01)
- [ ] **Phase 151: Ecosystem Sync & Hex Dependency Management** - Routine dependency bumps and verifying framework/OTP compatibility.
- [ ] **Phase 152: Strategic Bet Evaluation Gate** - A formal checkpoint to evaluate if accumulated adopter demand warrants future work on strategic bets.

---

## Phase Details

### Phase 150: Issue Triage & Bugfix Cadence
**Goal**: Establish a repeatable process for monitoring adopter feedback, diagnosing friction, and patching bugs to maintain operator trust and stability.
**Depends on**: Nothing (first phase)
**Requirements**: MAINT-01, MAINT-02, MAINT-03
**Success Criteria** (what must be TRUE):
  1. A clear triage and bugfix process is documented in the maintainer runbook.
  2. Adopter-reported bugs are patched.
  3. Existing adopters have a documented path for applying generated-host template updates from minor/patch bumps.
**Plans**: 1 plan
- [x] 150-01-PLAN.md — Establish maintainer triage cadence, template update patterns, and verify zero-bug state.

### Phase 151: Ecosystem Sync & Hex Dependency Management
**Goal**: Ensure supply-chain security and framework alignment by syncing dependencies and checking OTP/Elixir compatibility.
**Depends on**: Phase 150
**Requirements**: ECO-01, ECO-02, ECO-03
**Success Criteria** (what must be TRUE):
  1. CI passes with zero deprecation warnings on the latest OTP.
  2. All dependencies are bumped to their latest stable versions without breaking CI pipelines.
  3. A minor or patch release is prepared if dependencies require it.
**Plans**: 1 plan
- [ ] 151-01-PLAN.md — Update Erlang to 28.5 and batch update Hex dependencies

### Phase 152: Strategic Bet Evaluation Gate
**Goal**: Validate feature requests against the Diminishing Returns Wall and establish a formal evaluation for future strategic bets.
**Depends on**: Phase 151
**Requirements**: STRAT-01, STRAT-02, STRAT-03
**Success Criteria** (what must be TRUE):
  1. A formal document assesses demand for SCIM, sigra_lockspire, and Threadline.
  2. A concrete threshold of adopter demand is established for overriding the maintenance-first default.
  3. Approved strategic bets (if any) are queued for deep research; rejected bets are formally deferred.
**Plans**: TBD

---

## Progress

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 150. Issue Triage & Bugfix Cadence | 1/1 | Complete    | 2026-06-01 |
| 151. Ecosystem Sync & Hex Dependency Management | 0/1 | Planned | - |
| 152. Strategic Bet Evaluation Gate | 0/0 | Not started | - |
