# Requirements: Sigra v1.32 RELEASE-ADOPTION

**Defined:** 2026-05-31
**Core Value:** Authentication that works out of the box with great DX on the happy path and on the rough edges.

## v1.32 Requirements

### Release Truth

- [x] **REL1-01**: Maintainer can cut Hex `1.0.0` with `mix.exs`, `.release-please-manifest.json`, `CHANGELOG.md`, release tag, Hex version, and HexDocs `source_ref` all aligned.
- [ ] **REL1-02**: Maintainer can run a 1.0 release gate matrix that blocks publish unless library tests, install golden/idempotency, fresh install smoke, example/browser smoke, dep-off lane, docs warnings, Hex dry-run, and post-publish visibility checks are green or explicitly waived with evidence.
- [ ] **REL1-03**: Maintainer can follow a deterministic 1.0 runbook covering normal publish, dry-run inspection, tag/source-link checks, Hex publish, documentation publish, revert/replace recovery, and first-14-day hotfix policy.
- [x] **REL1-04**: Release notes can explain the planning-milestone-vs-Hex-version axis without confusing users about installable versions.

### Public Contract

- [x] **CONTRACT-01**: Developer can read a single public 1.0 contract that states supported Elixir, OTP, Phoenix, Ecto, and Postgres ranges plus optional dependency posture.
- [x] **CONTRACT-02**: Developer can distinguish library-owned, generated-host-owned, and shared seam surfaces before installing or upgrading Sigra.
- [x] **CONTRACT-03**: Developer can understand Sigra's SemVer, public API stability, experimental/private API, and deprecation/removal policy.
- [x] **CONTRACT-04**: Developer can read a security invariants and non-goals table covering sessions, tokens, MFA/passkeys, audit durability, mail/Oban/OAuth responsibilities, and host-owned authz/business policy.

### Upgrade And Migration

- [x] **UPGRADE-01**: Existing `0.3.x` adopter can follow an `upgrading-to-v1.0.md` guide with breaking-change table, generated-file review strategy, migration/schema impact, rollback notes, and verification commands.
- [x] **UPGRADE-02**: Maintainer can run an automated consumer upgrade smoke from latest `0.3.x` posture to `1.0.0`-candidate source and fail the release on unexpected compile/install/runtime regressions.
- [x] **MIGRATE-01**: Phoenix developer using `phx.gen.auth` can evaluate a migration lane that compares scope/session/token models, adoption sequence, risks, and when not to migrate.
- [x] **MIGRATE-02**: Developer using Pow, Guardian, Ueberauth, or composed auth stacks can evaluate a migration lane that explains cutover options, session/token/OAuth ownership differences, and migration risk.

### Adoption Funnel

- [ ] **ADOPT-01**: New evaluator can find one canonical first path from README, Hex package text, ExDoc, and `test/example/README.md` to run the demo and see meaningful auth flows in 10 minutes or less.
- [ ] **ADOPT-02**: Evaluator can use a persona intent map and screenshot grid to understand what each seeded demo account proves, including rough-edge states and explicit demo limitations.
- [ ] **ADOPT-03**: Developer can choose between greenfield, existing-app, migration, and advanced-control adoption lanes from the top-level docs without reading the whole guide set first.
- [ ] **ADOPT-04**: Developer can run `mix sigra.doctor` or equivalent documented verification immediately after install and understand expected success/failure output for common first-run mistakes.

### Launch Evidence

- [ ] **LAUNCH-01**: Maintainer has a publish-ready 1.0 announcement package with problem framing, core differentiators, explicit non-goals, proof links, upgrade guidance, and "who should upgrade now vs wait" guidance.
- [ ] **LAUNCH-02**: Public docs include an honest "Sigra vs alternatives" section comparing `phx.gen.auth`, Pow/Guardian/Ueberauth composition, and hosted auth without overclaiming.
- [ ] **LAUNCH-03**: Maintainer can attach a compact 1.0 evidence bundle to the release/announcement covering CI gates, UAT/CI mapping, demo screenshots, docs build, and known limitations.
- [ ] **LAUNCH-04**: AI-consumption assets (`llms.txt` or equivalent docs index) point to canonical install, ownership, migration, security, and demo paths so generated guidance stays consistent.

## Future Requirements

### Post-Launch

- **DEMO-03**: In-app per-persona explainer banner in the demo showcase.
- **SCIM-01**: Directory sync / SCIM once real adopter demand validates the enterprise lifecycle need.
- **CORR-01**: Threadline correlation-ID propagation after a stable Threadline injection seam exists.
- **GLUE-01**: Optional `sigra_lockspire` glue package after both APIs stabilize and a real companion-app trigger fires.

## Out of Scope

| Feature | Reason |
|---------|--------|
| New auth primitives | 1.0 launch should stabilize and explain the existing contract, not expand it. |
| Public RC train | Direct `1.0.0` is the selected path; RCs are fallback only if a concrete blocker appears. |
| Hosted control plane | Sigra remains a self-hosted Phoenix library with host-owned generated code. |
| Opinionated authorization engine | Authz policy is host business logic; Sigra provides identity and seams. |
| Broad UI redesign | This milestone may improve docs/demo affordances, not redesign generated-host UI. |
| Compliance certification claims | Evidence and operator guidance are in scope; legal certification is not. |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| REL1-01 | Phase 145 | Complete |
| REL1-02 | Phase 146 | Pending |
| REL1-03 | Phase 146 | Pending |
| REL1-04 | Phase 145 | Complete |
| CONTRACT-01 | Phase 145 | Complete |
| CONTRACT-02 | Phase 145 | Complete |
| CONTRACT-03 | Phase 145 | Complete |
| CONTRACT-04 | Phase 145 | Complete |
| UPGRADE-01 | Phase 147 | Complete |
| UPGRADE-02 | Phase 147 | Complete |
| MIGRATE-01 | Phase 147 | Complete |
| MIGRATE-02 | Phase 147 | Complete |
| ADOPT-01 | Phase 148 | Pending |
| ADOPT-02 | Phase 148 | Pending |
| ADOPT-03 | Phase 148 | Pending |
| ADOPT-04 | Phase 148 | Pending |
| LAUNCH-01 | Phase 149 | Pending |
| LAUNCH-02 | Phase 149 | Pending |
| LAUNCH-03 | Phase 149 | Pending |
| LAUNCH-04 | Phase 149 | Pending |
| DEMO-03 | Future | Deferred |
| SCIM-01 | Future | Deferred |
| CORR-01 | Future | Deferred |
| GLUE-01 | Future | Deferred |

**Coverage:**
- v1.32 requirements: 20 total
- Mapped to phases: 20
- Unmapped: 0

---
*Requirements defined: 2026-05-31*
*Last updated: 2026-05-31 after v1.32 new milestone research synthesis*
