# Phase 28: User Operations Surface - Research

**Researched:** 2026-04-16
**Domain:** Phoenix LiveView admin user operations on top of Sigra's library-owned auth/admin runtime
**Confidence:** MEDIUM

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
### Runtime ownership and Phoenix architecture
- **D-01:** Keep the admin runtime library-owned. Phase 28 should add
  library-owned admin LiveViews, query helpers, and action modules under
  `Sigra.Admin.*`, while the host app continues to own only the router mount,
  policy module, layout shell seam, and narrow customization hooks.
- **D-02:** Do not generate host-owned admin LiveViews as the primary extension
  seam. Generated page copies would drift from security and scope fixes too
  quickly for a default-on auth admin.
- **D-03:** Keep the Phase 27 route split as the structural boundary:
  `/admin/...` for global admin work and `/admin/organizations/:org/...` for
  org-scoped admin work. Platform admins may intentionally enter either path;
  org admins remain structurally limited to organization-scoped paths.
- **D-04:** Model user-list filters as URL-addressable params parsed by
  router-mounted LiveViews via `handle_params/3`, not as ephemeral client-only
  state. Entering a user detail page and returning to the list must preserve the
  operator's current query/filter context.
- **D-05:** Keep list/detail as separate LiveViews and keep risky mutations in
  context/action modules. Do not build one giant LiveView that owns search,
  detail, and every mutation path in one process.

### Information architecture and navigation
- **D-06:** Make the user operations index the default operational landing for
  Phase 28. Do not insert a dashboard-first screen ahead of the user list.
- **D-07:** Add lightweight summary chips/counters above the list for operator
  orientation, but keep user search and filtering as the primary focus of the
  page.
- **D-08:** Keep active scope visible in persistent shell chrome, not in a
  separate scope picker screen, breadcrumb, or temporary banner. Phase 27's
  scope bar remains the authority for "where am I acting?"
- **D-09:** Use `/admin/users` as the global user index and
  `/admin/organizations/:org/users` as the organization-scoped user index.
  User detail pages should follow the same split so the URL itself reflects the
  admin scope.
- **D-10:** Preserve a clear pivot from global user detail into an intentional
  org-scoped context when a platform admin wants to inspect or act within one
  organization, but do not blur global and org lenses into one ambiguous page.

### User list shape and mobile behavior
- **D-11:** Use one canonical list query model with two presentations:
  a compact sortable table on desktop and stacked result cards on mobile.
  Mobile support must not mean horizontal scrolling of the desktop table.
- **D-12:** Each list row/card should lead with the fields operators use to
  identify the user quickly: name, primary email, and a copyable stable id.
  Secondary metadata should emphasize support and auth state rather than raw
  schema exhaust.
- **D-13:** The first visible list metadata should include the auth/support
  state that helps triage quickly: confirmation state, MFA/passkey state,
  lockout state, deletion state, org membership summary, last sign-in/last
  activity signal when available, and created-at/registration timing.
- **D-14:** Prefer a responsive "same data, different presentation" model over
  designing separate mobile-only and desktop-only flows. Operators should learn
  one user-operations mental model that scales across breakpoints.
- **D-15:** Keep row-level actions light. The list is for finding and triaging
  users, not for hosting the entire admin action surface inline.

### Search and filtering model
- **D-16:** Provide one primary search box that supports email, user id, and
  name by default. Organization membership must also be reachable from the list
  flow, but not necessarily from the same free-text parser if a structured org
  filter is cleaner.
- **D-17:** Make the first-class quick filters the exact operational states
  already locked in requirements: confirmation, MFA, passkeys, lockout,
  deletion, provider mix, and registration date range.
- **D-18:** Keep the default filter surface compact and fast-scanning: expose
  the highest-frequency filters as chips/toggles on the main page, and move
  lower-frequency or multi-input filters into a "More filters" drawer/sheet.
- **D-19:** Org-admin search and filtering must always be structurally scoped to
  the resolved organization context. Never fetch globally and then trim results
  in the LiveView or template.
- **D-20:** Filter state must be preserved, shareable, and bookmarkable. If an
  operator returns from detail to list, the same query/filter/page context
  should be restored instead of resetting to a blank index.

### User detail information model
- **D-21:** Use a single URL-addressable detail page with anchored sections
  instead of heavy tabbing as the default Phase 28 detail surface. Tabs hide
  too much critical state on mobile and make support scanning slower.
- **D-22:** Organize detail sections in this priority order:
  `Identity & Status` -> `Sessions` -> `Security` -> `Identities` ->
  `Organizations` -> `Recent Audit` -> `Danger Zone`.
