# Role-Based Access Control

Sigra ships authorization as a *seam*, not as a permission engine. The library exposes one behaviour with one callback — `c:Sigra.Authz.can?/3` — and defines no role taxonomy. Host applications own which actions exist, which subjects are privileged, and how the request scope is interpreted.

This recipe shows one concrete host-app implementation. The roles you see below — `:owner`, `:admin`, `:member` — are example values supplied by the generated `use Sigra.Organizations` block, not library defaults. Edit them freely to match your product.

## What Sigra ships

The default install gives you four moving parts that interact at the RBAC seam:

- `Sigra.Authz` — a behaviour with a single `can?(action, subject, scope)` callback.
- `MyApp.SigraAuthz` — a generated host module that implements the behaviour. The starter returns `true` for every call.
- `MyApp.Organizations` — a generated host wrapper that passes explicit `roles`, `owner_role`, and `invitation_admin_roles` lists to `use Sigra.Organizations`.
- `%Scope{role: ..., actor_type: nil}` — the request scope carries the active membership's host-defined role atom; `:actor_type` is reserved for Phase 93 (M2M tokens) and stays `nil` until then.

The working rule is simple: privilege decisions belong in `MyApp.SigraAuthz.can?/3`. Pattern-match on `scope.role` to gate sensitive actions, then end with a deny fall-through.

## The generated allow-all starter

`mix sigra.install` writes a host-owned `lib/my_app/sigra_authz.ex` that looks like this:

    defmodule MyApp.SigraAuthz do
      @behaviour Sigra.Authz

      @impl Sigra.Authz
      def can?(action, subject, scope) do
        # TODO (Plan 92-04): replace this allow-all starter with explicit
        # per-action rules and a deny-by-default fall-through.
        _ = action
        _ = subject
        _ = scope
        true
      end
    end

Returning `true` for every call keeps a fresh install behaviourally identical to the pre-Phase-92 world (where Sigra shipped no host authz module at all). The starter exists so adopters have an obvious place to put their policy — not as a recommended posture.

## Replace the starter with deny-by-default

The hardening step is small and mechanical:

1. Replace the catch-all clause with explicit allow rules per `(action, subject, scope)`.
2. End the function with `def can?(_action, _subject, _scope), do: false` so unknown actions deny.
3. Add tests for both the allow paths and the deny fall-through.

Here is a worked example for a host that uses the generator's starter `[:owner, :admin, :member]` taxonomy:

    defmodule MyApp.SigraAuthz do
      @behaviour Sigra.Authz

      # ── Reads ──────────────────────────────────────────────────────────────
      # Anyone who has a membership can read the org's data. The PutActiveOrganization
      # plug already verifies the user is a member before the scope reaches you.
      @impl Sigra.Authz
      def can?(:read, _subject, %{role: role}) when role in [:owner, :admin, :member],
        do: true

      # ── Writes ─────────────────────────────────────────────────────────────
      # Owners and admins can manage members, billing, and org settings.
      def can?({:manage, :members}, _subject, %{role: role}) when role in [:owner, :admin],
        do: true

      def can?({:manage, :billing}, _subject, %{role: role}) when role in [:owner, :admin],
        do: true

      def can?({:manage, :org_settings}, _subject, %{role: role}) when role in [:owner, :admin],
        do: true

      # ── Owner-only ─────────────────────────────────────────────────────────
      # Only the owner can transfer ownership or delete the organization.
      def can?({:manage, :ownership}, _subject, %{role: :owner}), do: true
      def can?({:manage, :delete_organization}, _subject, %{role: :owner}), do: true

      # ── Deny fall-through (REQUIRED) ───────────────────────────────────────
      # Unknown actions, missing roles, and wrong-role attempts all hit here
      # and deny. Add it last; never rely on the implicit return value.
      def can?(_action, _subject, _scope), do: false
    end

A few things to notice about this shape:

- **Pattern-match in the head, not in the body.** Reading `scope.role` once in the function head keeps each clause readable. Computed predicates (`scope_has_mfa?(scope)`, etc.) belong in private helpers called from a guard or the body when a single-pattern match is not enough.
- **`scope.role` is host-defined.** The atoms above (`:owner`, `:admin`, `:member`) come from `MyApp.Organizations`'s `use Sigra.Organizations, roles: [...]` block. Change the wrapper, change the role atoms here. The library does not enforce any taxonomy.
- **`scope.actor_type` is nil under Phase 92.** Do not branch on it. Phase 93 will populate it for M2M tokens / service accounts; doing so today would silently couple your policy to a field that is always `nil`.
- **Membership presence is already checked upstream.** `Sigra.Plug.PutActiveOrganization` and `Sigra.Plug.RequireMembership` reject non-members before `can?/3` runs. Inside `can?/3` you are deciding which of an org's members may act, not whether someone is a member at all.

## Calling can?/3 from controllers and LiveViews

Use the host module directly from controllers, LiveViews, and background jobs. Sigra never invokes it for you.

    # In a controller
    defmodule MyAppWeb.BillingController do
      use MyAppWeb, :controller

      def update(conn, params) do
        scope = conn.assigns.current_scope

        if MyApp.SigraAuthz.can?({:manage, :billing}, scope.user, scope) do
          # … perform the update …
          redirect(conn, to: ~p"/billing")
        else
          conn
          |> put_flash(:error, "You don't have permission to manage billing.")
          |> redirect(to: ~p"/")
        end
      end
    end

    # In a LiveView
    defmodule MyAppWeb.MembersLive do
      use MyAppWeb, :live_view

      def mount(_params, _session, socket) do
        scope = socket.assigns.current_scope

        socket =
          assign(socket,
            can_manage_members?: MyApp.SigraAuthz.can?({:manage, :members}, scope.user, scope)
          )

        {:ok, socket}
      end
    end

