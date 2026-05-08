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

  - Uses `mix phx.new --no-assets --no-install` to avoid network fetches and
    JS asset builds. The mailer scaffold is kept so Swoosh is present as a
    dep — `sigra.install`'s generated `core/auth_mailer.ex` template does
    `import Swoosh.Email` unconditionally, so the tmp app must be able to
    compile against Swoosh. Apps are generated under `System.tmp_dir!/0`
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
        ["phx.new", app_name, "--no-assets", "--no-install"],
        cd: tmp_root,
        stderr_to_stdout: true
      )

    if phx_status != 0 do
      raise "mix phx.new failed (status #{phx_status}):\n#{phx_out}"
    end

    app_dir = Path.join(tmp_root, app_name)

    # 2. Point the generated app at the in-tree sigra via a :path dependency
    patch_mix_exs_with_path_dep!(app_dir)

    # 3. Fetch deps locally (offline where possible). Hex may prompt for
    # interactive re-auth when a saved API token expired — subprocess harnesses
    # have no TTY, so pipe "n" to continue as anonymous fetch (public packages).
    mix_deps_get_noninteractive!(app_dir)

    # 4. Pre-compile deps so the sigra.install run does not spew dep compile
    #    noise into stdout. This keeps the captured install output focused on
    #    what the installer itself writes.
    {compile_out, compile_status} =
      System.cmd("mix", ["compile"],
        cd: app_dir,
        stderr_to_stdout: true,
        env: subprocess_env([{"MIX_ENV", "dev"}])
      )

    if compile_status != 0 do
      raise "pre-install mix compile failed:\n#{compile_out}"
    end

    # 5. Snapshot the baseline tree so we can compute the delta sigra.install
    #    introduces. This cleanly separates installer-owned files from the
    #    random bits phx.new sprinkles into config/*.exs.
    baseline_paths = snapshot_paths(app_dir)

    # 6. Run sigra.install and capture stdout
    {install_out, install_status} =
      System.cmd(
        "mix",
        ["sigra.install", "Accounts", "User", "users", "--yes"],
        cd: app_dir,
        stderr_to_stdout: true,
        env: subprocess_env([{"MIX_ENV", "dev"}])
      )

    if install_status != 0 do
      raise "mix sigra.install failed (status #{install_status}):\n#{install_out}"
    end

    {:ok,
     %{
       app_dir: app_dir,
       stdout: install_out,
       baseline_paths: baseline_paths
     }}
  end

  @doc """
  Scaffolds a fresh Phoenix tmp app with the path-dep to in-tree sigra patched in,
  deps fetched, and baseline compile done — but WITHOUT running `mix sigra.install`.

  Use this when you want to drive the installer yourself via `run_sigra_install/2`
  (e.g. to pass `--no-organizations` or other non-default flags), or to run the
  upgrade task against a v1.0-shape install.

  Preserves byte-identity with `setup_tmp_app/1` by mirroring its prep steps
  (phx.new + path-dep patch + deps.get + compile) without touching the existing
  function's body — golden_diff_test remains unaffected.

  Returns `{:ok, %{app_dir: path}}` on success.
  """
  @spec setup_tmp_app_without_install(keyword()) :: {:ok, %{app_dir: Path.t()}}
  def setup_tmp_app_without_install(opts \\ []) do
    app_name = Keyword.get(opts, :app_name, @app_name)
    tmp_root = Path.join(System.tmp_dir!(), "sigra_golden_#{:erlang.unique_integer([:positive])}")
    File.rm_rf!(tmp_root)
    File.mkdir_p!(tmp_root)

    {phx_out, phx_status} =
      System.cmd(
        "mix",
        ["phx.new", app_name, "--no-assets", "--no-install"],
        cd: tmp_root,
        stderr_to_stdout: true
      )

    if phx_status != 0 do
      raise "mix phx.new failed (status #{phx_status}):\n#{phx_out}"
    end

    app_dir = Path.join(tmp_root, app_name)

    patch_mix_exs_with_path_dep!(app_dir)

    mix_deps_get_noninteractive!(app_dir)

    {compile_out, compile_status} =
      System.cmd("mix", ["compile"],
        cd: app_dir,
        stderr_to_stdout: true,
        env: subprocess_env([{"MIX_ENV", "dev"}])
      )

    if compile_status != 0 do
      raise "pre-install mix compile failed:\n#{compile_out}"
    end

    {:ok, %{app_dir: app_dir}}
  end

  defp mix_deps_get_noninteractive!(app_dir) do
    {out, status} =
      System.cmd(
        "sh",
        ["-c", "echo n | mix deps.get"],
        cd: app_dir,
        stderr_to_stdout: true,
        env: subprocess_env([{"MIX_ENV", "dev"}])
      )

    if status != 0 do
      raise "mix deps.get failed (status #{status}):\n#{out}"
    end
  end

  @doc """
  Runs `mix sigra.install Accounts User users <flags> --yes` in an already-prepared
  tmp app with the given extra flags.

  Used by `test/upgrade_test.exs` to install with non-default flags (e.g.
  `--no-organizations`) in a tmp app that was set up with
  `setup_tmp_app_without_install/1`.

  Returns `{:ok, stdout}` on success; raises with captured stdout on failure.
  """
  @spec run_sigra_install(Path.t(), [String.t()]) :: {:ok, String.t()}
  def run_sigra_install(app_dir, flags) when is_list(flags) do
    args = ["sigra.install", "Accounts", "User", "users"] ++ flags ++ ["--yes"]

    {out, status} =
      System.cmd("mix", args,
        cd: app_dir,
        stderr_to_stdout: true,
        env: subprocess_env([{"MIX_ENV", "dev"}])
      )

    if status != 0 do
      raise """
      mix sigra.install #{Enum.join(flags, " ")} failed in #{app_dir}:

      #{out}
      """
    end

    {:ok, out}
  end

  @doc """
  Runs `mix sigra.upgrade <flags> --yes` in a tmp app. Mirror of `run_sigra_install/2`.

  Used by `test/upgrade_test.exs` to exercise the upgrade path after an initial
  v1.0-shape install.

  Returns `{:ok, stdout}` on success; raises with captured stdout on failure.
  """
  @spec run_sigra_upgrade(Path.t(), [String.t()]) :: {:ok, String.t()}
  def run_sigra_upgrade(app_dir, flags) when is_list(flags) do
    # `mix phx.new` runs `git init` without an initial commit, so the tmp app
    # is always "dirty" from sigra.upgrade's perspective. The fixture owns the
    # directory end-to-end, so --allow-dirty is always correct here.
    args = ["sigra.upgrade"] ++ flags ++ ["--allow-dirty", "--yes"]

    {out, status} =
      System.cmd("mix", args,
        cd: app_dir,
        stderr_to_stdout: true,
        env: subprocess_env([{"MIX_ENV", "dev"}])
      )

    if status != 0 do
      raise """
      mix sigra.upgrade #{Enum.join(flags, " ")} failed in #{app_dir}:

      #{out}
      """
    end

    {:ok, out}
  end

  @doc """
  Runs a raw `mix` command in a tmp app — escape hatch for seed helpers,
  `mix ecto.migrate`, etc. from `test/upgrade_test.exs`.

  Returns `{:ok, stdout}` on success; raises with captured stdout on failure.
  """
  @spec run_mix(Path.t(), [String.t()]) :: {:ok, String.t()}
  def run_mix(app_dir, args) when is_list(args) do
    {out, status} =
      System.cmd("mix", args,
        cd: app_dir,
        stderr_to_stdout: true,
        env: subprocess_env([{"MIX_ENV", "dev"}])
      )

    if status != 0 do
      raise """
      mix #{Enum.join(args, " ")} failed in #{app_dir}:

      #{out}
      """
    end

    {:ok, out}
  end

  @doc """
  Reads an asset file from the tmp app's `assets/` directory.
  """
  @spec read_asset_file(Path.t(), String.t()) :: binary()
  def read_asset_file(app_dir, relative_path) when is_binary(relative_path) do
    app_dir
    |> Path.join("assets")
    |> Path.join(relative_path)
    |> File.read!()
  end

  @doc """
  Overwrites an asset file in the tmp app's `assets/` directory.
  """
  @spec write_asset_file(Path.t(), String.t(), iodata()) :: :ok
  def write_asset_file(app_dir, relative_path, contents)
      when (is_binary(relative_path) and is_list(contents)) or is_binary(contents) do
    path =
      app_dir
      |> Path.join("assets")
      |> Path.join(relative_path)

    path
    |> Path.dirname()
    |> File.mkdir_p!()

    File.write!(path, contents)
  end

  @doc """
  Snapshot the set of {relative_path, content_hash} tuples under the tracked
  directories. Used to compute the sigra.install delta.
  """
  @spec snapshot_paths(Path.t()) :: %{String.t() => binary()}
  def snapshot_paths(app_dir) do
    tracked_dirs = ["lib", "priv/repo/migrations", "config", "test/support", "docs"]

    for sub <- tracked_dirs,
        abs_sub = Path.join(app_dir, sub),
        File.dir?(abs_sub),
        abs_path <- Path.wildcard(Path.join(abs_sub, "**"), match_dot: true),
        File.regular?(abs_path),
        into: %{} do
      rel = Path.relative_to(abs_path, app_dir)
      {rel, :crypto.hash(:sha256, File.read!(abs_path))}
    end
  end

  @doc """
  Walk the app tree and return a sorted list of `{normalized_path, content}`
  tuples for every generated file whose path belongs to the set of
  installer-owned directories (schemas, contexts, migrations, config edits,
  templates, LiveViews).

  Migration filenames under `priv/repo/migrations/<14-digit>_*.exs` have their
  14-digit timestamp prefix replaced with the literal string `TIMESTAMP` so
  wall-clock time does not pollute the diff. Migration bodies stay
  byte-identical aside from a single canonical trailing newline (same as all
  tracked files); `config/*.exs` additionally get deterministic salt
  placeholders via `normalize_content_for_golden/2`.
  """
  @spec normalize_tree(Path.t(), %{String.t() => binary()}) :: [{String.t(), binary()}]
  def normalize_tree(app_dir, baseline \\ %{}) do
    tracked_dirs = [
      "lib",
      "priv/repo/migrations",
      "config",
      "test/support",
      "docs"
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
    |> Enum.flat_map(fn abs_path ->
      rel = Path.relative_to(abs_path, app_dir)
      content = File.read!(abs_path)
      hash = :crypto.hash(:sha256, content)

      # Drop files that are byte-identical to the pre-install baseline. Only
      # files sigra.install created or modified contribute to the golden
      # snapshot.
      if Map.get(baseline, rel) == hash do
        []
      else
        [{normalize_path(rel), normalize_content_for_golden(rel, content)}]
      end
    end)
    |> Enum.sort_by(&elem(&1, 0))
  end

  # Phoenix's `mix phx.new` generator sprinkles random secrets into
  # config/*.exs (signing_salt, secret_key_base, live_view salt). Those are
  # carried forward when sigra.install injects into the same file, so they
  # pollute byte-level golden diffs even though sigra.install itself did not
  # touch them. Replace each with a deterministic placeholder.
  @doc """
  Normalizes installer-owned file contents for golden-diff comparison.

  Applies deterministic `config/*.exs` salt placeholders, strips trailing
  whitespace on each line (Phoenix template drift),   then strips trailing format chars / separators / whitespace with
  `~r/[\\p{Cf}\\p{Zs}\\s]+\\z/u` and ends with exactly one `\\n`.
  """
  @spec normalize_content_for_golden(String.t(), binary()) :: binary()
  def normalize_content_for_golden(rel, content) do
    content =
      if String.starts_with?(rel, "config/") do
        content
        |> String.replace(~r/signing_salt: "[^"]+"/, ~s(signing_salt: "<SIGNING_SALT>"))
        |> String.replace(~r/secret_key_base: "[^"]+"/, ~s(secret_key_base: "<SECRET_KEY_BASE>"))
        |> String.replace(
          ~r/live_view: \[signing_salt: "[^"]+"\]/,
          ~s(live_view: [signing_salt: "<LIVE_VIEW_SALT>"])
        )
        # Phoenix generator output occasionally drifts on trailing spaces per
        # line; strip so golden bytes stay stable across patch releases.
        |> String.replace("\r\n", "\n")
        |> String.replace("\r", "")
        |> String.split("\n")
        |> Enum.map(&String.trim_trailing/1)
        |> Enum.join("\n")
        # Collapse "blank" lines that contain only a single space (phx.new
        # drift shows up as `\n \n` in Myers diffs).
        |> collapse_newline_space_newlines()
        # Comma then spaces before newline — occasional generator drift.
        |> String.replace(~r/, +\n/, ",\n")
      else
        content
      end

    if String.starts_with?(rel, "config/") do
      # Strip trailing format chars (e.g. U+200B), separators, and ASCII
      # whitespace — phx.new / editor drift occasionally leaves these after
      # the logical end of `config/*.exs`.
      content =
        Regex.replace(~r/[\p{Cf}\p{Zs}\s]+\z/u, content, "")
        |> strip_ascii_eof_noise()

      content <> "\n"
    else
      String.trim_trailing(content, "\n") <> "\n"
    end
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
    # macOS resolves /tmp and /var/folders paths via /private/..., so the
    # compile output sometimes contains the /private-prefixed variant of the
    # app_dir while `app_dir` itself does not. Normalize both forms to <APP>.
    private_app_dir = "/private" <> app_dir

    raw
    |> strip_ansi()
    |> String.replace(private_app_dir, "<APP>")
    |> String.replace(app_dir, "<APP>")
    |> String.replace(~r/\b\d{14}_/, "TIMESTAMP_")
    |> String.replace("\r\n", "\n")
    |> String.split("\n")
    |> Enum.map(&String.trim_trailing/1)
    |> Enum.reject(&dep_compile_noise?/1)
    |> Enum.join("\n")
  end

  # Lines that come from Mix's dep compile machinery — they vary by OS,
  # Erlang version, and what's already cached in _build. Drop them from the
  # golden snapshot so only installer-owned output survives.
  defp dep_compile_noise?(line) do
    cond do
      String.starts_with?(line, "==> ") -> true
      String.starts_with?(line, "===> ") -> true
      String.match?(line, ~r/^Compiling \d+ files? \(\.ex\)$/) -> true
      String.match?(line, ~r/^Generated .+ app$/) -> true
      String.starts_with?(line, "cc ") -> true
      String.starts_with?(line, "mkdir -p ") -> true
      String.match?(line, ~r/^==> sigra(_| )/) -> true
      # OTP version warnings that Mix prints on some patch versions (e.g. OTP 28.0
      # warns about regex recompilation). These are environment-dependent and not
      # part of the installer's own output, so they must not affect byte-identity.
      String.match?(line, ~r/^warning! Erlang\/OTP \S+ detected\./) -> true
      String.starts_with?(line, "Regexes will be re-compiled from source at runtime") -> true
      String.match?(line, ~r/^This can be fixed by using Erlang OTP /) -> true
      true -> false
    end
  end

  # -- internals --------------------------------------------------------------

  @doc false
  def normalize_path_for_golden(rel), do: normalize_path(rel)

  defp strip_ascii_eof_noise(content) do
    stripped =
      cond do
        String.ends_with?(content, "\r\n ") ->
          binary_part(content, 0, byte_size(content) - 4)

        String.ends_with?(content, "\n ") ->
          binary_part(content, 0, byte_size(content) - 2)

        true ->
          content
      end

    if stripped == content, do: content, else: strip_ascii_eof_noise(stripped)
  end

  defp collapse_newline_space_newlines(content) do
    collapsed = String.replace(content, ~r/\n +\n/m, "\n\n")
    if collapsed == content, do: content, else: collapse_newline_space_newlines(collapsed)
  end

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

  defp subprocess_env(overrides) when is_list(overrides) do
    System.get_env()
    |> Map.merge(Enum.into(overrides, %{}))
    |> Map.to_list()
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
