# Phase 92: RBAC seams (B2B-02) - Research

**Researched:** 2026-04-29  
**Domain:** Sigra organization scope propagation, generator seams, and host-owned authorization contracts [VERIFIED: .planning/ROADMAP.md]  
**Confidence:** MEDIUM [VERIFIED: codebase grep]

## User Constraints

- Generated host gets a nullable `role` field on `OrganizationMembership`.
- Add a `Sigra.Authz` behaviour with `can?/3` and a no-op default host implementation.
- Propagate `current_scope.role` when an org membership is active, and keep it nil-safe when not org-active.
- Prepare for Phase 93, which depends on Phase 92 for `:role` and `actor_type` scope extension.
- Library must remain role-agnostic: no opinionated `:owner/:admin/:member` constants in `lib/sigra/`.
- Recipe doc must show how hosts implement their own roles without library changes.

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| B2B-02 | Generated host receives a `role` field on `OrganizationMembership`, a `Sigra.Authz` `can?/3` behaviour, scope-struct `:role` propagation, and a recipe doc demonstrating role-based policy implementation — without the library shipping any opinionated roles. [VERIFIED: .planning/REQUIREMENTS.md] | Shared scope seams already exist in `Sigra.Scope.Hydration`, `Sigra.Plug.PutActiveOrganization`, and the generated `Scope` template; generator ownership already splits core vs organizations features; tests already gate scope template drift, parity, and golden output. [VERIFIED: lib/sigra/scope/hydration.ex] [VERIFIED: lib/sigra/plug/put_active_organization.ex] [VERIFIED: priv/templates/sigra.install/core/scope.ex] [VERIFIED: lib/sigra/install/features/organizations.ex] [VERIFIED: test/sigra/scope/plug_liveview_parity_test.exs] [VERIFIED: test/sigra/install/golden_diff_test.exs] |

## Summary

The safest seam for `scope.role` is not `FetchSession` or `FetchBearer` directly; it is the shared org-enrichment layer that already owns `active_organization` and `membership`. `FetchSession` only creates a user-only scope, `FetchBearer` only creates a token/user scope, and both later depend on either `Sigra.Scope.Hydration.hydrate/3`, `Sigra.Plug.PutActiveOrganization.call/3`, or the generated host scope module’s `put_active_organization/3` to add org-active data. Extending those shared seams keeps session, LiveView, and URL-driven org switching aligned and preserves nil-safe behavior when there is no active org. [VERIFIED: lib/sigra/plug/fetch_session.ex] [VERIFIED: lib/sigra/plug/fetch_bearer.ex] [VERIFIED: lib/sigra/scope/hydration.ex] [VERIFIED: lib/sigra/plug/put_active_organization.ex] [VERIFIED: lib/sigra/plug/load_organization_from_slug.ex] [VERIFIED: priv/templates/sigra.install/core/user_auth.ex]

The generated-host surface is currently not role-agnostic. The organization membership template uses `Ecto.Enum` over `[:owner, :admin, :member]`, the organizations migration defaults membership and invitation roles to `"member"`, and library modules still declare canonical role defaults and validation around `:owner/:admin/:member`. That means a strict reading of the Phase 92 success criterion "no opinionated roles in `lib/sigra/`" is larger than just adding `Sigra.Authz`; it reaches existing organization-management and `RequireMembership` code. The planner should explicitly decide whether Phase 92 only removes opinionated roles from the new RBAC seam, or also de-opinionates the pre-existing org-role APIs in the same phase. [VERIFIED: priv/templates/sigra.install/organizations/organization_membership.ex] [VERIFIED: priv/templates/sigra.install/organizations/migration.exs] [VERIFIED: lib/sigra/organizations.ex] [VERIFIED: lib/sigra/plug/require_membership.ex]

The repo already has the right generator and verification scaffolding for this work. `Sigra.Install.Features.Organizations` owns membership schema and org migration files, `Sigra.Install.Features.Core` owns the generated scope/auth files, docs extras are explicitly enumerated in `mix.exs`, and tests already enforce scope-template shape, renderability, plug/liveview parity, example-app compile truth, and golden drift. Phase 92 should use those existing seams rather than inventing new wiring. [VERIFIED: lib/sigra/install/features/organizations.ex] [VERIFIED: lib/sigra/install/features/core.ex] [VERIFIED: mix.exs] [VERIFIED: test/sigra/install/scope_template_fields_test.exs] [VERIFIED: test/sigra/install/scope_template_invariants_test.exs] [VERIFIED: test/sigra/scope/plug_liveview_parity_test.exs] [VERIFIED: test/sigra/install/template_render_test.exs] [VERIFIED: README.md]

