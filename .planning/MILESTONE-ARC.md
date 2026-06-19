---
last_updated: 2026-05-31
status: release_adoption_then_post_1_0_maintenance
current_release_followup: completed-REL-01
current_active_milestone: RELEASE-ADOPTION
default_post_release_candidate: POST-1.0-MAINTENANCE-AND-STRATEGIC-BETS
---

# Sigra Milestone Arc

## Strategic Goal

Make Sigra feel batteries-included for Phoenix teams until additional work becomes diminishing-return polish. v1.32 is the release/adoption closeout for that arc; after it closes, default to maintenance, release support, adopter feedback, and selective strategic bets instead of automatically selecting another feature tranche.

This arc exists so milestone selection starts from a ranked strategic sequence instead of re-researching priorities every time `/gsd-new-milestone` runs.

## Ranking Rules

Prefer milestones that:

1. Deepen already-shipped substrate instead of inventing new greenfield primitives.
2. Remove production or integration friction that adopters hit immediately after install.
3. Improve user/operator trust through clearer control surfaces, diagnostics, and honest docs.
4. Keep Sigra core provider-agnostic and Phoenix-native.
5. After v1.32 closes, respond to concrete evidence: regressions, security/trust findings, adopter reports, release failures, or an explicit strategic thesis.

Deprioritize work that is mostly:

- generic back-office admin expansion
- hosted-control-plane imitation
- product-specific authorization policy
- compliance theater without executable seams or evidence
- post-1.0 super-polish without adopter friction or release-risk evidence
- broad new auth primitives after the 1.0 contract is cut

## Ownership Boundaries

**Sigra core owns:**
- auth, session, passkey, and audit invariants
- provider-agnostic contracts
- diagnostics and verification hooks

**Generated host code owns:**
- user-facing and operator-facing UX
- email composition/layout overrides
- branding, copy, and host policy

**Docs and optional integrations own:**
- ESP-specific setup and bounce/complaint handling
- SPF / DKIM / DMARC and sender reputation posture
- compliance recipes and operator guidance
- cross-device passkey operational guidance

## GSD Defaults

When milestone selection or roadmap triage is delegated:

- while v1.32 is active, finish the RELEASE-ADOPTION phases before proposing new feature work
- after v1.32 closes, default to the post-1.0 maintenance/strategic-bets posture unless the user explicitly pivots
- only escalate decisions that affect the public contract, semver, security model, generated-host contract, or milestone order
- prefer decisive recommendations over reopening broad product-choice loops

## Post-1.0 Default Posture

After `v1.32 RELEASE-ADOPTION` closes and the real Hex `1.0.0` release is cut, Sigra should be considered broadly feature-complete for the expected Phoenix authentication-library surface. Future milestone proposals should answer "why now?" against one of these lanes:

- **Release support / hotfix:** fix actual release, install, upgrade, HexDocs, CI, or adopter regression evidence.
- **Maintenance / trust:** security findings, audit drift, dependency churn, deprecation cleanup, docs corrections, or release-process failures.
- **Adopter feedback:** concrete user pain from installation, upgrade, migration, demo/evaluator flow, or generated-host ownership.
- **Strategic bet:** a deliberate new thesis with clear boundaries and non-goals.

If none of those lanes apply, do not create a new milestone. Keep the work silent, defer it as polish, or record it as a future idea without planning.

## Backlog Corrections

The carried-forward future-requirement labels are not equally fresh. Treat these as corrected before planning the next milestone:

- `SESS-01` is effectively already shipped through session/device labeling in the generated host session surface.
- `PK-01` is mostly already shipped through passkey list / rename / remove flows.
- `EMAIL-02` should mean a coherent localization workflow and override seam, not merely that gettext calls exist.

The remaining meaningful work clusters are:

- email reliability, override seams, and diagnostics
- passkey recovery and cross-device trust
- compliance-friendly export and data-lifecycle seams

## Candidates

### active-followup

**Name:** `REL-01 Release Truth Reset`
**Priority:** required-before-new-feature-milestone
**Why now:** The repo has a milestone boundary but still needs a single coherent release/version story across package metadata, changelog, and release automation.
**Includes:**
- reconcile `mix.exs`, `.release-please-manifest.json`, `CHANGELOG.md`, and maintainer release docs
- verify the next release cut can be explained without mixing planning milestones with Hex versioning
**Non-goals:**
- new feature work
- reopening webhook trust work
- redesigning semver policy beyond restoring one coherent truth

