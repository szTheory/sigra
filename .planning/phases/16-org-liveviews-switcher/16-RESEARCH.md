# Phase 16: Org LiveViews + Switcher — Research

**Researched:** 2026-04-12
**Domain:** Phoenix 1.8 LiveView UX for multi-tenant organizations on top of Sigra's Phase 13/14 library-owned org context and scope-hydration plugs.
**Confidence:** HIGH (behaviors are fully constrained by 16-CONTEXT.md, which locks 30 decisions and lists every canonical reference; this research verifies each against the actual codebase and surfaces one gap + five small constraints the planner must respect).

## Research Summary

The planner should lock in these eight items before writing any PLAN:

1. **CONTEXT.md D-01..D-30 are authoritative and locked.** This research confirms every decision is implementable against the current codebase with one exception (item 3). Do not re-open decisions.
2. **SC-4 force-logout is NOT yet in `Sigra.Organizations.remove_member/3`.** Phase 16 must extend it (or add an out-of-band step in the Multi) because `remove_member` today only deletes the membership + emits audit — no session purge. See §5.
3. **`<.modal>` does not exist in the example app's `core_components.ex`.** CD-04 is discretionary but the practical answer is: ship a minimal generated `<.modal>` component into `core_components.ex` via a Phase 16 injection OR use a daisyUI `<dialog>` element directly. Do NOT hand-wave that core_components ships one — phx.new 1.8 does not. See §6.
4. **URL slug plug + on_mount are net-new library modules** (`Sigra.Plug.LoadOrganizationFromSlug`, `Sigra.LiveView.OrganizationScope`). Phase 14 did not ship these; grepping Phase 14 artifacts confirms zero references.
5. **Route ordering is load-bearing.** `POST /organizations/switch` and `/organizations` (landing) must be declared **before** `scope "/organizations/:org"` in the generated router, otherwise `switch` / empty will match `:org`. D-06 locks this.
6. **Inline sudo pattern (D-11) has a concrete precedent to copy:** `priv/templates/sigra.install/core/settings_live.ex` (v1.0) + `priv/templates/sigra.install/core/sudo_controller.ex` — both verified. The destructive context functions take `password` as an argument, verify via `Sigra.Crypto.verify_password/2`, then call `context.confirm_sudo(session.hashed_token)` (exactly what SudoController.create/2 does at line 30). No redirect.
7. **`last_active_at` source is already hot-path-updated** by `Sigra.Plug.FetchSession` at `lib/sigra/plug/fetch_session.ex:164-170` on a ~5-minute throttle. `list_members_with_activity/2` just LEFT-JOINs it — zero new schema, zero new writes.
8. **Nyquist validation is enabled** (`.planning/config.json` `workflow.nyquist_validation: true`). Phase 16 ships a `16-VALIDATION.md` mapping each ORG-UX requirement to a LiveViewTest file; §10 below specifies the mapping.

## User Constraints (from CONTEXT.md)

### Locked Decisions (verbatim D-01..D-30 from 16-CONTEXT.md)

> These are locked. Research THESE, not alternatives. The full text lives in `.planning/phases/16-org-liveviews-switcher/16-CONTEXT.md`; this section summarizes the binding contract for quick reference.

**Routing & URL-Driven Scope**
- **D-01** Use Phoenix 1.8 scopes guide idiom — `scope "/organizations/:org", MyAppWeb do ... end` + `pipe_through [Sigra.Plug.LoadOrganizationFromSlug]` (+ LV on_mount parallel).
- **D-02** URL slug = per-request active org; session column = resume pointer. URL plug delegates to `put_active_organization/2` to refresh the session pointer.
- **D-03** New library modules: `lib/sigra/plug/load_organization_from_slug.ex` + `lib/sigra/live_view/organization_scope.ex`; both accept `:scope_param` (default `"org"`).
- **D-04** Slug not found → 404. Slug found but not a member → 404. Slug differs from session pointer but user IS a member → assign + refresh pointer via `put_active_organization/2`.
- **D-05** Switcher POST is a plain controller (`MyAppWeb.OrganizationSwitchController.update/2`, body `%{"organization_id" => id, "return_to" => path}`), delegates to thin-wrapper `set_active_organization/2`, redirects to local-path-validated `return_to`.
- **D-06** Route ordering: `POST /organizations/switch` + `/organizations` landing **before** `scope "/organizations/:org"`. Reserved-slug addendum: `"orgs"`, `"organizations"`, `"switch"` added to `Sigra.Organizations.Slug.default_reserved_slugs/0`.

**Landing & First-Org Signup**
- **D-07** Single `OrganizationsLive.Index` at `/organizations` with three render branches keyed on `(memberships, pending_invitations)`: zero/zero → hero create form; zero/invites → invite list + collapsed create card; some/any → picker + create CTA + invite section.
- **D-08** ORG-UX-09 is free — no changes to `registration_live.ex`. Flow: register → auto-login → `select_active_organization/3` returns `{:none, :zero_orgs}` → `/` → `RequireMembership` → `:no_active_org` → `~p"/organizations"` → Index zero-state. Invitation-signup bypasses because `select_active_organization/3` returns `{:ok, org}`.
- **D-09** `RegistrationLive` stays byte-for-byte untouched.

**Settings (Rename / Slug / Soft-Delete)**
- **D-10** Single page, three stacked sections (General / Slug / Danger Zone). Route: `live "/organizations/:org/settings", OrganizationSettingsLive, :edit`. Mirror v1.0 `SettingsLive` styling (`bg-gray-50 p-4 rounded-lg border`, `border-l-4 border-red-500` on Danger Zone).
- **D-11** Inline `current_password` per destructive mutation — NO `RequireSudo` redirect. Context functions: `rename_organization(scope, attrs)`, `update_slug(scope, %{slug, password, confirm_slug})`, `soft_delete_organization(scope, %{password, confirm_name})`. Destructive functions verify via `Sigra.Crypto.verify_password/2` and call `confirm_sudo(session.hashed_token)` on success.
- **D-12** Progressive disclosure: slug + delete sections show a button; clicking flips `@slug_form_open?` / `@delete_form_open?` to reveal the form. Composes with Phase 21 passkey-for-sudo.
- **D-13** Slug-redirect history is backend-only with one warning banner. Slug-history + alias rows + expiry are produced by `update_slug`'s `Ecto.Multi`.

