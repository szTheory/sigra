# Phase 28: User Operations Surface - Context

**Gathered:** 2026-04-16
**Status:** Ready for planning

<domain>
## Phase Boundary

Deliver the first real admin user-operations surface on top of the Phase 27
admin foundation. This phase covers searchable, filterable, mobile-friendly
user list and detail flows, plus session revocation from the admin UI. It does
not introduce impersonation UX, rich audit exploration/export, broad bulk
mutations, or analytics-heavy dashboard work; those remain in later phases.

</domain>

<decisions>
## Implementation Decisions

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

</decisions>

<specifics>
## Specific Ideas

- The right default for Sigra is an ops-first admin, not a decorative dashboard.
  The first screen should help an operator find one user fast.
- Use the existing Phase 27 shell as the persistent scope and navigation anchor
  instead of inventing a second IA for Phase 28.
- Learn from Django admin's strengths: search and filters are first-class,
  preserved in URLs, and immediately useful without extra setup.
- Learn from Django admin's footguns too: broad bulk actions and default-delete
  ergonomics are not the standard Sigra should copy into its first release.
- Learn from Auth0/Okta/Clerk that user detail pages are where session/security
  actions belong, and that provider-managed identity data often should not be
  treated as locally editable.
- Learn from popular admin frameworks that "responsive" cannot mean a
  horizontally scrolling desktop table on a phone.
- Use Phoenix LiveDashboard as the packaging precedent: library-owned runtime,
  host-mounted and host-authorized, with thin seams rather than generated
  long-lived runtime code.

</specifics>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Milestone and phase requirements
- `.planning/ROADMAP.md` — Phase 28 goal, success criteria, dependencies, and
  phase ordering inside v1.2
- `.planning/REQUIREMENTS.md` — USER-01 through USER-05 plus out-of-scope guardrails
- `.planning/PROJECT.md` — milestone goals, DX philosophy, and admin milestone framing
- `.planning/v1.2-DIRECTION.md` — original user direction for the admin
  user-management surface, mobile expectations, and future-phase boundaries
- `.planning/phases/27-admin-access-foundation/27-CONTEXT.md` — locked Phase 27
  admin scope, shell, and ownership decisions that Phase 28 must build on

### Admin scope and enforcement foundation
- `lib/sigra/admin/policy.ex` — host-owned admin policy contract that Phase 28
  must continue to respect
- `lib/sigra/admin/scope.ex` — resolved global vs organization admin scope model
- `lib/sigra/admin/authorizer.ex` — direct-path authorization helpers and query
  scoping boundary
- `lib/sigra/plug/require_admin_access.ex` — request-time enforcement for admin routes
- `lib/sigra/live_view/admin_scope.ex` — LiveView-side admin scope parity
- `lib/sigra/organizations/query.ex` — structural org-scoping pattern that must
  continue to guard org-admin data access

### Existing host wiring and shell seams
- `test/example/lib/example_web/router.ex` — current global and org admin route
  split plus `live_session` structure
- `test/example/lib/example_web/user_auth.ex` — existing current-scope hydration
  and `on_mount` patterns
- `test/example/lib/example_web/components/admin_shell.ex` — persistent scope
  chrome, desktop sidebar, and mobile bottom-nav seam
- `lib/sigra/admin/live/index_live.ex` — current global admin landing placeholder
- `lib/sigra/admin/live/organization_live.ex` — current org-scoped admin landing
  placeholder

### Existing list/action interaction patterns
- `test/example/lib/example_web/live/organization_members_live.ex` — current
  LiveView list, load-more, modal confirmation, and mobile-aware interaction style
- `lib/sigra/auth.ex` — existing session and auth mutation surfaces Phase 28 can
  build on for session revocation and state display
- `lib/sigra/passkeys.ex` — passkey state and operations that will inform the
  security summary portion of user detail
- `lib/sigra/organizations.ex` — organization membership and danger-zone style
  patterns relevant to org membership display and high-risk confirmations
- `lib/sigra/audit/query.ex` — existing audit query foundation for the
  "recent audit" summary surface

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `Sigra.Admin.Scope` and `Sigra.Admin.Authorizer`: already provide the correct
  global-vs-org scope boundary for both list queries and user detail actions.
- `ExampleWeb.Components.AdminShell`: already encodes visible admin scope,
  desktop sidebar navigation, and mobile bottom-nav behavior that Phase 28
  should extend instead of replacing.
- `ExampleWeb.OrganizationMembersLive`: already demonstrates Sigra's current
  LiveView interaction style for long lists, modal confirmations, and phone-safe
  action handling.
- `Sigra.Organizations.Query.for_org/2`: proven structural org-scoping helper
  for avoiding cross-tenant leaks.
- `Sigra.Auth` session and auth mutation functions: existing runtime surface
  for session revoke-one/revoke-all and user security-state summarization.
- `Sigra.Audit.Query`: existing query builder that can support a recent-audit
  preview on the user detail page before the full Phase 30 explorer exists.

### Established Patterns
- Library owns long-lived security-sensitive runtime; host app owns explicit
  policy and shell seams.
- Plug and LiveView authorization are kept in parity through route pipelines,
  `live_session`, and `on_mount`.
- Scope is URL-driven and request-local, not inferred from mutable UI state.
- Org-safe access uses structural query scoping, not post-query filtering in UI.
- Current example LiveViews prefer straightforward server-rendered interactions
  over heavy client-side admin-grid abstractions.

### Integration Points
- New global admin user routes under `/admin/users` plus matching global detail routes
- New org-scoped admin user routes under `/admin/organizations/:org/users`
- New `Sigra.Admin.Users` query/action modules consumed by library-owned LiveViews
- Shell navigation updates so user operations become the primary Phase 28 admin destination
- Host hook/config seam for optional extra list/detail presentation without moving
  the core runtime out of the library

</code_context>

<deferred>
## Deferred Ideas

- Dashboard-first admin overview with richer analytics widgets
- Broad bulk mutations such as lock/unlock/reset across many selected users
- Saved views, advanced filter builders, and CSV export
- Full audit explorer and export workflows
- Impersonation UI, banners, and controller handoff
- Generalized admin resource DSL beyond the user-operations surface

</deferred>

---

*Phase: 28-user-operations-surface*
*Context gathered: 2026-04-16*