### shipped

**ID:** `SESS-CTRL`
**Name:** `Session Control Plane`
**Priority:** 1
**Status:** Shipped 2026-05-08 via Phases 108-110.
**Why it mattered:** Best leverage-to-risk ratio; strengthened trust for every adopter using mostly shipped primitives.
**Theme:** Turn existing session primitives into a coherent account-security surface.
**Delivered scope:**
- logout-other-sessions-except-current
- clearer current-session truth on user/admin surfaces
- recent security activity over persisted audit/session truth
- cleaner revoke UX and bounded docs truth
**Bounded non-goals held:** no session-store redesign, no generic account-center expansion, no timeout-history over-claim.

### shipped

**ID:** `EMAIL-RAILS`
**Name:** `Email Reliability & Override Rails`
**Priority:** 1
**Status:** Shipped 2026-05-23 via Phases 111-114.
**Why now:** Phoenix still leaves email integration rough edges to the host; Sigra could make the default production path legible without claiming to own deliverability itself.
**Theme:** Make auth email integration production-ready after install.
**Delivered scope:**
- generated-host override seam for auth email templates
- preview and snapshot rails
- diagnostics and doctor checks for missing or inconsistent setup
- provider-agnostic telemetry and async delivery posture
- bounce / complaint hooks or stubs plus recipes
**Notable outcomes:**
- adopted Mailglass as the default preview/diagnostics unlock while preserving provider-agnostic delivery seams
- proved nested example-app compile/runtime behavior for bounce and complaint hooks after the optional-dependency guard fix
**Non-goals:**
- owning SPF / DKIM / DMARC
- hard-coding a preferred ESP in core
- becoming a generic inbound email-processing platform

### shipped

**ID:** `PK-LIFECYCLE`
**Name:** `Passkey Lifecycle Completion`
**Priority:** 2
**Status:** Shipped 2026-05-25 via Phases 115-121.
**Why now:** Passkey ceremony and basic management exist; the remaining risk is recovery and lifecycle trust.
**Theme:** Make passkey-primary and multi-device use trustworthy instead of just technically functional.
**Delivered scope:**
- recovery-first passkey-primary posture
- last-passkey warnings
- cross-device and bootstrap guidance/UX
- tighter lifecycle integration around passkeys
**Notable outcomes:**
- repaired-form proof authority now lives on Phases 115 and 116 rather than stale implementation summaries
- generated-host/browser proof and Nyquist closure now reconcile the milestone without claiming Sigra-owned sync or hosted recovery
**Prerequisites:**
- stable fallback and recovery story
- browser/platform validation for real flows
**Non-goals:**
- removing fallback auth by default
- inventing a custom sync layer
- broad MFA rewrite outside passkey-specific paths

### shipped

**ID:** `ENT-SSO`
**Name:** `Enterprise SSO & B2B Connections`
**Priority:** 3
**Status:** Shipped 2026-05-26 via Phases 122-126.
**Why now:** B2B customers demand SAML or OIDC single sign-on (e.g., Okta, Entra ID) to enforce their own corporate policies. Sigra has OAuth, but enterprise SSO requires Just-In-Time (JIT) provisioning and tenant-level identity routing.
**Theme:** Open the door to enterprise contracts for host applications.
**Delivered scope:**
- organization-bound enterprise connection model with truthful validation and activation refusal
- org-scoped enterprise entry and bounded domain discovery
- Just-In-Time (JIT) organization membership provisioning and safe reconciliation
- SSO-only enforcement with explicit break-glass recovery
- generated-host proof, installer parity, and canonical enterprise operator docs
**Assessment calibration (2026-05-25):**
- Repo-grounded next-step review kept this ranked first because Sigra already ships the org/MFA/RBAC/service-account substrate; the missing contract-closing wedge is enterprise login routing and JIT truth, not another narrow polish pass.
**Notable outcomes:**
- retroactive verification authority now exists for Phases 123, 124, and 125 instead of relying on summary-only closeout
- the shipped contract stayed OIDC-first and organization-scoped without claiming SCIM, hosted control-plane behavior, or opinionated authz
**Prerequisites:**
- Deep understanding of Assent's SAML capabilities vs host-application requirements.
**Non-goals:**
- Building a full SCIM directory sync layer (beyond JIT).
- Custom cryptography outside the Assent primitives.

