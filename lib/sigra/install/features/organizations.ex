defmodule Sigra.Install.Features.Organizations do
  @moduledoc """
  `Sigra.Install.Feature` implementation for the organizations feature:
  multi-tenant organization support with memberships and invitations.

  Owns every template under `priv/templates/sigra.install/organizations/`
  and the single migration that creates the `organizations`,
  `organization_memberships`, and `organization_invitations` tables.

  `enabled?/1` checks `Keyword.get(opts, :organizations, true)` — the
  organizations feature is enabled by default (ORG-01). Pass
  `--no-organizations` to the installer to disable.

  ## Phase 16 scope

  Phase 16 Plan 02 populates `files/1`, `injections/1`, and
  `post_instructions/2` to ship the Phase 16 user-facing surface:
  organization switcher function component, POST switch controller,
  router scope block + route ordering (D-06), and the user_auth
  `:assign_user_organizations` `on_mount` hook. The Phase 16 LiveView
  templates (landing, settings, members) are added in Plans 03–05 and
  simply append to the lists below.

  ## Isolation invariant (Pitfall X-3)

  This module contains ZERO references to `Features.Core`,
  `Features.Passkeys`, or `Features.Admin`. That boundary is what makes
  `mix sigra.install --no-organizations` produce a compiling app even
  with no Organizations code present.
  """

  @behaviour Sigra.Install.Feature

  alias Sigra.Install.Injection

  @impl true
  def enabled?(opts), do: Keyword.get(opts, :organizations, true)

  @impl true
  def files(binding) do
    otp_app = Keyword.fetch!(binding, :otp_app) |> to_string()
    web = "#{otp_app}_web"

    [
      # Phase 14 Plan 03 D-19: generated Organizations context wrapper.
      # Exposes set_active_organization/2 via defdelegate, uses
      # `use Sigra.Organizations` so hosts get __sigra_org_config__/0
      # for free (consumed by Phase 14 LoadActiveOrganization plug +
      # LiveView on_mount parity path).
      {:eex, "organizations/organizations.ex", Path.join(["lib", otp_app, "organizations.ex"])},

      # Phase 16 Plan 02: organization switcher function component
      # (generated + host-owned per D-24). Host pastes
      # `<.org_switcher />` into their layouts.ex per post_instructions.
      {:eex, "organizations/components/org_switcher.ex",
       Path.join(["lib", web, "components", "org_switcher.ex"])},

      # Phase 16 Plan 02: POST /organizations/switch controller
      # (plain controller per D-05 / ORG-UX-03).
      {:eex, "organizations/controllers/organization_switch_controller.ex",
       Path.join(["lib", web, "controllers", "organization_switch_controller.ex"])},

      # Phase 16 Plan 03: unified landing / picker LiveView at /organizations.
      # Three render branches keyed on (memberships, pending_invitations):
      #   * zero-state hero + create form (also the post-signup destination
      #     via ORG-UX-09's zero-line registration path)
      #   * pending-invitations list (Phase 17 wires Accept)
      #   * picker with per-row switch forms
      {:eex, "organizations/live/organizations_live/index.ex",
       Path.join(["lib", web, "live", "organizations_live", "index.ex"])},

      # Phase 16 Plan 03: dedicated create-organization LiveView at
      # /organizations/new (parallel to Branch A of the Index LV).
      {:eex, "organizations/live/organizations_live/new.ex",
       Path.join(["lib", web, "live", "organizations_live", "new.ex"])},

      # Phase 16 Plan 04: OrganizationSettingsLive — three-section single-page
      # settings surface (General / Slug / Danger Zone) with progressive
      # disclosure + inline sudo for destructive actions (D-10 / D-11 / D-12).
      {:eex, "organizations/live/organization_settings_live.ex",
       Path.join(["lib", web, "live", "organization_settings_live.ex"])},

      # Phase 16 Plan 05: OrganizationMembersLive — members list, role-change
      # modal, remove modal with force-logout, Phase 17 invitations seam.
      # Host-owned per D-28 / D-29.
      {:eex, "organizations/live/organization_members_live.ex",
       Path.join(["lib", web, "live", "organization_members_live.ex"])},

      # Phase 17 Plan 07 (D-06): InvitationAcceptLive — single unscoped
      # LiveView with 7 render branches (signup/accept/mismatch/invalid/
      # expired/revoked/already_accepted). The :mismatch branch contains
      # ZERO accept DOM controls by construction — structural Jetstream
      # #907 / CVE-2026-1529 defense. Host-owned per D-28 / D-29.
      {:eex, "organizations/live/invitation_accept_live.ex",
       Path.join(["lib", web, "live", "invitation_accept_live.ex"])}
    ]
  end

  @impl true
  def injections(binding) do
    otp_app = binding |> Keyword.fetch!(:otp_app) |> to_string()
    web = "#{otp_app}_web"

    [
      router_injection(otp_app),
      user_auth_on_mount_injection(otp_app, web)
    ]
  end

  @impl true
  def migrations(_binding) do
    [{:organizations, "organizations/migration.exs", "create_organizations.exs"}]
  end

  @impl true
  def post_instructions(_binding, _report) do
    [
      """

      Sigra organizations installed!

      Next steps:

        1. Add the organization switcher to your app layout.
           In lib/<app>_web/components/layouts.ex, inside the <header>, add:

               <.org_switcher
                 current_scope={@current_scope}
                 user_organizations={@user_organizations}
                 return_to={@current_path}
               />

        2. Organization routes were injected into your router, including
           the /organizations landing + scoped /organizations/:org block.

        3. Run `mix ecto.migrate` to create the organizations tables.

        4. Add `:require_org` gates to routes that should force org
           selection:

               pipe_through [:browser, :require_authenticated, :require_org]
      """
    ]
  end

  # ──────────────────────────────────────────────────────────────────────────
  # Injection builders (Phase 16 Plan 02)
  #
  # Both injections are read from template files rather than being
  # embedded inline so the golden-diff harness and the Phase 16 test suite
  # can grep the template contents directly (router + user_auth content
  # lives on disk as an .ex template).
  # ──────────────────────────────────────────────────────────────────────────

  defp router_injection(otp_app) do
    content = read_template!("organizations/router_injection.ex")

    %Injection{
      target: Path.join(["lib", "#{otp_app}_web", "router.ex"]),
      marker: "# Sigra organizations",
      anchor: :before_last_end,
      content: content
    }
  end

  defp user_auth_on_mount_injection(_otp_app, web) do
    content = read_template!("organizations/user_auth_on_mount_assign_user_organizations.ex")

    %Injection{
      target: Path.join(["lib", web, "user_auth.ex"]),
      marker: "on_mount(:assign_user_organizations",
      anchor: :before_last_end,
      content: content
    }
  end

  defp read_template!(relative_path) do
    Path.join(["priv", "templates", "sigra.install", relative_path])
    |> File.read!()
  end
end
