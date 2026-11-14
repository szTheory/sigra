defmodule Sigra.Brand.PolicyDocsTest do
  use ExUnit.Case, async: true

  @adr ".planning/decisions/005-brand-adoption-compatibility-policy.md"

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

    test "labels decision 12 confirmed and every other recorded decision as pending" do
      assert File.regular?(path(@adr)), "missing #{@adr}"

      slice = section_slice(read!(@adr), "## Owner decision table")

      rows =
        for row <- table_data_rows(slice), into: %{} do
          {hd(row), Enum.join(row, " | ")}
        end

      assert Map.keys(rows) |> Enum.sort() == Enum.sort(@decision_numbers)
      assert rows["12"] =~ "confirmed"
      assert rows["12"] =~ "2026-11-13"
      refute rows["12"] =~ "owner confirmation pending"

      pending = for {num, text} <- rows, num != "12", do: {num, text}

      assert Enum.all?(pending, fn {_num, text} -> text =~ "owner confirmation pending" end)
      assert length(pending) == 11
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

    test "section_slice stops at the next H2 and returns empty for an absent heading" do
      content = "# Title\n\n## A\n\nalpha row\n\n## B\n\nbeta row\n"

      slice = section_slice(content, "## A")

      assert slice =~ "alpha row"
      refute slice =~ "beta row"
      assert section_slice(content, "## Missing") == ""
    end
  end
end
