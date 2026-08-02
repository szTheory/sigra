defmodule Sigra.Planning.Phase235TerminalRatificationContractTest do
  use ExUnit.Case, async: true

  @ledger_path ".planning/phases/235-terminal-ratification-measured-not-read/235-TERMINAL-RATIFICATION.json"
  @workflow_path ".github/workflows/ci.yml"
  @cutoff_sha "6c57d7b4a22aa87a757a6f508f2cf4fdb414e40a"
  @top_level_keys MapSet.new(~w(schema_version topology_cutoff capture_endpoint baseline measurements ownership receipts verdict closeout))
  @events ~w(pull_request push schedule)

  test "the terminal ratification ledger is a pending, versioned tracer with an immutable cutoff" do
    ledger = ledger!()

    assert validate_ledger!(ledger) == :ok
    assert MapSet.new(Map.keys(ledger)) == @top_level_keys
    assert ledger["schema_version"] == "sigra.terminal-ratification/v1"
    assert ledger["topology_cutoff"]["source_commit_sha"] == @cutoff_sha
    assert ledger["topology_cutoff"]["committed_at"] == "2026-08-01T02:06:30Z"
    assert ledger["capture_endpoint"]["status"] == "pending"
    assert ledger["verdict"]["status"] == "pending"
    assert ledger["closeout"]["status"] == "pending"
  end

  test "baseline-compatible measurements preserve the committed seconds without recomputation" do
    assert ledger!()["baseline"] == %{
             "pull_request" => %{"n" => 21, "mean_seconds" => 1770, "p50_seconds" => 1638, "max_seconds" => 2502, "pass" => 17, "fail" => 4},
             "push" => %{"n" => 7, "mean_seconds" => 1830, "p50_seconds" => 1656, "max_seconds" => 2538, "pass" => 6, "fail" => 1},
             "schedule" => %{"n" => 9, "mean_seconds" => 1638, "p50_seconds" => 1626, "max_seconds" => 1764, "pass" => 0, "fail" => 9}
           }
  end

  test "library scaffold and golden ownership has one explicit executable row per terminal event" do
    ledger = ledger!()
    rows = ledger["ownership"]["rows"]

    assert Enum.map(rows, & &1["event"]) == @events

    for row <- rows do
      assert row["family"] == "library_scaffold_golden"
      assert row["after"]["direct_owner"] == "library_tests_shard"
      assert row["after"]["invocation"] == "MIX_ENV=test mix ci"
      assert row["after"]["terminal_aggregate"] == %{"id" => "library_tests", "name" => "Library tests"}
      assert row["receiver"] == "library_tests_shard"
      assert row["receipt"] == "phase_233_library_suite"
    end

    workflow = File.read!(@workflow_path)
    assert workflow =~ "library_tests_shard:"
    assert workflow =~ "Run contributor CI gate"
    assert workflow =~ "MIX_ENV=test mix ci"
    assert workflow =~ "name: Library tests"
  end

  test "validation fails closed for malformed and success-shaped pending ledger mutations" do
    ledger = ledger!()

    assert_raise ArgumentError, ~r/exact top-level keys/, fn ->
      validate_ledger!(Map.delete(ledger, "closeout"))
    end

    assert_raise ArgumentError, ~r/exact top-level keys/, fn ->
      validate_ledger!(Map.put(ledger, "extra", %{}))
    end

    assert_raise ArgumentError, ~r/cutoff SHA/, fn ->
      put_in(ledger, ["topology_cutoff", "source_commit_sha"], "short") |> validate_ledger!()
    end

    assert_raise ArgumentError, ~r/direct owner/, fn ->
      put_in(ledger, ["ownership", "rows", Access.at(0), "after", "direct_owner"], nil) |> validate_ledger!()
    end

    assert_raise ArgumentError, ~r/aggregate-only/, fn ->
      put_in(ledger, ["ownership", "rows", Access.at(0), "after", "direct_owner"], "library_tests") |> validate_ledger!()
    end

    assert_raise ArgumentError, ~r/pending measurement/, fn ->
      put_in(ledger, ["measurements", "pull_request", "status"], "complete") |> validate_ledger!()
    end
  end

  defp ledger!, do: @ledger_path |> File.read!() |> Jason.decode!()

  defp validate_ledger!(ledger) do
    unless MapSet.new(Map.keys(ledger)) == @top_level_keys, do: raise(ArgumentError, "exact top-level keys required")
    unless ledger["schema_version"] == "sigra.terminal-ratification/v1", do: raise(ArgumentError, "schema version")
    validate_cutoff!(ledger["topology_cutoff"])
    validate_pending!(ledger)
    validate_baseline!(ledger["baseline"])
    validate_rows!(ledger["ownership"]["rows"])
    :ok
  end

  defp validate_cutoff!(%{"source_commit_sha" => @cutoff_sha, "committed_at" => "2026-08-01T02:06:30Z"}) do
    {output, 0} = System.cmd("git", ["show", "-s", "--format=%H%n%cI", @cutoff_sha])
    [sha, committed_at] = String.split(String.trim(output), "\n")
    unless sha == @cutoff_sha and same_instant?(committed_at, "2026-08-01T02:06:30Z"), do: raise(ArgumentError, "cutoff Git timestamp")
  end
  defp validate_cutoff!(_), do: raise(ArgumentError, "cutoff SHA or timestamp")

  defp validate_pending!(ledger) do
    unless ledger["capture_endpoint"]["status"] == "pending", do: raise(ArgumentError, "capture endpoint")
    unless ledger["verdict"]["status"] == "pending" and ledger["closeout"]["status"] == "pending", do: raise(ArgumentError, "pending verdict or closeout")

    for event <- @events do
      measurement = ledger["measurements"][event]
      unless measurement["status"] == "pending" and measurement["run_ids"] == [] and not Map.has_key?(measurement, "statistics"), do: raise(ArgumentError, "pending measurement #{event}")
    end
  end

  defp validate_baseline!(baseline) do
    unless MapSet.new(Map.keys(baseline)) == MapSet.new(@events), do: raise(ArgumentError, "baseline events")
  end

  defp validate_rows!(rows) when is_list(rows) do
    unless Enum.map(rows, & &1["event"]) == @events, do: raise(ArgumentError, "event coverage")

    for row <- rows do
      after_row = row["after"] || %{}
      direct_owner = after_row["direct_owner"]
      unless is_binary(direct_owner) and direct_owner != "", do: raise(ArgumentError, "direct owner #{row["event"]}")
      if direct_owner == "library_tests", do: raise(ArgumentError, "aggregate-only ownership #{row["event"]}")
      unless row["receiver"] == "library_tests_shard" and is_binary(row["receipt"]), do: raise(ArgumentError, "receipt or receiver #{row["event"]}")
    end
  end
  defp validate_rows!(_), do: raise(ArgumentError, "ownership rows")

  defp same_instant?(left, right) do
    {:ok, left, _} = DateTime.from_iso8601(left)
    {:ok, right, _} = DateTime.from_iso8601(right)
    DateTime.compare(left, right) == :eq
  end
end
