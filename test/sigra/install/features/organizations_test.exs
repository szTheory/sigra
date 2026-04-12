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
    test "returns the generated Organizations context wrapper template (Phase 14 Plan 03)" do
      files = Organizations.files(otp_app: :my_app)

      assert [{:eex, template, target}] = files
      assert template == "organizations/organizations.ex"
      assert target == Path.join(["lib", "my_app", "organizations.ex"])
    end

    test "renders target path relative to the host app's otp_app" do
      files = Organizations.files(otp_app: :acme)
      assert [{:eex, _template, target}] = files
      assert target == Path.join(["lib", "acme", "organizations.ex"])
    end

    test "scope.ex template contains the put_active_organization/3 pure function (Phase 14 Task 2)" do
      # Task 2 acceptance criterion — the generated Scope template gets the
      # pure put function added. This is owned by Features.Core but tested
      # here alongside the new Organizations wrapper since it's part of the
      # Phase 14 template-edit bundle.
      scope_template = File.read!("priv/templates/sigra.install/core/scope.ex")
      assert scope_template =~ "def put_active_organization"
      assert scope_template =~ "%__MODULE__{} = scope, nil, nil"
    end

    test "error_handler.ex template contains the :no_active_org + :insufficient_role clauses with exact UI-SPEC copy" do
      error_handler = File.read!("priv/templates/sigra.install/core/error_handler.ex")
      assert error_handler =~ ":no_active_org"
      assert error_handler =~ ":insufficient_role"
      assert error_handler =~ "Pick or create an organization to continue."
      assert error_handler =~ "You don't have permission to access this page in the current organization."
      # Copy Rules non-negotiable: no role-name leak in the insufficient_role message.
      refute error_handler =~ "This page requires the"
      # :no_active_org uses :info (not :error) per UI-SPEC (non-blaming).
      assert error_handler =~ "put_flash(:info, \"Pick or create an organization to continue.\")"
    end

    test "organizations.ex template defdelegates set_active_organization/2 to Sigra.Plug.PutActiveOrganization" do
      organizations_template = File.read!("priv/templates/sigra.install/organizations/organizations.ex")
      assert organizations_template =~ "defdelegate set_active_organization"
      assert organizations_template =~ "Sigra.Plug.PutActiveOrganization"
      assert organizations_template =~ "as: :call"
      assert organizations_template =~ "use Sigra.Organizations"
    end

    test "user_auth.ex template mount_current_scope calls Sigra.Scope.Hydration.hydrate/3" do
      user_auth = File.read!("priv/templates/sigra.install/core/user_auth.ex")
      assert user_auth =~ "Sigra.Scope.Hydration.hydrate"
      # The LV mount path MUST use get_user_and_session_by_token (not the
      # single-arg get_user_by_session_token which drops the session struct).
      assert user_auth =~ "get_user_and_session_by_token"
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
