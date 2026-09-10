defmodule Sigra.CI.LibraryTestPartitionsTest do
  use ExUnit.Case, async: true

  alias Sigra.CI.LibraryTestPartitions

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
          {opts[:costs] ++ [%{"path" => hd(LibraryTestPartitions.scaffold_paths()), "time_us" => 1}],
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
end
