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

  """

  alias <%= context_module %>.<%= schema_alias %>

  # Reserved for v1.2 impersonation. Do not remove — see UPGRADE-v1.2.md.
  defstruct user: nil,
            active_organization: nil,
            membership: nil,
            impersonating_from: nil

  @type t :: %__MODULE__{
          user: %<%= schema_alias %>{} | nil,
          active_organization: %<%= context_module %>.Organization{} | nil,
          membership: %<%= context_module %>.OrganizationMembership{} | nil,
          impersonating_from: %<%= schema_alias %>{} | nil
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
end
