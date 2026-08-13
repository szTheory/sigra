defmodule Sigra.Install.Features.AppSessions do
  @moduledoc """
  Additive installer feature for first-party app-session ownership.

  The feature is selected only by `--app-sessions`. Direct password login is
  intentionally a separate binding consumed by later ceremony templates; the
  installer rejects it unless this feature is explicitly selected.
  """

  @behaviour Sigra.Install.Feature

  alias Sigra.Install.Injection

  @impl true
  def enabled?(opts), do: Keyword.get(opts, :app_sessions, false)

  @impl true
  def files(binding) do
    if enabled?(Keyword.get(binding, :opts, [])) do
      otp_app = binding |> Keyword.fetch!(:otp_app) |> to_string()
      context = binding |> Keyword.fetch!(:context_alias) |> Macro.underscore()

      [
        {:eex, "app_sessions/user_app_session_family.ex",
         Path.join(["lib", otp_app, context, "user_app_session_family.ex"])},
        {:eex, "app_sessions/user_app_session_token.ex",
         Path.join(["lib", otp_app, context, "user_app_session_token.ex"])},
        {:eex, "app_sessions/user_app_login_attempt.ex",
         Path.join(["lib", otp_app, context, "user_app_login_attempt.ex"])},
        {:eex, "app_sessions/first_party_apps.ex",
         Path.join(["lib", otp_app, context, "first_party_apps.ex"])},
        {:eex, "app_sessions/auth_app_sessions.ex",
         Path.join(["lib", otp_app, context, "auth", "app_sessions.ex"])},
        {:eex, "app_sessions/app_login_controller.ex",
         Path.join(["lib", "#{otp_app}_web", "controllers", "app_login_controller.ex"])},
        {:eex, "app_sessions/app_login_html.ex",
         Path.join(["lib", "#{otp_app}_web", "controllers", "app_login_html.ex"])},
        {:eex, "app_sessions/app_login_approve.html.heex",
         Path.join([
           "lib",
           "#{otp_app}_web",
           "controllers",
           "app_login_html",
           "approve.html.heex"
         ])},
        {:eex, "app_sessions/app_login_continuation.ex",
         Path.join(["lib", "#{otp_app}_web", "app_login_continuation.ex"])},
        {:eex, "app_sessions/app_sessions_migration.exs",
         migration_target(binding, :ceremony, "create_user_app_sessions.exs")}
      ]
    else
      []
    end
  end

  @impl true
  def injections(binding) do
    otp_app = binding |> Keyword.fetch!(:otp_app) |> to_string()

    [
      %Injection{
        target: Path.join(["lib", "#{otp_app}_web", "router.ex"]),
        marker: "# Sigra app login",
        anchor: :before_last_end,
        content: eval_template!("app_sessions/router_injection.ex", binding)
      }
    ]
  end

  @impl true
  def migrations(_binding) do
    [
      {:family, "app_sessions/user_app_session_family_migration.exs",
       "create_user_app_session_families.exs"},
      {:token, "app_sessions/user_app_session_token_migration.exs",
       "create_user_app_session_tokens.exs"},
      {:ceremony, "app_sessions/app_sessions_migration.exs", "create_user_app_sessions.exs"}
    ]
  end

  @impl true
  def post_instructions(_binding, _report), do: []

  @doc false
  def migration_target(binding, slot_key, basename) do
    timestamp =
      binding
      |> Keyword.get(:migration_timestamps, %{})
      |> Map.get(slot_key, "TIMESTAMP")

    Path.join(["priv", "repo", "migrations", "#{timestamp}_#{basename}"])
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
