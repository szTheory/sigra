defmodule Sigra.Install.TemplateRenderTest do
  @moduledoc """
  D-06.1 regression guard for Phase 24.

  Walks every `.ex` template under
  `priv/templates/sigra.install/organizations/` and verifies:

  1. `EEx.eval_file/2` renders the file without raising.
  2. The rendered content parses as valid Elixir via
     `Code.string_to_quoted/1`.

  This catches the DEF-18-01 bug class (HEEx inside EEx causing
  `CompileError: undefined variable "assigns"`) in a fast, narrow
  unit test that does NOT require the full `InstallFixture` harness.
  """
  use ExUnit.Case, async: true

  @moduletag :install

  # Fixture binding matches `lib/mix/tasks/sigra.install.ex:97-119` plus
  # `migration_timestamps: %{}` added by `lib/sigra/install/runner.ex:60`.
  @render_binding [
    web_module: "FixtureAppWeb",
    app_module: "FixtureApp",
    context_module: "FixtureApp.Accounts",
    context_alias: "Accounts",
    schema_module: "FixtureApp.Accounts.User",
    schema_alias: "User",
    table_name: "users",
    app_name: "FixtureApp",
    otp_app: :fixture_app,
    from_email: "noreply@example.com",
    log_in_url: "/users/log_in",
    repo_module: "FixtureApp.Repo",
    binary_id: true,
    live: true,
    api: false,
    jwt: false,
    organizations?: true,
    passkeys?: true,
    adapter: :postgres,
    reset_password_url: "http://localhost:4000/users/reset-password",
    settings_url: "http://localhost:4000/users/settings",
    opts: [live: true, api: false, jwt: false, binary_id: true, organizations: true, passkeys: true],
    migration_timestamps: %{}
  ]

  describe "organizations/**/*.ex templates" do
    for path <- Path.wildcard("priv/templates/sigra.install/organizations/**/*.ex") do
      @path path

      test "renders and parses: #{@path}" do
        content =
          try do
            EEx.eval_file(@path, @render_binding)
          rescue
            e ->
              flunk(
                "EEx.eval_file raised for #{@path}: #{inspect(e)}\n" <>
                  "Usual cause: HEEx `<%= ... %>` inside a `~H\"\"\"` heredoc where EEx sees `@assigns` first. " <>
                  "Fix by lifting the case into Elixir and using `{...}` curly-brace HEEx interpolation."
              )
          end

        assert is_binary(content), "expected binary, got #{inspect(content)}"

        assert {:ok, _ast} = Code.string_to_quoted(content, file: @path),
               "rendered content of #{@path} is not valid Elixir"
      end
    end
  end
end