**Members List**
- **D-14** `<.table>` + `<.modal>` from `core_components.ex` in a responsive `<div class="overflow-x-auto">`. Route: `live "/organizations/:org/members", OrganizationMembersLive, :index`.
- **D-15** No schema additions to `OrganizationMembership`. Status = hardcoded `Active` in Phase 16. Last-active sourced via LEFT JOIN against `user_sessions.last_active_at` filtered by `active_organization_id`.
- **D-16** New library queries: `list_members_with_activity(scope, opts)` returning `[{membership_with_user, last_active_at | nil}]` with `:limit` (default 100) / `:offset`; `count_members(scope)`.
- **D-17** Columns: Email / Role (daisyUI badge) / Status / Joined / Last active / Actions.
- **D-18** Role change via action menu + confirm modal (NOT inline select).
- **D-19** Remove via action menu + simple confirm modal — NO typed-email confirmation.
- **D-20** Last-owner guard surfaces inline in modal: *"Cannot remove the last owner. Promote another member to owner first."* — no preemptive client disable.
- **D-21** Force-logout on remove is the library's responsibility (Ecto.Multi deletes membership + `DELETE FROM user_sessions WHERE user_id = ? AND active_organization_id = ?`). **Phase 16 must extend `remove_member/3` — see §5 gap.**
- **D-22** `LIMIT 100` + "Load more" via `stream_insert(..., at: -1)`. No Flop.
- **D-23** Phase 17 stub: members LV has `@streams.pending_invitations` + HEEx comment. Phase 16 renders empty-state + comment seam.

**Switcher & Layout**
- **D-24** Switcher is a generated function component at `lib/<app>_web/components/org_switcher.ex`. Layout is NOT auto-patched. Post-install instructions tell the host to paste `<.org_switcher current_scope={@current_scope} />` into their layout.
- **D-25** Switcher contents per ORG-UX-02: active org + role badge, divider, other-orgs list (each wrapped in a `<form action={~p"/organizations/switch"} method="post">` with CSRF + hidden `organization_id` + `return_to` = current path), divider, create-org link, conditional settings link for owner/admin.
- **D-26** New `on_mount :assign_user_organizations` in generated `UserAuth` — calls `MyApp.Organizations.list_organizations_for_user(user)`, assigns the list.
- **D-27** Post-install instructions block added to `Features.Organizations.post_instructions/2`.

**Library vs Generated Boundary**
- **D-28** Sigra UI Ownership Rule (v1.1+): library owns security-adjacent request-time wiring + context functions; generated = page-level LVs, presentation, core_components, layouts, emails. Promotion requires ≥3 consumers OR security-sensitivity OR narrow a11y primitive.
- **D-29** Phase 16 application: zero new library UI components. Only `Sigra.Plug.LoadOrganizationFromSlug`, `Sigra.LiveView.OrganizationScope`, and new `Sigra.Organizations.*` context functions go in the library.
- **D-30** Rejected promotions (stay generated): `Sigra.Components.org_switcher/1`, `Sigra.LiveComponents.TypedConfirmDialog`, `Sigra.LiveHelpers.*` (banned namespace).

### Claude's Discretion (CD-01..CD-07)

- **CD-01** Exact filepath for new library modules (sub-namespace OK).
- **CD-02** Single `.ex` file for `OrganizationsLive.Index` vs extract a function component for the zero-state form.
- **CD-03** daisyUI class strings on the switcher dropdown.
- **CD-04** `<.modal>` implementation — stock core_components vs daisyUI `<dialog>`. **→ See §6: the stock answer is empty in phx.new 1.8; plan must actually ship one.**
- **CD-05** `@user_organizations` on the socket assign vs fetched per-render in the switcher component.
- **CD-06** Default sort order of the members list (join date desc vs alphabetical).
- **CD-07** Auto-inject `:require_active_organization` pipeline macro into the router, or only document in post-install instructions.

### Deferred Ideas (OUT OF SCOPE — DO NOT RESEARCH)

- Phase 17 invitations flow (HMAC tokens, email, accept/reject/revoke, rate limiting). Phase 16 only stubs the pending-invitations sections.
- Phase 18 `--no-organizations` flag + backfill migration.
- Library-owned UI components (`Sigra.Components.*`, `Sigra.LiveComponents.*`).
- Mobile-first card-stack members layout.
- Flop pagination.
- Typed-email confirm for member removal.
- `RequireSudo` redirect flow for settings.
- `OrganizationMembership.status` / `last_active_at` schema columns.
- `Sigra.LiveHelpers` namespace (banned in Phoenix 1.8).

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| ORG-UX-01 | Create org from UI with auto slug + reserved-word rejection | §7 — existing `Sigra.Organizations.create_organization/3` + `Slug.validate_slug_changeset` cover it; Phase 16 adds `"orgs"`, `"organizations"`, `"switch"` to `Slug.default_reserved_slugs/0` (verified at `lib/sigra/organizations/slug.ex:10-14`). Host form lives in `OrganizationsLive.Index` zero-state branch (§2). |
| ORG-UX-02 | Header dropdown switcher, active org + role badge, other orgs, create link, settings link for owner/admin | §6 — generated `org_switcher.ex` function component, daisyUI `dropdown dropdown-end` classes (daisyUI CSS verified at `test/example/priv/static/assets/default.css:1`). D-25 locks the structure. |
| ORG-UX-03 | Switching is POST to plain controller, rotates session `active_organization_id`, redirect to referrer | §1, §2 — `OrganizationSwitchController.update/2` delegates to `set_active_organization/2` (existing defdelegate at `priv/templates/sigra.install/organizations/organizations.ex:42-44`), which calls `Sigra.Plug.PutActiveOrganization.call/3` (verified at `lib/sigra/plug/put_active_organization.ex:87-112`). Uses SudoController's local-path validation pattern (verified at `priv/templates/sigra.install/core/sudo_controller.ex:32-38`). |
| ORG-UX-04 | Owner rename + slug change (sudo + typed-confirm + 7d redirect) | §3 — inline password + typed confirm via progressive disclosure + `confirm_sudo/1` side effect. Slug-redirect history is backend-only (`update_slug` Multi writes alias row + expiry in same tx per D-13). |
| ORG-UX-05 | Owner soft-delete (sudo + typed org-name confirm) | §3, §4 — existing `soft_delete_organization/3` at `lib/sigra/organizations.ex:269-288` sets `deleted_at`; new wrapper-level `soft_delete_organization(scope, %{password, confirm_name})` adds password verification + typed-confirm + `confirm_sudo` side effect. Non-owner = 403 at plug layer via `Sigra.Plug.RequireMembership, roles: [:owner]` (verified at `lib/sigra/plug/require_membership.ex`). |
| ORG-UX-06 | Owner/admin members list (email, role, status, joined, last-active) | §6 — new `list_members_with_activity/2` LEFT-JOINs `user_sessions.last_active_at` where `active_organization_id = ?`. Existing `FetchSession` hot-path throttle at `lib/sigra/plug/fetch_session.ex:164-170` keeps data fresh. |
| ORG-UX-07 | Role change with confirmation | §6 — action menu + confirm modal. Existing `Sigra.Organizations.change_role/4` at `lib/sigra/organizations.ex:355-382` already has the last-owner-on-demote guard (`maybe_guard_last_owner_on_demote`). |
| ORG-UX-08 | Remove member → revoke membership + force-logout that user's org-scoped sessions **in the same `Ecto.Multi`** | §5 — **Phase 13's `remove_member/3` does NOT currently delete sessions.** Phase 16 must extend the Multi with a `Multi.delete_all(:sessions, query)` step. Pattern verified against `lib/sigra/session_stores/ecto.ex:94-108` which has a user-scoped delete but no per-org filter. |
| ORG-UX-09 | No auto-personal-org on signup; optional "create first org" step | §2 — D-08 structurally achieves this with zero `registration_live.ex` edits. Path: register → login → `{:none, :zero_orgs}` → `/` → `:no_active_org` → `~p"/organizations"` → Index zero-state. Verified against `Sigra.Organizations.select_active_organization/3` at `lib/sigra/organizations.ex:497` and Phase 14 D-09 at `.planning/phases/14-org-plugs-scope-hydration/14-CONTEXT.md:82`. |

