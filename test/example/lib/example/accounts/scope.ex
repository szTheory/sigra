defmodule Example.Accounts.Scope do
  @moduledoc """
  Defines the scope for authenticated requests.

  The scope carries the current user and is assigned to
  `conn.assigns.current_scope` by the authentication pipeline.

  ## Usage

      scope = Example.Accounts.Scope.for_user(user)
      scope.user #=> %Example.Accounts.User{}

  """

  alias Example.Accounts.User

  defstruct user: nil

  @type t :: %__MODULE__{user: %User{} | nil}

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
