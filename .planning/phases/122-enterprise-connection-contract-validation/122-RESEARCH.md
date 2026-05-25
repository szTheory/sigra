# Phase 122: Enterprise Connection Contract & Validation - Research

**Researched:** 2026-05-25 [VERIFIED: roadmap, requirements, codebase, official Assent docs]
**Domain:** Organization-bound enterprise OIDC connection modeling, setup validation, and truthful activation semantics for Sigra's generated-host operator surface [VERIFIED: `.planning/ROADMAP.md`, `.planning/REQUIREMENTS.md`, `.planning/PROJECT.md`]
**Confidence:** HIGH [VERIFIED: current codebase patterns plus primary OIDC dependency docs]

<user_constraints>
## User Constraints

- Phase 122 is explicitly OIDC-first. The milestone keeps SAML as a future-compatible seam, but this phase must not pretend broader protocol support than the repo can ship honestly now. [VERIFIED: `.planning/MILESTONE-ARC.md`, `.planning/research/SUMMARY.md`]
- The enterprise connection must be organization-bound, not a global provider toggle. Routing and JIT membership land in later phases; this phase only defines and validates the connection contract itself. [VERIFIED: `.planning/ROADMAP.md`, `.planning/REQUIREMENTS.md`]
- Activation must fail truthfully when discovery or client configuration is unusable. A saved draft may exist, but Sigra must not represent an invalid connection as active. [VERIFIED: `.planning/ROADMAP.md`, `.planning/REQUIREMENTS.md`]
- The public/generated-host contract must stay provider-agnostic enough that future protocol expansion can reuse the same operator mental model rather than inventing a second control surface. [VERIFIED: `.planning/ROADMAP.md`]
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| SSO-01 | Organization admins can configure an enterprise OIDC connection for their organization using validated discovery and client settings. [VERIFIED: `.planning/REQUIREMENTS.md`] | Sigra already has NimbleOptions-backed config validation, organization ownership/membership substrate, generated-host patterns, and Assent OIDC support to build an org-scoped connection model without inventing a separate auth stack. [VERIFIED: `lib/sigra/config.ex`, `lib/sigra/organizations.ex`, `lib/mix/tasks/sigra.gen.oauth.ex`, `test/sigra/oauth/assent_oidc_contract_test.exs`] |
| SSO-02 | Sigra refuses to activate an unusable enterprise connection and exposes setup truth clearly enough that operators do not need to reverse-engineer callback failures. [VERIFIED: `.planning/REQUIREMENTS.md`] | The safest contract is a draft/validated/active lifecycle with preflight discovery checks, callback-url validation, and explicit error state persisted on the connection instead of discovering breakage only at login time. [INFERENCE from roadmap goal + existing operator-truth patterns] |
</phase_requirements>

## Summary

Phase 122 should establish a new organization-owned enterprise connection resource plus a thin validation service, not a full login flow. The repo already has the three ingredients this phase needs: a mature organization substrate for ownership and scoping, an OAuth/OIDC integration layer built around Assent, and generated-host/admin/operator patterns for exposing truthful settings surfaces. What it lacks is a first-class per-organization enterprise connection model and the activation semantics that distinguish "saved configuration" from "validated and usable". [VERIFIED: `lib/sigra/organizations.ex`, `lib/sigra/oauth.ex`, `lib/sigra/oauth/strategies.ex`, `lib/mix/tasks/sigra.gen.oauth.ex`]

The key design decision is to model enterprise SSO as an organization-scoped connection with explicit lifecycle state, not as another entry inside the existing global `oauth[:providers]` keyword config. The current OAuth configuration is compile-time-ish host config for generic social providers; it does not fit dynamic per-organization connections, validation outcomes, or future enterprise protocol expansion. [VERIFIED: `lib/sigra/config.ex`, `lib/sigra/oauth.ex`, `guides/flows/oauth.md`]

The safest bounded contract for this phase is:

