Code.require_file("library_test_partitions.exs", __DIR__)

defmodule Sigra.CI.LibraryTestPartitionsTest do
  use ExUnit.Case, async: true

  alias Sigra.CI.LibraryTestPartitions

  @calibration_path ".planning/phases/235.1-close-v1-47-library-economics-integration-gaps-test-01-test/235.1-PARTITION-CALIBRATION.json"

  test "the measured manifest is an exhaustive disjoint lexical ordinary universe" do
    partitions = LibraryTestPartitions.build_partitions!()
    ordinary = LibraryTestPartitions.current_ordinary_paths!()

    assert partitions[1].paths != []
    assert partitions[2].paths != []
    assert partitions[1].paths == Enum.sort(partitions[1].paths)
    assert partitions[2].paths == Enum.sort(partitions[2].paths)
    assert Enum.sort(partitions[1].paths ++ partitions[2].paths) == ordinary
    assert MapSet.disjoint?(MapSet.new(partitions[1].paths), MapSet.new(partitions[2].paths))
    assert Enum.all?(LibraryTestPartitions.scaffold_paths(), &(&1 not in ordinary))
  end

  test "longest-processing-time assignment is deterministic and partition one wins exact ties" do
    costs = [
      %{"path" => "test/z_test.exs", "time_us" => 10},
      %{"path" => "test/a_test.exs", "time_us" => 10},
      %{"path" => "test/m_test.exs", "time_us" => 5},
      %{"path" => "test/b_test.exs", "time_us" => 5}
    ]

    assert LibraryTestPartitions.assign!(Enum.reverse(costs)) ==
             LibraryTestPartitions.assign!(costs)

    assert LibraryTestPartitions.assign!(costs) == %{
             1 => %{paths: ["test/a_test.exs", "test/b_test.exs"], total_us: 15},
             2 => %{paths: ["test/m_test.exs", "test/z_test.exs"], total_us: 15}
           }
  end

  test "assignment rejects zero costs in either input order" do
    costs = [
      %{"path" => "test/a_test.exs", "time_us" => 0},
      %{"path" => "test/b_test.exs", "time_us" => 0}
    ]

    for candidate <- [costs, Enum.reverse(costs)] do
      assert_raise ArgumentError, ~r/positive measured cost/, fn ->
        LibraryTestPartitions.assign!(candidate)
      end
    end
  end

  test "calibration replays all three retained triples into exact positive median costs" do
    calibration = LibraryTestPartitions.load_calibration!()
    raw = @calibration_path |> File.read!() |> JSON.decode!()

    assert raw["source"] == %{
             "aggregation" => "median(max(1,sum(time_us)))",
             "blocked_summary_commit" => "2d854758",
             "collection_command" =>
               "ASDF_ERLANG_VERSION=28.4.1 MIX_ENV=test bash scripts/ci/library-partitions.sh",
             "implementation_commit" => "60ef7c94e955a15e404a3133789ab3b0325f8b62",
             "sample_count" => 3
           }

    assert Enum.map(raw["samples"], & &1["ordinal"]) == [1, 2, 3]
    assert length(for sample <- raw["samples"], receipt <- [sample["combined"] | sample["timings"]], do: receipt) == 9
    assert calibration.costs == independently_replayed_costs(raw)
    assert Enum.map(calibration.costs, & &1["path"]) == raw["ordinary_universe"]["paths"]
    assert Enum.all?(calibration.costs, &(&1["time_us"] > 0))
  end

  test "sample and timing row order cannot alter independently replayed costs" do
    raw = @calibration_path |> File.read!() |> JSON.decode!()
    expected = LibraryTestPartitions.load_calibration!().costs

    reordered_samples = Map.update!(raw, "samples", &Enum.reverse/1)
    assert LibraryTestPartitions.load_calibration!(path: write_calibration!(reordered_samples)).costs == expected

    reordered_rows =
      update_in(raw, ["samples", Access.at(0), "timings", Access.at(0)], fn receipt ->
        timing = receipt |> decode_receipt!() |> Map.update!("tests", &Enum.reverse/1)
        replace_payload(receipt, JSON.encode!(timing))
      end)

    assert LibraryTestPartitions.load_calibration!(path: write_calibration!(reordered_rows)).costs == expected
  end

  test "calibration rejects provenance, payload, universe, and derived-cost mutations" do
    raw = @calibration_path |> File.read!() |> JSON.decode!()

    mutations = [
      Map.put(raw, "unexpected", true),
      put_in(raw, ["source", "implementation_commit"], String.duplicate("0", 40)),
      put_in(raw, ["limits", "timing_bytes"], 1),
      update_in(raw, ["ordinary_universe", "paths"], &tl/1),
      put_in(raw, ["derived_costs", Access.at(0), "time_us"], 0),
      update_in(raw, ["derived_costs"], &Enum.reverse/1),
      put_in(raw, ["samples", Access.at(0), "combined", "payload_base64"], "not-base64"),
      put_in(raw, ["samples", Access.at(0), "combined", "sha256"], String.duplicate("0", 64)),
      update_in(raw, ["samples", Access.at(0), "combined", "byte_count"], &(&1 + 1)),
      put_in(raw, ["samples", Access.at(0), "timings", Access.at(1), "role"], "timing-1"),
      put_in(
        raw,
        ["samples", Access.at(0), "timings", Access.at(0), "source_path"],
        "/tmp/forged.json"
      )
    ]

    Enum.each(mutations, fn mutation ->
      assert_raise ArgumentError, fn ->
        LibraryTestPartitions.load_calibration!(path: write_calibration!(mutation))
      end
    end)

    oversized =
      update_in(raw, ["samples", Access.at(0), "timings", Access.at(0)], fn receipt ->
        replace_payload(receipt, String.duplicate("x", 1_048_577))
      end)

    assert_raise ArgumentError, fn ->
      LibraryTestPartitions.load_calibration!(path: write_calibration!(oversized))
    end
  end

  test "missing, stale, duplicate, and scaffold paths fail closed" do
    opts = [
      costs: [
        %{"path" => "test/a_test.exs", "time_us" => 2},
        %{"path" => "test/b_test.exs", "time_us" => 1}
      ],
      ordinary_paths: ["test/a_test.exs", "test/b_test.exs"]
    ]

    assert %{1 => %{paths: ["test/a_test.exs"]}, 2 => %{paths: ["test/b_test.exs"]}} =
             LibraryTestPartitions.build_partitions!(opts)

    for {costs, message} <- [
          {[%{"path" => "test/a_test.exs", "time_us" => 1}], "missing current paths"},
          {opts[:costs] ++ [%{"path" => "test/stale_test.exs", "time_us" => 1}],
           "stale manifest paths"},
          {opts[:costs] ++ [%{"path" => "test/a_test.exs", "time_us" => 1}], "duplicate"},
          {opts[:costs] ++
             [%{"path" => hd(LibraryTestPartitions.scaffold_paths()), "time_us" => 1}],
           "scaffold"}
        ] do
      assert_raise ArgumentError, ~r/#{message}/, fn ->
        LibraryTestPartitions.build_partitions!(Keyword.put(opts, :costs, costs))
      end
    end
  end

  test "receipt metadata pins the two fixed timing paths and manifest digests" do
    partitions = LibraryTestPartitions.build_partitions!()

    assert LibraryTestPartitions.timing_path(1) == "/tmp/sigra-library-1-timings.json"
    assert LibraryTestPartitions.timing_path(2) == "/tmp/sigra-library-2-timings.json"

    for id <- [1, 2] do
      assert LibraryTestPartitions.manifest_sha256(partitions[id].paths) ==
               :crypto.hash(:sha256, Enum.join(partitions[id].paths, "\n") <> "\n")
               |> Base.encode16(case: :lower)
    end
  end


  defp independently_replayed_costs(raw) do
    raw["ordinary_universe"]["paths"]
    |> Enum.map(fn path ->
      samples =
        Enum.map(raw["samples"], fn sample ->
          sample["timings"]
          |> Enum.flat_map(&(decode_receipt!(&1)["tests"]))
          |> Enum.filter(&(&1["file"] == path))
          |> Enum.map(& &1["time_us"])
          |> Enum.sum()
          |> max(1)
        end)
        |> Enum.sort()

      %{"path" => path, "time_us" => Enum.at(samples, 1)}
    end)
  end

  defp decode_receipt!(receipt) do
    receipt["payload_base64"] |> Base.decode64!() |> JSON.decode!()
  end

  defp replace_payload(receipt, payload) do
    receipt
    |> Map.put("payload_base64", Base.encode64(payload))
    |> Map.put("byte_count", byte_size(payload))
    |> Map.put("sha256", :crypto.hash(:sha256, payload) |> Base.encode16(case: :lower))
  end

  defp write_calibration!(value) do
    path = Path.join(System.tmp_dir!(), "sigra-partition-calibration-#{System.unique_integer([:positive])}.json")
    File.write!(path, JSON.encode!(value))
    on_exit(fn -> File.rm(path) end)
    path
  end
end
