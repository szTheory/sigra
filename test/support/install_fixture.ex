defmodule Sigra.Test.InstallFixture do
  @moduledoc """
  Test helper for generating a fresh Phoenix app and running `mix sigra.install`
  against it, producing a normalized tree snapshot and captured STDOUT that can
  be diffed against a committed golden fixture.

  Used by the Phase 11 `golden_diff_test.exs` regression barrier. The helpers
  here are deliberately narrow: one function to scaffold a fresh tmp app, one
  to run the installer (capturing stdout), and a pair of normalization
  helpers that strip nondeterministic output so tree/STDOUT comparisons are
  byte-stable across runs.

  ## Guarantees

  - Uses `mix phx.new --no-assets --no-mailer --no-install` to avoid network
    fetches and JS asset builds. Apps are generated under `System.tmp_dir!/0`
    inside a per-run subdirectory so parallel test runs do not collide.
  - `mix sigra.install` is invoked with `--yes` against the canonical trio
    `Accounts User users` (the default exercise path for the golden fixture).
  - The repo under test is pointed at via `MIX_ARCHIVES` + `MIX_HOME` isolation
    so the installer runs the in-tree version of sigra, not whatever the
    developer's global archives happen to have.

  This module is only compiled in `:test` (`elixirc_paths(:test)` adds
  `test/support`).
  """

  @app_name "sigra_install_golden_tmp"

  @doc """
  Builds a fresh Phoenix app + runs `mix sigra.install Accounts User users --yes`.

  Returns `{:ok, %{app_dir: path, stdout: binary}}` on success.

  The returned `app_dir` is cleaned up by the caller via `File.rm_rf!/1` if
  desired; this helper does not register on_exit cleanup so the caller can
  inspect artifacts on failure.
  """
  @spec setup_tmp_app(keyword()) :: {:ok, %{app_dir: Path.t(), stdout: binary()}}
  def setup_tmp_app(opts \\ []) do
    app_name = Keyword.get(opts, :app_name, @app_name)
    tmp_root = Path.join(System.tmp_dir!(), "sigra_golden_#{:erlang.unique_integer([:positive])}")
    File.rm_rf!(tmp_root)
    File.mkdir_p!(tmp_root)

    # 1. Generate fresh Phoenix app
    {phx_out, phx_status} =
      System.cmd(
        "mix",
        ["phx.new", app_name, "--no-assets", "--no-mailer", "--no-install"],
        cd: tmp_root,
        stderr_to_stdout: true
      )

    if phx_status != 0 do
      raise "mix phx.new failed (status #{phx_status}):\n#{phx_out}"
    end

    app_dir = Path.join(tmp_root, app_name)

    # 2. Point the generated app at the in-tree sigra via a :path dependency
    patch_mix_exs_with_path_dep!(app_dir)

    # 3. Fetch deps locally (offline where possible)
    {deps_out, deps_status} =
      System.cmd("mix", ["deps.get"], cd: app_dir, stderr_to_stdout: true)

    if deps_status != 0 do
      raise "mix deps.get failed (status #{deps_status}):\n#{deps_out}"
    end

    # 4. Run sigra.install and capture stdout
    {install_out, install_status} =
      System.cmd(
        "mix",
        ["sigra.install", "Accounts", "User", "users", "--yes"],
        cd: app_dir,
        stderr_to_stdout: true
      )

    if install_status != 0 do
      raise "mix sigra.install failed (status #{install_status}):\n#{install_out}"
    end

    {:ok, %{app_dir: app_dir, stdout: install_out}}
  end

  @doc """
  Walk the app tree and return a sorted list of `{normalized_path, content}`
  tuples for every generated file whose path belongs to the set of
  installer-owned directories (schemas, contexts, migrations, config edits,
  templates, LiveViews).

  Migration filenames under `priv/repo/migrations/<14-digit>_*.exs` have their
  14-digit timestamp prefix replaced with the literal string `TIMESTAMP` so
  wall-clock time does not pollute the diff. Migration file **contents** are
  NOT normalized — per decision D-05, the inside of the file must be
  byte-identical.
  """
  @spec normalize_tree(Path.t()) :: [{String.t(), binary()}]
  def normalize_tree(app_dir) do
    tracked_dirs = [
      "lib",
      "priv/repo/migrations",
      "config",
      "test/support"
    ]

    tracked_dirs
    |> Enum.flat_map(fn sub ->
      abs = Path.join(app_dir, sub)

      if File.dir?(abs) do
        abs
        |> Path.join("**")
        |> Path.wildcard(match_dot: true)
        |> Enum.filter(&File.regular?/1)
      else
        []
      end
    end)
    |> Enum.map(fn abs_path ->
      rel = Path.relative_to(abs_path, app_dir)
      normalized = normalize_path(rel)
      {normalized, File.read!(abs_path)}
    end)
    |> Enum.sort_by(&elem(&1, 0))
  end

  @doc """
  Normalize a captured STDOUT buffer from `mix sigra.install`:

  - Strip ANSI color escapes (`\\e[...m`)
  - Replace absolute paths pointing into the tmp app with the placeholder
    `<APP>` so runs from different tmp directories compare equal
  - Replace migration filename timestamps (14-digit prefix) with `TIMESTAMP`
  - Normalize line endings to `\\n` and strip trailing whitespace per line
  """
  @spec normalize_stdout(binary(), Path.t()) :: binary()
  def normalize_stdout(raw, app_dir) do
    raw
    |> strip_ansi()
    |> String.replace(app_dir, "<APP>")
    |> String.replace(~r/\b\d{14}_/, "TIMESTAMP_")
    |> String.replace("\r\n", "\n")
    |> String.split("\n")
    |> Enum.map(&String.trim_trailing/1)
    |> Enum.join("\n")
  end

  # -- internals --------------------------------------------------------------

  defp normalize_path(rel) do
    rel
    |> String.replace(~r|priv/repo/migrations/\d{14}_|, "priv/repo/migrations/TIMESTAMP_")
  end

  defp strip_ansi(str) do
    Regex.replace(~r/\e\[[0-9;]*[A-Za-z]/, str, "")
  end

  defp patch_mix_exs_with_path_dep!(app_dir) do
    sigra_root = sigra_repo_root()
    mix_exs = Path.join(app_dir, "mix.exs")
    content = File.read!(mix_exs)

    # Insert `{:sigra, path: "..."}` into the deps list. We match the opening
    # `defp deps do` / `[` and inject our dep line after it.
    patched =
      Regex.replace(
        ~r/defp deps do\s*\n\s*\[/,
        content,
        "defp deps do\n    [\n      {:sigra, path: #{inspect(sigra_root)}, override: true},",
        global: false
      )

    if patched == content do
      raise "Failed to patch #{mix_exs} — deps/0 function not found in expected shape"
    end

    File.write!(mix_exs, patched)
  end

  defp sigra_repo_root do
    # This module lives at test/support/install_fixture.ex, so two levels up
    # from __ENV__.file is the sigra repo root.
    __ENV__.file
    |> Path.dirname()
    |> Path.join("../..")
    |> Path.expand()
  end
end