**Primary recommendation:** Put `:role` and future `:actor_type` on the generated scope template and on `Sigra.Scope.build/3`, derive `scope.role` only from `membership.role` inside `Sigra.Scope.Hydration` and `put_active_organization/3` paths, generate a host-owned `Authz` module by mirroring the existing `Sigra.Admin.Policy` pattern, and treat full de-opinionation of existing org role constants as an explicit scope callout before planning. [VERIFIED: priv/templates/sigra.install/core/scope.ex] [VERIFIED: lib/sigra/scope.ex] [VERIFIED: lib/sigra/scope/hydration.ex] [VERIFIED: lib/sigra/admin/policy.ex] [VERIFIED: priv/templates/sigra.install/admin/policy.ex] [VERIFIED: lib/sigra/organizations.ex]

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| User-only scope construction on session auth | API / Backend | Frontend Server (Plug pipeline) | `FetchSession` synthesizes `current_scope` from the session row and host scope module before any org enrichment. [VERIFIED: lib/sigra/plug/fetch_session.ex] |
| Bearer-token scope construction | API / Backend | Frontend Server (Plug pipeline) | `FetchBearer` synthesizes `current_scope` from API token or JWT claims and host scope module before any org enrichment. [VERIFIED: lib/sigra/plug/fetch_bearer.ex] |
| Org-active scope enrichment | Frontend Server (Plug/LiveView runtime) | API / Backend | `Sigra.Scope.Hydration` and `PutActiveOrganization` are the shared seams that add `active_organization` and `membership` to scope for request/live contexts. [VERIFIED: lib/sigra/scope/hydration.ex] [VERIFIED: lib/sigra/plug/put_active_organization.ex] [VERIFIED: lib/sigra/plug/load_active_organization.ex] [VERIFIED: priv/templates/sigra.install/core/user_auth.ex] |
| Host authorization policy decisions (`can?/3`) | API / Backend | — | The requested `Sigra.Authz` behaviour is a host-owned policy contract analogous to `Sigra.Admin.Policy`; it should decide authorization, not the client. [VERIFIED: .planning/ROADMAP.md] [VERIFIED: lib/sigra/admin/policy.ex] |
| Generated host schema/migration for membership role | Database / Storage | API / Backend | The nullable `role` column lives in `organization_memberships` migration and schema templates owned by the organizations installer feature. [VERIFIED: priv/templates/sigra.install/organizations/migration.exs] [VERIFIED: priv/templates/sigra.install/organizations/organization_membership.ex] [VERIFIED: lib/sigra/install/features/organizations.ex] |
| Documentation recipe for opinionated roles | Frontend Server (docs build) | API / Backend | Guides are explicit ExDoc extras and the new recipe must compile with docs warnings-as-errors expectations from the roadmap. [VERIFIED: .planning/ROADMAP.md] [VERIFIED: mix.exs] |

## Project Constraints (from CLAUDE.md)

- Phoenix `1.8+` and Ecto `3.x` are the blessed path, with PostgreSQL as the primary database posture. [CITED: CLAUDE.md]
- Security-sensitive behavior is expected to live in the library, while generated host code stays host-owned and editable. [CITED: CLAUDE.md]
- Dependencies should stay minimal; copy-paste is preferred over adding a new dependency when code is small and stable. [CITED: CLAUDE.md]
- LiveView is supported but optional; login/logout stays on HTTP POST, not LiveView events. [CITED: CLAUDE.md]
- Tests should be comprehensive, AAA-style, flat, and self-contained. [CITED: CLAUDE.md]
- Local `mix test` in this repo requires a live Postgres at `localhost:5432` with `postgres/postgres`. [CITED: CLAUDE.md]

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `Sigra.Scope` helpers | `1.20.0` | Builds reflected host scope structs and worker/audit scopes. [VERIFIED: mix.exs] | It is the only library-side constructor already aware of generated host scope fields. [VERIFIED: lib/sigra/scope.ex] |
| `Sigra.Scope.Hydration` | `1.20.0` | Shared request/liveview org hydration seam. [VERIFIED: mix.exs] | It is explicitly documented as the single place future scope augmentation should extend. [VERIFIED: lib/sigra/scope/hydration.ex] |
| Generated host `Scope` template | `1.20.0` | Concrete `%Scope{}` struct used by session, bearer, plug, and LiveView paths. [VERIFIED: mix.exs] | It is already the authoritative host-side write seam through `put_active_organization/3`. [VERIFIED: priv/templates/sigra.install/core/scope.ex] |
| `Sigra.Plug.PutActiveOrganization` | `1.20.0` | Single authoritative active-org writer for request/session state. [VERIFIED: mix.exs] | It already updates both `sigra_session` and `current_scope` atomically after membership verification. [VERIFIED: lib/sigra/plug/put_active_organization.ex] |
| `Sigra.Install.Features.Organizations` + `Core` | `1.20.0` | Generator ownership for org schema/migration files and core scope/auth files. [VERIFIED: mix.exs] | The repo already separates org-owned and core-owned generated files by feature. [VERIFIED: lib/sigra/install/features/organizations.ex] [VERIFIED: lib/sigra/install/features/core.ex] |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `Sigra.Admin.Policy` pattern | `1.20.0` | Existing host-owned behaviour + generated policy module pattern. [VERIFIED: mix.exs] | Use as the shape to mirror for `Sigra.Authz` and its generated no-op host implementation. [VERIFIED: lib/sigra/admin/policy.ex] [VERIFIED: priv/templates/sigra.install/admin/policy.ex] |
| ExUnit + Mox | `1.20.0 repo test stack` | Unit, render, parity, and installer regression tests. [VERIFIED: mix.exs] [VERIFIED: test/test_helper.exs] | Use for behavior contract tests, scope propagation tests, and generator drift coverage. [VERIFIED: test/sigra/scope/plug_liveview_parity_test.exs] [VERIFIED: test/sigra/install/template_render_test.exs] |
| ExDoc extras list in `mix.exs` | `1.20.0` | Controls which guides compile into docs output. [VERIFIED: mix.exs] | Use when adding `guides/recipes/role-based-access-control.md`; the file must be added to `extras:` to ship and compile. [VERIFIED: mix.exs] |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Shared `Hydration` + `put_active_organization/3` enrichment | Patch `FetchSession` and `FetchBearer` independently | Faster locally, but it creates parity drift because org-active data is not created in the same place for session, bearer, stale-pointer recovery, URL-driven org selection, and LiveView mount. [VERIFIED: lib/sigra/plug/fetch_session.ex] [VERIFIED: lib/sigra/plug/fetch_bearer.ex] [VERIFIED: lib/sigra/scope/hydration.ex] |
| Host-generated `Authz` module mirroring admin-policy pattern | Library-owned default role engine | A library role engine would contradict the phase requirement that hosts define their own role taxonomy and that Sigra not ship opinionated roles. [VERIFIED: .planning/ROADMAP.md] [VERIFIED: lib/sigra/admin/policy.ex] |
| Nullable string role in host schema | Keep `Ecto.Enum [:owner, :admin, :member]` | The existing enum is compile-time opinionated and incompatible with arbitrary host-defined roles plus nullable/no-role memberships. [VERIFIED: priv/templates/sigra.install/organizations/organization_membership.ex] |

