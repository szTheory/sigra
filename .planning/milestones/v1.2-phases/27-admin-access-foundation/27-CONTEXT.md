# Phase 27: Admin Access Foundation - Context

**Gathered:** 2026-04-16
**Status:** Ready for planning

<domain>
## Phase Boundary

Establish the foundation for Sigra's admin surface on the existing Phoenix/LiveView stack. This phase covers default-on admin installation with `--no-admin` opt-out, the host-owned admin policy contract, explicit server-side admin scope enforcement for routes/LiveViews/exports/mutations, and the base admin shell that keeps global vs organization scope visible at all times. It does not deliver the full user-operations surface, impersonation workflows, or rich audit exploration; it creates the packaging, policy, scope, and shell contracts those later phases build on.

</domain>

<decisions>
## Implementation Decisions

### Packaging and installation model
- **D-01:** Admin ships inside the main `sigra` package as a new first-class installer feature, enabled by default and disabled with `--no-admin`. Do not split Phase 27 into a separate `sigra_admin` package.
- **D-02:** Admin follows the existing feature-manifest pattern as `Sigra.Install.Features.Admin`, with isolated templates, injections, migrations, and post-install instructions parallel to organizations and passkeys.
- **D-03:** The long-lived admin runtime stays library-owned wherever Sigra needs stable security, scoping, and upgrade behavior. Generate only thin host-owned boundary files: router mount/wiring, policy module, and small configuration/chrome hooks where needed.
- **D-04:** Do not make the admin surface primarily generated host code. Generated-host-heavy admin would create drift, weaken upgradeability, and push security-sensitive scoping logic out of the library.

### Admin policy contract
- **D-05:** Admin access is always explicit and host-owned. Sigra must never infer admin access from signup order, first user, first org owner, email domain, or any hidden default.
- **D-06:** Generate a small host policy module such as `MyApp.SigraAdminPolicy` behind a clear behaviour. The contract should stay intentionally small.
- **D-07:** The policy contract should require `platform_admin?(scope)` and support `admin_org_ids(scope)` for org-admin scope resolution.
- **D-08:** Sigra may provide a helper for the common case where org-admin authority is derived from Sigra organization memberships with roles in `[:owner, :admin]`, but this remains helper behavior, not an implicit default magic path.
- **D-09:** Platform-admin and org-admin are distinct concepts. Do not collapse them into one boolean or assume org admin implies global access.

### Admin scope model and enforcement boundary
- **D-10:** Admin scope is explicit in the URL and request lifecycle. Use a global admin entry point at `/admin` and organization-scoped admin entry points at `/admin/organizations/:org`.
- **D-11:** Platform admins may intentionally enter either global or organization-scoped admin views. Org admins may enter only organization-scoped admin views for organizations in `admin_org_ids(scope)`.
- **D-12:** URL org scope is the authorization source of truth for admin pages. Session state may remember the last admin org only as a redirect convenience, never as the actual authorization decision.
- **D-13:** Sigra should resolve a request-local admin scope struct, distinct from but derived from `current_scope`, so admin routes, LiveViews, queries, exports, and mutations all enforce the same resolved scope.
- **D-14:** Server-side enforcement is mandatory at every boundary: route/pipeline entry, LiveView mount, context/query layer, export layer, and mutation endpoints. UI visibility is never the protection boundary.
- **D-15:** Org-admin surfaces must be structurally scoped queries, not global queries filtered in templates or LiveViews after the fact.

### Admin shell and scope visibility
- **D-16:** Use a hybrid admin shell: a sticky top scope bar plus conventional admin navigation. This is the default shell contract for both desktop and mobile.
- **D-17:** The sticky scope bar must always show `Admin`, the active scope (`Global` or the active organization name), and any special session state that changes action meaning.
- **D-18:** Desktop uses a grouped sidebar for durable wayfinding. Mobile keeps 3-5 high-frequency destinations in a bottom nav and puts the rest behind a drawer/menu. Do not rely on a hamburger-only shell for all mobile navigation.
- **D-19:** Page headers should show the current object/action, not repeat the scope as the only context cue. Scope must already be visible in the persistent shell.
- **D-20:** Global and organization-destructive actions must never be visually mixed in a way that blurs scope. The shell and page composition should make cross-org vs single-org action context obvious before confirmation.

### Phoenix and library-architecture fit
- **D-21:** Stay fully idiomatic to Phoenix/Plug/Ecto/LiveView. Reuse router scopes, pipelines, `live_session`, `on_mount`, current scope hydration, and server-rendered LiveView shells rather than inventing a parallel framework.
- **D-22:** Reuse the existing organizations and scope plumbing as the foundation for admin org scoping. Phase 27 should extend the system incrementally, not fork the scope model.
- **D-23:** Keep admin concerns in dedicated modules and feature boundaries. Do not leak admin-specific behavior into unrelated feature modules or the core installer path.

