# Roadmap: Sigra

**Core Value:** Authentication that works out of the box with great DX on the happy path and on the rough edges.
**Status:** v1.49 RELEASE-1.6.0 is planned. The package target is 1.6.0 from the existing Release Please PR #224; v1.49 is the GSD milestone number.

## Milestones

- 🚧 **v1.49 RELEASE-1.6.0** — Phases 246–249; ship Sigra 1.6.0 from reviewed, exactly tested source with adopter guidance and durable public evidence.
- ⚠️ **v1.48 CLEAN-BASELINE** — Phases 236–245; 21/27 requirements satisfied, four partial, two unsatisfied; seven stale verification reports and Phase 245 gaps_found. [Full roadmap](milestones/v1.48-ROADMAP.md) · [requirements](milestones/v1.48-REQUIREMENTS.md) · [audit](milestones/v1.48-MILESTONE-AUDIT.md)
- ⚠️ **v1.47 CI-EFFICIENCY** — Phases 230-235 (shipped 2026-09-15 · `override_closeout`, 21/24 requirements, TEST-01/TEST-02 unsatisfied, 46 artifacts acknowledged) · full detail in milestones/v1.47-ROADMAP.md
- ✅ **v1.46 ADOPTER-EXPERIENCE** — Phases 224-229 (shipped 2026-07-27 · `override_closeout`, 15/15 requirements, 8 audit findings deferred) · full detail in milestones/v1.46-ROADMAP.md
- ⚠️ **v1.45 RELEASE-CURRENCY** — Phases 221-223 (shipped 2026-07-11 · `override_closeout`, Phase 223 deferred) · full detail in milestones/v1.45-ROADMAP.md
- ✅ **v1.44 ADMIN-UX-RATCHET** — Phases 216-220 (shipped 2026-07-10) · full detail in milestones/v1.44-ROADMAP.md
- ✅ **v1.43 STABILIZE** — Phases 213-215 (shipped 2026-07-03) · full detail in milestones/v1.43-ROADMAP.md
- ✅ **v1.42 ADMIN-DS-ELEVATION** — Phases 205-212 (shipped 2026-07-02) · full detail in milestones/v1.42-ROADMAP.md
- ✅ **v1.41 ADMIN-UX-ELEVATION** — Phases 199-204 (shipped 2026-06-27)
- ✅ **v1.40 CI-PERF** — Phases 193-198 (shipped 2026-06-21)
- ✅ **v1.39 DS-COHERENCE** — Phases 184-192 (shipped 2026-06-19)
- ✅ **v1.38 BRAND-V2** — Phases 178-183 (shipped 2026-06-13)
- ✅ **v1.37 AUTH-BRANDING-WHITELABEL** — Phases 173-177 (shipped 2026-06-07)
- ✅ **v1.36 ADMIN-BRAND-THEME-POLISH** — Phases 168-172 (shipped 2026-06-06)
- ✅ **v1.35 BRAND-SYSTEM-PRESSURE-TEST** — Phases 161-167 (shipped 2026-06-05)
- ✅ **v1.34 ADMIN-UI-COHERENCE** — Phases 154-160 (shipped 2026-06-05)
- ✅ **v1.33 POST-1.0-MAINTENANCE-AND-STRATEGIC-BETS** — Phases 150-153 (shipped 2026-06-02)

## v1.49 — RELEASE-1.6.0 (In Progress)

**Milestone Goal:** Close the committed generated confirmation defects, release Sigra 1.6.0 from the exact reviewed and gated source, and finish with accurate adopter guidance, green main CI, clean worktrees, a triaged PR queue, and a durable package-to-source receipt.

**Phase Numbering:** Continues from the archived v1.48 Phase 245. The four phases below are the active v1.49 scope; prior milestone history remains in the archive links above.

- [ ] **Phase 246: Generated Confirmation Recovery** - Adopters can use the generated confirmation journey reliably, including pasted codes and visible feedback.
- [ ] **Phase 247: Release Candidate and Repository Readiness** - The 1.6.0 candidate is accurate for adopters and comes from a clean, reviewed source with the inherited checkout and PR queue dispositioned.
- [ ] **Phase 248: Exact-Source Release Gate** - The existing release lane proves source identity, completes its checks, and retains actionable receipts for every outcome.
- [ ] **Phase 249: Publish and Prove Sigra 1.6.0** - Hex, versioned HexDocs, protected main, local worktrees, and committed evidence agree on the release.