**Installation:**
```bash
# No new external package is required for Phase 92; use existing Sigra code paths and templates.
```

## Architecture Patterns

### System Architecture Diagram

```text
session cookie / remember-me       Authorization: Bearer
            |                                |
            v                                v
  Sigra.Plug.FetchSession            Sigra.Plug.FetchBearer
            |                                |
            | user-only scope                | token/user scope
            +---------------+----------------+
                            |
                            v
              generated host Scope.new/1
                            |
          +-----------------+------------------+
          |                                    |
          v                                    v
 Sigra.Plug.LoadActiveOrganization     UserAuth hydrate_scope/2
          |                                    |
          +-----------> Sigra.Scope.Hydration.hydrate/3
                                      |
                                      v
                  scope.active_organization / scope.membership / scope.role
                                      |
                        URL switch / org slug routes
                                      |
                                      v
                 generated Scope.put_active_organization/3
                                      |
                                      v
                 host Authz.can?(action, subject, scope)
```

The key property is that org-active enrichment is centralized after user/token identity resolution, not duplicated inside each auth entry point. [VERIFIED: lib/sigra/plug/fetch_session.ex] [VERIFIED: lib/sigra/plug/fetch_bearer.ex] [VERIFIED: lib/sigra/scope/hydration.ex] [VERIFIED: lib/sigra/plug/load_active_organization.ex] [VERIFIED: priv/templates/sigra.install/core/user_auth.ex]

### Recommended Project Structure

```text
lib/
├── sigra/
│   ├── authz.ex                 # new behaviour only
│   ├── scope.ex                 # reflected scope builder
│   └── scope/hydration.ex       # shared org-active enrichment
priv/templates/sigra.install/
├── core/
│   ├── scope.ex                 # generated scope fields + put_active_organization/3
│   └── authz.ex                 # generated host no-op implementation
└── organizations/
    ├── migration.exs            # nullable membership role column
    └── organization_membership.ex
guides/recipes/
└── role-based-access-control.md
```

This split follows existing feature ownership: scope/auth files are core-owned, while organization schema and migration files are organizations-owned. [VERIFIED: lib/sigra/install/features/core.ex] [VERIFIED: lib/sigra/install/features/organizations.ex]

### Pattern 1: Shared org-active enrichment

**What:** Add `scope.role` at the same layer that already adds `active_organization` and `membership`. [VERIFIED: lib/sigra/scope/hydration.ex]  
**When to use:** Any request/live path where a scope becomes org-active or org-inactive. [VERIFIED: lib/sigra/plug/put_active_organization.ex] [VERIFIED: lib/sigra/plug/load_active_organization.ex]  
**Example:**
```elixir
# Source: lib/sigra/scope/hydration.ex
case Organizations.get_membership(config, user, org) do
  nil ->
    {:error, :not_a_member}

  membership ->
    {:ok, %{scope | active_organization: org, membership: membership}}
end
```

### Pattern 2: Host-owned policy contract

**What:** Define a library behaviour and generate a host-owned implementation stub. [VERIFIED: lib/sigra/admin/policy.ex] [VERIFIED: priv/templates/sigra.install/admin/policy.ex]  
**When to use:** Authorization surfaces where Sigra must remain agnostic and the host owns the actual policy. [VERIFIED: .planning/ROADMAP.md]  
**Example:**
```elixir
# Source: lib/sigra/admin/policy.ex
@callback platform_admin?(scope :: term()) :: boolean()
@callback admin_org_ids(scope :: term()) :: [term()]
```

### Pattern 3: Generated scope write helper

