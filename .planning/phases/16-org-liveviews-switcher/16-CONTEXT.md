# Phase 16: Org LiveViews + Switcher - Context

**Gathered:** 2026-04-13
**Status:** Ready for planning

<domain>
## Phase Boundary

Phase 16 delivers the full user-facing organization surface in the generated example app: switcher, landing/picker, create-first-org, settings (rename/slug/soft-delete), and members list. It is also the first phase to add **URL-driven per-request organization scoping** on top of Phase 14's session-driven resume pointer, following the Phoenix 1.8 scopes guide pattern (`scope "/organizations/:org" do ... end`).

**In scope:**
- URL-driven routing: `scope "/organizations/:org"` block + `Sigra.Plug.LoadOrganizationFromSlug` (library) + `Sigra.LiveView.OrganizationScope` on_mount (library). Parallel to Phase 14's session-driven plug/on_mount, reusing the same `put_active_organization/2` orchestrator.
- `OrganizationsLive.Index` — single unified LV at `/organizations` serving all four entry points (signup-zero, login-zero, login-2+-without-resume, stale-recovery). Three render branches keyed on `(memberships, pending_invitations)`.
- `OrganizationSettingsLive` at `/organizations/:org/settings` — single page, three stacked sections (General / Slug / Danger Zone), inline progressive disclosure for destructive actions.
- `OrganizationMembersLive` at `/organizations/:org/members` — responsive core_components `<.table>`, per-row action menu, stock `<.modal>` for role-change + remove confirmation, Phase 17 stub section for pending invitations.
- `OrganizationSwitchController` — POST `/organizations/switch` (plain controller per ORG-UX-03), delegates to `Sigra.Plug.put_active_organization/2` via the thin wrapper's `set_active_organization/2`.
- Generated function component `lib/<app>_web/components/org_switcher.ex` — daisyUI dropdown rendering active org + role badge, other orgs, create-org link, settings link for owners/admins (ORG-UX-02). Host-owned, host pastes into their layout per post-install instructions.
- New library context functions: `list_members_with_activity/2`, `count_members/1`, `rename_organization/2`, `update_slug/2`, `soft_delete_organization/2`. Settings mutations verify `current_password` inline via `Sigra.Crypto.verify_password` and call `confirm_sudo/1` on success — matches v1.0 `SettingsLive` pattern, no `RequireSudo` redirect.
- `Features.Organizations` generator fills in `files/1`, `injections/1`, `post_instructions/2` for the above (Phase 13 stubbed this module; Phase 16 populates it alongside Phase 18 finishing `--no-organizations` conditionality).
- Tiny Phase 13 schema follow-ups: add `"orgs"`, `"organizations"`, `"switch"` to reserved slug list; ensure `@derive {Phoenix.Param, key: :slug}` on `Organization`.
- Example app consumption: generated switcher wired into example app layout via the post-install instructions path (the smoke harness exercises it end to end).
- Tests: LV tests for each page, switcher controller round-trip, slug-in-URL mismatch → 404, URL-driven plug refreshes session pointer, last-owner guard surfacing in members LV, SC-4 force-logout on member remove.

**Out of scope (belongs in later phases):**
- Invitation flow logic (HMAC, email template, accept/reject, revoke, rate-limited creation) — Phase 17. Phase 16 ships the members-page stub section + the `Index` landing's pending-invitations render branch; Phase 17 plugs in the real queries.
- `--no-organizations` generator flag + backfill migration — Phase 18.
- Library-owned function components (`Sigra.Components.*`) and library-owned LiveComponents (`Sigra.LiveComponents.*`) — deferred pending 3+ consumers under the new UI Ownership Rule (D-12).
- Mobile-first card-stack members layout — v1.2 admin UI pass.
- Flop-based pagination — v1.2 admin UI pass.
- Typed-email-confirm for member removal — reversible by re-invitation, not warranted.
- `RequireSudo` redirect flow for settings — v1.0 precedent is inline password verification, not redirect.
- Multi-tab cross-request re-verification test — covered by the slug-in-URL plug behavior, no separate harness.
- Schema additions for Membership `status` or `last_active_at` — computed from existing sources.
- `Sigra.LiveHelpers` namespace — banned in Phoenix 1.8; shared on_mount helpers use `Sigra.LiveView.*`.

</domain>

<decisions>
## Implementation Decisions

### Routing & URL-Driven Scope

- **D-01: Slug-in-URL routing using the Phoenix 1.8 scopes guide pattern.** Phase 16 adds a `scope "/organizations/:org", MyAppWeb do ... end` block in the generated router with a `pipe_through [Sigra.Plug.LoadOrganizationFromSlug]` (+ LV `on_mount` parallel). Scoped routes: `/organizations/:org/settings`, `/organizations/:org/members`. Unscoped routes: `/organizations` (landing), `POST /organizations/switch`.

  **Why:** The Phoenix 1.8 scopes guide documents `route_prefix: "/organizations/:org"` with `@derive {Phoenix.Param, key: :slug}` as the canonical pattern, and Sigra's positioning ("fills the Pow gap on Phoenix 1.8+") cannot credibly diverge from the framework's own guide on the most visible routing decision in the org system. Matches Linear / GitHub / Vercel / Slack / Clerk / Supabase mental model — zero learning curve for end users. Enables shareable deep links AND multi-tab-multi-org (open two orgs side-by-side in different tabs) which is a genuine product feature impossible under v1.0's session-implicit `/users/settings` pattern.

