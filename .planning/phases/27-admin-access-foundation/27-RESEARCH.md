# Phase 27: Admin Access Foundation - Research

**Researched:** 2026-04-16 [VERIFIED: 27-CONTEXT.md]
**Domain:** Phoenix/LiveView admin installation, scope hydration, and server-side admin enforcement on Sigra's hybrid lib+generator architecture [VERIFIED: 27-CONTEXT.md][VERIFIED: codebase grep]
**Confidence:** HIGH [VERIFIED: 27-CONTEXT.md][VERIFIED: codebase grep][CITED: https://hexdocs.pm/phoenix_live_view/security-model.html]

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01:** Admin ships inside the main `sigra` package as a new first-class installer feature, enabled by default and disabled with `--no-admin`. Do not split Phase 27 into a separate `sigra_admin` package. [VERIFIED: 27-CONTEXT.md]
- **D-02:** Admin follows the existing feature-manifest pattern as `Sigra.Install.Features.Admin`, with isolated templates, injections, migrations, and post-install instructions parallel to organizations and passkeys. [VERIFIED: 27-CONTEXT.md]
- **D-03:** The long-lived admin runtime stays library-owned wherever Sigra needs stable security, scoping, and upgrade behavior. Generate only thin host-owned boundary files: router mount/wiring, policy module, and small configuration/chrome hooks where needed. [VERIFIED: 27-CONTEXT.md]
- **D-04:** Do not make the admin surface primarily generated host code. Generated-host-heavy admin would create drift, weaken upgradeability, and push security-sensitive scoping logic out of the library. [VERIFIED: 27-CONTEXT.md]
- **D-05:** Admin access is always explicit and host-owned. Sigra must never infer admin access from signup order, first user, first org owner, email domain, or any hidden default. [VERIFIED: 27-CONTEXT.md]
- **D-06:** Generate a small host policy module such as `MyApp.SigraAdminPolicy` behind a clear behaviour. The contract should stay intentionally small. [VERIFIED: 27-CONTEXT.md]
- **D-07:** The policy contract should require `platform_admin?(scope)` and support `admin_org_ids(scope)` for org-admin scope resolution. [VERIFIED: 27-CONTEXT.md]
- **D-08:** Sigra may provide a helper for the common case where org-admin authority is derived from Sigra organization memberships with roles in `[:owner, :admin]`, but this remains helper behavior, not an implicit default magic path. [VERIFIED: 27-CONTEXT.md]
- **D-09:** Platform-admin and org-admin are distinct concepts. Do not collapse them into one boolean or assume org admin implies global access. [VERIFIED: 27-CONTEXT.md]
- **D-10:** Admin scope is explicit in the URL and request lifecycle. Use a global admin entry point at `/admin` and organization-scoped admin entry points at `/admin/organizations/:org`. [VERIFIED: 27-CONTEXT.md]
- **D-11:** Platform admins may intentionally enter either global or organization-scoped admin views. Org admins may enter only organization-scoped admin views for organizations in `admin_org_ids(scope)`. [VERIFIED: 27-CONTEXT.md]
- **D-12:** URL org scope is the authorization source of truth for admin pages. Session state may remember the last admin org only as a redirect convenience, never as the actual authorization decision. [VERIFIED: 27-CONTEXT.md]
- **D-13:** Sigra should resolve a request-local admin scope struct, distinct from but derived from `current_scope`, so admin routes, LiveViews, queries, exports, and mutations all enforce the same resolved scope. [VERIFIED: 27-CONTEXT.md]
- **D-14:** Server-side enforcement is mandatory at every boundary: route/pipeline entry, LiveView mount, context/query layer, export layer, and mutation endpoints. UI visibility is never the protection boundary. [VERIFIED: 27-CONTEXT.md]
- **D-15:** Org-admin surfaces must be structurally scoped queries, not global queries filtered in templates or LiveViews after the fact. [VERIFIED: 27-CONTEXT.md]
- **D-16:** Use a hybrid admin shell: a sticky top scope bar plus conventional admin navigation. This is the default shell contract for both desktop and mobile. [VERIFIED: 27-CONTEXT.md]
- **D-17:** The sticky scope bar must always show `Admin`, the active scope (`Global` or the active organization name), and any special session state that changes action meaning. [VERIFIED: 27-CONTEXT.md]
- **D-18:** Desktop uses a grouped sidebar for durable wayfinding. Mobile keeps 3-5 high-frequency destinations in a bottom nav and puts the rest behind a drawer/menu. Do not rely on a hamburger-only shell for all mobile navigation. [VERIFIED: 27-CONTEXT.md]
- **D-19:** Page headers should show the current object/action, not repeat the scope as the only context cue. Scope must already be visible in the persistent shell. [VERIFIED: 27-CONTEXT.md]
- **D-20:** Global and organization-destructive actions must never be visually mixed in a way that blurs scope. The shell and page composition should make cross-org vs single-org action context obvious before confirmation. [VERIFIED: 27-CONTEXT.md]
- **D-21:** Stay fully idiomatic to Phoenix/Plug/Ecto/LiveView. Reuse router scopes, pipelines, `live_session`, `on_mount`, current scope hydration, and server-rendered LiveView shells rather than inventing a parallel framework. [VERIFIED: 27-CONTEXT.md]
- **D-22:** Reuse the existing organizations and scope plumbing as the foundation for admin org scoping. Phase 27 should extend the system incrementally, not fork the scope model. [VERIFIED: 27-CONTEXT.md]
- **D-23:** Keep admin concerns in dedicated modules and feature boundaries. Do not leak admin-specific behavior into unrelated feature modules or the core installer path. [VERIFIED: 27-CONTEXT.md]

### Claude's Discretion
- Exact module names under `Sigra.Admin.*` [VERIFIED: 27-CONTEXT.md]
- Exact admin scope struct field names, as long as the split between global vs org-scoped admin context remains explicit [VERIFIED: 27-CONTEXT.md]
- Exact sidebar group names and iconography [VERIFIED: 27-CONTEXT.md]
- Exact mobile bottom-nav destination set, as long as it prioritizes the highest-frequency operator destinations [VERIFIED: 27-CONTEXT.md]
- Exact branding hook API, provided it stays basic and does not grow into a theming engine [VERIFIED: 27-CONTEXT.md]

### Deferred Ideas (OUT OF SCOPE)
- Separate `sigra_admin` package or monorepo package boundary [VERIFIED: 27-CONTEXT.md]
- Full theming engine or runtime admin shell customization UI [VERIFIED: 27-CONTEXT.md]
- Session-owned admin scope as the primary authorization source [VERIFIED: 27-CONTEXT.md]
- Any "first admin" bootstrap magic beyond explicit documentation or tooling [VERIFIED: 27-CONTEXT.md]
- Broader role/permission management beyond the small admin policy contract [VERIFIED: 27-CONTEXT.md]
- Rich admin information architecture beyond what Phase 27 needs to establish the shell and scope contracts [VERIFIED: 27-CONTEXT.md]
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| ADMIN-01 | Default-on admin install with `--no-admin` opt-out using the existing feature-manifest pattern. [VERIFIED: REQUIREMENTS.md] | Implement admin as an additive installer feature alongside core/organizations/passkeys, extending `@features` and installer switches without changing runner semantics. [VERIFIED: codebase grep] |
| ADMIN-02 | Explicit host policy contract for platform-admin and org-admin access; no inferred admin defaults. [VERIFIED: REQUIREMENTS.md] | Generate one small host-owned policy behaviour seam and keep all authorization decisions library-invoked but host-supplied. [VERIFIED: 27-CONTEXT.md][VERIFIED: codebase grep] |
| ADMIN-03 | Admin routes, LiveViews, exports, and mutations enforce admin access server-side. [VERIFIED: REQUIREMENTS.md] | Mirror Plug + `live_session`/`on_mount` parity already used for organization scoping because LiveView navigations do not pass through the plug pipeline. [VERIFIED: codebase grep][CITED: https://hexdocs.pm/phoenix_live_view/security-model.html] |
| ADMIN-04 | Org admins stay inside allowed organization scope; platform admins may access cross-org views intentionally. [VERIFIED: REQUIREMENTS.md] | Reuse URL-based slug resolution and structural query scoping patterns from organizations, but derive allowed orgs from the admin policy instead of membership alone. [VERIFIED: 27-CONTEXT.md][VERIFIED: codebase grep] |
| ADMIN-05 | Admin chrome makes global vs organization scope visible. [VERIFIED: REQUIREMENTS.md] | Extend the existing generated shell/component pattern in `layouts.ex` and `org_switcher.ex` with a dedicated admin shell contract from `27-UI-SPEC.md`. [VERIFIED: 27-UI-SPEC.md][VERIFIED: codebase grep] |
</phase_requirements>

## Summary

Phase 27 should be planned as an extension of three existing Sigra seams, not a new subsystem: the additive installer feature model, the `current_scope` hydration model, and the Phoenix router/LiveView boundary model. The codebase already has a proven pattern for default-on optional features in `Sigra.Install.Features.Organizations`, URL-owned scope resolution in `Sigra.Plug.LoadOrganizationFromSlug`, and Plug/LiveView parity in `ExampleWeb.UserAuth` plus `Sigra.LiveView.OrganizationScope`. [VERIFIED: codebase grep]

The most important planning constraint is that admin authorization cannot live in chrome or generated host pages. Phoenix LiveView explicitly requires authorization on mount because client-side navigations inside a `live_session` bypass the plug pipeline, and Sigra's own org-scoping work already compensates for that with parallel Plug and `on_mount` hydration. Phase 27 should reuse that pattern for admin scope resolution, with a library-owned admin scope resolver plus thin host-owned policy and router wiring. [VERIFIED: 27-CONTEXT.md][VERIFIED: codebase grep][CITED: https://hexdocs.pm/phoenix_live_view/Phoenix.LiveView.Router.html][CITED: https://hexdocs.pm/phoenix_live_view/security-model.html]

The second planning risk is route topology. LiveView's router docs state that `live_session` does not work with `forward`, so the admin surface should be mounted through normal router scopes and `live_session` blocks, not a forwarded sub-router or dashboard-style mount. That fits the locked decision to stay idiomatic to Phoenix scopes/pipelines and keeps admin auth, org slug loading, and shell layout boundaries visible in the host router. [VERIFIED: 27-CONTEXT.md][CITED: https://hexdocs.pm/phoenix_live_view/Phoenix.LiveView.Router.html]

**Primary recommendation:** Plan Phase 27 as one new additive installer feature plus one library-owned admin enforcement stack that is invoked from both Plug and LiveView, with URL-derived admin scope as the single source of truth. [VERIFIED: 27-CONTEXT.md][VERIFIED: codebase grep]

## Project Constraints (from CLAUDE.md)

- Phoenix 1.8+ and Ecto 3.x are the blessed path; Plug compatibility is secondary to DX. [VERIFIED: CLAUDE.md]
- PostgreSQL is primary; MySQL/SQLite support stays conditional in migrations. [VERIFIED: CLAUDE.md]
- Security defaults are OWASP-aligned, tokens are HMAC-protected, and enumeration prevention is required. [VERIFIED: CLAUDE.md]
- Prefer minimal transitive dependencies and copy-paste only when code is small and stable. [VERIFIED: CLAUDE.md]
- LiveView is supported but optional; core flows must still respect HTTP boundaries. [VERIFIED: CLAUDE.md]
- Testing should stay comprehensive, flat, and self-contained. [VERIFIED: CLAUDE.md]
- Local `mix test` requires Postgres on `localhost:5432` with `postgres/postgres`. [VERIFIED: CLAUDE.md][VERIFIED: local env]

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Default-on admin installer wiring | Backend build/generator | Host app files | Installer features, templates, injections, and migration timestamps are owned by the library runner; generated files are thin seams. [VERIFIED: codebase grep] |
| Platform/org admin policy decision | Host app backend | Library behaviour | The decision must be explicit and host-owned, but Sigra invokes it through a small contract. [VERIFIED: 27-CONTEXT.md] |
| Admin route entry enforcement | Phoenix router / Plug pipeline | LiveView mount | Regular requests are gated in plugs; LiveViews need matching mount checks because `navigate` skips plugs. [VERIFIED: codebase grep][CITED: https://hexdocs.pm/phoenix_live_view/security-model.html] |
| Admin scope resolution from URL | Backend request lifecycle | Session redirect helper | The URL is the auth source of truth; session memory can only assist redirects after revalidation. [VERIFIED: 27-CONTEXT.md] |
| Org-scoped admin query enforcement | Context/query layer | Repo defense-in-depth | Sigra conventions require structural org scoping in queries, with `prepare_query/3` as a secondary guard. [VERIFIED: CONVENTIONS.md][VERIFIED: codebase grep] |
| Admin shell and visible scope chrome | LiveView/app shell | Generated host components | The admin shell should extend current Phoenix layout conventions and remain visible across admin pages. [VERIFIED: 27-UI-SPEC.md][VERIFIED: codebase grep] |

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Phoenix | 1.8.5 [VERIFIED: mix.lock][VERIFIED: hex package info] | Router scopes, pipelines, verified routes, and shell integration for the admin surface. [VERIFIED: codebase grep] | The repo already uses router scopes and generated scope structs, and Phoenix 1.8 docs explicitly support scoped resources and separate scope modules. [VERIFIED: codebase grep][CITED: https://hexdocs.pm/phoenix/scopes.html] |
| Phoenix LiveView | 1.1.28 [VERIFIED: test/example/mix.lock][VERIFIED: hex package info] | `live_session`, `on_mount`, and admin shell pages. [VERIFIED: codebase grep] | The current example app already relies on router-level `on_mount` hooks; official docs require mount-time authorization for LiveViews. [VERIFIED: codebase grep][CITED: https://hexdocs.pm/phoenix_live_view/security-model.html] |
| Ecto | 3.13.5 [VERIFIED: mix.lock][VERIFIED: hex package info] | Structural scope-safe queries and migration support for installer output. [VERIFIED: codebase grep] | Existing org-scope enforcement and Repo defense-in-depth already rely on Ecto query composition. [VERIFIED: CONVENTIONS.md][VERIFIED: codebase grep] |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Sigra installer feature system | Internal current code [VERIFIED: codebase grep] | Add admin as a first-class optional feature with isolated files/injections/migrations. [VERIFIED: codebase grep] | Use for all admin scaffolding and opt-out behavior. [VERIFIED: 27-CONTEXT.md] |
| Existing generated scope struct + hydrators | Internal current code [VERIFIED: codebase grep] | Derive admin scope from `current_scope` instead of inventing a parallel auth object. [VERIFIED: 27-CONTEXT.md] | Use whenever admin enforcement needs user, org, or impersonation context. [VERIFIED: codebase grep] |
| Existing Tailwind/daisyUI HEEx shell substrate | Internal current code [VERIFIED: 27-UI-SPEC.md][VERIFIED: codebase grep] | Admin scope bar, sidebar, bottom nav, and denied/empty states. [VERIFIED: 27-UI-SPEC.md] | Use for Phase 27 shell chrome only; defer tables and analytics panels. [VERIFIED: 27-UI-SPEC.md] |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Router scopes + `live_session` | `forward "/admin", ...` | Rejected because `live_session` does not work with `forward`, which would break the standard LiveView auth boundary for admin pages. [CITED: https://hexdocs.pm/phoenix_live_view/Phoenix.LiveView.Router.html] |
| Library-owned admin enforcement with thin host seams | Mostly generated host admin runtime | Rejected by locked decisions because drift and security-sensitive logic would move out of the library. [VERIFIED: 27-CONTEXT.md] |
| URL-derived admin scope | Session-owned admin scope | Rejected by locked decisions because session state may only help redirects, not authorization. [VERIFIED: 27-CONTEXT.md] |

**Installation:**
```bash
# No new external dependencies are recommended for Phase 27.
# Extend the existing installer feature list and switches instead.
```

**Version verification:** `mix.lock` and `mix hex.info` confirm Phoenix `1.8.5`, Phoenix LiveView `1.1.28`, and Ecto `3.13.5` in the current workspace. [VERIFIED: mix.lock][VERIFIED: hex package info]

## Architecture Patterns

### System Architecture Diagram
```text
mix sigra.install
  -> feature list includes Admin
  -> Admin templates/injections/migrations generated
  -> host router mounts /admin and /admin/organizations/:org

HTTP request / LiveView connect
  -> :browser + auth pipeline
  -> admin entry plug resolves admin scope from current_scope + URL + host policy
  -> route/controller/export/mutation path checks resolved admin scope
  -> live_session on_mount re-runs equivalent admin-scope check
  -> admin shell renders sticky scope bar + nav
  -> context/query layer uses structural org scoping for org-admin paths
```

### Recommended Project Structure
```text
lib/sigra/install/features/admin.ex         # installer feature entry
lib/sigra/admin/                            # library-owned admin runtime
priv/templates/sigra.install/admin/         # generated boundary templates
test/sigra/admin/                           # library enforcement tests
test/example/lib/example_web/...            # generated host seams + shell examples
test/example/test/example_web/...           # example app integration tests
```

### Pattern 1: Additive Installer Feature
**What:** Implement admin as a sibling feature module with its own files, injections, migrations, and post-install instructions. [VERIFIED: codebase grep]  
**When to use:** For all Phase 27 scaffold generation, including the `--no-admin` opt-out path. [VERIFIED: 27-CONTEXT.md]  
**Example:**
```elixir
# Source: lib/mix/tasks/sigra.install.ex + lib/sigra/install/features/organizations.ex
@features [
  Sigra.Install.Features.Core,
  Sigra.Install.Features.Organizations,
  Sigra.Install.Features.Passkeys,
  Sigra.Install.Features.Admin
]
```

### Pattern 2: Plug + LiveView Parity for Scope Enforcement
**What:** Perform equivalent scope resolution in both the router pipeline and a `live_session` `on_mount` hook. [VERIFIED: codebase grep][CITED: https://hexdocs.pm/phoenix_live_view/security-model.html]  
**When to use:** For every admin route that can be reached through LiveView navigation. [VERIFIED: 27-CONTEXT.md]  
**Example:**
```elixir
# Source: test/example/lib/example_web/router.ex
pipeline :org_scoped do
  plug Sigra.Plug.LoadOrganizationFromSlug, ...
  plug Sigra.Plug.RequireMembership, ...
end

live_session :organization_scoped,
  on_mount: [
    {ExampleWeb.UserAuth, :ensure_authenticated},
    {Sigra.LiveView.OrganizationScope, [...]}
  ] do
  live "/members", OrganizationMembersLive, :index
end
```

### Pattern 3: Structural Org Scope, Not UI Filtering
**What:** Scope queries in the context/query layer before rendering, with Repo-time defense-in-depth for org-bearing schemas. [VERIFIED: CONVENTIONS.md][VERIFIED: codebase grep]  
**When to use:** For all org-admin data reads and writes in later admin phases, and for any Phase 27 wiring that sets the boundary. [VERIFIED: 27-CONTEXT.md]  
**Example:**
```elixir
# Source: lib/sigra/organizations/query.ex
Post
|> Sigra.Organizations.Query.for_org(scope)
|> Repo.all()
```

### Anti-Patterns to Avoid
- **Forwarded admin router:** `live_session` does not work with `forward`, so forwarded admin mounts would undercut the normal LiveView auth model. [CITED: https://hexdocs.pm/phoenix_live_view/Phoenix.LiveView.Router.html]
- **Single boolean `is_admin?`:** Locked decisions require platform-admin and org-admin to stay distinct. [VERIFIED: 27-CONTEXT.md]
- **Session-selected org as auth source:** The URL must own scope; session memory can only restore a last-used destination after revalidation. [VERIFIED: 27-CONTEXT.md]
- **Global query then UI filter:** Sigra conventions treat structural query scoping as the primary protection boundary. [VERIFIED: CONVENTIONS.md]
- **Generated host-heavy runtime:** Locked decisions require library ownership for long-lived security and scoping behavior. [VERIFIED: 27-CONTEXT.md]

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Optional feature installation | Ad hoc installer conditionals across unrelated modules | `Sigra.Install.Feature` + feature list + isolated templates/injections/migrations [VERIFIED: codebase grep] | The existing runner already guarantees additive composition and idempotent re-runs. [VERIFIED: codebase grep] |
| LiveView-only auth | UI or `handle_event` checks without mount parity | Router pipeline plus `live_session` `on_mount` parity [VERIFIED: codebase grep][CITED: https://hexdocs.pm/phoenix_live_view/security-model.html] | LiveView navigation can bypass plug pipelines. [CITED: https://hexdocs.pm/phoenix_live_view/security-model.html] |
| Org-admin filtering | Template-level or LiveView-level filtering of global results | `Sigra.Organizations.Query.for_org/2` and explicit admin-scope query APIs [VERIFIED: CONVENTIONS.md][VERIFIED: codebase grep] | Structural scoping prevents cross-org leaks and is already the project convention. [VERIFIED: CONVENTIONS.md] |
| Admin shell state | Separate SPA or custom client state manager | Existing Phoenix layout + HEEx component pattern + URL-derived scope [VERIFIED: 27-UI-SPEC.md][VERIFIED: codebase grep] | The milestone explicitly stays on the Phoenix/LiveView stack. [VERIFIED: REQUIREMENTS.md][VERIFIED: 27-CONTEXT.md] |

**Key insight:** Phase 27 should compose proven local mechanisms rather than add new infrastructure; almost every risky part already has a nearby organization-scoping precedent. [VERIFIED: codebase grep]

## Common Pitfalls

### Pitfall 1: Plug-Only Authorization
**What goes wrong:** Admin LiveViews become reachable after internal LiveView navigation even though the initial HTTP entry was protected. [CITED: https://hexdocs.pm/phoenix_live_view/security-model.html]  
**Why it happens:** `navigate` inside a `live_session` does not pass through the plug pipeline. [CITED: https://hexdocs.pm/phoenix_live_view/Phoenix.LiveView.Router.html]  
**How to avoid:** Pair every admin pipeline check with router-level `on_mount` enforcement. [VERIFIED: codebase grep]  
**Warning signs:** Plug tests pass but direct LiveView mount/navigation tests do not exist. [VERIFIED: codebase grep]

### Pitfall 2: Hidden Admin Inference
**What goes wrong:** Hosts get accidental platform-admin access through signup order, first membership, or email domain shortcuts. [VERIFIED: 27-CONTEXT.md]  
**Why it happens:** Admin bootstrap is tempting to wire as convenience instead of explicit policy. [VERIFIED: 27-CONTEXT.md]  
**How to avoid:** Keep policy behaviour explicit and generated into the host app, with no fallback magic. [VERIFIED: 27-CONTEXT.md]  
**Warning signs:** Any code path that returns admin access without consulting the generated policy module. [VERIFIED: 27-CONTEXT.md][VERIFIED: codebase grep]

### Pitfall 3: Using `forward` for Admin Mounting
**What goes wrong:** Admin routing loses `live_session` boundaries or requires awkward workarounds. [CITED: https://hexdocs.pm/phoenix_live_view/Phoenix.LiveView.Router.html]  
**Why it happens:** `forward` looks like a natural packaging seam for a library-owned admin surface. [ASSUMED]  
**How to avoid:** Inject normal router scopes and `live_session` blocks into the host router instead. [VERIFIED: 27-CONTEXT.md][VERIFIED: codebase grep]  
**Warning signs:** Proposed router API centers on `forward "/admin", ...`. [CITED: https://hexdocs.pm/phoenix_live_view/Phoenix.LiveView.Router.html]

### Pitfall 4: Query Scope Applied After Fetch
**What goes wrong:** Org admins can observe cross-org rows before UI filtering or export trimming. [VERIFIED: REQUIREMENTS.md][VERIFIED: CONVENTIONS.md]  
**Why it happens:** Developers reuse global admin query functions inside org-admin pages. [ASSUMED]  
**How to avoid:** Split global and org-admin query paths explicitly and keep org-admin reads structurally scoped. [VERIFIED: 27-CONTEXT.md][VERIFIED: CONVENTIONS.md]  
**Warning signs:** `Repo.all(schema, skip_org_check: true)` shows up in org-admin code paths. [VERIFIED: CONVENTIONS.md]

## Code Examples

### Installer Feature Toggle
```elixir
# Source: lib/mix/tasks/sigra.install.ex
@switches [
  organizations: :boolean,
  passkeys: :boolean,
  admin: :boolean
]

@default_opts [
  organizations: true,
  passkeys: true,
  admin: true
]
```
[VERIFIED: codebase grep]

### LiveView Security Boundary
```elixir
# Source: https://hexdocs.pm/phoenix_live_view/security-model.html
scope "/admin" do
  pipe_through [:authenticate_admin]

  live_session :admin, on_mount: MyAppWeb.AdminLiveAuth do
    live "/", AdminDashboardLive
  end
end
```
[CITED: https://hexdocs.pm/phoenix_live_view/security-model.html]

### Scoped Resource Augmentation
```elixir
# Source: https://hexdocs.pm/phoenix/scopes.html
def put_organization(%__MODULE__{} = scope, %Organization{} = organization) do
  %{scope | organization: organization}
end
```
[CITED: https://hexdocs.pm/phoenix/scopes.html]

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Phoenix auth surfaces often used one user scope only. [ASSUMED] | Phoenix 1.8 documents first-class scope structs, route prefixes, and scope augmentation for org-aware resources. [CITED: https://hexdocs.pm/phoenix/scopes.html] | Phoenix 1.8 docs current as of 2026-04-16. [CITED: https://hexdocs.pm/phoenix/scopes.html] | Sigra can model admin scope as a distinct scope-derived structure without fighting the framework. [CITED: https://hexdocs.pm/phoenix/scopes.html][VERIFIED: 27-CONTEXT.md] |
| LiveView auth was often treated like plug auth alone. [ASSUMED] | Official LiveView guidance requires mount-time auth and treats `live_session` as the boundary between auth strategies. [CITED: https://hexdocs.pm/phoenix_live_view/security-model.html][CITED: https://hexdocs.pm/phoenix_live_view/Phoenix.LiveView.Router.html] | Present in current LiveView 1.1.28 docs. [VERIFIED: hex package info][CITED: https://hexdocs.pm/phoenix_live_view/security-model.html] | Phase 27 should plan paired Plug and LiveView enforcement from the start. [VERIFIED: 27-CONTEXT.md] |

**Deprecated/outdated:**
- Mounting the admin surface as a forwarded LiveView subtree is not compatible with the standard `live_session` model. [CITED: https://hexdocs.pm/phoenix_live_view/Phoenix.LiveView.Router.html]

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | A forwarded admin mount is likely to be considered because it superficially resembles other library-owned dashboards. [ASSUMED] | Common Pitfalls | Low; the official docs still settle the decision against `forward`. |
| A2 | Developers may be tempted to reuse global admin queries for org-admin pages and trim later in the UI. [ASSUMED] | Common Pitfalls | Medium; if not anticipated, the plan may miss query-layer verification tasks. |

## Resolved Questions

1. **Generated host policy helper shape**
   - Decision: Keep the generated host policy explicit and reviewable. Ship the behaviour plus an optional library helper for the common `[:owner, :admin]` membership-role mapping, but do not generate implicit membership logic into the host policy by default. [VERIFIED: 27-CONTEXT.md][VERIFIED: codebase grep]
   - Planning impact: Phase 27 should create `Sigra.Admin.Policy` and may expose an explicit helper API, while the generated `sigra_admin_policy.ex` remains a thin host-owned seam with no hidden fallback grants. [VERIFIED: 27-CONTEXT.md]

2. **Admin shell seam placement**
   - Decision: Use one dedicated generated admin shell component imported by `layouts.ex`, rather than embedding all admin chrome directly inside `layouts.ex`. [VERIFIED: codebase grep][VERIFIED: 27-CONTEXT.md]
   - Planning impact: The shell contract stays localized for upgrades, while the host layout change remains small and consistent with existing component-based shell patterns such as `org_switcher.ex`. [VERIFIED: codebase grep]

**Status:** All planning-time questions are resolved enough for execution. No open research blockers remain.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Elixir | Phase implementation and tests | ✓ [VERIFIED: local env] | 1.19.5 [VERIFIED: local env] | — |
| Mix | Installer and test commands | ✓ [VERIFIED: local env] | bundled with Elixir 1.19.5 [VERIFIED: local env] | — |
| Node.js | Example-app Playwright/browser artifacts later in milestone | ✓ [VERIFIED: local env] | 22.14.0 [VERIFIED: local env] | — |
| npm | Example-app Playwright package scripts | ✓ [VERIFIED: local env] | 11.1.0 [VERIFIED: local env] | — |
| PostgreSQL CLI/runtime | Local `mix test` and example app tests | ✓ [VERIFIED: local env] | 14.17 CLI [VERIFIED: local env] | Docker container per `CLAUDE.md` if local server is absent. [VERIFIED: CLAUDE.md] |
| Docker | Disposable Postgres for local testing | ✓ [VERIFIED: local env] | 29.3.1 [VERIFIED: local env] | Existing local Postgres also works. [VERIFIED: CLAUDE.md] |

**Missing dependencies with no fallback:** None. [VERIFIED: local env]

**Missing dependencies with fallback:** None. [VERIFIED: local env]

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | ExUnit for library and example-app tests; Phoenix.ConnTest and selective Phoenix.LiveViewTest in the example app. [VERIFIED: codebase grep] |
| Config file | [`/Users/jon/projects/sigra/test/test_helper.exs`](/Users/jon/projects/sigra/test/test_helper.exs), [`/Users/jon/projects/sigra/test/example/test/test_helper.exs`](/Users/jon/projects/sigra/test/example/test/test_helper.exs), [`/Users/jon/projects/sigra/test/example/config/test.exs`](/Users/jon/projects/sigra/test/example/config/test.exs) [VERIFIED: codebase grep] |
| Quick run command | `mix test test/sigra/plug/require_membership_test.exs test/sigra/live_view/organization_scope_test.exs` adapted with new admin equivalents. [VERIFIED: codebase grep] |
| Full suite command | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost mix test` plus example-app targeted tests under `test/example`. [VERIFIED: CLAUDE.md][VERIFIED: codebase grep] |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| ADMIN-01 | `--no-admin` opt-out and default-on install behavior | installer/unit | `mix test test/sigra/install/...admin...` [ASSUMED] | ❌ Wave 0 |
| ADMIN-02 | explicit policy contract and no implicit admin inference | unit | `mix test test/sigra/admin/policy_test.exs` [ASSUMED] | ❌ Wave 0 |
| ADMIN-03 | route + LiveView + direct-path admin enforcement | unit/integration | `mix test test/sigra/admin test/example/test/example_web/...admin...` [ASSUMED] | ❌ Wave 0 |
| ADMIN-04 | org-admin structural scope restrictions | unit/integration | `mix test test/sigra/admin_scope_test.exs test/example/test/example_web/...admin_scope...` [ASSUMED] | ❌ Wave 0 |
| ADMIN-05 | visible scope chrome and denied/empty states | example-app integration | `cd test/example && mix test test/example_web/...admin_shell...` [ASSUMED] | ❌ Wave 0 |

### Sampling Rate
- **Per task commit:** Run focused library tests for the touched plug/scope/installer modules. [VERIFIED: codebase grep]
- **Per wave merge:** Run the Phase 27 library tests plus example-app integration tests that exercise router and shell wiring. [VERIFIED: codebase grep]
- **Phase gate:** Run the full library suite with Postgres available before `/gsd-verify-work`. [VERIFIED: CLAUDE.md]

### Wave 0 Gaps
- [ ] `test/sigra/install/features/admin_test.exs` — installer feature contract and `--no-admin` coverage. [ASSUMED]
- [ ] `test/sigra/plug/require_admin_access_test.exs` — route/pipeline enforcement parity with existing plug tests. [ASSUMED]
- [ ] `test/sigra/live_view/admin_scope_test.exs` — LiveView on-mount enforcement and 404/denial behavior. [ASSUMED]
- [ ] `test/example/test/example_web/admin_*` — generated host router/layout integration. [ASSUMED]
- [ ] `test/example/test/example_web/integration/phase_27_integration_test.exs` — end-to-end admin entry and scope chrome. [ASSUMED]

## Security Domain

### Applicable ASVS Categories
| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | yes [VERIFIED: REQUIREMENTS.md] | Reuse existing authenticated `current_scope` and explicit admin policy contract. [VERIFIED: codebase grep][VERIFIED: 27-CONTEXT.md] |
| V3 Session Management | yes [VERIFIED: REQUIREMENTS.md] | URL-derived admin scope with session only as redirect convenience; LiveView/logout boundaries remain server-owned. [VERIFIED: 27-CONTEXT.md][CITED: https://hexdocs.pm/phoenix_live_view/security-model.html] |
| V4 Access Control | yes [VERIFIED: REQUIREMENTS.md] | Plug + `on_mount` enforcement plus structural org scoping at query/mutation/export layers. [VERIFIED: 27-CONTEXT.md][VERIFIED: CONVENTIONS.md] |
| V5 Input Validation | yes [VERIFIED: REQUIREMENTS.md] | Reuse slug-based route resolution and role/policy validation patterns already present in plugs. [VERIFIED: codebase grep] |
| V6 Cryptography | no new crypto in Phase 27 [VERIFIED: REQUIREMENTS.md] | Reuse existing Sigra token/session mechanisms; do not introduce custom crypto here. [VERIFIED: codebase grep] |

### Known Threat Patterns for Phoenix/LiveView Admin Access
| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Hidden admin privilege inference | Elevation of Privilege | Explicit generated host policy with no fallback magic. [VERIFIED: 27-CONTEXT.md] |
| LiveView navigation bypassing plug-only auth | Elevation of Privilege | `live_session` boundary plus `on_mount` auth parity. [CITED: https://hexdocs.pm/phoenix_live_view/security-model.html] |
| Cross-org data leakage in org-admin screens | Information Disclosure | Structural org scoping in queries and explicit admin scope resolution from URL org. [VERIFIED: CONVENTIONS.md][VERIFIED: 27-CONTEXT.md] |
| Ambiguous global vs org destructive action context | Tampering | Sticky scope bar and page composition that keeps scope visible at all times. [VERIFIED: 27-UI-SPEC.md][VERIFIED: 27-CONTEXT.md] |

## Sources

### Primary (HIGH confidence)
- `27-CONTEXT.md` - locked decisions, scope model, packaging model, and shell contract. [VERIFIED: 27-CONTEXT.md]
- [`https://hexdocs.pm/phoenix_live_view/security-model.html`](https://hexdocs.pm/phoenix_live_view/security-model.html) - LiveView auth and `live_session` security model. [CITED: https://hexdocs.pm/phoenix_live_view/security-model.html]
- [`https://hexdocs.pm/phoenix_live_view/Phoenix.LiveView.Router.html`](https://hexdocs.pm/phoenix_live_view/Phoenix.LiveView.Router.html) - `live_session` behavior and `forward` incompatibility. [CITED: https://hexdocs.pm/phoenix_live_view/Phoenix.LiveView.Router.html]
- [`https://hexdocs.pm/phoenix/scopes.html`](https://hexdocs.pm/phoenix/scopes.html) - Phoenix 1.8 scopes, route prefixes, and scope augmentation patterns. [CITED: https://hexdocs.pm/phoenix/scopes.html]
- Local code precedents in `lib/sigra/install/*`, `lib/sigra/plug/*`, `lib/sigra/live_view/*`, and `test/example/lib/example_web/*`. [VERIFIED: codebase grep]

### Secondary (MEDIUM confidence)
- [`https://hexdocs.pm/phoenix/Phoenix.Router.html`](https://hexdocs.pm/phoenix/Phoenix.Router.html) - router scopes and pipelines. [CITED: https://hexdocs.pm/phoenix/Phoenix.Router.html]
- `CLAUDE.md` - project constraints and local test prerequisites. [VERIFIED: CLAUDE.md]

### Tertiary (LOW confidence)
- None. [VERIFIED: research session]

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - existing repo versions and official docs align, and Phase 27 adds no new external dependency surface. [VERIFIED: mix.lock][VERIFIED: hex package info]
- Architecture: HIGH - locked decisions line up directly with nearby org/install precedents in the codebase. [VERIFIED: 27-CONTEXT.md][VERIFIED: codebase grep]
- Pitfalls: MEDIUM-HIGH - the biggest pitfalls are directly supported by official LiveView docs and existing org-scoping conventions; a few human-behavior guesses are logged as assumptions. [CITED: https://hexdocs.pm/phoenix_live_view/security-model.html][VERIFIED: CONVENTIONS.md][ASSUMED]

**Research date:** 2026-04-16 [VERIFIED: 27-CONTEXT.md]
**Valid until:** 2026-05-16 for repo precedents; recheck Phoenix/LiveView docs if the phase is delayed materially. [VERIFIED: research session]