**What:** Keep scope field updates behind host `put_active_organization/3` instead of ad hoc map updates scattered across plugs. [VERIFIED: priv/templates/sigra.install/core/scope.ex]  
**When to use:** Any path that sets or clears the active organization in request state. [VERIFIED: lib/sigra/plug/put_active_organization.ex] [VERIFIED: lib/sigra/plug/load_organization_from_slug.ex]  
**Example:**
```elixir
# Source: priv/templates/sigra.install/core/scope.ex
def put_active_organization(%__MODULE__{} = scope, nil, nil) do
  %{scope | active_organization: nil, membership: nil}
end
```

### Anti-Patterns to Avoid

- **Duplicating `role` assignment in `FetchSession` and `FetchBearer`:** Those modules do not know whether an org membership is active, so adding `role` there risks stale or inconsistent values. [VERIFIED: lib/sigra/plug/fetch_session.ex] [VERIFIED: lib/sigra/plug/fetch_bearer.ex]
- **Keeping generated membership `role` as `Ecto.Enum [:owner, :admin, :member]`:** That hard-codes library opinion into host-owned schema and blocks arbitrary host roles plus nullable state. [VERIFIED: priv/templates/sigra.install/organizations/organization_membership.ex]
- **Updating `active_organization` and `membership` with bare map literals everywhere:** The repo already standardized on `put_active_organization/3` as the single authoritative write path. [VERIFIED: lib/sigra/plug/put_active_organization.ex] [VERIFIED: priv/templates/sigra.install/core/scope.ex]
- **Treating `scope.role` as always present:** Existing org selectors and stale-pointer recovery intentionally produce nil org state; `role` must be nil-safe in exactly those branches. [VERIFIED: lib/sigra/scope/hydration.ex] [VERIFIED: lib/sigra/plug/load_active_organization.ex]

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Session vs bearer vs liveview scope parity | Three independent role-propagation paths | `Sigra.Scope.Hydration`, generated `Scope.put_active_organization/3`, and `PutActiveOrganization.call/3` | Those seams already exist specifically to collapse auth/runtime parity. [VERIFIED: lib/sigra/scope/hydration.ex] [VERIFIED: lib/sigra/plug/put_active_organization.ex] [VERIFIED: test/sigra/scope/plug_liveview_parity_test.exs] |
| Host authorization engine | Library-owned role constants and hierarchy tables | `Sigra.Authz` behaviour + generated host stub + recipe | The roadmap requires host-defined roles with no library role taxonomy. [VERIFIED: .planning/ROADMAP.md] |
| New installer registry or ad hoc file writes | Manual injection outside feature ownership | Existing `Sigra.Install.Features.Core` and `Organizations` file lists | Feature ownership is already encoded and regression-tested by render/syntax/golden tests. [VERIFIED: lib/sigra/install/features/core.ex] [VERIFIED: lib/sigra/install/features/organizations.ex] [VERIFIED: test/sigra/install/template_render_test.exs] |
| Docs surfacing outside ExDoc extras | Unlisted guide file that never ships | Add the recipe under `guides/recipes/` and register it in `mix.exs` extras | The docs build uses an explicit extras list, so unregistered files will not be part of published docs. [VERIFIED: mix.exs] |

**Key insight:** Sigra already has the seam abstraction needed for RBAC; the risky part is not creating one more helper, it is bypassing the shared seams and reintroducing divergent scope truth. [VERIFIED: lib/sigra/scope/hydration.ex] [VERIFIED: lib/sigra/plug/put_active_organization.ex]

## Common Pitfalls

### Pitfall 1: Session/bearer parity drift

**What goes wrong:** `scope.role` is present for browser sessions but missing or differently shaped for bearer-authenticated requests. [VERIFIED: lib/sigra/plug/fetch_session.ex] [VERIFIED: lib/sigra/plug/fetch_bearer.ex]  
**Why it happens:** The user/token identity constructors are separate, so patching only one entry point looks locally correct but misses shared org-active hydration. [VERIFIED: lib/sigra/plug/fetch_session.ex] [VERIFIED: lib/sigra/plug/fetch_bearer.ex]  
**How to avoid:** Add the field to the generated scope struct and update only shared enrichment seams (`Hydration` and `put_active_organization/3`). [VERIFIED: lib/sigra/scope/hydration.ex] [VERIFIED: priv/templates/sigra.install/core/scope.ex] [VERIFIED: lib/sigra/plug/put_active_organization.ex]  
**Warning signs:** `test/sigra/scope/plug_liveview_parity_test.exs` or targeted bearer tests start asserting different maps for equivalent org-active requests. [VERIFIED: test/sigra/scope/plug_liveview_parity_test.exs] [VERIFIED: test/sigra/plug/fetch_bearer_test.exs]

### Pitfall 2: Hidden opinionated-role residue

**What goes wrong:** Phase 92 ships a new `Authz` seam but leaves hard-coded `:owner/:admin/:member` defaults in library or template code, violating the stated milestone boundary. [VERIFIED: lib/sigra/organizations.ex] [VERIFIED: lib/sigra/plug/require_membership.ex] [VERIFIED: priv/templates/sigra.install/organizations/organization_membership.ex]  
**Why it happens:** The repo already predates this milestone with role-aware org APIs and tests. [VERIFIED: lib/sigra/organizations.ex] [VERIFIED: test/sigra/organizations/schema_test.exs]  
**How to avoid:** Treat de-opinionation as an explicit grep-driven audit task, not an implied side effect of adding `Sigra.Authz`. [VERIFIED: .planning/ROADMAP.md] [VERIFIED: codebase grep]  
**Warning signs:** `rg ":owner|:admin|:member" lib/sigra priv/templates/sigra.install/organizations test/example/lib/example/accounts` still shows new or unchanged library hits after the phase. [VERIFIED: codebase grep]

