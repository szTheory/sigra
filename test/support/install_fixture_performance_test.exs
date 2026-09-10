defmodule Sigra.Test.InstallFixturePerformanceTest do
  use ExUnit.Case, async: false

  alias Sigra.Test.InstallFixture

  @variants [
    :default_installed,
    :passkeys_standard,
    :passkeys_nonstandard_app_js,
    :no_passkeys,
    :no_org_no_passkeys,
    :no_org_installed
  ]

  setup do
    root =
      Path.join(
        System.tmp_dir!(),
        "sigra_install_golden.unit-#{System.unique_integer([:positive])}"
      )

    on_exit(fn ->
      if File.dir?(root), do: InstallFixture.cleanup_graph!(root)
    end)

    %{root: root}
  end

  test "one source base derives the exact six immutable variants", %{root: root} do
    graph = prepare_test_graph!(root)

    assert InstallFixture.variant_names() == @variants
    assert Map.keys(graph.variants) |> Enum.sort() == Enum.sort(@variants)
    assert File.regular?(Path.join(graph.base_path, "base.txt"))
    assert File.regular?(graph.manifest_path)

    Enum.each(graph.variants, fn {name, variant} ->
      assert variant.name == name
      assert variant.immutable
      assert is_binary(variant.partition)
      assert is_integer(variant.port)
      assert Path.type(variant.path) == :absolute
      assert File.read!(Path.join(variant.path, "variant.txt")) == Atom.to_string(name)

      assert_raise File.Error, fn ->
        File.write!(Path.join(variant.path, "variant.txt"), "mutation")
      end
    end)
  end

  test "private scenario checkouts isolate files, builds, partitions, and ports", %{root: root} do
    graph = prepare_test_graph!(root)

    first = InstallFixture.checkout!(graph, :default_installed, "idempotency")
    second = InstallFixture.checkout!(graph, :default_installed, "upgrade")

    assert first.partition != second.partition
    assert first.partition =~ ~r/^prepared_[0-9a-f]{10}_\d+$/
    assert second.partition =~ ~r/^prepared_[0-9a-f]{10}_\d+$/
    assert first.port != second.port
    allocated_ports = [first.port, second.port | Enum.map(graph.variants, &elem(&1, 1).port)]
    assert length(allocated_ports) == MapSet.size(MapSet.new(allocated_ports))

    Enum.each(allocated_ports, fn port ->
      assert {:ok, socket} = :gen_tcp.listen(port, [:binary, active: false, reuseaddr: false])
      assert :ok = :gen_tcp.close(socket)
    end)

    assert first.build_path != second.build_path
    assert first.path != second.path
    assert first.copy_mode in [:reflink, :copy]
    refute File.exists?(Path.join(first.path, "deps"))
    refute File.exists?(Path.join(second.path, "deps"))
    refute File.exists?(Path.join(graph.variants.default_installed.path, "deps"))
    assert File.dir?(graph.deps_path)
    assert Bitwise.band(File.stat!(graph.deps_path).mode, 0o222) == 0

    assert File.read!(Path.join(first.build_path, "lib/phoenix/priv/static/phoenix.js")) ==
             "prepared phoenix asset"

    assert File.read!(Path.join(second.build_path, "lib/phoenix/priv/static/phoenix.js")) ==
             "prepared phoenix asset"

    executable = "lib/file_system/priv/mac_listener"
    first_executable = File.stat!(Path.join(first.build_path, executable)).mode

    template_executable = File.stat!(Path.join(graph.build_template_path, executable)).mode

    assert Bitwise.band(first_executable, 0o100) == 0o100
    assert Bitwise.band(first_executable, 0o200) == 0o200
    assert Bitwise.band(template_executable, 0o100) == 0o100
    assert Bitwise.band(template_executable, 0o200) == 0
    refute File.exists?(Path.join(graph.variants.default_installed.path, "_build/dev"))

    template = "lib/sigra/priv/templates/sigra.install/organizations/router_injection.ex"
    assert File.regular?(Path.join(first.build_path, template))

    assert File.read!(Path.join(first.build_path, template)) ==
             File.read!("priv/templates/sigra.install/organizations/router_injection.ex")

    first_dev = File.read!(Path.join(first.path, "config/dev.exs"))
    second_dev = File.read!(Path.join(second.path, "config/dev.exs"))
    variant_dev = File.read!(Path.join(graph.variants.default_installed.path, "config/dev.exs"))

    assert first_dev =~ ~S|System.get_env("MIX_TEST_PARTITION"|
    assert first_dev =~ ~S|System.get_env("PORT"|
    assert first_dev == second_dev
    assert first_dev == variant_dev

    normalized_dev = InstallFixture.normalize_content_for_golden("config/dev.exs", first_dev)
    assert normalized_dev =~ ~s(database: "sigra_install_golden_tmp_dev")
    refute normalized_dev =~ "System.get_env"

    first_runtime_config = read_runtime_config(first)
    second_runtime_config = read_runtime_config(second)

    assert get_in(first_runtime_config, [
             :sigra_install_golden_tmp,
             SigraInstallGoldenTmp.Repo,
             :database
           ]) == "sigra_install_golden_tmp_dev_#{first.partition}"

    assert get_in(second_runtime_config, [
             :sigra_install_golden_tmp,
             SigraInstallGoldenTmp.Repo,
             :database
           ]) == "sigra_install_golden_tmp_dev_#{second.partition}"

    assert get_in(first_runtime_config, [
             :sigra_install_golden_tmp,
             SigraInstallGoldenTmpWeb.Endpoint,
             :http,
             :port
           ]) == first.port

    assert get_in(second_runtime_config, [
             :sigra_install_golden_tmp,
             SigraInstallGoldenTmpWeb.Endpoint,
             :http,
             :port
           ]) == second.port

    File.write!(Path.join(first.path, "variant.txt"), "private mutation")

    File.write!(
      Path.join(first.build_path, "lib/phoenix/priv/static/phoenix.js"),
      "private build"
    )

    assert File.read!(Path.join(second.path, "variant.txt")) == "default_installed"

    assert File.read!(Path.join(graph.variants.default_installed.path, "variant.txt")) ==
             "default_installed"

    assert File.read!(
             Path.join(
               graph.build_template_path,
               "lib/phoenix/priv/static/phoenix.js"
             )
           ) == "prepared phoenix asset"

    assert File.read!(Path.join(second.build_path, "lib/phoenix/priv/static/phoenix.js")) ==
             "prepared phoenix asset"

    refute InstallFixture.tree_has_shared_writable_state?(
             graph.variants.default_installed.path,
             first.path
           )

    refute InstallFixture.tree_has_shared_writable_state?(first.build_path, second.build_path)
  end

  test "cache bytes are reused only for an exact compatibility fingerprint", %{root: root} do
    source = Path.join(root, "source-build")
    compatible = Path.join(root, "compatible-build")
    mismatch = Path.join(root, "mismatch-build")
    File.mkdir_p!(source)
    File.write!(Path.join(source, "beam"), "compiled")
    File.ln!(Path.join(source, "beam"), Path.join(source, "beam-hardlink"))

    fingerprint = InstallFixture.compatibility_fingerprint(lock: "lock", compiler: "compiler")

    assert {:ok, mode, elapsed_ms} =
             InstallFixture.seed_compatible_tree!(source, compatible, fingerprint, fingerprint)

    assert mode in [:reflink, :copy]
    assert elapsed_ms >= 1
    assert File.read!(Path.join(compatible, "beam")) == "compiled"
    assert File.read!(Path.join(compatible, "beam-hardlink")) == "compiled"
    assert File.stat!(Path.join(compatible, "beam")).links == 1
    assert File.stat!(Path.join(compatible, "beam-hardlink")).links == 1

    assert :incompatible =
             InstallFixture.seed_compatible_tree!(source, mismatch, fingerprint, "different")

    refute File.exists?(mismatch)
  end

  test "Linux graph parent selection requires every tmpfs safety predicate", %{root: root} do
    File.mkdir_p!(root)
    {canonical_root, 0} = System.cmd("pwd", [], cd: root)
    {canonical_tmp, 0} = System.cmd("pwd", [], cd: System.tmp_dir!())
    canonical_root = String.trim(canonical_root)
    canonical_tmp = String.trim(canonical_tmp)
    eligible = %{canonical?: true, tmpfs?: true, writable?: true, free_bytes: 1_610_612_736}

    assert InstallFixture.graph_parent_for_test(
             os_type: {:unix, :linux},
             tmpfs_parent: root,
             probe: fn ^root -> eligible end
           ) == canonical_root

    for rejected <- [
          %{eligible | canonical?: false},
          %{eligible | tmpfs?: false},
          %{eligible | writable?: false},
          %{eligible | free_bytes: 1_610_612_735}
        ] do
      assert InstallFixture.graph_parent_for_test(
               os_type: {:unix, :linux},
               tmpfs_parent: root,
               probe: fn ^root -> rejected end
             ) == canonical_tmp
    end

    assert InstallFixture.graph_parent_for_test(
             os_type: {:unix, :darwin},
             tmpfs_parent: root,
             probe: fn _ -> flunk("non-Linux must not probe tmpfs") end
           ) == canonical_tmp
  end

  test "Linux copy mode reports reflink only when reflink=always succeeds", %{root: root} do
    source = Path.join(root, "copy-source")
    File.mkdir_p!(source)
    File.write!(Path.join(source, "bytes"), "private")
    parent = self()

    successful_reflink = fn executable, args, options ->
      send(parent, {:copy_command, args})
      System.cmd(executable, Enum.reject(args, &(&1 == "--reflink=always")), options)
    end

    reflink_target = Path.join(root, "reflink-target")

    assert {:reflink, _elapsed} =
             InstallFixture.copy_tree_for_test!(source, reflink_target,
               os_type: {:unix, :linux},
               command: successful_reflink
             )

    assert_receive {:copy_command, ["--reflink=always", "-a", ^source, ^reflink_target]}

    fallback_target = Path.join(root, "fallback-target")

    fallback = fn
      "cp", ["--reflink=always" | _rest] = args, _options ->
        send(parent, {:copy_command, args})
        File.mkdir_p!(fallback_target)
        partial = Path.join(fallback_target, "read-only-partial")
        File.write!(partial, "incomplete reflink")
        File.chmod!(partial, 0o400)
        File.chmod!(fallback_target, 0o500)
        {"reflink unsupported", 1}

      executable, args, options ->
        send(parent, {:copy_command, args})
        System.cmd(executable, args, options)
    end

    assert {:copy, _elapsed} =
             InstallFixture.copy_tree_for_test!(source, fallback_target,
               os_type: {:unix, :linux},
               command: fallback
             )

    assert_receive {:copy_command, ["--reflink=always", "-a", ^source, ^fallback_target]}
    assert_receive {:copy_command, ["-a", ^source, ^fallback_target]}
    assert File.read!(Path.join(fallback_target, "bytes")) == "private"
    refute InstallFixture.tree_has_shared_writable_state?(reflink_target, fallback_target)
  end

  test "validated compiler manifest relocation preserves a clean private build", %{root: root} do
    graph =
      InstallFixture.prepare_graph!(
        root: root,
        fingerprint: "relocation",
        base_builder: fn base ->
          File.mkdir_p!(Path.join(base, "lib"))
          deps = Path.join([Path.dirname(Path.dirname(base)), "shared_deps"])
          File.mkdir_p!(deps)
          File.chmod!(deps, 0o500)

          File.write!(
            Path.join(base, "mix.exs"),
            "defmodule R.MixProject do\nuse Mix.Project\ndef project, do: [app: :r, version: \"0.1.0\"]\nend\n"
          )

          File.write!(Path.join(base, "lib/r.ex"), "defmodule R do\ndef ok, do: true\nend\n")
          {_, 0} = System.cmd("mix", ["compile"], cd: base, stderr_to_stdout: true)
          :ok
        end,
        variant_builder: fn _name, _path -> {:ok, ""} end,
        variant_compiler: fn path ->
          assert {:ok, output} = InstallFixture.run_mix(path, ["compile"])
          assert output =~ "Compiling 1 file"
          :ok
        end
      )

    checkout = InstallFixture.checkout!(graph, :default_installed, "relocated")
    assert checkout.manifest_mode == :relocated
    assert {:ok, output} = InstallFixture.run_mix(checkout.path, ["compile"])
    refute output =~ "Compiling"

    File.write!(
      Path.join(checkout.path, "lib/r.ex"),
      "defmodule R do\ndef ok, do: :changed\nend\n"
    )

    assert {:ok, output} = InstallFixture.run_mix(checkout.path, ["compile"])
    assert output =~ "Compiling 1 file"

    unknown = Path.join([checkout.build_path, "lib", "r", ".mix", "compile.elixir"])
    File.write!(unknown, :erlang.term_to_binary({999, :unknown}))

    assert :fallback =
             InstallFixture.relocate_compile_manifest!(
               checkout.build_path,
               checkout.path,
               checkout.path
             )
  end

  test "generated lock pruning retains only compatible dependency and Sigra build bytes", %{
    root: root
  } do
    build = Path.join(root, "seeded-build")
    lock = Path.join(root, "generated.lock")
    project = Path.join(root, "generated-project")
    File.mkdir_p!(project)

    File.write!(
      Path.join(project, "mix.exs"),
      "def project, do: [app: :generated_host]\ndefp deps, do: [{:sigra, path: \"../sigra\"}]\n"
    )

    for {app, version} <- [phoenix: "1.8.13", stale_dep: "9.0.0", sigra: "1.5.0"] do
      app_dir = Path.join([build, "lib", Atom.to_string(app), "ebin"])
      File.mkdir_p!(app_dir)

      File.write!(
        Path.join(app_dir, "#{app}.app"),
        "{application,#{app},[{vsn,\"#{version}\"}]} ."
      )
    end

    File.write!(
      lock,
      ~s(%{\n  "phoenix": {:hex, :phoenix, "1.8.13", "hash", [], [], "hexpm", "hash"}\n})
    )

    assert {:ok, %{missing_required_apps: missing}} =
             InstallFixture.prune_incompatible_seed!(build, lock, project)

    assert File.dir?(Path.join([build, "lib", "phoenix"]))
    assert File.dir?(Path.join([build, "lib", "sigra"]))
    refute File.exists?(Path.join([build, "lib", "stale_dep"]))
    assert missing == MapSet.new(["generated_host"])
  end

  test "generated lock pruning reports a missing required path app for Mix invalidation", %{
    root: root
  } do
    build = Path.join(root, "missing-path-build")
    project = Path.join(root, "missing-path-project")
    lock = Path.join(root, "missing-path.lock")
    File.mkdir_p!(Path.join(build, "lib"))
    File.mkdir_p!(project)
    File.write!(lock, "%{}\n")

    File.write!(
      Path.join(project, "mix.exs"),
      "def project, do: [app: :generated_host]\ndefp deps, do: [{:sigra, path: \"../sigra\"}]\n"
    )

    assert {:ok, %{missing_required_apps: missing}} =
             InstallFixture.prune_incompatible_seed!(build, lock, project)

    assert missing == MapSet.new(["generated_host", "sigra"])
    refute File.exists?(Path.join([build, "lib", "sigra"]))
  end

  test "incomplete seeded applications are invalidated before trusted reuse", %{root: root} do
    build = Path.join(root, "incomplete-app-build")
    app_path = Path.join([build, "lib", "parser_dep"])
    ebin = Path.join(app_path, "ebin")
    File.mkdir_p!(ebin)

    File.write!(
      Path.join(ebin, "parser_dep.app"),
      ~c"{application,parser_dep,[{modules,['Elixir.ParserDep',parser_dep_generated]}]}.\n"
    )

    File.write!(Path.join(ebin, "Elixir.ParserDep.beam"), "present")
    InstallFixture.prune_incomplete_seed_apps_for_test!(build)
    refute File.exists?(app_path)
  end

  test "Sigra dependency compile bypass is conditional on a trusted current seed", %{root: root} do
    app = Path.join(root, "seed-policy-app")
    File.mkdir_p!(app)
    sigra_root = Path.expand(".")
    mix_exs = Path.join(app, "mix.exs")

    dependency = "{:sigra, path: #{inspect(sigra_root)}, override: true}"
    File.write!(mix_exs, "defp deps, do: [#{dependency}]\n")

    assert :fallback = InstallFixture.configure_seeded_path_dep_for_test!(app, false)
    assert File.read!(mix_exs) =~ dependency
    refute File.read!(mix_exs) =~ "compile: false"

    assert :trusted = InstallFixture.configure_seeded_path_dep_for_test!(app, true)
    assert File.read!(mix_exs) =~ "#{dependency |> String.trim_trailing("}")}, compile: false}"

    missing_build = Path.join(root, "missing-seed")
    copied_build = Path.join(root, "copied-seed")
    File.mkdir_p!(copied_build)

    refute InstallFixture.trusted_sigra_seed_for_test?(missing_build, copied_build)
  end

  test "trusted seed skips baseline host compile and uses the exact no-compile installer task" do
    compiler = fn ->
      send(self(), :compiled)
      :ok
    end

    assert :trusted = InstallFixture.compile_baseline_for_test!(true, compiler)
    refute_received :compiled
    assert :compiled = InstallFixture.compile_baseline_for_test!(false, compiler)
    assert_received :compiled

    assert ["run", "--no-start", "--no-compile", "-e", expression] =
             InstallFixture.installer_no_compile_command_for_test(:no_org_no_passkeys)

    assert expression ==
             "Mix.Tasks.Sigra.Install.run([\"Accounts\", \"User\", \"users\", \"--no-organizations\", \"--no-passkeys\", \"--yes\"])"
  end

  test "no-compile stdout strips only canonical leading allowlisted warning blocks" do
    installer = "* creating lib/example.ex\ninstaller-owned bytes\n"
    sigra = unavailable_app_warning("sigra_install_golden_tmp")
    live_view = unavailable_app_warning("phoenix_live_view")

    assert InstallFixture.normalize_no_compile_stdout_for_test(installer) == installer
    assert InstallFixture.normalize_no_compile_stdout_for_test(sigra <> installer) == installer

    assert InstallFixture.normalize_no_compile_stdout_for_test(
             sigra <> sigra <> live_view <> installer
           ) == installer

    forbidden = unavailable_app_warning("unknown_app")

    assert InstallFixture.normalize_no_compile_stdout_for_test(forbidden <> installer) ==
             forbidden <> installer

    mismatched =
      unavailable_app_warning("sigra_install_golden_tmp")
      |> String.replace(
        "Please ensure :sigra_install_golden_tmp exists",
        "Please ensure :phoenix_live_view exists"
      )

    assert InstallFixture.normalize_no_compile_stdout_for_test(mismatched <> installer) ==
             mismatched <> installer

    noncanonical =
      String.replace(sigra, "This usually means one of:", "This usually means one of: ")

    assert InstallFixture.normalize_no_compile_stdout_for_test(noncanonical <> installer) ==
             noncanonical <> installer

    assert InstallFixture.normalize_no_compile_stdout_for_test(installer <> live_view) ==
             installer <> live_view

    assert InstallFixture.normalize_no_compile_stdout_for_test(sigra <> installer <> live_view) ==
             installer <> live_view
  end

  test "compile-state reuse requires identical compile-relevant source bytes", %{root: root} do
    first = Path.join(root, "digest-first")
    second = Path.join(root, "digest-second")

    for path <- [first, second] do
      File.mkdir_p!(Path.join(path, "lib"))
      File.mkdir_p!(Path.join(path, "assets"))
      File.write!(Path.join(path, "mix.exs"), "def project, do: [app: :host]\n")
      File.write!(Path.join(path, "mix.lock"), "%{}\n")
      File.write!(Path.join(path, "lib/host.ex"), "defmodule Host do\nend\n")
    end

    File.write!(Path.join(first, "assets/app.js"), "standard")
    File.write!(Path.join(second, "assets/app.js"), "nonstandard")

    assert InstallFixture.compile_relevant_digest_for_test(first) ==
             InstallFixture.compile_relevant_digest_for_test(second)

    File.write!(
      Path.join(second, "lib/host.ex"),
      "defmodule Host do\ndef changed, do: true\nend\n"
    )

    refute InstallFixture.compile_relevant_digest_for_test(first) ==
             InstallFixture.compile_relevant_digest_for_test(second)
  end

  test "copies materialize valid links and omit dangling generated build links", %{root: root} do
    graph =
      InstallFixture.prepare_graph!(
        root: root,
        fingerprint: "test-fingerprint",
        base_builder: fn base_path ->
          generated_dir = Path.join(base_path, "_build/dev/phoenix-colocated/node_modules")
          File.mkdir_p!(generated_dir)
          File.write!(Path.join(base_path, "source.txt"), "source bytes")
          File.ln_s!("source.txt", Path.join(base_path, "valid-link"))

          File.ln_s!(
            "../../../../missing-node-modules",
            Path.join(generated_dir, "dangling-link")
          )

          :ok
        end,
        variant_builder: fn _name, _variant_path -> {:ok, ""} end
      )

    assert File.lstat!(Path.join(graph.base_path, "valid-link")).type == :symlink

    refute File.exists?(Path.join(graph.base_path, "_build/dev"))

    Enum.each(graph.variants, fn {_name, variant} ->
      materialized = Path.join(variant.path, "valid-link")

      assert File.regular?(materialized)
      assert File.read!(materialized) == "source bytes"
      refute File.exists?(Path.join(variant.path, "_build/dev"))
    end)

    dangling =
      Path.join(graph.build_template_path, "phoenix-colocated/node_modules/dangling-link")

    refute File.exists?(dangling)
    assert File.lstat(dangling) == {:error, :enoent}
  end

  test "subprocess helpers retain return shape and propagate checkout partition", %{root: root} do
    graph = prepare_test_graph!(root)
    checkout = InstallFixture.checkout!(graph, :default_installed, "subprocess")

    command = fn executable, argv, options ->
      send(self(), {:command, executable, argv, options})
      {"ok", 0}
    end

    assert {:ok, "ok"} = InstallFixture.run_mix(checkout.path, ["compile"], command: command)

    assert_receive {:command, "mix", ["compile"], options}
    assert {"MIX_TEST_PARTITION", checkout.partition} in options[:env]
    assert {"MIX_BUILD_PATH", checkout.build_path} in options[:env]
    assert {"MIX_DEPS_PATH", graph.deps_path} in options[:env]

    assert {"PORT", to_string(checkout.port)} in options[:env]
  end

  test "cleanup rejects arbitrary roots and removes only the validated graph root", %{root: root} do
    graph = prepare_test_graph!(root)
    outside = Path.join(root, "..") |> Path.expand()

    assert_raise ArgumentError, fn -> InstallFixture.cleanup_graph!(outside) end
    assert :ok = InstallFixture.cleanup_graph!(graph)
    refute File.exists?(root)
  end

  test "graph cleanup retries a transient partially removed tree without hiding failure", %{
    root: root
  } do
    nested = Path.join(root, "shared_deps")
    File.mkdir_p!(nested)
    File.chmod!(nested, 0o500)

    remover = fn path ->
      case Process.get(:cleanup_attempt, 0) do
        0 ->
          Process.put(:cleanup_attempt, 1)
          {:error, :eexist, nested}

        _ ->
          File.rm_rf(path)
      end
    end

    assert :ok = InstallFixture.cleanup_graph_root_for_test!(root, remover)
    assert Process.get(:cleanup_attempt) == 1
    refute File.exists?(root)
    Process.delete(:cleanup_attempt)
  end

  test "diagnostics require exact positive phases bounded by raw install duration", %{root: root} do
    graph = prepare_test_graph!(root)
    receipt_without_raw = InstallFixture.diagnostic_receipt(graph)

    refute Map.has_key?(receipt_without_raw, :raw_install_duration_ms)

    assert Map.keys(receipt_without_raw.phases) |> Enum.sort() ==
             ~w(baseline_compile checkout_copy deps_get installer phx_new receiver_compile_runtime)a

    assert Enum.all?(receipt_without_raw.phases, fn {_phase, duration} -> duration > 0 end)

    phase_sum = Enum.sum(Map.values(receipt_without_raw.phases))
    assert phase_sum > 0

    receipt = Map.put(receipt_without_raw, :raw_install_duration_ms, phase_sum)

    assert :ok = InstallFixture.validate_diagnostics!(receipt)
    assert Enum.sum(Map.values(receipt.phases)) == receipt.raw_install_duration_ms
    assert receipt.variant_count == 6
    assert receipt.worker_count == 2
    refute Map.has_key?(receipt, :verdict)

    assert_raise ArgumentError, fn ->
      receipt
      |> put_in([:phases, :installer], 0)
      |> InstallFixture.validate_diagnostics!()
    end

    assert_raise ArgumentError, fn ->
      %{receipt | phases: Map.put(receipt.phases, :unexpected, 1)}
      |> InstallFixture.validate_diagnostics!()
    end

    assert_raise ArgumentError, fn ->
      %{receipt | raw_install_duration_ms: phase_sum - 1}
      |> InstallFixture.validate_diagnostics!()
    end
  end

  test "variant preparation uses the same exact two-worker ceiling", %{root: root} do
    {:ok, counter} = Agent.start_link(fn -> %{active: 0, maximum: 0} end)

    graph =
      InstallFixture.prepare_graph!(
        root: root,
        fingerprint: "test-fingerprint",
        base_builder: fn base_path ->
          File.mkdir_p!(base_path)
          File.write!(Path.join(base_path, "base.txt"), "base")
          :ok
        end,
        variant_builder: fn name, variant_path ->
          Agent.update(counter, fn state ->
            active = state.active + 1
            %{active: active, maximum: max(state.maximum, active)}
          end)

          Process.sleep(20)
          File.write!(Path.join(variant_path, "variant.txt"), Atom.to_string(name))
          Agent.update(counter, &%{&1 | active: &1.active - 1})
          {:ok, ""}
        end
      )

    assert map_size(graph.variants) == 6
    assert Agent.get(counter, & &1.maximum) == 2
  end

  test "scenario runner fixes concurrency at two and cancels on first failure" do
    {:ok, counter} = Agent.start_link(fn -> %{active: 0, maximum: 0, completed: []} end)
    caller = self()

    barrier =
      spawn(fn ->
        receive do
          {:entered, first_id, first_pid} ->
            receive do
              {:entered, second_id, second_pid} ->
                fail_pid =
                  Map.fetch!(%{first_id => first_pid, second_id => second_pid}, :fail)

                send(fail_pid, :both_workers_entered)
            end
        end
      end)

    scenarios = [
      %{id: :slow, path: "/tmp/slow"},
      %{id: :fail, path: "/tmp/fail"},
      %{id: :never_started, path: "/tmp/never"}
    ]

    runner = fn scenario ->
      Agent.update(counter, fn state ->
        active = state.active + 1
        %{state | active: active, maximum: max(state.maximum, active)}
      end)

      send(caller, {:started, scenario.id})
      send(barrier, {:entered, scenario.id, self()})

      result =
        case scenario.id do
          :fail ->
            receive do
              :both_workers_entered -> {:error, 23}
            end

          _ ->
            receive do
              :unexpected_release -> :unexpected
            end
        end

      Agent.update(counter, fn state ->
        %{state | active: state.active - 1, completed: [scenario.id | state.completed]}
      end)

      result
    end

    assert {:error, %{status: 23, failed_path: "/tmp/fail"}} =
             InstallFixture.run_scenarios(scenarios, runner)

    state = Agent.get(counter, & &1)
    assert state.maximum == 2
    refute :never_started in state.completed
    refute :slow in state.completed
    assert_receive {:started, :slow}
    assert_receive {:started, :fail}
    refute_receive {:started, :never_started}
  end

  test "scenario runner bounds a hung external command and cancels its peer" do
    caller = self()

    scenarios = [
      %{id: :hung, path: "/tmp/hung", timeout_ms: 25},
      %{id: :peer, path: "/tmp/peer", timeout_ms: 25},
      %{id: :never_started, path: "/tmp/never", timeout_ms: 25}
    ]

    runner = fn scenario ->
      send(caller, {:started, scenario.id})
      Process.sleep(:infinity)
    end

    assert {:error, %{status: 124, failed_path: failed_path}} =
             InstallFixture.run_scenarios(scenarios, runner)

    assert failed_path in ["/tmp/hung", "/tmp/peer"]
    assert_receive {:started, :hung}
    assert_receive {:started, :peer}
    refute_receive {:started, :never_started}
  end

  test "scenario runner preserves exception diagnostics while failing closed" do
    scenario = %{path: "/tmp/diagnostic"}

    assert {:error, %{status: 1, failed_path: "/tmp/diagnostic", detail: detail}} =
             InstallFixture.run_scenarios([scenario], fn _scenario ->
               raise MatchError, term: {:error, :timeout}
             end)

    assert detail =~ "** (MatchError)"
    assert detail =~ "{:error, :timeout}"
  end

  test "graph-global worker leases cap independent callers and recover after owner death" do
    {:ok, counter} = Agent.start_link(fn -> %{active: 0, maximum: 0} end)

    1..4
    |> Enum.map(fn _index ->
      Task.async(fn ->
        InstallFixture.with_worker(fn ->
          Agent.update(counter, fn state ->
            active = state.active + 1
            %{active: active, maximum: max(state.maximum, active)}
          end)

          Process.sleep(20)
          Agent.update(counter, &%{&1 | active: &1.active - 1})
        end)
      end)
    end)
    |> Task.await_many(1_000)

    assert Agent.get(counter, & &1.maximum) == 2

    caller = self()

    holder =
      spawn(fn ->
        InstallFixture.with_worker(fn ->
          send(caller, :holder_acquired)
          Process.sleep(:infinity)
        end)
      end)

    assert_receive :holder_acquired
    Process.exit(holder, :kill)

    spawn(fn -> InstallFixture.with_worker(fn -> send(caller, :replacement_acquired) end) end)
    assert_receive :replacement_acquired, 500
  end

  test "variant compilation retries once with a complete graph-private writable deps copy", %{
    root: root
  } do
    %{variant_path: variant_path, shared_deps: shared_deps} = recovery_fixture!(root)
    shared_snapshot = tree_snapshot(shared_deps)
    Process.delete({__MODULE__, :compile_calls})

    command = fn "mix", ["compile"], options ->
      call = Process.get({__MODULE__, :compile_calls}, 0) + 1
      Process.put({__MODULE__, :compile_calls}, call)
      env = options[:env] |> Map.new()

      case call do
        1 ->
          assert env["MIX_DEPS_PATH"] == shared_deps
          {"Could not compile dependency :telemetry_poller, mix compile failed", 1}

        2 ->
          retry_deps = Map.fetch!(env, "MIX_DEPS_PATH")
          assert env["DIAGNOSTIC"] == "1"
          assert retry_deps != shared_deps
          assert String.starts_with?(retry_deps, Path.join(root, "compile_recovery") <> "/")
          assert File.read!(Path.join(retry_deps, "telemetry_poller/source.erl")) == "poller"
          assert File.read!(Path.join(retry_deps, "jason/source.ex")) == "jason"

          assert File.read!(
                   Path.join(retry_deps, "telemetry_poller/_build/prod/lib/.rebar3/base_graph")
                 ) == "sealed graph"

          assert Bitwise.band(File.stat!(retry_deps).mode, 0o200) == 0o200
          refute InstallFixture.tree_has_shared_writable_state?(shared_deps, retry_deps)

          dag_path =
            Path.join(retry_deps, "telemetry_poller/_build/prod/lib/.rebar3/compile_graph")

          File.mkdir_p!(Path.dirname(dag_path))
          File.write!(dag_path, "private dag")
          {"retry succeeded", 0}
      end
    end

    assert :ok = InstallFixture.compile_variant_for_test!(variant_path, command)
    assert Process.get({__MODULE__, :compile_calls}) == 2
    assert tree_snapshot(shared_deps) == shared_snapshot

    [retry_deps] = Path.wildcard(Path.join(root, "compile_recovery/*/shared_deps"))

    assert File.read!(
             Path.join(retry_deps, "telemetry_poller/_build/prod/lib/.rebar3/compile_graph")
           ) ==
             "private dag"
  end

  test "non-dependency failures keep original authority and create no recovery copy", %{
    root: root
  } do
    %{variant_path: variant_path} = recovery_fixture!(root)
    Process.put({__MODULE__, :compile_calls}, 0)

    command = fn "mix", ["compile"], _options ->
      Process.put({__MODULE__, :compile_calls}, Process.get({__MODULE__, :compile_calls}) + 1)
      {"ordinary compiler failure", 17}
    end

    assert_raise RuntimeError, ~r/ordinary compiler failure/, fn ->
      InstallFixture.compile_variant_for_test!(variant_path, command)
    end

    assert Process.get({__MODULE__, :compile_calls}) == 1
    refute File.exists?(Path.join(root, "compile_recovery"))
  end

  test "missing dependency source fails closed before retry or copy", %{root: root} do
    %{variant_path: variant_path} = recovery_fixture!(root)
    Process.put({__MODULE__, :compile_calls}, 0)

    command = fn "mix", ["compile"], _options ->
      Process.put({__MODULE__, :compile_calls}, Process.get({__MODULE__, :compile_calls}) + 1)
      {"Could not compile dependency :missing_dep, mix compile failed", 19}
    end

    assert_raise RuntimeError, ~r/missing dependency source/, fn ->
      InstallFixture.compile_variant_for_test!(variant_path, command)
    end

    assert Process.get({__MODULE__, :compile_calls}) == 1
    refute File.exists?(Path.join(root, "compile_recovery"))
  end

  test "ambiguous or path-shaped dependency output cannot authorize recovery", %{root: root} do
    %{variant_path: variant_path} = recovery_fixture!(root)

    for output <- [
          "Could not compile dependency :../../escape, mix compile failed",
          "Could not compile dependency :jason\nCould not compile dependency :telemetry_poller"
        ] do
      Process.put({__MODULE__, :compile_calls}, 0)

      command = fn "mix", ["compile"], _options ->
        Process.put({__MODULE__, :compile_calls}, Process.get({__MODULE__, :compile_calls}) + 1)
        {output, 31}
      end

      assert_raise RuntimeError, fn ->
        InstallFixture.compile_variant_for_test!(variant_path, command)
      end

      assert Process.get({__MODULE__, :compile_calls}) == 1
      refute File.exists?(Path.join(root, "compile_recovery"))
    end
  end

  test "failed retry remains bounded and graph cleanup removes its private source", %{root: root} do
    %{variant_path: variant_path, shared_deps: shared_deps} = recovery_fixture!(root)
    shared_snapshot = tree_snapshot(shared_deps)
    Process.put({__MODULE__, :compile_calls}, 0)

    command = fn "mix", ["compile"], _options ->
      call = Process.get({__MODULE__, :compile_calls}) + 1
      Process.put({__MODULE__, :compile_calls}, call)

      if call == 1,
        do: {"Could not compile dependency :telemetry_poller, mix compile failed", 23},
        else: {"retry still failed", 29}
    end

    assert_raise RuntimeError, ~r/retry still failed/, fn ->
      InstallFixture.compile_variant_for_test!(variant_path, command)
    end

    assert Process.get({__MODULE__, :compile_calls}) == 2
    assert tree_snapshot(shared_deps) == shared_snapshot
    assert [_private] = Path.wildcard(Path.join(root, "compile_recovery/*/shared_deps"))
    assert :ok = InstallFixture.cleanup_graph!(root)
    refute File.exists?(root)
  end

  defp prepare_test_graph!(root) do
    InstallFixture.prepare_graph!(
      root: root,
      fingerprint: "test-fingerprint",
      base_builder: fn base_path ->
        File.mkdir_p!(base_path)
        File.write!(Path.join(base_path, "base.txt"), "base")
        shared_deps = Path.join([Path.dirname(Path.dirname(base_path)), "shared_deps"])
        File.mkdir_p!(shared_deps)
        dependency_source = Path.join(shared_deps, "source.ex")
        File.write!(dependency_source, "dependency source")
        File.chmod!(dependency_source, 0o400)
        File.chmod!(shared_deps, 0o500)
        build_asset = Path.join(base_path, "_build/dev/lib/phoenix/priv/static/phoenix.js")
        File.mkdir_p!(Path.dirname(build_asset))
        File.write!(build_asset, "prepared phoenix asset")

        executable = Path.join(base_path, "_build/dev/lib/file_system/priv/mac_listener")
        File.mkdir_p!(Path.dirname(executable))
        File.write!(executable, "#!/bin/sh\nexit 0\n")
        File.chmod!(executable, 0o755)

        dev_config = Path.join(base_path, "config/dev.exs")
        File.mkdir_p!(Path.dirname(dev_config))

        File.write!(dev_config, """
        import Config
        config :sigra_install_golden_tmp, SigraInstallGoldenTmp.Repo,
          database: "sigra_install_golden_tmp_dev"
        config :sigra_install_golden_tmp, SigraInstallGoldenTmpWeb.Endpoint,
          http: [ip: {127, 0, 0, 1}]
        """)

        template_source =
          Path.expand("priv/templates/sigra.install/organizations/router_injection.ex")

        template_link =
          Path.join(
            base_path,
            "_build/dev/lib/sigra/priv/templates/sigra.install/organizations/router_injection.ex"
          )

        File.mkdir_p!(Path.dirname(template_link))
        File.ln_s!(template_source, template_link)
        :ok
      end,
      variant_builder: fn name, variant_path ->
        File.write!(Path.join(variant_path, "variant.txt"), Atom.to_string(name))
        {:ok, "stdout #{name}"}
      end
    )
  end

  defp unavailable_app_warning(app) do
    """
    You have configured application :#{app} in your configuration file,
    but the application is not available.

    This usually means one of:

      1. You have not added the application as a dependency in a mix.exs file.

      2. You are configuring an application that does not really exist.

    Please ensure :#{app} exists or remove the configuration.

    """
  end

  defp recovery_fixture!(root) do
    variant_path = Path.join(root, "variants/default_installed")
    shared_deps = Path.join(root, "shared_deps")
    build_path = Path.join(root, "build_template/dev")

    File.mkdir_p!(variant_path)
    File.mkdir_p!(build_path)
    File.mkdir_p!(Path.join(shared_deps, "telemetry_poller"))
    File.mkdir_p!(Path.join(shared_deps, "jason"))
    File.write!(Path.join(shared_deps, "telemetry_poller/source.erl"), "poller")
    File.write!(Path.join(shared_deps, "jason/source.ex"), "jason")

    sealed_dag = Path.join(shared_deps, "telemetry_poller/_build/prod/lib/.rebar3/base_graph")
    File.mkdir_p!(Path.dirname(sealed_dag))
    File.write!(sealed_dag, "sealed graph")

    {_, 0} = System.cmd("chmod", ["-R", "a-w", shared_deps], stderr_to_stdout: true)

    %{variant_path: variant_path, shared_deps: Path.expand(shared_deps)}
  end

  defp tree_snapshot(root) do
    root
    |> Path.join("**/*")
    |> Path.wildcard(match_dot: true)
    |> Enum.sort()
    |> Enum.map(fn path ->
      stat = File.lstat!(path)
      bytes = if stat.type == :regular, do: File.read!(path), else: nil
      {Path.relative_to(path, root), stat.type, Bitwise.band(stat.mode, 0o777), bytes}
    end)
  end

  defp read_runtime_config(checkout) do
    previous_partition = System.get_env("MIX_TEST_PARTITION")
    previous_port = System.get_env("PORT")
    System.put_env("MIX_TEST_PARTITION", checkout.partition)
    System.put_env("PORT", to_string(checkout.port))

    try do
      Config.Reader.read!(Path.join(checkout.path, "config/dev.exs"))
    after
      restore_env("MIX_TEST_PARTITION", previous_partition)
      restore_env("PORT", previous_port)
    end
  end

  defp restore_env(key, nil), do: System.delete_env(key)
  defp restore_env(key, value), do: System.put_env(key, value)
end
