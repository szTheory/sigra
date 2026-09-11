Code.require_file("library_test_partitions.exs", __DIR__)

defmodule Sigra.CI.LibraryTestPartitionsTest do
  use ExUnit.Case, async: true

  alias Sigra.CI.LibraryTestPartitions

  @calibration_path ".planning/phases/235.1-close-v1-47-library-economics-integration-gaps-test-01-test/235.1-PARTITION-CALIBRATION.json"
  @manifest_path ".planning/phases/235.1-close-v1-47-library-economics-integration-gaps-test-01-test/235.1-PARTITION-CALIBRATION-MANIFEST.json"
  @immutable_source_commit "b37ac1164cee96be11a5cdeb60b31db560018e04"
  @immutable_source_tree "02bb907f075b1428d89bb87e519c0e0d8810fcd9"

  @tag :provenance_fixture
  test "exact runtime source index authorizes a shallow checkout without the provenance object" do
    fixture = shallow_repository_fixture!()

    assert_standalone_repository!(fixture.root)
    assert_git_object_missing!(fixture.root, @immutable_source_commit, "commit")
    assert_git_object_missing!(fixture.root, @immutable_source_tree, "tree")
    assert_git_object_missing!(fixture.root, "47f9578fc97edc63603953d446e79fac884326c3", "commit")

    loaded = LibraryTestPartitions.load_calibration!(root: fixture.root)
    partitions = LibraryTestPartitions.assign!(loaded.costs)

    assert length(partitions[1].paths) == 114
    assert length(partitions[2].paths) == 111
  end

  @tag :provenance_fixture
  test "reachable provenance remains a non-authorizing compatibility control" do
    fixture = shallow_repository_fixture!()

    assert_standalone_repository!(fixture.root)
    assert_git_object_missing!(fixture.root, @immutable_source_commit, "commit")
    assert_git_object_missing!(fixture.root, @immutable_source_tree, "tree")
    assert_git_object_missing!(fixture.root, "47f9578fc97edc63603953d446e79fac884326c3", "commit")

    install_exact_provenance_object!(fixture.root)
    assert_git_object_present!(fixture.root, @immutable_source_commit, "commit")
    assert_git_object_missing!(fixture.root, @immutable_source_tree, "tree")
    assert_git_object_missing!(fixture.root, "47f9578fc97edc63603953d446e79fac884326c3", "commit")

    loaded = LibraryTestPartitions.load_calibration!(root: fixture.root)
    partitions = LibraryTestPartitions.assign!(loaded.costs)
    assert {length(partitions[1].paths), length(partitions[2].paths)} == {114, 111}
  end

  test "immutable provenance and artifact cross-link mutations fail with regenerated bindings" do
    assert_fixture_mutation!(~r/source snapshot commit\/tree/, fn fixture ->
      rewrite_bound_fixture!(fixture, fn calibration, manifest ->
        commit = String.duplicate("0", 40)

        {
          put_in(calibration, ["source", "implementation_commit"], commit),
          put_in(manifest, ["source_snapshot", "commit"], commit)
        }
      end)
    end)

    assert_fixture_mutation!(~r/source snapshot commit\/tree/, fn fixture ->
      rewrite_bound_fixture!(fixture, fn calibration, manifest ->
        {calibration, put_in(manifest, ["source_snapshot", "tree"], String.duplicate("0", 40))}
      end)
    end)

    assert_fixture_mutation!(~r/calibration provenance/, fn fixture ->
      rewrite_bound_fixture!(fixture, fn calibration, manifest ->
        {put_in(calibration, ["source", "implementation_commit"], String.duplicate("0", 40)),
         manifest}
      end)
    end)
  end

  test "runtime source path, content, order, index, regular-file, and uniqueness drift fail closed" do
    assert_fixture_mutation!(~r/current ordinary source bytes/, fn fixture ->
      path = Path.join(fixture.root, hd(fixture.ordinary_paths))
      File.write!(path, File.read!(path) <> "# changed\n")
    end)

    assert_fixture_mutation!(~r/ordinary universe/, fn fixture ->
      added = Path.join(fixture.root, "test/plan36_added_test.exs")
      File.write!(added, "defmodule Plan36AddedTest do\nend\n")
      {_, 0} = System.cmd("git", ["-C", fixture.root, "add", "test/plan36_added_test.exs"])
    end)

    assert_fixture_mutation!(
      ~r/ordinary source file|ordinary universe|tracked path is not regular/,
      fn fixture ->
        File.rm!(Path.join(fixture.root, hd(fixture.ordinary_paths)))
      end
    )

    assert_fixture_mutation!(~r/ordinary universe/, fn fixture ->
      first = hd(fixture.ordinary_paths)
      renamed = first <> ".renamed_test.exs"
      {_, 0} = System.cmd("git", ["-C", fixture.root, "mv", first, renamed])
    end)

    assert_fixture_mutation!(~r/ordinary source index/, fn fixture ->
      rewrite_bound_fixture!(fixture, fn calibration, manifest ->
        rows = calibration["ordinary_universe"]["source_files"] |> Enum.reverse()
        calibration = put_in(calibration, ["ordinary_universe", "source_files"], rows)

        manifest =
          put_in(manifest, ["ordinary_source_index_sha256"], digest(JSON.encode!(rows) <> "\n"))

        {calibration, manifest}
      end)
    end)

    assert_fixture_mutation!(~r/current ordinary source bytes/, fn fixture ->
      rewrite_bound_fixture!(fixture, fn calibration, manifest ->
        calibration =
          put_in(
            calibration,
            ["ordinary_universe", "source_files", Access.at(0), "sha256"],
            String.duplicate("0", 64)
          )

        rows = calibration["ordinary_universe"]["source_files"]

        {calibration,
         put_in(manifest, ["ordinary_source_index_sha256"], digest(JSON.encode!(rows) <> "\n"))}
      end)
    end)

    assert_fixture_mutation!(~r/ordinary source index digest/, fn fixture ->
      rewrite_bound_fixture!(fixture, fn calibration, manifest ->
        {calibration,
         put_in(manifest, ["ordinary_source_index_sha256"], String.duplicate("0", 64))}
      end)
    end)

    assert_fixture_mutation!(~r/ordinary source file|tracked path is not regular/, fn fixture ->
      first = hd(fixture.ordinary_paths)
      path = Path.join(fixture.root, first)
      bytes = File.read!(path)
      File.rm!(path)
      File.ln_s!(Path.basename(first), path)
      assert File.lstat!(path).type == :symlink
      refute bytes == ""
    end)

    assert_fixture_mutation!(~r/ordinary source file|tracked path is not regular/, fn fixture ->
      path = Path.join(fixture.root, hd(fixture.ordinary_paths))
      File.rm!(path)
      File.mkdir_p!(path)
    end)

    assert_fixture_mutation!(~r/ordinary source index|ordinary universe/, fn fixture ->
      rewrite_bound_fixture!(fixture, fn calibration, manifest ->
        rows = calibration["ordinary_universe"]["source_files"]
        duplicate_rows = [hd(rows) | rows]

        calibration =
          calibration
          |> put_in(["ordinary_universe", "source_files"], duplicate_rows)

        manifest =
          put_in(
            manifest,
            ["ordinary_source_index_sha256"],
            digest(JSON.encode!(duplicate_rows) <> "\n")
          )

        {calibration, manifest}
      end)
    end)
  end

  test "v2 calibration is externally bound to source bytes" do
    source = File.read!("test/support/ci/library_test_partitions.exs")

    assert source =~ ~s(@calibration_schema "sigra.library-partition-calibration/v2")
    assert source =~ "sigra.library-partition-calibration-manifest/v1"
    assert source =~ "source_files"
    assert source =~ "ordinary_source_index_sha256"
    refute source =~ "git_blob_bytes!"
    refute source =~ ~s(System.cmd("git", ["-C", root, "rev-parse")
    assert source =~ @immutable_source_commit
    assert source =~ @immutable_source_tree
    refute source =~ ~r/@sample_implementation_commit|@calibration_sha256|@calibration_byte_count/
    assert File.exists?(@calibration_path)
  end

  test "v2 loader rejects source, snapshot, index, artifact, manifest, and symlink drift" do
    fixture = calibration_fixture!()
    opts = fixture.opts

    loaded = LibraryTestPartitions.load_calibration!(opts)
    assert Enum.map(loaded.costs, & &1["path"]) == fixture.paths

    first = hd(fixture.paths)
    first_path = Path.join(fixture.root, first)
    original = File.read!(first_path)
    File.write!(first_path, original <> "# drift\n")

    assert_raise ArgumentError, ~r/current ordinary source bytes/, fn ->
      LibraryTestPartitions.load_calibration!(opts)
    end

    File.write!(first_path, original)
    File.rm!(first_path)
    File.ln_s!("ordinary_b_test.exs", first_path)

    assert_raise ArgumentError, ~r/ordinary source file/, fn ->
      LibraryTestPartitions.load_calibration!(opts)
    end

    File.rm!(first_path)
    File.write!(first_path, original)

    manifest = fixture.manifest_path |> File.read!() |> JSON.decode!()
    File.write!(fixture.manifest_path, JSON.encode!(Map.put(manifest, "unexpected", true)))

    assert_raise ArgumentError, ~r/manifest keys/, fn ->
      LibraryTestPartitions.load_calibration!(opts)
    end

    File.write!(fixture.manifest_path, JSON.encode!(manifest))

    calibration = fixture.calibration_path |> File.read!() |> JSON.decode!()
    reordered = update_in(calibration, ["ordinary_universe", "source_files"], &Enum.reverse/1)
    write_bound_fixture!(fixture, reordered, manifest)

    assert_raise ArgumentError, ~r/ordinary source index/, fn ->
      LibraryTestPartitions.load_calibration!(opts)
    end

    write_bound_fixture!(fixture, calibration, manifest)
    File.write!(fixture.calibration_path, File.read!(fixture.calibration_path) <> "\n")

    assert_raise ArgumentError, ~r/manifest calibration byte binding/, fn ->
      LibraryTestPartitions.load_calibration!(opts)
    end
  end

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

  @tag :assignment_contract
  test "both global Oban paths can occupy either measured partition" do
    deletion = "test/sigra/account/deletion_test.exs"
    delivery = "test/sigra/delivery_test.exs"
    paths = [deletion, delivery, "test/a_test.exs", "test/b_test.exs"] |> Enum.sort()

    fixtures = [
      [{deletion, 100}, {delivery, 90}, {"test/a_test.exs", 80}, {"test/b_test.exs", 70}],
      [{deletion, 90}, {delivery, 100}, {"test/a_test.exs", 80}, {"test/b_test.exs", 70}]
    ]

    placements =
      Enum.map(fixtures, fn fixture ->
        costs =
          Enum.map(fixture, fn {path, time_us} -> %{"path" => path, "time_us" => time_us} end)

        partitions = LibraryTestPartitions.build_partitions!(ordinary_paths: paths, costs: costs)

        assert LibraryTestPartitions.validate_current_universe!(partitions, ordinary_paths: paths) ==
                 partitions

        assigned = partitions[1].paths ++ partitions[2].paths
        assert Enum.sort(assigned) == paths
        assert MapSet.disjoint?(MapSet.new(partitions[1].paths), MapSet.new(partitions[2].paths))
        assert partitions[1].paths != [] and partitions[2].paths != []
        assert partitions[1].total_us > 0 and partitions[2].total_us > 0

        assert max(partitions[1].total_us, partitions[2].total_us) /
                 min(partitions[1].total_us, partitions[2].total_us) <= 2.0

        %{deletion => owner(partitions, deletion), delivery => owner(partitions, delivery)}
      end)

    assert Enum.map(placements, & &1[deletion]) |> Enum.sort() == [1, 2]
    assert Enum.map(placements, & &1[delivery]) |> Enum.sort() == [1, 2]
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
             "blocked_summary_commit" => "81afbf0cafcf7dcf380d728a03053c42cdccdaa0",
             "collection_command" =>
               "ASDF_ERLANG_VERSION=28.4.1 MIX_ENV=test bash scripts/ci/library-partitions.sh",
             "implementation_commit" =>
               @manifest_path
               |> File.read!()
               |> JSON.decode!()
               |> get_in(["source_snapshot", "commit"]),
             "sample_count" => 3
           }

    assert Enum.map(raw["samples"], & &1["ordinal"]) == [1, 2, 3]

    assert length(
             for sample <- raw["samples"],
                 receipt <- [sample["combined"] | sample["timings"]],
                 do: receipt
           ) == 9

    assert calibration.costs == independently_replayed_costs(raw)
    assert Enum.map(calibration.costs, & &1["path"]) == raw["ordinary_universe"]["paths"]
    assert Enum.all?(calibration.costs, &(&1["time_us"] > 0))
  end

  test "unbound sample and timing row reorderings are rejected" do
    raw = @calibration_path |> File.read!() |> JSON.decode!()

    reordered_samples = Map.update!(raw, "samples", &Enum.reverse/1)

    assert_raise ArgumentError, ~r/calibration path differs from manifest/, fn ->
      LibraryTestPartitions.load_calibration!(path: write_calibration!(reordered_samples))
    end

    reordered_rows =
      update_in(raw, ["samples", Access.at(0), "timings", Access.at(0)], fn receipt ->
        timing = receipt |> decode_receipt!() |> Map.update!("tests", &Enum.reverse/1)
        replace_payload(receipt, JSON.encode!(timing))
      end)

    assert_raise ArgumentError, ~r/calibration path differs from manifest/, fn ->
      LibraryTestPartitions.load_calibration!(path: write_calibration!(reordered_rows))
    end
  end

  test "calibration rejects provenance, payload, universe, and derived-cost mutations" do
    raw = @calibration_path |> File.read!() |> JSON.decode!()

    mutations = [
      Map.put(raw, "unexpected", true),
      put_in(raw, ["source", "implementation_commit"], String.duplicate("0", 40)),
      put_in(raw, ["samples", Access.at(1), "ordinal"], 1),
      put_in(raw, ["limits", "timing_bytes"], 1),
      update_in(raw, ["ordinary_universe", "paths"], &tl/1),
      put_in(raw, ["derived_costs", Access.at(0), "time_us"], 0),
      update_in(raw, ["derived_costs", Access.at(0), "time_us"], &(&1 + 1)),
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

    embedded_mutations = [
      mutate_payload(raw, ["samples", Access.at(0), "combined"], fn combined ->
        update_in(combined, ["partitions", Access.at(0), "duration_ms"], &(&1 + 1))
      end),
      mutate_payload(raw, ["samples", Access.at(0), "combined"], fn combined ->
        update_in(combined, ["partitions", Access.at(0), "paths"], &tl/1)
      end),
      mutate_payload(raw, ["samples", Access.at(0), "timings", Access.at(0)], fn timing ->
        update_in(timing, ["tests", Access.at(0), "file"], fn _ ->
          hd(LibraryTestPartitions.scaffold_paths())
        end)
      end),
      mutate_payload(raw, ["samples", Access.at(0), "timings", Access.at(0)], fn timing ->
        update_in(timing, ["tests", Access.at(0)], &Map.delete(&1, "outcome"))
      end),
      mutate_payload(raw, ["samples", Access.at(0), "timings", Access.at(0)], fn timing ->
        put_in(timing, ["tests"], [hd(timing["tests"]) | timing["tests"]])
      end)
    ]

    Enum.each(mutations ++ embedded_mutations, fn mutation ->
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

    assert_raise ArgumentError, fn ->
      LibraryTestPartitions.load_calibration!(path: write_raw_calibration!("{"))
    end

    duplicate_top_key =
      File.read!(@calibration_path)
      |> String.replace_prefix("{", "{\"schema_version\":\"forged\",")

    assert_raise ArgumentError, fn ->
      LibraryTestPartitions.load_calibration!(path: write_raw_calibration!(duplicate_top_key))
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
          |> Enum.flat_map(&decode_receipt!(&1)["tests"])
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

  defp mutate_payload(raw, access_path, fun) do
    update_in(raw, access_path, fn receipt ->
      payload = receipt |> decode_receipt!() |> fun.() |> JSON.encode!()
      replace_payload(receipt, payload)
    end)
  end

  defp write_calibration!(value) do
    write_raw_calibration!(JSON.encode!(value))
  end

  defp write_raw_calibration!(value) do
    path =
      Path.join(
        System.tmp_dir!(),
        "sigra-partition-calibration-#{System.unique_integer([:positive])}.json"
      )

    File.write!(path, value)
    on_exit(fn -> File.rm(path) end)
    path
  end

  defp calibration_fixture! do
    root =
      Path.join(
        System.tmp_dir!(),
        "sigra-calibration-fixture-#{System.unique_integer([:positive])}"
      )

    paths = ["test/ordinary_a_test.exs", "test/ordinary_b_test.exs"]
    Enum.each(paths, fn path -> File.mkdir_p!(Path.dirname(Path.join(root, path))) end)
    File.write!(Path.join(root, Enum.at(paths, 0)), "defmodule OrdinaryA do\nend\n")
    File.write!(Path.join(root, Enum.at(paths, 1)), "defmodule OrdinaryB do\nend\n")
    System.cmd("git", ["-C", root, "init", "--quiet"])
    System.cmd("git", ["-C", root, "add", "test"])

    System.cmd("git", [
      "-C",
      root,
      "-c",
      "user.name=Sigra",
      "-c",
      "user.email=sigra@example.test",
      "commit",
      "-m",
      "snapshot",
      "--quiet"
    ])

    source_files = Enum.map(paths, fn path -> source_row!(root, path) end)

    costs = [
      %{"path" => Enum.at(paths, 0), "time_us" => 10},
      %{"path" => Enum.at(paths, 1), "time_us" => 8}
    ]

    samples =
      for ordinal <- 1..3 do
        timings =
          Enum.map(Enum.with_index(paths, 1), fn {path, id} ->
            timing = %{
              "schema_version" => 1,
              "partition" => Integer.to_string(id),
              "tests" => [
                %{
                  "file" => path,
                  "module" => "Fixture#{id}",
                  "name" => "test fixture",
                  "time_us" => if(id == 1, do: 10, else: 8),
                  "outcome" => "passed"
                }
              ],
              "total" => 1,
              "passed" => 1,
              "failed" => 0,
              "skipped" => 0,
              "excluded" => 0,
              "invalid" => 0
            }

            embedded!("timing-#{id}", LibraryTestPartitions.timing_path(id), timing)
          end)

        combined = %{
          "schema_version" => "sigra.library-partitions/v1",
          "execution_mode" => "sequential",
          "ordinary_universe" => %{
            "paths" => paths,
            "count" => 2,
            "missing" => [],
            "stale" => [],
            "duplicate" => [],
            "scaffold_leaks" => []
          },
          "partitions" =>
            Enum.map(Enum.with_index(paths, 1), fn {path, id} ->
              %{
                "id" => id,
                "paths" => [path],
                "manifest_sha256" => LibraryTestPartitions.manifest_sha256([path]),
                "timing_receipt_path" => LibraryTestPartitions.timing_path(id),
                "start_ms" => id * 100,
                "end_ms" => id * 100 + 10,
                "duration_ms" => 10,
                "conclusion" => "success",
                "exit_status" => 0
              }
            end)
        }

        %{
          "ordinal" => ordinal,
          "combined" => embedded!("combined", "/tmp/sigra-library-partitions.json", combined),
          "timings" => timings
        }
      end

    calibration = %{
      "schema_version" => "sigra.library-partition-calibration/v2",
      "source" => %{
        "implementation_commit" => @immutable_source_commit,
        "blocked_summary_commit" => "81afbf0cafcf7dcf380d728a03053c42cdccdaa0",
        "collection_command" =>
          "ASDF_ERLANG_VERSION=28.4.1 MIX_ENV=test bash scripts/ci/library-partitions.sh",
        "sample_count" => 3,
        "aggregation" => "median(max(1,sum(time_us)))"
      },
      "ordinary_universe" => %{
        "paths" => paths,
        "count" => 2,
        "nul_manifest_sha256" => LibraryTestPartitions.ordinary_universe_sha256(paths),
        "source_files" => source_files
      },
      "limits" => %{
        "artifact_bytes" => 8_388_608,
        "combined_bytes" => 1_048_576,
        "timing_bytes" => 1_048_576,
        "sample_count" => 3,
        "combined_per_sample" => 1,
        "timings_per_sample" => 2,
        "partitions" => [1, 2]
      },
      "samples" => samples,
      "derived_costs" => costs
    }

    calibration_path = Path.join(root, "calibration.json")
    manifest_path = Path.join(root, "manifest.json")
    File.write!(calibration_path, JSON.encode!(calibration))

    manifest =
      manifest_for!(
        calibration_path,
        @immutable_source_commit,
        @immutable_source_tree,
        source_files
      )

    File.write!(manifest_path, JSON.encode!(manifest))
    on_exit(fn -> File.rm_rf!(root) end)

    %{
      root: root,
      paths: paths,
      calibration_path: calibration_path,
      manifest_path: manifest_path,
      manifest: manifest,
      opts: [
        root: root,
        path: calibration_path,
        manifest_path: manifest_path,
        ordinary_paths: paths
      ]
    }
  end

  defp shallow_repository_fixture! do
    source_root = File.cwd!()

    root =
      Path.join(
        System.tmp_dir!(),
        "sigra-shallow-calibration-fixture-#{System.unique_integer([:positive])}"
      )

    ordinary_paths = LibraryTestPartitions.current_ordinary_paths!()

    Enum.each(ordinary_paths, fn path ->
      target = Path.join(root, path)
      File.mkdir_p!(Path.dirname(target))
      File.cp!(Path.join(source_root, path), target)
    end)

    Enum.each(LibraryTestPartitions.scaffold_paths(), fn path ->
      target = Path.join(root, path)
      File.mkdir_p!(Path.dirname(target))
      File.cp!(Path.join(source_root, path), target)
    end)

    calibration = @calibration_path |> File.read!() |> JSON.decode!()

    source_files =
      Enum.map(calibration["ordinary_universe"]["source_files"], fn row ->
        if row["path"] == "test/support/ci/library_test_partitions_test.exs" do
          source_row!(root, row["path"])
        else
          row
        end
      end)

    calibration = put_in(calibration, ["ordinary_universe", "source_files"], source_files)
    calibration_path = Path.join(root, @calibration_path)
    manifest_path = Path.join(root, @manifest_path)
    File.mkdir_p!(Path.dirname(calibration_path))
    File.write!(calibration_path, JSON.encode!(calibration))

    manifest = @manifest_path |> File.read!() |> JSON.decode!()

    manifest =
      manifest
      |> put_in(["source_snapshot", "commit"], @immutable_source_commit)
      |> put_in(["source_snapshot", "tree"], @immutable_source_tree)
      |> put_in(["ordinary_source_index_sha256"], digest(JSON.encode!(source_files) <> "\n"))
      |> put_in(["calibration", "byte_count"], File.stat!(calibration_path).size)
      |> put_in(["calibration", "sha256"], digest(File.read!(calibration_path)))

    File.write!(manifest_path, JSON.encode!(manifest))
    {_, 0} = fixture_git!(root, ["init", "--quiet"])
    {_, 0} = fixture_git!(root, ["add", "test", ".planning"])

    {_, 0} =
      fixture_git!(root, [
        "-c",
        "user.name=Sigra",
        "-c",
        "user.email=sigra@example.test",
        "commit",
        "-m",
        "shallow candidate",
        "--quiet"
      ])

    on_exit(fn -> File.rm_rf!(root) end)

    %{
      root: root,
      ordinary_paths: ordinary_paths,
      calibration_path: calibration_path,
      manifest_path: manifest_path
    }
  end

  defp install_exact_provenance_object!(root) do
    payload =
      "tree 02bb907f075b1428d89bb87e519c0e0d8810fcd9\n" <>
        "parent 47f9578fc97edc63603953d446e79fac884326c3\n" <>
        "author Sigra Evidence <ci@sigra.dev> 1788998400 +0000\n" <>
        "committer Sigra Evidence <ci@sigra.dev> 1788998400 +0000\n" <>
        "\n" <>
        "test(235.1-34): freeze identity-safe ordinary source\n"

    assert byte_size(payload) == 259

    payload_path = Path.join(root, ".git/sigra-provenance-commit")
    File.write!(payload_path, payload)

    {object_id, 0} =
      System.cmd(
        "sh",
        [
          "-c",
          ~s(exec "$1" -C "$2" hash-object -t commit -w --stdin < "$3"),
          "sigra-provenance-hash-object",
          System.find_executable("git"),
          root,
          payload_path
        ],
        stderr_to_stdout: true,
        env: fixture_git_env()
      )

    File.rm!(payload_path)

    assert String.trim(object_id) == @immutable_source_commit
  end

  defp assert_standalone_repository!(root) do
    assert File.dir?(Path.join(root, ".git"))
    refute File.regular?(Path.join(root, ".git"))
    refute File.exists?(Path.join(root, ".git/commondir"))
    refute File.exists?(Path.join(root, ".git/gitdir"))
    refute File.exists?(Path.join(root, ".git/objects/info/alternates"))

    {common_dir, 0} = fixture_git!(root, ["rev-parse", "--git-common-dir"])
    assert String.trim(common_dir) == ".git"

    {objects_dir, 0} = fixture_git!(root, ["rev-parse", "--git-path", "objects"])
    assert String.trim(objects_dir) == ".git/objects"

    {remotes, 0} = fixture_git!(root, ["remote"])
    assert String.trim(remotes) == ""
  end

  defp assert_git_object_missing!(root, object, type) do
    {_output, status} = fixture_git!(root, ["cat-file", "-e", "#{object}^{#{type}}"])
    assert status != 0
  end

  defp assert_git_object_present!(root, object, type) do
    {actual_type, 0} = fixture_git!(root, ["cat-file", "-t", object])
    assert String.trim(actual_type) == type
  end

  defp fixture_git!(root, args, opts \\ []) do
    System.cmd(
      "git",
      ["-C", root | args],
      Keyword.merge([stderr_to_stdout: true, env: fixture_git_env()], opts)
    )
  end

  defp fixture_git_env do
    [
      {"GIT_ALTERNATE_OBJECT_DIRECTORIES", nil},
      {"GIT_OBJECT_DIRECTORY", nil},
      {"GIT_COMMON_DIR", nil},
      {"GIT_DIR", nil},
      {"GIT_WORK_TREE", nil}
    ]
  end

  defp assert_fixture_mutation!(message, mutate) do
    fixture = shallow_repository_fixture!()
    mutate.(fixture)

    assert_raise ArgumentError, message, fn ->
      LibraryTestPartitions.load_calibration!(root: fixture.root)
    end
  end

  defp rewrite_bound_fixture!(fixture, rewrite) do
    calibration = fixture.calibration_path |> File.read!() |> JSON.decode!()
    manifest = fixture.manifest_path |> File.read!() |> JSON.decode!()
    {calibration, manifest} = rewrite.(calibration, manifest)
    File.write!(fixture.calibration_path, JSON.encode!(calibration))
    bytes = File.read!(fixture.calibration_path)

    manifest =
      manifest
      |> put_in(["calibration", "byte_count"], byte_size(bytes))
      |> put_in(["calibration", "sha256"], digest(bytes))

    File.write!(fixture.manifest_path, JSON.encode!(manifest))
  end

  defp source_row!(root, path) do
    bytes = File.read!(Path.join(root, path))
    %{"path" => path, "byte_count" => byte_size(bytes), "sha256" => digest(bytes)}
  end

  defp embedded!(role, source_path, value) do
    payload = JSON.encode!(value)

    %{
      "role" => role,
      "source_path" => source_path,
      "byte_count" => byte_size(payload),
      "sha256" => digest(payload),
      "payload_base64" => Base.encode64(payload)
    }
  end

  defp manifest_for!(calibration_path, commit, tree, source_files) do
    bytes = File.read!(calibration_path)
    canonical = JSON.encode!(source_files) <> "\n"

    %{
      "schema_version" => "sigra.library-partition-calibration-manifest/v1",
      "source_snapshot" => %{"commit" => commit, "tree" => tree},
      "calibration" => %{
        "path" => Path.basename(calibration_path),
        "byte_count" => byte_size(bytes),
        "sha256" => digest(bytes)
      },
      "ordinary_source_index_sha256" => digest(canonical),
      "sample_count" => 3,
      "payload_count" => 9
    }
  end

  defp write_bound_fixture!(fixture, calibration, manifest) do
    File.write!(fixture.calibration_path, JSON.encode!(calibration))
    bytes = File.read!(fixture.calibration_path)

    rebound =
      put_in(manifest, ["calibration", "byte_count"], byte_size(bytes))
      |> put_in(["calibration", "sha256"], digest(bytes))

    File.write!(fixture.manifest_path, JSON.encode!(rebound))
  end

  defp digest(bytes), do: :crypto.hash(:sha256, bytes) |> Base.encode16(case: :lower)

  defp owner(partitions, path) do
    Enum.find([1, 2], &(path in partitions[&1].paths))
  end
end
