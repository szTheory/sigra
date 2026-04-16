defmodule Sigra.Install.Features.Admin do
  @moduledoc """
  `Sigra.Install.Feature` implementation for the admin feature.

  Owns every template under `priv/templates/sigra.install/admin/`.
  The admin feature is enabled by default and omitted with
  `--no-admin`.

  Phase 27 Plan 01 keeps admin additive and host-boundary focused:
  the feature generates a small host policy module, a host-owned shell
  component, and a router injection that mounts `/admin` plus
  `/admin/organizations/:org` using normal Phoenix scopes and
  `live_session`.

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

    [
      %Injection{
        target: Path.join(["lib", "#{otp_app}_web", "router.ex"]),
        marker: "# Sigra admin",
        anchor: :before_last_end,
        content: eval_template!("admin/router_injection.ex", binding)
      }
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
           `/admin/organizations/:org` before wiring runtime enforcement
           in the next phase.

        3. Use `lib/<app>_web/components/admin_shell.ex` as the host-owned
           chrome seam for future admin pages.
      """
    ]
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
