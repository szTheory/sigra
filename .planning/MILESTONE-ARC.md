---
last_updated: 2026-05-08
status: active
current_release_followup: completed-REL-01
default_post_release_candidate: EMAIL-RAILS
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

### active-milestone

**ID:** `EMAIL-RAILS`
**Name:** `Email Reliability & Override Rails`
**Priority:** 1
**Why now:** Phoenix still leaves email integration rough edges to the host; Sigra can make the default production path legible without claiming to own deliverability itself.
**Theme:** Make auth email integration production-ready after install.
**Likely scope:**
- generated-host override seam for auth email templates
- preview and snapshot rails
- diagnostics and doctor checks for missing or inconsistent setup
- provider-agnostic telemetry and async delivery posture
- bounce / complaint hooks or stubs plus recipes
- evaluate Mailglass adapter (`Sigra.Mailers.Adapters.Mailglass`) as the primary unlock for preview + admin + webhook ledger + unsubscribe; see `seeds/SEED-005-mailglass-mailer-adapter.md`. If adopted, EMAIL-RAILS scope shrinks to "wire the adapter, document the override surface, ship the preview catalog."
**Prerequisites:**
- keep core provider-agnostic
- preserve Swoosh and Oban seams
- if pursuing Mailglass path, widen Mailglass's optional `:sigra` constraint first (see `todos/pending/2026-05-08-cross-repo-mailglass-sigra-constraint.md`)
**Non-goals:**
- owning SPF / DKIM / DMARC
- hard-coding a preferred ESP in core
- becoming a generic inbound email-processing platform

### candidate

**ID:** `PK-LIFECYCLE`
**Name:** `Passkey Lifecycle Completion`
**Priority:** 2
**Why now:** Passkey ceremony and basic management exist; the remaining risk is recovery and lifecycle trust.
**Theme:** Make passkey-primary and multi-device use trustworthy instead of just technically functional.
**Likely scope:**
- recovery-first passkey-primary posture
- last-passkey warnings
- cross-device and bootstrap guidance/UX
- tighter lifecycle integration around passkeys
**Prerequisites:**
- stable fallback and recovery story
- browser/platform validation for real flows
**Non-goals:**
- removing fallback auth by default
- inventing a custom sync layer
- broad MFA rewrite outside passkey-specific paths

### candidate

**ID:** `DATA-LIFECYCLE`
**Name:** `Compliance Export & Data Lifecycle`
**Priority:** 3
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
**Priority:** 4
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

## Selection Guidance

`REL-01 Release Truth Reset` is complete. Until a stronger signal appears from real adopter feedback, use this default sequence:

1. `EMAIL-RAILS Email Reliability & Override Rails`
2. `PK-LIFECYCLE Passkey Lifecycle Completion`
3. `DATA-LIFECYCLE Compliance Export & Data Lifecycle`
4. `SUITE-INTEGRATION szTheory Suite Integration`

If a future milestone proposal does not clearly advance production trust, integration clarity, or DX on rough edges, treat it as lower priority than the ranked candidates above.
