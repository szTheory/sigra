defmodule SigraInstallGoldenTmp.Accounts.Scope do
  @moduledoc """
  Defines the scope for authenticated requests.

  The scope carries the current user and is assigned to
  `conn.assigns.current_scope` by the authentication pipeline.

  ## Usage

      scope = SigraInstallGoldenTmp.Accounts.Scope.for_user(user)
      scope.user #=> %SigraInstallGoldenTmp.Accounts.User{}

  ## Reserved fields

  `:impersonating_from` is reserved for v1.2 impersonation support and must
  not be removed. See `UPGRADE-v1.2.md` at the project root for the contract.

  """

  alias SigraInstallGoldenTmp.Accounts.User

  # Reserved for v1.2 impersonation. Do not remove — see UPGRADE-v1.2.md.
  defstruct user: nil,
            active_organization: nil,
            membership: nil,
            impersonating_from: nil

  @type t :: %__MODULE__{
          user: %User{} | nil,
          active_organization: struct() | nil,
          membership: struct() | nil,
          impersonating_from: %User{} | nil
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
end
