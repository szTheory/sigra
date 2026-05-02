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
    # `context_alias` defaults to "Accounts" so existing tests that pass
    # only `otp_app: :foo` continue to work; the real installer binding
    # always sets context_alias (via mix sigra.install <ctx> <schema> ...).
    ctx = binding |> Keyword.get(:context_alias, "Accounts") |> Macro.underscore()

    base_files = [
      # Phase 13 Plan 02 / Phase 24.1: v1.1 organization schema modules.
      # These four schemas were created in Phase 13 but never registered
      # in files/1 until Phase 24 absorbed Phase 18 Plan 18-03's charter
      # to unblock install_matrix CI. Generated under the host app's
      # accounts context directory alongside core/user.ex etc.
      {:eex, "organizations/organization.ex",
       Path.join(["lib", otp_app, ctx, "organization.ex"])},
      {:eex, "organizations/organization_invitation.ex",
       Path.join(["lib", otp_app, ctx, "organization_invitation.ex"])},
      {:eex, "organizations/organization_membership.ex",
       Path.join(["lib", otp_app, ctx, "organization_membership.ex"])},
      {:eex, "organizations/organization_slug_alias.ex",
       Path.join(["lib", otp_app, ctx, "organization_slug_alias.ex"])},

      # Phase 24.1: organizations table migration. Must land BEFORE
      # `audit_events_org_columns` (which references it via hard FK).
      {:eex, "organizations/migration.exs",
       migration_target(binding, :organizations, "create_organizations.exs")},

      # Phase 24.1: audit_events_org_columns migration. Moved out of
      # the Core feature because it `references(:organizations, ...)`
      # and must land AFTER the organizations migration AND be skipped
      # under --no-organizations. The template still lives under
      # priv/templates/sigra.install/core/ because that's where the
      # other audit-events migrations live and splitting it across
      # subdirs would complicate the coverage lint.
      {:eex, "core/alter_audit_events_add_org_columns.exs",
       migration_target(
         binding,
         :audit_events_org_columns,
         "alter_audit_events_add_org_columns.exs"
       )},

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

      # NOTE: priv/templates/sigra.install/organizations/organization_invitation_email.ex
      # is intentionally NOT listed in files/1. That file is a reference
      # fragment — it mirrors the canonical inline organization_invitation/4
      # implementation spliced into core/emails.ex at generator time, but
      # it is not a valid standalone Elixir module (uses bare `@font_family`
      # interpolation + unresolved `<%= app_name %>` markers, both of which
      # resolve correctly only inside the emails.ex host module). Copying it
      # into the host app breaks `mix compile --warnings-as-errors` with
      # `(ArgumentError) cannot invoke @/1 outside module`. The fragment is
      # kept under organizations/ for CD-01 subdir ownership and to give
      # Phase 17/24 verifiers a grep anchor, but it is reference-only.
    ]

    if Keyword.get(Keyword.get(binding, :opts, []), :jwt, false) do
      base_files ++
        [
          {:eex, "organizations/service_account.ex",
           Path.join(["lib", otp_app, ctx, "service_account.ex"])},
          {:eex, "organizations/service_account_credential.ex",
           Path.join(["lib", otp_app, ctx, "service_account_credential.ex"])},
          {:eex, "organizations/service_accounts_migration.exs",
           migration_target(binding, :service_accounts, "create_service_accounts.exs")},
          {:eex, "organizations/live/organization_service_accounts_live.ex",
           Path.join(["lib", web, "live", "organization_service_accounts_live.ex"])},
          # Phase 93 Plan 09: CopyToClipboard hook source — ships into the host's
          # assets/js/ directory. The hook is required by phx-hook="CopyToClipboard"
          # on the credential-disclosure modal copy buttons in OrganizationServiceAccountsLive.
          # Uses :eex atom to stay consistent with how passkey_hooks.js is shipped;
          # the file contains no EEx markers but the :eex pipeline produces identical
          # output for plain-text files.
          {:eex, "organizations/copy_to_clipboard_hook.js",
           Path.join(["assets", "js", "copy_to_clipboard_hook.js"])}
        ]
    else
      base_files
    end
  end

  @impl true
  def injections(binding) do
    otp_app = binding |> Keyword.fetch!(:otp_app) |> to_string()

    base_injections = [
      # user_auth injection was removed in Phase 24.1: the
      # :assign_user_organizations on_mount clause is now baked directly
      # into core/user_auth.ex gated on `<%= if organizations? do %>`.
      # Injecting a new on_mount clause at :before_last_end produced
      # `clauses with the same name and arity should be grouped together`
      # and `redefining @doc attribute` warnings under
      # `mix compile --warnings-as-errors` because the clause landed far
      # from the existing on_mount group.
      router_injection(otp_app, binding)
    ]

    if Keyword.get(Keyword.get(binding, :opts, []), :jwt, false) do
      base_injections ++
        [
          # Phase 93 Plan 09: inject ClipboardHooks registration into host's
          # assets/js/app.js. Mirrors the existing passkeys app_js injection
          # pattern (anchor: :app_js_passkeys) without taking a structural
          # dependency on it — Pitfall X-3 isolation.
          %Injection{
            target: Path.join(["assets", "js", "app.js"]),
            marker: "// Sigra clipboard:start",
            anchor: :app_js_clipboard,
            content: read_template!("organizations/app_js_clipboard_injection.js")
          }
        ]
    else
      base_injections
    end
  end

  @impl true
  def migrations(binding) do
    base = [
      {:organizations, "organizations/migration.exs", "create_organizations.exs"},
      # Phase 24.1: moved out of the Core feature so the hard FK to the
      # organizations table lands after that table is created AND is
      # skipped entirely under --no-organizations.
      {:audit_events_org_columns, "core/alter_audit_events_add_org_columns.exs",
       "alter_audit_events_add_org_columns.exs"}
    ]

    if Keyword.get(Keyword.get(binding, :opts, []), :jwt, false) do
      base ++
        [
          {:service_accounts, "organizations/service_accounts_migration.exs",
           "create_service_accounts.exs"}
        ]
    else
      base
    end
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
  #
  # The templates contain EEx tags (`<%= web_module %>`, `<%= app_module %>`)
  # that MUST be evaluated against the installer binding before the
  # content is spliced into the target file. Splicing the raw file
  # content into the host router leaves literal `<%= web_module %>`
  # strings, which fail `mix compile` with `syntax error before: '<'`.
  # (Other feature modules that build their injections as Elixir string
  # heredocs with `#{var}` interpolation don't need this step.)
  # ──────────────────────────────────────────────────────────────────────────

  defp router_injection(otp_app, binding) do
    content = eval_template!("organizations/router_injection.ex", binding)

    %Injection{
      target: Path.join(["lib", "#{otp_app}_web", "router.ex"]),
      marker: "# Sigra organizations",
      anchor: :before_last_end,
      content: content
    }
  end

  defp eval_template!(relative_path, binding) do
    relative_path
    |> read_template!()
    |> EEx.eval_string(binding, trim: false)
  end

  # Local copy of the generic migration-target resolver. Duplicated from
  # the sibling feature's private helper (rather than referenced across
  # feature boundaries) to preserve the isolation invariant (Pitfall X-3):
  # no cross-feature module references in Organizations source.
  defp migration_target(binding, slot_key, basename) do
    ts =
      binding
      |> Keyword.get(:migration_timestamps, %{})
      |> Map.get(slot_key, "TIMESTAMP")

    Path.join(["priv", "repo", "migrations", "#{ts}_#{basename}"])
  end

  defp read_template!(relative_path) do
    # Resolve via Application.app_dir/2 so the path works whether the
    # installer runs from the sigra repo cwd or from a host app cwd
    # (mix sigra.install runs with cwd=host_app, where a relative
    # "priv/templates/..." path would not resolve).
    :sigra
    |> Application.app_dir(Path.join(["priv", "templates", "sigra.install", relative_path]))
    |> File.read!()
  end
end
