defmodule Example.Accounts.Scope do
  @moduledoc """
  Defines the scope for authenticated requests.

  The scope carries the current user and is assigned to
  `conn.assigns.current_scope` by the authentication pipeline.

  ## Usage

      scope = Example.Accounts.Scope.for_user(user)
      scope.user #=> %Example.Accounts.User{}

  ## Reserved fields

  `:impersonating_from` is reserved for v1.2 impersonation support and must
  not be removed. See `UPGRADE-v1.2.md` at the project root for the contract.

  `:role`, `:actor_type`, and `:service_account_id` are additive authz fields
  used by later Sigra phases.

  """

  alias Example.Accounts.User

  # Reserved for v1.2 impersonation. Do not remove — see UPGRADE-v1.2.md.
  defstruct user: nil,
            active_organization: nil,
            membership: nil,
            impersonating_from: nil,
            role: nil,
            actor_type: nil,
            service_account_id: nil

  @type t :: %__MODULE__{
          user: %User{} | nil,
          active_organization: struct() | nil,
          membership: struct() | nil,
          impersonating_from: %User{} | nil,
          role: atom() | nil,
          actor_type: atom() | nil,
          service_account_id: binary() | nil
        }

  @doc """
  Creates a scope for the given user.
  """
  def for_user(%User{} = user) do
    %__MODULE__{user: user}
  end

  def for_user(nil), do: nil

  @doc """
  Creates a scope struct from a user. Used by Sigra plugs.
  """
  def new(%User{} = user) do
    %__MODULE__{user: user}
  end

  def new(nil), do: nil

  def new(%{} = attrs) when is_map(attrs) do
    struct(__MODULE__, attrs)
  end

  @doc """
  Assigns the active organization and membership to the scope.

  Phase 16 adds this contract so `Sigra.Plug.LoadOrganizationFromSlug`
  and `Sigra.Plug.PutActiveOrganization` can hydrate the per-request
  scope struct through the host's scope module (D-03).
  """
  def put_active_organization(%__MODULE__{} = scope, organization, membership) do
    %__MODULE__{scope | active_organization: organization, membership: membership}
  end
end
