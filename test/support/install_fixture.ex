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
  @prepared_key {__MODULE__, :prepared_graph}
  @manifest_name ".sigra-install-fixture.json"
  @diagnostic_path "/tmp/sigra-install-golden-diagnostics.json"
  @scenario_table :sigra_install_fixture_scenarios
  @diagnostic_phases [
    :phx_new,
    :deps_get,
    :baseline_compile,
    :installer,
    :receiver_compile_runtime,
    :checkout_copy
  ]
  @variant_names [
    :default_installed,
    :passkeys_standard,
    :passkeys_nonstandard_app_js,
    :no_passkeys,
    :no_org_no_passkeys,
    :no_org_installed
  ]
  @variant_flags %{
    default_installed: [],
    passkeys_standard: ["--passkeys"],
    passkeys_nonstandard_app_js: ["--passkeys"],
    no_passkeys: ["--no-passkeys"],
    no_org_no_passkeys: ["--no-organizations", "--no-passkeys"],
    no_org_installed: ["--no-organizations"]
  }
  @standard_app_js """
  import "phoenix_html"
  import { Socket } from "phoenix"
  import { LiveSocket } from "phoenix_live_view"
  import topbar from "../vendor/topbar"
  import { hooks as colocatedHooks } from "phoenix-colocated/my_app"

  const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
  const liveSocket = new LiveSocket("/live", Socket, {
    longPollFallbackMs: 2500,
    params: { _csrf_token: csrfToken },
    hooks: { ...colocatedHooks },
  })

  topbar.config({ barColors: { 0: "#29d" }, shadowColor: "rgba(0, 0, 0, .3)" })
  window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
  window.addEventListener("phx:page-loading-stop", _info => topbar.hide())
  liveSocket.connect()
  window.liveSocket = liveSocket
  """
  @nonstandard_app_js """
  import "phoenix_html"
  import { Socket } from "phoenix"
  import topbar from "../vendor/topbar"

  const socket = new Socket("/socket", {})
  socket.connect()

  window.topbar = topbar
  """

  @doc "Returns the fixed prepared-state universe in construction order."
  def variant_names, do: @variant_names

  @doc "Builds and publishes one immutable prepared-fixture graph."
  def prepare_graph!(opts \\ []) do
    root = Keyword.get_lazy(opts, :root, &new_graph_root!/0) |> validate_graph_root!()
    Process.put({__MODULE__, :building_root}, root)
    fingerprint = Keyword.get_lazy(opts, :fingerprint, &compatibility_fingerprint/0)
    base_path = Path.join([root, "source", @app_name])
    manifest_path = Path.join(root, @manifest_name)
    base_builder = Keyword.get(opts, :base_builder, &build_source_base!/1)
    variant_builder = Keyword.get(opts, :variant_builder, &build_variant!/2)

    File.mkdir_p!(Path.dirname(base_path))
    started = monotonic_ms()

    timings =
      case base_builder.(base_path) do
        :ok -> %{phx_new: positive_elapsed(started), deps_get: 1, baseline_compile: 1}
        {:ok, timings} when is_map(timings) -> validate_base_timings!(timings)
        other -> raise "base builder returned invalid result: #{inspect(other)}"
      end

    {variants, timings} =
      Enum.reduce(@variant_names, {%{}, timings}, fn name, {variants, phase_timings} ->
        variant_path = Path.join([root, "variants", Atom.to_string(name)])
        {copy_mode, copy_ms} = copy_tree!(base_path, variant_path)
        baseline_paths = snapshot_paths(variant_path)
        started = monotonic_ms()

        stdout =
          case variant_builder.(name, variant_path) do
            :ok -> ""
            {:ok, output} when is_binary(output) -> output
            other -> raise "variant builder returned invalid result: #{inspect(other)}"
          end

        installer_ms = positive_elapsed(started)
        token = System.unique_integer([:positive, :monotonic])
        make_tree_read_only!(variant_path)

        variant = %{
          name: name,
          path: Path.expand(variant_path),
          stdout: normalize_stdout(stdout, variant_path),
          baseline_paths: baseline_paths,
          fingerprint: fingerprint,
          copy_mode: copy_mode,
          partition: "variant-#{token}",
          port: 40_000 + rem(token, 20_000),
          immutable: true
        }

        phase_timings =
          phase_timings
          |> Map.update(:checkout_copy, copy_ms, &(&1 + copy_ms))
          |> Map.update(:installer, installer_ms, &(&1 + installer_ms))

        {Map.put(variants, name, variant), phase_timings}
      end)

    timings = Map.put_new(timings, :receiver_compile_runtime, 1)

    graph = %{
      root: root,
      base_path: Path.expand(base_path),
      variants: variants,
      manifest_path: manifest_path,
      fingerprint: fingerprint,
      timings: timings,
      prepared_at_ms: monotonic_ms(),
      failed_paths: []
    }

    reset_scenario_table!()
    write_manifest!(graph)
    :persistent_term.put(@prepared_key, graph)
    Process.delete({__MODULE__, :building_root})
    graph
  rescue
    exception ->
      failed_root = Process.delete({__MODULE__, :building_root})
      if is_binary(failed_root) and File.dir?(failed_root), do: safe_remove_graph!(failed_root)
      reraise exception, __STACKTRACE__
  end

  @doc "Returns the suite-owned prepared graph or fails closed."
  def prepared_graph! do
    case :persistent_term.get(@prepared_key, nil) do
      nil -> raise "prepared install fixture graph is unavailable"
      graph -> graph
    end
  end

  @doc "Returns one immutable named variant from the suite-owned graph."
  def variant!(name), do: variant!(prepared_graph!(), name)

  def variant!(%{variants: variants}, name) when name in @variant_names,
    do: Map.fetch!(variants, name)

  def variant!(_graph, name),
    do: raise(ArgumentError, "unknown install fixture variant: #{inspect(name)}")

  @doc "Creates a private writable copy for a mutating receiver scenario."
  def checkout!(name, scenario) when name in @variant_names,
    do: checkout!(prepared_graph!(), name, scenario)

  def checkout!(graph, name, scenario) when name in @variant_names and is_binary(scenario) do
    variant = variant!(graph, name)
    token = System.unique_integer([:positive, :monotonic])
    safe_scenario = String.replace(scenario, ~r/[^a-zA-Z0-9_-]/, "-")
    checkout_path = Path.join([graph.root, "checkouts", "#{safe_scenario}-#{token}"])
    {copy_mode, copy_ms} = copy_tree!(variant.path, checkout_path)
    make_tree_writable!(checkout_path)
    build_path = Path.join(checkout_path, "_build/dev")

    unless File.dir?(build_path) do
      raise "prepared fixture checkout is missing its private compatible build: #{build_path}"
    end

    checkout = %{
      name: name,
      scenario: scenario,
      path: Path.expand(checkout_path),
      build_path: Path.expand(build_path),
      partition: "prepared-#{token}",
      port: 40_000 + rem(token, 20_000),
      fingerprint: graph.fingerprint,
      copy_mode: copy_mode,
      immutable: false
    }

    write_checkout_manifest!(checkout)
    :ets.insert(@scenario_table, {checkout.path, checkout})
    record_checkout_copy!(graph.root, copy_ms)
    checkout
  end

  @doc "Runs independent fixture scenarios with an invariant two-worker ceiling."
  def run_scenarios(scenarios, runner) when is_list(scenarios) and is_function(runner, 1) do
    ref = make_ref()
    run_scenario_queue(ref, scenarios, %{}, [], runner)
  end

  @doc "Builds the diagnostic-only receipt consumed by the fixed shell runner."
  def diagnostic_receipt(graph, raw_install_duration_ms \\ nil) do
    checkouts = scenario_checkouts()
    identities = Map.values(graph.variants) ++ checkouts
    partitions = Enum.map(identities, & &1.partition)
    ports = Enum.map(identities, & &1.port)

    receipt = %{
      schema_version: "sigra.install-fixture-diagnostics/v1",
      phases: Map.take(graph.timings, @diagnostic_phases),
      copy_mode: aggregate_copy_mode(graph, checkouts),
      variant_count: map_size(graph.variants),
      worker_count: 2,
      partitions: partitions,
      ports: ports,
      failed_paths: failed_paths()
    }

    if is_nil(raw_install_duration_ms),
      do: receipt,
      else: Map.put(receipt, :raw_install_duration_ms, raw_install_duration_ms)
  end

  @doc "Rejects incomplete, forged, non-positive, or out-of-bound diagnostics."
  def validate_diagnostics!(receipt) when is_map(receipt) do
    expected_keys =
      ~w(schema_version phases copy_mode variant_count worker_count partitions ports failed_paths raw_install_duration_ms)a

    phase_keys = receipt |> Map.fetch!(:phases) |> Map.keys()
    raw_duration = Map.fetch!(receipt, :raw_install_duration_ms)
    durations = Map.values(receipt.phases)

    valid? =
      Enum.sort(Map.keys(receipt)) == Enum.sort(expected_keys) and
        receipt.schema_version == "sigra.install-fixture-diagnostics/v1" and
        Enum.sort(phase_keys) == Enum.sort(@diagnostic_phases) and
        Enum.all?(durations, &(is_integer(&1) and &1 > 0)) and
        is_integer(raw_duration) and raw_duration > 0 and Enum.sum(durations) <= raw_duration and
        receipt.variant_count == 6 and receipt.worker_count == 2 and
        unique?(receipt.partitions) and unique?(receipt.ports) and
        receipt.copy_mode in [:reflink, :copy] and is_list(receipt.failed_paths)

    if valid?, do: :ok, else: raise(ArgumentError, "invalid install fixture diagnostics")
  rescue
    KeyError -> raise ArgumentError, "invalid install fixture diagnostics"
  end

  @doc "Finalizes receiver time and atomically publishes non-authoritative diagnostics."
  def finalize_diagnostics!(graph) do
    graph =
      case :persistent_term.get(@prepared_key, nil) do
        %{root: root} = current when root == graph.root -> current
        _ -> graph
      end

    receiver_ms = positive_elapsed(graph.prepared_at_ms)
    graph = put_in(graph, [:timings, :receiver_compile_runtime], receiver_ms)
    write_diagnostic!(graph)
    graph
  end

  @doc "Builds an exact runtime/lock/compiler compatibility digest."
  def compatibility_fingerprint(opts \\ []) do
    lock =
      Keyword.get_lazy(opts, :lock, fn ->
        lock_path = Path.join(sigra_repo_root(), "mix.lock")
        if File.regular?(lock_path), do: File.read!(lock_path), else: ""
      end)

    compiler =
      Keyword.get_lazy(opts, :compiler, fn ->
        if Code.ensure_loaded?(Mix.Project),
          do: inspect(Mix.Project.config()[:compilers]),
          else: ""
      end)

    :crypto.hash(
      :sha256,
      Enum.join([System.version(), System.otp_release(), lock, compiler], "\0")
    )
    |> Base.encode16(case: :lower)
  end

  @doc "Copies compatible cached bytes into a private writable tree."
  def seed_compatible_tree!(source, target, expected_fingerprint, actual_fingerprint) do
    if expected_fingerprint == actual_fingerprint do
      {mode, elapsed_ms} = copy_tree!(source, target)
      make_tree_writable!(target)

      if tree_contains_symlink_or_hardlink?(target) do
        File.rm_rf!(target)
        raise "compatible cache copy contains a symlink or hardlink"
      end

      {:ok, mode, elapsed_ms}
    else
      :incompatible
    end
  end

  @doc "Detects filesystem identity sharing or unsafe links across mutable trees."
  def tree_has_shared_writable_state?(left, right) do
    tree_contains_symlink_or_hardlink?(left) or tree_contains_symlink_or_hardlink?(right) or
      not MapSet.disjoint?(inode_index(left), inode_index(right))
  end

  @doc "Deletes only a validated graph root and clears the suite registry."
  def cleanup_graph!(%{root: root}), do: cleanup_graph!(root)

  def cleanup_graph!(root) when is_binary(root) do
    root = validate_graph_root!(root)
    safe_remove_graph!(root)

    case :persistent_term.get(@prepared_key, nil) do
      %{root: ^root} -> :persistent_term.erase(@prepared_key)
      _ -> :ok
    end

    if :ets.whereis(@scenario_table) != :undefined, do: :ets.delete(@scenario_table)

    :ok
  end

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
        env: [{"MIX_ENV", "dev"}]
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
        env: [{"MIX_ENV", "dev"}]
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
        env: [{"MIX_ENV", "dev"}]
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
        stderr_to_stdout: true
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
  @spec run_sigra_install(Path.t(), [String.t()], keyword()) :: {:ok, String.t()}
  def run_sigra_install(app_dir, flags, opts \\ []) when is_list(flags) do
    args = ["sigra.install", "Accounts", "User", "users"] ++ flags ++ ["--yes"]
    {out, status} = command(opts).("mix", args, command_options(app_dir))

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
  @spec run_sigra_upgrade(Path.t(), [String.t()], keyword()) :: {:ok, String.t()}
  def run_sigra_upgrade(app_dir, flags, opts \\ []) when is_list(flags) do
    # `mix phx.new` runs `git init` without an initial commit, so the tmp app
    # is always "dirty" from sigra.upgrade's perspective. The fixture owns the
    # directory end-to-end, so --allow-dirty is always correct here.
    args = ["sigra.upgrade"] ++ flags ++ ["--allow-dirty", "--yes"]

    {out, status} = command(opts).("mix", args, command_options(app_dir))

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
  @spec run_mix(Path.t(), [String.t()], keyword()) :: {:ok, String.t()}
  def run_mix(app_dir, args, opts \\ []) when is_list(args) do
    {out, status} = command(opts).("mix", args, command_options(app_dir))

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
    tracked_dirs = ["lib", "priv/repo/migrations", "priv/static", "config", "test/support"]

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
      "priv/static",
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

  defp new_graph_root! do
    template = Path.join(System.tmp_dir!(), "sigra_install_golden.XXXXXX")

    case System.cmd("mktemp", ["-d", template], stderr_to_stdout: true) do
      {path, 0} -> String.trim(path) |> validate_graph_root!()
      {output, status} -> raise "mktemp failed (status #{status}): #{output}"
    end
  end

  defp validate_graph_root!(root) do
    expanded = Path.expand(root)
    parent = expanded |> Path.dirname() |> canonical_directory!()
    temp_parent = System.tmp_dir!() |> canonical_directory!()
    basename = Path.basename(expanded)

    if parent != temp_parent or not String.starts_with?(basename, "sigra_install_golden.") do
      raise ArgumentError, "unsafe install fixture graph root: #{expanded}"
    end

    expanded
  end

  defp canonical_directory!(path) do
    case System.cmd("pwd", [], cd: path, stderr_to_stdout: true) do
      {resolved, 0} ->
        String.trim(resolved)

      {output, status} ->
        raise "could not resolve directory #{path} (status #{status}): #{output}"
    end
  end

  defp safe_remove_graph!(root) do
    _ = File.chmod(root, 0o700)
    make_tree_writable!(root)
    File.rm_rf!(root)
    :ok
  end

  defp build_source_base!(base_path) do
    parent = Path.dirname(base_path)
    phx_started = monotonic_ms()

    {phx_out, phx_status} =
      System.cmd("mix", ["phx.new", @app_name, "--no-assets", "--no-install"],
        cd: parent,
        stderr_to_stdout: true
      )

    if phx_status != 0, do: raise("mix phx.new failed (status #{phx_status}):\n#{phx_out}")
    phx_ms = positive_elapsed(phx_started)
    patch_mix_exs_with_path_dep!(base_path)
    deps_started = monotonic_ms()
    mix_deps_get_noninteractive!(base_path)
    deps_ms = positive_elapsed(deps_started)
    compile_started = monotonic_ms()

    {compile_out, compile_status} =
      System.cmd("mix", ["compile"],
        cd: base_path,
        stderr_to_stdout: true,
        env: [{"MIX_ENV", "dev"}]
      )

    if compile_status != 0, do: raise("pre-install mix compile failed:\n#{compile_out}")

    {:ok,
     %{
       phx_new: phx_ms,
       deps_get: deps_ms,
       baseline_compile: positive_elapsed(compile_started)
     }}
  end

  defp build_variant!(name, variant_path) do
    prepare_variant_assets!(name, variant_path)
    run_sigra_install(variant_path, Map.fetch!(@variant_flags, name))
  end

  defp prepare_variant_assets!(:passkeys_standard, path) do
    write_asset_file(path, "js/app.js", @standard_app_js)
  end

  defp prepare_variant_assets!(:passkeys_nonstandard_app_js, path) do
    write_asset_file(path, "js/app.js", @nonstandard_app_js)
  end

  defp prepare_variant_assets!(_name, _path), do: :ok

  defp command(opts), do: Keyword.get(opts, :command, &System.cmd/3)

  defp command_options(app_dir) do
    checkout = read_checkout_manifest(app_dir)

    env =
      [{"MIX_ENV", "dev"}]
      |> maybe_put_env("MIX_TEST_PARTITION", checkout["partition"])
      |> maybe_put_env("MIX_BUILD_PATH", checkout["build_path"])

    [cd: app_dir, stderr_to_stdout: true, env: env]
  end

  defp maybe_put_env(env, _key, nil), do: env
  defp maybe_put_env(env, key, value), do: [{key, value} | env]

  defp read_checkout_manifest(app_dir) do
    path = Path.join(app_dir, @manifest_name)

    case File.lstat(path) do
      {:ok, %{type: :regular}} -> path |> File.read!() |> Jason.decode!()
      _ -> %{}
    end
  end

  defp write_checkout_manifest!(checkout) do
    path = Path.join(checkout.path, @manifest_name)

    File.write!(
      path,
      Jason.encode!(%{
        "schema_version" => "sigra.install-checkout/v1",
        "name" => Atom.to_string(checkout.name),
        "partition" => checkout.partition,
        "port" => checkout.port,
        "build_path" => checkout.build_path,
        "fingerprint" => checkout.fingerprint,
        "copy_mode" => Atom.to_string(checkout.copy_mode)
      }) <> "\n",
      [:exclusive]
    )
  end

  defp write_manifest!(graph) do
    variants =
      Map.new(graph.variants, fn {name, variant} ->
        {Atom.to_string(name),
         %{
           "path" => variant.path,
           "stdout" => variant.stdout,
           "baseline_paths" =>
             Map.new(variant.baseline_paths, fn {path, digest} ->
               {path, Base.encode16(digest, case: :lower)}
             end),
           "fingerprint" => variant.fingerprint,
           "copy_mode" => Atom.to_string(variant.copy_mode),
           "partition" => variant.partition,
           "port" => variant.port,
           "immutable" => true
         }}
      end)

    receipt = %{
      "schema_version" => "sigra.install-fixture/v1",
      "root" => graph.root,
      "base_path" => graph.base_path,
      "fingerprint" => graph.fingerprint,
      "variants" => variants,
      "timings" => Map.new(graph.timings, fn {key, value} -> {Atom.to_string(key), value} end),
      "failed_paths" => []
    }

    write_json_atomic!(graph.manifest_path, receipt)
    write_diagnostic!(graph)
  end

  defp write_diagnostic!(graph) do
    write_json_atomic!(@diagnostic_path, diagnostic_receipt(graph))
  end

  defp write_json_atomic!(path, value) do
    File.mkdir_p!(Path.dirname(path))
    temp = "#{path}.tmp.#{System.unique_integer([:positive])}"
    File.write!(temp, Jason.encode!(value) <> "\n", [:exclusive])
    File.chmod!(temp, 0o600)
    File.rename!(temp, path)
  end

  defp validate_base_timings!(timings) do
    expected = [:baseline_compile, :deps_get, :phx_new]

    if Enum.sort(Map.keys(timings)) == expected and
         Enum.all?(timings, fn {_phase, duration} -> is_integer(duration) and duration > 0 end) do
      timings
    else
      raise "base builder timings must contain exact positive phx_new/deps_get/baseline_compile values"
    end
  end

  defp monotonic_ms, do: System.monotonic_time(:millisecond)
  defp positive_elapsed(started), do: max(monotonic_ms() - started, 1)

  defp copy_tree!(source, target) do
    source = Path.expand(source)
    target = validate_graph_member!(target)
    File.mkdir_p!(Path.dirname(target))
    started = monotonic_ms()

    {mode, output, status} =
      case :os.type() do
        {:unix, :linux} ->
          {out, rc} =
            System.cmd("cp", ["--reflink=auto", "-R", source, target], stderr_to_stdout: true)

          {:reflink, out, rc}

        {:unix, :darwin} ->
          {out, rc} = System.cmd("cp", ["-cR", source, target], stderr_to_stdout: true)
          {:reflink, out, rc}

        _ ->
          {out, rc} = System.cmd("cp", ["-R", source, target], stderr_to_stdout: true)
          {:copy, out, rc}
      end

    {mode, output, status} =
      if status == 0 do
        {mode, output, status}
      else
        File.rm_rf!(target)
        {out, rc} = System.cmd("cp", ["-R", source, target], stderr_to_stdout: true)
        {:copy, out, rc}
      end

    if status != 0, do: raise("private fixture copy failed (status #{status}): #{output}")
    make_directories_writable_no_follow!(target)
    materialize_or_omit_links!(source, target)

    if tree_contains_symlink_or_hardlink?(target) do
      raise "private fixture copy retained a symlink or hardlink"
    end

    {mode, positive_elapsed(started)}
  end

  defp make_directories_writable_no_follow!(root) do
    File.chmod!(root, 0o700)

    root
    |> File.ls!()
    |> Enum.each(fn entry ->
      path = Path.join(root, entry)

      case File.lstat(path) do
        {:ok, %{type: :directory}} -> make_directories_writable_no_follow!(path)
        _ -> :ok
      end
    end)
  end

  defp materialize_or_omit_links!(source_root, target_root) do
    source_root
    |> symlink_paths()
    |> Enum.each(fn source_link ->
      relative = Path.relative_to(source_link, source_root)
      target_link = Path.join(target_root, relative)
      File.rm_rf!(target_link)

      case resolve_safe_link(source_root, source_link, MapSet.new()) do
        {:ok, resolved} ->
          copy_materialized_path!(source_root, resolved, target_link, MapSet.new())

        :omit ->
          :ok
      end
    end)
  end

  defp symlink_paths(root) do
    case File.ls(root) do
      {:ok, entries} ->
        Enum.flat_map(entries, fn entry ->
          path = Path.join(root, entry)

          case File.lstat(path) do
            {:ok, %{type: :symlink}} -> [path]
            {:ok, %{type: :directory}} -> symlink_paths(path)
            _ -> []
          end
        end)

      {:error, _reason} ->
        []
    end
  end

  defp resolve_safe_link(source_root, link, seen) do
    if MapSet.member?(seen, link) do
      :omit
    else
      seen = MapSet.put(seen, link)

      with {:ok, link_target} <- File.read_link(link),
           candidate <-
             if(Path.type(link_target) == :absolute,
               do: Path.expand(link_target),
               else: Path.expand(link_target, Path.dirname(link))
             ),
           true <- allowed_materialization_target?(source_root, candidate),
           {:ok, stat} <- File.lstat(candidate) do
        if stat.type == :symlink,
          do: resolve_safe_link(source_root, candidate, seen),
          else: {:ok, candidate}
      else
        _ -> :omit
      end
    end
  end

  defp allowed_materialization_target?(source_root, candidate) do
    repository_priv = Path.join(sigra_repo_root(), "priv") |> Path.expand()

    candidate == source_root or String.starts_with?(candidate, source_root <> "/") or
      candidate == repository_priv or String.starts_with?(candidate, repository_priv <> "/")
  end

  defp copy_materialized_path!(source_root, source, target, seen) do
    case File.lstat!(source) do
      %{type: :regular} ->
        File.cp!(source, target)

      %{type: :directory} ->
        File.mkdir_p!(target)

        source
        |> File.ls!()
        |> Enum.each(fn entry ->
          copy_materialized_path!(
            source_root,
            Path.join(source, entry),
            Path.join(target, entry),
            seen
          )
        end)

      %{type: :symlink} ->
        case resolve_safe_link(source_root, source, seen) do
          {:ok, resolved} -> copy_materialized_path!(source_root, resolved, target, seen)
          :omit -> :ok
        end

      _other ->
        :ok
    end
  end

  defp validate_graph_member!(path) do
    expanded = Path.expand(path)

    graph_root =
      expanded
      |> Path.dirname()
      |> Stream.unfold(fn
        "/" -> nil
        current -> {current, Path.dirname(current)}
      end)
      |> Enum.find(fn candidate ->
        String.starts_with?(Path.basename(candidate), "sigra_install_golden.") and
          canonical_directory!(Path.dirname(candidate)) == canonical_directory!(System.tmp_dir!())
      end)

    if is_nil(graph_root) or expanded == graph_root or
         not String.starts_with?(expanded, graph_root <> "/") do
      raise ArgumentError, "unsafe install fixture target: #{expanded}"
    end

    expanded
  end

  defp make_tree_read_only!(root) do
    walk_tree(root, fn path, type ->
      File.chmod!(path, if(type == :directory, do: 0o555, else: 0o444))
    end)
  end

  defp make_tree_writable!(root) do
    if File.exists?(root) do
      walk_tree(root, fn path, type ->
        File.chmod!(path, if(type == :directory, do: 0o700, else: 0o600))
      end)
    end
  end

  defp walk_tree(root, fun) do
    [root | Path.wildcard(Path.join(root, "**/*"), match_dot: true)]
    |> Enum.sort_by(&String.length/1, :desc)
    |> Enum.each(fn path ->
      case File.lstat(path) do
        {:ok, %{type: type}} when type in [:directory, :regular] -> fun.(path, type)
        {:ok, _} -> :ok
        {:error, :enoent} -> :ok
        {:error, reason} -> raise File.Error, reason: reason, action: "stat", path: path
      end
    end)
  end

  defp tree_contains_symlink_or_hardlink?(root) do
    [root | Path.wildcard(Path.join(root, "**/*"), match_dot: true)]
    |> Enum.any?(fn path ->
      case File.lstat(path) do
        {:ok, %{type: :symlink}} -> true
        {:ok, %{type: :regular, links: links}} -> links > 1
        _ -> false
      end
    end)
  end

  defp inode_index(root) do
    [root | Path.wildcard(Path.join(root, "**/*"), match_dot: true)]
    |> Enum.reduce(MapSet.new(), fn path, acc ->
      case File.stat(path) do
        {:ok, %{type: :regular, inode: inode, major_device: device}} ->
          MapSet.put(acc, {device, inode})

        _ ->
          acc
      end
    end)
  end

  defp reset_scenario_table! do
    if :ets.whereis(@scenario_table) != :undefined, do: :ets.delete(@scenario_table)
    :ets.new(@scenario_table, [:named_table, :public, :set, read_concurrency: true])
  end

  defp scenario_checkouts do
    case :ets.whereis(@scenario_table) do
      :undefined ->
        []

      _table ->
        @scenario_table |> :ets.tab2list() |> Enum.map(&elem(&1, 1)) |> Enum.sort_by(& &1.path)
    end
  end

  defp record_checkout_copy!(root, copy_ms) do
    :global.trans({__MODULE__, :graph_update}, fn ->
      case :persistent_term.get(@prepared_key, nil) do
        %{root: ^root} = graph ->
          updated = update_in(graph, [:timings, :checkout_copy], &(&1 + copy_ms))
          :persistent_term.put(@prepared_key, updated)

        _ ->
          :ok
      end
    end)
  end

  defp failed_paths do
    scenario_checkouts()
    |> Enum.filter(&Map.get(&1, :failed, false))
    |> Enum.map(& &1.path)
  end

  defp aggregate_copy_mode(graph, checkouts) do
    modes =
      Enum.map(graph.variants, fn {_name, variant} -> variant.copy_mode end) ++
        Enum.map(checkouts, & &1.copy_mode)

    if Enum.all?(modes, &(&1 == :reflink)), do: :reflink, else: :copy
  end

  defp unique?(values), do: length(values) == MapSet.size(MapSet.new(values))

  defp run_scenario_queue(ref, queued, active, results, runner) do
    {queued, active} = fill_scenario_workers(ref, queued, active, runner)

    if map_size(active) == 0 do
      {:ok, Enum.reverse(results)}
    else
      receive do
        {^ref, pid, scenario, {:ok, result}} ->
          run_scenario_queue(
            ref,
            queued,
            Map.delete(active, pid),
            [{scenario, result} | results],
            runner
          )

        {^ref, pid, scenario, {:error, status}} ->
          active |> Map.delete(pid) |> Map.keys() |> Enum.each(&Process.exit(&1, :kill))
          mark_scenario_failed!(scenario)
          {:error, %{status: status, failed_path: Map.get(scenario, :path)}}
      end
    end
  end

  defp fill_scenario_workers(ref, queued, active, runner) when map_size(active) < 2 do
    case queued do
      [scenario | rest] ->
        parent = self()

        pid =
          spawn(fn ->
            result =
              try do
                case runner.(scenario) do
                  :ok -> {:ok, :ok}
                  {:ok, value} -> {:ok, value}
                  {:error, status} when is_integer(status) and status != 0 -> {:error, status}
                  other -> {:error, {:invalid_result, other}}
                end
              rescue
                _exception -> {:error, 1}
              catch
                :exit, _reason -> {:error, 1}
              end

            send(parent, {ref, self(), scenario, result})
          end)

        fill_scenario_workers(ref, rest, Map.put(active, pid, scenario), runner)

      [] ->
        {[], active}
    end
  end

  defp fill_scenario_workers(_ref, queued, active, _runner), do: {queued, active}

  defp mark_scenario_failed!(%{path: path}) when is_binary(path) do
    case :ets.whereis(@scenario_table) do
      :undefined ->
        :ok

      _table ->
        case :ets.lookup(@scenario_table, path) do
          [{^path, checkout}] ->
            :ets.insert(@scenario_table, {path, Map.put(checkout, :failed, true)})

          [] ->
            :ok
        end
    end
  end

  defp mark_scenario_failed!(_scenario), do: :ok

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

  defp sigra_repo_root do
    # This module lives at test/support/install_fixture.ex, so two levels up
    # from __ENV__.file is the sigra repo root.
    __ENV__.file
    |> Path.dirname()
    |> Path.join("../..")
    |> Path.expand()
  end
end
