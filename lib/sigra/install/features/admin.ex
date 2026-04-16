defmodule Sigra.Install.Features.Admin do
  @moduledoc """
  `Sigra.Install.Feature` implementation for the admin feature.

  Owns every template under `priv/templates/sigra.install/admin/`.
  The admin feature is enabled by default and omitted with
  `--no-admin`.

  Phase 27 Plan 01 keeps admin additive and host-boundary focused:
  the feature generates a small host policy module, a host-owned shell
  component, and a router injection that mounts `/admin` plus
  `/admin/organizations/:org` using normal Phoenix scopes,
  `RequireAdminAccess`, and `AdminScope`.

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

    [
      {:eex, "admin/policy.ex", Path.join(["lib", otp_app, "sigra_admin_policy.ex"])},
      {:eex, "admin/components/admin_shell.ex",
       Path.join(["lib", web, "components", "admin_shell.ex"])}
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
  def migrations(_binding), do: []

  @impl true
  def post_instructions(_binding, _report) do
    [
      """

      Sigra admin installed!

      Next steps:

        1. Review `lib/<app>/sigra_admin_policy.ex` and define platform-admin
           and org-admin access explicitly for your host app.

        2. Review the injected admin router scopes at `/admin` and
           `/admin/organizations/:org`, which already enforce the admin
           policy contract through Sigra's Plug and LiveView guards.

        3. Adjust `lib/<app>_web/components/admin_shell.ex` and the injected
           `Layouts.admin/1` function to match your product chrome.
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
      content: """
        attr :flash, :map, default: %{}, doc: "the map of flash messages"
        attr :current_scope, :map, default: nil
        attr :admin_scope, :map, default: nil
        attr :inner_content, :any, default: nil

        def admin(assigns) do
          ~H\"\"\"
          <.admin_shell admin_scope={@admin_scope} current_scope={@current_scope}>
            {@inner_content}
          </.admin_shell>

          <.flash_group flash={@flash} />
          \"\"\"
        end
      """
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
end