### Pitfall 3: Nil-unsafe role reads

**What goes wrong:** A route or LiveView assumes `scope.role` exists even when `active_organization` is nil, causing crashes or false denies on zero-org, multiple-org, or stale-pointer branches. [VERIFIED: lib/sigra/scope/hydration.ex] [VERIFIED: lib/sigra/plug/load_active_organization.ex]  
**Why it happens:** Existing code already allows nil org-active state by design and only later enforces membership through `RequireMembership`. [VERIFIED: lib/sigra/plug/load_active_organization.ex] [VERIFIED: lib/sigra/plug/require_membership.ex]  
**How to avoid:** Keep `role` nullable on the scope and derive it from `membership` only when org-active branches succeed. [VERIFIED: .planning/ROADMAP.md] [VERIFIED: lib/sigra/scope/hydration.ex]  
**Warning signs:** `current_scope` assertions fail for `/organizations` picker paths or non-org-active worker contexts. [VERIFIED: .planning/ROADMAP.md] [VERIFIED: lib/sigra/scope.ex]

### Pitfall 4: Wrong generator ownership

**What goes wrong:** The new `Authz` file lands in the wrong feature, so `--no-organizations` or example-app rendering starts failing unexpectedly. [VERIFIED: lib/sigra/install/features/core.ex] [VERIFIED: lib/sigra/install/features/organizations.ex]  
**Why it happens:** Core and organizations feature ownership is explicit and tested, but Phase 92 touches both surfaces. [VERIFIED: lib/sigra/install/features/core.ex] [VERIFIED: lib/sigra/install/features/organizations.ex]  
**How to avoid:** Decide up front whether `Authz` is always generated as a core contract or only when organizations are enabled, and align files, tests, and docs to that choice. [VERIFIED: lib/sigra/install/features/core.ex] [VERIFIED: lib/sigra/install/features/organizations.ex]  
**Warning signs:** `test/sigra/install/template_render_test.exs`, `features/organizations_test.exs`, or the golden fixture starts failing on missing/extra file sets. [VERIFIED: test/sigra/install/template_render_test.exs] [VERIFIED: test/sigra/install/features/organizations_test.exs] [VERIFIED: test/sigra/install/golden_diff_test.exs]

## Code Examples

Verified patterns from the codebase:

### Shared scope build helper

```elixir
# Source: lib/sigra/scope.ex
struct(scope_module,
  user: user,
  active_organization: Keyword.get(opts, :active_organization),
  membership: Keyword.get(opts, :membership),
  impersonating_from: Keyword.get(opts, :impersonating_from)
)
```

This is the right place to reserve additional scope fields like `:role` and `:actor_type` so worker/audit scope construction and generated-scope reflection stay aligned. [VERIFIED: lib/sigra/scope.ex]

### Host-owned behavior pattern

```elixir
# Source: priv/templates/sigra.install/admin/policy.ex
@behaviour Sigra.Admin.Policy

@impl true
def platform_admin?(scope) do
  _ = scope
  false
end
```

Use this exact pattern for a generated `MyApp.Authz` default implementation that returns `true` from `can?/3` and pushes real policy decisions into host code. [VERIFIED: priv/templates/sigra.install/admin/policy.ex]

### Existing org-active write seam

```elixir
# Source: lib/sigra/plug/put_active_organization.ex
case Organizations.get_membership(config, scope.user, org) do
  nil ->
    {:error, :not_a_member}

  membership ->
    new_scope = scope_module.put_active_organization(scope, org, membership)
```

If `scope.role` is added, this call chain is one of the two places that must populate it. [VERIFIED: lib/sigra/plug/put_active_organization.ex]

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Per-entry-point org scope logic | Shared `Sigra.Scope.Hydration.hydrate/3` plus host `put_active_organization/3` | Phase 14-16 code now in repo head. [VERIFIED: lib/sigra/scope/hydration.ex] [VERIFIED: lib/sigra/plug/put_active_organization.ex] | Phase 92 should extend the shared seam, not add another role propagation path. [VERIFIED: codebase grep] |
| `user_auth` on-mount injection patching | Organizations on-mount logic baked directly into `core/user_auth.ex` and feature comments warn against scattered injection | Phase 24.1. [VERIFIED: lib/sigra/install/features/organizations.ex] [VERIFIED: priv/templates/sigra.install/core/user_auth.ex] | Phase 92 should prefer template edits over new function-group injection surgery. [VERIFIED: lib/sigra/install/features/organizations.ex] |
| Example app as informal reference | Example app plus golden fixture are explicit generated-output truth | Current README and tests. [VERIFIED: README.md] [VERIFIED: test/sigra/install/golden_diff_test.exs] | Any new `Authz` file or scope field must update example output and golden snapshots. [VERIFIED: README.md] |

