# Architecture Patterns

**Domain:** Sigra v1.2 Admin Dashboard integration
**Researched:** 2026-04-16
**Confidence:** HIGH

## Recommended Architecture

Sigra v1.2 should extend the existing hybrid lib+generator split instead of introducing a separate "admin subsystem." Keep security-critical impersonation, scope/session hydration, and audit query primitives in the library. Keep admin LiveViews, route wiring, presentation queries, and UX-review artifacts in generated host code. That matches the current pattern: library owns durable security behavior; generated code owns app-facing Phoenix surface and can be customized safely.

The cleanest shape is one new generator feature, `Sigra.Install.Features.Admin`, default-on with `--no-admin`, added additively beside Core, Organizations, and Passkeys. It should generate an admin surface that reuses the current request lifecycle:

`router/live_session -> generated UserAuth + org scope hooks -> library scope hydration -> generated admin query wrapper -> Repo`

Impersonation should be modeled as a session-state transition, not a parallel auth mode. The session row remains owned by the real admin actor, while the hydrated `%Scope{}` presents the effective user plus `impersonating_from`. Audit rows then naturally record `actor_id` as the real admin, `effective_user_id` as the impersonated user, and `organization_id` from the active org already established in v1.1.

## Component Boundaries

### New Library Components

| Component | Responsibility | Communicates With |
|-----------|---------------|-------------------|
| `Sigra.Impersonation` | Start/stop impersonation, validate guardrails, create replacement session state, emit audit events | `Sigra.Auth`, session store, `Sigra.Audit`, generated wrapper context |
| `Sigra.Plug.RequireNotImpersonating` | Block sensitive operations while impersonating | Generated router pipelines, existing controllers/LiveViews |
| `Sigra.Admin.AuditFilters` or `Sigra.Audit.Query` extensions | Library-owned canonical filter semantics for admin audit exploration | Generated admin audit context/LiveViews |
| `Sigra.Install.Features.Admin` | Generator feature for routes, LiveViews, controllers, tests, Playwright specs, asset hooks | `Mix.Tasks.Sigra.Install`, `Sigra.Install.Runner` |

### Modified Library Components

| Component | Change | Why |
|-----------|--------|-----|
| `Sigra.Scope.Hydration` | Extend from org-only hydration to full v1.2 scope hydration: effective user first, org/membership second | Existing docs already mark this as the single scope augmentation point |
| `Sigra.Session` | Add impersonation/effective-user fields | Session row remains the durable source of truth |
| `Sigra.Audit.scope_fields/1` in `lib/sigra/audit.ex` | Derive `actor_id` from `scope.impersonating_from` when present, keep `effective_user_id` as `scope.user.id` | Enables dual-actor audit without changing every caller |
| `Sigra.Audit.Query` | Add impersonation-aware filters and indexes that support user/global/org audit views | Audit UI should build on library query primitives, not custom ad hoc SQL |
| `Sigra.Testing` | Add helpers for impersonated-session setup and audit assertions | Keeps generated tests concise and repeatable |
| Session-store update path | Support storing/restoring impersonation session attributes | Needed by controller-owned session transitions |

### New Generated Components

| Component | Responsibility | Communicates With |
|-----------|---------------|-------------------|
| `MyAppWeb.AdminAccess` | Host-owned admin authorization gate for platform admin routes | Router pipelines, LiveView `on_mount`, host user schema/policy |
| `MyApp.Accounts.Admin` | Presentation/query wrapper for user list, user detail, audit search, CSV export | Repo, generated schemas, `Sigra.Audit.Query` |
| `MyAppWeb.Admin.UsersLive.Index` | User list, search/filter, entry point to detail + impersonation | `Accounts.Admin` |
| `MyAppWeb.Admin.UsersLive.Show` | Sessions, security state, identities, memberships, danger-zone actions | `Accounts.Admin`, generated `Accounts` delegates |
| `MyAppWeb.Admin.AuditLive.Index` | Global/org/user audit exploration UI | `Accounts.Admin`, `Sigra.Audit.Query` |
| `MyAppWeb.Admin.ImpersonationController` | POST start/stop endpoints that renew/replace browser session | `Accounts.start_impersonation/3`, `Accounts.stop_impersonation/2`, `UserAuth.put_user_session_token/2` |
| Shared admin components/layout hooks | Banner, filters, tables, breadcrumbs, light/dark/branding hooks | Admin LiveViews and root layout |
| Playwright admin specs + report scripts | UX verification, screenshots, video, HTML report generation | Existing Playwright project and CI scripts |

