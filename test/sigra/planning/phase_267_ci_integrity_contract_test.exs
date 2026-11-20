defmodule Sigra.Planning.Phase267CiIntegrityContractTest do
  use ExUnit.Case, async: true

  @workflow_path Path.expand("../../../.github/workflows/ci.yml", __DIR__)
  @helper_path Path.expand("../../test_helper.exs", __DIR__)
  @upgrade_path Path.expand("../../upgrade_test.exs", __DIR__)

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
end
