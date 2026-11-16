defmodule Sigra.Install.DoubleInstallTest do
  @moduledoc """
  BGEN-02: two fresh `mix sigra.install` runs produce identical output.

  `idempotency_test.exs` proves that installing twice into the SAME app writes
  nothing new. It does not prove that two independent installs agree, which is
  what the golden fixture and the Phase 262 before/after report both rely on.

  Two apps are scaffolded with `Sigra.Test.InstallFixture.setup_tmp_app/0`, then:

    * the normalized trees are equal (migration filenames and `config/*.exs`
      salts are normalized by `InstallFixture.normalize_tree/2`);
    * the normalized `mix sigra.install` stdout is equal;
    * the RAW difference, taken over the installer delta only, is confined to
      migration filenames (a wall-clock timestamp) and `config/*.exs` salt lines.

  The raw leg compares the installer delta (paths whose hash differs from the
  pre-install baseline), never the whole tree: `phx.new` writes a random
  `signing_salt` into `lib/<app>_web/endpoint.ex`, which the installer does not
  touch, so an unfiltered comparison would fail for a reason unrelated to it.

  The pure helpers (`compare_trees/2`, `raw_differences/2`, `allowed_raw_path?/1`)
  are exercised by planted controls in `Sigra.Install.DoubleInstallControlsTest`
  below, which carries no `:scaffold` tag so it runs under plain
  `mix test --exclude scaffold`.

  This file is listed in the `ci.install_golden` alias in `mix.exs`, which is an
  explicit file list; `test --exclude scaffold` skips scaffold-tagged modules, so
  an unlisted file would never run.
  """

  use ExUnit.Case, async: false

  alias Sigra.Test.InstallFixture

  @moduletag :integration
  @moduletag :scaffold
  # Two scaffolds (phx.new + deps.get + compile + install) run in setup_all.
  @moduletag timeout: 900_000

  @allowed_raw_prefixes ["priv/repo/migrations/", "config/"]

  setup_all do
    {:ok, first} = InstallFixture.setup_tmp_app()
    on_exit(fn -> File.rm_rf!(Path.dirname(first.app_dir)) end)

    {:ok, second} = InstallFixture.setup_tmp_app()
    on_exit(fn -> File.rm_rf!(Path.dirname(second.app_dir)) end)

    %{first: first, second: second}
  end

  describe "two fresh installs" do
    test "are scaffolded in independent directories", %{first: first, second: second} do
      refute first.app_dir == second.app_dir
      refute Path.dirname(first.app_dir) == Path.dirname(second.app_dir)
    end

    test "produce identical normalized trees", %{first: first, second: second} do
      tree_a = normalized_tree(first)
      tree_b = normalized_tree(second)

      assert map_size(tree_a) > 0, "the normalized tree is empty; the comparison would be vacuous"

      assert_trees_equal(tree_a, tree_b, "normalized tree")
    end

    test "produce identical normalized stdout", %{first: first, second: second} do
      stdout_a = InstallFixture.normalize_stdout(first.stdout, first.app_dir)
      stdout_b = InstallFixture.normalize_stdout(second.stdout, second.app_dir)

      assert stdout_a != "", "the normalized stdout is empty; the comparison would be vacuous"

      assert_trees_equal(%{"STDOUT" => stdout_a}, %{"STDOUT" => stdout_b}, "normalized stdout")
    end

    test "differ in the raw installer delta only by migration filenames and config salts",
         %{first: first, second: second} do
      delta_a = installer_delta(first)
      delta_b = installer_delta(second)

      assert map_size(delta_a) > 0, "the first install has an empty installer delta"
      assert map_size(delta_b) > 0, "the second install has an empty installer delta"

      differing = raw_differences(delta_a, delta_b)

      # Non-vacuity: two independent installs always differ in at least the
      # migration timestamps and the phx.new salts. An empty set would mean the
      # raw leg compared an install with itself.
      refute differing == [],
             "the raw leg saw no variance at all between two independent installs"

      outside = Enum.reject(differing, &allowed_raw_path?/1)

      assert outside == [],
             """
             The installer delta differs between two fresh installs outside the allowed paths.
             Allowed: #{inspect(@allowed_raw_prefixes)} (migration timestamps, config salts).

             Differing paths outside them:
               #{Enum.join(outside, "\n  ")}
             """
    end
  end

  # -- pure helpers (public so the controls module can reach them) --------------

  @doc false
  # Compares two `%{path => binary}` maps. `:ok` when equal, otherwise the first
  # (sorted) path that differs: `{:error, path, :only_in_first | :only_in_second}`
  # for a file present on one side, or `{:error, path, byte_offset}` for content.
  @spec compare_trees(%{String.t() => binary()}, %{String.t() => binary()}) ::
          :ok | {:error, String.t(), :only_in_first | :only_in_second | non_neg_integer()}
  def compare_trees(first, second) when is_map(first) and is_map(second) do
    (Map.keys(first) ++ Map.keys(second))
    |> Enum.uniq()
    |> Enum.sort()
    |> Enum.find_value(:ok, fn path ->
      case {Map.fetch(first, path), Map.fetch(second, path)} do
        {{:ok, same}, {:ok, same}} -> nil
        {{:ok, a}, {:ok, b}} -> {:error, path, first_diff_offset(a, b, 0)}
        {{:ok, _}, :error} -> {:error, path, :only_in_first}
        {:error, {:ok, _}} -> {:error, path, :only_in_second}
      end
    end)
  end

  @doc false
  # Paths whose hash differs between two installer deltas (`%{path => hash}`),
  # including a path present in only one of them.
  @spec raw_differences(%{String.t() => binary()}, %{String.t() => binary()}) :: [String.t()]
  def raw_differences(delta_a, delta_b) do
    (Map.keys(delta_a) ++ Map.keys(delta_b))
    |> Enum.uniq()
    |> Enum.filter(&(Map.get(delta_a, &1) != Map.get(delta_b, &1)))
    |> Enum.sort()
  end

  @doc false
  @spec allowed_raw_path?(String.t()) :: boolean()
  def allowed_raw_path?(path),
    do: Enum.any?(@allowed_raw_prefixes, &String.starts_with?(path, &1))

  defp first_diff_offset(<<byte, rest_a::binary>>, <<byte, rest_b::binary>>, offset),
    do: first_diff_offset(rest_a, rest_b, offset + 1)

  defp first_diff_offset(_a, _b, offset), do: offset

  # -- scaffold helpers ---------------------------------------------------------

  defp normalized_tree(%{app_dir: app_dir, baseline_paths: baseline}),
    do: app_dir |> InstallFixture.normalize_tree(baseline) |> Map.new()

  # The paths the installer created or modified: hash differs from the baseline.
  defp installer_delta(%{app_dir: app_dir, baseline_paths: baseline}) do
    app_dir
    |> InstallFixture.snapshot_paths()
    |> Enum.reject(fn {rel, hash} -> Map.get(baseline, rel) == hash end)
    |> Map.new()
  end

  defp assert_trees_equal(first, second, label) do
    case compare_trees(first, second) do
      :ok ->
        :ok

      {:error, path, :only_in_first} ->
        flunk("#{label}: #{path} exists in the first install but not in the second")

      {:error, path, :only_in_second} ->
        flunk("#{label}: #{path} exists in the second install but not in the first")

      {:error, path, offset} ->
        a = Map.fetch!(first, path)
        b = Map.fetch!(second, path)

        flunk("""
        #{label}: content differs at #{path}
          first differing byte: #{offset}
          sizes: first #{byte_size(a)} bytes, second #{byte_size(b)} bytes
          first:  #{context(a, offset)}
          second: #{context(b, offset)}
        """)
    end
  end

  defp context(binary, offset) do
    lo = max(0, offset - 12)
    len = min(byte_size(binary), offset + 12) - lo
    inspect(binary_part(binary, lo, max(len, 0)), binaries: :as_binaries)
  end
