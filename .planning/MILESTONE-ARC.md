---
last_updated: 2026-05-25
status: ready_for_next_selection
current_release_followup: completed-REL-01
current_active_milestone: none
default_post_release_candidate: ENT-SSO
---

# Sigra Milestone Arc

## Strategic Goal

Make Sigra feel batteries-included for Phoenix teams until additional work becomes diminishing-return polish.

This arc exists so milestone selection starts from a ranked strategic sequence instead of re-researching priorities every time `/gsd-new-milestone` runs.

## Ranking Rules

Prefer milestones that:

1. Deepen already-shipped substrate instead of inventing new greenfield primitives.
2. Remove production or integration friction that adopters hit immediately after install.
3. Improve user/operator trust through clearer control surfaces, diagnostics, and honest docs.
4. Keep Sigra core provider-agnostic and Phoenix-native.

Deprioritize work that is mostly:

- generic back-office admin expansion
- hosted-control-plane imitation
- product-specific authorization policy
- compliance theater without executable seams or evidence

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

- default to the highest-ranked `candidate` below unless the user explicitly pivots
- only escalate decisions that affect the public contract, semver, security model, generated-host contract, or milestone order
- prefer decisive recommendations over reopening broad product-choice loops

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

### candidate

**ID:** `ENT-SSO`
**Name:** `Enterprise SSO & B2B Connections`
**Priority:** 3
**Why now:** B2B customers demand SAML or OIDC single sign-on (e.g., Okta, Entra ID) to enforce their own corporate policies. Sigra has OAuth, but enterprise SSO requires Just-In-Time (JIT) provisioning and tenant-level identity routing.
**Theme:** Open the door to enterprise contracts for host applications.
**Likely scope:**
- Standardization layer around `Assent` for enterprise connections (SAML).
- Tenant-level directory routing (IdP-initiated flows or domain-based IdP discovery).
- Just-In-Time (JIT) organization membership provisioning.
**Prerequisites:**
- Deep understanding of Assent's SAML capabilities vs host-application requirements.
**Non-goals:**
- Building a full SCIM directory sync layer (beyond JIT).
- Custom cryptography outside the Assent primitives.

### candidate

**ID:** `DATA-LIFECYCLE`
**Name:** `Compliance Export & Data Lifecycle`
**Priority:** 4
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

### candidate

**ID:** `SUITE-INTEGRATION`
**Name:** `szTheory Suite Integration`
**Priority:** 5
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

## The "Diminishing Returns" Wall (Permanent Non-Goals)

To protect the architectural integrity and maintainability of Sigra, we explicitly define boundaries that the library will **never** cross, even if requested:

- **Opinionated Authorization (RBAC / Zanzibar):** Sigra provides the identity (`user_id`, `organization_id`); the host app must own the *policy* (what the user can do). We provide seams, but we will not build a built-in roles engine.
- **Billing & Subscription Integration:** Direct mappings to Stripe or other billing providers are domain logic. Sigra provides webhook egress for syncing identity state, not billing logic.
- **Frontend / UI Component Libraries:** Sigra generates functional HTML (`mix sigra.install`); it will not ship a heavy CSS framework or React component library. Aesthetics belong to the adopter.

## Selection Guidance

`REL-01 Release Truth Reset` is complete and `PK-LIFECYCLE` is now shipped. With no active milestone selected, the default next sequence becomes:

1. `ENT-SSO Enterprise SSO & B2B Connections`
2. `DATA-LIFECYCLE Compliance Export & Data Lifecycle`
3. `SUITE-INTEGRATION szTheory Suite Integration`

If a future milestone proposal does not clearly advance production trust, integration clarity, or DX on rough edges, treat it as lower priority than the ranked candidates above.
