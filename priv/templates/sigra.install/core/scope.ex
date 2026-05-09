defmodule <%= context_module %>.Scope do
  @moduledoc """
  Defines the scope for authenticated requests.

  The scope carries the current user and is assigned to
  `conn.assigns.current_scope` by the authentication pipeline.

  ## Usage

      scope = <%= context_module %>.Scope.for_user(user)
      scope.user #=> %<%= context_module %>.<%= schema_alias %>{}

  ## Reserved fields

  `:impersonating_from` is reserved for v1.2 impersonation support and must
  not be removed. See `UPGRADE-v1.2.md` at the project root for the contract.

  `:role` is the active membership's host-defined role atom, populated by
  generated wiring during scope hydration. The host's `SigraAuthz` module
  reads this field when answering `Sigra.Authz.can?/3`. Phase 92 / B2B-02
  (Plan 92-02) introduced the field; the host owns the role taxonomy and
  may freely use any atoms it wants.

  `:actor_type` is reserved for Phase 93 (M2M tokens / service accounts)
  and MUST remain `nil` under Phase 92 — it exists now so populating it
  in Phase 93 stays additive (no breaking scope-struct change). DO NOT
  branch on `:actor_type` from any code under Phase 92; the field has
  no behavior attached anywhere in the library or in this generated
  starter.

  """

  alias <%= context_module %>.<%= schema_alias %>

  # Reserved for impersonation. Do not remove — see UPGRADE-v1.2.md.
  # `:role` and `:actor_type` are RBAC seam fields. `:role` carries the
  # active membership's host-defined role atom. `:actor_type` is reserved
  # for service-account work and stays `nil` until then — do not branch
  # on it from generated code.
  defstruct user: nil,
            active_organization: nil,
            membership: nil,
            impersonating_from: nil,
            role: nil,
            actor_type: nil,
            service_account_id: nil

  @type t :: %__MODULE__{
          user: %<%= schema_alias %>{} | nil,
<%= if organizations? do %>
          active_organization: %<%= context_module %>.Organization{} | nil,
          membership: %<%= context_module %>.OrganizationMembership{} | nil,
<% else %>
          active_organization: nil,
          membership: nil,
<% end %>
          impersonating_from: %<%= schema_alias %>{} | nil,
          role: atom() | nil,
          actor_type: atom() | nil,
          service_account_id: binary() | nil
        }

  @doc """
  Creates a scope for the given user.
  """
  def for_user(%<%= schema_alias %>{} = user) do
    %__MODULE__{user: user}
  end

  def for_user(nil), do: nil

  @doc """
  Creates a scope struct from a user. Used by Sigra plugs.
  """
  def new(%<%= schema_alias %>{} = user) do
    %__MODULE__{user: user}
  end

  def new(nil), do: nil

  def new(%{} = attrs) when is_map(attrs) do
    struct(__MODULE__, attrs)
  end

  @doc """
  Puts the given organization and membership on the scope.

  Called by `Sigra.Plug.PutActiveOrganization`:

    * `(scope, org, membership)` — after a membership check succeeds,
      sets the scope's active organization + membership.
    * `(scope, nil, nil)` — clears both fields. Used on the clear
      path and by `Sigra.Plug.LoadActiveOrganization`'s stale-pointer
      recovery branch.

  This is the single authoritative scope-level write path for
  active-organization transitions (Phase 14 D-15).
  """
<%= if organizations? do %>
  def put_active_organization(
        %__MODULE__{} = scope,
        %<%= context_module %>.Organization{} = org,
        %<%= context_module %>.OrganizationMembership{} = membership
      ) do
    %{scope | active_organization: org, membership: membership}
  end
<% end %>
  def put_active_organization(%__MODULE__{} = scope, nil, nil) do
    %{scope | active_organization: nil, membership: nil}
  end
end
