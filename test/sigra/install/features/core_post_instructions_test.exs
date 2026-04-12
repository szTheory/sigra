defmodule Sigra.Install.Features.CorePostInstructionsTest do
  @moduledoc """
  Fixture-mode tests for the Oban-detection and Swoosh-detection branches
  of `Sigra.Install.Features.Core.post_instructions/2`, ported from the
  v1.0 monolith's `inject_oban_queue/1` and `inject_swoosh_config/2`
  private helpers.

  Each test stages a host-app `config/` directory in a temp dir, `cd`s
  into it, and asserts (a) the iodata output and (b) — for the Swoosh
  case — the preserved file-mutation side effect.

  These tests are `async: false` because they `File.cd!/1`.
  """
  use ExUnit.Case, async: false

  alias Sigra.Install.Features.Core
  alias Sigra.Install.Report

  # Features.Core.post_instructions/2 returns iodata containing ANSI
  # color atoms (`:yellow`, `:green`, `:reset`, ...) — valid for
  # `Mix.shell().info/1` but not for `IO.iodata_to_binary/1`. Strip ANSI
  # codes before string-inspecting so the tests compare plain text.
  defp render(iodata) do
    iodata
    |> IO.ANSI.format(false)
    |> IO.iodata_to_binary()
  end

  @binding [
    otp_app: :my_app,
    context_alias: "Accounts",
    context_module: "MyApp.Accounts",
    schema_module: "MyApp.Accounts.User",
    schema_alias: "User",
    table_name: "users",
    web_module: "MyAppWeb",
    app_module: "MyApp",
    app_name: "MyApp",
    from_email: "noreply@example.com",
    log_in_url: "/users/log_in",
    repo_module: "MyApp.Repo",
    binary_id: true,
    live: true,
    api: false,
    jwt: false,
    adapter: :postgres,
    opts: [live: true, api: false, jwt: false, binary_id: true]
  ]

  setup do
    tmp =
      Path.join(System.tmp_dir!(), "sigra_post_instr_#{System.unique_integer([:positive])}")

    File.mkdir_p!(Path.join(tmp, "config"))
    cwd = File.cwd!()
    File.cd!(tmp)

    on_exit(fn ->
      File.cd!(cwd)
      File.rm_rf!(tmp)
    end)

    {:ok, tmp: tmp}
  end

  describe "Oban detection branch" do
    test "Oban in config/config.exs emits queue instruction" do
      File.write!(
        "config/config.exs",
        "import Config\nconfig :my_app, Oban, repo: MyApp.Repo\n"
      )

      out = @binding |> Core.post_instructions(Report.new()) |> render()

      assert out =~ "detected Oban config"
      assert out =~ "config/config.exs"
      assert out =~ "sigra_mailer: 10"
      refute out =~ "Oban not detected"
    end

    test "Oban in config/runtime.exs is preferred over config/config.exs" do
      File.write!(
        "config/config.exs",
        "import Config\n# no Oban here\n"
      )

      File.write!(
        "config/runtime.exs",
        "import Config\nconfig :my_app, Oban, repo: MyApp.Repo\n"
      )

      out = @binding |> Core.post_instructions(Report.new()) |> render()

      assert out =~ "detected Oban config"
      assert out =~ "config/runtime.exs"
    end

    test "Oban already configured with sigra_mailer queue emits already-configured line" do
      File.write!(
        "config/config.exs",
        """
        import Config
        config :my_app, Oban,
          repo: MyApp.Repo,
          queues: [default: 10, sigra_mailer: 10]
        """
      )

      out = @binding |> Core.post_instructions(Report.new()) |> render()

      assert out =~ "already configured"
      assert out =~ "Oban sigra_mailer queue"
      refute out =~ "detected Oban config"
    end

    test "Oban absent emits the synchronous-mode warning" do
      File.write!("config/config.exs", "import Config\n")

      out = @binding |> Core.post_instructions(Report.new()) |> render()

      assert out =~ "Oban not detected"
      assert out =~ "synchronous mode"
      assert out =~ "To enable async delivery"
    end

    test "neither config/config.exs nor config/runtime.exs present still emits Oban-absent warning" do
      # No config files staged at all — the Oban branch should take the "nil" path.
      out = @binding |> Core.post_instructions(Report.new()) |> render()

      assert out =~ "Oban not detected"
    end
  end

  describe "Swoosh detection branch" do
    test "config/dev.exs containing Swoosh emits already-configured line and does NOT mutate the file" do
      original =
        "import Config\nconfig :my_app, MyApp.Mailer, adapter: Swoosh.Adapters.Local\n"

      File.write!("config/dev.exs", original)

      out = @binding |> Core.post_instructions(Report.new()) |> render()

      assert out =~ "already configured"
      assert out =~ "Swoosh"
      assert out =~ "config/dev.exs"

      # File is not mutated when Swoosh is already present.
      assert File.read!("config/dev.exs") == original
    end

    test "config/dev.exs without Swoosh is mutated to include Swoosh dev config (side effect preserved)" do
      File.write!("config/dev.exs", "import Config\n")

      out = @binding |> Core.post_instructions(Report.new()) |> render()

      assert out =~ "injecting"
      assert out =~ "Swoosh dev config"
      assert out =~ "config/dev.exs"

      after_content = File.read!("config/dev.exs")
      assert after_content =~ "Swoosh.Adapters.Local"
      assert after_content =~ "config :swoosh, :api_client, false"
      # Preserve original content
      assert String.starts_with?(after_content, "import Config\n")
    end

    test "missing config/dev.exs produces no Swoosh output (no-op)" do
      File.write!("config/config.exs", "import Config\n")
      refute File.exists?("config/dev.exs")

      out = @binding |> Core.post_instructions(Report.new()) |> render()

      refute out =~ "Swoosh"
      # But the rest of the output is still there
      assert out =~ "Sigra authentication has been installed"
    end

    test "Swoosh mutation uses app_module from binding (raw Swoosh.Mailer target)" do
      File.write!("config/dev.exs", "import Config\n")

      binding = Keyword.put(@binding, :app_module, "CustomApp")
      _out = binding |> Core.post_instructions(Report.new()) |> render()

      after_content = File.read!("config/dev.exs")
      assert after_content =~ "config :my_app, CustomApp.Mailer"
    end
  end

  describe "base instruction content" do
    test "returns non-empty output mentioning Sigra" do
      out = @binding |> Core.post_instructions(Report.new()) |> render()

      assert out =~ "Sigra"
      assert String.length(out) > 100
      assert out =~ "mix ecto.migrate"
    end

    test "live mode includes LiveView instruction line" do
      binding = Keyword.put(@binding, :opts, live: true, api: false, jwt: false)
      out = binding |> Core.post_instructions(Report.new()) |> render()

      assert out =~ "LiveView pages were generated"
    end

    test "no-live mode includes the controller fallback line" do
      binding = Keyword.put(@binding, :opts, live: false, api: false, jwt: false)
      out = binding |> Core.post_instructions(Report.new()) |> render()

      assert out =~ "LiveView pages were NOT generated"
    end

    test "--api adds API token endpoint instructions" do
      binding = Keyword.put(@binding, :opts, live: true, api: true, jwt: false)
      out = binding |> Core.post_instructions(Report.new()) |> render()

      assert out =~ "/api/tokens"
      assert out =~ "auth_api_token.ex"
    end

    test "--jwt adds JWT endpoint instructions" do
      binding = Keyword.put(@binding, :opts, live: true, api: false, jwt: true)
      out = binding |> Core.post_instructions(Report.new()) |> render()

      assert out =~ "/api/auth/token"
    end
  end
end