### Phase Details

#### Phase 246: Generated Confirmation Recovery
**Goal**: Freshly generated Phoenix hosts can complete and understand the full confirmation journey.
**Depends on**: Nothing in v1.49; follows terminal Phase 245 without reopening its historical evidence gaps.
**Requirements**: CONF-01, CONF-02, CONF-03
**Success Criteria** (what must be TRUE):
  1. In a fresh generated host, anonymous and already signed-in visitors can confirm an account, and deterministic evidence shows the persisted account state changes.
  2. A visitor can paste the code shown in a generated confirmation email into the confirmation form and submit it successfully, including a spaced code, without truncation or locale-dependent rejection.
  3. Generated authentication screens visibly show confirmation success and invalid-code feedback emitted by their LiveViews.
**Plans**: TBD
**UI hint**: yes

#### Phase 247: Release Candidate and Repository Readiness
**Goal**: Maintainers and adopters have a reviewable 1.6.0 candidate and a clean, fully accounted-for source checkout.
**Depends on**: Phase 246
**Requirements**: READY-01, READY-02
**Success Criteria** (what must be TRUE):
  1. The 1.6.0 candidate's package metadata, manifest, changelog, planned tag, and HexDocs source reference agree with the reviewed package source.
  2. An adopter can read what changed, supported compatibility, the required generated-host action or an explicit no-action statement, and the `~> 1.6.0` update and check path without internal planning notes presented as product changes.
  3. A maintainer can see a recorded disposition for every open PR and every inherited checkout change; release work has a clean source checkout without unrelated changes folded in.
**Plans**: TBD

#### Phase 248: Exact-Source Release Gate
**Goal**: Maintainers can prove the existing release lane evaluated the exact source that it will publish and can diagnose every result.
**Depends on**: Phase 247
**Requirements**: AUTO-01, AUTO-02
**Success Criteria** (what must be TRUE):
  1. Before package work starts, the release tag resolves to the exact Release Please output SHA with a passing required CI gate; tests, warning-free documentation, package inspection, and Hex dry run execute against that immutable source.
  2. A running release evaluation can finish without cancellation by a later event; workflow permissions are scoped and the Hex credential is available only to the final publish step.
  3. A maintainer can retrieve machine-readable gate and publish receipts for success, failure, or cancellation, with version/tag, source SHA, workflow and run identity, verdict, relevant URLs, attempts, and timestamps.
**Plans**: TBD

#### Phase 249: Publish and Prove Sigra 1.6.0
**Goal**: Adopters can install documented Sigra 1.6.0, and maintainers can trace it to the exact gated source while finishing in a clean repository state.
**Depends on**: Phase 248
**Requirements**: REL-01, REL-02
**Success Criteria** (what must be TRUE):
  1. Hex serves Sigra 1.6.0 from the gated source, and the 1.6.0 HexDocs and source reference resolve to that same release.
  2. Required CI is green for the final protected-main release commit, and a committed receipt identifies that exact source, tag, package, documentation, and CI run.
  3. Every local worktree is clean and every PR still open at closeout has a recorded disposition.
**Plans**: TBD

### Progress

**Execution Order:** 246 → 247 → 248 → 249

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 246. Generated Confirmation Recovery | v1.49 | 0/TBD | Not started | - |
| 247. Release Candidate and Repository Readiness | v1.49 | 0/TBD | Not started | - |
| 248. Exact-Source Release Gate | v1.49 | 0/TBD | Not started | - |
| 249. Publish and Prove Sigra 1.6.0 | v1.49 | 0/TBD | Not started | - |

### Next

Phase 246 readiness was checked on 2026-10-06: it is pending, has no context, research, or plans, and reports no prerequisite blocker. Run `$gsd-discuss-phase 246` to establish its context. Phase 245's historical verification gaps remain visible in its archived reports and do not expand v1.49 scope.
