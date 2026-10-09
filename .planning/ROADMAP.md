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

- [x] **Phase 246: Generated Confirmation Recovery** - Adopters can use the generated confirmation journey reliably, including pasted codes and visible feedback. (completed 2026-10-07)
- [x] **Phase 247: Release Candidate and Repository Readiness** - The 1.6.0 candidate is accurate for adopters and comes from a clean, reviewed source with the inherited checkout and PR queue dispositioned. (completed 2026-10-08)
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

**Plans**: 3/3 plans complete
Plans:

**Wave 1**
- [x] 246-01-PLAN.md — Reachable, explicit email-link confirmation with fresh-host persistence proof.

**Wave 2** *(blocked on Wave 1 completion)*
- [x] 246-02-PLAN.md — Account-bound pasted-code verification and visible feedback.

**Wave 3** *(blocked on Wave 2 completion)*
- [x] 246-03-PLAN.md — Generated-host browser, install, and exact-source required CI evidence passed; phase verification scored 10/10.

**UI hint**: yes

#### Phase 247: Release Candidate and Repository Readiness

**Goal**: Maintainers and adopters have a reviewable 1.6.0 candidate and a clean, fully accounted-for source checkout.
**Depends on**: Phase 246
**Requirements**: READY-01, READY-02
**Success Criteria** (what must be TRUE):
  1. The 1.6.0 candidate's package metadata, manifest, changelog, planned tag, and HexDocs source reference agree with the reviewed package source.
  2. An adopter can read what changed, supported compatibility, the required generated-host action or an explicit no-action statement, and the `~> 1.6.0` update and check path without internal planning notes presented as product changes.
  3. A maintainer can see a recorded disposition for every open PR and every inherited checkout change; release work has a clean source checkout without unrelated changes folded in.

**Plans**: Plans 01–04 and 06–11 are implemented; Plan 05 remains checkpointed, with its unfinished evidence-recovery path superseded by Plans 08–11. The final candidate is `0e773d3614a242e4fbcdd34c418ecb8a307703d6`; required exact-head CI passed, the authenticated non-publishing dry run passed, final readiness has zero diagnostics, and independent verification passed 14/14. The local WebKit startup limitation is recorded as `blocked_host_appkit`; browser proof comes from exact-head CI.

Plans:
**Wave 1**
- [x] 247-01-PLAN.md — Inventory inherited work and PRs; promote the scoped confirmation fix and pin a clean candidate at reviewed main `590eb4e`.

**Wave 2** *(blocked on Wave 1 completion)*
- [x] 247-02-PLAN.md — Refresh PR #224 and curate source-backed 1.6.0 notes.

**Wave 3** *(blocked on Wave 2 completion)*
- [x] 247-03-PLAN.md — Write the README-to-guide-to-changelog adopter path.

**Wave 4** *(blocked on Wave 3 completion)*
- [x] 247-04-PLAN.md — Prove final candidate, package, and repository readiness. Later completed by the authenticated non-publishing recovery in Plan 08.
- [x] 247-06-PLAN.md — Restore adopter notes and README→guide→changelog navigation, synchronize mobile signup with the LiveView validation response, and prove the exact PR #224 head and CI. Candidate SHA `6f8028658f0bdd7f26e13c3fe4d45437880c341b`; run `37717911489` passed, including docs, mobile signup, and `ci-gate`.

**Wave 5** *(Plan 05 depends on halted Plan 04; Plan 07 depends on Plan 06)*
- [ ] 247-05-PLAN.md — Checkpointed after partial fixed-source evidence work; its unfinished Tasks 3–4 are operationally superseded by Plan 08 and must not be resumed against the historical SHA.
- [x] 247-07-PLAN.md — Rebind the existing fixed-candidate workflow and baseline through protected evidence, with fail-closed re-review after any Release Please refresh. Evidence PR #291 passed required CI and merged to main as `9bb7566f31b40a129c5a234b122ac00b540ede29`; manifest blob and exact source baseline verified.

**Wave 6** *(depends on Plan 07; Plan 05 remains checkpointed)*
- [x] 247-08-PLAN.md — Authenticated non-publishing Hex dry run and final readiness passed on candidate `d76d7f2306f6099063a80a420d2d8a4e04c7785f`; later independent verification found one remaining signup-test gap.

**Wave 7** *(depends on Plan 08; candidate push requires explicit approval)*
- [x] 247-09-PLAN.md — Restore the server-rendered `Strong` validation wait in both signup paths; local WebKit startup is blocked by the documented host AppKit abort, and exact-head CI run `37819712610` passed the mobile journey with zero retries after explicit push approval.

**Wave 8** *(depends on Plan 09 exact-head CI; evidence rebind requires a separate explicit approval)*
- [x] 247-10-PLAN.md — Produce the exact-source proposal and, after separate approval, merge evidence PR #297 at `51be73415cf6de5531d3fb4c91ec3caf2c7544b6`; the protected diff contains exactly four approved evidence paths and preserves the manifest blob.

