defmodule Sigra.Ecto.Types.RoleAtom do
  @moduledoc """
  Custom Ecto type that stores a role as a string in the database while
  preserving the atom round-trip in Elixir code.

  ## Why this exists (Phase 92 / B2B-02)

  Sigra's role taxonomy is host-owned (declared in `use Sigra.Organizations,
  roles: [...]`). The library's authorization seams compare role atoms
  (`scope.membership.role in [:owner, :admin]`, `m.role == config.owner_role`),
  so the in-memory shape MUST be an atom. Storing `field :role, :string`
  silently breaks every atom comparison once a row is loaded back from the DB.
  Storing `field :role, Ecto.Enum, values: [...]` would re-introduce a
  compile-time taxonomy literal — exactly the opinion Phase 92 deletes.

  This type bridges the gap: any role atom the host has registered (via
  `use Sigra.Organizations` or any other module compilation) round-trips
  cleanly.

  ## Behavior

  - **`cast/1`** accepts both atom and string input from changesets and
    returns an atom. A string input must correspond to a known atom (one
    that already exists in the BEAM) — otherwise `:error`. This prevents
    a controller param like `%{"role" => "ghost"}` from injecting an
    unrecognized atom into the system.
  - **`dump/1`** writes the atom as a string to the database column.
    `nil` is preserved for nullable columns.
  - **`load/1`** reads the string from the database and returns the
    matching atom via `String.to_existing_atom/1`. If no such atom exists
    (e.g. a database row inserted before the host's role module compiled,
    or manually-injected garbage), returns `:error` so Ecto raises a clean
    `Ecto.Type.LoadError` naming the field.

  ## Storage shape

  The database column is `:string`. Add a CHECK constraint or an external
  enforcement layer (e.g. a domain-specific Postgres CHECK or trigger) if
  you need DB-level role-set integrity in addition to the application-
  level guards in `Sigra.Organizations.add_member/5` and
  `Sigra.Organizations.change_role/4`.

  ## Usage

      schema "organization_memberships" do
        field :role, Sigra.Ecto.Types.RoleAtom
        # ...
      end

  ## Why `String.to_existing_atom/1` is safe here

  Roles enter the BEAM atom table at compile time when the host's
  `use Sigra.Organizations, roles: [...]` macro runs. By the time a Repo
  query loads any membership/invitation row at runtime, every legitimate
  role atom exists. A row with a role string that does not map to any
  existing atom is by definition a configuration drift event — surfacing
  it as a load error is the desired behavior.
  """

  use Ecto.Type

  @impl Ecto.Type
  def type, do: :string

  @impl Ecto.Type
  def cast(value) when is_atom(value) and not is_nil(value), do: {:ok, value}

  def cast(value) when is_binary(value) do
    {:ok, String.to_existing_atom(value)}
  rescue
    ArgumentError -> :error
  end

  def cast(nil), do: {:ok, nil}
  def cast(_), do: :error

  @impl Ecto.Type
  def dump(value) when is_atom(value) and not is_nil(value), do: {:ok, Atom.to_string(value)}
  def dump(nil), do: {:ok, nil}
  def dump(_), do: :error

  @impl Ecto.Type
  def load(value) when is_binary(value) do
    {:ok, String.to_existing_atom(value)}
  rescue
    ArgumentError -> :error
  end

  def load(nil), do: {:ok, nil}
  def load(_), do: :error
end
