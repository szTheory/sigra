defmodule Sigra.Ecto.Types.StringList do
  @moduledoc """
  Custom Ecto type for storing lists as comma-separated strings.

  Useful for MySQL/SQLite databases that lack native array column types.
  In PostgreSQL, prefer `{:array, :string}` for native array support.

  ## Storage Format

  Lists are stored as comma-separated strings in the database:

      ["profile:read", "sessions:write"] -> "profile:read,sessions:write"

  ## Usage

      field :scopes, Sigra.Ecto.Types.StringList

  """

  use Ecto.Type

  @doc """
  Returns the underlying database type (`:string`).
  """
  @impl Ecto.Type
  def type, do: :string

  @doc """
  Casts external input to a list of strings.

  Accepts both lists and comma-separated strings.
  """
  @impl Ecto.Type
  def cast(list) when is_list(list), do: {:ok, list}

  def cast(string) when is_binary(string) do
    {:ok, String.split(string, ",", trim: true)}
  end

  def cast(_), do: :error

  @doc """
  Dumps a list to a comma-separated string for database storage.
  """
  @impl Ecto.Type
  def dump(list) when is_list(list), do: {:ok, Enum.join(list, ",")}
  def dump(_), do: :error

  @doc """
  Loads a comma-separated string from the database into a list.

  Returns `{:ok, []}` for `nil` values (no scopes stored).
  """
  @impl Ecto.Type
  def load(string) when is_binary(string), do: {:ok, String.split(string, ",", trim: true)}
  def load(nil), do: {:ok, []}
  def load(_), do: :error
end