### shipped

**ID:** `DATA-LIFECYCLE`
**Name:** `Compliance Export & Data Lifecycle`
**Priority:** 4
**Status:** Shipped 2026-05-27 as v1.28 via Phases 127-130.
**Why now:** Valuable, but lower-frequency adopter pain than session and email rough edges.
**Theme:** Extend existing export and anonymize seams into a coherent auth-data lifecycle story.
**Likely scope:**
- extend `Sigra.DataExport`
- include audit-log export posture
- clarify anonymize/delete semantics and operator recipes
**Prerequisites:**
- keep exports narrowly scoped to auth/account data
- reuse existing audit and admin export substrate
**Non-goals:**
- legal or compliance certification
- generic BI/reporting exports
- claiming host-app regulatory ownership

### shipped

**ID:** `SUITE-INTEGRATION`
**Name:** `szTheory Suite Integration`
**Priority:** 5
**Status:** Shipped (recipe-only) 2026-05-29 as v1.29 via Phases 131-136. Threadline audit forwarder was the only new library code; the "reference starter app" was deferred and is the unbuilt remainder now carried by `DEMO-SHOWCASE`.
**Why now:** Sigra's value compounds when adopters can compose it with the rest of the szTheory ecosystem (Mailglass, Threadline, Accrue, Lockspire, Relyra, Rulestead). Today these are individual recipes (see `todos/pending/2026-05-08-write-*-integration-recipe.md`); a focused milestone could ship first-class adapters where they exist (Threadline, Mailglass) and a coherent OSS-suite narrative.
**Theme:** Sigra-as-suite-anchor — the auth library that plays cleanly with the rest of the szTheory toolkit.
**Likely scope:**
- Threadline audit adapter (`Sigra.Audit.Adapters.Threadline`); see `seeds/SEED-006-threadline-audit-adapter.md`
- Confirm Mailglass adoption posture (likely already absorbed into EMAIL-RAILS; cross-link)
- Suite-narrative guide section + ecosystem diagram in `guides/introduction/`
- Reference starter app (Sigra + Accrue + Mailglass) — separate repo or `examples/` directory
**Prerequisites:**
- EMAIL-RAILS shipped (Mailglass story crystallized)
- recipe TODOs C1–C5 landed (provides the doc baseline)
**Non-goals:**
- owning any sister-lib's roadmap
- replacing recipes with code where the library boundary doesn't justify it

### shipped

**ID:** `TRUST-HARDENING`
**Name:** `Trust Hardening — Optional-Dep SOT, Doctor & Deprecation Hygiene`
**Priority:** consolidation
**Status:** Shipped 2026-05-29 as v1.30 via Phases 137-140.
**Delivered scope:**
- `Sigra.OptionalDeps` single-source-of-truth + guard consolidation (replaced scattered `Code.ensure_loaded?`)
- `mix sigra.doctor` adopter-facing diagnostic
- recipe-contract fixture + sister-repo (Lockspire/Rulestead) verification with document-the-assumption fallback
- deprecation-removal timelines + verification + docs close
**Notable outcomes:**
- mid-milestone repo-grounded assessment (2026-05-29) put Sigra at 90-95% done-for-scope and named the one genuine *build* gap as the evaluator conversion surface (empty `test/example/priv/repo/seeds.exs`), graduating `DEMO-SHOWCASE` to top wedge.
**Non-goals held:** no new greenfield primitives; honored the Diminishing Returns Wall.

### next

