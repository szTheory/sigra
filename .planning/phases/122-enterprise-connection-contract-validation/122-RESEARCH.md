# Phase 122: Enterprise Connection Contract & Validation - Research

**Researched:** 2026-05-25  
**Domain:** Organization-bound enterprise OIDC connection modeling, validation, and generated-host operator truth [VERIFIED: roadmap.get-phase 122]  
**Confidence:** HIGH

## User Constraints

No phase-specific `*-CONTEXT.md` exists for Phase 122, so there are no additional locked user decisions beyond `.planning/REQUIREMENTS.md`, `.planning/ROADMAP.md`, `.planning/STATE.md`, `.planning/MILESTONE-ARC.md`, and `.planning/PROJECT.md`. [VERIFIED: init.phase-op 122]

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| SSO-01 | Organization admins can configure an enterprise OIDC connection for their organization using validated discovery and client settings. [VERIFIED: .planning/REQUIREMENTS.md] | Use an organization-scoped connection model, generated-host org settings UI, Assent OIDC discovery/config validation, and library-owned activation semantics. [VERIFIED: repo grep] |
| SSO-02 | Sigra refuses to activate an unusable enterprise connection and exposes setup truth clearly enough that operators do not need to reverse-engineer callback failures. [VERIFIED: .planning/REQUIREMENTS.md] | Add pre-activation validation, explicit activation state, error classification, and targeted tests for invalid issuer/discovery/client settings. [CITED: https://hexdocs.pm/assent/Assent.Strategy.OIDC.html] |
</phase_requirements>

## Project Constraints (from CLAUDE.md)

- Sigra’s blessed path is Phoenix `1.8+` with Ecto `3.x`; Plug compatibility is secondary and should not drive the primary design. [VERIFIED: CLAUDE.md]
- PostgreSQL is the primary database, and local `mix test` requires a live Postgres on `localhost:5432` with `postgres/postgres`. [VERIFIED: CLAUDE.md]
- Security-sensitive logic belongs in the library, while generated host code owns customizable UX and routes. [VERIFIED: CLAUDE.md; VERIFIED: lib/sigra/organizations.ex]
- OWASP-oriented security posture, minimal dependencies, and honest operator-facing behavior are mandatory project norms. [VERIFIED: CLAUDE.md]
- Do not make direct repo edits outside the GSD workflow unless explicitly asked; this research file is the planning artifact for that workflow. [VERIFIED: CLAUDE.md]
- No project-local skills were present under `.claude/skills/` or `.agents/skills/` in this workspace. [VERIFIED: filesystem check]

## Summary

Phase 122 should stay narrow: define a provider-agnostic enterprise connection contract, but only promise an OIDC implementation path in this milestone. Sigra already has a library-owned OAuth/OIDC orchestrator (`Sigra.OAuth`), a generic Assent strategy wrapper, a generated-host organization settings pattern, and an org-scoped routing substrate. Reusing those is the honest path; building a second enterprise-specific auth stack would violate the repo’s current architecture. [VERIFIED: lib/sigra/oauth.ex] [VERIFIED: lib/sigra/oauth/strategies/generic.ex] [VERIFIED: test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp_web/live/organization_settings_live.ex] [VERIFIED: lib/sigra/plug/load_organization_from_slug.ex]

The key planning requirement is to separate “configured” from “active”. Assent’s OIDC strategy can fetch OpenID configuration dynamically, adds `openid` scope automatically, supports nonce/session-bound state, and validates ID tokens against OIDC Core rules. That means Sigra can validate discovery and client configuration before activation instead of waiting for a failing callback. Phase 122 should therefore introduce an organization-bound connection record with explicit status, a library validation routine that exercises discovery and client configuration honestly, and generated-host UI that surfaces “draft / invalid / active” truth directly to org admins. [CITED: https://hexdocs.pm/assent/Assent.Strategy.OIDC.html] [CITED: https://openid.net/specs/openid-connect-discovery-1_0.html] [CITED: https://openid.net/specs/openid-connect-core-1_0.html]

**Primary recommendation:** Use a library-owned `enterprise connection` model per organization, validated through Assent OIDC before activation, and surface it through the existing generated-host organization settings pattern rather than inventing a new admin/control-plane surface. [VERIFIED: repo grep] [ASSUMED]

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Org admin configuration surface | Frontend Server | API / Backend | Existing organization settings are generated LiveView/controller code owned by the host app, while security-critical writes delegate to library modules. [VERIFIED: test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp_web/live/organization_settings_live.ex] [VERIFIED: lib/sigra/organizations.ex] |
| Enterprise connection validation and activation | API / Backend | Database / Storage | Discovery fetches, client-setting validation, and activation truth are security-critical and should follow the same library-owned pattern as OAuth and organizations. [VERIFIED: lib/sigra/oauth.ex] [VERIFIED: lib/sigra/organizations.ex] |
| OIDC discovery metadata fetch and token rules | API / Backend | CDN / Static | Assent performs OIDC protocol work server-side and validates ID tokens per OIDC rules. [CITED: https://hexdocs.pm/assent/Assent.Strategy.OIDC.html] |
| Org-bound connection persistence | Database / Storage | API / Backend | Phase 122 needs durable per-organization connection state; Sigra already persists organization and identity/auth state in Ecto/Postgres-backed schemas. [VERIFIED: mix.exs] [VERIFIED: .planning/PROJECT.md] |
| Public/generated-host contract stability for future protocols | API / Backend | Frontend Server | The library should own the contract shape, while generated-host forms render whatever fields the contract exposes. [VERIFIED: lib/sigra/config.ex] [ASSUMED] |

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `assent` | Repo constraint `~> 0.3`, locked `0.3.1`, latest release `0.3.1` on 2025-06-20. [VERIFIED: mix hex.info assent] | OIDC discovery, authorize/callback flow, ID token validation, userinfo fetch. [CITED: https://hexdocs.pm/assent/Assent.Strategy.OIDC.html] | Sigra already depends on Assent optionally, ships a generic Assent wrapper, and has an explicit contract test for `Assent.Strategy.OIDC`. [VERIFIED: mix.exs] [VERIFIED: lib/sigra/oauth/strategies/generic.ex] [VERIFIED: test/sigra/oauth/assent_oidc_contract_test.exs] |
| `phoenix` | Repo constraint `~> 1.8`, locked `1.8.5`, latest release `1.8.7` on 2026-05-06. [VERIFIED: mix hex.info phoenix] | Generated-host controller/LiveView/operator surface. [VERIFIED: mix.exs] | Existing org settings, routing, and generated-host patterns are Phoenix-owned already. [VERIFIED: repo grep] |
| `phoenix_live_view` | Repo constraint `~> 1.1`, locked `1.1.28`, latest stable release `1.1.30` on 2026-05-05. [VERIFIED: mix hex.info phoenix_live_view] | Org admin settings UX for configuration and truth display. [VERIFIED: mix.exs] | Existing organization settings surface is LiveView-based, so Phase 122 can extend the current operator model instead of adding a new UI system. [VERIFIED: test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp_web/live/organization_settings_live.ex] |
| `ecto` | Repo constraint `~> 3.12`, locked `3.13.5`, latest release `3.14.0` on 2026-05-19. [VERIFIED: mix hex.info ecto] | Persistence for org-bound connection records and validation state. [VERIFIED: mix.exs] | Sigra’s auth, org, identity, and audit state are already Ecto-backed. [VERIFIED: mix.exs] [VERIFIED: .planning/PROJECT.md] |
| `nimble_options` | Repo constraint `~> 1.1`, locked `1.1.1`, latest release `1.1.1` on 2024-05-25. [VERIFIED: mix hex.info nimble_options] | Library-owned option schemas and config validation. [VERIFIED: mix.exs] | Sigra already uses NimbleOptions for complex config surfaces like organizations, so enterprise connection validation should reuse the same pattern. [VERIFIED: lib/sigra/organizations.ex] |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Existing `Sigra.OAuth.Strategies.Generic` | Repo-local module. [VERIFIED: lib/sigra/oauth/strategies/generic.ex] | Generic wrapper for arbitrary Assent strategies. [VERIFIED: lib/sigra/oauth/strategies/generic.ex] | Use it as the reuse seam for enterprise OIDC strategy wiring instead of adding a second orchestration layer. [VERIFIED: lib/sigra/oauth/strategies/generic.ex] [ASSUMED] |
| Existing `Sigra.Plug.LoadOrganizationFromSlug` | Repo-local module. [VERIFIED: lib/sigra/plug/load_organization_from_slug.ex] | URL-scoped organization resolution and session-pointer refresh. [VERIFIED: lib/sigra/plug/load_organization_from_slug.ex] | Use it as the routing precedent for later org-aware enterprise entry work, and keep Phase 122’s contract compatible with slug-scoped routing. [VERIFIED: lib/sigra/plug/load_organization_from_slug.ex] |
| Existing generated `OrganizationSettingsLive` pattern | Repo-local template/proof surface. [VERIFIED: priv/templates/sigra.install/organizations/live/organization_settings_live.ex] | Operator-facing org settings UX with thin handlers delegating to library calls. [VERIFIED: priv/templates/sigra.install/organizations/live/organization_settings_live.ex] | Use it as the generated-host surface for configuring enterprise connections. [VERIFIED: repo grep] [ASSUMED] |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Assent OIDC | Custom OIDC discovery/JWKS/ID-token code | Do not hand-roll discovery, JWKS fetch, or ID token validation when Assent already owns those responsibilities. [CITED: https://hexdocs.pm/assent/Assent.Strategy.OIDC.html] |
| Existing org settings surface | New global admin/control-plane UI | A new global control plane contradicts the milestone’s generated-host/operator-surface goal and existing org-scoped UX model. [VERIFIED: .planning/ROADMAP.md] [VERIFIED: test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp_web/live/organization_settings_live.ex] |
| Provider-agnostic connection contract with OIDC discriminator | OIDC-specific public contract | OIDC-only naming would force a different operator model when SAML arrives later; a protocol discriminator keeps the contract stable. [VERIFIED: .planning/ROADMAP.md] [ASSUMED] |

**Installation:** Existing dependencies already cover the Phase 122 stack, so no new package is required for research-backed planning. [VERIFIED: mix.exs]

```bash
mix deps.get
```

**Version verification:** Versions above were verified with `mix hex.info assent`, `mix hex.info phoenix`, `mix hex.info phoenix_live_view`, `mix hex.info ecto`, and `mix hex.info nimble_options` on 2026-05-25. [VERIFIED: local commands]

## Architecture Patterns

### System Architecture Diagram

```text
Org admin
  |
  v
Generated host org settings (LiveView/controller)
  |
  v
Library command: create/update enterprise connection
  |
  +--> NimbleOptions / changeset validation
  |       |
  |       +--> reject missing issuer/client settings
  |
  +--> Assent OIDC validation probe
  |       |
  |       +--> fetch OpenID configuration
  |       +--> verify issuer/discovery endpoints
  |       +--> verify client auth mode prerequisites
  |
  +--> Persist org-bound connection + status
          |
          +--> `draft` / `invalid` / `active` status [ASSUMED]
          +--> operator-visible diagnostics
```

The critical design rule is that protocol validation happens before activation, not only during a callback failure path. [CITED: https://hexdocs.pm/assent/Assent.Strategy.OIDC.html]

### Recommended Project Structure

```text
lib/
├── sigra/enterprise/                 # Library-owned enterprise connection contract + validation [ASSUMED]
├── sigra/enterprise/oidc/            # OIDC-specific validation helpers over Assent [ASSUMED]
└── mix/tasks/ or install/features/   # Generator/install wiring for host surface updates [VERIFIED: repo grep]

priv/templates/sigra.install/
└── organizations/                    # Generated host org settings additions [VERIFIED: repo grep] [ASSUMED]

test/
├── sigra/enterprise/                 # Contract + validation tests to add in Wave 0 [ASSUMED]
└── sigra/install/                    # Generator/template contract tests for new UI/output [VERIFIED: repo grep] [ASSUMED]
```

### Pattern 1: Library Owns Validation, Host Owns Forms

**What:** Put OIDC discovery/client validation in library code, and keep the generated-host settings UI as a thin wrapper. [VERIFIED: lib/sigra/organizations.ex] [VERIFIED: test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp_web/live/organization_settings_live.ex]  
**When to use:** For any enterprise connection create/update/activate action. [ASSUMED]  
**Example:**

```elixir
# Source: repo pattern from Sigra.Organizations + generated OrganizationSettingsLive
def handle_event("save_enterprise_connection", %{"enterprise_connection" => params}, socket) do
  case Organizations.update_enterprise_connection(socket.assigns.current_scope, params) do
    {:ok, connection} -> {:noreply, assign(socket, :connection, connection)}
    {:error, changeset} -> {:noreply, assign(socket, :form, to_form(changeset))}
  end
end
```

### Pattern 2: Strategy Indirection Through Assent, Not Provider-Specific Branch Explosion

**What:** Keep provider-specific protocol mechanics behind Assent strategies and Sigra wrappers. [VERIFIED: lib/sigra/oauth/strategies/generic.ex] [CITED: https://hexdocs.pm/assent/Assent.Strategy.html]  
**When to use:** For enterprise OIDC issuer wiring and later protocol expansion. [ASSUMED]  
**Example:**

```elixir
# Source: lib/sigra/oauth/strategies/generic.ex
{strategy, config} = resolve_strategy(provider_config)
strategy.authorize_url(config)
```

### Pattern 3: Org Scope Is a First-Class Routing Input

**What:** Enterprise connections must be keyed to an organization and later resolved through org-aware routing, not global provider config. [VERIFIED: .planning/REQUIREMENTS.md] [VERIFIED: lib/sigra/plug/load_organization_from_slug.ex]  
**When to use:** For persistence keys, generated-host routes, and future callback correlation. [ASSUMED]  
**Example:**

```elixir
# Source: lib/sigra/plug/load_organization_from_slug.ex
with org when not is_nil(org) <- Organizations.get_organization_by_slug(config, slug),
     membership when not is_nil(membership) <- Organizations.get_membership(config, scope.user, org) do
  {:ok, org, membership}
end
```

### Anti-Patterns to Avoid

- **Activation boolean with no validation state:** A plain `enabled: true` flag would let Sigra claim a connection is active before discovery/client settings are proven usable. [VERIFIED: .planning/REQUIREMENTS.md] [ASSUMED]
- **Global `config.oauth.providers` reuse for enterprise org state:** Current OAuth config is app-global and keyed by provider atom, not organization-bound. [VERIFIED: lib/sigra/config.ex]
- **Callback-only truth:** Waiting for the first operator-reported callback failure violates `SSO-02`. [VERIFIED: .planning/REQUIREMENTS.md]
- **Protocol-specific public contract names:** Naming the model around OIDC only would undermine future SAML expansion without a public contract reshaping. [VERIFIED: .planning/ROADMAP.md] [ASSUMED]

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| OIDC discovery fetching | Custom `/.well-known` fetch/parser | `Assent.Strategy.OIDC` | Assent already supports dynamic OpenID configuration fetching. [CITED: https://hexdocs.pm/assent/Assent.Strategy.OIDC.html] |
| ID token validation / JWKS verification | Homegrown JWT/JWKS validation | `Assent.Strategy.OIDC.validate_id_token/2` path | Assent validates ID tokens per OIDC Core and can use `jwks_uri` for public-key verification. [CITED: https://hexdocs.pm/assent/Assent.Strategy.OIDC.html] |
| Option-schema validation | Ad hoc keyword parsing | `NimbleOptions` | Sigra already uses NimbleOptions for library config surfaces. [VERIFIED: lib/sigra/organizations.ex] |
| Org-scoped route resolution | New parallel tenant-routing logic | Existing org slug/scope patterns | `LoadOrganizationFromSlug` already defines org-scoped URL truth and membership-safe 404 behavior. [VERIFIED: lib/sigra/plug/load_organization_from_slug.ex] |
| Operator config UI scaffolding | Separate enterprise dashboard | Generated org settings surface | Existing organization settings prove Sigra’s generated-host operator model. [VERIFIED: test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp_web/live/organization_settings_live.ex] |

**Key insight:** Phase 122 is not blocked by missing protocol machinery; it is blocked by missing contract and activation truth. The plan should spend effort on model/state/UX truth, not on replacing Assent or Phoenix patterns already in the repo. [VERIFIED: mix.exs] [VERIFIED: repo grep]

## Common Pitfalls

### Pitfall 1: Treating “saved” as “active”

**What goes wrong:** Operators save issuer/client settings and the UI marks the connection as live even though discovery, issuer metadata, or client authentication settings are invalid. [VERIFIED: .planning/REQUIREMENTS.md] [CITED: https://hexdocs.pm/assent/Assent.Strategy.OIDC.html]  
**Why it happens:** Current Sigra OAuth config is declarative app config, so there is no built-in per-org activation truth yet. [VERIFIED: lib/sigra/config.ex]  
**How to avoid:** Persist an explicit validation/activation state and require a successful validation probe before moving to `active`. [ASSUMED]  
**Warning signs:** The only way to learn config is bad is an end-user callback failure. [VERIFIED: .planning/REQUIREMENTS.md]

### Pitfall 2: Smuggling enterprise state into global OAuth config

**What goes wrong:** Per-organization enterprise settings get forced into `config.oauth.providers`, which is app-global and provider-atom keyed. [VERIFIED: lib/sigra/config.ex]  
**Why it happens:** The existing OAuth surface is already there and looks superficially reusable. [VERIFIED: lib/sigra/config.ex]  
**How to avoid:** Create a dedicated org-bound connection model and keep `config.oauth.providers` for app-global social/provider config only. [ASSUMED]  
**Warning signs:** Designs that talk about `providers: [okta: ...]` without an `organization_id`. [VERIFIED: lib/sigra/config.ex] [ASSUMED]

### Pitfall 3: Losing org context between setup and future routing

**What goes wrong:** The connection is saved, but its contract does not preserve enough org/routing metadata for later slug-based entry and callback correlation. [VERIFIED: .planning/ROADMAP.md] [VERIFIED: lib/sigra/plug/load_organization_from_slug.ex]  
**Why it happens:** Phase 122 can be scoped too narrowly around forms and secrets, ignoring Phase 123’s routing dependency. [VERIFIED: .planning/ROADMAP.md]  
**How to avoid:** Include organization foreign key, protocol discriminator, and routing-relevant metadata in the contract now. [ASSUMED]  
**Warning signs:** Any proposed model that can only be looked up by provider name. [ASSUMED]

### Pitfall 4: Overpromising future protocols in current UX copy

**What goes wrong:** The public/generated-host surface says “enterprise SSO” generically while only OIDC has validated implementation semantics in the repo. [VERIFIED: .planning/research/SUMMARY.md] [VERIFIED: test/sigra/oauth/assent_oidc_contract_test.exs]  
**Why it happens:** Milestone language is broader than the current proven substrate. [VERIFIED: .planning/MILESTONE-ARC.md]  
**How to avoid:** Name the Phase 122 implementation “enterprise OIDC connection” while keeping the underlying data contract protocol-agnostic. [VERIFIED: .planning/ROADMAP.md] [ASSUMED]  
**Warning signs:** Docs or field names that hardcode “SAML/OIDC” without a real discriminator or implementation. [ASSUMED]

### Pitfall 5: Support-hostile error surfaces

**What goes wrong:** Operators only see a generic failure, with no distinction between bad issuer URL, discovery fetch failure, missing client secret, unsupported client auth method, or claim mismatch. [VERIFIED: .planning/REQUIREMENTS.md] [CITED: https://hexdocs.pm/assent/Assent.Strategy.OIDC.html]  
**Why it happens:** Raw protocol errors are not normalized into operator-facing states. [ASSUMED]  
**How to avoid:** Normalize validation errors into a bounded diagnostic taxonomy and persist/display the latest result. [ASSUMED]  
**Warning signs:** Flash copy that says only “SSO failed” or “Callback failed”. [ASSUMED]

## Code Examples

Verified patterns from official sources:

### OIDC Strategy Configuration

```elixir
# Source: https://hexdocs.pm/assent/Assent.Strategy.OIDC.html
config = [
  client_id: System.fetch_env!("OIDC_CLIENT_ID"),
  client_secret: System.fetch_env!("OIDC_CLIENT_SECRET"),
  base_url: "https://issuer.example.com",
  redirect_uri: "https://app.example.com/auth/enterprise/callback"
]
```

This is the verified minimum shape Assent expects for OIDC discovery-backed operation. [CITED: https://hexdocs.pm/assent/Assent.Strategy.OIDC.html]

### Generic Strategy Delegation

```elixir
# Source: lib/sigra/oauth/strategies/generic.ex
def authorize_url(provider_config) do
  ensure_assent!()
  {strategy, config} = resolve_strategy(provider_config)
  strategy.authorize_url(config)
end
```

This is the existing Sigra pattern for strategy indirection and is the cleanest reuse seam for enterprise OIDC strategy wiring. [VERIFIED: lib/sigra/oauth/strategies/generic.ex]

### Org-Scoped Route Resolution

```elixir
# Source: lib/sigra/plug/load_organization_from_slug.ex
case resolve(config, scope, slug) do
  {:ok, org, membership} -> assign_scope(conn, org, membership, opts)
  {:redirect, new_slug} -> redirect_to_canonical(conn, slug, new_slug)
  :not_found -> halt_not_found(conn, error_handler, opts)
end
```

This is the verified routing pattern that future enterprise entry flows must remain compatible with. [VERIFIED: lib/sigra/plug/load_organization_from_slug.ex]

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| App-global social OAuth provider config | Org-bound enterprise connection records with explicit status [ASSUMED] | Phase 122 target state for 2026-05-25 planning. [VERIFIED: roadmap.get-phase 122] | Prevents pretending that enterprise SSO is just another app-global social provider toggle. [VERIFIED: lib/sigra/config.ex] [ASSUMED] |
| “Discover truth at callback time” | Pre-activation discovery and client validation | Assent `OIDC` already supports discovery fetch and ID token validation in v0.3.1. [CITED: https://hexdocs.pm/assent/Assent.Strategy.OIDC.html] | Lets Sigra satisfy `SSO-02` honestly. [VERIFIED: .planning/REQUIREMENTS.md] |
| OIDC-specific host language | Provider-agnostic contract with protocol discriminator [ASSUMED] | Required by Phase 122 success criterion 3. [VERIFIED: roadmap.get-phase 122] | Keeps the operator model stable if SAML arrives later. [ASSUMED] |

**Deprecated/outdated:**

- Treating enterprise setup as a future docs problem is outdated for this milestone because `SSO-02` explicitly requires operator-visible setup truth in the product surface. [VERIFIED: .planning/REQUIREMENTS.md]

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | The generated host should extend `OrganizationSettingsLive` rather than add a separate enterprise admin surface. | Summary, Standard Stack, Architecture Patterns | Planner may assign UI work to the wrong surface and create avoidable operator-model churn. |
| A2 | The connection model should expose at least `draft / invalid / active` style states. | Summary, Architecture Patterns, Common Pitfalls | Planner may under-spec activation truth and leave `SSO-02` partially unmet. |
| A3 | A protocol discriminator should exist in the public contract even if only OIDC is implemented now. | Standard Stack, State of the Art | Planner may choose an OIDC-only schema that forces a breaking model change for SAML. |
| A4 | A dedicated `lib/sigra/enterprise/` namespace is the best implementation home. | Recommended Project Structure | Planner may lay work into awkward existing modules and reduce cohesion. |

## Open Questions

1. **Should client secrets and cached discovery metadata both be stored, or only client secrets?**
   - What we know: Sigra already uses `cloak_ecto` for sensitive auth data at rest. [VERIFIED: mix.exs] [VERIFIED: guides/flows/oauth.md]
   - What's unclear: Whether Phase 122 should persist discovery snapshots for diagnostics or fetch them on demand only. [ASSUMED]
   - Recommendation: Plan for encrypted client-secret storage in Phase 122 and treat discovery-metadata persistence as optional unless diagnostics UX clearly requires it. [ASSUMED]

2. **Should validation run synchronously on every save or as an explicit “Validate / Activate” action?**
   - What we know: `SSO-02` requires truthful activation failure, not silent acceptance. [VERIFIED: .planning/REQUIREMENTS.md]
   - What's unclear: Whether a synchronous validation-on-save experience will be acceptable for remote discovery timeouts. [ASSUMED]
   - Recommendation: Separate save from activate in the contract, and allow “validate now” before “activate” so draft edits do not pretend to be live. [ASSUMED]

3. **What minimum routing metadata must Phase 122 persist for Phase 123?**
   - What we know: Phase 123 depends directly on Phase 122 and requires org-aware entry plus verified email-domain discovery. [VERIFIED: .planning/ROADMAP.md]
   - What's unclear: Whether Phase 122 should already store verified domains, login hints, or only the connection contract. [ASSUMED]
   - Recommendation: Persist protocol discriminator and an organization foreign key now, and only add domain-routing fields in Phase 122 if they are required to avoid a schema rewrite in Phase 123. [ASSUMED]

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Elixir | Library implementation and tests | ✓ [VERIFIED: local command] | `1.19.5` [VERIFIED: local command] | — |
| Mix | Dependency and test commands | ✓ [VERIFIED: local command] | `1.19.5` [VERIFIED: local command] | — |
| PostgreSQL server | Local `mix test` for this repo | ✓ [VERIFIED: `pg_isready`] | `14.17` binary installed; `localhost:5432` accepting connections. [VERIFIED: local commands] | Docker is also installed if the local service changes. [VERIFIED: local commands] |
| Docker | Disposable Postgres fallback and CI parity | ✓ [VERIFIED: local command] | `29.4.1` [VERIFIED: local command] | Existing local Postgres is already live. [VERIFIED: `pg_isready`] |
| Node.js | Tooling and browser/example lanes in the repo | ✓ [VERIFIED: local command] | `v22.14.0` [VERIFIED: local command] | — |

**Missing dependencies with no fallback:**

- None. [VERIFIED: local commands]

**Missing dependencies with fallback:**

- None. [VERIFIED: local commands]

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | ExUnit on repo-root tests. [VERIFIED: test/test_helper.exs] |
| Config file | [`test/test_helper.exs`](/Users/jon/projects/sigra/test/test_helper.exs:1) [VERIFIED: test/test_helper.exs] |
| Quick run command | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/enterprise/connection_config_test.exs -x` [ASSUMED] |
| Full suite command | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test` [VERIFIED: CLAUDE.md] |

CI also runs `mix docs --warnings-as-errors` after library tests, so any planner should keep docs-build cleanliness in the phase gate. [VERIFIED: .github/workflows/ci.yml]

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| SSO-01 | Org admin can save valid enterprise OIDC settings and see truthful validation output. [VERIFIED: .planning/REQUIREMENTS.md] | unit + integration | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/enterprise/connection_config_test.exs -x` [ASSUMED] | ❌ Wave 0 |
| SSO-02 | Activation rejects unusable connections and classifies discovery/client-setting failures honestly. [VERIFIED: .planning/REQUIREMENTS.md] | integration | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/enterprise/activation_test.exs -x` [ASSUMED] | ❌ Wave 0 |

### Sampling Rate

- **Per task commit:** `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test test/sigra/enterprise/connection_config_test.exs test/sigra/enterprise/activation_test.exs` [ASSUMED]
- **Per wave merge:** `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test` [VERIFIED: CLAUDE.md]
- **Phase gate:** Full suite green, plus docs build still clean in CI. [VERIFIED: .github/workflows/ci.yml]

### Wave 0 Gaps

- [ ] `test/sigra/enterprise/connection_config_test.exs` — covers org-bound contract validation for `SSO-01`. [ASSUMED]
- [ ] `test/sigra/enterprise/activation_test.exs` — covers validation/activation failure truth for `SSO-02`. [ASSUMED]
- [ ] `test/sigra/install/enterprise_connection_template_test.exs` — covers generated-host surface emission. [ASSUMED]
- [ ] Discovery/client-setting fixtures or a minimal fake issuer harness — needed to test invalid discovery paths deterministically. [ASSUMED]

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | yes [VERIFIED: .planning/REQUIREMENTS.md] | Reuse Assent OIDC protocol validation and Sigra’s existing auth/session substrate. [CITED: https://hexdocs.pm/assent/Assent.Strategy.OIDC.html] |
| V3 Session Management | no for primary Phase 122 scope; routing/session integration lands mainly in later phases. [VERIFIED: .planning/ROADMAP.md] | Existing session model remains unchanged in this phase. [VERIFIED: .planning/ROADMAP.md] |
| V4 Access Control | yes [VERIFIED: .planning/REQUIREMENTS.md] | Restrict configuration writes to org-admin/owner surfaces through the existing org-scoped settings model. [VERIFIED: test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp_web/live/organization_settings_live.ex] |
| V5 Input Validation | yes [VERIFIED: .planning/REQUIREMENTS.md] | Use `NimbleOptions` and/or Ecto changesets for issuer URL, client settings, and status transitions. [VERIFIED: lib/sigra/organizations.ex] [ASSUMED] |
| V6 Cryptography | yes [CITED: https://hexdocs.pm/assent/Assent.Strategy.OIDC.html] | Do not hand-roll ID token verification; use Assent and existing encrypted-secret posture. [CITED: https://hexdocs.pm/assent/Assent.Strategy.OIDC.html] [VERIFIED: guides/flows/oauth.md] |

### Known Threat Patterns for this Stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Invalid or hostile issuer/discovery URL | Spoofing / Tampering | Validate issuer format, require honest validation before activation, and keep operator-visible failure states. [CITED: https://openid.net/specs/openid-connect-discovery-1_0.html] [ASSUMED] |
| Token substitution between ID token and userinfo | Spoofing | Enforce `sub` equality between ID token and userinfo claims. [CITED: https://openid.net/specs/openid-connect-core-1_0.html] [CITED: https://hexdocs.pm/assent/Assent.Strategy.OIDC.html] |
| Secret leakage in logs/audit rows | Information Disclosure | Follow the existing Sigra rule of never writing tokens/secrets into audit metadata. [VERIFIED: lib/sigra/oauth.ex] |
| Wrong-org configuration mutation | Elevation of Privilege | Reuse org-scoped settings/routing patterns and require organization-bound persistence keys. [VERIFIED: lib/sigra/plug/load_organization_from_slug.ex] [ASSUMED] |

## Sources

### Primary (HIGH confidence)

- `mix hex.info assent` — current Assent version/release date. [VERIFIED: local command]
- `mix hex.info phoenix` — current Phoenix version/release date. [VERIFIED: local command]
- `mix hex.info phoenix_live_view` — current LiveView version/release date. [VERIFIED: local command]
- `mix hex.info ecto` — current Ecto version/release date. [VERIFIED: local command]
- `mix hex.info nimble_options` — current NimbleOptions version/release date. [VERIFIED: local command]
- [https://hexdocs.pm/assent/Assent.Strategy.OIDC.html](https://hexdocs.pm/assent/Assent.Strategy.OIDC.html) — OIDC configuration, discovery fetch, nonce/session params, ID token validation. [CITED: https://hexdocs.pm/assent/Assent.Strategy.OIDC.html]
- [https://hexdocs.pm/assent/Assent.Strategy.html](https://hexdocs.pm/assent/Assent.Strategy.html) — Assent strategy behavior and helper responsibilities. [CITED: https://hexdocs.pm/assent/Assent.Strategy.html]
- [https://openid.net/specs/openid-connect-discovery-1_0.html](https://openid.net/specs/openid-connect-discovery-1_0.html) — discovery endpoint and metadata retrieval rules. [CITED: https://openid.net/specs/openid-connect-discovery-1_0.html]
- [https://openid.net/specs/openid-connect-core-1_0.html](https://openid.net/specs/openid-connect-core-1_0.html) — ID token and `sub`/userinfo consistency rules. [CITED: https://openid.net/specs/openid-connect-core-1_0.html]
- [`mix.exs`](/Users/jon/projects/sigra/mix.exs:1) — repo dependency constraints and optional Assent dependency. [VERIFIED: mix.exs]
- [`lib/sigra/config.ex`](/Users/jon/projects/sigra/lib/sigra/config.ex:591) — current global OAuth config model. [VERIFIED: lib/sigra/config.ex]
- [`lib/sigra/oauth.ex`](/Users/jon/projects/sigra/lib/sigra/oauth.ex:1) — existing OAuth orchestrator and audit/security posture. [VERIFIED: lib/sigra/oauth.ex]
- [`lib/sigra/oauth/strategies/generic.ex`](/Users/jon/projects/sigra/lib/sigra/oauth/strategies/generic.ex:1) — strategy indirection seam. [VERIFIED: lib/sigra/oauth/strategies/generic.ex]
- [`lib/sigra/organizations.ex`](/Users/jon/projects/sigra/lib/sigra/organizations.ex:1) — library-owned config/validation pattern for org features. [VERIFIED: lib/sigra/organizations.ex]
- [`lib/sigra/plug/load_organization_from_slug.ex`](/Users/jon/projects/sigra/lib/sigra/plug/load_organization_from_slug.ex:1) — org-scoped routing and 404-safe resolution pattern. [VERIFIED: lib/sigra/plug/load_organization_from_slug.ex]
- [`test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp_web/live/organization_settings_live.ex`](/Users/jon/projects/sigra/test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp_web/live/organization_settings_live.ex:1) — generated-host organization settings pattern. [VERIFIED: repo fixture]
- [`test/sigra/oauth/assent_oidc_contract_test.exs`](/Users/jon/projects/sigra/test/sigra/oauth/assent_oidc_contract_test.exs:1) — repo proof that `Assent.Strategy.OIDC` is an intentional substrate. [VERIFIED: repo test]

### Secondary (MEDIUM confidence)

- `.planning/research/SUMMARY.md`, `.planning/research/STACK.md`, `.planning/research/ARCHITECTURE.md`, `.planning/research/PITFALLS.md` — repo-local milestone framing and prior synthesis. [VERIFIED: planning docs]

### Tertiary (LOW confidence)

- None. All nontrivial external claims were verified against official docs or local repo state. [VERIFIED: this research pass]

## Metadata

**Confidence breakdown:**

- Standard stack: HIGH - Assent, Phoenix, LiveView, Ecto, and NimbleOptions versions were verified locally and the reuse seams are explicit in the repo. [VERIFIED: local commands] [VERIFIED: repo grep]
- Architecture: MEDIUM-HIGH - The host-vs-library split is well established in the repo, but exact module names and state enums for Phase 122 are still planning assumptions. [VERIFIED: lib/sigra/organizations.ex] [ASSUMED]
- Pitfalls: HIGH - The major failure modes are directly implied by `SSO-01`, `SSO-02`, the current global OAuth config model, and OIDC discovery/validation rules. [VERIFIED: .planning/REQUIREMENTS.md] [CITED: https://hexdocs.pm/assent/Assent.Strategy.OIDC.html]

**Research date:** 2026-05-25  
**Valid until:** 2026-06-24 for repo structure; re-check package releases and official OIDC/Assent docs after that date. [VERIFIED: local commands] [CITED: https://hexdocs.pm/assent/Assent.Strategy.OIDC.html]