- **D-23:** Put the highest-value support actions near the top of the detail
  experience, but keep irreversible or stateful work in clearly named sections
  rather than sprinkling actions across unrelated cards.
- **D-24:** Recent audit activity in Phase 28 is summary/preview only. A full
  audit explorer with richer filtering and export belongs to Phase 30.
- **D-25:** Do not treat provider-sourced identity fields as freely editable
  admin fields. Identity-provider-managed attributes may need to remain read-only
  or explicitly caveated so Sigra does not promise edits that upstream providers
  can overwrite.

### Action placement and safety model
- **D-26:** Keep list-level actions to safe, high-frequency tasks. Opening a
  user, copying identifiers, and possibly "revoke all sessions" are acceptable;
  stateful, destructive, or ambiguous actions belong on detail pages.
- **D-27:** Place individual session revoke and revoke-all-sessions on the user
  detail page, not inside dense mobile row menus. Session actions are central to
  Phase 28 and must be easy to inspect before execution.
- **D-28:** Use a three-tier action safety model:
  `Safe` (no confirmation), `Guarded` (confirm dialog with explicit effect
  text), and `High-risk` (sudo re-auth plus typed confirmation and/or reason
  capture).
- **D-29:** Every confirmation dialog for risky admin actions must include the
  current scope and the target identity in human-readable form. Operators should
  never have to infer whether they are acting globally or within one org.
- **D-30:** Broad bulk mutations are out of scope for the first release of the
  admin user-operations surface. Do not design the page around bulk-selection
  flows yet.

### Developer ergonomics and extension seams
- **D-31:** Keep queries and mutations library-owned, with narrow host-owned
  configuration hooks for extra list badges/columns, extra search fields,
  extra detail sections, and copy/label overrides.
- **D-32:** Prefer explicit callback/config registration over a generic macro
  DSL or generated page copies for Phase 28. A more general resource DSL can be
  reconsidered later if Sigra expands beyond auth-focused admin surfaces.
- **D-33:** Design the Phase 28 query and action surfaces so Phase 29
  impersonation and Phase 30 audit exploration can build on the same scope-safe
  primitives instead of replacing them.

### the agent's Discretion
- Exact module names under `Sigra.Admin.Users.*`
- Exact filter param encoding, as long as URLs remain stable and readable
- Exact summary chip/counter set above the list
- Exact visual treatment of mobile cards versus desktop rows
- Exact section card composition inside the user detail page
- Exact host hook API shape, provided it stays narrow and explicit
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| USER-01 | Admin can find a user quickly by email, id, name, or organization membership through searchable, paginated admin views. | Use router-mounted LiveViews with `handle_params/3` plus a validated query layer (`Flop` or equivalent) and scope-safe Ecto queries. |
| USER-02 | Admin can filter the user list by the auth and support states that matter operationally: confirmation, MFA/passkey status, lockout state, deletion state, provider mix, and registration date range. | Build a dedicated admin query module that joins or subqueries sessions, MFA, passkeys, memberships, and optional identities. |
| USER-03 | Admin can open a user detail surface that summarizes the user's current sign-in and security state, including sessions, MFA/passkeys, linked identities, organizations, and recent audit activity. | Reuse existing `Accounts.list_sessions/1`, `Accounts.mfa_status/1`, `Accounts.passkeys_for_user/1`, audit query helpers, and organization membership data behind a library-owned detail assembler. |
| USER-04 | Admin can revoke one session or all active sessions for a user from the admin UI with clear confirmation and audit coverage. | Reuse `Sigra.Auth.revoke_session/3` and `Sigra.Auth.delete_all_sessions/3`, which already emit audit rows and PubSub disconnects. |
| USER-05 | The admin user-management surface works well on mobile and desktop for the main jobs-to-be-done, not just as a compressed desktop table. | Keep one URL/query model with desktop table plus mobile cards, and use browser validation including mobile viewport coverage. |
</phase_requirements>

## Summary

