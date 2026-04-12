defmodule Sigra.Install.Features.OrganizationsTest do
  @moduledoc """
  Unit tests for `Sigra.Install.Features.Organizations` — the behaviour
  implementation that owns the organizations migration slot and templates.

  Phase 13 ships this module with only `migrations/1` populated; Phase 18
  fills in `files/1`, `injections/1`, and `post_instructions/2`.
  """
  use ExUnit.Case, async: true

  alias Sigra.Install.Features.Organizations

  describe "enabled?/1" do
    test "returns true by default (ORG-01)" do
      assert Organizations.enabled?([]) == true
    end

    test "returns true when organizations: true" do
      assert Organizations.enabled?(organizations: true) == true
    end

    test "returns false when organizations: false" do
      assert Organizations.enabled?(organizations: false) == false
    end
  end

  describe "migrations/1" do
    test "returns a list with one tuple matching {:organizations, _, _}" do
      slots = Organizations.migrations([])
      assert length(slots) == 1
      assert [{:organizations, template, basename}] = slots
      assert template == "organizations/migration.exs"
      assert String.ends_with?(basename, ".exs")
    end
  end

  describe "files/1" do
    test "returns empty list (Phase 18 fills this in)" do
      assert Organizations.files([]) == []
    end
  end

  describe "injections/1" do
    test "returns empty list (Phase 18 fills this in)" do
      assert Organizations.injections([]) == []
    end
  end

  describe "post_instructions/2" do
    test "returns empty list (Phase 18 fills this in)" do
      assert Organizations.post_instructions([], %Sigra.Install.Report{}) == []
    end
  end

  describe "behaviour contract" do
    test "implements all 5 Feature callbacks with correct arities" do
      Code.ensure_loaded!(Organizations)
      assert function_exported?(Organizations, :enabled?, 1)
      assert function_exported?(Organizations, :files, 1)
      assert function_exported?(Organizations, :injections, 1)
      assert function_exported?(Organizations, :migrations, 1)
      assert function_exported?(Organizations, :post_instructions, 2)
    end

    test "declares @behaviour Sigra.Install.Feature" do
      behaviours =
        Organizations.module_info(:attributes)
        |> Keyword.get_values(:behaviour)
        |> List.flatten()

      assert Sigra.Install.Feature in behaviours
    end
  end

  describe "isolation invariant (Pitfall X-3)" do
    test "Organizations module code contains no references to Features.Core" do
      source = File.read!("lib/sigra/install/features/organizations.ex")

      # Strip the @moduledoc so prose describing the isolation doesn't
      # false-positive.
      code =
        Regex.replace(~r/@moduledoc\s+"""[\s\S]*?"""\s*\n/m, source, "", global: false)

      refute code =~ "Features.Core",
             "Features.Organizations must not reference Features.Core (Pitfall X-3)"

      refute code =~ "Features.Passkeys"
      refute code =~ "Features.Admin"
    end
  end
end
