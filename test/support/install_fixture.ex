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
  @port_table :sigra_install_fixture_ports
  @worker_pool Sigra.Test.InstallFixture.WorkerPool
  @scenario_timeout_ms 120_000
  @linux_graph_parent "/dev/shm"
  @minimum_tmpfs_bytes 1_610_612_736
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

  defmodule WorkerPool do
    @moduledoc false
    use GenServer

    def start_link(name), do: GenServer.start_link(__MODULE__, :ok, name: name)
    def acquire(name), do: GenServer.call(name, :acquire, :infinity)
    def release(name), do: GenServer.cast(name, {:release, self()})

    @impl true
    def init(:ok), do: {:ok, %{active: %{}, queued: :queue.new()}}

    @impl true
    def handle_call(:acquire, {pid, _tag} = from, state) do
      if map_size(state.active) < 2 do
        ref = Process.monitor(pid)
        {:reply, :ok, put_in(state, [:active, pid], ref)}
      else
        {:noreply, %{state | queued: :queue.in(from, state.queued)}}
      end
    end

    @impl true
    def handle_cast({:release, pid}, state), do: {:noreply, release_and_promote(state, pid)}

    @impl true
    def handle_info({:DOWN, ref, :process, pid, _reason}, state) do
      case Map.get(state.active, pid) do
        ^ref -> {:noreply, release_and_promote(state, pid, false)}
        _other -> {:noreply, state}
      end
    end

    defp release_and_promote(state, pid, demonitor? \\ true) do
      case Map.pop(state.active, pid) do
        {nil, _active} ->
          state

        {ref, active} ->
          if demonitor?, do: Process.demonitor(ref, [:flush])
          promote(%{state | active: active})
      end
    end

    defp promote(state) when map_size(state.active) >= 2, do: state

    defp promote(state) do
      case :queue.out(state.queued) do
        {{:value, {pid, _tag} = from}, queued} ->
          if Process.alive?(pid) do
            ref = Process.monitor(pid)
            GenServer.reply(from, :ok)
            promote(%{state | active: Map.put(state.active, pid, ref), queued: queued})
          else
            promote(%{state | queued: queued})
          end

        {:empty, _queued} ->
          state
      end
    end
  end

  @doc "Runs generated-app work under the graph-global two-worker ceiling."
  def with_worker(fun) when is_function(fun, 0) do
    if Process.get({__MODULE__, :worker_lease}, false) do
      fun.()
    else
      ensure_worker_pool!()
      :ok = WorkerPool.acquire(@worker_pool)
      Process.put({__MODULE__, :worker_lease}, true)

      try do
        fun.()
      after
        Process.delete({__MODULE__, :worker_lease})
        WorkerPool.release(@worker_pool)
      end
    end
  end

  @doc "Builds and publishes one immutable prepared-fixture graph."
  def prepare_graph!(opts \\ []) do
    root = Keyword.get_lazy(opts, :root, &new_graph_root!/0) |> validate_graph_root!()
    Process.put({__MODULE__, :building_root}, root)
    Process.delete({__MODULE__, :trusted_seed})
    fingerprint = Keyword.get_lazy(opts, :fingerprint, &compatibility_fingerprint/0)
    base_path = Path.join([root, "source", @app_name])
    deps_path = Path.join(root, "shared_deps")
    manifest_path = Path.join(root, @manifest_name)
    base_builder = Keyword.get(opts, :base_builder, fn path -> build_source_base!(path, opts) end)
    variant_builder = Keyword.get(opts, :variant_builder, &build_variant!/2)

    variant_compiler =
      Keyword.get_lazy(opts, :variant_compiler, fn ->
        if Keyword.has_key?(opts, :variant_builder),
          do: fn _path -> :ok end,
          else: &compile_variant!/1
      end)

    reset_port_table!()
    ensure_worker_pool!()
    File.mkdir_p!(Path.dirname(base_path))
    started = monotonic_ms()

    timings =
      case base_builder.(base_path) do
        :ok ->
          %{
            phx_new: positive_elapsed(started),
            deps_get: 1,
            baseline_compile: 1,
            checkout_copy: 1
          }

        {:ok, timings} when is_map(timings) ->
          validate_base_timings!(timings)

        other ->
          raise "base builder returned invalid result: #{inspect(other)}"
      end

    trusted_seed? = Process.delete({__MODULE__, :trusted_seed}) == true

    if File.regular?(Path.join(base_path, "config/dev.exs")) do
      configure_runtime_isolation!(base_path)
    end

    build_template_path = seal_build_template!(root, base_path)

    copy_started = monotonic_ms()

    copied_variants =
      parallel_map!(@variant_names, fn name ->
        variant_path = Path.join([root, "variants", Atom.to_string(name)])
        {copy_mode, _copy_ms} = copy_tree!(base_path, variant_path)
        baseline_paths = snapshot_paths(variant_path)

        %{
          name: name,
          path: variant_path,
          deps_path: deps_path,
          copy_mode: copy_mode,
          baseline_paths: baseline_paths
        }
      end)

    copy_ms = positive_elapsed(copy_started)
    installer_started = monotonic_ms()

    installed_variants =
      copied_variants
      |> parallel_map!(fn copied ->
        name = copied.name
        variant_path = copied.path
        installer_build_path = prepare_installer_build!(root, build_template_path, name)
        Process.put({__MODULE__, :installer_build_path}, installer_build_path)

        stdout =
          try do
            run_variant_builder!(variant_builder, name, variant_path, trusted_seed?, opts)
          after
            Process.delete({__MODULE__, :installer_build_path})
          end

        %{
          copied: copied,
          stdout: normalize_stdout(stdout, variant_path),
          installer_build_path: installer_build_path,
          compile_digest: compile_relevant_digest(variant_path)
        }
      end)

    reuse_compiles? = trusted_seed? and not Keyword.has_key?(opts, :variant_compiler)
    compile_installed_variants!(installed_variants, variant_compiler, reuse_compiles?)

    variants =
      installed_variants
      |> Enum.map(fn installed ->
        copied = installed.copied
        name = copied.name
        variant_path = copied.path
        variant_build_template_path = seal_variant_build_template!(installed.installer_build_path)
        token = System.unique_integer([:positive, :monotonic])
        make_tree_read_only!(variant_path)

        %{
          name: name,
          path: Path.expand(variant_path),
          stdout: installed.stdout,
          baseline_paths: copied.baseline_paths,
          deps_path: copied.deps_path,
          build_template_path: variant_build_template_path,
          fingerprint: fingerprint,
          copy_mode: copied.copy_mode,
          partition: "variant-#{token}",
          port: allocate_port!(root, token),
          immutable: true
        }
      end)
      |> Map.new(&{&1.name, &1})

    timings =
      timings
      |> Map.update(:checkout_copy, copy_ms, &(&1 + copy_ms))
      |> Map.put(:installer, positive_elapsed(installer_started))

    timings = Map.put_new(timings, :receiver_compile_runtime, 1)

    graph = %{
      root: root,
      base_path: Path.expand(base_path),
      deps_path: Path.expand(deps_path),
      build_template_path: build_template_path,
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
      Process.delete({__MODULE__, :trusted_seed})
      failed_root = Process.delete({__MODULE__, :building_root})
      if is_binary(failed_root) and File.dir?(failed_root), do: safe_remove_graph!(failed_root)
      reraise exception, __STACKTRACE__
  end

  defp run_variant_builder!(variant_builder, name, variant_path, trusted_seed?, opts) do
    result =
      if trusted_seed? and not Keyword.has_key?(opts, :variant_builder) do
        build_variant_without_host_compile!(name, variant_path)
      else
        variant_builder.(name, variant_path)
      end

    case result do
      :ok -> ""
      {:ok, output} when is_binary(output) -> output
      other -> raise "variant builder returned invalid result: #{inspect(other)}"
    end
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
    with_worker(fn -> do_checkout!(graph, name, scenario) end)
  end

  defp do_checkout!(graph, name, scenario) do
    variant = variant!(graph, name)
    token = System.unique_integer([:positive, :monotonic])
    partition = checkout_partition(graph.root, token)
    port = allocate_port!(graph.root, token)
    safe_scenario = String.replace(scenario, ~r/[^a-zA-Z0-9_-]/, "-")
    checkout_path = Path.join([graph.root, "checkouts", "#{safe_scenario}-#{token}"])
    {source_copy_mode, source_copy_ms} = copy_tree!(variant.path, checkout_path)
    build_path = Path.join(checkout_path, "_build/dev")

    {build_copy_mode, build_copy_ms} =
      copy_build_template!(variant.build_template_path || graph.build_template_path, build_path)

    make_tree_writable!(checkout_path)
    manifest_mode = relocate_compile_manifest!(build_path, variant.path, checkout_path)

    unless File.dir?(build_path) do
      raise "prepared fixture checkout is missing its private compatible build: #{build_path}"
    end

    checkout = %{
      name: name,
      scenario: scenario,
      path: Path.expand(checkout_path),
      build_path: Path.expand(build_path),
      deps_path: variant.deps_path,
      partition: partition,
      port: port,
      fingerprint: graph.fingerprint,
      copy_mode: aggregate_modes([source_copy_mode, build_copy_mode]),
      manifest_mode: manifest_mode,
      immutable: false
    }

    write_checkout_manifest!(checkout)
    :ets.insert(@scenario_table, {checkout.path, checkout})
    record_checkout_copy!(graph.root, source_copy_ms + build_copy_ms)
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
    if :ets.whereis(@port_table) != :undefined, do: :ets.delete(@port_table)

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

  defp mix_deps_get_noninteractive!(app_dir, env \\ []) do
    {out, status} =
      System.cmd(
        "sh",
        ["-c", "echo n | mix deps.get"],
        cd: app_dir,
        stderr_to_stdout: true,
        env: env
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
    {out, status} = with_worker(fn -> command(opts).("mix", args, command_options(app_dir)) end)

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

    {out, status} = with_worker(fn -> command(opts).("mix", args, command_options(app_dir)) end)

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
    {out, status} = with_worker(fn -> command(opts).("mix", args, command_options(app_dir)) end)

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
        |> String.replace(
          ~S|database: "sigra_install_golden_tmp_dev_" <> System.get_env("MIX_TEST_PARTITION", "base")|,
          ~S|database: "sigra_install_golden_tmp_dev"|
        )
        |> String.replace(
          ~S|, port: String.to_integer(System.get_env("PORT", "4000"))|,
          ""
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
    template = Path.join(graph_parent_for_test(), "sigra_install_golden.XXXXXX")

    case System.cmd("mktemp", ["-d", template], stderr_to_stdout: true) do
      {path, 0} ->
        root = String.trim(path) |> validate_graph_root!()
        File.chmod!(root, 0o700)

        if Bitwise.band(File.stat!(root).mode, 0o777) != 0o700 do
          raise "install fixture graph root is not private: #{root}"
        end

        root

      {output, status} ->
        raise "mktemp failed (status #{status}): #{output}"
    end
  end

  @doc false
  def graph_parent_for_test(opts \\ []) do
    os_type = Keyword.get(opts, :os_type, :os.type())
    tmpfs_parent = Keyword.get(opts, :tmpfs_parent, @linux_graph_parent)
    probe = Keyword.get(opts, :probe, &probe_tmpfs_parent/1)

    case os_type do
      {:unix, :linux} ->
        case probe.(tmpfs_parent) do
          %{canonical?: true, tmpfs?: true, writable?: true, free_bytes: bytes}
          when is_integer(bytes) and bytes >= @minimum_tmpfs_bytes ->
            canonical_directory!(tmpfs_parent)

          _ ->
            canonical_directory!(System.tmp_dir!())
        end

      _ ->
        canonical_directory!(System.tmp_dir!())
    end
  end

  defp probe_tmpfs_parent(parent) do
    canonical? =
      File.dir?(parent) and
        canonical_directory!(parent) == canonical_directory!(@linux_graph_parent)

    {filesystem, fs_status} =
      System.cmd("stat", ["-f", "-c", "%T", parent], stderr_to_stdout: true)

    {_writable, writable_status} = System.cmd("test", ["-w", parent], stderr_to_stdout: true)
    {space, space_status} = System.cmd("df", ["-Pk", parent], stderr_to_stdout: true)

    free_bytes =
      if space_status == 0 do
        space
        |> String.split("\n", trim: true)
        |> List.last()
        |> to_string()
        |> String.split(~r/\s+/, trim: true)
        |> Enum.at(3, "0")
        |> String.to_integer()
        |> Kernel.*(1024)
      else
        0
      end

    %{
      canonical?: canonical?,
      tmpfs?: fs_status == 0 and String.trim(filesystem) == "tmpfs",
      writable?: writable_status == 0,
      free_bytes: free_bytes
    }
  rescue
    _ -> %{canonical?: false, tmpfs?: false, writable?: false, free_bytes: 0}
  end

  defp validate_graph_root!(root) do
    expanded = Path.expand(root)
    parent = expanded |> Path.dirname() |> canonical_directory!()
    allowed_parents = allowed_graph_parents()
    basename = Path.basename(expanded)

    if parent not in allowed_parents or not String.starts_with?(basename, "sigra_install_golden.") do
      raise ArgumentError, "unsafe install fixture graph root: #{expanded}"
    end

    expanded
  end

  defp allowed_graph_parents do
    [System.tmp_dir!(), @linux_graph_parent]
    |> Enum.filter(&File.dir?/1)
    |> Enum.map(&canonical_directory!/1)
    |> Enum.uniq()
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
    safe_remove_graph!(root, &File.rm_rf/1, 3)
  end

  defp safe_remove_graph!(root, remover, detach_attempts_left) do
    if File.exists?(root) do
      _ = File.chmod(root, 0o700)
      make_tree_writable!(root)
      detached = "#{root}.removing-#{System.unique_integer([:positive, :monotonic])}"
      File.rename!(root, detached)
      remove_detached_graph!(detached, remover, 3)

      if File.exists?(root) do
        if detach_attempts_left > 1 do
          safe_remove_graph!(root, remover, detach_attempts_left - 1)
        else
          raise File.Error,
            reason: :eexist,
            path: root,
            action: "remove recreated install fixture graph root"
        end
      end
    end

    :ok
  end

  defp remove_detached_graph!(root, remover, attempts_left) do
    if File.exists?(root) do
      _ = File.chmod(root, 0o700)
      make_tree_writable!(root)
    end

    case remover.(root) do
      {:ok, _removed} ->
        :ok

      {:error, _reason, _path} when attempts_left > 1 ->
        remove_detached_graph!(root, remover, attempts_left - 1)

      {:error, reason, path} ->
        raise File.Error,
          reason: reason,
          path: path,
          action: "remove files and directories recursively from"
    end
  end

  @doc false
  def cleanup_graph_root_for_test!(root, remover) when is_function(remover, 1),
    do: safe_remove_graph!(root, remover, 3)

  defp build_source_base!(base_path, opts) do
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
    {shared_env, deps_copy_ms} = prepare_private_deps!(base_path, opts)
    mix_deps_get_noninteractive!(base_path, shared_env)
    deps_ms = positive_elapsed(deps_started)
    {seed_ms, trusted_sigra_seed?} = seed_root_build!(base_path, opts)

    if trusted_sigra_seed? do
      normalize_seeded_sigra_app!(Path.join(base_path, "_build/dev"))
    end

    configure_seeded_path_dep_for_test!(base_path, trusted_sigra_seed?)

    compile_started = monotonic_ms()

    compile_baseline!(trusted_sigra_seed?, fn ->
      {compile_out, compile_status} =
        System.cmd("mix", ["compile"],
          cd: base_path,
          stderr_to_stdout: true,
          env: [{"MIX_ENV", "dev"} | shared_env]
        )

      if compile_status != 0, do: raise("pre-install mix compile failed:\n#{compile_out}")
      :ok
    end)

    unless trusted_sigra_seed? do
      disable_compiled_path_dep!(base_path)
    end

    Process.put({__MODULE__, :trusted_seed}, trusted_sigra_seed?)

    {:ok,
     %{
       phx_new: phx_ms,
       deps_get: deps_ms,
       baseline_compile: positive_elapsed(compile_started),
       checkout_copy: deps_copy_ms + seed_ms
     }}
    |> tap(fn _result ->
      make_tree_read_only!(Path.join(Path.dirname(Path.dirname(base_path)), "shared_deps"))
    end)
  end

  defp seal_build_template!(root, base_path) do
    source = Path.join(base_path, "_build/dev")

    if File.dir?(source) do
      target = validate_graph_member!(Path.join(root, "build_template/dev"))
      {_mode, _elapsed_ms} = copy_tree!(source, target)
      File.rm_rf!(source)
      make_tree_read_only!(target)
      Path.expand(target)
    end
  end

  defp copy_build_template!(nil, _target), do: {:copy, 1}

  defp copy_build_template!(source, target) do
    result = copy_tree!(source, target)

    if tree_has_shared_writable_state?(source, target) do
      File.rm_rf!(target)
      raise "prepared fixture private build shares filesystem identity with its sealed template"
    end

    result
  end

  defp prepare_installer_build!(_root, nil, _name), do: nil

  defp prepare_installer_build!(root, source, name) do
    target = Path.join([root, "installer_builds", Atom.to_string(name), "dev"])
    {_mode, _elapsed_ms} = copy_build_template!(source, target)
    make_tree_writable!(target)
    target
  end

  defp compile_variant!(variant_path), do: compile_variant!(variant_path, &System.cmd/3)

  @doc false
  def compile_variant_for_test!(variant_path, command) when is_function(command, 3),
    do: compile_variant!(variant_path, command)

  defp compile_variant!(variant_path, command) do
    options = command_options(variant_path)
    {output, status} = command.("mix", ["compile"], options)

    {output, status} =
      if status != 0 do
        retry_failed_dependency_compile(variant_path, output, options, status, command)
      else
        {output, status}
      end

    if status != 0, do: raise("prepared fixture variant compile failed:\n#{output}")
    if output =~ ~r/\bwarning:/i, do: raise("prepared fixture variant compile warned:\n#{output}")
    :ok
  end

  defp retry_failed_dependency_compile(variant_path, output, options, status, command) do
    with {:ok, dependency} <- failed_dependency(output) do
      retry_deps_path = prepare_retry_deps!(variant_path, options, dependency)

      retry_options =
        Keyword.update!(options, :env, fn env ->
          env
          |> List.keydelete("DIAGNOSTIC", 0)
          |> List.keydelete("MIX_DEPS_PATH", 0)
          |> then(&[{"DIAGNOSTIC", "1"}, {"MIX_DEPS_PATH", retry_deps_path} | &1])
        end)

      {retry_output, retry_status} = command.("mix", ["compile"], retry_options)
      {output <> "\ncompile retry:\n" <> retry_output, retry_status}
    else
      _ -> {output, status}
    end
  rescue
    error ->
      {output <> "\ncompile retry setup failed for #{variant_path}: #{Exception.message(error)}",
       status}
  end

  defp failed_dependency(output) do
    case Regex.scan(~r/Could not compile dependency :([a-z][a-z0-9_]*)\b/, output) do
      [[_match, dependency]] -> {:ok, dependency}
      _other -> :error
    end
  end

  defp prepare_retry_deps!(variant_path, options, dependency) do
    graph_root =
      graph_root_for(variant_path) || raise("prepared fixture is outside its graph root")

    env = options[:env] |> Map.new()

    shared_deps =
      case Map.get(env, "MIX_DEPS_PATH") do
        path when is_binary(path) -> validate_shared_deps!(graph_root, path)
        _other -> raise "prepared fixture retry is missing canonical shared deps"
      end

    validate_retry_shared_deps!(shared_deps)

    dependency_source = Path.join(shared_deps, dependency)

    case File.lstat(dependency_source) do
      {:ok, %{type: :directory}} -> :ok
      _other -> raise "prepared fixture retry is missing dependency source: #{dependency}"
    end

    token = System.unique_integer([:positive, :monotonic])

    retry_deps =
      Path.join([graph_root, "compile_recovery", "retry-#{token}", "shared_deps"])
      |> validate_graph_member!()

    source_state = tree_state(shared_deps)
    source_contents = tree_contents(source_state)

    try do
      {_mode, _elapsed_ms} = copy_tree!(shared_deps, retry_deps)
      make_tree_writable!(retry_deps)

      if tree_state(shared_deps) != source_state do
        raise "prepared fixture retry mutated canonical shared deps"
      end

      if retry_deps |> tree_state() |> tree_contents() != source_contents do
        raise "prepared fixture retry dependency copy is incomplete"
      end

      if tree_has_shared_writable_state?(shared_deps, retry_deps) do
        raise "prepared fixture retry dependency copy shares writable filesystem identity"
      end

      case File.lstat(Path.join(retry_deps, dependency)) do
        {:ok, %{type: :directory}} -> retry_deps
        _other -> raise "prepared fixture retry dependency copy is missing #{dependency}"
      end
    rescue
      error ->
        if File.exists?(retry_deps), do: safe_remove_graph_member!(retry_deps)
        reraise error, __STACKTRACE__
    end
  end

  defp validate_retry_shared_deps!(shared_deps) do
    paths = [shared_deps | Path.wildcard(Path.join(shared_deps, "**/*"), match_dot: true)]

    if unsafe_path = first_unsafe_link(shared_deps) do
      raise "prepared fixture shared deps contain an unsafe link: #{unsafe_path}"
    end

    case Enum.find(paths, fn path -> Bitwise.band(File.lstat!(path).mode, 0o222) != 0 end) do
      nil -> shared_deps
      writable -> raise "prepared fixture shared deps contain a writable path: #{writable}"
    end
  end

  defp tree_state(root) do
    [root | Path.wildcard(Path.join(root, "**/*"), match_dot: true)]
    |> Enum.map(fn path ->
      stat = File.lstat!(path)
      relative = if path == root, do: ".", else: Path.relative_to(path, root)
      bytes = if stat.type == :regular, do: File.read!(path), else: nil
      {relative, stat.type, Bitwise.band(stat.mode, 0o777), bytes}
    end)
    |> Enum.sort()
  end

  defp tree_contents(state) do
    Enum.map(state, fn {relative, type, _mode, bytes} -> {relative, type, bytes} end)
  end

  defp compile_installed_variants!(variants, variant_compiler, false) do
    parallel_map!(variants, &run_variant_compile!(&1, variant_compiler))
    :ok
  end

  defp compile_installed_variants!(variants, variant_compiler, true) do
    variants
    |> Enum.reduce([], fn variant, groups ->
      case Enum.find_index(groups, &(hd(&1).compile_digest == variant.compile_digest)) do
        nil -> groups ++ [[variant]]
        index -> List.update_at(groups, index, &(&1 ++ [variant]))
      end
    end)
    |> Enum.reduce(nil, fn [representative | equivalents], previous ->
      if previous do
        safe_remove_graph_member!(representative.installer_build_path)

        {_mode, _elapsed_ms} =
          copy_private_build!(previous.installer_build_path, representative.installer_build_path)

        make_tree_writable!(representative.installer_build_path)

        unless relocate_incremental_compile_manifest!(
                 representative.installer_build_path,
                 previous.copied.path,
                 representative.copied.path
               ) == :relocated do
          safe_remove_graph_member!(representative.installer_build_path)

          {_mode, _elapsed_ms} =
            copy_private_build!(
              graph_build_template_path(representative.copied.path),
              representative.installer_build_path
            )

          make_tree_writable!(representative.installer_build_path)
        end
      end

      :ok = run_variant_compile!(representative, variant_compiler)

      Enum.each(equivalents, fn equivalent ->
        source = representative.installer_build_path
        target = equivalent.installer_build_path
        safe_remove_graph_member!(target)
        {_mode, _elapsed_ms} = copy_private_build!(source, target)
        make_tree_writable!(target)

        unless relocate_compile_manifest!(
                 target,
                 representative.copied.path,
                 equivalent.copied.path
               ) == :relocated do
          :ok = run_variant_compile!(equivalent, variant_compiler)
        end
      end)

      representative
    end)

    :ok
  end

  defp copy_private_build!(source, target) do
    result = copy_tree!(source, target)

    if tree_contains_symlink_or_hardlink?(target) or
         not MapSet.disjoint?(inode_index(source), inode_index(target)) do
      safe_remove_graph_member!(target)
      raise "prepared fixture reused build is linked or shares filesystem identity"
    end

    result
  end

  defp run_variant_compile!(variant, variant_compiler) do
    Process.put({__MODULE__, :installer_build_path}, variant.installer_build_path)

    try do
      variant_compiler.(variant.copied.path)
    after
      Process.delete({__MODULE__, :installer_build_path})
    end
  end

  defp compile_relevant_digest(path) do
    files =
      [Path.join(path, "mix.exs"), Path.join(path, "mix.lock")] ++
        Path.wildcard(Path.join(path, "config/**/*")) ++
        Path.wildcard(Path.join(path, "lib/**/*"))

    digest =
      files
      |> Enum.filter(&File.regular?/1)
      |> Enum.sort()
      |> Enum.map(fn file -> [Path.relative_to(file, path), <<0>>, File.read!(file), <<0>>] end)
      |> then(&:crypto.hash(:sha256, &1))
      |> Base.encode16(case: :lower)

    digest
  end

  @doc false
  def compile_relevant_digest_for_test(path), do: compile_relevant_digest(path)

  defp seal_variant_build_template!(nil), do: nil

  defp seal_variant_build_template!(path) do
    [_dir, name, "dev"] = path |> Path.split() |> Enum.take(-3)
    graph_root = path |> Path.dirname() |> Path.dirname() |> Path.dirname()
    target = Path.join([graph_root, "variant_build_templates", name, "dev"])
    {_mode, _ms} = copy_tree!(path, target)
    safe_remove_graph_member!(path)
    make_tree_read_only!(target)
    Path.expand(target)
  end

  defp disable_compiled_path_dep!(app_dir) do
    mix_exs = Path.join(app_dir, "mix.exs")
    content = File.read!(mix_exs)

    patched =
      String.replace(
        content,
        "{:sigra, path: #{inspect(sigra_repo_root())}, override: true}",
        "{:sigra, path: #{inspect(sigra_repo_root())}, override: true, compile: false}"
      )

    if patched == content do
      raise "prepared fixture Sigra path dependency is not in the expected compiled shape"
    end

    File.write!(mix_exs, patched)
  end

  defp safe_remove_graph_member!(path) do
    path = validate_graph_member!(path)
    make_tree_writable!(path)
    File.rm_rf!(path)
    :ok
  end

  defp prepare_private_deps!(base_path, opts) do
    deps_path = root_deps_path(opts)
    target = Path.join([Path.dirname(Path.dirname(base_path)), "shared_deps"])

    if File.dir?(deps_path) do
      {_mode, elapsed_ms} = copy_tree!(deps_path, target)
      {[{"MIX_DEPS_PATH", target}], elapsed_ms}
    else
      File.mkdir_p!(target)
      {[{"MIX_DEPS_PATH", target}], 1}
    end
  end

  defp seed_root_build!(base_path, opts) do
    source = Keyword.get(opts, :root_build_path, Path.join(sigra_repo_root(), "_build/test"))
    target = Path.join(base_path, "_build/dev")
    expected = compatibility_fingerprint()
    actual = Keyword.get(opts, :root_build_fingerprint, expected)

    if File.dir?(source) and expected == actual do
      started = monotonic_ms()
      File.rm_rf!(target)

      case seed_compatible_tree!(source, target, expected, actual) do
        {:ok, _mode, _elapsed_ms} ->
          prune_incompatible_seed!(target, Path.join(base_path, "mix.lock"), base_path)
          prune_incomplete_seed_apps!(target)

          materialize_dependency_priv!(
            target,
            Path.join([Path.dirname(Path.dirname(base_path)), "shared_deps"])
          )

          {positive_elapsed(started), trusted_sigra_seed?(source, target)}

        :incompatible ->
          {1, false}
      end
    else
      {1, false}
    end
  end

  defp trusted_sigra_seed?(source_build, copied_build) do
    source_manifest = Path.join([source_build, "lib", "sigra", ".mix", "compile.elixir"])
    copied_app = Path.join([copied_build, "lib", "sigra", "ebin", "sigra.app"])

    File.regular?(copied_app) and File.regular?(source_manifest) and
      current_sigra_sources_match_manifest?(source_manifest) and
      manifest_modules_present?(source_manifest, copied_build, "sigra")
  end

  defp prune_incomplete_seed_apps!(build_path) do
    build_path
    |> Path.join("lib/*")
    |> Path.wildcard()
    |> Enum.each(fn app_path ->
      app = Path.basename(app_path)
      app_file = Path.join([app_path, "ebin", "#{app}.app"])

      complete? =
        with true <- File.regular?(app_file),
             {:ok, [{:application, _name, properties}]} <-
               :file.consult(String.to_charlist(app_file)),
             modules when is_list(modules) <- Keyword.get(properties, :modules) do
          Enum.all?(modules, fn module ->
            File.regular?(Path.join([app_path, "ebin", "#{module}.beam"]))
          end)
        else
          _ -> false
        end

      unless complete?, do: safe_remove_graph_member!(app_path)
    end)
  end

  @doc false
  def prune_incomplete_seed_apps_for_test!(build_path),
    do: prune_incomplete_seed_apps!(build_path)

  defp manifest_modules_present?(manifest, build_path, app) do
    {modules, _sources} = Mix.Compilers.Elixir.read_manifest(manifest)

    Enum.all?(Map.keys(modules), fn module ->
      File.regular?(Path.join([build_path, "lib", app, "ebin", "#{module}.beam"]))
    end)
  rescue
    _ -> false
  end

  defp normalize_seeded_sigra_app!(build_path) do
    app_path = Path.join([build_path, "lib", "sigra", "ebin", "sigra.app"])
    {:ok, [{:application, :sigra, properties}]} = :file.consult(String.to_charlist(app_path))

    core_apps = MapSet.new([:kernel, :stdlib, :elixir, :logger, :crypto])

    runtime_apps =
      properties
      |> Keyword.fetch!(:applications)
      |> Enum.filter(fn app ->
        MapSet.member?(core_apps, app) or
          File.regular?(Path.join([build_path, "lib", Atom.to_string(app), "ebin", "#{app}.app"]))
      end)

    normalized = {:application, :sigra, Keyword.put(properties, :applications, runtime_apps)}
    File.write!(app_path, :io_lib.format(~c"~tp.~n", [normalized]))
  end

  @doc false
  def trusted_sigra_seed_for_test?(source_build, copied_build),
    do: trusted_sigra_seed?(source_build, copied_build)

  @doc false
  def configure_seeded_path_dep_for_test!(app_dir, true) do
    disable_compiled_path_dep!(app_dir)
    :trusted
  end

  def configure_seeded_path_dep_for_test!(_app_dir, false), do: :fallback

  defp compile_baseline!(true, _compiler), do: :trusted

  defp compile_baseline!(false, compiler) do
    :ok = compiler.()
    :compiled
  end

  @doc false
  def compile_baseline_for_test!(trusted?, compiler), do: compile_baseline!(trusted?, compiler)

  @doc false
  def relocate_compile_manifest!(build_path, old_root, new_root) do
    old_root = canonical_directory!(old_root)
    new_root = canonical_directory!(new_root)

    with {:ok, app} <- project_app(new_root),
         manifest <- Path.join([build_path, "lib", app, ".mix", "compile.elixir"]),
         {:ok, bytes} <- File.read(manifest),
         term <- :erlang.binary_to_term(bytes),
         true <- is_tuple(term) and tuple_size(term) == 11 and elem(term, 0) == 29,
         {_modules, sources} <- Mix.Compilers.Elixir.read_manifest(manifest),
         true <- relocated_sources_match?(sources, old_root, new_root),
         {rewritten, count} <- rewrite_exact_term(term, old_root, new_root, 0),
         true <- count > 0 do
      temp = "#{manifest}.relocate-#{System.unique_integer([:positive])}"
      File.write!(temp, :erlang.term_to_binary(rewritten, compressed: 9))
      File.rename!(temp, manifest)
      :relocated
    else
      _ -> :fallback
    end
  rescue
    _ -> :fallback
  end

  defp relocate_incremental_compile_manifest!(build_path, old_root, new_root) do
    old_root = canonical_directory!(old_root)
    new_root = canonical_directory!(new_root)

    with {:ok, app} <- project_app(new_root),
         manifest <- Path.join([build_path, "lib", app, ".mix", "compile.elixir"]),
         {:ok, bytes} <- File.read(manifest),
         term <- :erlang.binary_to_term(bytes),
         true <- is_tuple(term) and tuple_size(term) == 11 and elem(term, 0) == 29,
         {_modules, sources} <- Mix.Compilers.Elixir.read_manifest(manifest),
         true <- manifest_sources_match_root?(sources, old_root),
         {rewritten, count} <- rewrite_exact_term(term, old_root, new_root, 0),
         true <- count > 0 do
      temp = "#{manifest}.relocate-#{System.unique_integer([:positive])}"
      File.write!(temp, :erlang.term_to_binary(rewritten, compressed: 9))
      File.rename!(temp, manifest)
      :relocated
    else
      _ -> :fallback
    end
  rescue
    _ -> :fallback
  end

  defp manifest_sources_match_root?(sources, root) do
    MapSet.new(Map.keys(sources)) == source_set(root) and
      Enum.all?(sources, fn {relative, source_entry} ->
        with {:source, size, mtime} <-
               source_entry |> Tuple.to_list() |> Enum.take(3) |> List.to_tuple(),
             {:ok, stat} <- File.stat(Path.join(root, relative), time: :posix) do
          stat.size == size and stat.mtime == mtime
        else
          _ -> false
        end
      end)
  end

  defp project_app(root) do
    case Regex.run(~r/\bapp:\s*:([a-zA-Z0-9_]+)/, File.read!(Path.join(root, "mix.exs"))) do
      [_match, app] -> {:ok, app}
      _ -> :error
    end
  end

  defp relocated_sources_match?(sources, old_root, new_root) do
    manifest_set = MapSet.new(Map.keys(sources))
    old_set = source_set(old_root)
    new_set = source_set(new_root)

    manifest_set == old_set and old_set == new_set and
      Enum.all?(sources, fn {relative, source_entry} ->
        with {:source, size, mtime} <-
               source_entry |> Tuple.to_list() |> Enum.take(3) |> List.to_tuple(),
             {:ok, old_stat} <- File.stat(Path.join(old_root, relative), time: :posix),
             {:ok, new_stat} <- File.stat(Path.join(new_root, relative), time: :posix) do
          old_stat.size == size and new_stat.size == size and old_stat.mtime == mtime and
            new_stat.mtime == mtime
        else
          _ -> false
        end
      end)
  end

  defp source_set(root) do
    root
    |> Path.join("lib/**/*.ex")
    |> Path.wildcard()
    |> MapSet.new(&Path.relative_to(&1, root))
  end

  defp rewrite_exact_term(value, old, new, count) when is_binary(value),
    do: if(value == old, do: {new, count + 1}, else: {value, count})

  defp rewrite_exact_term(value, old, new, count) when is_tuple(value) do
    {items, count} =
      value |> Tuple.to_list() |> Enum.map_reduce(count, &rewrite_exact_term(&1, old, new, &2))

    {List.to_tuple(items), count}
  end

  defp rewrite_exact_term(value, old, new, count) when is_list(value) do
    if value == String.to_charlist(old) do
      {String.to_charlist(new), count + 1}
    else
      Enum.map_reduce(value, count, &rewrite_exact_term(&1, old, new, &2))
    end
  end

  defp rewrite_exact_term(value, old, new, count) when is_map(value) do
    {pairs, count} =
      value
      |> Map.to_list()
      |> Enum.map_reduce(count, fn {key, item}, acc ->
        {key, acc} = rewrite_exact_term(key, old, new, acc)
        {item, acc} = rewrite_exact_term(item, old, new, acc)
        {{key, item}, acc}
      end)

    {Map.new(pairs), count}
  end

  defp rewrite_exact_term(value, _old, _new, count), do: {value, count}

  defp current_sigra_sources_match_manifest?(manifest_path) do
    {_modules, sources} = Mix.Compilers.Elixir.read_manifest(manifest_path)

    expected_sources =
      sigra_repo_root()
      |> Path.join("lib/**/*.ex")
      |> Path.wildcard()
      |> MapSet.new(&Path.relative_to(&1, sigra_repo_root()))

    manifest_sources = MapSet.new(Map.keys(sources))

    MapSet.subset?(expected_sources, manifest_sources) and
      Enum.all?(expected_sources, fn relative_path ->
        case {Map.fetch(sources, relative_path),
              File.stat(Path.join(sigra_repo_root(), relative_path), time: :posix)} do
          {{:ok, source_entry}, {:ok, stat}} ->
            elem(source_entry, 0) == :source and elem(source_entry, 1) == stat.size and
              elem(source_entry, 2) == stat.mtime

          _ ->
            false
        end
      end)
  rescue
    _ -> false
  end

  defp root_deps_path(opts),
    do: Keyword.get(opts, :root_deps_path, Path.join(sigra_repo_root(), "deps"))

  @doc false
  def prune_incompatible_seed!(build_path, lock_path, project_path \\ nil) do
    locked_versions =
      lock_path
      |> File.read!()
      |> then(&Regex.scan(~r/^\s*"([^"]+)": \{:hex, :[^,]+, "([^"]+)"/m, &1))
      |> Map.new(fn [_entry, app, locked_version] -> {app, locked_version} end)

    required_apps = project_build_apps(project_path)
    allowed_apps = MapSet.union(MapSet.new(Map.keys(locked_versions)), required_apps)

    build_path
    |> Path.join("lib")
    |> File.ls!()
    |> Enum.each(fn app ->
      app_path = Path.join([build_path, "lib", app])
      app_file = Path.join([app_path, "ebin", "#{app}.app"])

      if MapSet.member?(allowed_apps, app) do
        case Map.fetch(locked_versions, app) do
          {:ok, locked_version} ->
            case File.read(app_file) do
              {:ok, content} ->
                case Regex.run(~r/\{vsn,"([^"]+)"\}/, content) do
                  [_match, ^locked_version] -> :ok
                  _mismatch -> File.rm_rf!(app_path)
                end

              {:error, :enoent} ->
                :ok

              {:error, reason} ->
                raise File.Error, reason: reason, action: "read", path: app_file
            end

          :error ->
            :ok
        end
      else
        File.rm_rf!(app_path)
      end
    end)

    present_apps = build_path |> Path.join("lib") |> File.ls!() |> MapSet.new()
    {:ok, %{missing_required_apps: MapSet.difference(required_apps, present_apps)}}
  end

  defp project_build_apps(nil), do: MapSet.new(["sigra"])

  defp project_build_apps(project_path) do
    mix_exs = File.read!(Path.join(project_path, "mix.exs"))

    project_apps =
      Regex.scan(~r/\bapp:\s*:([a-zA-Z0-9_]+)/, mix_exs, capture: :all_but_first)
      |> List.flatten()

    unlocked_apps =
      Regex.scan(
        ~r/\{\s*:([a-zA-Z0-9_]+)\s*,[^}\n]*\b(?:path|git):/,
        mix_exs,
        capture: :all_but_first
      )
      |> List.flatten()

    MapSet.new(project_apps ++ unlocked_apps)
  end

  defp materialize_dependency_priv!(build_path, deps_path) do
    deps_path
    |> File.ls!()
    |> Enum.each(fn app ->
      source = Path.join([deps_path, app, "priv"])
      target = Path.join([build_path, "lib", app, "priv"])

      if File.dir?(source) and not File.exists?(target) do
        {_mode, _elapsed_ms} = copy_tree!(source, target)
      end
    end)
  end

  defp build_variant!(name, variant_path) do
    prepare_variant_assets!(name, variant_path)
    run_sigra_install(variant_path, Map.fetch!(@variant_flags, name))
  end

  defp build_variant_without_host_compile!(name, variant_path) do
    prepare_variant_assets!(name, variant_path)
    args = installer_no_compile_command(name)

    command_fun = fn -> System.cmd("mix", args, command_options(variant_path)) end
    {output, status} = with_worker(command_fun)

    if status != 0 do
      raise "mix sigra.install no-compile entrypoint failed in #{variant_path}:\n#{output}"
    end

    {:ok, strip_unavailable_optional_app_warning(output)}
  end

  defp strip_unavailable_optional_app_warning(output) do
    Regex.replace(
      ~r/\AYou have configured application :phoenix_live_view in your configuration file,\n.*?Please ensure :phoenix_live_view exists or remove the configuration\.\n\n/s,
      output,
      "",
      global: false
    )
  end

  defp installer_no_compile_command(name) do
    install_args =
      ["Accounts", "User", "users"] ++ Map.fetch!(@variant_flags, name) ++ ["--yes"]

    expression = "Mix.Tasks.Sigra.Install.run(#{inspect(install_args)})"
    ["run", "--no-start", "--no-compile", "-e", expression]
  end

  @doc false
  def installer_no_compile_command_for_test(name), do: installer_no_compile_command(name)

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
    partition = checkout["partition"]

    deps_path =
      case checkout["deps_path"] do
        nil -> graph_deps_path(app_dir) || Path.join(app_dir, "deps")
        path -> validate_manifest_deps_path!(app_dir, path)
      end

    env =
      [{"MIX_ENV", "dev"}, {"MIX_DEPS_PATH", deps_path}]
      |> maybe_put_env("MIX_TEST_PARTITION", partition)
      |> maybe_put_env(
        "MIX_BUILD_PATH",
        checkout["build_path"] || Process.get({__MODULE__, :installer_build_path}) ||
          graph_build_template_path(app_dir)
      )
      |> maybe_put_env("PORT", to_string_or_nil(checkout["port"]))

    [cd: app_dir, stderr_to_stdout: true, env: env]
  end

  defp graph_build_template_path(app_dir) do
    case graph_root_for(app_dir) do
      nil ->
        nil

      root ->
        path = Path.join(root, "build_template/dev")
        if File.dir?(path), do: validate_graph_member!(path)
    end
  end

  defp graph_deps_path(app_dir) do
    case graph_root_for(app_dir) do
      nil -> nil
      graph_root -> validate_shared_deps!(graph_root, Path.join(graph_root, "shared_deps"))
    end
  end

  defp validate_manifest_deps_path!(app_dir, path) do
    case graph_root_for(app_dir) do
      nil -> raise "prepared fixture checkout is outside its graph root"
      graph_root -> validate_shared_deps!(graph_root, path)
    end
  end

  defp validate_shared_deps!(graph_root, path) do
    expanded = Path.expand(path)
    expected = Path.join(graph_root, "shared_deps")

    if expanded != expected do
      raise "prepared fixture shared deps path escaped its graph root"
    end

    case File.lstat(expanded) do
      {:ok, %{type: :directory, mode: mode}} when Bitwise.band(mode, 0o222) == 0 -> expanded
      _other -> raise "prepared fixture shared deps are missing, writable, or unsafe"
    end
  end

  defp graph_root_for(app_dir) do
    app_dir
    |> Path.expand()
    |> Path.dirname()
    |> Stream.unfold(fn
      "/" -> nil
      current -> {current, Path.dirname(current)}
    end)
    |> Enum.find(&String.starts_with?(Path.basename(&1), "sigra_install_golden."))
  end

  defp maybe_put_env(env, _key, nil), do: env
  defp maybe_put_env(env, key, value), do: [{key, value} | env]

  defp to_string_or_nil(nil), do: nil
  defp to_string_or_nil(value), do: to_string(value)

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
        "deps_path" => checkout.deps_path,
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
           "deps_path" => variant.deps_path,
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
      "deps_path" => graph.deps_path,
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
    expected = [:baseline_compile, :checkout_copy, :deps_get, :phx_new]

    if Enum.sort(Map.keys(timings)) == expected and
         Enum.all?(timings, fn {_phase, duration} -> is_integer(duration) and duration > 0 end) do
      timings
    else
      raise "base builder timings must contain exact positive phx_new/deps_get/baseline_compile values"
    end
  end

  defp monotonic_ms, do: System.monotonic_time(:millisecond)
  defp positive_elapsed(started), do: max(monotonic_ms() - started, 1)

  @doc false
  def copy_tree_for_test!(source, target, opts \\ []), do: copy_tree!(source, target, opts)

  defp copy_tree!(source, target, opts \\ []) do
    source = Path.expand(source)
    target = validate_graph_member!(target)
    File.mkdir_p!(Path.dirname(target))
    started = monotonic_ms()
    os_type = Keyword.get(opts, :os_type, :os.type())
    copy_command = Keyword.get(opts, :command, &System.cmd/3)

    {mode, output, status} =
      case os_type do
        {:unix, :linux} ->
          {out, rc} =
            copy_command.("cp", ["--reflink=always", "-a", source, target],
              stderr_to_stdout: true
            )

          {:reflink, out, rc}

        {:unix, :darwin} ->
          {out, rc} = copy_command.("cp", ["-cRp", source, target], stderr_to_stdout: true)
          {:reflink, out, rc}

        _ ->
          {out, rc} = copy_command.("cp", ["-Rp", source, target], stderr_to_stdout: true)
          {:copy, out, rc}
      end

    {mode, output, status} =
      if status == 0 do
        {mode, output, status}
      else
        safe_remove_graph_member!(target)

        fallback_args =
          if os_type == {:unix, :linux}, do: ["-a", source, target], else: ["-Rp", source, target]

        {out, rc} = copy_command.("cp", fallback_args, stderr_to_stdout: true)
        {:copy, out, rc}
      end

    if status != 0, do: raise("private fixture copy failed (status #{status}): #{output}")
    chmod_tree!(target, "u+w")
    materialize_or_omit_links!(source, target)
    break_hardlinks!(target)

    if unsafe_path = first_unsafe_link(target) do
      raise "private fixture copy retained a symlink or hardlink: #{unsafe_path}"
    end

    {mode, positive_elapsed(started)}
  end

  defp aggregate_modes(modes) do
    if Enum.all?(modes, &(&1 == :reflink)), do: :reflink, else: :copy
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
    case System.cmd("find", [root, "-type", "l", "-print0"], stderr_to_stdout: true) do
      {output, 0} -> String.split(output, <<0>>, trim: true)
      {output, status} -> raise "fixture link scan failed (status #{status}): #{output}"
    end
  end

  defp break_hardlinks!(root) do
    case System.cmd("find", [root, "-type", "f", "-links", "+1", "-print0"],
           stderr_to_stdout: true
         ) do
      {output, 0} ->
        output
        |> String.split(<<0>>, trim: true)
        |> Enum.each(fn path ->
          temp = "#{path}.private-copy-#{System.unique_integer([:positive])}"
          File.cp!(path, temp)
          File.rename!(temp, path)
        end)

      {output, status} ->
        raise "fixture hardlink scan failed (status #{status}): #{output}"
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
          canonical_directory!(Path.dirname(candidate)) in allowed_graph_parents()
      end)

    if is_nil(graph_root) or expanded == graph_root or
         not String.starts_with?(expanded, graph_root <> "/") do
      raise ArgumentError, "unsafe install fixture target: #{expanded}"
    end

    expanded
  end

  defp make_tree_read_only!(root) do
    chmod_tree!(root, "a-w")
  end

  defp make_tree_writable!(root) do
    if File.exists?(root) do
      remove_inherited_acl!(root)
      chmod_tree!(root, "u+w")
    end
  end

  defp remove_inherited_acl!(root) do
    if :os.type() == {:unix, :darwin} do
      case System.cmd(
             "find",
             [root, "-type", "d", "-exec", "chmod", "-N", "{}", "+"],
             stderr_to_stdout: true
           ) do
        {_output, 0} -> :ok
        {output, status} -> raise "fixture ACL removal failed (status #{status}): #{output}"
      end
    else
      :ok
    end
  end

  defp chmod_tree!(root, mode) do
    case System.cmd("chmod", ["-R", mode, root], stderr_to_stdout: true) do
      {_output, 0} -> :ok
      {output, status} -> raise "fixture chmod failed (status #{status}): #{output}"
    end
  end

  defp configure_runtime_isolation!(app_path) do
    config_path = Path.join(app_path, "config/dev.exs")
    content = File.read!(config_path)

    patched =
      Regex.replace(
        ~r/database:\s*"sigra_install_golden_tmp_dev"/,
        content,
        ~S|database: "sigra_install_golden_tmp_dev_" <> System.get_env("MIX_TEST_PARTITION", "base")|,
        global: false
      )

    if patched == content do
      raise "prepared fixture source dev database config is not in the expected shape"
    end

    replaced_port =
      Regex.replace(
        ~r/(http:\s*\[[^\]\r\n]*port:\s*)\d+/,
        patched,
        ~S|\g{1}String.to_integer(System.get_env("PORT", "4000"))|,
        global: false
      )

    with_port =
      if replaced_port == patched do
        Regex.replace(
          ~r/(http:\s*\[[^\]\r\n]*)(\])/,
          patched,
          ~S|\g{1}, port: String.to_integer(System.get_env("PORT", "4000"))\g{2}|,
          global: false
        )
      else
        replaced_port
      end

    if with_port == patched do
      raise "prepared fixture source endpoint config is not in the expected shape"
    end

    File.write!(config_path, with_port)
  end

  defp checkout_partition(graph_root, token) do
    run_id =
      :crypto.hash(:sha256, graph_root)
      |> Base.encode16(case: :lower)
      |> binary_part(0, 10)

    "prepared_#{run_id}_#{token}"
  end

  defp tree_contains_symlink_or_hardlink?(root) do
    not is_nil(first_unsafe_link(root))
  end

  defp first_unsafe_link(root) do
    args = [
      root,
      "(",
      "-type",
      "l",
      "-o",
      "-type",
      "f",
      "-links",
      "+1",
      ")",
      "-print",
      "-quit"
    ]

    case System.cmd("find", args, stderr_to_stdout: true) do
      {"", 0} -> nil
      {path, 0} -> String.trim(path)
      {output, status} -> raise "fixture integrity scan failed (status #{status}): #{output}"
    end
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

  defp ensure_worker_pool! do
    case Process.whereis(@worker_pool) do
      nil ->
        case WorkerPool.start_link(@worker_pool) do
          {:ok, _pid} -> :ok
          {:error, {:already_started, _pid}} -> :ok
          {:error, reason} -> raise "prepared fixture worker pool failed: #{inspect(reason)}"
        end

      _pid ->
        :ok
    end
  end

  defp reset_port_table! do
    if :ets.whereis(@port_table) != :undefined, do: :ets.delete(@port_table)
    :ets.new(@port_table, [:named_table, :public, :set])
  end

  defp allocate_port!(graph_root, token) do
    start = :erlang.phash2({graph_root, token}, 20_000)

    Enum.find_value(0..19_999, fn step ->
      port = 40_000 + rem(start + step, 20_000)

      if :ets.insert_new(@port_table, {port}) do
        if port_available?(port) do
          port
        else
          :ets.delete(@port_table, port)
          nil
        end
      else
        nil
      end
    end) || raise "prepared fixture could not allocate a private endpoint port"
  end

  defp port_available?(port) do
    case :gen_tcp.listen(port, [:binary, active: false, reuseaddr: false]) do
      {:ok, socket} -> :gen_tcp.close(socket) == :ok
      {:error, _reason} -> false
    end
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
          cancel_scenario_timer(active, pid)

          run_scenario_queue(
            ref,
            queued,
            Map.delete(active, pid),
            [{scenario, result} | results],
            runner
          )

        {^ref, pid, scenario, {:error, {:exception, detail}}} ->
          cancel_scenario_workers(active, pid)
          mark_scenario_failed!(scenario)
          {:error, %{status: 1, failed_path: Map.get(scenario, :path), detail: detail}}

        {^ref, pid, scenario, {:error, status}} ->
          cancel_scenario_workers(active, pid)
          mark_scenario_failed!(scenario)
          {:error, %{status: status, failed_path: Map.get(scenario, :path)}}

        {^ref, :timeout, _pid, scenario} ->
          cancel_scenario_workers(active, nil)
          mark_scenario_failed!(scenario)
          {:error, %{status: 124, failed_path: Map.get(scenario, :path)}}
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
                case with_worker(fn -> runner.(scenario) end) do
                  :ok -> {:ok, :ok}
                  {:ok, value} -> {:ok, value}
                  {:error, status} when is_integer(status) and status != 0 -> {:error, status}
                  other -> {:error, {:invalid_result, other}}
                end
              rescue
                exception ->
                  {:error, {:exception, Exception.format(:error, exception, __STACKTRACE__)}}
              catch
                kind, reason ->
                  {:error, {:exception, Exception.format(kind, reason, __STACKTRACE__)}}
              end

            send(parent, {ref, self(), scenario, result})
          end)

        timeout_ms =
          min(Map.get(scenario, :timeout_ms, @scenario_timeout_ms), @scenario_timeout_ms)

        timer = Process.send_after(parent, {ref, :timeout, pid, scenario}, timeout_ms)
        worker = %{scenario: scenario, timer: timer}
        fill_scenario_workers(ref, rest, Map.put(active, pid, worker), runner)

      [] ->
        {[], active}
    end
  end

  defp fill_scenario_workers(_ref, queued, active, _runner), do: {queued, active}

  defp parallel_map!(items, fun) do
    items
    |> Task.async_stream(fun,
      max_concurrency: 2,
      ordered: true,
      timeout: @scenario_timeout_ms,
      on_timeout: :kill_task
    )
    |> Enum.map(fn
      {:ok, value} -> value
      {:exit, reason} -> raise "prepared fixture worker failed: #{inspect(reason)}"
    end)
  end

  defp cancel_scenario_timer(active, pid) do
    case Map.fetch(active, pid) do
      {:ok, %{timer: timer}} -> Process.cancel_timer(timer)
      :error -> :ok
    end
  end

  defp cancel_scenario_workers(active, completed_pid) do
    Enum.each(active, fn {pid, %{timer: timer}} ->
      Process.cancel_timer(timer)
      if pid != completed_pid, do: Process.exit(pid, :kill)
    end)
  end

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
