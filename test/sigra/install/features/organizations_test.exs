defmodule Sigra.Install.Features.OrganizationsTest do
  @moduledoc """
  Unit tests for `Sigra.Install.Features.Organizations` — the behaviour
  implementation that owns the organizations migration slot and templates.

  Phase 13 ships this module with only `migrations/1` populated; Phase 18
  fills in `files/1`, `injections/1`, and `post_instructions/2`.
  """
  use ExUnit.Case, async: true

  alias Sigra.Install.Features.Organizations

  describe "injection templates on disk" do
    test "injection template files exist on disk for Features.Organizations" do
      assert File.exists?("priv/templates/sigra.install/organizations/router_injection.ex"),
             "organizations/router_injection.ex is referenced by Features.Organizations.router_injection/1 via read_template!/1"

      assert File.exists?(
               "priv/templates/sigra.install/organizations/user_auth_on_mount_assign_user_organizations.ex"
             ),
             "organizations/user_auth_on_mount_assign_user_organizations.ex is referenced by Features.Organizations.user_auth_on_mount_injection/2 via read_template!/1"
    end
  end

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
    test "files/1 includes the moved organization_invitation_email.ex fragment" do
      entries = Organizations.files(otp_app: :fixture_app)

      sources = Enum.map(entries, fn {:eex, source, _target} -> source end)

      assert "organizations/organization_invitation_email.ex" in sources,
             "Features.Organizations.files/1 must register the moved email fragment (Phase 24 D-04.1)"
    end

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
      # Phase 16 Plan 05: OrganizationMembersLive template
      assert "organizations/live/organization_members_live.ex" in sources

      assert Enum.any?(targets, &String.ends_with?(&1, "components/org_switcher.ex"))

      assert Enum.any?(
               targets,
               &String.ends_with?(&1, "controllers/organization_switch_controller.ex")
             )

      assert Enum.any?(
               targets,
               &String.ends_with?(&1, "live/organization_members_live.ex")
             )
    end

    @tag :phase16
    test "Phase 16 Plan 05 OrganizationMembersLive template exists with required structure" do
      path = "priv/templates/sigra.install/organizations/live/organization_members_live.ex"
      template = File.read!(path)

      # Module declaration (D-14)
      assert template =~ "defmodule <%= web_module %>.OrganizationMembersLive"
      assert template =~ "use <%= web_module %>, :live_view"
      assert template =~ "alias <%= app_module %>.Organizations"

      # Mount seeds a LiveView stream + header stat (D-22).
      assert template =~ "stream(:members"
      assert template =~ "Organizations.list_members_with_activity"
      assert template =~ "Organizations.count_members"

      # Six distinct event handlers (load_more + 2 open + cancel + 2 mutate).
      for handler <- [
            ~S|handle_event("load_more"|,
            ~S|handle_event("open_role_modal"|,
            ~S|handle_event("open_remove_modal"|,
            ~S|handle_event("cancel_action"|,
            ~S|handle_event("change_role"|,
            ~S|handle_event("remove_member"|
          ] do
        assert template =~ handler,
               "OrganizationMembersLive template must define #{handler}"
      end

      # Native <dialog class="modal"> per CD-04 research (no stock <.modal>
      # in core_components — core_components.ex ships no def modal).
      assert template =~ ~S|<dialog id="confirm-role-modal" class="modal"|
      assert template =~ ~S|<dialog id="confirm-remove-modal" class="modal"|

      # Role change modal contains the role select + submit wired to
      # phx-submit "change_role"
      assert template =~ ~S|phx-submit="change_role"|
      assert template =~ ~S|phx-submit="remove_member"|

      # Exact UI-SPEC §Copywriting error copy for last-owner guards (D-20).
      assert template =~
               "Cannot demote the last owner. Promote another member to owner first."

      assert template =~
               "Cannot remove the last owner. Promote another member to owner first."

      # Success flash copy (behavior test 8 + 12).
      assert template =~ ~S|"Role updated."|
      assert template =~ ~S|Removed #{email} from #{org_name}.|

      # Remove-modal warning copy (UI-SPEC §Screen Anatomy 5 destructive copy).
      assert template =~
               "will be signed out of this organization immediately. You can re-invite them later."

      # Header stat uses Members (N) with bound assign.
      assert template =~ ~S|Members ({@total_count})|

      # "Invite member" button — Phase 17 Plan 17-06 replaced the Phase 16
      # disabled stub with an owner/admin-gated enabled button that opens
      # the invite-member modal. The non-admin branch still uses the
      # `disabled aria-disabled="true"` pattern (UI gate only — library
      # re-checks authorization).
      assert template =~ "Invite member"
      assert template =~ ~S|phx-click="open_invite_modal"|
      assert template =~ ~S|aria-disabled="true"|

      # Phase 17 Plan 17-06: section id preserved (additive constraint D-14);
      # content filled with real pending-invitations list + empty state.
      assert template =~ ~S|<section id="pending-invitations-section"|
      assert template =~ "No pending invitations."
      assert template =~ "Click <strong>Invite member</strong>"

      # Role badge variants per UI-SPEC §Color.
      assert template =~ "badge-primary"
      assert template =~ "badge-neutral"
      assert template =~ "badge-ghost"

      # Actions dropdown: <details class="dropdown dropdown-end"> matches the
      # UI-SPEC anatomy without requiring a new library widget (D-29).
      assert template =~ ~S|<details class="dropdown dropdown-end"|
      assert template =~ ~S|phx-click="open_role_modal"|
      assert template =~ ~S|phx-click="open_remove_modal"|

      # Table uses the LiveStream-aware <.table> binding.
      assert template =~ ~S|rows={@streams.members}|

      # "Load more" button appears conditionally on @has_more (D-22).
      assert template =~ ~S|:if={@has_more} phx-click="load_more"|

      # "Last active" column branches on nil → "Never".
      assert template =~ "Never"
      assert template =~ "__last_active__"

      # Sort order (CD-06): library call is the source of truth; the template
      # does not re-sort. Assert it passes through list_members_with_activity
      # with a limit/offset — the Plan 01 query already orders inserted_at DESC.
      assert template =~ "limit: @page_size"
      assert template =~ "offset: 0"

      # Force-logout linkage: template calls Organizations.remove_member/2
      # which (per Plan 01) runs the purge_org_sessions Multi step in the
      # same transaction (SC-4 / D-21).
      assert template =~ "Organizations.remove_member(scope, member)"
    end

    @tag :phase16
    test "Phase 16 Plan 05 template handles {:error, :last_owner} for BOTH mutations (D-20)" do
      template =
        File.read!("priv/templates/sigra.install/organizations/live/organization_members_live.ex")

      # Both mutation handlers branch on {:error, :last_owner} and route it
      # to an inline modal error (modal stays open per D-20).
      assert template =~ "{:error, :last_owner}"
      assert template =~ ":role_modal_error"
      assert template =~ ":remove_modal_error"

      # Verify both error assigns are surfaced in the rendered dialog bodies
      # inside a role="alert" paragraph so screen readers announce them.
      assert template =~ ~S|role="alert"|

      # The dialog bodies render the error assigns (not a literal string).
      assert template =~ "{@role_modal_error}"
      assert template =~ "{@remove_modal_error}"
    end

    @tag :phase16
    test "Phase 16 Plan 05 template uses the standard <%= web_module %> / <%= app_module %> EEx vars" do
      path = "priv/templates/sigra.install/organizations/live/organization_members_live.ex"
      source = File.read!(path)

      # Template uses the same EEx binding names the rest of
      # priv/templates/sigra.install/organizations/** uses so the generator
      # can interpolate them uniformly. A full `EEx.eval_string/2` is not
      # viable here — the template contains a `~H"""..."""` HEEx sigil that
      # references `assigns` at LiveView runtime; evaluating at test time
      # would raise `undefined variable "assigns"`. So we assert on the
      # literal EEx markers being present and no other binding names leaking
      # in (e.g. the plan's original `<%= @web_namespace %>`).
      assert source =~ "<%= web_module %>"
      assert source =~ "<%= app_module %>"
      refute source =~ "<%= @web_namespace %>"
      refute source =~ "<%= web_namespace %>"
    end

    @tag :phase16
    test "files/1 (Phase 16 Plan 03) includes OrganizationsLive.Index and OrganizationsLive.New templates" do
      files = Organizations.files(otp_app: :my_app)
      targets = Enum.map(files, fn {:eex, _template, target} -> target end)
      sources = Enum.map(files, fn {:eex, template, _target} -> template end)

      assert "organizations/live/organizations_live/index.ex" in sources
      assert "organizations/live/organizations_live/new.ex" in sources

      assert Enum.any?(
               targets,
               &String.ends_with?(&1, "live/organizations_live/index.ex")
             )

      assert Enum.any?(
               targets,
               &String.ends_with?(&1, "live/organizations_live/new.ex")
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

      settings_target =
        Enum.find(targets, &String.ends_with?(&1, "organization_settings_live.ex"))

      assert settings_target =~ ~r|lib/my_app_web/live/|
    end
  end

  describe "OrganizationsLive.Index template content (Phase 16 Plan 03)" do
    @template_path "priv/templates/sigra.install/organizations/live/organizations_live/index.ex"

    @tag :phase16
    test "exists and declares the expected module" do
      assert File.exists?(@template_path)
      template = File.read!(@template_path)
      assert template =~ ~S|defmodule <%= web_module %>.OrganizationsLive.Index|
      assert template =~ ~S|use <%= web_module %>, :live_view|
    end

    @tag :phase16
    test "mount loads memberships and pending invitations via the thin wrapper" do
      template = File.read!(@template_path)
      assert template =~ "Organizations.list_organizations_for_user(user)"
      assert template =~ "Organizations.list_pending_invitations_for_user(user)"
    end

    @tag :phase16
    test "has three render branches keyed on (memberships, pending_invitations)" do
      template = File.read!(@template_path)

      assert template =~ "defp render_branch_a"
      assert template =~ "defp render_branch_b"
      assert template =~ "defp render_branch_c"

      # Branch selection arms
      assert template =~ "pick_branch([], [])"
      assert template =~ "pick_branch([], [_ | _])"
      assert template =~ "pick_branch([_ | _]"
    end

    @tag :phase16
    test "Branch A has zero-state hero copy + create form verbatim" do
      template = File.read!(@template_path)

      assert template =~ "Create your first organization"

      assert template =~
               "You don't belong to any organizations yet. Create one to get started."

      assert template =~ ~s|phx-change="validate"|
      assert template =~ ~s|phx-submit="create"|
      assert template =~ ~S|aria-live="polite"|
      assert template =~ ~s|phx-disable-with="Creating..."|
      assert template =~ "Create organization"
      assert template =~ "Skip for now"
    end

    @tag :phase16
    test "Branch A uses Sigra.Organizations.Slug.generate/1 for live preview" do
      template = File.read!(@template_path)
      assert template =~ "Sigra.Organizations.Slug.generate(name)"
    end

    @tag :phase16
    test "Branch A maps reserved and collision changeset errors to exact UI-SPEC copy" do
      template = File.read!(@template_path)

      assert template =~ "That slug is reserved. Try another."
      assert template =~ "That slug is already in use. Try another."
    end

    @tag :phase16
    test "Branch A create handler redirects to /organizations/:slug/members on success" do
      template = File.read!(@template_path)
      assert template =~ ~S|~p"/organizations/#{org.slug}/members"|
      assert template =~ ~s|put_flash(:info, "Organization created.")|
    end

    @tag :phase16
    test "Branch C renders per-row switch forms posting to /organizations/switch with CSRF + org id + return_to" do
      template = File.read!(@template_path)

      assert template =~ ~S|action={~p"/organizations/switch"}|
      assert template =~ ~s|method="post"|
      assert template =~ ~s|name="_csrf_token"|
      assert template =~ ~s|name="organization_id"|
      assert template =~ ~s|name="return_to"|
    end

    @tag :phase16
    test "Branch C header contains '+ New organization' CTA linking to /organizations/new" do
      template = File.read!(@template_path)
      assert template =~ "Your organizations"
      assert template =~ "+ New organization"
      assert template =~ ~S|navigate={~p"/organizations/new"}|
    end

    @tag :phase16
    test "Branch B renders pending invitations with disabled Accept buttons (Phase 17 wires)" do
      template = File.read!(@template_path)
      assert template =~ "pending invitation"
      assert template =~ ~s|disabled|
      assert template =~ "Available in the next release"
    end
  end

  describe "OrganizationsLive.New template content (Phase 16 Plan 03)" do
    @new_template_path "priv/templates/sigra.install/organizations/live/organizations_live/new.ex"

    @tag :phase16
    test "exists and declares the expected module" do
      assert File.exists?(@new_template_path)
      template = File.read!(@new_template_path)
      assert template =~ ~S|defmodule <%= web_module %>.OrganizationsLive.New|
      assert template =~ ~S|use <%= web_module %>, :live_view|
    end

    @tag :phase16
    test "renders the same form shape as Branch A with live slug preview" do
      template = File.read!(@new_template_path)

      assert template =~ ~s|phx-change="validate"|
      assert template =~ ~s|phx-submit="create"|
      assert template =~ ~S|aria-live="polite"|
      assert template =~ ~s|phx-disable-with="Creating..."|
      assert template =~ "Create organization"
      assert template =~ "Sigra.Organizations.Slug.generate(name)"
    end

    @tag :phase16
    test "Cancel link navigates back to /organizations" do
      template = File.read!(@new_template_path)
      assert template =~ ~S|navigate={~p"/organizations"}|
      assert template =~ "Cancel"
    end

    @tag :phase16
    test "create handler redirects to /organizations/:slug/members on success" do
      template = File.read!(@new_template_path)
      assert template =~ ~S|~p"/organizations/#{org.slug}/members"|
      assert template =~ ~s|put_flash(:info, "Organization created.")|
    end

    @tag :phase16
    test "maps reserved and collision changeset errors to exact UI-SPEC copy" do
      template = File.read!(@new_template_path)
      assert template =~ "That slug is reserved. Try another."
      assert template =~ "That slug is already in use. Try another."
    end
  end

  describe "RegistrationLive untouched by Phase 16 Plan 03 (D-08 / D-09)" do
    @tag :phase16
    test "registration_live.ex template is byte-identical to its Phase 14 state" do
      # ORG-UX-09 is a free structural lunch: Phase 16 MUST NOT touch
      # registration_live.ex. The zero-org post-signup flow falls out of
      # Phase 14's :no_active_org redirect path, not a new registration
      # field or step.
      expected_sha =
        "c27d0b8993604ce2abd52f75331630dc5bab430ffe83b8f9d3d3f0e564b31140"

      actual_sha =
        "priv/templates/sigra.install/core/registration_live.ex"
        |> File.read!()
        |> then(&:crypto.hash(:sha256, &1))
        |> Base.encode16(case: :lower)

      assert actual_sha == expected_sha,
             "registration_live.ex was modified in Phase 16 — " <>
               "this violates D-08/D-09 (ORG-UX-09 is a zero-line structural free lunch). " <>
               "Expected SHA256 #{expected_sha}, got #{actual_sha}."
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

  describe "migration template IMMUTABLE-safety (Phase 17 Plan 08 — Phase 16 hotfix)" do
    # Postgres rejects non-IMMUTABLE functions (like `now()`) inside partial
    # index predicates. The Phase 16 slug-alias migration shipped with
    # `where: "expires_at > now()"` which breaks host-app `mix ecto.migrate`.
    # Plan 17-08 replaces this with a plain unique index (Option A) because
    # the `LoadOrganizationFromSlug` plug already filters by `expires_at > now`
    # at the query layer, so the partial-index predicate was structurally
    # redundant. See T-17-12.

    @template_path "priv/templates/sigra.install/organizations/migration.exs"

    test "migration template has ZERO `now()` inside any index `where:` predicate" do
      template = File.read!(@template_path)

      # Match any `create ... index(...)` whose options include
      # `where: "... now() ..."` — across both postgres and mysql/sqlite
      # branches. The pending-invitation partial index uses IS NULL
      # (IMMUTABLE-safe) and must not match; the slug-alias index must not
      # contain `now()` after this plan lands.
      offenders =
        Regex.scan(~r/where:\s*"[^"]*now\(\)[^"]*"/, template)

      assert offenders == [],
             "Migration template still contains `now()` inside an index where: predicate: #{inspect(offenders)}"
    end

    test "slug-alias unique index is present (Option A — full unique index)" do
      template = File.read!(@template_path)

      # Postgres branch: expect the renamed index name (Option A).
      assert template =~ "organization_slug_aliases_old_slug_idx",
             "Expected Option A slug-alias index name `organization_slug_aliases_old_slug_idx` to be present"

      # Old broken predicate must be gone from the postgres branch (the
      # mysql/sqlite branch already used a plain unique_index under the
      # legacy name, so it does not emit `now()` — it is covered by the
      # first test).
      refute template =~ ~r/unique_index\(:organization_slug_aliases, \[:old_slug\],\s*\n\s*where:\s*"expires_at > now\(\)"/,
             "Postgres slug-alias partial index with `now()` predicate must be removed"
    end

    test "Phase 17 Plan 02 unique_index on organization_invitations.hashed_token is preserved" do
      template = File.read!(@template_path)

      hashed_token_matches =
        Regex.scan(~r/unique_index\(:organization_invitations, \[:hashed_token\]\)/, template)

      # One occurrence per adapter branch (postgres + mysql/sqlite).
      assert length(hashed_token_matches) == 2,
             "Expected 2 `unique_index(:organization_invitations, [:hashed_token])` occurrences (one per adapter branch), got #{length(hashed_token_matches)}"
    end

    test "Phase 16 D-03 pending-invitation partial index (IS NULL predicate) is preserved" do
      template = File.read!(@template_path)

      assert template =~ "organization_invitations_pending_index",
             "Phase 16 D-03 `organization_invitations_pending_index` must be preserved"

      assert template =~ ~s(where: "accepted_at IS NULL AND revoked_at IS NULL"),
             "Pending-invitation partial index must keep its IMMUTABLE-safe IS NULL predicate"
    end
  end
end