- **D-02: URL slug = per-request active org; session column = resume pointer.** The reframe that preserves every Phase 14 decision:
  - Inside `/organizations/:org/...`, the **URL** is the authoritative per-request scope. `Sigra.Plug.LoadOrganizationFromSlug` reads `conn.params["org"]`, verifies membership, and assigns `%Scope{active_organization: org, membership: m}` for that request only.
  - Outside the scoped block (`/`, `/users/settings`, `/organizations`, etc.), the **session column** `user_sessions.active_organization_id` drives `%Scope{}` via Phase 14's existing `Sigra.Plug.LoadActiveOrganization`.
  - Phase 14 D-13 "per-session not per-user" holds because the column still lives on `user_sessions`.
  - Phase 14 D-16 "single authoritative writer" holds because the URL plug *delegates* to `put_active_organization/2` to refresh the pointer — it never touches the session column directly.

- **D-03: New library modules for URL-driven load.** `lib/sigra/plug/load_organization_from_slug.ex` and `lib/sigra/live_view/organization_scope.ex` (the `on_mount` parallel). Both accept `:scope_param` option (default `"org"`) and call into `Sigra.Organizations.get_organization_by_slug/2` + `get_membership/3`. This matches Phase 14 D-22's rule: shared request-time wiring lives in the library.

- **D-04: Slug mismatch / not-a-member resolution.**
  - URL slug does not resolve to an organization → **404** (enumeration prevention; matches v1.0 convention of hiding resource existence from non-members).
  - URL slug resolves but user is not a member → **404** (same reason — never 403, never reveal the org exists).
  - URL slug resolves and user IS a member, but differs from session pointer → assign the URL org to `%Scope{}` for this request AND call `put_active_organization(conn, url_org)` to refresh the session pointer ("I clicked a link, now I'm in that org; tomorrow I'm still there"). This is the only write path added in Phase 16 and it reuses Phase 14's orchestrator.