## 1. LiveView vs Controller Split, and Phoenix 1.8 on_mount + URL scope

**Controllers** (plain HTTP POST/GET):
- `POST /organizations/switch` — `OrganizationSwitchController.update/2` — only this one. Locked by D-05 and ORG-UX-03 (D-29 sensitive-mutation-via-POST convention).

**LiveViews**:
- `live "/organizations", OrganizationsLive.Index, :index` — unscoped. Zero-state, picker, and invite-accept landing all in one mount (D-07).
- `live "/organizations/:org/settings", OrganizationSettingsLive, :edit` — inside `scope "/organizations/:org"`.
- `live "/organizations/:org/members", OrganizationMembersLive, :index` — inside the same scope.

**Phoenix 1.8 idiom for an LV that requires an active org scope** (verified against `test/example/lib/example_web/user_auth.ex:193-231` existing `mount_current_scope` pattern + Phoenix 1.8 scopes guide):

The `live_session` macro in the router names an `on_mount` list. For the `/organizations/:org/...` scope, the planner creates a new `live_session` with two `on_mount`s: the existing `:ensure_authenticated` (already in the example router at line 79) and a new `:ensure_org_scope` handler (the LV-side parallel of `LoadOrganizationFromSlug`). Both read params: plug reads `conn.params["org"]`, on_mount reads the `params` argument to its `on_mount/4` callback.

**How `on_mount` interacts with Phase 14's scope hydration:** Phase 14's `Sigra.Plug.LoadActiveOrganization` runs in the `:browser` plug pipeline and hydrates `scope.active_organization` + `scope.membership` from the session row. When the user navigates to `/organizations/:org/...`, the plug pipeline runs first (populating from session), THEN `LoadOrganizationFromSlug` runs (which reassigns the scope from the URL slug and refreshes the session pointer via `put_active_organization/2`). On the LV side, the `on_mount` callback receives a pre-hydrated `current_scope` from the `live_session`'s `:ensure_authenticated` handler; `:ensure_org_scope` then rebinds `current_scope.active_organization` based on `params["org"]`.

**Sketch — `Sigra.LiveView.OrganizationScope.on_mount/4`** (CD-01 — exact file is `lib/sigra/live_view/organization_scope.ex`):

```elixir
def on_mount({:ensure_org_scope, opts}, %{"org" => slug} = _params, _session, socket) do
  organizations = Keyword.fetch!(opts, :organizations)
  scope_module = Keyword.fetch!(opts, :scope_module)
  config = organizations.__sigra_org_config__()
  scope = socket.assigns.current_scope

  case Sigra.Organizations.get_organization_by_slug(config, slug) do
    nil ->
      {:halt, socket |> Phoenix.LiveView.put_flash(:error, "Organization not found.") |> Phoenix.LiveView.redirect(to: "/")}

    org ->
      case Sigra.Organizations.get_membership(config, scope.user, org) do
        nil ->
          # 404-equivalent for LV: same message as org-not-found (enumeration prevention, D-04)
          {:halt, socket |> Phoenix.LiveView.put_flash(:error, "Organization not found.") |> Phoenix.LiveView.redirect(to: "/")}

        membership ->
          new_scope = scope_module.put_active_organization(scope, org, membership)
          {:cont, Phoenix.Component.assign(socket, :current_scope, new_scope)}
      end
  end
end
```

Note: the LV on_mount cannot call `put_active_organization/2` (no `Plug.Conn`). The **plug layer** refreshes the session pointer on `conn`-based requests; the on_mount only rebinds the scope for the LV process. For LV hot navigation within a `live_session`, the session pointer is already correct because the plug ran on the parent GET that mounted the live_session. For LV navigation across live_sessions (a full-page redirect), the plug runs again.

