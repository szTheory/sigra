defmodule Sigra.Planning.Phase2351LibraryEconomicsContractTest do
  use ExUnit.Case, async: false

  @receipt_path "/tmp/sigra-library-economics.json"
  @phase_235_dir ".planning/phases/235-terminal-ratification-measured-not-read"
  @fast_verifier "scripts/ci/verify-fast-01-source-complete-attestation-offline.sh"
  @terminal_verifier "scripts/ci/verify-terminal-ratification-attestation-offline.sh"
  @blocked_summary ".planning/phases/235.1-close-v1-47-library-economics-integration-gaps-test-01-test/235.1-04-SUMMARY.md"
  @context_path ".planning/phases/235.1-close-v1-47-library-economics-integration-gaps-test-01-test/235.1-CONTEXT.md"
  @plan_16_summary ".planning/phases/235.1-close-v1-47-library-economics-integration-gaps-test-01-test/235.1-16-SUMMARY.md"
  @calibration_path ".planning/phases/235.1-close-v1-47-library-economics-integration-gaps-test-01-test/235.1-PARTITION-CALIBRATION.json"

  test "routing evidence is independently admitted and keeps fixed-bound history negative" do
    verifier = File.read!("scripts/ci/verify-library-routing-evidence.sh")
    adverse = File.read!("scripts/ci/verify-library-routing-evidence.test.sh")

    assert verifier =~ "sigra.library-partitions-evidence/v1"
    assert verifier =~ "sigra.library-install-golden-evidence/v1"
    assert verifier =~ "max * 1000 <= min * 2000"
    assert verifier =~ "install_not_dominant"
    assert verifier =~ "ordinary-vs-scaffold comparable"
    assert adverse =~ "PR attempt"
    assert adverse =~ "same implementation SHA"
    assert adverse =~ "failed-history run"
    assert adverse =~ "history substitution"
    assert adverse =~ "deterministic-failure advancement"
    assert adverse =~ "candidate tree drift"
    assert adverse =~ "over budget"
  end

  setup do
    File.rm(@receipt_path)
    on_exit(fn -> File.rm(@receipt_path) end)
    :ok
  end

  test "production verifier accepts exact evidence and both equality boundaries" do
    assert_receipt_accepted!(valid_receipt(ordinary_ms: 2_000, install_ms: 1_000))
    assert_receipt_accepted!(valid_receipt(ordinary_ms: 1_000, install_ms: 1_000))
  end

  test "production verifier rejects every truth-bearing mutation and edge shape" do
    receipt = valid_receipt()

    mutations = [
      {Map.delete(receipt, "schema_version"), "top-level keys"},
      {Map.put(receipt, "unexpected", true), "top-level keys"},
      {Map.put(receipt, "schema_version", "sigra.library-economics/v0"), "schema_version"},
      {Map.put(receipt, "timing_receipt_path", "/tmp/forged.json"), "timing_receipt_path"},
      {Map.put(receipt, "install_leg_ran", false), "install_leg_ran"},
      {Map.put(receipt, "install_leg_ran", "true"), "install_leg_ran"},
      {Map.put(receipt, "classes", %{}), "exactly two fixed classes"},
      {put_in(receipt, ["classes", "install_scaffold"], nil), "install_scaffold keys"},
      {update_in(receipt, ["classes"], &Map.delete(&1, "install_scaffold")),
       "exactly two fixed classes"},
      {put_in(receipt, ["classes", "forged"], receipt["classes"]["ordinary"]),
       "exactly two fixed classes"},
      {put_in(receipt, ["classes", "ordinary", "duration_ms"], 0), "raw integer timing"},
      {put_in(receipt, ["classes", "ordinary", "duration_ms"], 1_001), "arithmetic predicate"},
      {put_in(receipt, ["classes", "ordinary", "start_ms"], -1), "raw integer timing"},
      {put_in(receipt, ["classes", "ordinary", "end_ms"], 1_000.5), "raw integer timing"},
      {put_in(receipt, ["classes", "ordinary", "conclusion"], "failure"), "conclusion predicate"},
      {put_in(receipt, ["classes", "ordinary", "exit_status"], 1), "exit-status predicate"},
      {put_in(receipt, ["classes", "ordinary", "verified"], true), "ordinary keys"},
      {put_in(receipt, ["classes", "install_scaffold", "duration_ms"], 2_001),
       "arithmetic predicate"},
      {valid_receipt(ordinary_ms: 1_000, install_ms: 2_001), "comparability predicate"},
      {valid_receipt(ordinary_ms: 1_000, install_ms: 1_001), "non-dominance predicate"}
    ]

    Enum.each(mutations, fn {mutation, diagnostic} ->
      assert_receipt_rejected!(mutation, diagnostic)
    end)

    assert_missing_receipt_rejected!()
    assert_raw_receipt_rejected!("")
    assert_raw_receipt_rejected!("null")

    assert_raw_receipt_rejected!(
      ~s({"schema_version":"sigra.library-economics/v1","schema_version":"sigra.library-economics/v1"})
    )
  end

  test "current contributor and workflow topology has one measured owner and two fail-closed receipts" do
    assert_current_topology!()
  end

  test "non-PR install authority is event-complete, fail-closed, and empirically justified" do
    workflow = File.read!(".github/workflows/ci.yml")
    non_pr = job_body(workflow, "library_install_golden_non_pr")
    context = File.read!(@context_path)

    assert non_pr =~
             "if: ${{ github.event_name == 'schedule' || github.event_name == 'workflow_dispatch' }}"

    refute non_pr =~ "pull_request"
    refute non_pr =~ "push"
    refute non_pr =~ "continue-on-error"
    refute non_pr =~ "force_"
    assert non_pr =~ "mix deps.get --check-locked"
    assert non_pr =~ "mix archive.install --force hex phx_new 1.8.8"
    assert non_pr =~ "version-file: .tool-versions"
    assert non_pr =~ "MIX_ENV=test bash scripts/ci/install-golden.sh"
    assert non_pr =~ "if: always()"
    assert non_pr =~ "bash scripts/ci/verify-library-install-golden.sh"
    assert length(Regex.scan(~r/if-no-files-found: error/, non_pr)) == 2
    assert length(Regex.scan(~r/retention-days: 7/, non_pr)) == 2

    assert length(
             Regex.scan(
               ~r/actions\/upload-artifact@043fb46d1a93c77aae656e7c1c64a875d1fc6a0a/,
               non_pr
             )
           ) == 2

    for evidence <- ["library-install-golden", "library-install-diagnostics"] do
      assert non_pr =~ "#{evidence}-${{ github.run_id }}-${{ github.run_attempt }}"
    end

    ci_gate = job_body(workflow, "ci-gate")
    aggregate = job_body(workflow, "library_tests")
    refute ci_gate =~ "library_install_golden_non_pr"
    refute aggregate =~ "library_install_golden_non_pr"

    for fact <- ["28,671ms", "79,614ms", "57,389ms", "negative diagnostics", "non-PR lane"] do
      assert context =~ fact
    end
  end

  test "same ordinary run consumes the formatter and preserves deterministic unique timing evidence" do
    assert_formatter_contract!()
  end

  test "formatter unit coverage cannot own either ordinary timing receipt" do
    source = File.read!("test/support/ci/ex_unit_timing_formatter_test.exs")
    runner = File.read!("scripts/ci/library-partitions.sh")

    assert source =~ ~s(path = "/tmp/sigra-library-scaffold-timings.json")
    refute source =~ "/tmp/sigra-library-1-timings.json"
    refute source =~ "/tmp/sigra-library-2-timings.json"
    assert runner =~ "partition_1_digest"
    assert runner =~ "partition 2 changed partition 1 timing receipt"
  end

  test "Plan 17 repairs only the global Oban test owners and runs three fresh validations" do
    registrants =
      "test"
      |> Path.join("**/*_test.exs")
      |> Path.wildcard()
      |> Enum.filter(&registers_global_oban?/1)
      |> Enum.sort()

    assert registrants == [
             "test/sigra/account/deletion_test.exs",
             "test/sigra/delivery_test.exs"
           ]

    Enum.each(registrants, fn path ->
      source = File.read!(path)
      assert oban_owner_contract?(source), "unsafe dummy Oban ownership: #{path}"

      mutations = [
        String.replace(source, "async: false", "async: true", global: false),
        String.replace(source, "ref = Process.monitor(dummy)", "ref = make_ref()", global: false),
        String.replace(source, "if Process.whereis(Oban) == dummy", "if true", global: false),
        String.replace(source, "Process.exit(dummy, :kill)", ":ok", global: false),
        String.replace(source, "{:DOWN, ^ref, :process, ^dummy, reason}", "{:DOWN, _, _, _, reason}",
          global: false
        ),
        String.replace(source, "reason in [:killed, :noproc]", "reason == :killed", global: false),
        String.replace(source, "1_000 -> raise", "5_000 -> raise", global: false),
        String.replace(
          source,
          "on_exit(fn -> cleanup_dummy_oban(dummy) end)\n\n    try do\n      Process.register(dummy, Oban)",
          "Process.register(dummy, Oban)\n    on_exit(fn -> cleanup_dummy_oban(dummy) end)\n\n    try do",
          global: false
        ),
        String.replace(
          source,
          "exception in ArgumentError ->\n        cleanup_dummy_oban(dummy)",
          "exception in ArgumentError ->\n        :ok",
          global: false
        )
      ]

      Enum.each(mutations, &refute(oban_owner_contract?(&1)))
    end)

    delivery = File.read!("test/sigra/delivery_test.exs")
    assert delivery =~ "failed dummy acquisition kills only the dummy"
    assert delivery =~ "cleanup does not unregister or kill a replacement Oban owner"
    assert length(Regex.scan(~r/Task\.async\(fn -> cleanup_dummy_oban\(dummy\) end\)/, delivery)) == 2

    calibration = File.read!(@calibration_path)
    assert byte_size(calibration) == 2_922_739
    assert sha256(calibration) == "975612d7f3cbfda75fb6857791ebfd9bcadd852451b86a6b917871b3ba092eeb"
    refute sha256(calibration <> "\n") == "975612d7f3cbfda75fb6857791ebfd9bcadd852451b86a6b917871b3ba092eeb"

    immutable_paths = %{
      "test/support/ci/library_test_partitions.exs" =>
        "91646f072512d32e603b850ac44caa14825543b67188c5221eea6ccaf7738c97",
      "test/support/ci/library_test_partitions_test.exs" =>
        "3550a8bd2fa9f408c8477928f1e82eac5d418d6d50865d74d4173493bbc75ae5",
      "scripts/ci/library-partitions.sh" =>
        "99c0114090412c297524c1e4b7e0905f2439211244c508504a59fdaf4d5a5202",
      "scripts/ci/verify-library-partitions.sh" =>
        "449d239630013c0f25837763c1dfe494442f32ad8d8fe6c4275d4890b5219a54",
      ".github/workflows/ci.yml" =>
        "ae1e2b519a433720aeb8f7a598d3869e3a5d73c871092f4e6df60456ee413682"
    }

    Enum.each(immutable_paths, fn {path, expected} ->
      bytes = File.read!(path)
      assert sha256(bytes) == expected, "immutable drift: #{path}"
      refute sha256(bytes <> "\n") == expected
    end)

    Code.require_file("test/support/ci/library_test_partitions.exs")
    partitions = apply(Sigra.CI.LibraryTestPartitions, :build_partitions!, [])
    assert length(partitions[1].paths) == 97
    assert length(partitions[2].paths) == 128
    assert partitions[1].total_us == 54_838_062
    assert partitions[2].total_us == 54_838_062
    assert "test/sigra/account/deletion_test.exs" in partitions[2].paths
    assert "test/sigra/delivery_test.exs" in partitions[2].paths

    missing_path = update_in(partitions, [2, :paths], &List.delete(&1, "test/sigra/delivery_test.exs"))

    assert_raise ArgumentError, fn ->
      apply(Sigra.CI.LibraryTestPartitions, :validate_current_universe!, [missing_path])
    end

    {production_diff, production_status} =
      System.cmd("git", ["diff", "--name-only", "fd97522d", "--", "lib"])

    assert production_status == 0
    assert production_diff == ""

    plan_16 = File.read!(@plan_16_summary)
    assert plan_16 =~ "37,517ms"
    assert plan_16 =~ "26,409ms"
    assert plan_16 =~ "Fresh post-calibration validation pairs completed: 0 of 3"

    {pinned_plan_16, 0} = System.cmd("git", ["show", "84550d73:#{@plan_16_summary}"])
    assert pinned_plan_16 == plan_16

    integration = File.read!("scripts/ci/library-partitions.test.sh")
    assert length(Regex.scan(~r/for validation in 1 2 3/, integration)) == 1
    assert integration =~ "validation-${validation}"
    assert integration =~ "verify-library-partitions.sh"
    assert length(Regex.scan(~r/fresh calibrated validation/, integration)) == 1
    refute integration =~ "for validation in $(seq"
    refute integration =~ ~r/retry|average|recalibrat|retun/i
    refute three_validation_contract?(String.replace(integration, "1 2 3", "1 2", global: false))
    refute three_validation_contract?(
             String.replace(integration, "MIX_ENV=test bash \"$RUNNER\"", "MIX_ENV=test :",
               global: false
             )
           )

    assert three_validation_contract?(integration)
  end

  test "prepared fixture source pins six variants, private mutations, and two-worker failure semantics" do
    fixture = File.read!("test/support/install_fixture.ex")
    runner = File.read!("scripts/ci/install-golden.sh")

    for variant <-
          ~w(default_installed passkeys_standard passkeys_nonstandard_app_js no_passkeys no_org_no_passkeys no_org_installed) do
      assert fixture =~ ":#{variant}"
    end

    assert length(install_golden_paths(runner)) == 6
    assert install_golden_paths(runner) == live_scaffold_paths()
    assert fixture =~ "when map_size(active) < 2"
    assert fixture =~ "Process.exit(pid, :kill)"
    assert fixture =~ "mark_scenario_failed!(scenario)"
    assert fixture =~ "{:error, %{status: status, failed_path: Map.get(scenario, :path)}}"
    assert fixture =~ "MIX_TEST_PARTITION"
    assert fixture =~ "MIX_BUILD_PATH"
  end

  test "receiver modules overlap behind one graph-global two-worker scheduler" do
    receiver_sources =
      [
        "test/upgrade_test.exs",
        "test/sigra/install/golden_diff_test.exs",
        "test/sigra/install/features/passkeys_js_test.exs",
        "test/sigra/install/generator_passkeys_opt_out_test.exs",
        "test/sigra/install/idempotency_test.exs",
        "test/sigra/install/vault_promotion_test.exs"
      ]
      |> Map.new(&{&1, File.read!(&1)})

    assert map_size(receiver_sources) == 6

    Enum.each(receiver_sources, fn {path, source} ->
      assert source =~ "use ExUnit.Case, async: true", "#{path} must opt into safe overlap"
      refute source =~ "use ExUnit.Case, async: false"
    end)

    fixture = File.read!("test/support/install_fixture.ex")

    assert fixture =~ "def with_worker(fun)"
    assert fixture =~ "map_size(state.active) < 2"
    assert fixture =~ "Process.monitor(pid)"
    assert fixture =~ "Process.get({__MODULE__, :worker_lease}"
    assert fixture =~ "WorkerPool.release(@worker_pool)"
    assert fixture =~ "with_worker(fn -> do_checkout!(graph, name, scenario) end)"
    assert fixture =~ "case with_worker(fn -> runner.(scenario) end)"
    assert length(Regex.scan(~r/with_worker\(fn/, fixture)) == 5

    golden = Map.fetch!(receiver_sources, "test/sigra/install/golden_diff_test.exs")
    assert golden =~ "InstallFixture.variant!(:default_installed)"
    refute golden =~ "InstallFixture.checkout!"
  end

  test "all remaining prepared receivers retain real behavior on exact named states" do
    passkeys = File.read!("test/sigra/install/features/passkeys_js_test.exs")
    opt_out = File.read!("test/sigra/install/generator_passkeys_opt_out_test.exs")
    vault = File.read!("test/sigra/install/vault_promotion_test.exs")

    assert passkeys =~ "InstallFixture.variant!(:passkeys_standard)"
    assert passkeys =~ "InstallFixture.checkout!(:passkeys_standard, \"passkeys-rerun\")"
    assert passkeys =~ "InstallFixture.variant!(:passkeys_nonstandard_app_js)"
    assert passkeys =~ "passkey_browser.js"
    assert passkeys =~ "count_occurrences(app_js, @passkey_start_marker) == 1"
    refute passkeys =~ "InstallFixture.setup_tmp_app_without_install"

    assert opt_out =~ "variant: :no_passkeys"
    assert opt_out =~ "variant: :no_org_no_passkeys"
    assert opt_out =~ "InstallFixture.run_scenarios(scenarios"
    assert opt_out =~ "prepare_checkouts!()"
    assert opt_out =~ "InstallFixture.checkout!(variant, scenario)"
    assert opt_out =~ "max_concurrency: 2"
    assert opt_out =~ "timeout: 120_000"
    assert opt_out =~ "on_timeout: :kill_task"
    assert opt_out =~ "\"compile\""
    assert opt_out =~ "\"--warnings-as-errors\""
    refute opt_out =~ "InstallFixture.setup_tmp_app_without_install"

    assert vault =~ "InstallFixture.checkout!(:passkeys_standard, \"vault-promotion\")"
    assert vault =~ "compile\", \"--warnings-as-errors"
    assert vault =~ "use Cloak.Vault"
    assert vault =~ "use Cloak.Ecto.Binary"
  end

  test "ordinary-vs-scaffold evidence remains failed history and is explicitly superseded" do
    harness = File.read!("scripts/ci/library-economics.sh")
    fixture = File.read!("test/support/install_fixture.ex")
    blocked = File.read!(@blocked_summary)
    context = File.read!(@context_path)

    assert byte_index!(harness, "install_start=") <
             byte_index!(harness, "rm -f \"$INSTALL_DIAGNOSTIC_PATH\"")

    assert byte_index!(harness, "rm -f \"$INSTALL_DIAGNOSTIC_PATH\"") <
             byte_index!(harness, "mix ci.install_golden")

    assert byte_index!(harness, "mix ci.install_golden") <
             last_byte_index!(harness, "install_end=")

    assert fixture =~ "sum(phases) <= raw_duration" or
             fixture =~ "Enum.sum(durations) <= raw_duration"

    assert blocked =~ "34395477605"
    assert blocked =~ "status: blocked"
    assert blocked =~ "**Passing evidence:** Intentionally absent"
    refute blocked =~ "status: complete"
    assert context =~ "D-02 superseded"
    assert context =~ "D-06 superseded"
    assert context =~ "negative diagnostics, not a"
    assert context =~ "passing claim"
  end

  test "receiver optimization keeps every behavioral proof executable" do
    sources = %{
      golden: File.read!("test/sigra/install/golden_diff_test.exs"),
      idempotency: File.read!("test/sigra/install/idempotency_test.exs"),
      upgrade: File.read!("test/upgrade_test.exs"),
      passkeys: File.read!("test/sigra/install/features/passkeys_js_test.exs"),
      opt_out: File.read!("test/sigra/install/generator_passkeys_opt_out_test.exs"),
      vault: File.read!("test/sigra/install/vault_promotion_test.exs")
    }

    assert_contains_all!(sources.golden, [
      "InstallFixture.normalize_tree",
      "assert_tree_equal(actual, expected)",
      "variant.stdout",
      "STDOUT diverges from fixture"
    ])

    assert_contains_all!(sources.idempotency, [
      "hash_snapshot(app_dir)",
      "collect_mtimes(app_dir)",
      "missing_or_changed == []",
      "new_files == []",
      "changed_mtimes == []",
      "already exists",
      "already injected"
    ])

    assert_contains_all!(sources.upgrade, [
      "ecto.migrate",
      "compile",
      "assert_login_redirects_to_organizations!",
      "organizations_table_exists?",
      "personal_org_count",
      "expected re-run to be a no-op",
      "status_codes_seen",
      "MIX_DEPS_PATH",
      "run_upgrade_session!(checkout, seeded_count:",
      ~S|task("ecto.create", ["--quiet"])|,
      ~S|task("ecto.migrate", ["--quiet"])|,
      ~S|task("sigra.upgrade", flags ++ ["--allow-dirty", "--yes"])|,
      ~S|task("compile", [])|,
      "Mix.Task.reenable(name)",
      ~S<Ecto.Migrator.run(@repo, "priv/repo/data_migrations">,
      ~S<InstallFixture.run_mix(app_dir, ["run", "--no-start", "--no-compile", "-e", script])>,
      "SIGRA_UPGRADE_RESULT:",
      "prepare_checkouts!([",
      "max_concurrency: 2",
      "timeout: 120_000",
      "on_timeout: :kill_task"
    ])

    assert length(Regex.scan(~r/InstallFixture\.run_mix\(/, sources.upgrade)) == 1

    assert_contains_all!(sources.passkeys, [
      "@passkey_start_marker",
      "@passkey_end_marker",
      "@passkey_import",
      "@passkey_hooks_line",
      "startRegistration",
      "startAuthentication",
      "run_browser_helper_node!"
    ])

    assert_contains_all!(sources.opt_out, [
      "@forbidden_strings",
      "\"compile\"",
      "\"--warnings-as-errors\"",
      "migration_present?",
      "tree_contains?"
    ])

    assert_contains_all!(sources.vault, [
      "use Cloak.Vault",
      "use Cloak.Ecto.Binary",
      "Vault, []",
      "compile\", \"--warnings-as-errors"
    ])
  end

  test "fixed runner and verifier expose no command, environment, or threshold bypass" do
    runner = File.read!("scripts/ci/install-golden.sh")
    verifier = File.read!("scripts/ci/verify-library-economics.sh")
    install_verifier = File.read!("scripts/ci/verify-library-install-golden.sh")

    assert runner =~ "export SIGRA_INSTALL_GOLDEN_PREPARED=1"
    assert runner =~ "mix test \"${receiver_paths[@]}\""
    refute runner =~ "eval "
    refute runner =~ "${SIGRA_INSTALL_GOLDEN"
    assert verifier =~ "maximum * 1000 <= minimum * 2000"
    assert verifier =~ "install <= ordinary"
    refute verifier =~ "THRESHOLD"
    refute verifier =~ "ALLOW_"
    assert install_verifier =~ "live scaffold ownership"
    assert install_verifier =~ ".worker_ceiling != 2"
    assert install_verifier =~ ".prepared_fixture != true"
    refute install_verifier =~ "THRESHOLD"
    refute install_verifier =~ "ALLOW_"
  end

  test "install ownership verifier uses portable tracked exact-tag discovery" do
    verifier = File.read!("scripts/ci/verify-library-install-golden.sh")
    adverse = File.read!("scripts/ci/verify-library-install-golden.test.sh")

    refute verifier =~ ~r/^\s*rg\s/m
    assert verifier =~ "find test -type f -name '*_test.exs'"
    assert verifier =~ "grep"
    assert verifier =~ "git ls-files --error-unmatch"
    assert verifier =~ "LC_ALL=C sort"
    assert adverse =~ "hermetic no-rg tool path"
    assert adverse =~ "unsafe delimiter-bearing ownership path rejected"
    assert adverse =~ "@moduletag :scaffold_extra"
    assert adverse =~ "# @moduletag :scaffold"
  end

  test "protected FAST-01 and GATE-05 verifiers remain independently green" do
    assert_protected_verifiers!()
  end

  test "protected digests, semantic tuples, and negative history remain immutable" do
    assert_protected_evidence!()
  end

  defp valid_receipt(opts \\ []) do
    ordinary_ms = Keyword.get(opts, :ordinary_ms, 1_000)
    install_ms = Keyword.get(opts, :install_ms, 500)

    %{
      "schema_version" => "sigra.library-economics/v1",
      "timing_receipt_path" => "/tmp/sigra-library-1-timings.json",
      "install_leg_ran" => true,
      "classes" => %{
        "ordinary" => %{
          "start_ms" => 1_000,
          "end_ms" => 1_000 + ordinary_ms,
          "duration_ms" => ordinary_ms,
          "conclusion" => "success",
          "exit_status" => 0
        },
        "install_scaffold" => %{
          "start_ms" => 10_000,
          "end_ms" => 10_000 + install_ms,
          "duration_ms" => install_ms,
          "conclusion" => "success",
          "exit_status" => 0
        }
      }
    }
  end

  defp assert_receipt_accepted!(receipt) do
    File.write!(@receipt_path, Jason.encode!(receipt))

    assert {"verify-library-economics: PASS\n", 0} =
             System.cmd("bash", ["scripts/ci/verify-library-economics.sh"],
               stderr_to_stdout: true
             )
  end

  defp assert_receipt_rejected!(receipt, diagnostic) do
    File.write!(@receipt_path, Jason.encode!(receipt))

    {output, status} =
      System.cmd("bash", ["scripts/ci/verify-library-economics.sh"], stderr_to_stdout: true)

    assert status != 0
    assert output =~ diagnostic
    refute output =~ "verify-library-economics: PASS"
  end

  defp assert_raw_receipt_rejected!(raw) do
    File.write!(@receipt_path, raw)

    {output, status} =
      System.cmd("bash", ["scripts/ci/verify-library-economics.sh"], stderr_to_stdout: true)

    assert status != 0
    assert output =~ "verify-library-economics: FAIL"
    refute output =~ "verify-library-economics: PASS"
  end

  defp assert_missing_receipt_rejected! do
    File.rm(@receipt_path)

    {output, status} =
      System.cmd("bash", ["scripts/ci/verify-library-economics.sh"], stderr_to_stdout: true)

    assert status != 0
    assert output =~ "receipt must be a regular non-symlink file"
  end

  defp assert_current_topology! do
    workflow = File.read!(".github/workflows/ci.yml")
    mix_exs = File.read!("mix.exs")
    harness = File.read!("scripts/ci/library-partitions.sh")
    shard = job_body(workflow, "library_tests_shard")
    aggregate = job_body(workflow, "library_tests")
    non_pr = job_body(workflow, "library_install_golden_non_pr")

    assert library_job_ids(workflow) == [
             "library_tests_shard",
             "library_tests",
             "library_tests_dep_off"
           ]

    assert length(Regex.scan(~r/MIX_ENV=test mix ci/, shard)) == 1

    assert ci_legs(mix_exs) |> Enum.count(&(&1 == "cmd bash scripts/ci/library-partitions.sh")) ==
             1

    assert harness =~ "run_partition 1"
    assert harness =~ "run_partition 2"
    assert length(Regex.scan(~r/mix test /, harness)) == 1
    refute harness =~ "ci.install_golden"
    refute shard =~ "matrix:"

    assert length(Regex.scan(~r/name: Upload library partition(?: receipt| [12] timings)/, shard)) ==
             3

    assert length(Regex.scan(~r/if-no-files-found: error/, shard)) == 3
    assert length(Regex.scan(~r/if: always\(\)/, shard)) == 4
    refute shard =~ "if-no-files-found: ignore"
    refute shard =~ "phx_new"
    assert aggregate =~ "name: Library tests"
    assert aggregate =~ "needs: [library_tests_shard]"
    assert aggregate =~ "if: always()"
    assert aggregate =~ ~s("$SHARD" != "success")
    refute shard =~ "install-golden.sh"
    refute shard =~ "phx_new"
    assert non_pr =~ "MIX_ENV=test bash scripts/ci/install-golden.sh"

    install_runner = File.read!("scripts/ci/install-golden.sh")
    assert install_alias_commands(mix_exs) == ["cmd bash scripts/ci/install-golden.sh"]
    receiver_paths = install_golden_paths(install_runner)
    assert length(receiver_paths) == 6
    assert length(receiver_paths) == MapSet.size(MapSet.new(receiver_paths))
    assert receiver_paths == live_scaffold_paths()
  end

  defp assert_formatter_contract! do
    harness = File.read!("scripts/ci/library-partitions.sh")
    workflow = File.read!(".github/workflows/ci.yml")
    shard = job_body(workflow, "library_tests_shard")
    formatter = File.read!("test/support/ci/ex_unit_timing_formatter.ex")

    assert harness =~ ~s(MIX_TEST_PARTITION="$id")
    assert harness =~ ~s(SIGRA_EXUNIT_TIMING_PATH="$timing")
    assert harness =~ "--formatter ExUnit.CLIFormatter"
    assert harness =~ "--formatter Sigra.CI.ExUnitTimingFormatter"
    refute harness =~ "--slowest"
    refute harness =~ "--trace"

    assert formatter =~ "handle_cast({:test_finished, %ExUnit.Test{} = test}"
    assert formatter =~ "Enum.sort_by(&{-&1.time_us, &1.file, &1.module, &1.name})"
    assert formatter =~ "is_integer(time) and time >= 0"
    assert formatter =~ "do: raise(ArgumentError, \"unknown completed test state:"

    assert shard =~ "verify-library-partitions.sh"

    assert File.read!("scripts/ci/verify-library-partitions.sh") =~
             ".tests == (.tests | sort_by([-(.time_us),.file,.module,.name]))"
  end

  defp assert_protected_verifiers! do
    assert {fast_output, 0} = run_offline_verifier(@fast_verifier)
    assert fast_output == "source_complete_offline_attestation_verified\n"

    assert {terminal_output, 0} = run_offline_verifier(@terminal_verifier)

    assert terminal_output =~ "offline_attestation_verified"
  end

  # GitHub-hosted Linux runners disable unprivileged network namespaces. The
  # protected verifiers therefore use their existing passwordless-sudo fallback;
  # invoking the whole verifier with the same privilege keeps gh's state files
  # removable by its EXIT trap. Darwin uses sandbox-exec and needs no elevation.
  defp run_offline_verifier(path) do
    case :os.type() do
      {:unix, :linux} -> System.cmd("sudo", ["-n", "bash", path], stderr_to_stdout: true)
      _ -> System.cmd("bash", [path], stderr_to_stdout: true)
    end
  end

  defp assert_protected_evidence! do
    pins = %{
      Path.join(@phase_235_dir, "235-PROTECTED-RECEIPTS.json") =>
        "022a03a03a440643871d19afe12cc7c8220b23e7d709d00e072d240e065b8244",
      Path.join(@phase_235_dir, "235-TERMINAL-RATIFICATION.json") =>
        "c667836535ae1141fe4419b6675777a6aa865dd99da528c33caa5ac16794a27e",
      Path.join(@phase_235_dir, "235-PROTECTED-RECEIPTS.attestation.jsonl") =>
        "af49fd36b603adbdfdeb8698141cea2e8749c1edc3f9b88764e3465b6f84215f",
      Path.join(@phase_235_dir, "235-TRUSTED-ROOT.jsonl") =>
        "65ca537f6ed8a47fd0e560c421baa1f6c1efb8b25fc200d8c5c02c0e92eb2b9c",
      @terminal_verifier => "6c0805e0386186f017215ea7bf10bf450c9aafb68ef6742afa2f9e75b0463367",
      Path.join(@phase_235_dir, "235-FAST-01-SOURCE-COMPLETE-REMEASUREMENT.json") =>
        "a5f4f6d5335755fcac14e9de8827f47f2b04ad3a143df4b6f283ebfc20853594",
      Path.join(
        @phase_235_dir,
        "235-FAST-01-SOURCE-COMPLETE-REMEASUREMENT-TRUSTED-ROOT.jsonl"
      ) => "65ca537f6ed8a47fd0e560c421baa1f6c1efb8b25fc200d8c5c02c0e92eb2b9c"
    }

    Enum.each(pins, fn {path, expected} ->
      actual = :crypto.hash(:sha256, File.read!(path)) |> Base.encode16(case: :lower)
      assert actual == expected, "immutable digest drift: #{path}"
    end)

    source_complete =
      @phase_235_dir
      |> Path.join("235-FAST-01-SOURCE-COMPLETE-REMEASUREMENT.json")
      |> File.read!()
      |> Jason.decode!()

    assert source_complete["eligible_pr_run_count"] == 52
    assert source_complete["statistics"]["p50_seconds"] == 469
    assert source_complete["verdict"] == "pass"
    assert source_complete["status"] == "measured"
    assert source_complete["binding_poles"] == nil

    terminal =
      @phase_235_dir
      |> Path.join("235-TERMINAL-RATIFICATION.json")
      |> File.read!()
      |> Jason.decode!()

    assert length(get_in(terminal, ["ownership", "rows"])) == 93

    assert get_in(terminal, ["measurements", "push", "statistics"]) == %{
             "fail" => 1,
             "max_seconds" => 1439,
             "mean_seconds" => 1430,
             "n" => 2,
             "p50_seconds" => 1439,
             "pass" => 1,
             "trigger" => "push"
           }

    assert get_in(terminal, ["measurements", "schedule", "statistics"]) == %{
             "fail" => 2,
             "max_seconds" => 1546,
             "mean_seconds" => 1436.5,
             "n" => 2,
             "p50_seconds" => 1546,
             "pass" => 0,
             "trigger" => "schedule"
           }

    history = File.read!(".planning/todos/pending/2026-08-02-fast-01-terminal-p50-miss.md")

    for immutable_fact <- ["772", "724", "466", "rejected derived-only"] do
      assert history =~ immutable_fact, "missing immutable FAST-01 history: #{immutable_fact}"
    end

    closeout = File.read!(".planning/REQUIREMENTS.md")
    assert closeout =~ "n=52"
    assert closeout =~ "p50 469 seconds"
    assert closeout =~ "34350618761"
    assert closeout =~ "protected run `30782184713`; 93-row execution proof"
  end

  defp ci_legs(mix_exs) do
    mix_exs
    |> alias_body("ci")
    |> quoted_values()
  end

  defp install_alias_commands(mix_exs) do
    mix_exs |> alias_body("ci.install_golden") |> quoted_values()
  end

  defp install_golden_paths(runner) do
    [_, body] = Regex.run(~r/receiver_paths=\(\n(?<body>.*?)\n\)/s, runner)

    body
    |> String.split("\n", trim: true)
    |> Enum.map(&String.trim/1)
    |> Enum.filter(&String.ends_with?(&1, "_test.exs"))
    |> Enum.sort()
  end

  defp byte_index!(source, needle), do: :binary.match(source, needle) |> elem(0)

  defp sha256(bytes), do: :crypto.hash(:sha256, bytes) |> Base.encode16(case: :lower)

  defp oban_owner_contract?(source) do
    [before_cleanup, cleanup_and_after] =
      String.split(source, "defp cleanup_dummy_oban(dummy) do", parts: 2)

    source =~ "use ExUnit.Case, async: false" and
      not (source =~ "use ExUnit.Case, async: true") and
      byte_index!(source, "on_exit(fn -> cleanup_dummy_oban(dummy) end)") <
        byte_index!(source, "Process.register(dummy, Oban)") and
      not (before_cleanup =~ "Process.monitor(dummy)") and
      cleanup_and_after =~ "ref = Process.monitor(dummy)" and
      cleanup_and_after =~ "if Process.whereis(Oban) == dummy" and
      cleanup_and_after =~ "if Process.alive?(dummy)" and
      cleanup_and_after =~ "Process.exit(dummy, :kill)" and
      cleanup_and_after =~ "{:DOWN, ^ref, :process, ^dummy, reason}" and
      cleanup_and_after =~ "reason in [:killed, :noproc]" and
      cleanup_and_after =~ "1_000 -> raise" and
      before_cleanup =~ "exception in ArgumentError ->\n        cleanup_dummy_oban(dummy)"
  end

  defp three_validation_contract?(source) do
    case String.split(source, "for validation in 1 2 3; do", parts: 2) do
      [_before, validation_loop] ->
        validation_loop =~ "MIX_ENV=test bash \"$RUNNER\"" and
          validation_loop =~ "verify-library-partitions.sh" and
          validation_loop =~ "validation-${validation}" and
          not (source =~ ~r/retry|average|recalibrat|retun/i)

      _other ->
        false
    end
  end

  defp registers_global_oban?(path) do
    case path |> File.read!() |> Code.string_to_quoted() do
      {:ok, quoted} ->
        {_quoted, found?} =
          Macro.prewalk(quoted, false, fn
            {{:., _, [{:__aliases__, _, [:Process]}, :register]}, _,
             [_, {:__aliases__, _, [:Oban]}]} = node,
            _found? ->
              {node, true}

            node, found? ->
              {node, found?}
          end)

        found?

      {:error, _reason} ->
        false
    end
  end

  defp last_byte_index!(source, needle),
    do: source |> :binary.matches(needle) |> List.last() |> elem(0)

  defp assert_contains_all!(source, needles) do
    Enum.each(needles, fn needle ->
      assert source =~ needle, "missing retained receiver proof: #{needle}"
    end)
  end

  defp alias_body(mix_exs, alias_name) do
    [_, body] = Regex.run(~r/"?#{Regex.escape(alias_name)}"?:\s*\[(.*?)\]/s, mix_exs)
    body
  end

  defp quoted_values(body) do
    Regex.scan(~r/"([^"]+)"/, body, capture: :all_but_first) |> List.flatten()
  end

  defp live_scaffold_paths do
    {tracked, 0} = System.cmd("git", ["ls-files", "test"])

    tracked
    |> String.split("\n", trim: true)
    |> Enum.filter(&String.ends_with?(&1, "_test.exs"))
    |> Enum.filter(&(File.read!(&1) =~ ~r/^\s*@moduletag\s+:scaffold\b/m))
    |> Enum.sort()
  end

  defp library_job_ids(workflow) do
    Regex.scan(~r/^  (library_tests(?:_[a-z_]+)?):$/m, workflow, capture: :all_but_first)
    |> List.flatten()
  end

  defp job_body(workflow, job_id) do
    pattern = ~r/^  #{Regex.escape(job_id)}:\n(?<body>(?:(?!^  [a-zA-Z0-9_]+:).*(?:\n|\z))*)/m

    case Regex.named_captures(pattern, workflow) do
      %{"body" => body} -> body
      _ -> flunk("missing workflow job #{job_id}")
    end
  end
end