- **D-05: Switcher POST controller is a plain controller, not a LV event.** Route: `post "/organizations/switch"`, handler: `MyAppWeb.OrganizationSwitchController.update/2`, body: `%{"organization_id" => id, "return_to" => path}`. Delegates to `MyApp.Organizations.set_active_organization(conn, org)` (the thin wrapper's defdelegate from Phase 14 D-19). Redirects to `return_to` after the session pointer is updated, with `return_to` validated as a local path (same pattern as `SudoController.create/2`). Matches ORG-UX-03 and v1.0 D-29 "sensitive mutation via POST" convention.

- **D-06: Route ordering in the generated router.** `POST /organizations/switch` is defined **before** the `scope "/organizations/:org"` block so Phoenix's definition-order matching doesn't interpret `switch` as a slug. Reserved-slug list also protects the data layer: Phase 16 adds `"orgs"`, `"organizations"`, `"switch"` to `Sigra.Organizations.default_reserved_slugs/0` (tiny Phase 13 follow-up applied here rather than as a separate phase).

### Landing Page & First-Org Signup

- **D-07: `OrganizationsLive.Index` is a single unified LiveView at `/organizations` serving four entry points.** One mount handles: (a) post-signup zero-org, (b) login with zero orgs, (c) login with 2+ orgs without a resume pointer, (d) stale-pointer recovery producing zero or multiple orgs. Three render branches keyed on `(memberships, pending_invitations)`:
  - `([], [])` → hero "Create your first organization" form prominent (matches the 0-org flash copy from Phase 14 D-09)
  - `([], [_|_])` → "You have N pending invitation(s)" list with Accept buttons + secondary collapsed "or create your own organization" card
  - `([_|_], _)` → picker list with "Open" buttons (each posts to `/organizations/switch`) + "+ New organization" secondary CTA + pending-invite section

  **Why one LV:** Phase 14 D-09 already commits `/organizations` as the `:no_active_org` redirect target. Every entry point funnels through that flash. One LV with three render branches collapses five flows into one mount; splitting into `/organizations`, `/organizations/new`, `/organizations/invitations` would force a second redirect on the zero-org case (every D-09 trigger becomes two redirects) and fragment the customization surface.

- **D-08: ORG-UX-09 "optional create-first-org at signup" costs zero lines in `registration_live.ex`.** The "optional" property falls out of Phase 14's existing plumbing rather than being inlined as a registration-form field, wizard step, or modal. Flow:
  ```
  POST /users/register → account created + auto-login
    → create_session/4 runs select_active_organization/3 → {:none, :zero_orgs}
    → redirect to post-login landing (example app: "/")
    → "/" is under :require_org pipeline → RequireMembership sees nil active_org
    → AuthErrorHandler :no_active_org (Phase 14 D-09) → flash + redirect ~p"/organizations"
    → OrganizationsLive.Index zero-state branch → create form (or close tab, which is the "optional" escape)
  ```
  This structurally eliminates the Jetstream #117 "auto-personal-org coupling" regression because there is no code path that creates an org during user registration. Invitation-signup (Phase 17) naturally bypasses the landing because the invitee lands with a membership already (`select_active_organization/3` returns `{:ok, org}`).

- **D-09: RegistrationLive stays byte-for-byte untouched.** The most-customized generated file in the installer gets zero new fields, zero new assigns, zero new events in Phase 16. Host devs who want required-first-org enforce it by adding `:require_org` gates on their routes (customizing one LV template), not by editing registration.

### Settings Page (Rename / Slug / Soft-Delete)

- **D-10: Single-page three-section layout mirroring v1.0 `SettingsLive`.** Route: `live "/organizations/:org/settings", OrganizationSettingsLive, :edit`. Sections stacked vertically: General (rename) / Slug / Danger Zone (soft-delete). Same styling hooks as v1.0 settings (`bg-gray-50 p-4 rounded-lg border` per section, `border-l-4 border-red-500` accent on the Danger Zone). No tabs, no sub-routes, no sidebar nav.

  **Why:** v1.0 `settings_live.ex` uses the single-page-sections pattern; Phase 16 should extend the pattern, not invent a parallel one. Diverging would mean two destructive-action conventions in the same generated app.

- **D-11: Sudo re-auth is collected inline via `current_password` field in the same form — NO `RequireSudo` redirect.** v1.0 `SettingsLive` does not wire `RequireSudo` to `/users/settings`; it verifies `current_password` inline per destructive action (`change_password`, etc.). Phase 16 extends this pattern. The new context functions take `password` as an argument, verify via `Sigra.Crypto.verify_password`, and call `confirm_sudo(session.hashed_token)` as a side effect on success — using the **same primitive** `SudoController.create/2` uses. That's not weakening sudo; it's using sudo without the redirect dance. State preservation across redirects becomes a non-problem because there is no redirect.

  **Signatures:**
  ```elixir
  Sigra.Organizations.rename_organization(scope, %{name: new_name})
  Sigra.Organizations.update_slug(scope, %{slug: new_slug, password: pw, confirm_slug: typed})
  Sigra.Organizations.soft_delete_organization(scope, %{password: pw, confirm_name: typed})
  ```
  Rename is a plain inline form with no password (low-risk, matches rename-user in v1.0). The two destructive functions return field-level `{:error, %Ecto.Changeset{}}` on password mismatch or typed-confirm mismatch so the LV rerenders inline errors exactly like v1.0 `change_password`.

- **D-12: Progressive disclosure for destructive actions.** The Slug and Danger Zone sections initially show only a button ("Change slug" / "Delete organization"). Clicking the button flips an LV assign (`@slug_form_open?`, `@delete_form_open?`) that reveals the form with password + typed-confirm fields inline. This enforces intent without a modal, stays testable via `element(...) |> render_click()` + `form(...) |> render_submit(...)`, and composes cleanly with Phase 21 passkey-for-sudo (the `password` field becomes `password_or_passkey_assertion` — the function branches on which was submitted).

- **D-13: 7-day slug-redirect history is backend-only with one warning banner.** The slug form renders a `<.alert kind={:warning}>` that reads: *"Your current slug `{current}` will redirect to the new slug for 7 days, after which it becomes available to other organizations. Links and bookmarks using `{current}` will continue to work during that window."* No cross-request UX state, no pending-mutation ribbon, no history list (deferred — can be added in v1.2 if operators ask). The slug-history backend (aliases table, route resolver, expiry sweeper) is produced by the context function's `Ecto.Multi` in the same transaction as the slug update.

### Members List

- **D-14: Responsive `<.table>` from existing core_components with per-row action menu + stock `<.modal>` for confirmations.** Route: `live "/organizations/:org/members", OrganizationMembersLive, :index`. Uses the Phoenix 1.8 `<.table>` component already in `core_components.ex` (LiveStream-aware). Wrapped in `<div class="overflow-x-auto">` for small-screen horizontal scroll. True mobile card-stack layout is deferred to the v1.2 admin UI phase — Phase 16 matches v1.0's desktop-first admin pattern.

  **Page structure:**
  ```
  <.header>Members ({@total_count})</.header>
  <section id="members">
    <.table id="members-table" rows={@streams.members}> ... </.table>
    <.button :if={@has_more}>Load more</.button>
  </section>
  <section id="pending-invitations">
    <h2>Pending invitations</h2>
    <%!-- Phase 17 populates @streams.pending_invitations and adds <.invite_form> above this section --%>
    <.empty_state :if={Enum.empty?(@streams.pending_invitations)}>No pending invitations yet.</.empty_state>
  </section>
  <.modal id="confirm-action" :if={@pending_action}> ... </.modal>
  ```

- **D-15: No schema additions for `status` or `last_active_at`.** The Membership schema stays at Phase 13 D-10's minimal shape (no `status` column, no `last_active_at` column).
  - **Status** is a derived display concern: hardcoded `Active` in Phase 16 (the existence of a membership row IS active). Becomes meaningful in Phase 17 when the page renders a union of memberships + pending invitations with derived status (`Pending` / `Expired`) from timestamps.
  - **Last-active** is sourced via `LEFT JOIN LATERAL` against `user_sessions.last_active_at` filtered by `active_organization_id`. `user_sessions.last_active_at` is already throttle-updated every 5 minutes by `Sigra.Plug.FetchSession` (existing, `fetch_session.ex:162-171`) — zero new schema, zero hot-path writes, already indexed-adjacent.

- **D-16: New library queries for the members view.** `Sigra.Organizations.list_members_with_activity(scope, opts)` returns `[{%OrganizationMembership{user: %User{}}, last_active_at | nil}]`, accepts `:limit` (default 100) and `:offset` (default 0). `Sigra.Organizations.count_members(scope)` returns the total count for the header stat. **Both live in the library** because the cross-schema join (memberships ⋈ users ⋈ user_sessions) is security-adjacent — host apps must not hand-roll a join that could leak `last_active_at` across tenants.

- **D-17: Columns (Phase 16).** Email (from `user.email`), Role (daisyUI `badge` — owner/admin/member with distinct variants), Status (hardcoded `Active` badge), Joined (relative time on `membership.inserted_at`), Last active (relative time on `last_active_at`, "Never" if nil), Actions (per-row `<details class="dropdown dropdown-end">` → "Change role" / "Remove").

- **D-18: Role change via action menu + confirm modal.** Click action menu → "Change role" → modal with role dropdown + confirm button. NOT inline `<select>` (inline change is a footgun for last-owner errors — UI state desync on server rejection). NOT a side drawer (overkill for Phase 16). Inline dropdown is fast but breaks the D-29 "sensitive-mutation-via-POST+confirm" convention; action-menu+modal matches v1.0's feel.

- **D-19: Remove member via action menu + simple confirm modal — NO typed-confirmation.** Modal copy: *"Remove {email} from {org.name}? They will be signed out of this organization immediately."* Typed-email confirmation is NOT required in Phase 16 — member removal is reversible by re-invitation, and typed confirmation is reserved for org-level destructive actions (slug change, soft-delete) per D-29. Matches GitHub org member removal UX.

- **D-20: Last-owner guard surfacing.** When `Sigra.Organizations.change_member_role/3` or `remove_member/2` returns `{:error, :last_owner}`, the LV keeps the modal open and renders an inline error: *"Cannot remove the last owner. Promote another member to owner first."* No client-side preemptive disable of the button — rely on the server guard as source of truth and surface the error when it fires.

- **D-21: Force-logout on member remove** is Phase 13's library responsibility (`remove_member/2` runs an `Ecto.Multi` that deletes the membership AND `DELETE FROM user_sessions WHERE user_id = ? AND active_organization_id = ?`). Phase 16 only calls the wrapper and renders the success flash; SC-4 is satisfied by the library.

- **D-22: Pagination = `LIMIT 100` + "Load more" button via LiveView stream append.** No Flop dep. Median B2B org has ~8 members; 95th has ~50. `LIMIT 100` covers the vast majority, and streaming append via `stream_insert(..., at: -1)` works natively. `@total_member_count` surfaces as a header stat so admins see the total without needing a pager. Flop / sortable columns / cursor pagination can come in v1.2 admin phase when pagination is formalized across all admin LVs.

- **D-23: Phase 17 coupling strategy = stub the invitations section in Phase 16.** One LV, two streams (`@streams.members` and `@streams.pending_invitations`), two sections stacked. Phase 16 renders an empty-state card and a HEEx comment marking the Phase 17 fill-in. Phase 17 adds: (a) an "Invite member" button + form modal, (b) `@streams.pending_invitations` population via `Sigra.Organizations.list_pending_invitations/1`, (c) revoke action per invitation row. **Zero changes to the members section** — Phase 17 is additive. Rejected: unified list with status badge (ugly row-type switching in HEEx), separate `/organizations/:org/invitations` route (splits a coherent admin task), tabbed sections (hides the empty-invite state, doubles URL/state surface).

### Switcher Component & Layout Injection

- **D-24: Switcher is a fully generated function component at `lib/<app>_web/components/org_switcher.ex`. Layout is NOT auto-patched.** The generator writes the file via `Features.Organizations.files/1`; post-install instructions tell the host dev to paste `<.org_switcher current_scope={@current_scope} />` into their `layouts.ex` header. Matches v1.0 Sigra convention (every existing injection anchor targets grammar-stable Elixir files — router, config, conn_case — never `.heex` or HEEx sigils) and matches `phx.gen.auth` convention. Preserves the invariant that every Sigra anchor is grammar-parseable.

  **Why not auto-inject:** string-replacing inside a `~H"""..."""` HEEx sigil is brittle on customized layouts (users may have deleted/renamed `<header>`), re-run idempotency is hard, and it introduces a new anchor class Phase 16 shouldn't be inventing.

- **D-25: Generated switcher component contents** (ORG-UX-02): active org name + role badge at the top, divider, list of other user's orgs (each wrapped in a small `<form action={~p"/organizations/switch"} method="post">` with CSRF + `organization_id` hidden input + `return_to` = current path), divider, "Create organization" link → `/organizations/new`, "Organization settings" link conditionally rendered for owner/admin → `/organizations/:org/settings`. Stateless — reads `current_scope.active_organization`, `current_scope.membership.role`, and a new socket assign `@user_organizations` that generated LVs populate via an `on_mount`.

- **D-26: `on_mount` for `@user_organizations` lives in the generated `UserAuth`.** Parallel to the existing `mount_current_scope` — a new `on_mount :assign_user_organizations` entry that calls `MyApp.Organizations.list_organizations_for_user(user)` and assigns the list. Generated, host-owned (host can filter/reorder). NOT a library `on_mount` — list-for-dropdown is presentation, not security.

- **D-27: Post-install instructions block** (added to `Features.Organizations.post_instructions/2`):
  ```
  Organizations installed!

    1. Add the organization switcher to your app layout.
       In lib/<app>_web/components/layouts.ex, inside the <header>, add:

           <.org_switcher current_scope={@current_scope} />

    2. Organization routes were injected into your router.
    3. Run `mix ecto.migrate` if you haven't already.
    4. Add `:require_org` gates to routes that should force org selection:

           pipe_through [:browser, :require_authenticated_user, :require_active_organization]
  ```

### Library vs Generated Boundary (v1.1+ Precedent)

- **D-28: Sigra UI Ownership Rule (v1.1+).** This phase establishes a project-level rule applied conservatively in Phase 16 and binding on Phases 17 / 19 / 20 / 21:
  1. **Library owns** shared security-adjacent request-time wiring: plugs, `on_mount` handlers, and the context functions they call. (Matches Phase 14 D-22.)
  2. **Generated (host-owned)** owns page-level LiveViews, domain-specific presentation (tables, forms, lists), `core_components.ex`, layouts, and email templates.
  3. **Promotion to library** is allowed only when (a) three or more phases would reuse the piece, OR (b) behavior is security-sensitive and a buggy host copy would be a vulnerability, OR (c) the piece is a narrow a11y/keyboard widget primitive in the `LiveSelect` / `LiveToast` class. Default to generated when in doubt.

- **D-29: Phase 16 application of the rule — zero new library UI components.** The only library additions are `Sigra.Plug.LoadOrganizationFromSlug`, `Sigra.LiveView.OrganizationScope` (rule 1), and the new `Sigra.Organizations.*` context functions (Phase 13 D-01). The switcher component, settings LV, members LV, landing LV, confirm modals, and progressive-disclosure inline forms are all **generated and host-owned**. No library function components, no library LiveComponents. Phases 17 / 19 / 20 / 21 may promote pieces to the library as they meet the 3+-consumer criterion — the rule is the precedent, not a specific library component.

- **D-30: Rejected promotion candidates in Phase 16.** The following were considered and rejected under D-28:
  - `Sigra.Components.org_switcher/1` (library FC + generated delegating wrapper): rejected because the switcher has only one consumer in Phase 16 and restyling headers is the single most common host customization.
  - `Sigra.LiveComponents.TypedConfirmDialog`: rejected because D-12 uses inline progressive disclosure instead of a modal dialog, so there are zero Phase 16 consumers. Reconsider in Phase 17 (invitation revoke) or Phase 21 (passkey removal) if modal-based typed confirm becomes necessary.
  - `Sigra.LiveHelpers.*`: rejected namespace — Phoenix 1.8 bans `Helpers` module suffixes. Any future shared `on_mount` helpers use `Sigra.LiveView.*`.

### Claude's Discretion

- **CD-01:** Exact file paths for the two new library modules (`lib/sigra/plug/load_organization_from_slug.ex` vs a sub-namespace). Behavior is fixed by D-03.
- **CD-02:** Whether `OrganizationsLive.Index` is one `.ex` file with all render branches or splits the zero-state form into a function component. Behavior fixed by D-07.
- **CD-03:** Exact daisyUI class strings on the switcher dropdown (`dropdown dropdown-end`, `menu menu-sm`, etc.) — pick what reads best with v1.0's existing template aesthetic.
- **CD-04:** Modal component implementation — stock `<.modal>` from core_components vs daisyUI `<dialog>` — planner picks based on what `core_components.ex` already ships in `phx.new 1.8`.
- **CD-05:** Whether `@user_organizations` lives on the socket assign (D-26) or is fetched per-render in the switcher component. Assign is cheaper per-render, fetch is simpler. Planner picks.
- **CD-06:** Sorting order of the members list (join date desc vs alphabetical by email). v1.1 default — v1.2 may introduce sortable columns.
- **CD-07:** Whether `:require_active_organization` pipeline macro is auto-injected into the router or just documented in post-install instructions. Planner picks based on how aggressive Phase 16 wants to be about router edits.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Requirements & Roadmap
- `.planning/REQUIREMENTS.md` lines 38–46 — **ORG-UX-01 through ORG-UX-09**. Source of D-01 (route structure), D-05 (switcher POST), D-07 (landing branches), D-08 (ORG-UX-09 optional first-org), D-10–D-13 (settings), D-14–D-23 (members).
- `.planning/ROADMAP.md` Phase 16 entry (lines 134–146) — goal, depends-on Phases 13/14/15, success criteria, pitfall O-5.

### Prior Phase Context
- `.planning/phases/13-organizations-schemas-context/13-CONTEXT.md` — D-01/D-02 library-first philosophy (source of D-28); D-06–D-09 slug rules (source of D-06 reserved-slug addendum); D-10–D-11 Membership schema (source of D-15); D-12 Invitation derived status (source of D-23); D-18 auto-owner on create; D-20 `log_safe/2` call sites.
- `.planning/phases/14-org-plugs-scope-hydration/14-CONTEXT.md` — D-03 no cookie mirror (source of D-02); D-09 `:no_active_org` → `~p"/organizations"` redirect (source of D-07/D-08); D-11–D-14 0/1/2+ selector + stale recovery (source of D-07); D-16 `put_active_organization/2` orchestrator (source of D-04/D-05); D-19 `set_active_organization/2` thin wrapper (source of D-05); D-22 library-owns-shared-plumbing rule (source of D-03/D-28 rule 1).
- `.planning/phases/15-audit-integration/15-CONTEXT.md` — audit call sites for org mutations (settings, members) use the real `organization_id` column + `metadata_from_scope/2`.

### Pitfalls
- `.planning/research/PITFALLS.md` §O-5 (switcher-driven session confusion) — mitigated by D-05 (POST switcher) + D-04 (session pointer refreshed only via `put_active_organization/2`).
- `.planning/research/PITFALLS.md` §O-9 (slug squatting) — mitigated by D-06 reserved-slug additions.

### Existing Code
- `priv/templates/sigra.install/core/settings_live.ex` — v1.0 settings pattern anchor (source of D-10, D-11, D-12). Single-page sections, inline password verification, no `RequireSudo` redirect.
- `priv/templates/sigra.install/core/sudo_controller.ex` — sudo primitive that D-11 reuses via `confirm_sudo(session.hashed_token)` side effect.
- `lib/sigra/plug/fetch_session.ex` lines 162–171 — throttled `last_active_at` update. Source of D-15 sourcing decision.
- `priv/templates/sigra.install/core/user_session.ex` — confirms `last_active_at` and `active_organization_id` fields exist on `user_sessions` (D-15).
- `test/example/lib/example_web/components/core_components.ex` — the `<.table>` component used by D-14. The `<.modal>` used by D-18/D-19.
- `test/example/lib/example_web/components/layouts.ex` — the host layout that D-24 does NOT patch.
- `lib/sigra/install/features/core.ex` — injection convention anchor (routes auto, UI touchpoints manual). D-24 matches this split.
- `lib/sigra/install/injector.ex` — available anchors (no HEEx/layout anchor exists; confirms D-24's reasoning).
- `priv/templates/sigra.install/organizations/organizations.ex` — the thin wrapper that gains `set_active_organization/2` defdelegate (Phase 14 D-19, unchanged here).

### Ecosystem References
- [Phoenix 1.8 Scopes guide](https://hexdocs.pm/phoenix/scopes.html) — documents `route_prefix: "/organizations/:org"`, `route_access_path: [:organization, :slug]`, `@derive {Phoenix.Param, key: :slug}`, and `assign_org_to_scope` plug as the idiomatic pattern. **Source of D-01.**
- [Phoenix.VerifiedRoutes](https://hexdocs.pm/phoenix/Phoenix.VerifiedRoutes.html) — `~p"/organizations/#{@org}/members"` compile-time verification.
- [Laravel Jetstream #117](https://github.com/laravel/jetstream/issues/117) — auto-personal-team coupling regression. Source of D-08 structural avoidance.
- [Clerk onboarding flow docs](https://clerk.com/docs/guides/development/add-onboarding-flow) — post-register redirect precedent for D-08.
- [phx.gen.auth source](https://github.com/phoenixframework/phoenix/tree/main/priv/templates/phx.gen.auth) — no layout edits convention. Source of D-24.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **`<.table>` in `core_components.ex`** — LiveStream-aware, used by D-14. No new table component needed.
- **`<.modal>` in `core_components.ex`** — used by D-18/D-19 for role-change and remove confirmations. No new dialog component needed.
- **`user_sessions.last_active_at`** — already throttle-updated; source for D-15 / D-16 `list_members_with_activity/2`.
- **`Sigra.Plug.put_active_organization/2`** (Phase 14 D-16) — the only write site for the active-org session column. D-04 delegates to it.
- **`Sigra.Organizations.set_active_organization/2`** (Phase 14 D-19 thin wrapper defdelegate) — D-05 switcher controller calls it.
- **`Sigra.Crypto.verify_password/2` + `confirm_sudo/1`** — D-11 reuses these for inline sudo.
- **`Sigra.Plug.RequireMembership`** (Phase 14 D-05) — applied per route (`:owner` on settings, `[:owner, :admin]` on members). Already ships role-filter semantics.
- **`Features.Organizations` stub** (Phase 13 D-21) — Phase 16 fills in `files/1`, `injections/1`, `post_instructions/2`.
- **`Sigra.Install.Injector` anchors** (`:before_last_end` for router, `:elixir_config`, etc.) — D-24 confirms no HEEx/layout anchor exists and keeps it that way.

### Established Patterns
- **Single-page sections for settings** (v1.0 `settings_live.ex`) — D-10 extends it.
- **Inline `current_password` for destructive mutations** (v1.0 `Auth.change_password/3`) — D-11 extends it.
- **POST controllers for sensitive mutations** (v1.0 D-29) — D-05 matches.
- **Thin wrapper delegates to library** (Phase 13 D-01) — D-05/D-11 follow it.
- **Shared library plugs/on_mount for request-time wiring** (Phase 14 D-22) — D-03 extends it to URL-driven scope loading.
- **Routes auto-injected, UI touchpoints manual** (Phase 11 / v1.0 Core injection convention) — D-24 matches.

### Integration Points
- **Router** — new `scope "/organizations/:org"` block + `POST /organizations/switch` + `/organizations` landing, all auto-injected via `Features.Organizations.injections/1`.
- **Generated `user_auth.ex`** — gains `on_mount :assign_user_organizations` (D-26).
- **Generated `organizations.ex` wrapper** — unchanged from Phase 14 (already has `set_active_organization/2`).
- **Generated `layouts.ex`** — unmodified by installer; host pastes `<.org_switcher />` per post-install instructions (D-24).
- **Generated `core_components.ex`** — unmodified by Phase 16; reuses existing `<.table>` and `<.modal>`.
- **`Sigra.Organizations` context** — gains 5 new public functions (D-11, D-16).
- **`default_reserved_slugs/0`** (Phase 13) — adds `"orgs"`, `"organizations"`, `"switch"` (D-06).

</code_context>

<specifics>
## Specific Ideas

- **The route structure decision is the most architecturally load-bearing call in Phase 16.** D-01 + D-02 + D-04 together add a new URL-driven scope layer on top of Phase 14's session-driven layer. The reframe ("URL = per-request, session = resume pointer") is the coherent story that preserves every Phase 14 decision while unlocking shareable deep links, multi-tab-multi-org, and the Phoenix 1.8 scopes-guide idiom. This reframe should be documented crisply in the planning doc and the eventual `guides/organizations.md` so host devs understand which layer writes what.

- **D-08 makes ORG-UX-09 free.** The "optional create-first-org at signup" requirement costs zero lines in `registration_live.ex` because every entry point funnels through Phase 14's existing `:no_active_org` redirect. This is the most elegant part of the plan and should be called out in the SUMMARY.md.

- **D-11 is a deliberate consistency choice.** ORG-UX-04 and ORG-UX-05 read "sudo re-auth required," which a naive reader would interpret as a GitHub-style full-page redirect. v1.0 Sigra's actual sudo-in-settings convention is inline `current_password` verification + `confirm_sudo/1` side effect. Phase 16 follows the v1.0 convention, not the naive reading. The context functions return field-level changeset errors so the LV renders inline validation, no state preservation across redirects.

- **D-15 is a deliberate non-change.** No new columns on `OrganizationMembership`, no `status` field, no `last_active_at` field. Status is derived. Last-active comes from `user_sessions.last_active_at` which already exists and is already updated on the hot path. The members query joins instead of denormalizing.

- **D-28 is Phase 16's most durable artifact.** The Sigra UI Ownership Rule binds Phases 17 / 19 / 20 / 21. Applied conservatively in Phase 16 (zero new library UI components), it gives future phases a crisp criterion for promotion (3+ consumers OR security-sensitive OR narrow widget primitive). Without this rule, every v1.1+ phase would re-debate the library-vs-generated boundary.

- **The switcher component is intentionally NOT library-owned.** Under D-28 rule 3, the switcher has only one consumer in Phase 16 and is not acutely security-sensitive (the security is in the POST controller). Restyling the header is the single most common host customization. Fully generated + post-install instructions wins on DX, matches v1.0 precedent, and avoids introducing a new `Sigra.Components.*` namespace in the same phase that introduces URL-driven routing and the injection contract for `Features.Organizations`.

- **Phase 17 will fill in the pending-invitations section** without changing any Phase 16 file structure. The stub stream + HEEx comment in `OrganizationMembersLive` and the invitations render branch in `OrganizationsLive.Index` are the seams.

</specifics>

<deferred>
## Deferred Ideas

### Phase 17: Invitations Flow
Phase 16 stubs the pending-invitations sections in both `OrganizationsLive.Index` and `OrganizationMembersLive`. Phase 17 plugs in: HMAC token generation, email template, accept/reject LV, revoke action, rate-limited creation, and populates the Phase 16 stubs additively (no file renames, no moves).

### Phase 17 or 18: `:require_active_organization` pipeline macro
If auto-injecting the pipeline into the router (CD-07) proves valuable, capture it as part of Phase 17 or 18's router injection work. Phase 16 may document it in post-install instructions only.

### v1.2: Admin UI phase
- Mobile-first card-stack members layout
- Flop-based sortable paginated tables
- Sidebar navigation for settings (if section count grows past ~5)
- Per-member detail side drawer with audit trail + session list
- Slug-history list inside the slug form (last N changes + expiry timestamps)
- Bulk member actions (bulk remove, bulk role change, bulk invite)

### v1.2 admin impersonation
The `OrganizationSwitcherLive` precedent (generated component, host pastes into layout, no auto-patching) should extend to the admin impersonation banner. The **security contract** (you cannot dismiss the banner without hitting the library-owned "stop impersonating" endpoint) lives in the controller + `on_mount`, not in the HEEx.

### Phase 21: passkey-for-sudo
D-12's progressive-disclosure form has `password` as a field. Phase 21 extends the context functions to accept `password_or_passkey_assertion` and branches on which was submitted. Same inline-verification pattern, same `confirm_sudo/1` side effect, no redirect.

### Future: library-owned UI primitives
Under D-28 rule 3, pieces can promote to library ownership when reuse hits 3+ phases. Candidates to watch:
- **`Sigra.Components.org_switcher/1`** — reconsider if v1.2 admin phase adds a parallel admin switcher.
- **`Sigra.LiveComponents.TypedConfirmDialog`** — reconsider in Phase 17 (invitation revoke) and Phase 21 (passkey removal). If both want modal-based typed confirm, promote.
- **`Sigra.Components.passkey_button/1`** — likely promoted in Phase 21 under "security-sensitive, a11y primitive."

### Future: revisit UI Ownership Rule (D-28) after v1.1 ships
The rule is written conservatively and may be too restrictive in practice. Revisit after v1.1 GA with concrete data on which pieces hosts actually restyle vs. leave alone. v1.2 admin phase is a natural trigger point.

</deferred>

<downstream>
## Downstream Phase Implications

### Phase 17 (Invitations)
- Members LV already has `@streams.pending_invitations` + empty-state + HEEx comment seam. Phase 17 adds: `list_pending_invitations/1` library query, "Invite member" header button, invite-form modal, revoke action per row. Zero file moves, zero Phase 16 test changes.
- `OrganizationsLive.Index` already has a pending-invitations render branch. Phase 17 wires it to `list_pending_invitations_for_email/1`.
- Invitation accept LV lives at `/invitations/:token/accept`, unscoped. It's NOT inside the `/organizations/:org` scope block because the invitee is not yet a member.
- Invite-signup (invitee registers via email link) bypasses `OrganizationsLive.Index` entirely because `select_active_organization/3` returns `{:ok, org}` with membership already in place.

### Phase 18 (`--no-organizations` flag + backfill)
- `Features.Organizations.enabled?/1` already gates `files/1`, `injections/1`, `post_instructions/2`. Phase 18 adds the flag wiring.
- No layout rollback needed because D-24 never patched layouts in the first place.
- The reserved-slug additions (D-06) survive `--no-organizations` because they're in the library module, not the generator.

### Phase 19/20/21 (Passkeys)
- D-28 Sigra UI Ownership Rule is the precedent for passkey UI. `PasskeyEnrollmentLive` + `PasskeyAuthenticationLive` are generated. The passkey-ceremony JS hook + potentially `<.passkey_button />` may promote to library under rule 3 (narrow security-sensitive primitive) — decide at Phase 21 planning time.
- Phase 21 `confirm_sudo` extension: D-11's context functions extend naturally to accept passkey assertions alongside passwords.

### v1.2 (Admin Dashboard)
- D-28 rule binds: admin LiveViews are generated under the admin phase. Admin impersonation banner follows D-24 pattern (generated component, manual layout paste, library-owned security contract in the controller).
- D-24's post-install instructions pattern extends: every v1.2 generated UI touchpoint gets listed in an instructions block, never auto-patched.

</downstream>

---

*Phase: 16-org-liveviews-switcher*
*Context gathered: 2026-04-13*
