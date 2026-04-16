defmodule Sigra.Install.Features.Passkeys do
  @moduledoc """
  `Sigra.Install.Feature` implementation for the passkeys feature.

  Owns every template under `priv/templates/sigra.install/passkeys/` and the
  migration that creates the `user_passkeys` table.

  This module contains zero references to other install features.
  """

  @behaviour Sigra.Install.Feature

  alias Sigra.Install.Injection

  @impl true
  def enabled?(opts), do: Keyword.get(opts, :passkeys, true)

  @impl true
  def files(binding) do
    otp_app = Keyword.fetch!(binding, :otp_app) |> to_string()
    context_slug = binding |> Keyword.get(:context_alias, "Accounts") |> Macro.underscore()

    [
      {:eex, "passkeys/user_passkey.ex",
       Path.join(["lib", otp_app, context_slug, "user_passkey.ex"])},
      {:eex, "passkeys/passkey_browser.js", Path.join(["assets", "js", "passkey_browser.js"])},
      {:eex, "passkeys/passkey_hooks.js", Path.join(["assets", "js", "passkey_hooks.js"])}
    ]
  end

  @impl true
  def migrations(_binding) do
    [
      {:user_passkeys, "passkeys/create_user_passkeys.exs", "create_user_passkeys.exs"}
    ]
  end

  @impl true
  def injections(binding) do
    otp_app = binding |> Keyword.fetch!(:otp_app) |> to_string()

    [
      router_injection(otp_app, binding),
      config_injection(binding),
      mix_exs_injection(),
      package_json_injection(),
      %Injection{
        target: Path.join(["assets", "js", "app.js"]),
        marker: "// Sigra passkeys:start",
        anchor: :app_js_passkeys,
        content: read_template!("passkeys/app_js_passkeys_injection.js")
      }
    ]
  end

  @impl true
  def post_instructions(_binding, report) do
    report.manual_actions
    |> Enum.filter(fn instruction ->
      String.contains?(instruction, ~s(import { PasskeyHooks } from "./passkey_hooks")) or
        String.contains?(instruction, "`mix.exs`") or
        String.contains?(instruction, "`assets/package.json`")
    end)
  end

  defp router_injection(otp_app, binding) do
    %Injection{
      target: Path.join(["lib", "#{otp_app}_web", "router.ex"]),
      marker: "# Sigra passkeys",
      anchor: :before_last_end,
      content: eval_template!("passkeys/router_injection.ex", binding)
    }
  end

  defp config_injection(binding) do
    otp_app = binding |> Keyword.fetch!(:otp_app) |> to_string()

    %Injection{
      target: Path.join(["config", "config.exs"]),
      marker: "# Sigra passkeys",
      anchor: :elixir_config,
      content:
        eval_template!("passkeys/config_injection.ex", binding |> Keyword.put(:otp_app, otp_app))
    }
  end

  defp mix_exs_injection do
    %Injection{
      target: "mix.exs",
      marker: ~s({:wax_, "~> 0.7"}),
      anchor: :mix_deps,
      content: read_template!("passkeys/mix_exs_injection.ex")
    }
  end

  defp package_json_injection do
    %Injection{
      target: Path.join(["assets", "package.json"]),
      marker: ~s("@simplewebauthn/browser"),
      anchor: :package_json_dependencies,
      content: read_template!("passkeys/package_json_injection.json")
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
