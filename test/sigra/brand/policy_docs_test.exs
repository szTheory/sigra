defmodule Sigra.Brand.PolicyDocsTest do
  use ExUnit.Case, async: true

  @adr ".planning/decisions/005-brand-adoption-compatibility-policy.md"
  @guide "guides/reference/brand-compatibility.md"
  @upgrade_guide "guides/introduction/upgrading-to-v1.51.md"
  @contract "guides/introduction/contract.md"

  @adr_headings [
    "Owner decision table",
    "Frozen list",
    "Add-only list",
    "Ownership lanes",
    "Surface map",
    "Recorded decisions"
  ]

  @decision_terms [
    "Profile defaults frozen",
    "--sg-font-sans",
    "--sg-font-mono",
    "minor release",
    "no `!` marker",
    "BREAKING footer",
    "rename table",
    "Suspended",
    "seven-day",
    "Deletion scheduled",
    "PNG-lane policy is park"
  ]

  @guide_headings [
    "Scope and audience",
    "Frozen list",
    "Add-only list",
    "Ownership lanes",
    "Surface map",
    "Consumed brand subset",
    "SemVer and changelog treatment",
    "Upgrade notes"
  ]

  @upgrade_headings [
    "Before you start",
    "Ownership lanes",
    "Generated auth message changes",
    "Admin token value changes",
    "Release notes"
  ]

  # Decision numbers recorded by Phase 259 (#10 and #13 belong to later phases).
  @decision_numbers ["1", "2", "3", "4", "5", "6", "7", "8", "9", "11", "12", "14"]

  defp root, do: Path.expand("../../..", __DIR__)
  defp path(rel), do: Path.join(root(), rel)
  defp read!(rel), do: rel |> path() |> File.read!()

  defp h2(title), do: "\n## " <> title <> "\n"

  # Pure helper: the terms from `terms` that `content` does not contain.
  defp missing_terms(content, terms) do
    Enum.reject(terms, &String.contains?(content, &1))
  end

  # Pure helper: the text from an H2 heading line to the next H2 (or the end).
  # Returns "" when the heading is absent, so callers assert on the content.
  defp section_slice(content, heading) do
    marker = "\n" <> heading <> "\n"

    case :binary.match(content, marker) do
      {start, len} ->
        rest = binary_part(content, start + len, byte_size(content) - start - len)

        case :binary.match(rest, "\n## ") do
          {stop, _} -> binary_part(rest, 0, stop)
          :nomatch -> rest
        end

      :nomatch ->
        ""
    end
  end

  # Pure helper: trimmed cells of one markdown table line.
  defp cells(line) do
    line |> String.trim() |> String.trim("|") |> String.split("|") |> Enum.map(&String.trim/1)
  end

  # Pure helper: byte offset of `needle` in `body`; fails the test by name when absent.
  defp byte_index!(body, needle) do
    case :binary.match(body, needle) do
      {index, _length} -> index
      :nomatch -> flunk("expected to find #{inspect(needle)}")
    end
  end

  # Pure helper: number of non-overlapping occurrences of `needle` in `body`.
  defp occurrences(body, needle), do: length(:binary.matches(body, needle))

  # Pure helper: data rows (cell lists) of the first table in a slice, header and
  # separator excluded.
  defp table_data_rows(slice) do
    slice
    |> String.split("\n")
    |> Enum.filter(&String.starts_with?(&1, "|"))
    |> Enum.map(&cells/1)
    |> Enum.reject(fn row -> Enum.all?(row, &Regex.match?(~r/^:?-+:?$/, &1)) end)
    |> Enum.drop(1)
  end

  describe "ADR 005" do
    test "exists and carries the required headings" do
      assert File.regular?(path(@adr)), "missing #{@adr}"

      adr = read!(@adr)
      expected = Enum.map(@adr_headings, &h2/1)

      assert String.starts_with?(adr, "# ADR 005:")
      assert missing_terms(adr, expected) == []
    end

    test "records each of the seven decisions by key term" do
      assert File.regular?(path(@adr)), "missing #{@adr}"

      adr = read!(@adr)

      assert missing_terms(adr, @decision_terms) == []
    end

    test "labels every recorded decision as confirmed with a date and none as pending" do
      assert File.regular?(path(@adr)), "missing #{@adr}"

      adr = read!(@adr)
      slice = section_slice(adr, "## Owner decision table")

      rows =
        for row <- table_data_rows(slice), into: %{} do
          {hd(row), Enum.join(row, " | ")}
        end

      others = for {num, text} <- rows, num != "12", do: {num, text}

      assert Map.keys(rows) |> Enum.sort() == Enum.sort(@decision_numbers)
      assert rows["12"] =~ "confirmed"
      assert rows["12"] =~ "2026-11-13"
      assert length(others) == 11

      assert Enum.all?(others, fn {_num, text} ->
               text =~ "Confirmed as recommended by owner" and text =~ "2026-11-15"
             end)

      assert Enum.all?(rows, fn {_num, text} -> not (text =~ ~r/pending/i) end)
      refute adr =~ "owner confirmation pending"
      refute adr =~ "awaiting owner confirmation"
      refute adr =~ "awaits owner confirmation"
    end

    test "carries the 2026-11-15 amendment with the SC-4 reading and the tracking todos" do
      assert File.regular?(path(@adr)), "missing #{@adr}"

      adr = read!(@adr)

      assert adr =~ "## Amendment 2026-11-15"
      assert adr =~ "SC-4"
      assert adr =~ "asserted, honest state"
      assert adr =~ "2026-11-13-duplicate-registration-timing-oracle.md"
      assert adr =~ "2026-11-13-passkey-options-email-existence-oracle.md"
    end

    test "surface map names a brand owner of Sigra or host for every surface" do
      assert File.regular?(path(@adr)), "missing #{@adr}"

      slice = section_slice(read!(@adr), "## Surface map")
      rows = table_data_rows(slice)
      owners = Enum.map(rows, fn [_surface, owner | _rest] -> owner end)

      assert slice =~ "Brand owner"
      assert length(rows) >= 9
      assert Enum.all?(owners, &(&1 in ["Sigra", "host"]))
      assert "Sigra" in owners
      assert "host" in owners
    end
  end

  describe "brand-compatibility guide" do
    test "exists with the eight required H2 headings and a plain-text title" do
      assert File.regular?(path(@guide)), "missing #{@guide}"

      guide = read!(@guide)

      assert String.starts_with?(guide, "# Brand and visual compatibility\n")
      assert missing_terms(guide, Enum.map(@guide_headings, &h2/1)) == []
    end

    test "surface map names a brand owner of Sigra or host for every surface" do
      assert File.regular?(path(@guide)), "missing #{@guide}"

      slice = section_slice(read!(@guide), "## Surface map")
      rows = table_data_rows(slice)
      owners = Enum.map(rows, fn [_surface, owner | _rest] -> owner end)

      assert slice =~ "Brand owner"
      assert length(rows) >= 9
      assert Enum.all?(owners, &(&1 in ["Sigra", "host"]))
      assert "Sigra" in owners
      assert "host" in owners
    end

    test "states the whole-tree pin, the compare-rather-than-overwrite rule and the changelog section" do
      assert File.regular?(path(@guide)), "missing #{@guide}"

      guide = read!(@guide)

      assert guide =~ "whole tracked tree" or guide =~ "whole tree"

      assert missing_terms(guide, ["compare rather than overwrite", "Visual and copy changes"]) ==
               []
    end

    test "carries the upgrade-note skeleton: numbered steps, command block and changes heading" do
      assert File.regular?(path(@guide)), "missing #{@guide}"

      slice = section_slice(read!(@guide), "## Upgrade notes")

      expected = [
        "\n### 1. ",
        "\n### 2. ",
        "\n### 3. ",
        "\n### 4. ",
        "\n### 5. Visual and copy changes\n",
        "\n    mix deps.update sigra\n",
        "compare rather than overwrite"
      ]

      assert missing_terms(slice, expected) == []
    end

    test "records shipped v1.51 changes and links to the detailed migration tables" do
      guide = read!(@guide)
      slice = section_slice(guide, "### 5. Visual and copy changes")
      rows = table_data_rows(slice)

      assert guide =~ "The first shipped adoption under this policy is v1.51"
      assert slice =~ "../introduction/upgrading-to-v1.51.html"

      assert Enum.map(rows, &hd/1) == [
               "Admin theme values and lockups",
               "Authentication and email wording",
               "README, HexDocs and package identity"
             ]

      assert Enum.map(rows, fn row -> Enum.at(row, 1) end) ==
               ["Host-owned", "Generated", "Library-owned"]
    end
  end

  describe "v1.51 upgrade guide" do
    test "exists and presents the upgrade sections in order" do
      assert File.regular?(path(@upgrade_guide)), "missing #{@upgrade_guide}"

      guide = read!(@upgrade_guide)
      positions = Enum.map(@upgrade_headings, &byte_index!(guide, h2(&1)))

      assert String.starts_with?(guide, "# Upgrading to v1.51\n")
      assert positions == Enum.sort(positions)
    end

    test "lists the three ownership lanes in their policy order" do
      slice = read!(@upgrade_guide) |> section_slice("## Ownership lanes")
      rows = table_data_rows(slice)

      assert slice =~ "| Lane | What changes in v1.51 | How your app receives it | What you do |"
      assert Enum.map(rows, &hd/1) == ["Library-owned", "Generated", "Host-owned"]
      assert rows |> Enum.map(&Enum.count/1) |> Enum.uniq() == [4]
    end

    test "carries all generated msgid rows and representative old/new copy" do
      slice = read!(@upgrade_guide) |> section_slice("## Generated auth message changes")
      rows = table_data_rows(slice)

      assert slice =~ "| Template | Surface | Old msgid | New msgid |"
      assert length(rows) == 10

      assert ["`core/registration_live.ex`", "Existing-account link", "`Log in`", "`Sign in`"] in rows

      assert [
               "`core/settings_live.ex`",
               "Account deletion strategy notice",
               "`Schedule account deletion according to your configured deletion strategy. After the grace period expires, Sigra finalizes the account lifecycle according to that strategy.`",
               "`Schedule account deletion according to your configured deletion strategy. After the grace period expires, the selected strategy is applied to your account.`"
             ] in rows
    end

    test "carries all token rows and representative light/dark values" do
      slice = read!(@upgrade_guide) |> section_slice("## Admin token value changes")
      rows = table_data_rows(slice)

      assert slice =~ "| Token | Old light | New light | Old dark | New dark |"
      assert length(rows) == 44

      assert ["`--sg-color-ink`", "`#151515`", "`#1F1A17`", "`#f4f1eb`", "`#F3EEE8`"] in rows

      assert ["`--sg-font-sans`", "none", "`inherit`", "none", "n/a"] in rows
    end
  end

  describe "contract.md brand section" do
    test "adds the new H2 exactly once and keeps the original H1" do
      assert File.regular?(path(@contract)), "missing #{@contract}"

      contract = read!(@contract)

      assert String.starts_with?(contract, "# Sigra 1.0 Contract\n")
      assert occurrences(contract, h2("Brand and visual compatibility")) == 1
    end

    test "places the section after SemVer And Deprecation Policy and before Security Invariants" do
      assert File.regular?(path(@contract)), "missing #{@contract}"

      contract = read!(@contract)
      semver = byte_index!(contract, h2("SemVer And Deprecation Policy"))
      brand = byte_index!(contract, h2("Brand and visual compatibility"))
      security = byte_index!(contract, h2("Security Invariants"))

      assert semver < brand and brand < security
    end

    test "points at the reference guide by backticked path, not by markdown link" do
      assert File.regular?(path(@contract)), "missing #{@contract}"

      slice = section_slice(read!(@contract), "## Brand and visual compatibility")

      assert slice =~ "`guides/reference/brand-compatibility.md`"
      refute slice =~ "]("
    end
  end

  describe "helpers (positive controls)" do
    test "planted missing term is reported, and an all-present set reports nothing" do
      content = "alpha beta gamma"

      assert missing_terms(content, ["alpha", "delta", "gamma"]) == ["delta"]
      assert missing_terms(content, ["alpha", "beta", "gamma"]) == []
    end

    test "planted removal from the real ADR turns the decision check red" do
      assert File.regular?(path(@adr)), "missing #{@adr}"

      adr = read!(@adr)
      planted = String.replace(adr, "Deletion scheduled", "")

      assert missing_terms(adr, ["Deletion scheduled"]) == []
      assert missing_terms(planted, ["Deletion scheduled"]) == ["Deletion scheduled"]
    end

    test "occurrences counts repeats, so a duplicated heading would be caught" do
      assert occurrences("## A\n## A\n", "## A\n") == 2
      assert occurrences("## A\n", "## A\n") == 1
      assert occurrences("## B\n", "## A\n") == 0
    end

    test "section_slice stops at the next H2 and returns empty for an absent heading" do
      content = "# Title\n\n## A\n\nalpha row\n\n## B\n\nbeta row\n"

      slice = section_slice(content, "## A")

      assert slice =~ "alpha row"
      refute slice =~ "beta row"
      assert section_slice(content, "## Missing") == ""
    end
  end
end
