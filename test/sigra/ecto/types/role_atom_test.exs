defmodule Sigra.Ecto.Types.RoleAtomTest do
  use ExUnit.Case, async: true

  alias Sigra.Ecto.Types.RoleAtom

  # These atoms must exist before the cast/load tests run. Listing them
  # in module attributes guarantees they're in the BEAM atom table.
  @owner :owner
  @admin :admin
  @member :member
  @tenant_lead :tenant_lead

  describe "type/0" do
    test "returns :string (the underlying database column type)" do
      assert RoleAtom.type() == :string
    end
  end

  describe "cast/1" do
    test "casts an atom to itself" do
      assert RoleAtom.cast(@owner) == {:ok, :owner}
    end

    test "casts a host-themed atom (proves no taxonomy is hardcoded)" do
      assert RoleAtom.cast(@tenant_lead) == {:ok, :tenant_lead}
    end

    test "casts a string to the matching existing atom" do
      assert RoleAtom.cast("admin") == {:ok, @admin}
    end

    test "casts nil to nil (nullable column support)" do
      assert RoleAtom.cast(nil) == {:ok, nil}
    end

    test "returns :error for a string with no matching atom (controller-injected garbage)" do
      # The atom :__definitely_unregistered_role_xyz__ does not exist in
      # the BEAM atom table; cast must refuse it rather than create it,
      # otherwise a malicious controller param could exhaust the atom
      # table.
      assert RoleAtom.cast("__definitely_unregistered_role_xyz__") == :error
    end

    test "returns :error for non-atom non-string non-nil input" do
      assert RoleAtom.cast(123) == :error
      assert RoleAtom.cast(%{}) == :error
      assert RoleAtom.cast([]) == :error
    end
  end

  describe "dump/1" do
    test "dumps an atom to a string for DB storage" do
      assert RoleAtom.dump(@member) == {:ok, "member"}
    end

    test "dumps a host-themed atom to its string representation" do
      assert RoleAtom.dump(@tenant_lead) == {:ok, "tenant_lead"}
    end

    test "dumps nil to nil (nullable column support)" do
      assert RoleAtom.dump(nil) == {:ok, nil}
    end

    test "returns :error for non-atom non-nil input" do
      assert RoleAtom.dump("already a string") == :error
      assert RoleAtom.dump(42) == :error
    end
  end

  describe "load/1" do
    test "loads a string into the matching existing atom" do
      assert RoleAtom.load("owner") == {:ok, @owner}
    end

    test "loads a host-themed string (proves no library taxonomy)" do
      assert RoleAtom.load("tenant_lead") == {:ok, @tenant_lead}
    end

    test "loads nil to nil" do
      assert RoleAtom.load(nil) == {:ok, nil}
    end

    test "returns :error for an unknown string (forces Ecto.Type.LoadError surfacing config drift)" do
      # If a host removes a role from their config but DB rows still
      # carry the old value, the atom stops existing on the next deploy.
      # Returning :error from load surfaces this loudly via Ecto rather
      # than silently producing a string that breaks downstream atom
      # comparisons.
      assert RoleAtom.load("__definitely_unregistered_role_xyz__") == :error
    end

    test "returns :error for non-string non-nil input" do
      assert RoleAtom.load(99) == :error
      assert RoleAtom.load(%{}) == :error
    end
  end

  describe "atom round-trip (the load-bearing invariant)" do
    test "atom -> dump -> load returns the same atom" do
      role = @admin
      {:ok, dumped} = RoleAtom.dump(role)
      assert {:ok, ^role} = RoleAtom.load(dumped)
    end

    test "host-themed atom round-trips" do
      role = @tenant_lead
      {:ok, dumped} = RoleAtom.dump(role)
      assert {:ok, ^role} = RoleAtom.load(dumped)
    end

    test "nil round-trips" do
      {:ok, dumped} = RoleAtom.dump(nil)
      assert {:ok, nil} = RoleAtom.load(dumped)
    end
  end
end