end

defmodule Sigra.Install.DoubleInstallControlsTest do
  @moduledoc """
  Planted controls for the pure helpers of `Sigra.Install.DoubleInstallTest`.

  No `:scaffold` tag and no scaffolding: these run in plain `mix test --exclude
  scaffold`, so the determinism comparison is proven able to fail on every
  ordinary test run, not only inside `ci.install_golden`.
  """

  use ExUnit.Case, async: true

  alias Sigra.Install.DoubleInstallTest, as: Double

  describe "compare_trees/2" do
    test "equal maps are reported as equal" do
      tree = %{"lib/a.ex" => "defmodule A do\nend\n", "config/config.exs" => "import Config\n"}

      assert Double.compare_trees(tree, tree) == :ok
    end

    test "one planted byte change is reported at the path and the byte offset" do
      first = %{"lib/a.ex" => "defmodule A do\nend\n", "lib/b.ex" => "b\n"}
      second = Map.update!(first, "lib/a.ex", &String.replace(&1, "A do", "B do"))

      assert Double.compare_trees(first, second) == {:error, "lib/a.ex", 10}
    end

    test "one appended byte is reported at the end of the shorter file" do
      first = %{"lib/a.ex" => "abc"}
      second = %{"lib/a.ex" => "abcx"}

      assert Double.compare_trees(first, second) == {:error, "lib/a.ex", 3}
    end

    test "a file present on one side only is reported with the side that has it" do
      assert Double.compare_trees(%{"a" => "1", "b" => "2"}, %{"a" => "1"}) ==
               {:error, "b", :only_in_first}

      assert Double.compare_trees(%{"a" => "1"}, %{"a" => "1", "b" => "2"}) ==
               {:error, "b", :only_in_second}
    end

    test "the first differing path in sorted order is the one reported" do
      first = %{"b" => "1", "a" => "1"}
      second = %{"b" => "2", "a" => "2"}

      assert Double.compare_trees(first, second) == {:error, "a", 0}
    end
  end

  describe "raw_differences/2 and allowed_raw_path?/1" do
    test "a changed hash and a one-sided path are both reported, sorted" do
      delta_a = %{
        "config/config.exs" => <<1>>,
        "priv/repo/migrations/20260101000000_x.exs" => <<9>>
      }

      delta_b = %{
        "config/config.exs" => <<2>>,
        "priv/repo/migrations/20260101000007_x.exs" => <<9>>
      }

      assert Double.raw_differences(delta_a, delta_b) == [
               "config/config.exs",
               "priv/repo/migrations/20260101000000_x.exs",
               "priv/repo/migrations/20260101000007_x.exs"
             ]
    end

    test "identical deltas report no difference" do
      delta = %{"lib/a.ex" => <<1>>}

      assert Double.raw_differences(delta, delta) == []
    end

    test "migration filenames and config files are allowed" do
      assert Double.allowed_raw_path?("priv/repo/migrations/20260101000000_create_users.exs")
      assert Double.allowed_raw_path?("config/runtime.exs")
    end

    test "a planted endpoint.ex salt difference is outside the allowed paths" do
      differing =
        Double.raw_differences(
          %{"lib/my_app_web/endpoint.ex" => <<1>>},
          %{"lib/my_app_web/endpoint.ex" => <<2>>}
        )

      assert differing == ["lib/my_app_web/endpoint.ex"]
      refute Enum.any?(differing, &Double.allowed_raw_path?/1)
    end

    test "a planted generated-lib difference is outside the allowed paths" do
      refute Double.allowed_raw_path?("lib/my_app/accounts/user.ex")
      refute Double.allowed_raw_path?("priv/static/assets/sigra_auth.css")
    end
  end
end
