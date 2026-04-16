defmodule Sigra.Scope.BuildTest do
  @moduledoc """
  Wave 0 tests for `Sigra.Scope.build/3`, the library-side scope
  constructor used by login-time synthesis and worker reference
  implementations.

  Created as `@tag :skip` stubs by Plan 15-01 Task 0 and un-skipped by
  Plan 15-01 Task 1.
  """
  use ExUnit.Case, async: true

  defmodule Scope do
    @moduledoc false
    defstruct [:user, :active_organization, :membership, :impersonating_from]
  end


  test "Sigra.Scope.build/3 with minimal opts returns struct with user set and others nil" do
    user = %{id: Ecto.UUID.generate()}
    scope = Sigra.Scope.build(Scope, user)

    assert %Scope{} = scope
    assert scope.user == user
    assert is_nil(scope.active_organization)
    assert is_nil(scope.membership)
    assert is_nil(scope.impersonating_from)
  end


  test "Sigra.Scope.build/3 propagates :active_organization and :membership from opts" do
    user = %{id: Ecto.UUID.generate()}
    org = %{id: Ecto.UUID.generate()}
    membership = %{id: Ecto.UUID.generate(), role: "admin"}

    scope = Sigra.Scope.build(Scope, user, active_organization: org, membership: membership)

    assert scope.user == user
    assert scope.active_organization == org
    assert scope.membership == membership
  end


  test "Sigra.Scope.build/3 propagates :impersonating_from additively for impersonation-aware callers" do
    user = %{id: Ecto.UUID.generate()}
    admin = %{id: Ecto.UUID.generate()}

    scope =
      Sigra.Scope.build(Scope, user,
        active_organization: %{id: Ecto.UUID.generate()},
        impersonating_from: admin
      )

    assert scope.impersonating_from == admin
  end
end