**Deprecated/outdated:**

- Relying on the library’s canonical role universe `[:owner, :admin, :member]` as the RBAC seam is outdated relative to the Phase 92 goal because the milestone now requires host-owned role taxonomies. [VERIFIED: lib/sigra/plug/require_membership.ex] [VERIFIED: .planning/ROADMAP.md]

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Reserving `:actor_type` on the generated scope in Phase 92, even if Phase 92 does not fully consume it yet, is the cleanest prep for Phase 93. [ASSUMED] | Summary / Primary recommendation | If Phase 93 wants a different default or field shape, Phase 92 could create unnecessary churn in scope templates and tests. |

## Open Questions (RESOLVED)

1. **Does Phase 92 de-opinionate only the new RBAC seam, or all pre-existing org-role constants in `lib/sigra/`?**
   - Resolution: Phase 92 planning must satisfy the broad current roadmap claim, not a seam-only subset. The de-opinionation audit therefore covers the relevant RBAC surfaces across `lib/sigra/`, including existing organization and membership-gating code paths, so Phase 92 can honestly attest that Sigra itself ships zero opinionated roles. [VERIFIED: .planning/ROADMAP.md] [VERIFIED: codebase grep]
   - Planning impact: Plans must widen grep/done criteria beyond the new seam files and treat any surviving `:owner/:admin/:member` taxonomy constants in `lib/sigra/` as in-phase work, not deferred cleanup. [VERIFIED: lib/sigra/organizations.ex] [VERIFIED: lib/sigra/plug/require_membership.ex]

