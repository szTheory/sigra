defmodule Sigra.Brand.TokenMigrationTest do
  @moduledoc """
  BTOK-01, BTOK-08: the reviewed old-to-new token table and the shipped stylesheet
  must agree.

  `261-TOKEN-MIGRATION.md` (the phase directory, found by wildcard under
  `.planning/` so archiving the directory later does not break this test) holds one
  table, applied to `priv/templates/sigra.install/admin/sigra_admin.css` by hand.
  This test parses the table under `## Old to new table` and compares every row
  with what the stylesheet declares in each of the four places a theme-variant token
  lives (the light `:root`, the dark `@media` block, the explicit Light block and
  the explicit Dark block), so the table and the CSS cannot drift.

  The row check is a pure function over a parsed table and the map
  `Sigra.Test.Brand.CssContrast.blocks/1` returns, so a planted mismatch runs in
  memory and proves the check can fire. Coverage is a set equality (every
  `--sg-color-*`, `--sg-logo-*`, `--sg-weight-*`, `--sg-focus-*` and `--sg-status-*`
  token `:root` declares, plus the two font tokens), derived from the stylesheet, so
  there is no row-count threshold to guess.

  Provenance is checked against the pinned brand book: every `tokens.json` path a
  row cites must resolve to a hex the row actually ships, and the two literals the
  book states outside `tokens.json` (dark selected ground and dark control edge)
  are held once and compared with their named source.
  """

  use ExUnit.Case, async: true

  alias Sigra.Test.Brand.CssContrast

  @root Path.expand("../../..", __DIR__)
  @table_heading "## Old to new table"
  @places [:root, :root_dark, :explicit_light, :explicit_dark]

  @additive ~w(
    --sg-status-active --sg-status-unconfirmed --sg-status-locked --sg-status-deleting
    --sg-status-suspended --sg-color-selected --sg-color-selected-edge
    --sg-color-current-tab --sg-color-sunken --sg-color-control-edge
  )

  @font_tokens ~w(--sg-font-sans --sg-font-mono)

  @coverage_prefixes ["--sg-color-", "--sg-logo-", "--sg-weight-", "--sg-focus-", "--sg-status-"]

  @dispositions [
    "changed",
    "kept, no book equivalent",
    "forced",
    "additive",
    "deferred:261-04"
  ]

  @words ~w(kept inherited none n/a)

  setup_all do
    %{
      rows: table_path() |> File.read!() |> parse_table(),
      blocks: CssContrast.read_css() |> CssContrast.blocks(),
      tokens: @root |> Path.join("brand/tokens.json") |> File.read!() |> JSON.decode!()
    }
  end

  describe "the reviewed table" do
    test "is found exactly once and parses into seven-cell rows with a known disposition", %{
      rows: rows
    } do
      refute rows == [], "the `#{@table_heading}` section parsed to no rows; the parse is broken"

      for row <- rows do
        assert row.disposition in @dispositions,
               "#{row.token}: disposition #{inspect(row.disposition)} is not one of #{inspect(@dispositions)}"
      end
    end

    test "a row with the wrong number of cells, or an unknown bare word, is rejected" do
      assert_raise ArgumentError, ~r/expected 7 cells/, fn ->
        parse_table("#{@table_heading}\n\n| `--sg-a` | `#111111` | kept | n/a | n/a | src |\n")
      end

      assert_raise ArgumentError, ~r/unrecognised cell/, fn ->
        parse_table(
          "#{@table_heading}\n\n| `--sg-a` | `#111111` | sameish | n/a | n/a | src | changed |\n"
        )
      end
    end

    test "has exactly one row per token the stylesheet declares, plus the two font tokens", %{
      rows: rows,
      blocks: blocks
    } do
      expected = expected_tokens(blocks)

      refute expected == [], "the derived expected token set is empty; the derivation is broken"

      for token <- @additive do
        assert token in expected,
               "#{token} is not declared in :root, so the stylesheet is missing an additive token"
      end

      assert coverage_report(rows, expected) == %{missing: [], unexpected: [], duplicates: []}
    end

    test "coverage planted controls: a missing, a duplicated and an unexpected row are each named",
         %{rows: rows, blocks: blocks} do
      expected = expected_tokens(blocks)
      dropped = List.first(expected)
      duplicated = Enum.at(expected, 1)

      without = Enum.reject(rows, &(&1.token == dropped))
      assert coverage_report(without, expected).missing == [dropped]

      assert coverage_report(rows ++ [Enum.find(rows, &(&1.token == duplicated))], expected).duplicates ==
               [duplicated]

      stray = %{List.first(rows) | token: "--sg-color-not-a-token"}
      assert "--sg-color-not-a-token" in coverage_report(rows ++ [stray], expected).unexpected
    end

    test "every additive token has the disposition `additive`", %{rows: rows} do
      for token <- @additive do
        row = Enum.find(rows, &(&1.token == token))

        assert row, "#{token} has no row"
        assert row.disposition == "additive", "#{token} is #{row.disposition}, not additive"
      end
    end
  end

  describe "the table agrees with the shipped stylesheet" do
    test "every row's new light and dark values are what the four blocks declare", %{
      rows: rows,
      blocks: blocks
    } do
      for place <- @places do
        refute Map.fetch!(blocks, place) == [],
               "the #{place} block parsed to no --sg-* declarations; the extraction is broken"
      end

      problems = Enum.flat_map(rows, &check_row(&1, blocks))

      assert problems == [],
             "261-TOKEN-MIGRATION.md and sigra_admin.css disagree:\n  " <>
               Enum.join(problems, "\n  ")
    end

    test "every dark-overridden token is restated in explicit Light with the :root value, brand and on-brand included",
         %{blocks: blocks} do
      for token <- ["--sg-color-brand", "--sg-color-on-brand"] do
        assert declared(blocks.root_dark, token),
               "#{token} is not overridden in the dark @media block"

        assert declared(blocks.explicit_light, token),
               "#{token} is not restated in the explicit Light block, so Light would lose to a dark OS"
      end

      offenders =
        for {token, _value} <- blocks.root_dark,
            not same?(declared(blocks.explicit_light, token), declared(blocks.root, token)),
            do: token

      assert Enum.uniq(offenders) == [],
             "explicit Light must restate the :root value of: #{inspect(Enum.uniq(offenders))}"
    end

    test "the ten additive tokens are literal hex in all four blocks", %{blocks: blocks} do
      for token <- @additive, place <- @places do
        value = declared(Map.fetch!(blocks, place), token)

        assert value, "#{token} is not declared in the #{place} block"

        assert value =~ ~r/\A#[0-9A-Fa-f]{6}\z/,
               "#{token} in the #{place} block must be a literal hex, not #{inspect(value)}"
      end
    end

    test "--sg-focus-ring is the two-layer ring in all four blocks", %{blocks: blocks} do
      values =
        for place <- @places do
          value = declared(Map.fetch!(blocks, place), "--sg-focus-ring")
          assert value, "--sg-focus-ring is not declared in the #{place} block"

          for reference <- [
                "var(--sg-color-brand-strong)",
                "var(--sg-focus-ring-offset)",
                "var(--sg-color-subtle)"
              ] do
            assert value =~ reference,
                   "--sg-focus-ring in the #{place} block must use #{reference}: #{inspect(value)}"
          end

          value
        end

      assert values |> Enum.map(&norm/1) |> Enum.uniq() |> length() == 1,
             "--sg-focus-ring differs between blocks: #{inspect(values)}"
    end

    test "planted control: a row whose new value is wrong is reported, in memory" do
      blocks = %{
        root: [{"--sg-a", "#111111"}],
        root_dark: [{"--sg-a", "#EEEEEE"}],
        explicit_light: [{"--sg-a", "#111111"}],
        explicit_dark: [{"--sg-a", "#EEEEEE"}]
      }

      good = row("--sg-a", {:literal, "#111111"}, {:literal, "#EEEEEE"})

      assert check_row(good, blocks) == []

      wrong_light = %{good | new_light: {:literal, "#222222"}}
      problems = check_row(wrong_light, blocks)
      assert length(problems) == 2
      assert Enum.all?(problems, &(&1 =~ "--sg-a"))
      assert Enum.any?(problems, &(&1 =~ ":root"))

      wrong_dark = %{good | new_dark: {:literal, "#222222"}}
      assert length(check_row(wrong_dark, blocks)) == 2

      unrestated = %{blocks | explicit_light: []}
      assert [problem] = check_row(good, unrestated)
      assert problem =~ "explicit Light"

      undeclared_dark = %{blocks | root_dark: [], explicit_dark: []}
      assert length(check_row(good, undeclared_dark)) == 2

      kept = %{good | new_light: {:word, "kept"}, old_light: {:literal, "#333333"}}
      assert Enum.any?(check_row(kept, blocks), &(&1 =~ "#333333"))

      assert check_row(
               %{good | disposition: "deferred:261-04", new_light: {:literal, "#222222"}},
               blocks
             ) ==
               []
    end
  end

  describe "provenance" do
    test "every tokens.json path a row cites resolves to a hex that row ships", %{
      rows: rows,
      tokens: tokens
    } do
      cited = Enum.flat_map(rows, &cited_paths/1)

      refute cited == [], "no row cites a tokens.json path; the Source parse is broken"

      problems = Enum.flat_map(rows, &source_problems(&1, tokens))

      assert problems == [],
             "Source cells disagree with brand/tokens.json:\n  " <> Enum.join(problems, "\n  ")
    end

    test "the cited-path check fires on a planted wrong hex and a planted missing path", %{
      tokens: tokens
    } do
      wrong =
        row("--sg-color-ink", {:literal, "#000000"}, {:literal, "#F3EEE8"},
          source: "color.light.soot / color.dark.chalk"
        )

      assert [problem] = source_problems(wrong, tokens)
      assert problem =~ "color.light.soot"

      missing =
        row("--sg-a", {:literal, "#111111"}, {:literal, "#222222"}, source: "color.light.nope")

      assert [problem] = source_problems(missing, tokens)
      assert problem =~ "does not resolve"
    end

    test "the two literals tokens.json lacks are held once and match their named source", %{
      rows: rows
    } do
      selected = Enum.find(rows, &(&1.token == "--sg-color-selected"))
      edge = Enum.find(rows, &(&1.token == "--sg-color-control-edge"))

      assert selected.source =~ "brand.json contrastPairs[selected-row]"
      assert edge.source =~ "BRAND.md control-edge"

      brand = @root |> Path.join("brand/brand.json") |> File.read!() |> JSON.decode!()
      pair = Enum.find(brand["color"]["contrastPairs"], &(&1["id"] == "selected-row"))

      assert same?(pair["dark"]["ground"], literal(selected.new_dark))
      assert same?(pair["light"]["ground"], literal(selected.new_light))

      book = @root |> Path.join("brand/BRAND.md") |> File.read!() |> String.downcase()

      assert book =~ String.downcase(literal(edge.new_dark)),
             "BRAND.md no longer states the dark control edge #{literal(edge.new_dark)}"

      assert literal(selected.new_dark) == "#33281F"
      assert literal(edge.new_dark) == "#8B7D72"
    end
  end

  # -- table ---------------------------------------------------------------------

  defp table_path do
    case Path.wildcard(Path.join(@root, ".planning/**/261-TOKEN-MIGRATION.md")) do
      [path] ->
        path

      paths ->
        flunk(
          "expected exactly one 261-TOKEN-MIGRATION.md under .planning/, found #{length(paths)}: " <>
            inspect(paths)
        )
    end
  end

  # Only the rows of the table under `## Old to new table` are machine-read; the
  # later sections use their own headings.
  defp parse_table(markdown) do
    markdown
    |> String.split("\n")
    |> Enum.drop_while(&(String.trim_trailing(&1) != @table_heading))
    |> Enum.drop(1)
    |> Enum.take_while(&(not String.starts_with?(&1, "## ")))
    |> Enum.filter(&String.starts_with?(&1, "| `--sg-"))
    |> Enum.map(&parse_row/1)
  end

  defp parse_row(line) do
    cells =
      line
      |> String.trim()
      |> String.trim_leading("|")
      |> String.trim_trailing("|")
      |> then(&Regex.split(~r/(?<!\\)\|/, &1))
      |> Enum.map(&(&1 |> String.trim() |> String.replace("\\|", "|")))

    case cells do
      [token, old_light, new_light, old_dark, new_dark, source, disposition] ->
        %{
          token: unwrap(token),
          old_light: cell(old_light),
          new_light: cell(new_light),
          old_dark: cell(old_dark),
          new_dark: cell(new_dark),
          source: source,
          disposition: disposition
        }

      _other ->
        raise ArgumentError, "expected 7 cells (got #{length(cells)}) in: #{line}"
    end
  end

  defp unwrap(text), do: text |> String.trim_leading("`") |> String.trim_trailing("`")

  defp cell("`" <> _rest = text) do
    if String.length(text) > 2 and String.ends_with?(text, "`"),
      do: {:literal, String.slice(text, 1..-2//1)},
      else: raise(ArgumentError, "unrecognised cell: #{inspect(text)}")
  end

  defp cell(word) when word in @words, do: {:word, word}
  defp cell(other), do: raise(ArgumentError, "unrecognised cell: #{inspect(other)}")

  defp literal({:literal, value}), do: value

  defp row(token, new_light, new_dark, opts \\ []) do
    %{
      token: token,
      old_light: {:literal, "#000000"},
      new_light: new_light,
      old_dark: {:literal, "#FFFFFF"},
      new_dark: new_dark,
      source: Keyword.get(opts, :source, "test"),
      disposition: "changed"
    }
  end

  # -- coverage ------------------------------------------------------------------

  defp expected_tokens(blocks) do
    blocks.root
    |> Enum.map(&elem(&1, 0))
    |> Enum.filter(&String.starts_with?(&1, @coverage_prefixes))
    |> Enum.concat(@font_tokens)
    |> Enum.uniq()
    |> Enum.sort()
  end

  defp coverage_report(rows, expected) do
    names = Enum.map(rows, & &1.token)
    expected = MapSet.new(expected)

    %{
      missing: expected |> MapSet.difference(MapSet.new(names)) |> Enum.sort(),
      unexpected: names |> MapSet.new() |> MapSet.difference(expected) |> Enum.sort(),
      duplicates:
        names
        |> Enum.frequencies()
        |> Enum.filter(fn {_token, count} -> count > 1 end)
        |> Enum.map(&elem(&1, 0))
        |> Enum.sort()
    }
  end

  # -- row check -----------------------------------------------------------------

  # Pure: a parsed row and the four parsed blocks in, a list of problems out. A row
  # a later plan owns (`deferred:261-04`) is not compared yet.
  defp check_row(%{disposition: "deferred:261-04"}, _blocks), do: []

  defp check_row(row, blocks) do
    with {:ok, light} <- effective_light(row),
         {:ok, dark} <- effective_dark(row, light) do
      light_problems(row.token, light, dark, blocks) ++ dark_problems(row.token, dark, blocks)
    else
      :error -> ["#{row.token}: the light or dark cells cannot be interpreted: #{inspect(row)}"]
    end
  end

  defp effective_light(%{new_light: {:literal, value}}), do: {:ok, value}

  defp effective_light(%{new_light: {:word, "kept"}, old_light: {:literal, value}}),
    do: {:ok, value}

  defp effective_light(_row), do: :error

  defp effective_dark(%{new_dark: {:literal, value}}, _light), do: {:ok, {:declared, value}}
  defp effective_dark(%{new_dark: {:word, "n/a"}}, _light), do: {:ok, :skip}

  defp effective_dark(%{new_dark: {:word, "kept"}, old_dark: {:literal, value}}, _light),
    do: {:ok, {:declared, value}}

  defp effective_dark(%{new_dark: {:word, "kept"}, old_dark: {:word, "inherited"}}, light),
    do: {:ok, {:inherits, light}}

  defp effective_dark(_row, _light), do: :error

  # `:root` must declare the light value. The explicit Light block must restate it
  # when the token is overridden in dark (otherwise Light loses to a dark OS), and
  # when it restates it anyway the value must agree.
  defp light_problems(token, light, dark, blocks) do
    restated = if match?({:declared, _}, dark), do: :required, else: :optional

    expect(token, ":root", declared(blocks.root, token), light, :required) ++
      expect(token, "explicit Light", declared(blocks.explicit_light, token), light, restated)
  end

  defp dark_problems(_token, :skip, _blocks), do: []

  defp dark_problems(token, {:declared, value}, blocks) do
    expect(token, "dark @media", declared(blocks.root_dark, token), value, :required) ++
      expect(token, "explicit Dark", declared(blocks.explicit_dark, token), value, :required)
  end

  defp dark_problems(token, {:inherits, value}, blocks) do
    expect(token, "dark @media", declared(blocks.root_dark, token), value, :optional) ++
      expect(token, "explicit Dark", declared(blocks.explicit_dark, token), value, :optional)
  end

  defp expect(token, place, nil, expected, :required),
    do: ["#{token}: not declared in #{place}; the table says #{inspect(expected)}"]

  defp expect(_token, _place, nil, _expected, :optional), do: []

  defp expect(token, place, actual, expected, _requirement) do
    if same?(actual, expected),
      do: [],
      else: [
        "#{token}: #{place} declares #{inspect(actual)}; the table says #{inspect(expected)}"
      ]
  end

  # The last declaration wins, as in CSS.
  defp declared(block, token) do
    case Enum.filter(block, &(elem(&1, 0) == token)) do
      [] -> nil
      declarations -> declarations |> List.last() |> elem(1)
    end
  end

  defp same?(left, right), do: is_binary(left) and is_binary(right) and norm(left) == norm(right)

  defp norm(value), do: value |> String.downcase() |> String.replace(~r/\s+/, "")

  # -- provenance ----------------------------------------------------------------

  defp cited_paths(row) do
    ~r/color\.(?:light|dark|logo|secondary|status|code)\.[a-z0-9-]+/
    |> Regex.scan(row.source)
    |> List.flatten()
  end

  defp source_problems(row, tokens) do
    shipped = shipped_hexes(row)

    for path <- cited_paths(row), problem <- path_problem(row.token, path, tokens, shipped) do
      problem
    end
  end

  # The light and dark values this row ends up shipping, as the table states them.
  defp shipped_hexes(row) do
    with {:ok, light} <- effective_light(row),
         {:ok, dark} <- effective_dark(row, light) do
      case dark do
        {:declared, value} -> [light, value]
        _other -> [light]
      end
    else
      :error -> []
    end
  end

  defp path_problem(token, path, tokens, shipped) do
    case get_in(tokens, String.split(path, ".")) do
      %{"$value" => %{"hex" => hex}} ->
        if Enum.any?(shipped, &same?(&1, hex)),
          do: [],
          else: ["#{token}: #{path} is #{hex}, which the row does not ship (#{inspect(shipped)})"]

      _other ->
        ["#{token}: #{path} does not resolve in brand/tokens.json"]
    end
  end
end
