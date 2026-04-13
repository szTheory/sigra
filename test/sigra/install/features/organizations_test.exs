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

      # Phase 14 Plan 03 surfaces the thin wrapper; Phase 16 Plan 02 appends
      # the switcher component + POST switch controller (see Phase 16 tests
      # below). The wrapper template is still present at its Phase 14 path.
      wrapper =
        Enum.find(files, fn {:eex, template, _target} ->
          template == "organizations/organizations.ex"
        end)

      assert {:eex, _, target} = wrapper
      assert target == Path.join(["lib", "my_app", "organizations.ex"])
    end

    test "renders target path relative to the host app's otp_app" do
      files = Organizations.files(otp_app: :acme)

      wrapper =
        Enum.find(files, fn {:eex, template, _target} ->
          template == "organizations/organizations.ex"
        end)

      assert {:eex, _, target} = wrapper
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

    test "organizations.ex template compiles against real Sigra.Organizations.__using__/1 (CR-01 regression)" do
      # This test renders the EEx template against a set of stub schema
      # modules and compiles the result end-to-end. It catches NimbleOptions
      # schema/template drift that a simple =~ string-match test cannot see —
      # e.g. the Phase 14 CR-01 bug where the template passed schemas flat
      # instead of nested under `:schemas`.
      suffix =
        :erlang.unique_integer([:positive, :monotonic])
        |> Integer.to_string()

      app_module = "Sigra.Test.OrgsTemplateCompile#{suffix}"
      context_module = "#{app_module}.Accounts"
      repo_module = "#{app_module}.Repo"

      bindings = [
        app_module: app_module,
        context_module: context_module,
        repo_module: repo_module,
        schema_alias: "User"
      ]

      # Define stub schema + scope modules so NimbleOptions `:atom` validation
      # sees real, loaded modules.
      Code.ensure_compiled!(Ecto.Schema)

      schemas_source = """
      defmodule #{app_module}.Repo do
      end

      defmodule #{app_module}.Organization do
        use Ecto.Schema
        @primary_key {:id, :binary_id, autogenerate: true}
        schema "organizations_template_compile_#{suffix}" do
          field :name, :string
          field :slug, :string
          field :deleted_at, :utc_datetime
          timestamps(type: :utc_datetime)
        end
      end

      defmodule #{app_module}.OrganizationMembership do
        use Ecto.Schema
        @primary_key {:id, :binary_id, autogenerate: true}
        schema "organization_memberships_template_compile_#{suffix}" do
          field :role, Ecto.Enum, values: [:owner, :admin, :member]
          field :organization_id, :binary_id
          field :user_id, :binary_id
          timestamps(type: :utc_datetime)
        end
      end

      defmodule #{app_module}.OrganizationInvitation do
        use Ecto.Schema
        @primary_key {:id, :binary_id, autogenerate: true}
        schema "organization_invitations_template_compile_#{suffix}" do
          field :email, :string
          timestamps(type: :utc_datetime)
        end
      end

      defmodule #{context_module}.User do
        use Ecto.Schema
        @primary_key {:id, :binary_id, autogenerate: true}
        schema "users_template_compile_#{suffix}" do
          field :email, :string
        end
      end

      defmodule #{context_module}.Scope do
        defstruct [:user, :active_organization, :membership, :impersonating_from]
      end
      """

      Code.compile_string(schemas_source)

      rendered =
        EEx.eval_string(
          File.read!("priv/templates/sigra.install/organizations/organizations.ex"),
          bindings
        )

      # Should compile cleanly — no NimbleOptions.ValidationError, no
      # KeyError, no unknown-option error.
      [{mod, _bin} | _] = Code.compile_string(rendered)
      assert Code.ensure_loaded?(mod)

      # Sanity-check that the generated wrapper exposes the Phase 14
      # plug/on_mount accessor.
      assert function_exported?(mod, :__sigra_org_config__, 0)
      config = mod.__sigra_org_config__()
      assert is_map(config)
      assert is_map(config.schemas)
      assert config.schemas.organization == Module.concat([app_module, "Organization"])
    end

    test "user_auth.ex template mount_current_scope calls Sigra.Scope.Hydration.hydrate/3" do
      user_auth = File.read!("priv/templates/sigra.install/core/user_auth.ex")
      assert user_auth =~ "Sigra.Scope.Hydration.hydrate"
      # The LV mount path MUST use get_user_and_session_by_token (not the
      # single-arg get_user_by_session_token which drops the session struct).
      assert user_auth =~ "get_user_and_session_by_token"
    end

    @tag :phase16
    test "Phase 16 org_switcher component template exists and exports org_switcher/1" do
      template = File.read!("priv/templates/sigra.install/organizations/components/org_switcher.ex")

      assert template =~ "defmodule <%= web_module %>.Components.OrgSwitcher"
      assert template =~ "def org_switcher(assigns)"
      # daisyUI dropdown + ARIA contract (UI-SPEC §Screen Anatomy 1)
      assert template =~ ~s|<details class="dropdown dropdown-end"|
      assert template =~ ~s|aria-label="Organization switcher"|
      # Each "other org" row posts to /organizations/switch via a form
      assert template =~ ~s|action={~p"/organizations/switch"}|
      assert template =~ ~s|method="post"|
      assert template =~ ~S|aria-label={"Switch to #{org.name}"}|
      assert template =~ "CSRFProtection.get_csrf_token"
      # Create org link always present
      assert template =~ ~s|~p"/organizations/new"|
      # Settings link ONLY for owner/admin
      assert template =~ "role in [:owner, :admin]"
      # Role badge variants (UI-SPEC §Color)
      assert template =~ "badge-primary"
      assert template =~ "badge-neutral"
      assert template =~ "badge-ghost"
    end

    @tag :phase16
    test "Phase 16 OrganizationSwitchController template exists with membership-before-write + local-path return_to" do
      template =
        File.read!(
          "priv/templates/sigra.install/organizations/controllers/organization_switch_controller.ex"
        )

      assert template =~ "defmodule <%= web_module %>.OrganizationSwitchController"
      assert template =~ "def update(conn,"
      # Delegates to the thin wrapper's set_active_organization/2
      assert template =~ "Organizations.set_active_organization(conn, org)"
      # Local-path validation for return_to (same pattern as SudoController)
      assert template =~ ~s|String.starts_with?(path, "/")|
      assert template =~ ~s|not String.starts_with?(path, "//")|
      # Unknown / cross-tenant org_id returns 404 (enumeration prevention D-04)
      assert template =~ ~s|put_status(:not_found)|
      assert template =~ "ErrorHTML"
      assert template =~ ~s|render(:"404")|
      # Flash on success
      assert template =~ ~S|"Switched to #{org.name}."|
    end

    @tag :phase16
    test "Phase 16 router_injection template defines POST /organizations/switch BEFORE scoped block (D-06)" do
      template = File.read!("priv/templates/sigra.install/organizations/router_injection.ex")

      # Both anchors present
      assert template =~ ~s|post "/organizations/switch"|
      assert template =~ ~s|scope "/organizations/:org"|

      # Line-order assertion: switch MUST be defined before the scoped block
      # so Phoenix's definition-order matching doesn't interpret "switch" as
      # a slug (D-06).
      switch_index =
        template
        |> String.split("\n")
        |> Enum.find_index(&String.contains?(&1, ~s|post "/organizations/switch"|))

      scope_index =
        template
        |> String.split("\n")
        |> Enum.find_index(&String.contains?(&1, ~s|scope "/organizations/:org"|))

      assert is_integer(switch_index)
      assert is_integer(scope_index)

      assert switch_index < scope_index,
             "POST /organizations/switch must appear before scope \"/organizations/:org\" block (D-06)"

      # :org_scoped pipeline uses LoadOrganizationFromSlug + RequireMembership
      assert template =~ "Sigra.Plug.LoadOrganizationFromSlug"
      assert template =~ "Sigra.Plug.RequireMembership"
      # live_session on_mount wires :assign_user_organizations
      assert template =~ ":assign_user_organizations"
    end

    @tag :phase16
    test "Phase 16 user_auth on_mount template defines :assign_user_organizations clause" do
      template =
        File.read!(
          "priv/templates/sigra.install/organizations/user_auth_on_mount_assign_user_organizations.ex"
        )

      assert template =~ "on_mount(:assign_user_organizations"
      assert template =~ "list_organizations_for_user"
      assert template =~ ":user_organizations"
    end

    @tag :phase16
    test "Phase 16 thin wrapper template exposes the 8 new defdelegates (Phase 16 Task 2 interfaces)" do
      template = File.read!("priv/templates/sigra.install/organizations/organizations.ex")

      # Each Phase 16 LiveView / settings page needs to reach these through
      # the host-owned context module. The thin wrapper either defdelegates
      # to the library function or surfaces it via `use Sigra.Organizations`.
      # We assert the wrapper explicitly names each function so it's
      # discoverable via `MyApp.Organizations.<fun>`.
      for name <- ~w(rename_organization update_slug soft_delete_organization
                     list_members_with_activity count_members change_member_role
                     remove_member list_organizations_for_user) do
        assert template =~ name,
               "thin wrapper template should expose #{name}/* (Phase 16 Task 2)"
      end
    end

    # ──────────────────────────────────────────────────────────────────────
    # Phase 16 Plan 04: OrganizationSettingsLive template
    # ──────────────────────────────────────────────────────────────────────

    @tag :phase16
    test "Phase 16-04 OrganizationSettingsLive template exists with correct module name (D-10)" do
      template =
        File.read!(
          "priv/templates/sigra.install/organizations/live/organization_settings_live.ex"
        )

      assert template =~ "defmodule <%= web_module %>.OrganizationSettingsLive"
      assert template =~ "use <%= web_module %>, :live_view"
      assert template =~ "alias <%= app_module %>.Organizations"
    end

    @tag :phase16
    test "Phase 16-04 OrganizationSettingsLive defines 7 phx event handlers (D-10/D-11/D-12)" do
      template =
        File.read!(
          "priv/templates/sigra.install/organizations/live/organization_settings_live.ex"
        )

      for handler <- ~w(rename open_slug_form close_slug_form update_slug
                        open_delete_form close_delete_form soft_delete) do
        assert template =~ ~s|handle_event("#{handler}"|,
               "settings LV must define handle_event(\"#{handler}\", ...) (Plan 16-04)"
      end
    end

    @tag :phase16
    test "Phase 16-04 OrganizationSettingsLive has progressive disclosure state for destructive actions (D-12)" do
      template =
        File.read!(
          "priv/templates/sigra.install/organizations/live/organization_settings_live.ex"
        )

      # mount seeds both closed
      assert template =~ ":slug_form_open?"
      assert template =~ ":delete_form_open?"
      # handlers flip open/closed (either assign/3 or pipe-form assign/2)
      assert template =~ ~r/assign\([^)]*:slug_form_open\?,\s*true\)/
      assert template =~ ~r/assign\([^)]*:slug_form_open\?,\s*false\)/
      assert template =~ ~r/assign\([^)]*:delete_form_open\?,\s*true\)/
      assert template =~ ~r/assign\([^)]*:delete_form_open\?,\s*false\)/
    end

    @tag :phase16
    test "Phase 16-04 OrganizationSettingsLive calls thin wrapper functions with scope + params" do
      template =
        File.read!(
          "priv/templates/sigra.install/organizations/live/organization_settings_live.ex"
        )

      # All three destructive handlers go through the host-owned Organizations wrapper
      assert template =~ "Organizations.rename_organization(socket.assigns.current_scope"
      assert template =~ "Organizations.update_slug(socket.assigns.current_scope"
      assert template =~ "Organizations.soft_delete_organization(socket.assigns.current_scope"
    end

    @tag :phase16
    test "Phase 16-04 OrganizationSettingsLive renders exact UI-SPEC button labels" do
      template =
        File.read!(
          "priv/templates/sigra.install/organizations/live/organization_settings_live.ex"
        )

      # Buttons from UI-SPEC §Copywriting Contract + Plan 16-04 must_haves
      assert template =~ "Save name"
      assert template =~ "Change slug"
      assert template =~ "Update slug"
      assert template =~ "Delete organization"
      assert template =~ "Delete organization permanently"
      # phx-disable-with copy
      assert template =~ ~s|phx-disable-with="Saving...|
      assert template =~ ~s|phx-disable-with="Updating...|
      assert template =~ ~s|phx-disable-with="Deleting...|
    end

    @tag :phase16
    test "Phase 16-04 OrganizationSettingsLive warning banner contains 7-day redirect copy" do
      template =
        File.read!(
          "priv/templates/sigra.install/organizations/live/organization_settings_live.ex"
        )

      # Exact copy anchor from Plan 16-04 Test 4 / UI-SPEC §Destructive Action Confirmations
      assert template =~ "Your current slug"
      assert template =~ "will redirect to the new slug for 7 days"
      # Warning alert variant
      assert template =~ "alert alert-warning"
    end

    @tag :phase16
    test "Phase 16-04 OrganizationSettingsLive Danger Zone uses red-zone treatment (D-10)" do
      template =
        File.read!(
          "priv/templates/sigra.install/organizations/live/organization_settings_live.ex"
        )

      # Per UI-SPEC §Screen Anatomy 4 + §Color "Destructive red zone treatment"
      assert template =~ "border-l-4 border-l-error"
      assert template =~ "Danger zone"
    end

    @tag :phase16
    test "Phase 16-04 OrganizationSettingsLive maps :invalid_password → exact UI copy for BOTH slug and delete handlers" do
      template =
        File.read!(
          "priv/templates/sigra.install/organizations/live/organization_settings_live.ex"
        )

      # Exact copy from UI-SPEC §Copywriting Contract Error States (line 142)
      assert template =~ "That password is incorrect."
      # Both destructive handlers must match {:error, :invalid_password}
      invalid_password_matches =
        template
        |> String.split("\n")
        |> Enum.count(&String.contains?(&1, "{:error, :invalid_password}"))

      assert invalid_password_matches >= 2,
             "expected at least 2 `{:error, :invalid_password}` clauses (slug + delete); got #{invalid_password_matches}"
    end

    @tag :phase16
    test "Phase 16-04 OrganizationSettingsLive maps typed-confirm errors to exact UI copy" do
      template =
        File.read!(
          "priv/templates/sigra.install/organizations/live/organization_settings_live.ex"
        )

      # Exact copy from UI-SPEC §Copywriting Contract Error States (lines 143-144)
      # The library's validate_confirm emits "does not match current slug" /
      # "does not match organization name" — the LV must remap to the typed-confirm copy.
      assert template =~ "Type "
      assert template =~ " exactly to confirm."
    end

    @tag :phase16
    test "Phase 16-04 OrganizationSettingsLive maps reserved + collision slug errors to UI-SPEC copy" do
      template =
        File.read!(
          "priv/templates/sigra.install/organizations/live/organization_settings_live.ex"
        )

      assert template =~ "That slug is reserved. Try another."
      assert template =~ "That slug is already in use. Try another."
    end

    @tag :phase16
    test "Phase 16-04 OrganizationSettingsLive emits exact flash + redirect copy on success" do
      template =
        File.read!(
          "priv/templates/sigra.install/organizations/live/organization_settings_live.ex"
        )

      # From UI-SPEC §Flash Copy (lines 182-184)
      assert template =~ "Name updated."
      assert template =~ "Slug updated. The old slug redirects for 7 days."
      assert template =~ "Organization deleted."
      # Redirect targets
      assert template =~ ~S|~p"/organizations/#{|
      assert template =~ ~S|~p"/organizations"|
    end

    @tag :phase16
    test "Phase 16-04 OrganizationSettingsLive renders three sections with v1.0 styling hooks" do
      template =
        File.read!(
          "priv/templates/sigra.install/organizations/live/organization_settings_live.ex"
        )

      # Three section headers (matches UI-SPEC §Screen Anatomy 4 layout)
      assert template =~ "General"
      assert template =~ ">Slug<"
      assert template =~ "Danger zone"
      # Uses the core_components <.header> and <.form> elements
      assert template =~ "<.header>"
      assert template =~ "phx-submit=\"rename\""
      assert template =~ "phx-submit=\"update_slug\""
      assert template =~ "phx-submit=\"soft_delete\""
    end
  end

  describe "injections/1" do
    test "returns list of router + user_auth injections (Phase 16)" do
      injections = Organizations.injections(otp_app: :my_app, web_module: "MyAppWeb")

      assert is_list(injections)
      # Phase 16 adds at least 2 injections: router scope block + user_auth on_mount
      assert length(injections) >= 2

      # Every entry is a %Sigra.Install.Injection{}
      Enum.each(injections, fn injection ->
        assert %Sigra.Install.Injection{} = injection
      end)

      targets = Enum.map(injections, & &1.target)
      assert Enum.any?(targets, &String.ends_with?(&1, "router.ex"))
      assert Enum.any?(targets, &String.ends_with?(&1, "user_auth.ex"))
    end

    @tag :phase16
    test "router injection content contains the scope block and switch route" do
      injections = Organizations.injections(otp_app: :my_app, web_module: "MyAppWeb")

      router_injection =
        Enum.find(injections, fn i -> String.ends_with?(i.target, "router.ex") end)

      assert router_injection
      assert router_injection.content =~ ~s|post "/organizations/switch"|
      assert router_injection.content =~ ~s|scope "/organizations/:org"|
      assert router_injection.content =~ "Sigra.Plug.LoadOrganizationFromSlug"
    end
  end

  describe "files/1 (Phase 16)" do
    @tag :phase16
    test "files/1 includes the new Phase 16 templates when organizations are enabled" do
      files = Organizations.files(otp_app: :my_app)
      targets = Enum.map(files, fn {:eex, _template, target} -> target end)
      sources = Enum.map(files, fn {:eex, template, _target} -> template end)

      assert "organizations/components/org_switcher.ex" in sources
      assert "organizations/controllers/organization_switch_controller.ex" in sources

      assert Enum.any?(targets, &String.ends_with?(&1, "components/org_switcher.ex"))

      assert Enum.any?(
               targets,
               &String.ends_with?(&1, "controllers/organization_switch_controller.ex")
             )
    end

    @tag :phase16
    test "files/1 includes the Phase 16-04 OrganizationSettingsLive template" do
      files = Organizations.files(otp_app: :my_app)
      targets = Enum.map(files, fn {:eex, _template, target} -> target end)
      sources = Enum.map(files, fn {:eex, template, _target} -> template end)

      assert "organizations/live/organization_settings_live.ex" in sources

      assert Enum.any?(
               targets,
               &String.ends_with?(&1, "live/organization_settings_live.ex")
             )

      # Target path is under lib/<web>/live/
      settings_target =
        Enum.find(targets, &String.ends_with?(&1, "organization_settings_live.ex"))

      assert settings_target =~ ~r|lib/my_app_web/live/|
    end
  end

  describe "post_instructions/2" do
    @tag :phase16
    test "Phase 16 post_instructions mention pasting org_switcher into layouts.ex" do
      report = %Sigra.Install.Report{}
      instructions = Organizations.post_instructions([otp_app: :my_app], report)

      assert is_list(instructions)
      flat = instructions |> List.flatten() |> Enum.map_join("\n", &to_string/1)

      assert flat =~ "org_switcher"
      assert flat =~ "layouts.ex"
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
