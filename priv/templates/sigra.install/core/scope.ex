defmodule <%= context_module %>.Scope do
  @moduledoc """
  Defines the scope for authenticated requests.

  The scope carries the current user and is assigned to
  `conn.assigns.current_scope` by the authentication pipeline.

  ## Usage

      scope = <%= context_module %>.Scope.for_user(user)
      scope.user #=> %<%= context_module %>.<%= schema_alias %>{}

  """

  alias <%= context_module %>.<%= schema_alias %>

  defstruct user: nil

  @type t :: %__MODULE__{user: %<%= schema_alias %>{} | nil}

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