### the agent's Discretion
- Exact module names under `Sigra.Admin.*`
- Exact admin scope struct field names, as long as the split between global vs org-scoped admin context remains explicit
- Exact sidebar group names and iconography
- Exact mobile bottom-nav destination set, as long as it prioritizes the highest-frequency operator destinations
- Exact branding hook API, provided it stays basic and does not grow into a theming engine

</decisions>

<specifics>
## Specific Ideas

- The recommendation set should bias toward "one package, one upgrade path, one security boundary" rather than package purity.
- Use the same additive feature pattern already proven by organizations and passkeys.
- Treat Phoenix LiveDashboard as the closer packaging precedent than `phx.gen.auth`: library-owned runtime mounted by the host app, with explicit host auth/config seams.
- Learn from Django admin's success at making internal tooling feel first-class, but do not copy Django's auto-discovery or permission magic.
- Learn from GitHub, Clerk, and Auth0 that active tenant/scope context needs to stay visible in persistent chrome, not only in URLs or breadcrumbs.
- Learn from popular admin frameworks that mobile support cannot mean "desktop table shrunk to 375px".
- Avoid the classic admin footguns called out by the research pass:
  - hidden or inferred admin privilege
  - global queries filtered in the UI
  - nav-only authorization
  - ambiguous scope when switching between global and org views
  - generated code owning long-lived security-sensitive behavior

</specifics>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Milestone and phase requirements
- `.planning/ROADMAP.md` — Phase 27 goal, dependencies, success criteria, and milestone ordering
- `.planning/REQUIREMENTS.md` — ADMIN-01 through ADMIN-05 and the v1.2 out-of-scope constraints
- `.planning/PROJECT.md` — milestone framing, architecture constraints, and prior decisions that v1.2 must respect
- `.planning/v1.2-DIRECTION.md` — original v1.2 direction and non-negotiables for admin, scope, impersonation, and audit

### Installer and feature architecture
- `lib/sigra/install/feature.ex` — canonical feature contract for additive installer features
- `lib/sigra/install/runner.ex` — feature walker and isolation/upgrade behavior
- `lib/mix/tasks/sigra.install.ex` — current installer switches and feature registration pattern
- `lib/sigra/install/features/organizations.ex` — strongest existing precedent for a default-on optional feature with router/layout wiring

### Scope and organization foundations
- `lib/sigra/scope.ex` — library-side scope construction contract
- `lib/sigra/plug/load_organization_from_slug.ex` — request-time org resolution pattern
- `lib/sigra/plug/require_membership.ex` — scoped access enforcement pattern
- `test/example/lib/example/accounts/scope.ex` — generated host scope contract, including reserved `:impersonating_from`
- `test/example/lib/example_web/user_auth.ex` — current Plug/LiveView scope loading and `on_mount` patterns
- `test/example/lib/example_web/router.ex` — current scoped router and `live_session` structure

### Existing shell and generated-app conventions
- `test/example/lib/example_web/components/layouts.ex` — current app shell pattern and existing org switcher placement

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `Sigra.Install.Feature` and `Sigra.Install.Runner`: already provide the exact additive feature seam needed for `Features.Admin`.
- `Sigra.Install.Features.Organizations`: proven pattern for default-on optional feature wiring, router injections, and host-owned generated shell pieces.
- `Sigra.Scope` and generated host `%Scope{}` modules: already support extension and reserved admin-adjacent fields without replacing the scope model.
- `Sigra.Plug.LoadOrganizationFromSlug` and `Sigra.Plug.RequireMembership`: strong precedent for request-time scope resolution and hard server-side guards.
- Example app `UserAuth` Plug + LiveView `on_mount` flow: existing pattern for keeping Plug and LiveView scope hydration aligned.
- Example layout + org switcher: concrete precedent for persistent scope-aware chrome inside a generated Phoenix shell.

### Established Patterns
- Feature additions are isolated siblings, not conditionals scattered through unrelated modules.
- Host apps own explicit boundary modules and routing glue; Sigra owns stable security-sensitive runtime.
- Scope is hydrated into `current_scope` and carried through Plug + LiveView rather than rebuilt ad hoc per page.
- URL-based scoped routing is already the preferred pattern for org-aware surfaces.

### Integration Points
- New installer switch and feature registration for `admin` in `mix sigra.install`
- New admin feature templates and injections under `priv/templates/sigra.install/admin/`
- New host policy module generation and router mount injection
- New admin scope resolver that composes with existing `current_scope` and organization plumbing
- New admin layout shell/components that extend the current Phoenix shell conventions instead of replacing them

</code_context>

<deferred>
## Deferred Ideas

- Separate `sigra_admin` package or monorepo package boundary
- Full theming engine or runtime admin shell customization UI
- Session-owned admin scope as the primary authorization source
- Any "first admin" bootstrap magic beyond explicit documentation or tooling
- Broader role/permission management beyond the small admin policy contract
- Rich admin information architecture beyond what Phase 27 needs to establish the shell and scope contracts

</deferred>

---

*Phase: 27-admin-access-foundation*
*Context gathered: 2026-04-16*