### Modified Generated Components

| Component | Change | Why |
|-----------|--------|-----|
| `router.ex` | Add admin route scopes and pipelines | Admin surface needs explicit entry points, not route-by-route leakage |
| `UserAuth` | Mount/assign impersonation banner state from hydrated scope; keep session mutation in controllers | Matches current controller-owned session model |
| Generated `Scope` module | Add `put_impersonation/2` helper, keep reserved `impersonating_from` field | Makes scope mutation explicit instead of open-coded |
| Generated `Accounts` context | Add thin delegates into library impersonation/session APIs | Preserve current Phoenix context API for callers |
| Existing sensitive routes | Apply `RequireNotImpersonating` to account settings, MFA enrollment, API token creation, destructive account actions | Prevent target-user takeover while impersonating |
| Example/fixture app | Add seeds/fixtures for platform admin, org admin, regular user, audit-heavy scenarios | Required for deterministic browser/system coverage |

## Route and Surface Shape

Use two route families that render the same admin LiveViews with different access constraints:

1. `/admin/...`
   Platform-admin surface. Global user search, global audit, cross-org impersonation.

2. `/organizations/:org/admin/...`
   Org-admin surface. Reuse existing `:org_scoped` pipeline and `Sigra.Plug.RequireMembership` with `[:owner, :admin]`. Queries are automatically constrained to `current_scope.active_organization`.

This keeps platform admin and org admin visibility separate by construction while still sharing the same generated components and query layer. The distinction belongs in routing and query constraints, not in duplicated UI modules.

## Data Flow

### 1. Admin User List / Detail

1. Request enters admin route.
2. Generated auth pipeline mounts `current_scope`.
3. Library scope hydrator resolves effective user state, then active org/membership.
4. Generated `AdminAccess` gate decides whether the request is platform-admin or org-admin authorized.
5. Generated `Accounts.Admin` builds presentation queries using generated schemas plus library audit/query helpers.
6. LiveView renders list/detail; mutations call generated `Accounts` delegates, which call Sigra library functions where security-sensitive.

### 2. Start Impersonation

1. Admin clicks impersonate on user detail.
2. Browser submits POST to generated `Admin.ImpersonationController`; do not start impersonation from a pure LiveView event because session rotation remains controller-owned in Sigra.
3. Generated controller calls `Accounts.start_impersonation(current_scope, target_user, opts)`.
4. Library `Sigra.Impersonation.start/4` validates:
   - sudo freshness
   - actor authorization
   - target eligibility
   - org boundary rules
   - forbidden self/loop cases
5. Library creates a replacement session state that preserves the real actor and sets the effective user/expiry metadata.
6. Controller renews the Plug session and stores the returned token with `UserAuth.put_user_session_token/2`.
7. Next request/mount hydrates `%Scope{user: target, impersonating_from: actor, active_organization: target_org}`.
8. Audit row records `actor_id = actor.id`, `effective_user_id = target.id`, `target_id = target.id`, plus org/session metadata.

### 3. Stop Impersonation

1. Banner "stop impersonating" submits POST to controller.
2. Library restores a fresh non-impersonated session for the original admin actor, restoring the saved pre-impersonation org if still valid.
3. Controller renews Plug session and swaps token.
4. Scope hydrates back to the original admin user.
5. Audit logs `admin.impersonation.stop`.

### 4. Audit Exploration

1. Audit LiveView collects filters from UI.
2. Generated `Accounts.Admin` translates UI params into library-owned `Sigra.Audit.Query` filters.
3. Library query builder produces canonical Ecto query.
4. Generated code may add joins/preloads for user email/name display, because that schema ownership is host-app specific.
5. Same base query powers HTML list, CSV export, and impersonation-focused views.

### 5. UX Review Artifact Generation

1. Generator emits admin Playwright specs inside the existing `priv/playwright/tests/` tree.
2. CI/local scripts run the existing browser stack, now with admin-specific flows.
3. Artifacts stay generated/app-owned: HTML report, screenshots, traces, optional video.
4. Route/controller shell smoke extends existing non-browser scripts to cover admin and impersonation endpoints outside the browser happy path.

