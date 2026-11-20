defmodule Sigra.Planning.Phase267CiIntegrityContractTest do
  use ExUnit.Case, async: true

  @workflow_path Path.expand("../../../.github/workflows/ci.yml", __DIR__)
  @helper_path Path.expand("../../test_helper.exs", __DIR__)
  @upgrade_path Path.expand("../../upgrade_test.exs", __DIR__)
  @playwright_config_path Path.expand(
                            "../../../test/example/priv/playwright/playwright.config.ts",
                            __DIR__
                          )
  @admin_eval_harness_path Path.expand("../../../scripts/ci/admin-eval-harness.sh", __DIR__)

  @required_flag "SIGRA_CI_REQUIRED: \"1\""
  @archive_install "run: mix archive.install --force hex phx_new 1.8.8"

  defp library_job(source) do
    case Regex.run(~r/^  library_tests_shard:\n(.*?)(?=^  [a-z_]+:|\z)/ms, source,
           capture: :all_but_first
         ) do
      [job] -> job
      nil -> nil
    end
  end

  defp workflow_job(source, name) do
    pattern = Regex.compile!("^  #{Regex.escape(name)}:\\n(.*?)(?=^  [a-z_-]+:|\\z)", "ms")

    case Regex.run(pattern, source, capture: :all_but_first) do
      [job] -> job
      nil -> nil
    end
  end

  defp project_block(source, name) do
    with [_, rest] <- String.split(source, "name: '#{name}',", parts: 2),
         [block | _] <- String.split(rest, "\n    },", parts: 2) do
      block
    else
      _ -> nil
    end
  end

  defp named_step(source, name) do
    pattern =
      Regex.compile!(
        "^      - name: #{Regex.escape(name)}\\n(.*?)(?=^      - name:|\\z)",
        "ms"
      )

    case Regex.run(pattern, source, capture: :all_but_first) do
      [step] -> step
      nil -> nil
    end
  end

  defp workflow_errors(source) do
    with job when is_binary(job) <- library_job(source),
         gate when is_binary(gate) <- named_step(job, "Run contributor CI gate") do
      install_at = :binary.match(job, @archive_install)
      gate_at = :binary.match(job, "- name: Run contributor CI gate")
      flag_count = length(Regex.scan(~r/SIGRA_CI_REQUIRED:/, source))

      []
      |> maybe_error(install_at == :nomatch, "library shard must install the pinned archive")
      |> maybe_error(gate_at == :nomatch, "library shard must contain the contributor gate")
      |> maybe_error(
        install_at != :nomatch and gate_at != :nomatch and elem(install_at, 0) > elem(gate_at, 0),
        "pinned archive installation must precede the contributor gate"
      )
      |> maybe_error(
        not String.contains?(gate, @required_flag),
        "required flag must belong to the gate"
      )
      |> maybe_error(flag_count != 1, "required flag must appear only on its gate owner")
      |> maybe_error(
        not String.contains?(gate, "run: MIX_ENV=test mix ci"),
        "gate command changed"
      )
      |> maybe_error(
        not Enum.all?(
          ["PGUSER: postgres", "PGPASSWORD: postgres", "PGHOST: localhost"],
          &String.contains?(gate, &1)
        ),
        "gate database environment changed"
      )
    else
      _ -> ["could not locate library_tests_shard contributor gate"]
    end
  end

  defp maybe_error(errors, true, message), do: errors ++ [message]
  defp maybe_error(errors, false, _message), do: errors

  test "the library owner installs phx_new before its fail-closed contributor gate" do
    source = File.read!(@workflow_path)
    assert workflow_errors(source) == []
  end

  test "the workflow contract rejects a removed or displaced required flag" do
    source = File.read!(@workflow_path)

    without_flag = String.replace(source, "          #{@required_flag}\n", "")
    assert workflow_errors(without_flag) != []

    displaced_flag =
      String.replace(source, "          #{@required_flag}\n", "") <>
        "\n# misplaced outside the library gate\n#{@required_flag}\n"

    assert workflow_errors(displaced_flag) != []
  end

  test "test helper resolves archive policy before ExUnit starts and no longer invokes archive.list" do
    helper = File.read!(@helper_path)

    assert helper =~ "Sigra.Test.PhxNewArchive.discover()"

    assert :binary.match(helper, "Sigra.Test.PhxNewArchive.discover()") <
             :binary.match(helper, "ExUnit.start()")

    refute helper =~ "archive.list"
  end

  test "all four upgrade behavior families remain asserted" do
    source = File.read!(@upgrade_path)

    for marker <- [
          "assert alter_migrations == []",
          "Enum.all?(login_result.status_codes_seen, &(&1 < 500))",
          "first_count == seeded_count",
          "expected re-run to be a no-op"
        ] do
      assert source =~ marker, "upgrade coverage marker missing: #{marker}"
    end
  end

  test "fast_checks runs the privacy preflights immediately after base resolution" do
    source = File.read!(@workflow_path)
    fast_checks = workflow_job(source, "fast_checks")
    assert is_binary(fast_checks)

    step_names =
      Regex.scan(~r/^      - name: (.+)$/m, fast_checks, capture: :all_but_first)
      |> List.flatten()

    base_index = Enum.find_index(step_names, &(&1 == "Resolve base ref"))
    assert is_integer(base_index)

    assert Enum.slice(step_names, base_index + 1, 3) == [
             "Tracked privacy guard syntax",
             "Tracked privacy guard self-test",
             "Tracked privacy tree scan"
           ]

    syntax = named_step(fast_checks, "Tracked privacy guard syntax")
    assert syntax =~ "perl -c scripts/ci/tracked-privacy-guard.pl"
    assert syntax =~ "bash -n scripts/ci/tracked-privacy-guard.test.sh"

    self_test = named_step(fast_checks, "Tracked privacy guard self-test")
    assert self_test =~ "bash scripts/ci/tracked-privacy-guard.test.sh"

    tree_scan = named_step(fast_checks, "Tracked privacy tree scan")
    assert tree_scan =~ "scripts/ci/tracked-privacy-guard.pl"
    assert tree_scan =~ "--base \"${{ steps.base.outputs.ref }}\""
    assert tree_scan =~ "--baseline test/fixtures/ci/tracked-privacy-exceptions.tsv"
  end

  test "the privacy preflights precede long ratchets and package checks" do
    source = File.read!(@workflow_path)
    fast_checks = workflow_job(source, "fast_checks")

    names =
      Regex.scan(~r/^      - name: (.+)$/m, fast_checks, capture: :all_but_first)
      |> List.flatten()

    index = fn name -> Enum.find_index(names, &(&1 == name)) end
    tree_scan = index.("Tracked privacy tree scan")
    assert is_integer(tree_scan)
    assert tree_scan < index.("Milestone verification gate")
    assert tree_scan < index.("Quality ledger monotonic guard")
  end

  test "admin-eval remains a non-PR lane outside ci-gate with its full harness" do
    source = File.read!(@workflow_path)
    admin_eval = workflow_job(source, "admin_eval_render")
    ci_gate = workflow_job(source, "ci-gate")

    harness =
      named_step(admin_eval || "", "Run admin-eval harness (render matrix + derivative guards)")

    assert is_binary(admin_eval)
    assert admin_eval =~ "if: github.event_name != 'pull_request'"
    assert is_binary(ci_gate)
    assert ci_gate =~ "needs:"

    needs =
      Regex.run(~r/^    needs:\n((?:      - [a-z0-9_-]+\n)+)/m, ci_gate, capture: :all_but_first)

    assert [needs_block] = needs
    refute needs_block =~ "admin_eval_render"
    assert is_binary(harness)
    assert harness =~ "run: bash scripts/ci/admin-eval-harness.sh"
  end

  test "admin-eval storage states keep all three setup dependencies and retries at zero" do
    config = File.read!(@playwright_config_path)
    assert config =~ "retries: 0"
    assert config =~ "const ADMIN_EVAL_SPEC = /admin-eval\\.spec\\.ts/;"

    expected = [
      {"admin-eval", "admin-eval-setup", "admin-eval-desktop.json"},
      {"admin-eval-mobile", "admin-eval-setup-mobile", "admin-eval-mobile.json"},
      {"admin-eval-dark", "admin-eval-setup-dark", "admin-eval-dark.json"}
    ]

    blocks =
      Enum.map(expected, fn {project_name, setup_name, state_file} ->
        block = project_block(config, project_name)
        assert is_binary(block), "missing Playwright project #{project_name}"
        assert block =~ "dependencies: ['#{setup_name}']"
        assert block =~ "storageState: 'test-results/.auth/#{state_file}'"
        block
      end)

    state_files =
      Enum.flat_map(blocks, &Regex.scan(~r/storageState: '([^']+)'/, &1, capture: :all_but_first))
      |> List.flatten()

    assert Enum.uniq(state_files) |> length() == 3
    assert File.read!(@admin_eval_harness_path) =~ "--project=admin-eval"
  end
end
