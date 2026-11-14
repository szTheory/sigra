defmodule Sigra.Brand.FrozenSurfaceTest do
  @moduledoc """
  Add-only ratchet over the names a host application may already depend on
  (BPOL-03).

  A committed baseline (`test/fixtures/brand/frozen-surface.json`) lists, per
  category, the frozen names measured from their sources of truth. The ratchet
  asserts `baseline SUBSET-OF current` for every category: additions pass
  silently, a removal fails naming the category and the removed name.

  The baseline can only grow. The opt-in extension path writes the union of the
  committed baseline and the current extraction after passing it through
  `extend_only/2`, which refuses a proposal that would drop any committed name.
  Nothing here evaluates repo content: extraction is regex or
  `Code.string_to_quoted/1`, and fixtures are read with `JSON.decode!/1`.
  """

  use ExUnit.Case, async: true

  alias Sigra.Branding.Profile

  @root Path.expand("../../..", __DIR__)
  @baseline_path Path.join(@root, "test/fixtures/brand/frozen-surface.json")
  @schema_version "sigra.brand-frozen-surface/v1"
  @extend_env "SIGRA_BRAND_BASELINE"
  @extend_command "SIGRA_BRAND_BASELINE=extend mix test test/sigra/brand/frozen_surface_test.exs"

  @admin_css "priv/templates/sigra.install/admin/sigra_admin.css"

  # Categories this module knows how to extract. The committed baseline must
  # carry exactly these keys; a baseline key without an extractor (or an
  # extractor without a baseline key) fails loudly instead of skipping a check.
  @categories ~w(css_custom_properties_sg profile_defaults)

  # Written once through the opt-in path, before any test reads the baseline.
  # Running in `setup_all` (not in a test) keeps the write ordered ahead of the
  # async tests that read the file.
  setup_all do
    if System.get_env(@extend_env) == "extend", do: extend_baseline!()
    :ok
  end

  describe "comparator (pure)" do
    test "a removal is reported by name" do
      baseline = ["--sg-a", "--sg-b", "--sg-c"]
      current = ["--sg-a", "--sg-c"]

      assert missing(baseline, current) == ["--sg-b"]
    end

    test "an addition stays green" do
      baseline = ["--sg-a", "--sg-b"]
      current = ["--sg-a", "--sg-b", "--sg-new"]

      assert missing(baseline, current) == []
    end

    test "identical sets and an empty baseline report nothing" do
      assert missing(["x"], ["x"]) == []
      assert missing([], ["x"]) == []
    end

    test "several removals come back sorted and distinct" do
      assert missing(["c", "a", "b", "a"], ["b"]) == ["a", "c"]
    end
  end

  describe "extend-only guard (pure)" do
    test "accepts a proposal that is a superset of the committed baseline" do
      committed = %{"cat" => ["a", "b"]}
      proposed = %{"cat" => ["a", "b", "c"], "new_cat" => ["z"]}

      assert extend_only(committed, proposed) == :ok
    end

    test "accepts an identical proposal" do
      committed = %{"cat" => ["a", "b"]}

      assert extend_only(committed, committed) == :ok
    end

    test "refuses a proposal that drops a committed name" do
      committed = %{"cat" => ["a", "b"]}
      proposed = %{"cat" => ["a"]}

      assert extend_only(committed, proposed) == {:error, [{"cat", "b"}]}
    end

    test "refuses a proposal that drops a whole category" do
      committed = %{"cat" => ["a"], "other" => ["x", "y"]}
      proposed = %{"cat" => ["a"]}

      assert extend_only(committed, proposed) == {:error, [{"other", "x"}, {"other", "y"}]}
    end

    test "union never shrinks and is what the extension path would write" do
      committed = %{"cat" => ["a", "b"], "kept" => ["k"]}
      current = %{"cat" => ["b", "c"]}

      merged = union(committed, current)

      assert merged == %{"cat" => ["a", "b", "c"], "kept" => ["k"]}
      assert extend_only(committed, merged) == :ok
    end

    test "pretty/1 keeps every array element on its own line" do
      out = pretty(%{"schema_version" => "v", "categories" => %{"c" => ["a", "b"]}})

      assert out ==
               """
               {
                 "categories": {
                   "c": [
                     "a",
                     "b"
                   ]
                 },
                 "schema_version": "v"
               }
               """
    end
  end

  describe "ratchet" do
    test "the baseline file exists, carries the schema version and the known categories" do
      baseline = read_baseline!()

      assert baseline["schema_version"] == @schema_version
      assert baseline["categories"] |> Map.keys() |> Enum.sort() == Enum.sort(@categories)
    end

    for category <- @categories do
      test "#{category}: baseline is a subset of the current surface" do
        category = unquote(category)
        baseline = baseline_names!(category)
        current = extract(category)

        removed = missing(baseline, current)

        assert removed == [], removal_message(category, removed)
      end

      test "#{category}: baseline and current surface are both non-empty" do
        category = unquote(category)

        assert baseline_names!(category) != [],
               "baseline category #{category} is empty (vacuous green)"

        assert extract(category) != [],
               "extractor for #{category} found nothing: its source path moved or the pattern drifted"
      end
    end

    test "every default value of Sigra.Branding.Profile is frozen verbatim" do
      frozen = baseline_names!("profile_defaults")

      expected = [
        accent_color: "#c2410c",
        accent_foreground: "#ffffff",
        background_color: "#f7f4ee",
        surface_color: "#ffffff",
        text_color: "#171717",
        muted_color: "#6b6258",
        border_color: "#ded8cf",
        product_name: "Your app",
        logo_alt: "Application logo",
        email_from_name: "Your app",
        theme: :system,
        logo_url: nil,
        dark_logo_url: nil,
        dark_accent_color: nil,
        dark_accent_foreground: nil,
        dark_background_color: nil,
        dark_surface_color: nil,
        dark_text_color: nil,
        dark_muted_color: nil,
        dark_border_color: nil,
        support_url: nil,
        privacy_url: nil,
        terms_url: nil,
        email_from_address: nil,
        email_reply_to: nil
      ]

      defaults = Profile.defaults()
      assert map_size(defaults) == length(expected)

      for {key, value} <- expected do
        assert Map.fetch!(defaults, key) == value,
               "Profile default #{key} changed from #{inspect(value)}"

        assert encode_default(key, value) in frozen,
               "baseline does not freeze #{encode_default(key, value)}"
      end
    end

    test "a changed default is a removal of the old string" do
      frozen = ["accent_color=\"#c2410c\""]
      changed = [encode_default(:accent_color, "#000000")]

      assert missing(frozen, changed) == ["accent_color=\"#c2410c\""]
    end
  end

  # -- extraction ------------------------------------------------------------

  defp extract("profile_defaults") do
    Profile.defaults()
    |> Enum.map(fn {key, value} -> encode_default(key, value) end)
    |> Enum.sort()
  end

  defp extract("css_custom_properties_sg") do
    @admin_css
    |> read_repo!()
    |> scan(~r/--sg-[a-z0-9-]+/)
  end

  defp encode_default(key, value), do: "#{key}=" <> inspect(value)

  defp scan(text, regex) do
    regex
    |> Regex.scan(text)
    |> Enum.map(&hd/1)
    |> Enum.uniq()
    |> Enum.sort()
  end

  defp read_repo!(relative), do: @root |> Path.join(relative) |> File.read!()

  # -- comparator and guard (pure) ------------------------------------------

  defp missing(baseline, current) do
    baseline
    |> MapSet.new()
    |> MapSet.difference(MapSet.new(current))
    |> MapSet.to_list()
    |> Enum.sort()
  end

  # Returns :ok when `proposed` contains every committed name of every committed
  # category, otherwise {:error, [{category, name}]} listing what would vanish.
  defp extend_only(committed, proposed) do
    removed =
      for {category, names} <- Enum.sort(committed),
          name <- missing(names, Map.get(proposed, category, [])),
          do: {category, name}

    if removed == [], do: :ok, else: {:error, removed}
  end

  defp union(committed, current) do
    committed
    |> Map.merge(current, fn _category, old, new -> old ++ new end)
    |> Map.new(fn {category, names} -> {category, names |> Enum.uniq() |> Enum.sort()} end)
  end

  # -- baseline I/O ----------------------------------------------------------

  defp read_baseline! do
    unless File.regular?(@baseline_path) do
      flunk("""
      Frozen-surface baseline is missing: #{Path.relative_to(@baseline_path, @root)}

      Create the initial baseline (extend-only) with:

        #{@extend_command}
      """)
    end

    @baseline_path |> File.read!() |> JSON.decode!()
  end

  defp baseline_names!(category) do
    baseline = read_baseline!()

    case get_in(baseline, ["categories", category]) do
      names when is_list(names) -> names
      _ -> flunk("baseline has no category #{category}; extend it with: #{@extend_command}")
    end
  end

  defp extend_baseline! do
    committed =
      if File.regular?(@baseline_path) do
        @baseline_path |> File.read!() |> JSON.decode!() |> Map.get("categories", %{})
      else
        %{}
      end

    current = Map.new(@categories, fn category -> {category, extract(category)} end)
    proposed = union(committed, current)

    case extend_only(committed, proposed) do
      :ok ->
        File.mkdir_p!(Path.dirname(@baseline_path))

        File.write!(
          @baseline_path,
          pretty(%{"schema_version" => @schema_version, "categories" => proposed})
        )

      {:error, removed} ->
        raise "refusing to shrink the frozen-surface baseline; would drop: #{inspect(removed)}"
    end
  end

  defp removal_message(category, removed) do
    """
    Frozen surface removed in category #{category}:

      #{Enum.join(removed, "\n  ")}

    A removal is a compatibility break; additions pass. Restore the name (the
    surface is add-only). If a new name was added on purpose, extend the
    baseline (extend-only, it can never shrink) with:

      #{@extend_command}
    """
  end

  # -- serialization ---------------------------------------------------------
  #
  # The stdlib JSON module only emits compact single-line JSON, which would turn
  # every added name into a whole-file diff. This small recipe emits sorted
  # object keys, two-space indent, one object key per line as `"key": value`,
  # one array element per line and scalar leaves via JSON.encode!/1.

  defp pretty(term), do: pretty(term, 0) <> "\n"

  defp pretty(map, _level) when is_map(map) and map_size(map) == 0, do: "{}"

  defp pretty(map, level) when is_map(map) do
    pad = String.duplicate("  ", level + 1)

    body =
      map
      |> Enum.sort_by(fn {key, _value} -> to_string(key) end)
      |> Enum.map_join(",\n", fn {key, value} ->
        pad <> JSON.encode!(to_string(key)) <> ": " <> pretty(value, level + 1)
      end)

    "{\n" <> body <> "\n" <> String.duplicate("  ", level) <> "}"
  end

  defp pretty([], _level), do: "[]"

  defp pretty(list, level) when is_list(list) do
    pad = String.duplicate("  ", level + 1)
    body = Enum.map_join(list, ",\n", fn element -> pad <> pretty(element, level + 1) end)

    "[\n" <> body <> "\n" <> String.duplicate("  ", level) <> "]"
  end

  defp pretty(scalar, _level), do: JSON.encode!(scalar)
end
