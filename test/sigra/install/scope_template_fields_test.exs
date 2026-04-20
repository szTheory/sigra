defmodule Sigra.Install.ScopeTemplateFieldsTest do
  use ExUnit.Case, async: true

  @scope_path Path.expand(
                "../../../priv/templates/sigra.install/core/scope.ex",
                __DIR__
              )

  @session_path Path.expand(
                  "../../../priv/templates/sigra.install/core/user_session.ex",
                  __DIR__
                )

  describe "scope.ex template fields" do
    test "defstruct includes all 4 fields defaulting to nil" do
      source = File.read!(@scope_path)

      assert source =~ ~r/active_organization:\s*nil/,
             "scope.ex must contain active_organization: nil in defstruct"

      assert source =~ ~r/membership:\s*nil/,
             "scope.ex must contain membership: nil in defstruct"

      assert source =~ ~r/impersonating_from:\s*nil/,
             "scope.ex must contain impersonating_from: nil in defstruct"
    end

    test "@type t includes all 4 fields" do
      source = File.read!(@scope_path)

      assert source =~ "active_organization: %<%= context_module %>.Organization{} | nil",
             "scope.ex @type must include active_organization with real Organization type (D-23)"

      assert source =~ "membership: %<%= context_module %>.OrganizationMembership{} | nil",
             "scope.ex @type must include membership with real OrganizationMembership type (D-23)"

      assert source =~ ~r/impersonating_from: %<%= schema_alias %>\{\} \| nil/,
             "scope.ex @type must include impersonating_from"
    end

    test "for_user/1 and new/1 remain arity-1" do
      source = File.read!(@scope_path)

      for_user_matches = Regex.scan(~r/def for_user\(/, source)
      assert length(for_user_matches) == 2, "Expected 2 for_user/1 clauses"

      new_matches = Regex.scan(~r/def new\(/, source)
      assert length(new_matches) == 2, "Expected 2 new/1 clauses"
    end

    test "moduledoc mentions reserved fields and UPGRADE-v1.2.md" do
      source = File.read!(@scope_path)

      assert source =~ "Reserved fields",
             "scope.ex @moduledoc must mention Reserved fields"

      assert source =~ "UPGRADE-v1.2.md",
             "scope.ex @moduledoc must cite UPGRADE-v1.2.md"
    end
  end

  describe "user_session.ex template fields" do
    test "includes active_organization_id binary_id field" do
      source = File.read!(@session_path)

      assert source =~ "field :active_organization_id, :binary_id",
             "user_session.ex must contain field :active_organization_id, :binary_id"
    end
  end
end