**Source:** Phoenix 1.8 scopes guide ([hexdocs.pm/phoenix/scopes.html](https://hexdocs.pm/phoenix/scopes.html)), verified against existing `test/example/lib/example_web/user_auth.ex:193-231` `on_mount` pattern and the new `Sigra.Plug.PutActiveOrganization` contract at `lib/sigra/plug/put_active_organization.ex:87-112`. **HIGH confidence.**

## 2. Session Rotation on Org Switch

**What "rotate the active_organization_id" means here:**
- **Plain `put_session/3`?** No — Sigra's session store is database-backed (`Sigra.SessionStore`), not the Plug cookie session. The Plug session cookie holds only `user_token`. The active org lives in the `user_sessions` table column `active_organization_id` (verified at `priv/templates/sigra.install/core/user_session.ex:30`).
- **Session token rotation?** Explicitly NO per `lib/sigra/plug/put_active_organization.ex:30-31`: *"Session token rotation / session renewal — a scope transition is NOT a trust transition (D-18)."* Org switch is not a privilege escalation event. Login rotates the token; org switch does not.
- **What Sigra does instead:** `Sigra.Plug.PutActiveOrganization.call/3` performs exactly three writes atomically (verified at lines 17-24):
  1. `user_sessions.active_organization_id` (via `SessionStore.update_active_organization/3`).
  2. `conn.private[:sigra_session]` (refreshed struct).
  3. `conn.assigns[:current_scope]` (via host scope module's `put_active_organization/3`).

There is no cookie mirror (D-03 of Phase 14). There is no new token. The row write is the rotation.

**Why this is safe:** Membership is re-verified on every request by `LoadActiveOrganization` (stale-pointer recovery at `lib/sigra/plug/load_active_organization.ex:95-122`). If a second browser tab has a cached `current_scope` pointing at an org the user no longer belongs to, the next request on that tab hits the stale-pointer path and recovers cleanly — no 500, no leak.

**Contrast with `phx.gen.auth` 1.8 login:** `phx.gen.auth` rotates the session token on `log_in_user` to prevent session fixation. Sigra follows the same pattern at login (existing `Sigra.Auth.create_session/4`). Org switch deliberately does **not** follow that pattern because there is no trust boundary being crossed — the user is already authenticated for this session.

**Sketch — `OrganizationSwitchController.update/2`:**

```elixir
defmodule MyAppWeb.OrganizationSwitchController do
  use MyAppWeb, :controller

  def update(conn, %{"organization_id" => org_id, "return_to" => return_to}) do
    scope = conn.assigns.current_scope
    config = MyApp.Organizations.__sigra_org_config__()

    with {:ok, org} <- Sigra.Organizations.fetch_organization(config, org_id),
         {:ok, conn} <- MyApp.Organizations.set_active_organization(conn, org) do
      conn |> redirect(to: safe_path(return_to))
    else
      {:error, :not_a_member} ->
        conn |> put_flash(:error, "You are not a member of that organization.") |> redirect(to: ~p"/")

      {:error, :not_found} ->
        conn |> put_flash(:error, "Organization not found.") |> redirect(to: ~p"/")
    end
  end

  defp safe_path(path) when is_binary(path) do
    if String.starts_with?(path, "/") and not String.starts_with?(path, "//"), do: path, else: ~p"/"
  end
  defp safe_path(_), do: ~p"/"
end
```

**Source:** `lib/sigra/plug/put_active_organization.ex` (HIGH); `priv/templates/sigra.install/core/sudo_controller.ex:32-38` (local-path validator pattern, HIGH).

## 3. Typed-Confirmation UX + 7-Day Slug Redirect

**Idiomatic LiveView typed-confirm pattern:** the form has a text field whose `Ecto.Changeset.validate_change/3` asserts the entered value equals a target. This renders inline errors on every keystroke via `phx-change`, exactly like password validation.

**Sketch — `Sigra.Organizations.update_slug/2` signature + validation:**

```elixir
def update_slug(scope, %{slug: new_slug, password: password, confirm_slug: typed}) do
  org = scope.active_organization

  attrs = %{slug: new_slug, password: password, confirm_slug: typed}

  changeset =
    {attrs, %{slug: :string, password: :string, confirm_slug: :string}}
    |> Ecto.Changeset.cast(attrs, [:slug, :password, :confirm_slug])
    |> Ecto.Changeset.validate_required([:slug, :password, :confirm_slug])
    |> Ecto.Changeset.validate_change(:confirm_slug, fn :confirm_slug, typed ->
      if typed == org.slug, do: [], else: [confirm_slug: "must match the current slug #{org.slug}"]
    end)
    |> validate_password(password, scope.user)

  with {:ok, _} <- Ecto.Changeset.apply_action(changeset, :update) do
    # Runs the slug-history Ecto.Multi: update org.slug + insert alias row
    # {old_slug, org_id, expires_at: now + 7 days} + call confirm_sudo(session.hashed_token)
    Multi.new()
    |> Multi.update(:organization, Ecto.Changeset.change(org, slug: new_slug))
    |> Multi.insert(:alias, build_slug_alias(org.slug, org.id, days: 7))
    |> append_audit(...)
    |> repo.transaction()
  end
end
```

The LV handles field-level errors by rendering `<.input field={@form[:confirm_slug]} type="text" label={"Type '#{@org.slug}' to confirm"} />` and the changeset error surfaces inline per v1.0 convention.

**7-day redirect mechanism:**
- `update_slug`'s `Ecto.Multi` inserts a row into a `organization_slug_aliases` table (schema: `old_slug`, `organization_id`, `expires_at`).
- `LoadOrganizationFromSlug` (§1), on slug miss, does a secondary lookup in the aliases table. If found and not expired, it 301-redirects to the canonical slug URL.
- An Oban worker (optional, since Oban is optional — inline fallback is `nil`) sweeps expired rows.

**Note on schema additions:** Phase 13 CONTEXT D-11 lists only organizations/memberships/invitations in the initial migration. The `organization_slug_aliases` table is a Phase 16 schema addition — the planner must add a migration (adapter-branched per PG/MySQL/SQLite convention) and a new schema module. This is unmentioned in 16-CONTEXT.md D-13 but is the only way "backend-only slug-history" is actually implementable; the CONTEXT appears to assume the planner will add it under D-13. Flag this to the user.

**Source:** Ecto 3.13 `Changeset.validate_change/3` ([hexdocs.pm/ecto/Ecto.Changeset.html](https://hexdocs.pm/ecto/Ecto.Changeset.html)); v1.0 `settings_live.ex` password validation precedent at `priv/templates/sigra.install/core/settings_live.ex:98-102`. **HIGH confidence** on the form pattern, **MEDIUM confidence** that D-13 expects a new aliases table — flag in Assumptions Log.

## 4. Last-Owner Guard Enforcement + UI Mirror

**Library-layer enforcement** is already in place:
- `remove_member/3` uses `guard_last_owner/3` as the first `Multi` step (verified at `lib/sigra/organizations.ex:330-331`).
- `change_role/4` uses `maybe_guard_last_owner_on_demote/3` when new_role != :owner (verified at `lib/sigra/organizations.ex:361-362`).
- Both return `{:error, :last_owner}` on guard failure — the Multi is rolled back before any delete/update.

**What "mirror" means in the UI per D-20:** NOT preemptive client-side disable. The LV clicks Open Modal → click Confirm → calls the context → on `{:error, :last_owner}` the modal stays open and the LV renders `<.alert kind={:error}>Cannot remove the last owner. Promote another member to owner first.</.alert>` inside the modal body. Server is source of truth. This avoids the desync where optimistic UI thinks there are 2 owners but a concurrent request just demoted one.

**Source:** verified in `lib/sigra/organizations.ex` lines 327-347 and 355-382. **HIGH confidence.**

## 5. Force-Logout on Member Removal (GAP)

**⚠️ GAP: `remove_member/3` does NOT currently delete user_sessions.**

Verified by reading `lib/sigra/organizations.ex:327-347` and grepping `user_session|delete_all_for_user|force_logout|active_organization_id` across the file — only `select_active_organization` references `active_organization_id`. The Multi today is:

```
guard_last_owner → delete(:membership) → append_audit → transaction
```

ORG-UX-08 requires: *"revoke the membership row and force-log-out that user's org-scoped sessions in the same `Ecto.Multi`."* D-21 asserts this is Phase 13's library responsibility, but Phase 13 did not ship it.

**Phase 16 must extend `Sigra.Organizations.remove_member/3`** with a `Multi.delete_all` step that deletes from `user_sessions` where `user_id = membership.user_id AND active_organization_id = membership.organization_id`. The column is nullable and indexed (verified in `priv/templates/sigra.install/core/add_active_organization_id_to_user_sessions.exs`).

**Sketch:**

```elixir
def remove_member(config, scope, membership) do
  session_schema = config.schemas[:user_session] # NEW: must be added to the config schemas keyword

  Multi.new()
  |> guard_last_owner(membership.organization_id, membership.id, config)
  |> Multi.delete(:membership, membership)
  |> Multi.delete_all(
    :revoked_sessions,
    from(s in session_schema,
      where: s.user_id == ^membership.user_id and s.active_organization_id == ^membership.organization_id
    )
  )
  |> append_audit(config, "organization.member_remove", scope, metadata: %{user_id: membership.user_id})
  |> config.repo.transaction()
  |> normalize_multi_result()
end
```

**Design questions for the planner:**
1. **Schema config extension:** `Sigra.Organizations` config schema (`@org_config_schema`) currently has no `user_session` key. Planner must either (a) add `user_session` to the schemas keyword, or (b) read it indirectly via the session store module. Option (a) is simpler and matches the pattern of existing schema declarations.
2. **Partial-logout semantics:** this deletes sessions where `active_organization_id = removed_org`. A user who has OTHER sessions (no active org, or a different active org) is not logged out globally. This is correct behavior — you lose access to the org you were removed from, not your entire account.
3. **Running sessions' active_organization_id nullification vs deletion:** the SC-4 spec says "force-log-out sessions." Deletion is the hard answer. An alternative (nullify the active_organization_id, leave the session alive) is softer but doesn't force a logout. **Recommend: delete.** This matches the word "force-logs-out" in both ORG-UX-08 and SC-4.
4. **Cross-session same-user:** a user can have multiple sessions with the same active_organization_id (e.g., phone + laptop). The `delete_all` nukes all of them, which is correct.

**Alternative:** use `Sigra.SessionStore.delete_all_for_user/2` outside the Multi after a successful delete. Rejected because (a) ORG-UX-08 explicitly says "in the same Ecto.Multi" and (b) if the SessionStore call fails the membership delete still committed — inconsistent state.

**Action for the planner:** lift this into a PLAN-level task with a unit test that: inserts two user_session rows (both active_organization_id = org_id), calls `remove_member`, asserts both are gone. Ship a second test that inserts a session with `active_organization_id = different_org` and asserts it survives.

**Source:** gap identified via direct code read of `lib/sigra/organizations.ex:327-347` (HIGH confidence that the code is absent). **HIGH confidence gap is real.**

## 6. Header Dropdown Switcher Component

**Library or shared component?** Generated (host-owned) per D-24/D-29. Fully fresh file at `lib/<app>_web/components/org_switcher.ex`. Not a LiveComponent — just a stateless function component.

**How it receives org list + active org:** via two assigns populated by on_mounts:
- `@current_scope` — from the existing `mount_current_scope` on_mount (Phase 14).
- `@user_organizations` — from the new `on_mount :assign_user_organizations` in generated `UserAuth` (D-26).

Both are socket assigns. The switcher component reads `@current_scope.active_organization`, `@current_scope.membership.role`, and `@user_organizations` — no DB hit in render.

**CD-05 resolution (recommend):** assign on socket. `list_organizations_for_user/2` at `lib/sigra/organizations.ex:420-432` is a small join query — paying it once per live_session mount is fine. Re-fetching in the component would run on every patch/update.

**Phoenix 1.8 layout slot conventions:** Phoenix 1.8 generated layouts (`layouts.ex`) use `~H` sigils and do not use named slots for header widgets — the host edits the header directly. D-24 confirms: no layout auto-patching; post-install instructions tell the host to paste `<.org_switcher current_scope={@current_scope} user_organizations={@user_organizations} />` inside the `<header>` in `layouts.ex`.

**`<.modal>` reality check (CD-04):** **phx.new 1.8 stripped modal out of `core_components.ex`.** Verified by reading the 473-line `test/example/lib/example_web/components/core_components.ex`: it contains `flash`, `button`, `input`, `header`, `table`, `list`, `icon` — **no `modal`, no `alert`, no `badge`**. The example app uses daisyUI CSS for these (`test/example/priv/static/assets/default.css`).

D-14 and D-18/D-19 assume `<.modal>` ships in core_components. It does not. Two options for the planner:
1. **Ship a minimal `<.modal>` function component** in Phase 16 via an injection into `core_components.ex` under an anchor. This is new injection territory; Phase 16 CONTEXT D-24 says "no HEEx/layout anchor exists and keeps it that way," so this would violate the precedent.
2. **Use daisyUI `<dialog>` directly** in `OrganizationMembersLive` and the settings danger zone. daisyUI ships a `<dialog class="modal">` component that works with LiveView via `JS.dispatch("showModal")` / `JS.dispatch("close")`. Recommended approach — zero new injection surface, and daisyUI is already present in the example. CD-04 discretion explicitly allows this.

**Recommend CD-04 = daisyUI `<dialog>`.** Matches the "zero new library UI components" posture of D-29.

**Sketch — switcher component (CD-03 daisyUI classes):**

```heex
<div class="dropdown dropdown-end">
  <div tabindex="0" role="button" class="btn btn-ghost">
    {@current_scope.active_organization.name}
    <span class="badge badge-sm">{@current_scope.membership.role}</span>
  </div>
  <ul tabindex="0" class="dropdown-content menu menu-sm bg-base-100 rounded-box z-[1] w-52 p-2 shadow">
    <li :for={org <- other_orgs(@user_organizations, @current_scope)}>
      <form action={~p"/organizations/switch"} method="post">
        <input type="hidden" name="_csrf_token" value={Plug.CSRFProtection.get_csrf_token()} />
        <input type="hidden" name="organization_id" value={org.id} />
        <input type="hidden" name="return_to" value={@current_path} />
        <button type="submit">{org.name}</button>
      </form>
    </li>
    <div class="divider my-1"></div>
    <li><.link navigate={~p"/organizations"}>+ New organization</.link></li>
    <li :if={@current_scope.membership.role in [:owner, :admin]}>
      <.link navigate={~p"/organizations/#{@current_scope.active_organization.slug}/settings"}>Settings</.link>
    </li>
  </ul>
</div>
```

**Source:** `test/example/lib/example_web/components/core_components.ex` (read, HIGH); daisyUI docs ([daisyui.com/components/dropdown/](https://daisyui.com/components/dropdown/), [daisyui.com/components/modal/](https://daisyui.com/components/modal/)) MEDIUM.

## 7. Signup "Create First Org" Step — D-08 Structural Free Lunch

**What Jetstream #117 says:** Laravel Jetstream auto-creates a "personal team" on user registration. This couples registration to team creation, which (a) breaks tests that only care about a user, (b) creates orphan "personal" teams when users are deleted, and (c) forces every user to have exactly one extra row they didn't ask for. Once in production, removing it is a breaking migration.

**Why Sigra is immune:** there is no code path that creates an org during user registration. `RegistrationLive` calls `Auth.register_user/1` which calls nothing in `Sigra.Organizations`. `create_session/4` (post-registration auto-login) runs `select_active_organization/3`; with zero orgs it returns `{:none, :zero_orgs}` and `set_active_organization(nil)` is a no-op. The user lands with no active org, hits `/`, the `:require_active_organization` pipeline fires `:no_active_org`, and is redirected to `~p"/organizations"` — the `OrganizationsLive.Index` zero-state branch with the create form.

**The "optional" property** falls out because the user can close the tab at that point. The app won't work (they have no org) but the registration succeeded and is persisted. No wizard step, no modal, no form field on RegistrationLive — D-09 holds.

**Invitation-signup bypass:** when an invitee registers via an invite link (Phase 17), the flow inserts a membership row inside the registration Multi. Then `select_active_organization/3` returns `{:ok, org}` with the membership attached, and the user lands inside that org directly — never touches `/organizations`.

**Source:** [github.com/laravel/jetstream/issues/117](https://github.com/laravel/jetstream/issues/117) (CITED); Phase 14 D-09 at `.planning/phases/14-org-plugs-scope-hydration/14-CONTEXT.md:82` (HIGH). Verified `select_active_organization/3` signature returns `{:none, :zero_orgs}` at `lib/sigra/organizations.ex:497`.

## 8. Generator vs Library Split for This Phase

**Library additions** (lives in `lib/sigra/`):
- `lib/sigra/plug/load_organization_from_slug.ex` — new plug (D-03).
- `lib/sigra/live_view/organization_scope.ex` — new on_mount handler (D-03). The filename uses `live_view/` not `live_helpers/` (D-30 bans `LiveHelpers` suffix).
- `lib/sigra/organizations.ex` — add `list_members_with_activity/2`, `count_members/1`, `rename_organization/2`, `update_slug/2`, `soft_delete_organization/2` (NB: existing `soft_delete_organization/3` stays; the new wrapper-signature version adds password + typed-confirm). Extend `remove_member/3` with session-delete Multi step (§5 gap).
- `lib/sigra/organizations/slug.ex` — add `"orgs"`, `"organizations"`, `"switch"` to `@default_reserved_slugs` (D-06).
- **Optional new schema:** `lib/sigra/organizations/slug_alias.ex` + migration for `organization_slug_aliases` (D-13 backend, §3).

**Generated into host app** (lives in `priv/templates/sigra.install/organizations/`):
- `organizations_live/index.ex` — the unified landing LV (D-07).
- `organization_settings_live.ex` — single-page sections LV (D-10).
- `organization_members_live.ex` — table + modals + pending-invitations stub (D-14, D-23).
- `organization_switch_controller.ex` — plain POST controller (D-05).
- `components/org_switcher.ex` — function component (D-24).
- Router injections: `scope "/organizations/:org"` block, `POST /organizations/switch`, `GET /organizations`, `live_session :org_scope` with the new on_mount, `:require_active_organization` pipeline (CD-07).
- `user_auth.ex` injection: new `on_mount :assign_user_organizations` clause (D-26).

**`Features.Organizations` fills `files/1`, `injections/1`, `post_instructions/2`** — all three were stubbed in Phase 13 (per 16-CONTEXT.md line 18-19) and get populated here. Precedent for multi-file feature modules: `lib/sigra/install/features/core.ex` (verified by the CONTEXT reference at line 222).

**phx.gen.auth 1.8 template structure as precedent:** [github.com/phoenixframework/phoenix/tree/main/priv/templates/phx.gen.auth](https://github.com/phoenixframework/phoenix/tree/main/priv/templates/phx.gen.auth) — the phx.gen.auth templates use EEx substitution (`<%= app_module %>`, `<%= web_module %>`) and are flat-structured under one `priv/templates` directory. Sigra already follows this pattern at `priv/templates/sigra.install/core/` (48 templates) and `priv/templates/sigra.install/organizations/` (5 templates from Phase 13). Phase 16 adds 5-6 new templates to the `organizations/` folder. **HIGH confidence.**

## 9. Testing Strategy for LiveView Org Flows

**Framework:** ExUnit + `Phoenix.LiveViewTest` (Phoenix 1.8 standard). Verified by existing tests under `test/example/test/example_web/` (not read in this research, but Phase 10.1.1 shipped a full LV test harness).

**Per-surface patterns:**

| Surface | Test helpers | Key assertions |
|---------|--------------|----------------|
| `OrganizationsLive.Index` (landing) | `live/2`, `has_element?/3`, `form/3 \|> render_submit/1`, `follow_redirect/2` | Zero-state: form visible + submits + creates org + redirects inside new org. Pending invites branch: list rendered. Picker branch: each row posts to switcher. |
| `OrganizationSwitchController` | `conn \|> post(~p"/organizations/switch", %{...})`, `redirected_to/1`, `assert_recent_audit("organization.active_set")` (per Phase 15 conventions) | POST updates `user_sessions.active_organization_id`, redirects to return_to, emits audit. Invalid org_id → 302 redirect to `/` with flash. |
| `OrganizationSettingsLive` | `live/2` under an `/organizations/:slug/settings` URL, `element(...) \|> render_click/1` to open progressive-disclosure sections, `form(...) \|> render_submit/2` | Rename succeeds without password. Slug change with wrong password → inline field error, no DB write. Slug change with wrong typed-confirm → inline field error. Slug change success → redirect to new canonical URL. Soft-delete with all inputs correct → `deleted_at` set + redirect to `/organizations`. |
| `OrganizationMembersLive` | `live/2`, `element("#member-#{id} [data-action=change-role]") \|> render_click/1` opens modal via daisyUI JS, form submit | Role change: last-owner-on-demote surfaces inline modal error. Remove: successful remove streams-out the row + DB assertion that user_session rows for `(removed_user_id, org_id)` are gone. Unauthorized (plain member viewing) → `RequireMembership` 403 at plug layer. |
| `LoadOrganizationFromSlug` plug | `conn \|> get(~p"/organizations/unknown/settings")` → 404 | Unknown slug → 404; member with session pointer at org A visiting URL /organizations/org-b/... → scope reflects org-b AND `user_sessions.active_organization_id` = org_b.id after response. |
| `Sigra.LiveView.OrganizationScope` on_mount | `live/2` directly (bypasses plug) | Same assertions as above but via `{Sigra.LiveView.OrganizationScope, :ensure_org_scope}` on_mount in a test live_session. |

**Sudo gate testing under D-11 (inline password):** tests pass a `password: valid_password` key into the form submit — no `conn_case` sudo-elevation helper is needed (because there is no `RequireSudo` redirect to bypass). This simplifies the test setup materially vs v1.0's `log_in_user_with_sudo/2` helper at `priv/templates/sigra.install/core/conn_case_helpers.ex` (verified reference from Phase 14).

**Source:** Phoenix.LiveViewTest docs ([hexdocs.pm/phoenix_live_view/Phoenix.LiveViewTest.html](https://hexdocs.pm/phoenix_live_view/Phoenix.LiveViewTest.html)); existing `conn_case_helpers.ex` template (referenced in Phase 14 CONTEXT). **HIGH confidence.**

## 10. Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | ExUnit + Phoenix.LiveViewTest (Phoenix 1.8.5) |
| Config files | `test/example/config/test.exs`, `test/test_helper.exs` (library) |
| Quick run command | `mix test --only phase16` (add `@tag :phase16` to new tests) |
| Full suite command | `mix test && (cd test/example && mix test)` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| ORG-UX-01 | Create org from UI, auto slug + reserved rejection | LV integration | `mix test test/example/test/example_web/live/organizations_live/index_test.exs -x` | ❌ Wave 0 |
| ORG-UX-02 | Switcher dropdown renders active org + role + list | LV render | `mix test test/example/test/example_web/components/org_switcher_test.exs -x` | ❌ Wave 0 |
| ORG-UX-03 | POST /organizations/switch updates session row + redirects | Controller | `mix test test/example/test/example_web/controllers/organization_switch_controller_test.exs -x` | ❌ Wave 0 |
| ORG-UX-04 | Rename + slug change (sudo + typed + 7d alias) | LV integration | `mix test test/example/test/example_web/live/organization_settings_live_test.exs -x` | ❌ Wave 0 |
| ORG-UX-05 | Soft-delete (sudo + typed-confirm org name) | LV integration | same file as above | ❌ Wave 0 |
| ORG-UX-06 | Members list with last-active LEFT JOIN | LV integration + unit | `mix test test/example/test/example_web/live/organization_members_live_test.exs -x` + `mix test test/sigra/organizations_test.exs -x` | Partially — library tests exist; example LV test is ❌ Wave 0 |
| ORG-UX-07 | Role change via modal + last-owner guard UI | LV integration | members_live_test.exs (same file) | ❌ Wave 0 |
| ORG-UX-08 | Remove member + force-logout same Multi | Unit (library) + LV integration | `mix test test/sigra/organizations_test.exs::test_remove_member_deletes_org_scoped_sessions -x` + members_live_test.exs | ❌ Wave 0 (both the library unit test and the LV test are new) |
| ORG-UX-09 | No auto-personal-org on registration; Index zero-state | Integration | `mix test test/example/test/example_web/flows/signup_zero_org_flow_test.exs -x` | ❌ Wave 0 |
| D-04 URL-404 | Unknown slug → 404, not-a-member slug → 404 | Plug unit | `mix test test/sigra/plug/load_organization_from_slug_test.exs -x` | ❌ Wave 0 |
| D-04 URL-refresh | Valid cross-org URL updates session pointer | Plug unit + LV | plug test above + a cross-org LV flow test | ❌ Wave 0 |
| D-13 Slug alias | Old slug redirects for 7 days, expires | Plug unit | `mix test test/sigra/plug/load_organization_from_slug_test.exs::test_slug_alias_redirect -x` | ❌ Wave 0 |

### Sampling Rate
- **Per task commit:** `mix test --only phase16` (< 30s target for the Phase 16 subset).
- **Per wave merge:** `mix test && (cd test/example && mix test)` (full library suite + full example suite).
- **Phase gate:** Full suite green + `mix credo --strict` + `mix dialyzer` before `/gsd-verify-work`.

### Wave 0 Gaps
- [ ] `test/sigra/plug/load_organization_from_slug_test.exs` — plug behavior (slug match, slug miss → 404, slug alias redirect, member verification, session pointer refresh). Covers D-03/D-04/D-13.
- [ ] `test/sigra/live_view/organization_scope_test.exs` — on_mount parallel tests.
- [ ] `test/sigra/organizations_test.exs` additions — `list_members_with_activity/2`, `count_members/1`, `rename_organization/2`, `update_slug/2` (typed-confirm), new `soft_delete_organization/2` (typed-confirm), extended `remove_member/3` (session purge). Covers ORG-UX-06/07/08 library side.
- [ ] `test/example/test/example_web/live/organizations_live/index_test.exs` — three render branches + create form + pick-to-switch flow.
- [ ] `test/example/test/example_web/live/organization_settings_live_test.exs` — rename, slug with password+typed, soft-delete with password+typed, non-owner 403.
- [ ] `test/example/test/example_web/live/organization_members_live_test.exs` — table render, change role modal, remove modal + last-owner inline error, force-logout DB assertion.
- [ ] `test/example/test/example_web/controllers/organization_switch_controller_test.exs` — POST success, invalid org, not-a-member reject, return_to sanitization.
- [ ] `test/example/test/example_web/flows/signup_zero_org_flow_test.exs` — end-to-end D-08 verification (register → redirect → Index zero-state).
- [ ] `test/example/test/example_web/components/org_switcher_test.exs` — component render with various scope states.
- [ ] `test/example/test/fixtures/organizations_fixtures.ex` — helpers for creating multi-org / multi-member / pending-invite scenarios. May already exist from Phase 13; verify in Wave 0.

### Sudo Gate Testing (D-11 simplification)
Because sudo is collected inline via `current_password` field, tests do NOT need a `log_in_user_with_sudo/2` helper for the Phase 16 destructive actions — just pass `password: valid_test_password()` in the form submit map. The `conn_case_helpers.ex` sudo helper is still used for any test that touches `SudoController` directly.

## Environment Availability

All dependencies already present in the project — no new packages required:

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Elixir | everything | ✓ | per CLAUDE.md 1.18+ | — |
| Phoenix | LV routing + scopes | ✓ | 1.8.5 (CLAUDE.md) | — |
| phoenix_live_view | all LVs | ✓ | matches Phoenix 1.8 | — |
| Ecto 3.13 | Multi.transact, :writable | ✓ | 3.13.5 (CLAUDE.md) | — |
| PostgreSQL + citext | members user.email lookup | ✓ | via test/example | — |
| daisyUI (CSS only) | dropdown, badge, modal/dialog | ✓ | prebuilt at test/example/priv/static/assets/default.css | Raw Tailwind (verbose) |

No new deps for Phase 16. Phase 17 will need `Hammer` for rate-limited invites; not this phase.

## Project Constraints (from CLAUDE.md)

- **Phoenix/Ecto blessed path.** Every routing and LV decision must be idiomatic Phoenix 1.8. No Plug-only alternatives that compromise DX.
- **PostgreSQL primary, MySQL/SQLite via conditional migration.** Any new migration (the slug-aliases table per §3) must be adapter-branched.
- **OWASP throughout, Argon2id default.** Password verification for sudo uses `Sigra.Crypto.verify_password/2` which wraps Argon2id. Do not hand-roll.
- **Minimal transitive deps.** No new deps in Phase 16 (verified §11).
- **LiveView supported but optional; login/logout via HTTP POST, not LV events.** D-05 switcher POST is consistent with this rule — org switch is a sensitive mutation, same class as login/logout, must be plain HTTP POST.
- **GSD workflow enforcement.** Phase 16 work must happen via `/gsd-execute-phase`; direct edits outside the workflow are forbidden by CLAUDE.md.
- **Comprehensive specs — AAA, flat, self-contained.** §10 validation map reflects this: each test file covers one surface, tests are self-contained (build fixtures in-test, no cross-file setup reliance).

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | D-13 "slug redirect history is backend-only" implies a new `organization_slug_aliases` schema + migration | §3, §8 | MEDIUM — if the user intended "keep the old slug string in a soft-deleted form on `organizations`" instead, the planner would build the wrong thing. Flag at discuss-phase. |
| A2 | `remove_member/3` must be extended in Phase 16 (D-21 called it a Phase 13 responsibility, but Phase 13 did not ship it) | §5 | HIGH — this is load-bearing for SC-4 and is a real code gap. Confirmed via direct read. |
| A3 | CD-04 stock `<.modal>` does not exist in phx.new 1.8 `core_components.ex`; recommendation is daisyUI `<dialog>` | §6 | LOW — discretionary per CONTEXT; recommendation is implementation-time. But the CONTEXT assumes a modal exists and the planner must not propagate that assumption into tasks. |
| A4 | `Sigra.LiveView.OrganizationScope.on_mount` cannot write to the session row (no Plug.Conn). The plug layer handles session pointer refresh on GET; LV on_mount only rebinds the scope for the process | §1 | LOW — this is an architectural fact of Phoenix 1.8 on_mount, not a decision. But worth locking so the planner doesn't accidentally add a `put_active_organization` call in on_mount. |
| A5 | daisyUI is the right answer for dropdown + dialog markup (CSS is already bundled into the example app at `priv/static/assets/default.css`) | §6 | LOW — explicit evidence in the repo. |
| A6 | `Sigra.Organizations.__config_schema__` currently lacks a `:user_session` entry; force-logout Multi will need the schema passed in | §5 | MEDIUM — alternative is to delegate to SessionStore's existing `delete_all_for_user/2` and add a new variant with an org filter. Planner should pick one. |

## Open Questions

1. **Q: Does the user want a dedicated `organization_slug_aliases` table (recommended) or a lighter approach (e.g. a JSONB array column on `organizations`)?** The CONTEXT D-13 text ("slug-history backend... produced by the context function's `Ecto.Multi` in the same transaction as the slug update") implies a real table. Recommend: discuss-phase confirms table. [A1]
2. **Q: For SC-4 force-logout, expose `:user_session` as a config schema entry (clean) OR extend `Sigra.SessionStore` with `delete_all_for_user_in_org/3` (keeps session knowledge in the session store)?** Second option is arguably cleaner separation of concerns but adds a new behaviour callback. Recommend: discuss-phase. [A6]
3. **Q: CD-07 — should the `:require_active_organization` pipeline macro be auto-injected into the router or only documented in post-install instructions?** D-24 leans "never auto-patch UI files," but the router is grammar-stable and existing Sigra features auto-inject pipelines (`:require_authenticated` per Phase 11). Recommend: auto-inject the pipeline, matching the existing `:require_authenticated` precedent.
4. **Q: Recommendation for CD-06 sort order — default alphabetical by email or by `inserted_at desc` (newest member first)?** v1.2 admin phase will add sortable columns; Phase 16 picks one default. Recommend: `inserted_at desc` so a new member is visible at the top of the list right after they join.

## Sources

### Primary (HIGH confidence)
- `.planning/phases/16-org-liveviews-switcher/16-CONTEXT.md` — 30 locked decisions, canonical references, downstream implications.
- `.planning/REQUIREMENTS.md` lines 38-46 — ORG-UX-01..ORG-UX-09 verbatim.
- `.planning/ROADMAP.md` lines 134-146 — Phase 16 entry + SC-1..SC-5 criteria.
- `.planning/phases/14-org-plugs-scope-hydration/14-CONTEXT.md` — D-03, D-09, D-14, D-16, D-22 (source for D-02/D-07/D-08 in Phase 16).
- `.planning/phases/13-organizations-schemas-context/13-CONTEXT.md` — D-10/D-11 membership schema, D-12 invitation derived status, reserved-slug source.
- `lib/sigra/organizations.ex` — verified public API, last-owner guards, absence of session-delete in `remove_member/3`.
- `lib/sigra/plug/put_active_organization.ex` — verified the single-writer contract for active org.
- `lib/sigra/plug/load_active_organization.ex` — verified stale-pointer recovery.
- `lib/sigra/plug/require_membership.ex` — verified `:roles` option and error_handler delegation.
- `lib/sigra/plug/fetch_session.ex:157-170` — verified last_active_at throttle.
- `lib/sigra/organizations/slug.ex:10-14` — verified default_reserved_slugs list.
- `lib/sigra/session_stores/ecto.ex:94-108` — verified existing `delete_all_for_user/2` (user-scoped only; no org filter).
- `priv/templates/sigra.install/core/settings_live.ex` — v1.0 inline-password + single-page-sections precedent.
- `priv/templates/sigra.install/core/sudo_controller.ex` — local-path validation + `confirm_sudo` side-effect pattern.
- `priv/templates/sigra.install/core/user_session.ex` — verified `active_organization_id :binary_id` field on user_sessions.
- `priv/templates/sigra.install/organizations/organizations.ex` — verified `set_active_organization/2` defdelegate already present.
- `test/example/lib/example_web/components/core_components.ex` — **verified absence of `<.modal>`, `<.alert>`, `<.badge>`**.
- `test/example/lib/example_web/user_auth.ex:193-231` — existing `mount_current_scope` on_mount pattern.
- `test/example/lib/example_web/router.ex` — existing `live_session` + pipeline structure for /users routes.
- `.planning/config.json` — `workflow.nyquist_validation: true` confirmed.

### Secondary (MEDIUM confidence)
- [Phoenix 1.8 Scopes guide](https://hexdocs.pm/phoenix/scopes.html) — `scope "/organizations/:org"` idiom (CITED, not re-fetched this session; CONTEXT already documents the guide's pattern).
- [Phoenix.LiveViewTest](https://hexdocs.pm/phoenix_live_view/Phoenix.LiveViewTest.html) — test helpers (CITED).
- [Ecto.Changeset.validate_change/3](https://hexdocs.pm/ecto/Ecto.Changeset.html#validate_change/3) — typed-confirm pattern (CITED).
- [daisyUI dropdown](https://daisyui.com/components/dropdown/) + [daisyUI modal](https://daisyui.com/components/modal/) — class names for §6 sketch (CITED).
- [phx.gen.auth templates](https://github.com/phoenixframework/phoenix/tree/main/priv/templates/phx.gen.auth) — generator template precedent for §8 (CITED).

### Tertiary (LOW confidence — flagged for validation)
- [Laravel Jetstream #117](https://github.com/laravel/jetstream/issues/117) — auto-personal-team regression (CITED from CONTEXT, not re-fetched).

## Metadata

**Confidence breakdown:**
- CONTEXT alignment: HIGH — every decision re-read and verified against actual code.
- Library gap identification (§5 remove_member): HIGH — direct code read; reproducible grep.
- Modal component (§6 CD-04): HIGH on the absence; MEDIUM on the daisyUI `<dialog>` recommendation (discretionary).
- Slug alias schema (§3, A1): MEDIUM — reasonable interpretation of D-13 but warrants confirm at discuss-phase.
- Test strategy (§10): HIGH — concrete file paths with Wave 0 flags.

**Research date:** 2026-04-12
**Valid until:** 2026-05-12 (30 days; stable stack, locked decisions).

## RESEARCH COMPLETE