**Wave 9** *(depends on Plan 10's approved evidence merge)*
- [x] 247-11-PLAN.md — Authenticated non-publishing dry run `37824714823` passed; the final ledger validates with zero diagnostics and independent verification passed 14/14 on the same candidate SHA.

#### Phase 248: Exact-Source Release Gate

**Goal**: Maintainers can prove the existing release lane evaluated the exact source that it will publish and can diagnose every result.
**Depends on**: Phase 247
**Requirements**: AUTO-01, AUTO-02
**Success Criteria** (what must be TRUE):
  1. Before package work starts, the release tag resolves to the exact Release Please output SHA with a passing required CI gate; tests, warning-free documentation, package inspection, and Hex dry run execute against that immutable source.
  2. A running release evaluation can finish without cancellation by a later event; workflow permissions are scoped and the Hex credential is available only to the final publish step.
  3. A maintainer can retrieve machine-readable gate and publish receipts for success, failure, or cancellation, with version/tag, source SHA, workflow and run identity, verdict, relevant URLs, attempts, and timestamps.

**Plans**: 5/5 plans executed

Plans:

**Wave 1**
- [x] 248-01-PLAN.md — Bind the release package checks and CI gate to one exact source SHA.

**Wave 2** *(blocked on Wave 1 completion and Phase 247 candidate readiness)*
- [x] 248-02-PLAN.md — Test the Release Please head and guarded auto-squash-merge only that green head.

**Wave 3** *(blocked on Wave 2 completion)*
- [x] 248-03-PLAN.md — Scope workflow permissions and isolate release credentials behind main-only environments.

**Wave 4** *(blocked on Wave 3 completion)*
- [x] 248-04-PLAN.md — Retain machine-readable terminal gate and publish receipts.

**Wave 5** *(blocked on Waves 2 and 4 completion)*
- [x] 248-05-PLAN.md — Capture cancellation receipts and close cross-workflow security contracts.

#### Phase 249: Publish and Prove Sigra 1.6.0

**Goal**: Adopters can install documented Sigra 1.6.0, and maintainers can trace it to the exact gated source while finishing in a clean repository state.
**Depends on**: Phase 248
**Requirements**: REL-01, REL-02
**Success Criteria** (what must be TRUE):
  1. Hex serves Sigra 1.6.0 from the gated source, and the 1.6.0 HexDocs and source reference resolve to that same release.
  2. Required CI is green for the final protected-main release commit; the committed artifact-derived receipt identifies the immutable 1.6.0 package-source SHA and matching source CI, while final-main SHA and CI are recorded separately.
  3. Every local worktree is clean and every PR still open at closeout has a recorded disposition.

**Plans**: 7 plans

Plans:

**Wave 1**
- [ ] 249-01-PLAN.md — Prove the published 1.6.0 source, public docs and artifact-derived receipt.

**Wave 2** *(blocked on Wave 1 completion)*
- [ ] 249-02-PLAN.md — Regenerate the complete ExDoc index and require build-then-compare in CI.
- [ ] 249-04-PLAN.md — Inventory and disposition every current open PR and worktree change set.
- [ ] 249-07-PLAN.md — Expand exact-source proof mismatch and hostile-artifact fixtures.

**Wave 3** *(blocked on Plan 02)*
- [ ] 249-03-PLAN.md — Refresh the fixed Release Please candidate automatically with scoped write authority.

**Wave 4** *(blocked on Plans 03 and 04)*
- [ ] 249-05-PLAN.md — Preserve inherited work and promote the scoped release change through protected review.

**Wave 5** *(blocked on Plan 05)*
- [ ] 249-06-PLAN.md — Prove the final protected-main head and finish public and repository closeout acceptance.

### Progress

**Execution Order:** 246 → 247 → 248 → 249

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 246. Generated Confirmation Recovery | v1.49 | 3/3 | Complete    | 2026-10-07 |
| 247. Release Candidate and Repository Readiness | v1.49 | 10/11 | Complete | 2026-10-08 |
| 248. Exact-Source Release Gate | v1.49 | 5/5 | In Progress | - |
| 249. Publish and Prove Sigra 1.6.0 | v1.49 | 0/7 | Not started | - |

### Next

**Next: close Phase 248 verification gaps before Phase 249.** Plans 01-05 are implemented; `248-VERIFICATION.md` reports `gaps_found` (13/18). The gap is environment scope and hosted evidence, not a demonstrated expiry: `RELEASE_PLEASE_TOKEN` and `HEX_API_KEY` exist at repository scope, but their values and expiry are not visible and are not in the user’s 1Password. Regular Chrome is paused at GitHub and Hex identity checks. A fine-grained GitHub token is staged for only `szTheory/sigra`, no expiry if organization policy permits, and only workflow-needed permissions. Hex is pending the user’s choice between a long-lived API key and OIDC trusted publishing. Hosted dry-run and failure/cancellation receipts remain unverified. Phase 249 depends on Phase 248; do not publish Sigra 1.6.0 until the separate Phase 249 scope.
