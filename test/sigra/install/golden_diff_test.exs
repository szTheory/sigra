defmodule Sigra.Install.GoldenDiffTest do
  @moduledoc """
  Phase 11 regression barrier: proves that `mix sigra.install --yes` produces a
  tree and stdout output byte-identical to the pre-refactor baseline captured
  in `test/fixtures/install_golden/`.

  This test is deliberately landed in Wave 0 — BEFORE any generator refactor
  work begins in Waves 1+. Every subsequent commit in Phase 11 is gated
  against this test's green state. Any drift in template content, injection
  output, or summary formatting fails the build loudly, with a unified diff
  of the first divergent file.

  ## Fixture shape

  `test/fixtures/install_golden/`
    ├── STDOUT.txt                        # normalized captured stdout
    └── tree/                             # normalized file tree
        ├── lib/...
        ├── priv/repo/migrations/TIMESTAMP_*.exs
        ├── config/...
        └── test/support/...

  Paths under `tree/` mirror the target app layout. Migration filenames have
  had their 14-digit timestamp prefix replaced with `TIMESTAMP_` so runs are
  deterministic. Migration file *contents* are byte-identical (D-05).

  ## Regeneration (do not do this casually)

  If a legitimate template change lands, regenerate the fixture with the
  runbook procedure documented in `.planning/phases/11-generator-feature-system/11-01-SUMMARY.md`
  and review the resulting diff carefully before committing.
  """

  use ExUnit.Case, async: false

  alias Sigra.Test.InstallFixture

  @moduletag :golden
  @moduletag timeout: 300_000
  @moduletag :scaffold

  @fixture_dir Path.expand("../../fixtures/install_golden", __DIR__)
  @fixture_tree_dir Path.join(@fixture_dir, "tree")
  @fixture_stdout Path.join(@fixture_dir, "STDOUT.txt")

  setup_all do
    ensure_fixture_present!()
    {:ok, fixture_dir: @fixture_dir}
  end

  describe "golden diff" do
    @describetag :integration

    test "generated tree matches committed fixture byte-for-byte (migration filenames normalized)" do
      {:ok, %{app_dir: app_dir, baseline_paths: baseline}} = run_installer()

      try do
        actual = InstallFixture.normalize_tree(app_dir, baseline)
        expected = read_fixture_tree()

        assert_tree_equal(actual, expected)
      after
        File.rm_rf!(Path.dirname(app_dir))
      end
    end

    test "captured stdout matches committed STDOUT.txt after normalization" do
      {:ok, %{app_dir: app_dir, stdout: raw}} = run_installer()

      try do
        actual = InstallFixture.normalize_stdout(raw, app_dir)
        expected = File.read!(@fixture_stdout)

        if actual != expected do
          diff = render_diff(expected, actual)
          flunk("STDOUT diverges from fixture:\n#{diff}")
        end
      after
        File.rm_rf!(Path.dirname(app_dir))
      end
    end
  end

  # -- helpers ----------------------------------------------------------------

  defp run_installer do
    InstallFixture.setup_tmp_app()
  end

  defp ensure_fixture_present! do
    cond do
      not File.dir?(@fixture_tree_dir) ->
        flunk_with_runbook("fixture tree directory missing: #{@fixture_tree_dir}")

      not File.regular?(@fixture_stdout) ->
        flunk_with_runbook("fixture STDOUT.txt missing: #{@fixture_stdout}")

      fixture_tree_empty?() ->
        flunk_with_runbook("fixture tree directory is empty: #{@fixture_tree_dir}")

      true ->
        :ok
    end
  end

  defp fixture_tree_empty? do
    case File.ls(@fixture_tree_dir) do
      {:ok, entries} -> Enum.empty?(entries)
      _ -> true
    end
  end

  defp flunk_with_runbook(reason) do
    raise """
    Golden fixture is missing or empty.

    Reason: #{reason}

    The golden fixture is the Phase 11 regression barrier and must be
    captured from the PRE-REFACTOR monolith before any generator
    decomposition work begins.

    Run the capture runbook documented in:
      .planning/phases/11-generator-feature-system/11-01-SUMMARY.md

    Summary:
      1. From a clean checkout of main, run:
         mix test test/sigra/install/golden_diff_test.exs --only snapshot
         (or the helper mix task once it exists)
      2. Commit the resulting test/fixtures/install_golden/ directory.
      3. Re-run this test — it should now pass.
    """
  end

  defp read_fixture_tree do
    @fixture_tree_dir
    |> Path.join("**")
    |> Path.wildcard(match_dot: true)
    |> Enum.filter(&File.regular?/1)
    |> Enum.map(fn abs_path ->
      rel = Path.relative_to(abs_path, @fixture_tree_dir)
      raw = File.read!(abs_path)
      norm_rel = InstallFixture.normalize_path_for_golden(rel)
      {norm_rel, InstallFixture.normalize_content_for_golden(norm_rel, raw)}
    end)
    |> Enum.sort_by(&elem(&1, 0))
  end

  defp assert_tree_equal(actual, expected) do
    actual_paths = actual |> Enum.map(&elem(&1, 0)) |> Enum.sort()
    expected_paths = expected |> Enum.map(&elem(&1, 0)) |> Enum.sort()

    missing = expected_paths -- actual_paths
    extra = actual_paths -- expected_paths

    if missing != [] or extra != [] do
      flunk("""
      File set differs from golden fixture.

        Missing from generated output (in fixture but not generated):
          #{Enum.join(missing, "\n      ")}

        Extra in generated output (generated but not in fixture):
          #{Enum.join(extra, "\n      ")}

      If a template was legitimately added/removed/renamed, regenerate the
      fixture per the runbook. Otherwise the refactor has drifted.
      """)
    end

    expected_map = Map.new(expected)

    for {path, actual_content} <- actual do
      expected_content = Map.fetch!(expected_map, path)

      if actual_content != expected_content do
        flunk("""
        Content differs at #{path}:

        #{render_diff(expected_content, actual_content)}

        sizes: expected #{byte_size(expected_content)} bytes, actual #{byte_size(actual_content)} bytes
        first_mismatch: #{first_mismatch_offset(expected_content, actual_content)}
        """)
      end
    end

    :ok
  end

  defp first_mismatch_offset(a, b) do
    max_i = min(byte_size(a), byte_size(b)) - 1

    case max_i do
      x when x < 0 ->
        "n/a (one side empty)"

      _ ->
        case Enum.find(0..max_i, fn i -> binary_part(a, i, 1) != binary_part(b, i, 1) end) do
          nil ->
            "eof (one side longer)"

          i ->
            lo = max(0, i - 12)
            la = min(byte_size(a), i + 12) - lo
            lb = min(byte_size(b), i + 12) - lo

            """
            byte offset #{i}
              expected: #{inspect(binary_part(a, lo, la), binaries: :as_binaries)}
              actual:   #{inspect(binary_part(b, lo, lb), binaries: :as_binaries)}
            """
        end
    end
  end

  defp render_diff(expected, actual) do
    case String.myers_difference(expected, actual) do
      diff when is_list(diff) ->
        diff
        |> Enum.map(fn
          {:eq, _} -> ""
          {:del, s} -> "- " <> inspect(s)
          {:ins, s} -> "+ " <> inspect(s)
        end)
        |> Enum.reject(&(&1 == ""))
        |> Enum.join("\n")
    end
  end
end