## Scope and Session Model

### Recommended Session Fields

Add these fields to generated `user_sessions` and `Sigra.Session`:

| Field | Purpose |
|-------|---------|
| `effective_user_id` | Target user during impersonation; `nil` otherwise |
| `impersonation_started_at` | Auditability and banner UX |
| `impersonation_expires_at` | Hard time bound enforced in hydration/plug path |
| `impersonator_active_organization_id` | Restore the admin's prior org on stop |

Keep `user_id` as the real authenticated actor. Do not overwrite it with the impersonated user. That preserves revocation semantics, actor identity, and audit consistency.

### Recommended Scope Hydration Order

1. Base actor is loaded from `session.user_id`.
2. If `effective_user_id` is present and unexpired:
   - set `scope.user` to the effective user
   - set `scope.impersonating_from` to the real actor
3. If impersonation has expired:
   - fail closed by clearing impersonation session state
   - rehydrate as the original actor
   - emit one expiration audit event
4. Resolve `active_organization` and `membership` against `scope.user`, not the underlying actor.

This order matters. Org hydration against the wrong user would leak the actor's membership into an impersonated request.

## Schema and Migration Implications

### `user_sessions`

Add the impersonation fields above plus these indexes:

| Index | Reason |
|-------|--------|
| `(effective_user_id)` | Fast lookups for session invalidation / admin detail |
| `(impersonation_expires_at)` | Cleanup / expiry checks |

No separate impersonation table is needed for v1.2. The existing session table is already the durable per-browser state boundary.

### `audit_events`

The v1.1 groundwork is correct: keep `organization_id` and `effective_user_id` on rows. Extend migration/index coverage with:

| Index | Reason |
|-------|--------|
| `(effective_user_id, inserted_at)` | Per-user audit exploration and impersonation traces |
| `(actor_id, inserted_at)` | Already present; keep as the actor-centric view |
| `(organization_id, inserted_at)` | Already present; keep as org-admin audit view |

No new audit table is necessary. The missing piece is better query/filter support, not storage shape.

## Audit Query Implications

Extend `Sigra.Audit.Query` with a small set of admin-facing filters instead of letting generated code invent query semantics:

| Filter | Use |
|--------|-----|
| `:effective_user_id` | Existing per-target-user view |
| `:organization_scope` | Existing org-admin view |
| `:actor_id` | Existing actor-admin view |
| `:impersonation` | New boolean filter for rows where actor and effective user diverge |
| `:session_id` | Optional, if session id continues to be logged in metadata |

Keep joins to host `users` tables out of the library. The library should own row semantics and portable filters; generated code should own display joins, labels, CSV column choices, and any app-specific search fields.

## Ownership Rules: Library vs Generated Code

### Library Owns

- Impersonation validation and session-state transitions
- Scope hydration rules
- Sensitive-operation blocking plugs
- Audit field derivation and canonical audit filters
- Generator feature plumbing and templates
- Test helpers that validate audit/session behavior

### Generated Code Owns

- Route layout and admin shell organization
- Platform-admin authorization policy
- LiveView/HEEx UI, branding hooks, responsive behavior
- User list/detail query shaping and CSV rendering
- Browser/system smoke specs and review artifacts
- Example app seeds, fixtures, and demoability

### Boundary Rule

Do not put platform-admin policy in the library. Sigra already treats authorization as out of scope. The library can enforce impersonation invariants once a caller is authorized to attempt impersonation, but the definition of "platform admin" stays generated and host-editable.

## Patterns to Follow

### Pattern 1: Controller-Owned Session Transitions

**What:** Start/stop impersonation through POST controller endpoints that rotate or replace browser session state.

**When:** Any operation that changes who the browser is acting as.

**Why:** Sigra already treats login/logout/session mutation as controller-owned and stores session truth in the DB-backed session row.

### Pattern 2: Shared LiveViews, Distinct Route Scopes

**What:** Reuse the same admin LiveViews under `/admin` and `/organizations/:org/admin`.

**When:** Platform-admin and org-admin surfaces differ mostly by query scope, not by component tree.

**Why:** Keeps one UI implementation while preserving explicit boundaries in routing.