**ID:** `DEMO-SHOWCASE`
**Name:** `Seed-rich Evaluator Demo Showcase`
**Priority:** 1 (top remaining build wedge — SELECTED as v1.31, 2026-05-29)
**Why now:** Repo-grounded assessment (2026-05-29) puts Sigra at 90–95% done for scope with adoption-evidence automation already strong (E2E, install-smoke, golden-path Playwright, dep-off CI). The one genuine gap is the *evaluator conversion surface*: `test/example/priv/repo/seeds.exs` is empty and the example app is a headless test fixture, not a positioned showcase. This is the unbuilt remainder of `SUITE-INTEGRATION`'s "reference starter app" (shipped recipe-only). For a pre-1.0 lib chasing adopters, the evaluation funnel is the highest-leverage *build* left.
**Theme:** Turn `test/example/` into double-duty adopter proof + click-around evaluator showcase.
**Likely scope:**
- realistic domain + 4–6 personas (admin w/ MFA + multi-org, standard user, invited-unconfirmed, locked, OAuth-linked, passkey user)
- idempotent, deterministic `seeds.exs`
- one-command spin-up (`mix setup && mix phx.server` → fully populated, clickable realistic SaaS)
- README/guide "try it locally" path with screenshots (README "Evaluating" lane)
- extend the existing Playwright golden-path to exercise seeded data
**Prerequisites:**
- v1.30 TRUST-HARDENING closed
- reuse existing `test/example/` + E2E/CI substrate (low net-new code)
**Non-goals:**
- a *separate standalone* demo repo (extend `test/example/`; nested-app drift cost already paid in Phase 114)
- a marketing site, component library, or generic seeding framework
- seeding host-app domain data beyond what makes auth/account features legible

> **Meta-framing (graduated from 137-LEARNINGS, 2026-05-29):** the honest bottleneck for "is Sigra done?" is **absence of real adopters, not missing features**. Demo Showcase is the best remaining *build*; the move after it is non-code — a 1.0 Hex cut + adoption push. Weight that above further feature wedges.

### ACTIVE — promoted to milestone v1.40 (2026-06-19)

**ID:** `CI-PERF` — **CI/CD Pipeline Performance Audit** (filed 2026-06-18; promoted to active milestone **v1.40 CI-PERF** on 2026-06-19; see `.planning/seeds/SEED-005-ci-cd-pipeline-performance-audit.md` + `.planning/REQUIREMENTS.md`)
**Lane:** Maintenance / trust (CI) + contributor DX. **Priority:** Medium-High, but **not** correctness — CI is green, just slow (~17–30m PR wall-clock; long poles: `library_tests` ~16m unpartitioned, `library_tests_dep_off` ~13m full rerun, two Playwright lanes ~8–22m). Driven by the verbatim companion playbook in the seed. Guardrails: keep high-value gates, cut only lowest-signal/flaky, deterministic, cache correctly, never trade trust for speed.

## The "Diminishing Returns" Wall (Permanent Non-Goals)

To protect the architectural integrity and maintainability of Sigra, we explicitly define boundaries that the library will **never** cross, even if requested:

- **Opinionated Authorization (RBAC / Zanzibar):** Sigra provides the identity (`user_id`, `organization_id`); the host app must own the *policy* (what the user can do). We provide seams, but we will not build a built-in roles engine.
- **Billing & Subscription Integration:** Direct mappings to Stripe or other billing providers are domain logic. Sigra provides webhook egress for syncing identity state, not billing logic.
- **Frontend / UI Component Libraries:** Sigra generates functional HTML (`mix sigra.install`); it will not ship a heavy CSS framework or React component library. Aesthetics belong to the adopter.

## Selection Guidance

`REL-01 Release Truth Reset`, `PK-LIFECYCLE`, `ENT-SSO`, `DATA-LIFECYCLE` (v1.28), `SUITE-INTEGRATION` (v1.29, recipe-only), and `TRUST-HARDENING` (v1.30) are all shipped. The ranked follow-on sequence after v1.30 closed is:

1. `DEMO-SHOWCASE Seed-rich Evaluator Demo Showcase` — **SELECTED as v1.31** (top remaining build wedge; re-ranked + confirmed 2026-05-29 over greenfield SCIM)
2. **1.0 Hex cut + adoption push** (non-code) — the honest bottleneck is adopters, not features; let real usage choose what's next

**Greenfield SCIM directory-sync is explicitly deprioritized below both of the above.** It is already a stated `ENT-SSO` non-goal ("full SCIM directory sync layer beyond JIT"). With Sigra at 90-95% done-for-scope, inventing a new greenfield primitive violates Ranking Rule 1 (deepen substrate over new primitives) and the Diminishing Returns Wall. Do not pull SCIM forward unless a concrete enterprise adopter proves JIT provisioning is insufficient for a real contract.

If a future milestone proposal does not clearly advance production trust, integration clarity, or DX on rough edges, treat it as lower priority than the ranked candidates above. After `DEMO-SHOWCASE`, default to the adoption push over any further feature wedge unless a concrete adopter need proves a new seam.