1. persist enterprise connection records per organization with enough fields to support OIDC now and future protocols later,
2. add a validation path that performs issuer/discovery/client-setting checks before activation,
3. expose truthful operator states such as `draft`, `validation_failed`, and `active`, and
4. keep later routing/JIT/enforcement concerns out of scope. [INFERENCE from roadmap phase boundaries]

**Primary recommendation:** split Phase 122 into two plans. Plan 01 should add the domain model, migrations, validation service, and tests for discovery/config semantics. Plan 02 should add the generated-host/admin/operator surface and documentation/tests that make invalid-vs-active truth legible. That keeps the public contract stable while separating persistence/validation risk from UI/operator-surface risk. [INFERENCE from repo structure and similar phase patterns]

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Enterprise connection persistence and org ownership | library context + host schemas | generated host wrappers | Security-critical org scoping belongs in Sigra's library-first context pattern, consistent with organizations and auth. [VERIFIED: `lib/sigra/organizations.ex`] |
| OIDC discovery and client validation | library service around Assent/Req | generated-host form UX | Validation must be reusable and authoritative; UI should display results, not invent them. [VERIFIED: `test/sigra/oauth/assent_oidc_contract_test.exs`, `test/example/AGENTS.md`] |
| Operator-facing configuration workflow | generated-host/admin LiveView or controller surface | library context APIs | Generated-host owns UX; Sigra core owns correctness and truth. [VERIFIED: `.planning/MILESTONE-ARC.md`, `lib/sigra/admin/live/organization_live.ex`] |
| Activation truth state | persisted connection status + validation metadata | audit/docs/operator copy | Active must mean "preflight validated", not merely "saved". [INFERENCE from requirement SSO-02] |
| Future protocol expansion seam | protocol-neutral connection envelope | OIDC-specific settings/details | Prevents Phase 122 from hard-coding an operator model that would block SAML later. [VERIFIED: roadmap success criterion 3] |

## Project Constraints

- Do not widen into routing, IdP discovery from user email, JIT provisioning, or SSO-only enforcement. Those belong to Phases 123-125. [VERIFIED: `.planning/ROADMAP.md`]
- Do not treat existing global OAuth provider config as the enterprise storage layer. It lacks per-organization scope and truthful activation state. [VERIFIED: `lib/sigra/config.ex`, `lib/sigra/oauth.ex`]
- Keep the persisted contract provider-agnostic at the top level. OIDC-specific fields can live under a protocol/type-specific configuration map or embedded schema, but the operator model must not require a future rewrite for SAML. [INFERENCE from roadmap success criterion 3]
- Avoid secrets leakage in audit metadata and operator diagnostics. Existing audit policy already treats tokens and secrets as sensitive and that must extend to enterprise client credentials. [VERIFIED: `lib/sigra/audit/changeset.ex`, `lib/sigra/oauth.ex`]

## Standard Stack

### Core