### Pattern 3: Library Query Primitive, Generated Presentation Query

**What:** Build audit filters in the library, then let generated code add joins/preloads/CSV formatting.

**When:** Audit exploration and user-detail panes.

**Why:** The library owns audit semantics; the host app owns schema presentation.

## Anti-Patterns to Avoid

### Anti-Pattern 1: Impersonation via `session.user_id` overwrite

**Why bad:** Destroys actor identity, complicates revocation, and breaks dual-actor audit semantics.

**Instead:** Keep actor in `user_id`, target in `effective_user_id`, and hydrate scope accordingly.

### Anti-Pattern 2: Pure LiveView impersonation toggles

**Why bad:** Hides session mutation inside socket events and drifts from the current controller-owned session model.

**Instead:** Use POST controller endpoints and then let LiveView consume the resulting session state.

### Anti-Pattern 3: Library-owned admin authorization

**Why bad:** Reintroduces Sigra-owned authorization policy even though authorization is explicitly out of scope.

**Instead:** Generated platform-admin gate plus library-owned security invariants.

### Anti-Pattern 4: Separate audit query implementations per UI

**Why bad:** Global, org, and per-user audit views will drift in filter semantics and pagination behavior.

**Instead:** One canonical library query builder with generated presentation wrappers.

## Build Order

1. **Session + scope groundwork**
   - Add impersonation fields to `user_sessions` and `Sigra.Session`
   - Extend scope hydration to resolve effective user before org membership
   - Add `Scope.put_impersonation/2`
   - This is the dependency floor for everything else

2. **Generator feature skeleton**
   - Add `Sigra.Install.Features.Admin`
   - Wire `--no-admin`
   - Generate minimal router/admin access scaffolding and example app placeholders
   - This keeps subsequent work inside the proven feature-manifest pattern

3. **Admin query layer**
   - Add generated `Accounts.Admin`
   - Extend `Sigra.Audit.Query`
   - Add migration indexes for `effective_user_id`
   - This gives the UI stable read models before design polish

4. **Admin UI shell and user-management flows**
   - Implement `/admin` and `/organizations/:org/admin` route families
   - Build user index/detail, sessions/security/memberships panes
   - Keep impersonation button present but disabled until step 5 lands

5. **Secure impersonation**
   - Add library `Sigra.Impersonation`
   - Add controller start/stop flow, banner state, and `RequireNotImpersonating`
   - Update audit field derivation
   - This depends on the session/scope model and is easier once the user detail page exists

6. **Expanded audit UI**
   - Add global/org/user audit exploration, impersonation filter, CSV export
   - This should follow impersonation so the audit UI reflects the final row semantics

7. **Automation and review artifacts**
   - Extend Playwright with admin flows
   - Extend shell/browser smoke to admin endpoints
   - Add screenshot/report conventions and CI orchestration
   - This lands last so tests track stable routes and copy, but start the fixture/seeding work earlier when step 4 begins

## Sources

- `/Users/jon/projects/sigra/.planning/PROJECT.md`
- `/Users/jon/projects/sigra/lib/sigra/scope.ex`
- `/Users/jon/projects/sigra/lib/sigra/scope/hydration.ex`
- `/Users/jon/projects/sigra/lib/sigra/session.ex`
- `/Users/jon/projects/sigra/lib/sigra/audit.ex`
- `/Users/jon/projects/sigra/lib/sigra/audit/query.ex`
- `/Users/jon/projects/sigra/lib/sigra/plug/load_active_organization.ex`
- `/Users/jon/projects/sigra/lib/sigra/install/feature.ex`
- `/Users/jon/projects/sigra/lib/mix/tasks/sigra.install.ex`
- `/Users/jon/projects/sigra/priv/templates/sigra.install/core/scope.ex`
- `/Users/jon/projects/sigra/priv/templates/sigra.install/core/user_auth.ex`
- `/Users/jon/projects/sigra/lib/sigra/install/features/organizations.ex`
- `/Users/jon/projects/sigra/test/example/lib/example_web/router.ex`
- `/Users/jon/projects/sigra/test/example/lib/example/accounts/audit_event.ex`
- `/Users/jon/projects/sigra/test/example/priv/playwright/playwright.config.ts`
- `/Users/jon/projects/sigra/scripts/ci/http-smoke.sh`