Phase 28 should stay inside the architectural boundary established in Phase 27: library-owned admin LiveViews and admin query/action modules, host-owned router mount plus shell seams, and strict reuse of `Sigra.Admin.Scope` for every list/detail/action path. [VERIFIED: codebase grep] [CITED: https://hexdocs.pm/phoenix_live_view/Phoenix.LiveView.html]

The highest-leverage planning choice is to standardize the list/query contract instead of hand-rolling pagination, sorting, filter validation, and URL generation piecemeal. `Phoenix.LiveView.handle_params/3` is the correct router-mounted state boundary for URL-addressable admin views, and `Flop`/`Flop.Phoenix` are the strongest current fit for validated filtering, pagination metadata, sortable tables, and path generation on Phoenix 1.8 / LiveView 1.1. [CITED: https://hexdocs.pm/phoenix_live_view/Phoenix.LiveView.html] [CITED: https://hexdocs.pm/flop/Flop.html] [CITED: https://hexdocs.pm/flop_phoenix/Flop.Phoenix.html] [VERIFIED: hex.pm api]

The codebase already provides most of the risky primitives: admin scope resolution, session listing and revocation, MFA status, passkey listing, audit querying, and mobile-aware LiveView list patterns. The main plan risk is not raw implementation complexity; it is contract definition around user search fields and optional OAuth identities, because the example app currently lacks a built-in `name` field and does not have an installed `UserIdentity` schema. [VERIFIED: codebase grep] [ASSUMED]

**Primary recommendation:** Use library-owned `Sigra.Admin.Users.*` modules with `Flop`-validated URL params, custom mobile-card rendering, and direct reuse of Sigra's existing session/audit/MFA/passkey APIs. [CITED: https://hexdocs.pm/flop/Flop.html] [VERIFIED: codebase grep]

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Admin user list query, pagination, and filtering | API / Backend | Frontend Server (SSR) | Query semantics, scope enforcement, and filter correctness belong in library-owned Ecto/admin modules; LiveView only reflects URL state. [VERIFIED: codebase grep] [CITED: https://hexdocs.pm/phoenix_live_view/Phoenix.LiveView.html] |
| Mobile/desktop list presentation | Frontend Server (SSR) | Browser / Client | LiveView renders both table and card variants; the browser only handles responsive layout and interaction events. [VERIFIED: codebase grep] |
| User detail assembly | API / Backend | Frontend Server (SSR) | Sessions, MFA, passkeys, audit preview, and memberships all come from server-side data assembly. [VERIFIED: codebase grep] |
| Session revocation | API / Backend | Frontend Server (SSR) | Revocation must reuse `Sigra.Auth` actions for audit and disconnect side effects; LiveView only confirms and invokes. [VERIFIED: codebase grep] |
| Scope visibility and route separation | Frontend Server (SSR) | API / Backend | The shell and URL keep scope visible, but the backend remains the enforcement boundary. [VERIFIED: codebase grep] |
| Audit preview | API / Backend | Database / Storage | Audit filtering and limiting are query concerns against `audit_events`; the detail page only presents the preview slice. [VERIFIED: codebase grep] |

## Project Constraints (from CLAUDE.md)

- Phoenix 1.8+ / Ecto 3.x is the blessed path. [VERIFIED: CLAUDE.md]
- PostgreSQL is the primary database. [VERIFIED: CLAUDE.md]
- Security-sensitive logic stays in the library; generated or host-owned code should remain thin seams. [VERIFIED: CLAUDE.md]
- Prefer minimal transitive dependencies. Small stable code may be copied instead of depending on a package, but only when complexity is actually small. [VERIFIED: CLAUDE.md]
- LiveView is supported but optional across the product; login/logout remain controller-owned elsewhere. Phase 28 can still use LiveView because admin routes already do. [VERIFIED: CLAUDE.md] [VERIFIED: codebase grep]
- Tests should be comprehensive and self-contained. [VERIFIED: CLAUDE.md]
- Local `mix test` requires Postgres on `localhost:5432`. [VERIFIED: CLAUDE.md]
- No project skills were found in `.claude/skills/` or `.agents/skills/`. [VERIFIED: codebase grep]

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Phoenix | `1.8.5` (published 2026-03-05) [VERIFIED: hex.pm api] | Router, verified routes, layouts, admin route split | Already anchors the example app and admin shell wiring. [VERIFIED: codebase grep] |
| Phoenix LiveView | `1.1.28` (published 2026-03-27) [VERIFIED: hex.pm api] | Router-mounted list/detail LiveViews with `handle_params/3` | Official docs explicitly position `handle_params/3` for router-mounted URL state. [CITED: https://hexdocs.pm/phoenix_live_view/Phoenix.LiveView.html] |
| Ecto | `3.13.5` (published 2025-11-09) [VERIFIED: hex.pm api] | Query composition, joins/subqueries for filterable user operations | Existing auth/admin runtime is already Ecto-based. [VERIFIED: codebase grep] |
| Flop | `0.26.3` (published 2025-05-29) [VERIFIED: hex.pm api] | Validated filtering, sorting, and pagination params | Avoids ad hoc query-param parsing and supports schema-based field whitelisting. [CITED: https://hexdocs.pm/flop/Flop.html] |
| Flop.Phoenix | `0.26.0` (published 2026-03-13) [VERIFIED: hex.pm api] | URL builders, pagination controls, sortable table helpers | Matches the phase need for patchable URLs and sortable desktop tables while leaving mobile cards custom. [CITED: https://hexdocs.pm/flop_phoenix/Flop.Phoenix.html] |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Sigra admin/runtime modules | in-repo [VERIFIED: codebase grep] | Scope enforcement, admin route parity, action/query boundary | Use for every admin path; do not bypass with host-owned ad hoc queries. [VERIFIED: codebase grep] |
| Sigra.Auth session APIs | in-repo [VERIFIED: codebase grep] | List/revoke single session, revoke all sessions, sudo updates | Use for all session actions so audit and disconnect behavior stay centralized. [VERIFIED: codebase grep] |
| Sigra.MFA / Sigra.Passkeys | in-repo [VERIFIED: codebase grep] | Security-state summaries | Use to populate the detail view instead of duplicating per-table logic. [VERIFIED: codebase grep] |
| Phoenix core components + Tailwind + daisyUI conventions | in-repo stack [VERIFIED: UI-SPEC] | Desktop table chrome, chips, drawers, cards, dialogs | Use for presentation only; keep query/action semantics outside templates. [VERIFIED: UI-SPEC] |
| Playwright | `1.59.1` available locally [VERIFIED: npm registry] [VERIFIED: local env] | Browser/mobile workflow verification | Use for mobile smoke after ExUnit covers direct-path behavior. [VERIFIED: local env] |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `Flop` + `Flop.Phoenix` | Custom `handle_params` parsing + hand-built Ecto pagination | Fewer deps, but it pushes validation, pagination metadata, sort links, and filter URL encoding into custom code the phase does not need to invent. [CITED: https://hexdocs.pm/flop/Flop.html] |
| `Flop.Phoenix.table/1` desktop-only | Custom table and custom pagination controls | Reasonable if the team wants zero UI helper deps, but sorting/path generation and pagination links become bespoke. [CITED: https://hexdocs.pm/flop_phoenix/Flop.Phoenix.html] |

**Installation:**
```elixir
# mix.exs
{:flop, "~> 0.26.3"},
{:flop_phoenix, "~> 0.26.0"}
```

## Architecture Patterns

### System Architecture Diagram
```text
/admin/users or /admin/organizations/:org/users
        |
        v
Phoenix Router + live_session
        |
        v
Sigra.LiveView.AdminScope on_mount
        |
        v
UserIndexLive.handle_params/3 <----- patch links / filter form / pagination
        |
        v
Sigra.Admin.Users.Query.validate+run
        |
        +--> global admin -> base user query
        |
        +--> org admin -> Sigra.Admin.Authorizer.scope_query(...) / org-scoped join path
        |
        v
User list rows/cards + summary chips
        |
        +--> open user ----------------------------+
                                                 |
                                                 v
                          UserShowLive.handle_params/3
                                                 |
                                                 v
                         Sigra.Admin.Users.Detail.load
                            |      |      |      |
                            |      |      |      +--> Audit preview query
                            |      |      +--------> MFA/passkey status
                            |      +---------------> Sessions list
                            +----------------------> User/org identity summary
                                                 |
                                                 v
                       Guarded action -> Sigra.Admin.Users.Actions
                                                 |
                                                 v
                     Sigra.Auth revoke APIs -> audit row + PubSub disconnect
```

### Recommended Project Structure
```text
lib/
├── sigra/admin/users/              # library-owned query, detail, and action modules
│   ├── query.ex                    # list/search/filter/pagination contract
│   ├── detail.ex                   # detail-page data assembler
│   ├── actions.ex                  # revoke-session and revoke-all actions
│   └── hooks.ex                    # narrow host customization callbacks [ASSUMED]
├── sigra/admin/live/
│   ├── users_index_live.ex         # global/org list LiveView with handle_params
│   └── user_show_live.ex           # detail LiveView with anchored sections
test/example/lib/example_web/
├── router.ex                       # route mounts only
└── components/admin_shell.ex       # shell chrome only
```

### Pattern 1: Router-owned URL state
**What:** Keep query/filter/pagination state in URL params and parse them in `handle_params/3`. [CITED: https://hexdocs.pm/phoenix_live_view/Phoenix.LiveView.html]  
**When to use:** All list/filter transitions, sort links, and back-navigation restoration. [VERIFIED: CONTEXT.md]  
**Example:**
```elixir
# Source: https://hexdocs.pm/phoenix_live_view/Phoenix.LiveView.html
@impl true
def handle_params(params, _uri, socket) do
  case MyApp.Flop.validate_and_run(base_query(socket.assigns.admin_scope), params, for: MyApp.AdminUserRow) do
    {:ok, {rows, meta}} ->
      {:noreply, assign(socket, rows: rows, meta: meta, params: params)}

    {:error, meta} ->
      {:noreply, assign(socket, rows: [], meta: meta, params: params)}
  end
end
```

### Pattern 2: Library-owned query boundary
**What:** Build one admin query module that accepts `admin_scope` plus validated list params and returns rows shaped for both desktop and mobile presentation. [VERIFIED: codebase grep] [ASSUMED]  
**When to use:** USER-01 and USER-02 list/search/filter work.  
**Example:**
```elixir
# Source: codebase pattern + https://hexdocs.pm/flop/Flop.html
def list_users(admin_scope, params) do
  base =
    User
    |> join_memberships()
    |> join_latest_session()
    |> maybe_join_passkeys()
    |> maybe_join_identities()
    |> Sigra.Admin.Authorizer.scope_query(admin_scope)

  Flop.validate_and_run(base, params, for: Sigra.Admin.Users.Row)
end
```

### Pattern 3: Stream resets for list repaint
**What:** If the list LiveView uses streams, replace the visible collection with `reset: true` on filter/page changes instead of accumulating pages in socket state. [CITED: https://hexdocs.pm/phoenix_live_view/Phoenix.LiveView.html]  
**When to use:** Filter or page changes that replace the current result set.  
**Example:**
```elixir
# Source: https://hexdocs.pm/phoenix_live_view/Phoenix.LiveView.html
socket
|> stream(:users, rows, reset: true)
|> assign(:meta, meta)
```

### Anti-Patterns to Avoid
- **Global query then trim in template:** Org-admin search must be structurally scoped before data reaches the template. [VERIFIED: CONTEXT.md] [VERIFIED: codebase grep]
- **One giant LiveView:** Keep list/detail separate and move mutations into action/context modules. [VERIFIED: CONTEXT.md]
- **Inline destructive row menus on mobile:** Session revocation belongs on detail pages with explicit confirmation copy. [VERIFIED: CONTEXT.md] [VERIFIED: UI-SPEC]
- **Ephemeral filter state:** Client-only state breaks back-navigation, sharing, and scope clarity. [VERIFIED: CONTEXT.md] [CITED: https://hexdocs.pm/phoenix_live_view/Phoenix.LiveView.html]

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Filter param validation | custom query-string parser | `Flop.validate_and_run/3` | Whitelists fields, validates operators, and returns query metadata. [CITED: https://hexdocs.pm/flop/Flop.html] |
| Sort/pagination link generation | manual URL builders in templates | `Flop.Phoenix.build_path/3` and pagination/table helpers | Keeps URL state consistent with validated params. [CITED: https://hexdocs.pm/flop_phoenix/Flop.Phoenix.html] |
| Session revoke side effects | direct DB deletes from admin code | `Sigra.Auth.revoke_session/3` and `delete_all_sessions/3` | Existing APIs already audit and broadcast disconnects. [VERIFIED: codebase grep] |
| Scope enforcement | ad hoc `where` clauses in each LiveView | `Sigra.Admin.Authorizer.scope_query/2` and `authorize_organization!/2` | Centralized fail-closed org/global rules already exist. [VERIFIED: codebase grep] |
| MFA/passkey summary math | hand-counting multiple tables in templates | `Example.Accounts.mfa_status/1` and `passkeys_for_user/1` or their library equivalents | Existing APIs already normalize these security-state summaries. [VERIFIED: codebase grep] |

**Key insight:** the tricky part of this phase is not rendering a table; it is keeping scope, URL state, and destructive actions coherent under admin semantics. The repo already has those semantics in library code, so the plan should compose them rather than recreate them. [VERIFIED: codebase grep]

## Common Pitfalls

### Pitfall 1: Designing the list around the current `OrganizationMembersLive` load-more pattern
**What goes wrong:** That pattern is useful for org members, but it is not URL-addressable pagination and will fight the Phase 28 requirement to preserve filter/search/page state. [VERIFIED: codebase grep]  
**Why it happens:** The existing example page streams rows and appends via `"load_more"`, which optimizes one screen but not admin search URLs. [VERIFIED: codebase grep]  
**How to avoid:** Use `handle_params/3` as the source of truth and reserve streams for repainting or incremental UI updates. [CITED: https://hexdocs.pm/phoenix_live_view/Phoenix.LiveView.html]  
**Warning signs:** Back button resets filters; copied URLs lose the current view. [VERIFIED: CONTEXT.md]

### Pitfall 2: Overpromising user-name search when the generated user schema has no canonical name field
**What goes wrong:** The example app's `users` table currently has `email` and auth fields but no `name` column. [VERIFIED: codebase grep]  
**Why it happens:** Sigra is a library and does not force a universal profile schema. [VERIFIED: CLAUDE.md]  
**How to avoid:** Plan a narrow host hook or explicit example-app field addition for display/search name. [ASSUMED]  
**Warning signs:** Query code reaches for `users.name`; example schema compile fails. [VERIFIED: codebase grep]

### Pitfall 3: Assuming linked identities always exist
**What goes wrong:** The library has OAuth identity support, but the example app currently has no installed `UserIdentity` schema or `user_identities` migration. [VERIFIED: codebase grep]  
**Why it happens:** OAuth is generator-driven and optional. [VERIFIED: codebase grep]  
**How to avoid:** Make the identities section conditional on configured schema/support, or explicitly add OAuth generation as prerequisite work. [ASSUMED]  
**Warning signs:** Detail loader depends on `config.identity_schema` in an app where it is nil. [VERIFIED: codebase grep]

### Pitfall 4: Losing audit coverage by bypassing Sigra action APIs
**What goes wrong:** Direct session-row deletes would skip the current audit and PubSub disconnect behavior. [VERIFIED: codebase grep]  
**Why it happens:** Admin code is tempted to call `Repo.delete_all` because the table is simple.  
**How to avoid:** Route all session actions through `Sigra.Auth` wrappers. [VERIFIED: codebase grep]  
**Warning signs:** Session revoke succeeds in the DB but no `session.revoke_all` or related audit appears. [VERIFIED: codebase grep]

## Code Examples

Verified patterns from official sources and current code:

### URL-addressable list page
```elixir
# Source: https://hexdocs.pm/phoenix_live_view/Phoenix.LiveView.html
def handle_params(params, _uri, socket) do
  {:ok, {rows, meta}} =
    Flop.validate_and_run(base_query(socket.assigns.admin_scope), params, for: Sigra.Admin.Users.Row)

  {:noreply, assign(socket, rows: rows, meta: meta, params: params)}
end
```

### Scope-safe admin query
```elixir
# Source: /Users/jon/projects/sigra/lib/sigra/admin/authorizer.ex
def scope_query(queryable, %Scope{} = admin_scope) do
  query = Ecto.Queryable.to_query(queryable)

  cond do
    Scope.global?(admin_scope) ->
      query

    Scope.organization?(admin_scope) and is_binary(admin_scope.organization_id) ->
      Sigra.Organizations.Query.for_org(query, admin_scope.organization_id)

    true ->
      raise UnauthorizedError, reason: :not_found
  end
end
```

### Revoke all sessions through the canonical action
```elixir
# Source: /Users/jon/projects/sigra/lib/sigra/auth.ex
def delete_all_sessions(config, user_id, opts \\ []) do
  sessions = session_store.list_by_user(user_id, store_opts)
  {count, _} = session_store.delete_all_for_user(user_id, delete_opts)
  broadcast_disconnects(pubsub, sessions, except_token)
  Sigra.Audit.log_safe("session.revoke_all", scope, audit_opts)
  {count, nil}
end
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| LiveView pages with local-only filter state | Router-mounted LiveViews using `handle_params/3` and patch navigation | current LiveView docs [CITED: https://hexdocs.pm/phoenix_live_view/Phoenix.LiveView.html] | Correct back/forward behavior and shareable admin URLs |
| Hand-built pagination/filter plumbing | `Flop` + `Flop.Phoenix` schema-driven filtering/pagination | `Flop` current published line 0.26.x [VERIFIED: hex.pm api] | Lower risk for complex admin filter surfaces |
| Direct session row manipulation in app code | Centralized `Sigra.Auth` session revoke APIs with audit/disconnect side effects | already present in repo [VERIFIED: codebase grep] | Phase 28 can focus on UI and scoping, not reinvent session semantics |

**Deprecated/outdated:**
- Custom load-more as the primary admin navigation model: acceptable for org members, but not for Phase 28's bookmarkable search/filter surface. [VERIFIED: codebase grep] [VERIFIED: CONTEXT.md]

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | A narrow host hook can satisfy the locked "name search" requirement without forcing a universal `users.name` field into Sigra core. | Summary / Common Pitfalls / Recommended Project Structure | Planner may under-scope schema or contract work. |
| A2 | The linked-identities detail section should degrade gracefully when OAuth is not installed, instead of making OAuth generation a hidden prerequisite for Phase 28. | Summary / Common Pitfalls | Planner may either over-scope the phase or ship a broken detail page in the example app. |
| A3 | A small `Sigra.Admin.Users.Hooks`-style customization seam is the right expression of D-31 for extra fields/sections. | Architecture Patterns | Planner may choose the wrong extension API shape. |

## Open Questions

1. **How will Phase 28 satisfy locked "name search" in a library that does not own a canonical name field?**
   - What we know: The example app's generated `User` schema has no `name` column today. [VERIFIED: codebase grep]
   - What's unclear: Whether Phase 28 should add example-app display-name data, define a host callback for search expressions, or narrow the example implementation separately from the library contract. [ASSUMED]
   - Recommendation: Resolve this in planning as a first-wave contract task, not an implementation afterthought.

2. **Should linked identities be conditional in the first cut?**
   - What we know: The library exposes OAuth identity support, but the example app does not currently have `UserIdentity` installed. [VERIFIED: codebase grep]
   - What's unclear: Whether the milestone expects the example app to install OAuth before or during Phase 28. [ASSUMED]
   - Recommendation: Treat identity support as conditional unless planning explicitly inserts OAuth prerequisite work.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Elixir | repo build/test | ✓ | `1.19.5` [VERIFIED: local env] | — |
| Erlang/OTP | repo build/test | ✓ | `28` [VERIFIED: local env] | — |
| Node.js | Playwright/browser assets | ✓ | `22.14.0` [VERIFIED: local env] | — |
| npm | Playwright/browser assets | ✓ | `11.1.0` [VERIFIED: local env] | — |
| PostgreSQL client/server | example app and tests | ✓ | client `14.17`; local server accepting on `5432` [VERIFIED: local env] | — |
| Docker | disposable DB option | ✓ | `29.3.1` [VERIFIED: local env] | local Postgres already running |
| Playwright CLI | browser validation | ✓ | `1.59.1` [VERIFIED: local env] | ExUnit-only checks, lower confidence |

**Missing dependencies with no fallback:** None. [VERIFIED: local env]

**Missing dependencies with fallback:** None. [VERIFIED: local env]

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | ExUnit + Phoenix.ConnTest/Phoenix.LiveViewTest in `test/example`; Playwright 1.59.1 for browser smoke [VERIFIED: codebase grep] [VERIFIED: local env] |
| Config file | root `mix.exs`; example `test/example/mix.exs`; browser `test/example/priv/playwright/playwright.config.ts` [VERIFIED: codebase grep] |
| Quick run command | `cd test/example && mix test test/example_web/integration/phase_27_integration_test.exs` |
| Full suite command | `PGUSER=postgres PGPASSWORD=postgres PGHOST=localhost mix test && cd test/example && mix test && cd priv/playwright && npx playwright test` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| USER-01 | Global/org admin can search and paginate users by id/email/name/org membership | integration + LiveView | `cd test/example && mix test test/example_web/live/admin_user_index_live_test.exs -x` | ❌ Wave 0 |
| USER-02 | Quick filters and more-filters sheet drive URL params and scoped query results | LiveView | `cd test/example && mix test test/example_web/live/admin_user_filters_live_test.exs -x` | ❌ Wave 0 |
| USER-03 | Detail page shows identity/status, sessions, security, orgs, audit preview | LiveView + integration | `cd test/example && mix test test/example_web/live/admin_user_show_live_test.exs -x` | ❌ Wave 0 |
| USER-04 | Session revoke and revoke-all confirm correctly and emit canonical side effects | integration + direct-path | `mix test test/sigra/auth_test.exs test/sigra/admin/users_actions_test.exs -x` | ❌ Wave 0 |
| USER-05 | Mobile card flow stays usable for search -> open user -> revoke session | Playwright | `cd test/example/priv/playwright && npx playwright test tests/admin-user-operations.spec.ts --project=chromium` | ❌ Wave 0 |

### Sampling Rate
- **Per task commit:** `cd test/example && mix test test/example_web/live/admin_user_index_live_test.exs -x`
- **Per wave merge:** `cd test/example && mix test`
- **Phase gate:** Full suite green plus Playwright admin-user-operations spec

### Wave 0 Gaps
- [ ] `test/example/test/example_web/live/admin_user_index_live_test.exs` — USER-01 / USER-02 / USER-05
- [ ] `test/example/test/example_web/live/admin_user_show_live_test.exs` — USER-03 / USER-04 / USER-05
- [ ] `test/sigra/admin/users_query_test.exs` — scoped query/filter contract
- [ ] `test/sigra/admin/users_actions_test.exs` — revoke semantics, audit, scope failures
- [ ] `test/example/priv/playwright/tests/admin-user-operations.spec.ts` — mobile and desktop operator smoke

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | Existing login/auth foundation is Phase 27 and earlier; Phase 28 consumes current auth state. [VERIFIED: ROADMAP.md] |
| V3 Session Management | yes | Reuse `Sigra.Auth` session APIs and `Sigra.SessionStores.Ecto`; never mutate sessions ad hoc. [VERIFIED: codebase grep] |
| V4 Access Control | yes | `Sigra.Admin.Scope`, `Sigra.Admin.Authorizer`, route split, and org-scoped queries. [VERIFIED: codebase grep] |
| V5 Input Validation | yes | `Flop` filter validation and Ecto query shaping; confirmation inputs stay server-validated. [CITED: https://hexdocs.pm/flop/Flop.html] |
| V6 Cryptography | no | No new cryptographic primitives should be introduced in this phase. [VERIFIED: CLAUDE.md] |

### Known Threat Patterns for Phoenix LiveView admin surfaces

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Org admin accesses global or foreign-org users by URL tampering | Elevation of Privilege | Route split + `Sigra.LiveView.AdminScope` + `Sigra.Admin.Authorizer.scope_query/2`. [VERIFIED: codebase grep] |
| Filter params leak data by widening queries | Information Disclosure | Validate params and scope the base query before filters run. [CITED: https://hexdocs.pm/flop/Flop.html] [VERIFIED: codebase grep] |
| Destructive session actions target the wrong user/scope | Tampering | Show scope and target identity in confirm copy and route action through library-owned action module. [VERIFIED: CONTEXT.md] [VERIFIED: UI-SPEC] |
| Audit trail missing for admin actions | Repudiation | Reuse existing Sigra revoke APIs that already audit. [VERIFIED: codebase grep] |
| Mobile UI hides context or dangerous actions behind ambiguous menus | Spoofing / Tampering | Keep scope visible in shell chrome and keep revoke actions on detail page, not dense row menus. [VERIFIED: CONTEXT.md] [VERIFIED: UI-SPEC] |

## Sources

### Primary (HIGH confidence)
- `https://hexdocs.pm/phoenix_live_view/Phoenix.LiveView.html` - `handle_params/3`, streams, router-mounted LiveView behavior
- `https://hexdocs.pm/flop/Flop.html` - validated filtering, pagination, schema configuration
- `https://hexdocs.pm/flop_phoenix/Flop.Phoenix.html` - path generation, pagination, sortable table helpers
- `https://hex.pm/api/packages/phoenix` - latest Phoenix version and publish timestamp
- `https://hex.pm/api/packages/phoenix_live_view` - latest LiveView version and publish timestamp
- `https://hex.pm/api/packages/ecto` - latest Ecto version and publish timestamp
- `https://hex.pm/api/packages/flop` - latest Flop version and publish timestamp
- `https://hex.pm/api/packages/flop_phoenix` - latest Flop Phoenix version and publish timestamp
- `/Users/jon/projects/sigra/lib/sigra/admin/scope.ex` - admin scope contract
- `/Users/jon/projects/sigra/lib/sigra/admin/authorizer.ex` - scope-safe admin query/action helpers
- `/Users/jon/projects/sigra/lib/sigra/live_view/admin_scope.ex` - LiveView parity for admin scope
- `/Users/jon/projects/sigra/lib/sigra/auth.ex` - session list/revoke/revoke-all behavior
- `/Users/jon/projects/sigra/lib/sigra/session_stores/ecto.ex` - session persistence/query behavior
- `/Users/jon/projects/sigra/lib/sigra/mfa.ex` - MFA status surface
- `/Users/jon/projects/sigra/test/example/lib/example/accounts.ex` - example app wrappers for sessions, MFA, passkeys
- `/Users/jon/projects/sigra/test/example/lib/example/accounts/user.ex` - generated user schema shape
- `/Users/jon/projects/sigra/test/example/priv/repo/migrations/20260410125242_create_sigra_auth_tables.exs` - current indexes and auth schema tables

### Secondary (MEDIUM confidence)
- `https://hexdocs.pm/phoenix/components.html` - Phoenix component guidance aligning with current UI stack
- `/Users/jon/projects/sigra/test/example/lib/example_web/live/organization_members_live.ex` - existing mobile-aware LiveView list/modal pattern
- `/Users/jon/projects/sigra/test/example/test/example_web/integration/phase_27_integration_test.exs` - current admin route/scope integration pattern

### Tertiary (LOW confidence)
- None

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - official docs plus Hex API verification
- Architecture: MEDIUM - codebase evidence is strong, but the `name` and optional identity contracts are still unresolved
- Pitfalls: HIGH - all major pitfalls come directly from current code or locked decisions

**Research date:** 2026-04-16
**Valid until:** 2026-05-16
