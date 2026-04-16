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
  def injections(_binding) do
    [
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
    |> Enum.filter(&String.contains?(&1, ~s(import { PasskeyHooks } from "./passkey_hooks")))
  end

  defp read_template!(relative_path) do
    Application.app_dir(:sigra, Path.join(["priv", "templates", "sigra.install", relative_path]))
    |> File.read!()
  end
end
