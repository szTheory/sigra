defmodule Mix.Tasks.Sigra.Install do
  @moduledoc """
  Generates Sigra authentication scaffold.

  ## Usage

      mix sigra.install Accounts User users
      mix sigra.install Accounts User users --no-live
      mix sigra.install Accounts User users --api --jwt
      mix sigra.install Accounts User users --admin
      mix sigra.install Accounts User users --no-admin
      mix sigra.install Accounts User users --no-passkeys

  Arguments: `context_name schema_name table_name`.

  ## Options

    * `--live` / `--no-live` — Generate LiveView pages (default: true)
    * `--organizations` / `--no-organizations` — Generate organizations scaffolding (default: true)
    * `--binary-id` / `--no-binary-id` — UUID vs bigint PKs (default: true)
    * `--table` — Override the table name
    * `--api` — Generate API token controller (implied by `--jwt`)
    * `--jwt` — Generate JWT token controller
    * `--admin` / `--no-admin` — Generate admin scaffolding (default: true)
    * `--passkeys` / `--no-passkeys` — Generate passkey scaffolding (default: true)
    * `--yes` — Non-interactive mode (reserved; required by CI smoke jobs)

  ## Architecture (Phase 11)

  Thin walker caller. v1.0-specific concerns live in
  `Sigra.Install.Features.Core`; the generic `Sigra.Install.Runner`
  iterates `@features` and calls each feature's 5 callbacks. Adding a
  feature is purely additive — drop a module into `@features`.
  """
  @shortdoc "Generates Sigra authentication scaffold"

  use Mix.Task

  alias Sigra.Install.Runner

  @features [
    Sigra.Install.Features.Core,
    Sigra.Install.Features.Organizations,
    Sigra.Install.Features.Passkeys,
    Sigra.Install.Features.Admin
  ]

  @switches [
    live: :boolean,
    binary_id: :boolean,
    table: :string,
    api: :boolean,
    jwt: :boolean,
    organizations: :boolean,
    passkeys: :boolean,
    admin: :boolean,
    yes: :boolean
  ]
  @default_opts [
    live: true,
    api: false,
    jwt: false,
    binary_id: true,
    organizations: true,
    passkeys: true,
    admin: true
  ]

  @impl true
  def run(args) do
    {opts, parsed, _} = OptionParser.parse(args, switches: @switches)
    opts = Keyword.merge(@default_opts, opts)

    case parsed do
      [context_name, schema_name, table_name] ->
        validate_args!(context_name, schema_name, table_name)
        binding = build_binding(context_name, schema_name, opts[:table] || table_name, opts)
        {:ok, _report} = Runner.run(@features, binding, opts)

      _ ->
        Mix.raise("""
        Expected exactly 3 arguments: context_name schema_name table_name

        Usage:
            mix sigra.install Accounts User users
            mix sigra.install Accounts User users --no-live
            mix sigra.install Accounts User users --binary-id
        """)
    end
  end

  defp validate_args!(context_name, schema_name, table_name) do
    unless context_name =~ ~r/^[A-Z][A-Za-z0-9]*(\.[A-Z][A-Za-z0-9]*)*$/ do
      Mix.raise(
        "The context name must be a valid Elixir module name (e.g., Accounts), got: #{context_name}"
      )
    end

    unless schema_name =~ ~r/^[A-Z][A-Za-z0-9]*$/ do
      Mix.raise(
        "The schema name must be a valid Elixir module name (e.g., User), got: #{schema_name}"
      )
    end

    unless table_name =~ ~r/^[a-z][a-z0-9_]*$/ do
      Mix.raise("The table name must be a valid identifier (e.g., users), got: #{table_name}")
    end
  end

  defp build_binding(context_name, schema_name, table_name, opts) do
    base = Mix.Phoenix.base()
    web_module = Module.concat([Mix.Phoenix.web_module(base)])
    otp_app = Mix.Phoenix.otp_app()
    repo_module = get_repo_module(otp_app)
    adapter = detect_adapter(repo_module)
    app_name = otp_app |> to_string() |> Macro.camelize()

    [
      context_module: inspect(Module.concat([base, context_name])),
      context_alias: context_name,
      schema_module: inspect(Module.concat([base, context_name, schema_name])),
      schema_alias: schema_name,
      table_name: table_name,
      web_module: inspect(web_module),
      app_module: inspect(Module.concat([base])),
      app_name: app_name,
      from_email: "noreply@example.com",
      log_in_url: "/users/log_in",
      otp_app: otp_app,
      repo_module: inspect(repo_module),
      binary_id: Keyword.get(opts, :binary_id, true),
      live: opts[:live],
      api: opts[:api] || opts[:jwt] || false,
      jwt: opts[:jwt] || false,
      organizations?: Keyword.get(opts, :organizations, true),
      passkeys?: Keyword.get(opts, :passkeys, true),
      admin?: Keyword.get(opts, :admin, true),
      adapter: adapter,
      reset_password_url: "\#{#{inspect(web_module)}.Endpoint.url()}/users/reset-password",
      settings_url: "\#{#{inspect(web_module)}.Endpoint.url()}/users/settings",
      opts: opts
    ]
  end

  defp get_repo_module(otp_app) do
    case Application.get_env(otp_app, :ecto_repos, []) do
      [repo | _] -> repo
      [] -> Module.concat([Mix.Phoenix.base(), "Repo"])
    end
  end

  defp detect_adapter(repo_module) do
    if Code.ensure_loaded?(repo_module) and function_exported?(repo_module, :__adapter__, 0) do
      case repo_module.__adapter__() do
        Ecto.Adapters.Postgres -> :postgres
        Ecto.Adapters.MyXQL -> :mysql
        Ecto.Adapters.SQLite3 -> :sqlite
        _ -> :postgres
      end
    else
      :postgres
    end
  end
end
