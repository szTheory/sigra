ExUnit.start()

defmodule Phase236AuditSnapshotTest do
  use ExUnit.Case, async: false

  @root Path.expand("../..", __DIR__)
  @script Path.join(@root, "scripts/planning/phase-236-audit-snapshot.exs")

  test "snapshot inventories canonical sources and comparison rejects a mutation" do
    {json, 0} = System.cmd("elixir", [@script], cd: @root)
    snapshot = :json.decode(json)
    paths = Enum.map(snapshot["files"], & &1["path"])

    assert ".planning/ROADMAP.md" in paths
    assert ".planning/REQUIREMENTS.md" in paths
    assert Enum.any?(paths, &String.ends_with?(&1, "230-VERIFICATION.md"))
    assert Enum.any?(paths, &String.ends_with?(&1, "235-VALIDATION.md"))
    assert Enum.any?(paths, &String.ends_with?(&1, "236-04-SUMMARY.md"))
    assert Enum.map(snapshot["members"], & &1["phase"]) == Enum.to_list(230..235)
    assert Enum.map(snapshot["files"], & &1["path"]) == Enum.sort(paths)
    assert Enum.all?(snapshot["resolvers"], &Map.has_key?(&1, "exit_status"))

    temp =
      Path.join(
        System.tmp_dir!(),
        "phase-236-audit-snapshot-#{System.unique_integer([:positive])}.json"
      )

    File.write!(temp, json)
    assert {_output, 0} = System.cmd("elixir", [@script, "compare", temp], cd: @root)

    File.write!(
      temp,
      String.replace(json, snapshot["manifest_sha256"], String.duplicate("0", 64), global: false)
    )

    assert {_output, status} = System.cmd("elixir", [@script, "compare", temp], cd: @root)
    assert status != 0
  end

  test "utility is snapshot-only and has no audit dispatch" do
    source = File.read!(@script)
    refute source =~ "$gsd-"
    refute source =~ "validate" <> "-phase"
    refute source =~ "audit" <> "-milestone"
  end

  test "historical verification rejects mutated boundary inputs" do
    input =
      Path.join(
        @root,
        ".planning/phases/236-closeout-evidence-reconciliation/236-AUDIT-INPUT-SNAPSHOT.json"
      )

    output =
      Path.join(
        @root,
        ".planning/phases/236-closeout-evidence-reconciliation/236-AUDIT-OUTPUT-SNAPSHOT.json"
      )

    assert {_result, status} =
             System.cmd(
               "elixir",
               [@script, "historical-verify", input, output, "22dfd088", "a523575d"],
               cd: @root
             )

    assert status == 0

    temp =
      Path.join(System.tmp_dir!(), "phase-236-historical-#{System.unique_integer([:positive])}")

    File.mkdir_p!(temp)
    on_exit(fn -> File.rm_rf!(temp) end)

    altered_input = Path.join(temp, "input.json")
    altered_output = Path.join(temp, "output.json")

    File.write!(altered_input, File.read!(input))
    File.write!(altered_output, File.read!(output))
    assert_historical_failure!(altered_input, altered_output, "bad-freeze", "a523575d")

    File.write!(
      altered_input,
      String.replace(File.read!(input), "e25714d", "0000000", global: false)
    )

    assert_historical_failure!(altered_input, altered_output, "22dfd088", "a523575d")

    File.write!(altered_input, File.read!(input))

    File.write!(
      altered_output,
      String.replace(File.read!(output), "e25714d", "0000000", global: false)
    )

    assert_historical_failure!(altered_input, altered_output, "22dfd088", "a523575d")

    File.write!(
      altered_output,
      String.replace(File.read!(output), "58115d", "000000", global: false)
    )

    assert_historical_failure!(altered_input, altered_output, "22dfd088", "a523575d")
  end

  defp assert_historical_failure!(input, output, freeze, audit) do
    assert {_result, status} =
             System.cmd("elixir", [@script, "historical-verify", input, output, freeze, audit],
               cd: @root
             )

    assert status != 0
  end
end