The `(action, subject, scope)` calling convention is just a convention — Sigra does not interpret the arguments. If your host needs a different signature, write `MyApp.Authz` helpers that wrap `MyApp.SigraAuthz.can?/3` with the shape you prefer.

## How the scope role gets populated

You do not need to wire role propagation by hand. Phase 92 / Plan 92-03 placed `scope.role` writes at exactly two seams in the library:

- `Sigra.Scope.Hydration.hydrate/3` — derives `scope.role` from `membership.role` on the read path. Both the plug pipeline and the LiveView `on_mount` callback flow through this hydrator, so plug ↔ LiveView role parity is automatic.
- `Sigra.Plug.PutActiveOrganization` — writes `scope.role` from the new membership when the user transitions to a different active organization, and clears it on the no-org path.

Stale-pointer recovery branches in `Sigra.Plug.LoadActiveOrganization` clear `scope.role` alongside `scope.membership` so a previously populated role never leaks across a recovery boundary.

The take-away for adopters: by the time `current_scope` reaches your `can?/3` call, `scope.role` is either the host-defined role atom for the active membership or `nil` (no active org, no membership, recovery branch). You do not need to refresh it manually.

## Testing your policy

Tests should cover the allow paths and the deny fall-through explicitly. The deny fall-through is the most common production miss — a missing clause silently denies, but a wrong-role attempt against a non-existent rule also denies, and you want a regression catch for both.

    defmodule MyApp.SigraAuthzTest do
      use ExUnit.Case, async: true

      alias MyApp.Accounts.Scope
      alias MyApp.SigraAuthz

      describe "owner privileges" do
        test "owner can manage billing" do
          scope = %Scope{role: :owner}
          assert SigraAuthz.can?({:manage, :billing}, %{}, scope)
        end

        test "owner can transfer ownership" do
          scope = %Scope{role: :owner}
          assert SigraAuthz.can?({:manage, :ownership}, %{}, scope)
        end
      end

      describe "admin privileges" do
        test "admin can manage members" do
          scope = %Scope{role: :admin}
          assert SigraAuthz.can?({:manage, :members}, %{}, scope)
        end

        test "admin cannot transfer ownership" do
          scope = %Scope{role: :admin}
          refute SigraAuthz.can?({:manage, :ownership}, %{}, scope)
        end
      end

      describe "deny fall-through" do
        test "unknown action denies for any role" do
          for role <- [:owner, :admin, :member] do
            scope = %Scope{role: role}
            refute SigraAuthz.can?(:summon_dragon, %{}, scope)
          end
        end

        test "nil role denies every known action" do
          scope = %Scope{role: nil}
          refute SigraAuthz.can?(:read, %{}, scope)
          refute SigraAuthz.can?({:manage, :members}, %{}, scope)
        end
      end
    end

Add request-level tests that assert routes are gated correctly — `can?/3` unit tests prove the policy is right, but only the request tests prove the policy is wired into the right controllers and LiveViews.

## Customizing the role taxonomy

The starter values come from your generated `lib/my_app/organizations.ex` wrapper:

    use Sigra.Organizations,
      repo: MyApp.Repo,
      schemas: [...],
      roles: [:owner, :admin, :member],
      owner_role: :owner,
      invitation_admin_roles: [:owner, :admin],
      audit_schema: MyApp.Accounts.AuditEvent

Change these lists to match your product. Common variations:

- **Flatter shape:** `roles: [:admin, :member]`, `owner_role: :admin`, `invitation_admin_roles: [:admin]`.
- **More tiers:** `roles: [:owner, :admin, :editor, :viewer]`, `owner_role: :owner`, `invitation_admin_roles: [:owner, :admin]`.
- **Domain-specific atoms:** `roles: [:tenant_lead, :site_admin, :reviewer, :viewer]`, `owner_role: :tenant_lead`, `invitation_admin_roles: [:tenant_lead, :site_admin]`.

After changing `roles`, update `MyApp.SigraAuthz.can?/3` clauses to match the new taxonomy and add migration-time logic if you need to remap existing memberships. The `organization_memberships.role` column is plain `:string` and nullable (Plan 92-02), so you can stage a backfill without fighting the schema.

## What can?/3 should NOT decide

Keep three jobs separate:

- **Membership presence** — whether someone belongs to the active organization. Owned by `Sigra.Plug.RequireMembership` and `Sigra.Plug.PutActiveOrganization`, not by `can?/3`.
- **Data isolation** — which rows a query can see. Owned by `Sigra.Organizations.Query.for_org/2` (see [Multi-Tenant Apps](multi-tenant.html)), not by `can?/3`.
- **Privilege within a membership** — what an existing member may do. This is `can?/3`'s entire job.

If you find yourself encoding "is this user a member" inside `can?/3`, push the check up to the plug layer instead. If you find yourself encoding "filter rows for this org" inside `can?/3`, push the scoping into the query helper instead. `can?/3` is a yes/no oracle; everything else degrades its readability.

## Related

- [Sigra.Authz](Sigra.Authz.html) — the behaviour contract and callback signature.
- [Multi-Tenant Apps](multi-tenant.html) — `Sigra.Organizations.Query.for_org/2` for data isolation.
- [Getting Started](getting-started.html) — the default organizations and passkeys walkthrough.