| Library / Tool | Version / Source | Purpose | Why Standard |
|----------------|------------------|---------|--------------|
| Ecto schemas + migrations | repo-local | Persist organization-bound enterprise connection records and validation state | All existing auth/org state is modeled this way. [VERIFIED: `lib/sigra/organizations.ex`, existing org migrations under `test/example/priv/repo/migrations/`] |
| Sigra context modules | repo-local | Own enterprise connection CRUD, scoping, and activation rules | Security-critical logic lives in library contexts, not generated host glue. [VERIFIED: `lib/sigra/organizations.ex`] |
| Assent OIDC | official HexDocs | Discovery-driven OIDC authorize/callback semantics and token/userinfo handling | Assent already exposes `Assent.Strategy.OIDC.authorize_url/1`, `callback/3`, discovery config, and ID-token validation. [VERIFIED: `test/sigra/oauth/assent_oidc_contract_test.exs`, https://hexdocs.pm/assent/Assent.Strategy.OIDC.html] |
| Req | project guideline | Fetch discovery documents and JWKS/userinfo preflight data where Sigra performs validation | Project guidance prefers `Req` for HTTP. [VERIFIED: `test/example/AGENTS.md`] |

### Supporting

| Library / Tool | Purpose | When to Use |
|----------------|---------|-------------|
| NimbleOptions-backed config/schema patterns | Validate operator-entered settings and config envelopes | Reuse for normalized OIDC settings and lifecycle enums where possible. [VERIFIED: `lib/sigra/config.ex`] |
| Existing OAuth strategy wrappers | Pattern source for provider abstraction and normalized user data | Useful for later routing/login phases and for understanding how OIDC-specific options should flow through Sigra. [VERIFIED: `lib/sigra/oauth/strategies.ex`, `lib/sigra/oauth/strategies/generic.ex`] |
| LiveView/generated-host form patterns | Truthful operator UI and validation feedback | Reuse existing generated-host conventions for forms, flash, and scoped pages. [VERIFIED: `priv/templates/sigra.gen.oauth/`, `test/sigra/oauth/oauth_settings_template_contract_test.exs`] |

## Architecture Patterns

### Pattern 1: Library-First Org-Scoped Substrate

**What:** Put enterprise connection invariants in a Sigra context and host-owned schema modules, then expose thin generated-host wrappers/views around them. [VERIFIED: `lib/sigra/organizations.ex`]

**When to use:** Any feature that binds identity/security state to organizations and must survive generated-host regeneration or UX customization. [VERIFIED: org architecture docs in code]

**Why it fits here:** Enterprise connections affect authentication correctness and cross-phase routing/JIT logic. They need a durable core contract now so later phases can compose on top without moving business rules back out of the host surface. [INFERENCE from roadmap sequence]

### Pattern 2: Saved Draft vs Validated Active State

**What:** Distinguish persisted configuration from activated configuration with explicit status fields and last-validation metadata.

**Recommended states:**
- `draft` — incomplete or unvalidated
- `validation_failed` — most recent preflight failed; not usable
- `active` — discovery and required client settings validated
- `disabled` — intentionally turned off while preserving config/history

**When to use:** Operator-entered external integrations where callback-time failure would otherwise be the first truth signal.

**Why it fits here:** Requirement `SSO-02` is explicitly about refusing to activate unusable configs. A boolean `enabled` flag is too weak unless it is backed by a validation transition. [INFERENCE from requirements]

### Pattern 3: Protocol-Neutral Connection Envelope with OIDC-Specific Detail

**What:** Model a top-level connection with neutral fields such as `organization_id`, `provider_type`, `status`, `display_name`, `domains`, and validation timestamps, while keeping OIDC-specific settings in a typed embedded schema or validated map.

**When to use:** When the roadmap already signals likely future protocol expansion but current delivery is intentionally narrower.

**Why it fits here:** Phase 122 must stay OIDC-first without trapping future SAML work behind a second operator surface. [VERIFIED: `.planning/MILESTONE-ARC.md`, `.planning/ROADMAP.md`]

### Pattern 4: Preflight Discovery Validation Before Activation

**What:** Validate issuer/discovery URL, required endpoints, client authentication method compatibility, redirect URI, and basic claim expectations before flipping the connection to `active`.

**Likely checks for OIDC now:**
- issuer/base URL present and well-formed
- discovery document fetch succeeds
- authorization/token/JWKS endpoints are discoverable
- client authentication method is one Sigra supports now
- redirect URI matches the generated-host callback route Sigra will use later
- configured scopes include `openid`

**Why it fits here:** Assent OIDC already depends on issuer/discovery data and session params such as `state`, `code_verifier`, and `nonce`. Failing these early is safer than treating callback-time explosions as operator validation. [VERIFIED: https://hexdocs.pm/assent/Assent.Strategy.OIDC.html]

## Recommended Domain Shape

### New bounded subsystem

- `Sigra.EnterpriseConnections` context or similar library-owned module
- host-owned schema(s) generated by a new install/generator seam or manual integration path
- one primary `enterprise_connections` table scoped by `organization_id`

### Likely persisted fields

- `organization_id`
- `slug` or stable internal key
- `protocol` or `provider_type` (`:oidc` now; future-safe for `:saml`)
- `status` (`draft`, `validation_failed`, `active`, `disabled`)
- `display_name`
- `issuer` / `base_url`
- `client_id`
- encrypted `client_secret`
- optional `discovery_document_uri` override
- `client_authentication_method`
- `scopes`
- `email_domains` or verified routing hints placeholder
- `last_validated_at`
- `last_validation_error`
- timestamps/audit metadata

**Important:** `email_domains` can exist as a future routing seam but Phase 122 should not ship domain-based login resolution yet; it is just part of the connection contract for Phase 123 to consume. [INFERENCE from roadmap dependency]

## Anti-Patterns to Avoid

- **Reusing global `oauth[:providers]` config as enterprise storage:** that config is host-global and not suitable for organization-owned state or activation truth. [VERIFIED: `lib/sigra/config.ex`]
- **Single `enabled` boolean without validation lifecycle:** this makes it easy to overclaim unusable connections as active. [INFERENCE from `SSO-02`]
- **Overfitting the schema to OIDC-only naming at the top level:** later SAML support would force either a breaking rename or a second control plane. [VERIFIED: roadmap success criterion 3]
- **Deferring all validation to first login attempt:** operators then have to reverse-engineer callback failures, which is exactly what `SSO-02` forbids. [VERIFIED: `.planning/REQUIREMENTS.md`]
- **Logging client secrets or token-shaped values in audit/events:** existing Sigra audit policy already forbids this class of leakage. [VERIFIED: `lib/sigra/audit/changeset.ex`, `lib/sigra/oauth.ex`]

## Common Pitfalls

### Pitfall 1: Conflating "saved" with "usable"

**What goes wrong:** The operator saves issuer/client values and the UI marks the connection enabled even though discovery or redirect constraints are wrong.

**How to avoid:** Treat save and activate as separate transitions or make activation contingent on successful validation in the same transaction. Persist the validation result and surface the last failure reason clearly. [INFERENCE from requirement SSO-02]

### Pitfall 2: Baking login-routing decisions into the Phase 122 model

**What goes wrong:** The phase expands into domain discovery heuristics, org chooser UX, or callback routing before the base contract is stable.

**How to avoid:** Keep Phase 122 focused on the persisted connection shape and validation APIs. Domain resolution and org-aware entry belong to Phase 123. [VERIFIED: `.planning/ROADMAP.md`]

### Pitfall 3: Depending on compile-time config for per-org credentials

**What goes wrong:** Enterprise customers cannot manage their own connection state without redeploy/reconfigure cycles, and generated-host operator surfaces become fake.

**How to avoid:** Store per-organization connection credentials/state in DB-backed schemas with encrypted secret handling, then have runtime logic read that substrate. [INFERENCE from enterprise requirement shape]

### Pitfall 4: Narrowing the contract to one IdP's quirks

**What goes wrong:** The model ends up looking like "Okta config" rather than a generic OIDC enterprise connection.

**How to avoid:** Normalize on OIDC concepts from Assent and the discovery document instead of provider-brand-specific fields. [VERIFIED: Assent OIDC docs]

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | ExUnit with schema/context/config contract tests and generated-host surface tests. [VERIFIED: repo test patterns] |
| Config file | `test/test_helper.exs` and `test/example/test/test_helper.exs`. [VERIFIED: codebase] |
| Quick run command | `mix test test/sigra/oauth/assent_oidc_contract_test.exs test/sigra/oauth/config_test.exs test/sigra/oauth/strategies_test.exs` |
| Full suite command | `mix test test/sigra/oauth/assent_oidc_contract_test.exs test/sigra/oauth/config_test.exs test/sigra/oauth/strategies_test.exs test/sigra/organizations/context_test.exs test/sigra/organizations/schema_test.exs test/sigra/admin/live/organization_live_test.exs` |

### Phase Requirements -> Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| SSO-01 | Enterprise connection schema/context enforces organization ownership, required OIDC settings, and normalized status transitions. | ExUnit context/schema | `mix test test/sigra/enterprise_connections/context_test.exs test/sigra/enterprise_connections/schema_test.exs` | ❌ Wave 0 |
| SSO-01 | Discovery/config validation accepts minimally valid OIDC inputs and rejects malformed issuer/client data. | ExUnit service/contract | `mix test test/sigra/enterprise_connections/validation_test.exs` | ❌ Wave 0 |
| SSO-02 | Activation cannot succeed when discovery, endpoints, redirect shape, or required client settings are invalid. | ExUnit integration/context | `mix test test/sigra/enterprise_connections/activation_test.exs` | ❌ Wave 0 |
| SSO-02 | Generated-host/admin surface exposes truthful draft/failed/active states and does not claim invalid configs are active. | LiveView/controller/template | `mix test test/sigra/admin/live/enterprise_connection_live_test.exs` | ❌ Wave 0 |

### Sampling Rate

- **After every task commit:** run the smallest plan-local ExUnit command for the touched subsystem.
- **After the schema/service plan:** run all `test/sigra/enterprise_connections/*` tests plus existing OIDC contract tests.
- **After the operator-surface plan:** run the full suite command plus any new generated-host/admin surface tests.
- **Before `$gsd-verify-work`:** all new enterprise-connection tests and the existing OIDC contract tests must pass.

### Wave 0 Gaps

- `test/sigra/enterprise_connections/schema_test.exs` - schema/state transition contract
- `test/sigra/enterprise_connections/context_test.exs` - org-scoped CRUD/authorization contract
- `test/sigra/enterprise_connections/validation_test.exs` - discovery/client validation behavior
- `test/sigra/enterprise_connections/activation_test.exs` - invalid configs cannot activate
- `test/sigra/admin/live/enterprise_connection_live_test.exs` or equivalent generated-host test surface

## Suggested Plan Split

### Plan 01 - Domain model, validation service, and proof substrate

Focus:
- new schema(s) and migration
- org-scoped context API
- encrypted secret handling
- validation lifecycle/status contract
- ExUnit coverage for OIDC discovery and activation refusal

### Plan 02 - Generated-host/admin surface and truthful operator UX

Focus:
- organization admin route/page/form
- validation feedback and status display
- activation/deactivation flow
- docs and tests that prove invalid configurations do not masquerade as active

## Sources

### Primary (HIGH confidence)

- `.planning/ROADMAP.md`
- `.planning/REQUIREMENTS.md`
- `.planning/PROJECT.md`
- `.planning/MILESTONE-ARC.md`
- `.planning/research/SUMMARY.md`
- `lib/sigra/config.ex`
- `lib/sigra/oauth.ex`
- `lib/sigra/oauth/strategies.ex`
- `lib/sigra/organizations.ex`
- `lib/mix/tasks/sigra.gen.oauth.ex`
- `test/sigra/oauth/assent_oidc_contract_test.exs`
- `test/sigra/oauth/config_test.exs`
- `test/sigra/oauth/strategies_test.exs`
- `test/sigra/oauth/oauth_settings_template_contract_test.exs`
- `test/example/AGENTS.md`
- https://hexdocs.pm/assent/Assent.Strategy.OIDC.html

### Secondary (MEDIUM confidence)

- `guides/flows/oauth.md`
- `lib/sigra/admin/live/organization_live.ex`
- organization-related tests and generated example files under `test/example/`

### Tertiary (LOW confidence)

- None. The phase can be planned primarily from repo-local patterns plus current official Assent OIDC docs.