2. **Should the generated `Authz` module be core-owned or organizations-owned?**
   - Resolution: The generated `Authz` file is core-owned because it is a contract/scope-template seam that belongs with generated auth/scope primitives. Organizations continues to own membership storage, migrations, and wrapper integration. [VERIFIED: lib/sigra/install/features/core.ex] [VERIFIED: lib/sigra/install/features/organizations.ex]
   - Planning impact: Generator verification must explicitly cover feature ownership drift and second-run idempotency for the new core-vs-organizations split. [VERIFIED: test/sigra/install/features/coverage_test.exs] [VERIFIED: test/sigra/install/idempotency_test.exs]

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | ExUnit with Mox mocks. [VERIFIED: mix.exs] [VERIFIED: test/test_helper.exs] |
| Config file | `test/test_helper.exs`. [VERIFIED: test/test_helper.exs] |
| Quick run command | `MIX_ENV=test mix test test/sigra/authz_test.exs test/sigra/plug/put_active_organization_test.exs test/sigra/scope/plug_liveview_parity_test.exs test/sigra/install/scope_template_fields_test.exs test/sigra/install/scope_template_invariants_test.exs test/sigra/install/features/coverage_test.exs test/sigra/install/features/organizations_test.exs test/sigra/install/idempotency_test.exs test/sigra/install/template_render_test.exs test/sigra/install/template_syntax_test.exs test/sigra/install/golden_diff_test.exs`. [VERIFIED: .planning/ROADMAP.md] [VERIFIED: test/sigra/plug/put_active_organization_test.exs] [VERIFIED: test/sigra/scope/plug_liveview_parity_test.exs] |
| Full suite command | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost MIX_ENV=test mix test`. [CITED: CLAUDE.md] [VERIFIED: test/test_helper.exs] |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| B2B-02 | Scope template grows nil-safe `:role` and likely reserved `:actor_type` without breaking generated struct contract. [VERIFIED: .planning/ROADMAP.md] | unit/render | `MIX_ENV=test mix test test/sigra/install/scope_template_fields_test.exs test/sigra/install/scope_template_invariants_test.exs test/sigra/install/template_render_test.exs` | ✅ existing scaffolding; assertions need extension. [VERIFIED: test/sigra/install/scope_template_fields_test.exs] [VERIFIED: test/sigra/install/scope_template_invariants_test.exs] [VERIFIED: test/sigra/install/template_render_test.exs] |
| B2B-02 | Session/plug/liveview/org-switch seams propagate `scope.role` only when org-active. [VERIFIED: .planning/ROADMAP.md] | unit/integration | `MIX_ENV=test mix test test/sigra/plug/put_active_organization_test.exs test/sigra/scope/plug_liveview_parity_test.exs test/sigra/scope/hydration_test.exs` | ✅ existing scaffolding; new assertions needed. [VERIFIED: test/sigra/plug/put_active_organization_test.exs] [VERIFIED: test/sigra/scope/plug_liveview_parity_test.exs] [VERIFIED: test/sigra/scope/hydration_test.exs] |
| B2B-02 | Generated host membership schema/migration become nullable-role and host-authz aware. [VERIFIED: .planning/ROADMAP.md] | generator/golden | `MIX_ENV=test mix test test/sigra/install/features/coverage_test.exs test/sigra/install/features/organizations_test.exs test/sigra/install/idempotency_test.exs test/sigra/install/golden_diff_test.exs test/sigra/install/template_render_test.exs test/sigra/install/template_syntax_test.exs` | ✅ existing scaffolding; new file and snapshot expectations needed. [VERIFIED: test/sigra/install/features/coverage_test.exs] [VERIFIED: test/sigra/install/features/organizations_test.exs] [VERIFIED: test/sigra/install/idempotency_test.exs] [VERIFIED: test/sigra/install/golden_diff_test.exs] [VERIFIED: test/sigra/install/template_render_test.exs] [VERIFIED: test/sigra/install/template_syntax_test.exs] |
| B2B-02 | New `Sigra.Authz` behaviour contract stays role-taxonomy agnostic. [VERIFIED: .planning/ROADMAP.md] | unit | `MIX_ENV=test mix test test/sigra/authz_test.exs` | ❌ Wave 0 gap. [VERIFIED: .planning/ROADMAP.md] |
| B2B-02 | Example/generated host compiles and docs recipe is included. [VERIFIED: .planning/ROADMAP.md] | compile/docs/manual+automated | `MIX_ENV=test mix test test/example/test/example_web/smoke/install_compile_test.exs` and `mix docs --warnings-as-errors` | ✅ example compile test exists; docs command exists but recipe file is missing. [VERIFIED: test/example/test/example_web/smoke/install_compile_test.exs] [VERIFIED: mix.exs] [VERIFIED: codebase grep] |

### Sampling Rate

- **Per task commit:** Run the quick targeted command bundle above, including ownership/idempotency plus render/syntax coverage when generator files change. [VERIFIED: test/sigra/install/features/coverage_test.exs] [VERIFIED: test/sigra/install/idempotency_test.exs] [VERIFIED: test/sigra/install/template_render_test.exs] [VERIFIED: test/sigra/install/template_syntax_test.exs]
- **Per wave merge:** Run root targeted installer/scope suite and example-app compile smoke. [VERIFIED: README.md] [VERIFIED: test/example/test/example_web/smoke/install_compile_test.exs]
- **Phase gate:** Root full suite green, example generated app compile green, golden drift stable, and `mix docs --warnings-as-errors` green after adding the recipe. [VERIFIED: .planning/ROADMAP.md] [VERIFIED: mix.exs]

### Wave 0 Gaps

- [ ] `test/sigra/authz_test.exs` — new behavior contract and default host implementation coverage. [VERIFIED: .planning/ROADMAP.md]
- [ ] Extend `test/sigra/install/scope_template_fields_test.exs` for `:role` and any reserved `:actor_type` field. [VERIFIED: test/sigra/install/scope_template_fields_test.exs]
- [ ] Extend `test/sigra/plug/put_active_organization_test.exs` and `test/sigra/scope/plug_liveview_parity_test.exs` for `scope.role` propagation and nil clearing. [VERIFIED: test/sigra/plug/put_active_organization_test.exs] [VERIFIED: test/sigra/scope/plug_liveview_parity_test.exs]
- [ ] Add docs coverage for `guides/recipes/role-based-access-control.md` to the explicit `mix.exs` extras list. [VERIFIED: mix.exs]

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | Phase 92 does not change credential verification directly; it changes post-auth scope and authz seams. [VERIFIED: .planning/ROADMAP.md] |
| V3 Session Management | yes | Keep org-active role enrichment on existing session/liveview state seams without adding new session writes. [VERIFIED: lib/sigra/plug/put_active_organization.ex] [VERIFIED: lib/sigra/plug/load_active_organization.ex] |
| V4 Access Control | yes | Host-owned `Sigra.Authz.can?/3` contract and nil-safe role propagation are access-control surfaces. [VERIFIED: .planning/ROADMAP.md] |
| V5 Input Validation | yes | Existing generator and plug tests validate scope/template invariants and protect against bad role assumptions. [VERIFIED: test/sigra/install/template_render_test.exs] [VERIFIED: lib/sigra/plug/require_membership.ex] |
| V6 Cryptography | no | No new crypto primitives are introduced in this phase. [VERIFIED: .planning/ROADMAP.md] |

### Known Threat Patterns for this stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Role confusion between session and bearer paths | Elevation of Privilege | Use the shared scope enrichment seams rather than duplicating role population in auth entry points. [VERIFIED: lib/sigra/plug/fetch_session.ex] [VERIFIED: lib/sigra/plug/fetch_bearer.ex] [VERIFIED: lib/sigra/scope/hydration.ex] |
| Hard-coded role hierarchy leaks into library | Tampering / Elevation of Privilege | Keep authorization semantics in host `Authz` code and audit library/template grep for `:owner/:admin/:member` residue. [VERIFIED: .planning/ROADMAP.md] [VERIFIED: codebase grep] |
| Nil org-active state treated as authorized role | Elevation of Privilege | Preserve explicit nil branches in hydrator and load-active-org recovery; only derive `role` from a real membership. [VERIFIED: lib/sigra/scope/hydration.ex] [VERIFIED: lib/sigra/plug/load_active_organization.ex] |

## Sources

### Primary (HIGH confidence)

- `.planning/ROADMAP.md` - Phase 92 and Phase 93 dependency/goal/success criteria. [VERIFIED: .planning/ROADMAP.md]
- `.planning/REQUIREMENTS.md` - `B2B-02` requirement wording and out-of-scope note on built-in opinionated roles. [VERIFIED: .planning/REQUIREMENTS.md]
- `.planning/STATE.md` - milestone and phase positioning. [VERIFIED: .planning/STATE.md]
- `CLAUDE.md` - project constraints, testing expectations, and local Postgres requirement. [CITED: CLAUDE.md]
- `lib/sigra/scope.ex` - reflected scope builder contract. [VERIFIED: lib/sigra/scope.ex]
- `lib/sigra/scope/hydration.ex` - shared org-active enrichment seam and parity contract. [VERIFIED: lib/sigra/scope/hydration.ex]
- `lib/sigra/plug/fetch_session.ex` - session user-only scope synthesis. [VERIFIED: lib/sigra/plug/fetch_session.ex]
- `lib/sigra/plug/fetch_bearer.ex` - bearer scope synthesis and current extra fields. [VERIFIED: lib/sigra/plug/fetch_bearer.ex]
- `lib/sigra/plug/put_active_organization.ex` - authoritative active-org write seam. [VERIFIED: lib/sigra/plug/put_active_organization.ex]
- `lib/sigra/plug/load_active_organization.ex` and `lib/sigra/plug/load_organization_from_slug.ex` - hydration and URL-driven scope updates. [VERIFIED: lib/sigra/plug/load_active_organization.ex] [VERIFIED: lib/sigra/plug/load_organization_from_slug.ex]
- `lib/sigra/organizations.ex` and `lib/sigra/plug/require_membership.ex` - existing opinionated role defaults in library code. [VERIFIED: lib/sigra/organizations.ex] [VERIFIED: lib/sigra/plug/require_membership.ex]
- `priv/templates/sigra.install/core/scope.ex`, `core/user_auth.ex` - generated scope struct and liveview hydration path. [VERIFIED: priv/templates/sigra.install/core/scope.ex] [VERIFIED: priv/templates/sigra.install/core/user_auth.ex]
- `priv/templates/sigra.install/organizations/organization_membership.ex`, `organizations/migration.exs`, `organizations/organizations.ex` - current host role schema/migration/wrapper output. [VERIFIED: priv/templates/sigra.install/organizations/organization_membership.ex] [VERIFIED: priv/templates/sigra.install/organizations/migration.exs] [VERIFIED: priv/templates/sigra.install/organizations/organizations.ex]
- `lib/sigra/install/features/core.ex`, `lib/sigra/install/features/organizations.ex` - file ownership and migration ownership. [VERIFIED: lib/sigra/install/features/core.ex] [VERIFIED: lib/sigra/install/features/organizations.ex]
- `lib/sigra/admin/policy.ex`, `priv/templates/sigra.install/admin/policy.ex` - existing behavior + generated host policy pattern to mirror. [VERIFIED: lib/sigra/admin/policy.ex] [VERIFIED: priv/templates/sigra.install/admin/policy.ex]
- `mix.exs` - repo version, ExDoc extras, and test stack. [VERIFIED: mix.exs]
- `test/sigra/scope/plug_liveview_parity_test.exs`, `test/sigra/plug/put_active_organization_test.exs`, `test/sigra/install/*`, `test/example/*` - regression surfaces and compile/golden expectations. [VERIFIED: test/sigra/scope/plug_liveview_parity_test.exs] [VERIFIED: test/sigra/plug/put_active_organization_test.exs] [VERIFIED: test/sigra/install/golden_diff_test.exs] [VERIFIED: test/example/test/example_web/smoke/install_compile_test.exs]

### Secondary (MEDIUM confidence)

- `guides/recipes/multi-tenant.md` - current documentation posture around organization scope and membership semantics. [VERIFIED: guides/recipes/multi-tenant.md]
- `README.md` - example app and generated-output truth description. [VERIFIED: README.md]
- `.planning/phases/91-org-level-mfa-enforcement-b2b-01/91-CONTEXT.md` and `91-VERIFICATION.md` - latest adjacent-phase precedent for scope extension, verification style, and generated-host gating. [VERIFIED: .planning/phases/91-org-level-mfa-enforcement-b2b-01/91-CONTEXT.md] [VERIFIED: .planning/phases/91-org-level-mfa-enforcement-b2b-01/91-VERIFICATION.md]

### Tertiary (LOW confidence)

- None. All substantive claims above were verified against the current repo or cited from project instructions. [VERIFIED: codebase grep]

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - the relevant stack is mostly existing repo-local modules and generator ownership, all directly inspectable. [VERIFIED: lib/sigra/scope.ex] [VERIFIED: lib/sigra/install/features/core.ex] [VERIFIED: lib/sigra/install/features/organizations.ex]
- Architecture: HIGH - the shared scope seams and ownership boundaries are explicit in code and tests. [VERIFIED: lib/sigra/scope/hydration.ex] [VERIFIED: lib/sigra/plug/put_active_organization.ex] [VERIFIED: test/sigra/scope/plug_liveview_parity_test.exs]
- Pitfalls: MEDIUM - the current residue of hard-coded role taxonomy is verified, but the exact de-opinionation scope for Phase 92 still needs a locked decision. [VERIFIED: lib/sigra/organizations.ex] [VERIFIED: lib/sigra/plug/require_membership.ex]

**Research date:** 2026-04-29  
**Valid until:** 2026-05-29 for repo-structure claims; revisit sooner if Phase 91/93-adjacent scope code changes land first. [VERIFIED: .planning/STATE.md]
