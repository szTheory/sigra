defmodule Sigra.Install.Features.Admin do
  @moduledoc """
  `Sigra.Install.Feature` implementation for the admin feature.

  Owns every template under `priv/templates/sigra.install/admin/`.
  The admin feature is enabled by default and omitted with
  `--no-admin`.

  The feature stays additive and host-boundary focused: it generates a
  persisted, host-owned platform-admin grant seam and lifecycle tasks, a
  policy with allow/deny tests, a host-owned shell component, and router
  injections that mount `/admin` plus `/admin/organizations/:org` using
  normal Phoenix scopes, `RequireAdminAccess`, and `AdminScope`.

  This module contains zero references to other install features.
  """

  @behaviour Sigra.Install.Feature

  alias Sigra.Install.Injection

  @impl true
  def enabled?(opts), do: Keyword.get(opts, :admin, true)

  @impl true
  def files(binding) do
    otp_app = Keyword.fetch!(binding, :otp_app) |> to_string()
    web = "#{otp_app}_web"
    context = binding |> Keyword.get(:context_alias, "Accounts") |> Macro.underscore()

    [
      {:eex, "admin/create_platform_admin_grants.exs",
       migration_target(binding, :platform_admin_grants, "create_platform_admin_grants.exs")},
      {:eex, "admin/platform_admin_grant.ex",
       Path.join(["lib", otp_app, context, "platform_admin_grant.ex"])},
      {:eex, "admin/admin_access.ex", Path.join(["lib", otp_app, "sigra_admin_access.ex"])},
      {:eex, "admin/policy.ex", Path.join(["lib", otp_app, "sigra_admin_policy.ex"])},
      {:eex, "admin/policy_test.exs",
       Path.join(["test", otp_app, "sigra_admin_policy_test.exs"])},
      {:eex, "admin/mix_tasks/admin_task.ex",
       Path.join(["lib", "mix", "tasks", "sigra.admin.task.ex"])},
      {:eex, "admin/mix_tasks/grant.ex",
       Path.join(["lib", "mix", "tasks", "sigra.admin.grant.ex"])},
      {:eex, "admin/mix_tasks/revoke.ex",
       Path.join(["lib", "mix", "tasks", "sigra.admin.revoke.ex"])},
      {:eex, "admin/mix_tasks/list.ex",
       Path.join(["lib", "mix", "tasks", "sigra.admin.list.ex"])},
      {:eex, "admin/mix_tasks/check.ex",
       Path.join(["lib", "mix", "tasks", "sigra.admin.check.ex"])},
      {:eex, "admin/components/admin_shell.ex",
       Path.join(["lib", web, "components", "admin_shell.ex"])},
      {:eex, "admin/sigra-logo-primary.svg",
       Path.join(["priv", "static", "images", "sigra-logo-primary.svg"])},
      {:eex, "admin/sigra-logo-primary-dark.svg",
       Path.join(["priv", "static", "images", "sigra-logo-primary-dark.svg"])},
      {:eex, "admin/impersonation_controller.ex",
       Path.join(["lib", web, "controllers", "admin", "impersonation_controller.ex"])},
      {:eex, "admin/audit_export_controller.ex",
       Path.join(["lib", web, "controllers", "admin", "audit_export_controller.ex"])},
      {:eex, "admin/sigra_admin.css", Path.join(["priv", "static", "assets", "sigra_admin.css"])}
    ]
  end

  @impl true
  def injections(binding) do
    otp_app = Keyword.fetch!(binding, :otp_app) |> to_string()
    web_module = Keyword.fetch!(binding, :web_module)
    app_module = Keyword.fetch!(binding, :app_module)

    [
      router_injection(otp_app, binding),
      layouts_import_injection(otp_app, web_module),
      layouts_admin_injection(otp_app),
      error_handler_injection(otp_app, web_module, app_module)
    ]
  end

  @impl true
  def migrations(_binding) do
    [
      {:platform_admin_grants, "admin/create_platform_admin_grants.exs",
       "create_platform_admin_grants.exs"}
    ]
  end

  @impl true
  def post_instructions(_binding, _report) do
    [
      """

      Sigra admin installed!

      Next steps:

        1. Run `mix ecto.migrate`, then grant an existing confirmed account:

               mix sigra.admin.grant --email operator@example.com

           The generated host-owned policy delegates platform-admin checks to
           the persisted grant table. Keep `admin_org_ids/1` explicit for your
           application's organization-admin rules.

        2. Review the injected admin router scopes at `/admin` and
           `/admin/organizations/:org`, which already enforce the admin
           policy contract through Sigra's Plug and LiveView guards.

        3. Adjust `lib/<app>_web/components/admin_shell.ex` and your layouts
           so impersonation stays visibly persistent and the app-wide
           `/impersonation` stop action remains reachable from host-owned
           chrome.
      """
    ]
  end

  defp router_injection(otp_app, binding) do
    %Injection{
      target: Path.join(["lib", "#{otp_app}_web", "router.ex"]),
      marker: "# Sigra admin",
      anchor: :before_last_end,
      content: eval_template!("admin/router_injection.ex", binding)
    }
  end

  defp layouts_import_injection(otp_app, web_module) do
    %Injection{
      target: Path.join(["lib", "#{otp_app}_web", "components", "layouts.ex"]),
      marker: "import #{web_module}.Components.AdminShell",
      anchor: :after_use_block,
      content: "import #{web_module}.Components.AdminShell"
    }
  end

  defp layouts_admin_injection(otp_app) do
    %Injection{
      target: Path.join(["lib", "#{otp_app}_web", "components", "layouts.ex"]),
      marker: "def admin(assigns) do",
      anchor: :before_last_end,
      content: read_template!("admin/layouts_admin_injection.ex")
    }
  end

  defp error_handler_injection(otp_app, _web_module, _app_module) do
    %Injection{
      target: Path.join(["lib", "#{otp_app}_web", "auth_error_handler.ex"]),
      marker: "def auth_error(conn, :insufficient_scope, _opts) do",
      anchor: :before_last_end,
      content: """
        @impl true
        def auth_error(conn, :insufficient_scope, _opts) do
          conn
          |> put_status(:forbidden)
          |> put_resp_content_type("text/html")
          |> send_resp(
            403,
            "Access denied. You do not have access to this admin scope."
          )
        end

        @impl true
        def auth_error(conn, :not_found, _opts) do
          conn
          |> put_status(:not_found)
          |> put_resp_content_type("text/html")
          |> send_resp(
            404,
            "Not found. This organization admin scope is unavailable."
          )
        end
      """
    }
  end

  defp eval_template!(relative_path, binding) do
    relative_path
    |> read_template!()
    |> EEx.eval_string(binding, trim: false)
  end

  defp read_template!(relative_path) do
    Application.app_dir(:sigra, Path.join(["priv", "templates", "sigra.install", relative_path]))
    |> File.read!()
  end

  defp migration_target(binding, slot_key, basename) do
    timestamp =
      binding
      |> Keyword.get(:migration_timestamps, %{})
      |> Map.get(slot_key, "TIMESTAMP")

    Path.join(["priv", "repo", "migrations", "#{timestamp}_#{basename}"])
  end
end
