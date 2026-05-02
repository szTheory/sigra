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
    test "defstruct includes all 6 fields defaulting to nil" do
      source = File.read!(@scope_path)

      assert source =~ ~r/active_organization:\s*nil/,
             "scope.ex must contain active_organization: nil in defstruct"

      assert source =~ ~r/membership:\s*nil/,
             "scope.ex must contain membership: nil in defstruct"

      assert source =~ ~r/impersonating_from:\s*nil/,
             "scope.ex must contain impersonating_from: nil in defstruct"

      # Phase 92 / B2B-02 (Plan 92-02): scope reserves :role and :actor_type
      # as additive RBAC fields. :role is the active membership's host-defined
      # role atom. :actor_type is reserved Phase 93 prep ONLY — it MUST
      # remain nil-only in Phase 92 with no behavior attached anywhere.
      assert source =~ ~r/role:\s*nil/,
             "scope.ex must contain role: nil in defstruct (Phase 92 Plan 92-02)"

      assert source =~ ~r/actor_type:\s*nil/,
             "scope.ex must contain actor_type: nil in defstruct (Phase 92 Plan 92-02 — Phase 93 prep)"
    end

    test "@type t includes all 6 fields" do
      source = File.read!(@scope_path)

      assert source =~ "active_organization: %<%= context_module %>.Organization{} | nil",
             "scope.ex @type must include active_organization with real Organization type (D-23)"

      assert source =~ "membership: %<%= context_module %>.OrganizationMembership{} | nil",
             "scope.ex @type must include membership with real OrganizationMembership type (D-23)"

      assert source =~ ~r/impersonating_from: %<%= schema_alias %>\{\} \| nil/,
             "scope.ex @type must include impersonating_from"

      # Phase 92 / B2B-02: role + actor_type @type entries.
      assert source =~ ~r/role:\s*atom\(\)\s*\|\s*nil/,
             "scope.ex @type must include role: atom() | nil (Phase 92 Plan 92-02)"

      assert source =~ ~r/actor_type:\s*atom\(\)\s*\|\s*nil/,
             "scope.ex @type must include actor_type: atom() | nil (Phase 92 Plan 92-02 — Phase 93 prep)"
    end

    test "moduledoc documents :actor_type as reserved Phase 93 prep with no Phase 92 behavior" do
      source = File.read!(@scope_path)

      assert source =~ "actor_type",
             "scope.ex moduledoc must reference :actor_type to document the Phase 93 reservation"

      assert source =~ "Phase 93",
             "scope.ex moduledoc must explicitly call out Phase 93 as the reservation target so the field cannot accidentally gain behavior in Phase 92"
    end

    test "for_user/1 and new/1 remain arity-1" do
      source = File.read!(@scope_path)

      for_user_matches = Regex.scan(~r/def for_user\(/, source)
      assert length(for_user_matches) == 2, "Expected 2 for_user/1 clauses"

      new_matches = Regex.scan(~r/def new\(/, source)
      assert length(new_matches) == 3, "Expected 3 new/1 clauses (Phase 93-04 added a service-account attrs-map clause)"
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
