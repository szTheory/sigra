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

    assert {wrong_commit_output, wrong_commit_status} =
             System.cmd(
               "elixir",
               [@script, "historical-verify", input, output, "a523575d", "a523575d"],
               cd: @root,
               stderr_to_stdout: true
             )

    assert wrong_commit_status != 0
    assert wrong_commit_output =~ "freeze commit differs"

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

    forged_input =
      input
      |> File.read!()
      |> :json.decode()
      |> Map.put("files", [])
      |> Map.put("resolvers", [])
      |> with_manifest_sha()

    forged_output =
      output
      |> File.read!()
      |> :json.decode()
      |> Map.put("input_manifest_sha256", forged_input["manifest_sha256"])
      |> Map.put("post_audit_manifest_sha256", forged_input["manifest_sha256"])

    assert forged_input["manifest_sha256"] == manifest_sha(forged_input)
    assert forged_output["input_manifest_sha256"] == forged_output["post_audit_manifest_sha256"]

    File.write!(altered_input, forged_input |> :json.encode() |> IO.iodata_to_binary())
    File.write!(altered_output, forged_output |> :json.encode() |> IO.iodata_to_binary())

    assert_historical_failure!(
      altered_input,
      altered_output,
      "22dfd088",
      "a523575d",
      "committed input snapshot differs"
    )
  end

  defp assert_historical_failure!(input, output, freeze, audit, expected_error \\ nil) do
    assert {result, status} =
             System.cmd("elixir", [@script, "historical-verify", input, output, freeze, audit],
               cd: @root,
               stderr_to_stdout: true
             )

    assert status != 0

    if expected_error, do: assert(result =~ expected_error)
  end

  defp with_manifest_sha(snapshot) do
    manifest = snapshot |> Map.drop(["starting_commit", "manifest_sha256"]) |> canonical_json()
    Map.put(snapshot, "manifest_sha256", sha256(manifest))
  end

  defp manifest_sha(snapshot),
    do:
      snapshot |> Map.drop(["starting_commit", "manifest_sha256"]) |> canonical_json() |> sha256()

  defp canonical_json(value) when is_map(value) do
    value
    |> Enum.sort_by(&elem(&1, 0))
    |> Enum.map(fn {key, item} -> [:json.encode(key), ":", canonical_json(item)] end)
    |> IO.iodata_to_binary()
    |> then(&("{" <> &1 <> "}"))
  end

  defp canonical_json(value) when is_list(value),
    do: "[" <> Enum.map_join(value, ",", &canonical_json/1) <> "]"

  defp canonical_json(value), do: value |> :json.encode() |> IO.iodata_to_binary()

  defp sha256(value), do: :crypto.hash(:sha256, value) |> Base.encode16(case: :lower)
end
