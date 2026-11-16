defmodule Sigra.Brand.TokenParityTest do
  @moduledoc """
  The four-place token rule, enforced over the SHIPPED admin stylesheet (BTOK-01).

  A theme-variant `--sg-*` token lives in four blocks of
  `priv/templates/sigra.install/admin/sigra_admin.css`:

    1. the light `:root`;
    2. `@media (prefers-color-scheme: dark) { :root { ... } }` (System, dark OS);
    3. the explicit Light shell block (`html[data-sg-admin-theme="light"] .sg-admin-shell`);
    4. the explicit Dark shell block (`html[data-sg-admin-theme="dark"] .sg-admin-shell`).

  Three invariants keep them in step. Each is a pure function over the map
  `Sigra.Test.Brand.CssContrast.blocks/1` returns, so a planted violation runs in
  memory with no file written, and each has one: a clean run of a check proves
  nothing until the check has been seen to fire.

    * **Invariant 1** - the dark `@media` declarations equal the explicit-Dark
      declarations (same tokens, same values). The existing D-11 test in
      `admin_test.exs` asserts the same on raw strings and stays in place.
    * **Invariant 2** - every token the dark `@media` block overrides is also
      restated in the explicit-Light block with the `:root` value. Without it, an OS
      set to dark with the admin set to Light would render dark values. A token that
      exists only in the dark block has no `:root` value to restate, so it is
      reported, not skipped.
    * **Invariant 3** - a `:root` custom property whose value uses `var()` of a
      theme-variant token is declared in all four blocks. A `var()` resolves where it
      is declared, so an alias that lives only in `:root` stays light inside an
      explicit-Dark shell. "Theme-variant" is the dark `@media` token set plus, to a
      fixed point, any `:root` token that itself references one, because an alias of
      an alias carries the same staleness.

  If one of these goes red after a token change, the stylesheet is wrong, not the
  test: declare the token in the missing block.
  """

  use ExUnit.Case, async: true

  alias Sigra.Test.Brand.CssContrast

  @places [:root, :root_dark, :explicit_light, :explicit_dark]

  # A small stylesheet-shaped map that satisfies all three invariants. The planted
  # tests change exactly one thing in it. `--sg-inset` is the real `--sg-elev-inset`
  # shape: an alias of a theme-variant token, restated in every block.
  @good %{
    root: [
      {"--sg-ink", "#111111"},
      {"--sg-line", "#222222"},
      {"--sg-inset", "inset 0 0 0 1px var(--sg-line)"},
      {"--sg-gap", "4px"}
    ],
    root_dark: [
      {"--sg-ink", "#eeeeee"},
      {"--sg-line", "#dddddd"},
      {"--sg-inset", "inset 0 0 0 1px var(--sg-line)"}
    ],
    explicit_light: [
      {"--sg-ink", "#111111"},
      {"--sg-line", "#222222"},
      {"--sg-inset", "inset 0 0 0 1px var(--sg-line)"}
    ],
    explicit_dark: [
      {"--sg-ink", "#eeeeee"},
      {"--sg-line", "#dddddd"},
      {"--sg-inset", "inset 0 0 0 1px var(--sg-line)"}
    ]
  }

  setup_all do
    %{blocks: CssContrast.read_css() |> CssContrast.blocks()}
  end

  describe "the shipped stylesheet" do
    test "all four token places are parsed and non-empty", %{blocks: blocks} do
      for place <- @places do
        refute Map.fetch!(blocks, place) == [],
               "the #{place} block parsed to no --sg-* declarations; the extraction is broken"
      end
    end

    test "invariant 1: dark @media declarations equal explicit-dark declarations", %{
      blocks: blocks
    } do
      assert_non_vacuous(blocks)

      assert dark_parity_offenders(blocks) == [],
             "dark @media and explicit-Dark blocks diverged for: " <>
               "#{inspect(dark_parity_offenders(blocks))}. Update BOTH dark blocks together."
    end

    test "invariant 2: every dark-overridden token is restated in explicit-light with the :root value",
         %{blocks: blocks} do
      assert_non_vacuous(blocks)

      assert light_restatement_offenders(blocks) == [],
             "the explicit Light block must restate the :root value of every token the dark @media " <>
               "block overrides, or Light loses to a dark OS: " <>
               inspect(light_restatement_offenders(blocks))
    end

    test "invariant 3: an alias of a theme-variant token is declared in all four blocks", %{
      blocks: blocks
    } do
      assert_non_vacuous(blocks)

      assert alias_offenders(blocks) == [],
             "a :root token that uses var() of a theme-variant token must be declared in all four " <>
               "places (a var() resolves where it is declared): #{inspect(alias_offenders(blocks))}"
    end

    test "the alias rule is exercised: --sg-elev-inset is such an alias and is in all four blocks",
         %{blocks: blocks} do
      {"--sg-elev-inset", raw} = List.keyfind(blocks.root, "--sg-elev-inset", 0)

      assert raw =~ "var(--sg-color-line)"

      for place <- @places do
        assert List.keymember?(Map.fetch!(blocks, place), "--sg-elev-inset", 0),
               "--sg-elev-inset is missing from the #{place} block"
      end
    end
  end

  describe "the checks are pure and pass on a known-good map" do
    test "the good map satisfies all three invariants" do
      assert dark_parity_offenders(@good) == []
      assert light_restatement_offenders(@good) == []
      assert alias_offenders(@good) == []
    end
  end

  describe "positive controls: each invariant goes red on a planted violation" do
    test "invariant 1: an extra declaration on one side is reported by name" do
      planted = plant(@good, :explicit_dark, [{"--sg-extra", "#abcdef"}])

      assert dark_parity_offenders(planted) == ["--sg-extra"]
    end

    test "invariant 1: a differing value is reported by name" do
      planted = replace(@good, :explicit_dark, "--sg-ink", "#ffffff")

      assert dark_parity_offenders(planted) == ["--sg-ink"]
    end

    test "invariant 2: a token the dark block overrides but the light block omits is reported" do
      planted =
        @good
        |> plant(:root, [{"--sg-brand", "#aa0000"}])
        |> plant(:root_dark, [{"--sg-brand", "#ff0000"}])
        |> plant(:explicit_dark, [{"--sg-brand", "#ff0000"}])

      assert light_restatement_offenders(planted) == ["--sg-brand"]
    end

    test "invariant 2: a light restatement that differs from the :root value is reported" do
      planted = replace(@good, :explicit_light, "--sg-ink", "#333333")

      assert light_restatement_offenders(planted) == ["--sg-ink"]
    end

    test "invariant 2: a dark-only token with no :root value is reported, not skipped" do
      planted = plant(@good, :root_dark, [{"--sg-dark-only", "#010203"}])

      assert light_restatement_offenders(planted) == ["--sg-dark-only"]
    end

    test "invariant 3: a :root alias of a theme-variant token declared only in :root is reported" do
      planted = plant(@good, :root, [{"--sg-alias", "0 0 0 2px var(--sg-ink)"}])

      assert alias_offenders(planted) == ["--sg-alias"]
    end

    test "invariant 3: an alias missing from just one block is reported" do
      declaration = [{"--sg-alias", "var(--sg-ink)"}]

      planted =
        @good
        |> plant(:root, declaration)
        |> plant(:root_dark, declaration)
        |> plant(:explicit_light, declaration)

      assert alias_offenders(planted) == ["--sg-alias"]
    end

    test "invariant 3: an alias of an alias is reported too (the staleness is transitive)" do
      planted =
        plant(@good, :root, [{"--sg-alias", "var(--sg-ink)"}, {"--sg-alias-2", "var(--sg-alias)"}])

      assert alias_offenders(planted) == ["--sg-alias", "--sg-alias-2"]
    end

    test "invariant 3: an alias of a theme-invariant token is not reported" do
      planted = plant(@good, :root, [{"--sg-stack", "var(--sg-gap)"}])

      assert alias_offenders(planted) == []
    end

    test "planting into the real stylesheet shape is caught too", %{blocks: blocks} do
      dark_planted = plant(blocks, :explicit_dark, [{"--sg-planted", "#123456"}])
      alias_planted = plant(blocks, :root, [{"--sg-planted", "var(--sg-color-ink)"}])

      assert dark_parity_offenders(dark_planted) == ["--sg-planted"]
      assert alias_offenders(alias_planted) == ["--sg-planted"]
    end
  end

  defp plant(blocks, place, declarations) do
    Map.update!(blocks, place, &(&1 ++ declarations))
  end

  defp replace(blocks, place, token, value) do
    Map.update!(blocks, place, &List.keyreplace(&1, token, 0, {token, value}))
  end

  # -- pure checks: each returns the sorted offending token names (empty = pass) ----

  defp dark_parity_offenders(%{root_dark: media, explicit_dark: explicit}) do
    media_counts = Enum.frequencies(media)
    explicit_counts = Enum.frequencies(explicit)

    (Map.keys(media_counts) ++ Map.keys(explicit_counts))
    |> Enum.uniq()
    |> Enum.filter(&(Map.get(media_counts, &1, 0) != Map.get(explicit_counts, &1, 0)))
    |> names()
  end

  defp light_restatement_offenders(%{root: root, root_dark: media, explicit_light: light}) do
    root_values = Map.new(root)
    light_values = Map.new(light)

    media
    |> Enum.map(&elem(&1, 0))
    |> Enum.reject(fn token ->
      Map.has_key?(root_values, token) and
        Map.get(light_values, token) == Map.fetch!(root_values, token)
    end)
    |> Enum.uniq()
    |> Enum.sort()
  end

  defp alias_offenders(blocks) do
    variant = variant_tokens(blocks, MapSet.new(blocks.root_dark, &elem(&1, 0)))
    declared_everywhere = declared_in_all_places(blocks)

    blocks.root
    |> Enum.filter(fn {_token, raw} ->
      Enum.any?(references(raw), &MapSet.member?(variant, &1))
    end)
    |> Enum.map(&elem(&1, 0))
    |> Enum.reject(&MapSet.member?(declared_everywhere, &1))
    |> Enum.uniq()
    |> Enum.sort()
  end

  # Fixed point: the dark-block tokens, plus any :root token that references one.
  defp variant_tokens(blocks, variant) do
    grown =
      Enum.reduce(blocks.root, variant, fn {token, raw}, acc ->
        if Enum.any?(references(raw), &MapSet.member?(acc, &1)),
          do: MapSet.put(acc, token),
          else: acc
      end)

    if MapSet.equal?(grown, variant), do: variant, else: variant_tokens(blocks, grown)
  end

  defp declared_in_all_places(blocks) do
    @places
    |> Enum.map(fn place -> blocks |> Map.fetch!(place) |> MapSet.new(&elem(&1, 0)) end)
    |> Enum.reduce(&MapSet.intersection/2)
  end

  defp references(raw) do
    ~r/var\(\s*(--sg-[\w-]+)/
    |> Regex.scan(raw, capture: :all_but_first)
    |> List.flatten()
  end

  defp names(pairs_or_tokens) do
    pairs_or_tokens
    |> Enum.map(fn
      {token, _value} -> token
      token -> token
    end)
    |> Enum.uniq()
    |> Enum.sort()
  end

  # The real-file tests lean on these; a stylesheet that parsed to nothing would
  # make every offender list trivially empty.
  defp assert_non_vacuous(blocks) do
    for place <- @places do
      assert Map.fetch!(blocks, place) != [], "the #{place} block is empty"
    end

    assert length(blocks.root_dark) > 10, "the dark @media block is suspiciously small"
  end
end
