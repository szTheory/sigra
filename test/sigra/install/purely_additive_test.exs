defmodule Sigra.Install.PurelyAdditiveTest do
  @moduledoc """
  V-PA-01: mechanical proof that the walker is feature-agnostic.

  Defines a `FakeFeature` module implementing `Sigra.Install.Feature`
  and drives it through `Sigra.Install.Runner.run/3` against a tmp
  directory. The test succeeds *without any source edits* to
  `lib/sigra/install/runner.ex` or `lib/mix/tasks/sigra.install.ex` —
  proving the "purely additive" invariant: adding a feature in a
  future phase requires nothing more than implementing the behaviour
  and appending the module to `@features`.

  See Phase 11 CONTEXT.md V-PA-01 and RESEARCH.md §Validation
  Architecture.
  """
  use ExUnit.Case, async: false

  @moduletag :purely_additive

  alias Sigra.Install.Injection
  alias Sigra.Install.Runner

  defmodule FakeFeature do
    @moduledoc false
    @behaviour Sigra.Install.Feature

    alias Sigra.Install.Injection

    @impl true
    def enabled?(_opts), do: true

    @impl true
    def files(binding) do
      tmp = Keyword.fetch!(binding, :tmp_dir)

      ts =
        binding
        |> Keyword.get(:migration_timestamps, %{})
        |> Map.get(:fake_slot, "19700101000000")

      migration_target =
        Path.join([tmp, "priv", "repo", "migrations", "#{ts}_create_fake.exs"])

      [
        {:eex, "fake/hello.txt", Path.join(tmp, "hello.txt")},
        {:eex, "fake/fake_migration.exs", migration_target}
      ]
    end

    @impl true
    def injections(binding) do
      tmp = Keyword.fetch!(binding, :tmp_dir)

      [
        %Injection{
          target: Path.join(tmp, "router.ex"),
          marker: "# fake:injected",
          anchor: :at_top,
          content: "# fake:injected\n# fake line"
        }
      ]
    end

    @impl true
    def migrations(_binding) do
      [{:fake_slot, "fake/fake_migration.exs", "create_fake.exs"}]
    end

    @impl true
    def post_instructions(_binding, _report), do: ["Fake feature done.\n"]
  end

  setup do
    tmp =
      Path.join(System.tmp_dir!(), "sigra_purely_additive_#{System.unique_integer([:positive])}")

    File.mkdir_p!(Path.join([tmp, "priv", "repo", "migrations"]))
    File.write!(Path.join(tmp, "router.ex"), "defmodule Router do\nend\n")

    # Write a fake template that Runner.find_template/1 can resolve via
    # the host-app override path (cwd/priv/templates/sigra.install/<source>).
    File.mkdir_p!(Path.join([tmp, "priv", "templates", "sigra.install", "fake"]))

    File.write!(
      Path.join([tmp, "priv", "templates", "sigra.install", "fake", "hello.txt"]),
      "hello world\n"
    )

    File.write!(
      Path.join([tmp, "priv", "templates", "sigra.install", "fake", "fake_migration.exs"]),
      "defmodule Repo.Migrations.CreateFake do\nend\n"
    )

    on_exit(fn -> File.rm_rf!(tmp) end)
    {:ok, tmp: tmp}
  end

  test "FakeFeature is walked by Runner with zero edits to runner.ex or sigra.install.ex",
       %{tmp: tmp} do
    cwd_before = File.cwd!()
    File.cd!(tmp)

    try do
      binding = [tmp_dir: tmp, opts: []]

      # Mix.shell().info output is captured to keep test output clean.
      ExUnit.CaptureIO.capture_io(fn ->
        assert {:ok, _report} = Runner.run([FakeFeature], binding, [])
      end)

      # File written
      assert File.read!(Path.join(tmp, "hello.txt")) =~ "hello world"

      # Injection applied
      assert File.read!(Path.join(tmp, "router.ex")) =~ "# fake:injected"

      # Migration written with a timestamped filename
      migrations = File.ls!(Path.join([tmp, "priv", "repo", "migrations"]))
      assert Enum.any?(migrations, fn f -> f =~ ~r/^\d{14}_create_fake\.exs$/ end)
    after
      File.cd!(cwd_before)
    end
  end

  test "sigra.install.ex contains no feature-specific branches (grep assertion)" do
    source = File.read!("lib/mix/tasks/sigra.install.ex")

    # Feature modules may appear in the @features list, but nowhere else.
    admin_mentions = Regex.scan(~r/Sigra\.Install\.Features\.Admin/, source) |> length()
    assert admin_mentions == 1, "Features.Admin should appear exactly once in the @features list"

    # Organizations must be declared *only* via the @features list entry,
    # never via case-match or per-feature branching.
    assert source =~ "Sigra.Install.Features.Organizations",
           "sigra.install.ex must register Features.Organizations in @features (Phase 18 Plan 18-01)"

    assert source =~ "Sigra.Install.Features.Passkeys",
           "sigra.install.ex must register Features.Passkeys in @features"

    # The Mix task must declare a @features module attribute — this is
    # the single extensibility point where future features are listed.
    assert source =~ "@features", "sigra.install.ex must declare @features module attribute"

    refute source =~ ~r/case\s+feature\s+do/,
           "sigra.install.ex must not case-match on feature modules"
  end

  test "runner.ex contains no feature-specific code branches" do
    source = File.read!("lib/sigra/install/runner.ex")
    code = strip_docstrings(source)

    refute code =~ "Features.Core",
           "runner.ex code must be feature-agnostic (docstring references OK)"

    refute code =~ "Features.Organizations"
    refute code =~ "Features.Passkeys"
    refute code =~ "Features.Admin"
  end

  # Removes `@moduledoc """..."""` and `@doc """..."""` heredoc blocks
  # so symbol checks target executable code only. Documentation is
  # allowed to reference future feature names (the whole point of the
  # docs is to explain the isolation invariant).
  defp strip_docstrings(source) do
    source
    |> String.replace(~r/@moduledoc\s+"""[\s\S]*?"""/m, "")
    |> String.replace(~r/@doc\s+"""[\s\S]*?"""/m, "")
    |> String.replace(~r/@shortdoc\s+"[^"]*"/m, "")
  end
end
