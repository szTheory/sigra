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
    assert first.port != second.port
    assert first.build_path != second.build_path
    assert first.path != second.path
    assert first.copy_mode in [:reflink, :copy]

    File.write!(Path.join(first.path, "variant.txt"), "private mutation")

    assert File.read!(Path.join(second.path, "variant.txt")) == "default_installed"

    assert File.read!(Path.join(graph.variants.default_installed.path, "variant.txt")) ==
             "default_installed"

    refute InstallFixture.tree_has_shared_writable_state?(
             graph.variants.default_installed.path,
             first.path
           )
  end

  test "cache bytes are reused only for an exact compatibility fingerprint", %{root: root} do
    source = Path.join(root, "source-build")
    compatible = Path.join(root, "compatible-build")
    mismatch = Path.join(root, "mismatch-build")
    File.mkdir_p!(source)
    File.write!(Path.join(source, "beam"), "compiled")

    fingerprint = InstallFixture.compatibility_fingerprint(lock: "lock", compiler: "compiler")

    assert {:ok, mode, elapsed_ms} =
             InstallFixture.seed_compatible_tree!(source, compatible, fingerprint, fingerprint)

    assert mode in [:reflink, :copy]
    assert elapsed_ms >= 1
    assert File.read!(Path.join(compatible, "beam")) == "compiled"

    assert :incompatible =
             InstallFixture.seed_compatible_tree!(source, mismatch, fingerprint, "different")

    refute File.exists?(mismatch)
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
  end

  test "cleanup rejects arbitrary roots and removes only the validated graph root", %{root: root} do
    graph = prepare_test_graph!(root)
    outside = Path.join(root, "..") |> Path.expand()

    assert_raise ArgumentError, fn -> InstallFixture.cleanup_graph!(outside) end
    assert :ok = InstallFixture.cleanup_graph!(graph)
    refute File.exists?(root)
  end

  test "diagnostics require exact positive phases bounded by raw install duration", %{root: root} do
    graph = prepare_test_graph!(root)
    receipt = InstallFixture.diagnostic_receipt(graph, 100)

    assert :ok = InstallFixture.validate_diagnostics!(receipt)

    assert Map.keys(receipt.phases) |> Enum.sort() ==
             ~w(baseline_compile checkout_copy deps_get installer phx_new receiver_compile_runtime)a

    assert Enum.all?(receipt.phases, fn {_phase, duration} -> duration > 0 end)
    assert Enum.sum(Map.values(receipt.phases)) <= receipt.raw_install_duration_ms
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
      %{receipt | raw_install_duration_ms: 1}
      |> InstallFixture.validate_diagnostics!()
    end
  end

  test "scenario runner fixes concurrency at two and cancels on first failure" do
    {:ok, counter} = Agent.start_link(fn -> %{active: 0, maximum: 0, completed: []} end)
    caller = self()

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

      result =
        case scenario.id do
          :fail -> {:error, 23}
          _ -> Process.sleep(5_000)
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

  defp prepare_test_graph!(root) do
    InstallFixture.prepare_graph!(
      root: root,
      fingerprint: "test-fingerprint",
      base_builder: fn base_path ->
        File.mkdir_p!(base_path)
        File.write!(Path.join(base_path, "base.txt"), "base")
        :ok
      end,
      variant_builder: fn name, variant_path ->
        File.write!(Path.join(variant_path, "variant.txt"), Atom.to_string(name))
        {:ok, "stdout #{name}"}
      end
    )
  end
end
