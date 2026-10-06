# Requirements: Sigra — v1.49 RELEASE-1.6.0

**Defined:** 2026-10-06
**Core Value:** Authentication that works out of the box with great DX on the happy path and on the rough edges — so developers can ship SaaS apps fast and grow with confidence.

**Milestone goal:** Ship Sigra 1.6.0 from reviewed, exactly tested source, close the committed generated-confirmation fast-follow, and finish with accurate adopter guidance, green main CI, clean worktrees, a triaged PR queue, and durable package-to-source evidence.

**Version decision:** The user delegated package-version selection. Use the existing Release Please PR #224 proposing 1.6.0; v1.49 is the GSD milestone number. Recheck the candidate's current source, review state, and CI before merge.

**Verification default:** No manual UAT for criteria that can be proven with deterministic generated-host tests, workflow contracts, GitHub/Hex APIs, CI run results, and versioned documentation checks. Record machine-readable evidence and exact SHAs. See [VERIFICATION-POLICY.md](VERIFICATION-POLICY.md).

## v1 Requirements

### Generated confirmation (CONF)

- [ ] **CONF-01**: In a freshly generated host app, an anonymous visitor and an already signed-in visitor can complete email confirmation, and the test proves the persisted account state changed rather than relying on response status alone.
- [ ] **CONF-02**: A confirmation code copied from the generated email can be pasted into the generated confirmation form and accepted without browser-side truncation or locale-dependent validation failure.
- [ ] **CONF-03**: Generated authentication screens display confirmation success and error feedback produced by their LiveViews, including invalid-code feedback.

### Release readiness (READY)

- [ ] **READY-01**: The 1.6.0 release candidate's package metadata, manifest, changelog, tag, and HexDocs source reference agree; adopter notes accurately describe shipped changes, compatibility, required generated-host action or no action, and the `~> 1.6.0` update/check path.
- [ ] **READY-02**: Every open PR at readiness time has a recorded release-blocking, release-relevant, or separate-follow-up disposition; inherited checkout changes are preserved and dispositioned; release work proceeds from a clean source checkout without silently absorbing unrelated work.

### Release automation (AUTO)

- [ ] **AUTO-01**: Before release package work starts, the release tag is proven to resolve to the exact Release Please source SHA whose required CI gate passed; the existing test, warning-free docs, package-content, and Hex dry-run checks run against that immutable source. Active release evaluation is not cancelled, workflow permissions are scoped, and the Hex secret is available only to the final publish step.
- [ ] **AUTO-02**: The release lane retains machine-readable gate and publish receipts for both success and failure, linking version/tag, source SHA, workflow/run identity, verdict, relevant URLs, attempts/timestamps, and failure or cancellation state.

### Published release (REL)

- [ ] **REL-01**: Hex contains package version 1.6.0 built from the gated source, and live checks prove the versioned HexDocs and source reference resolve to the same release.
- [ ] **REL-02**: The final protected-main release commit has green required CI, the release receipt is committed and points to that exact source, every local worktree is clean, and every open PR has a recorded disposition.

## Deferred Requirements

Tracked for later milestones; not part of the v1.49 roadmap.

- **AUTHUI-01**: Expand generated-auth browser coverage beyond the confirmation journey and add axe coverage across generated auth surfaces.
- **EMAIL-01**: Resolve the Mailglass ownership boundary and address remaining email-client rendering findings from SEED-011.
- **AUTH-01**: Correct the remaining spent-link messaging and other SEED-011 findings not included in CONF-01..03.
- **HEX-01**: Change Hex's `latest_stable_version` ranking or dependency resolver behavior. Publishing 1.6.0 does not itself repair the retired 1.20.0 ranking signal.
- **OPS-01**: Resolve Phase 245's historical PR-base and cleanup-history evidence gaps when new source evidence can prove the missing relationships.

## Out of Scope

| Feature | Reason |
|---------|--------|
| Publishing 1.5.1 or creating a separate patch backport | User delegated the version decision; the existing protected-main Release Please candidate is 1.6.0. |
| Version-jumping above 1.20.0 to alter Hex ranking | Burns intervening versions and does not belong to this release-delivery scope. |
| Fixing every finding in the generated email defect cluster | Only confirmation route, code paste, and visible feedback are committed to this release; email styling and unrelated findings need separate scope/ownership decisions. |
| Merging all open Dependabot or evidence PRs | PRs must be classified and dispositioned; unrelated PRs are not release prerequisites. |
| Phase 245 branch-prune proof and historical cleanup pairs | No new evidence addresses the archived blocker; repeating negative-proof work would churn. |
| New publisher, broad CI redesign, or exact-tarball attestation platform | Reuse the existing Release Please → CI gate → Hex path and harden only the identified gaps. |
| Auth UI, admin UI, brand, or unrelated feature work | These do not advance the selected package release. |

## Traceability

Every v1 requirement maps to exactly one v1.49 phase.

| Requirement | Phase | Status |
|-------------|-------|--------|
| CONF-01 | Phase 246 | Pending |
| CONF-02 | Phase 246 | Pending |
| CONF-03 | Phase 246 | Pending |
| READY-01 | Phase 247 | Pending |
| READY-02 | Phase 247 | Pending |
| AUTO-01 | Phase 248 | Pending |
| AUTO-02 | Phase 248 | Pending |
| REL-01 | Phase 249 | Pending |
| REL-02 | Phase 249 | Pending |

**Coverage:** 9/9 v1 requirements mapped exactly once; 0 unmapped.

---
*Requirements defined: 2026-10-06*
*Last updated: 2026-10-06 after v1.49 roadmap mapping*
