defmodule Sigra.Brand.NameClearanceTest do
  @moduledoc """
  BPOL-04 / BCOPY-07 doc contract for ADR 006, the name search log and claims
  register.

  The record must stay what it says it is: a search log, not a clearance. This
  module asserts, with a planted control for every check so it can go red:

    * the title phrase, the same-name package and its facts, and the
      maintainer-to-confirm wording are present;
    * no clearance wording, no trademark or registered-mark symbols, and no
      GitHub owner handle (derived from `mix.exs` at run time, never written
      here);
    * every registry row id appears in backticks in the claims register, and the
      register's status agrees with the registry state (a row that is not
      `parity` may never read as proven or bounded);
    * the example-host limitation, the two decisions and their
      `confirmed as recommended` status are present;
    * every product file path the record cites exists (planning-only paths are
      checked by GSD locally and are excluded from the strict code-only PR).

  Pure filesystem; no database is touched. The repo root is resolved from
  `__DIR__`, never from the working directory.
  """
  use ExUnit.Case, async: true

  @record ".planning/decisions/006-name-clearance-search-log-and-claims-register.md"
  @announcement "docs/launch/v1.51/announcement.md"
  @registry "test/fixtures/brand/public-surfaces.json"
  @mix_exs "mix.exs"
  @closed_library_claim_id "lib-moduledoc-claims"

  @title_phrase "search log, not clearance"

  # Status kinds a claims-register row may carry, longest prefix first so that
  # "not proven" is never read as "proven".
  @status_kinds ["not proven", "by design", "bounded", "proven"]

  # Registry state -> the only status kind the register may give that row.
  @state_to_status %{
    "parity" => "bounded",
    "known_divergence" => "not proven",
    "not_proven" => "not proven",
    "by_design" => "by design"
  }

  defp root, do: Path.expand("../../..", __DIR__)
  defp read!(rel), do: root() |> Path.join(rel) |> File.read!()
  defp record, do: read!(@record)
  defp surfaces, do: @registry |> read!() |> JSON.decode!() |> Map.fetch!("surfaces")

  defp non_parity_ids,
    do: for(row <- surfaces(), row["state"] != "parity", do: row["id"])

  defp parity_ids,
    do: for(row <- surfaces(), row["state"] == "parity", do: row["id"])

  defp states, do: Map.new(surfaces(), &{&1["id"], &1["state"]})

  # Pure helper: the ids from `ids` that do not appear inside backticks in
  # `content`.
  defp missing_ids(content, ids) do
    Enum.reject(ids, &String.contains?(content, "`" <> &1 <> "`"))
  end

  # Pure helper: labels of the forbidden wording found in `content`. The symbols
  # are written as escapes so this source carries no literal glyph.
  defp forbidden_wording(content) do
    [
      {"the word cleared", fn c -> Regex.match?(~r/\bcleared\b/i, c) end},
      {"registered trademark", fn c -> Regex.match?(~r/registered\s+trademark/i, c) end},
      {"trademark symbol", fn c -> String.contains?(c, "™") end},
      {"registered-mark symbol", fn c -> String.contains?(c, "®") end}
    ]
    |> Enum.filter(fn {_label, found?} -> found?.(content) end)
    |> Enum.map(&elem(&1, 0))
  end

  # Pure helper: true when `content` spells `owner` in any letter case.
  defp mentions?(content, owner) do
    String.contains?(String.downcase(content), String.downcase(owner))
  end

  # The GitHub owner segment of `@source_url` in mix.exs, derived at run time.
  defp source_owner do
    case Regex.run(~r{@source_url\s+"https?://github\.com/([^/"]+)/}, read!(@mix_exs)) do
      [_, owner] -> owner
      _ -> flunk("could not derive the source_url owner from #{@mix_exs}")
    end
  end

  # Pure helper: text from the `## heading` line to the next `## ` heading.
  # `### ` subsections do not end it. Returns "" when the heading is absent.
  defp section(content, heading) do
    marker = "\n## " <> heading <> "\n"

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

  # Pure helper: every table line in `text` as a list of cells, header and
  # separator rows dropped.
  defp table_rows(text) do
    text
    |> String.split("\n")
    |> Enum.filter(&String.starts_with?(&1, "|"))
    |> Enum.map(&cells/1)
    |> Enum.reject(fn [first | _] -> first == "Claim" or String.starts_with?(first, "---") end)
  end

  # Pure helper: the exact status label, optionally followed by a supported
  # parenthetical or punctuation-delimited explanation, or nil.
  @status_kind_pattern Regex.compile!(
                         "\\A(?<kind>#{Enum.join(@status_kinds, "|")})(?:\\z|\\s+\\([^)]*\\)|\\s+(?:—|–|:|-)\\s+\\S.*)\\z"
                       )

  defp status_kind(cell) do
    case Regex.named_captures(@status_kind_pattern, cell) do
      %{"kind" => kind} -> kind
      nil -> nil
    end
  end

  # Pure helper: for each registry id, what is wrong with its claims-register
  # row. `rows` are `[claim, where, evidence, status]` cell lists and `states`
  # maps id => registry state. Empty list means every row agrees with the
  # registry.
  defp status_violations(rows, states) do
    for {id, state} <- states, reduce: [] do
      acc ->
        matching =
          Enum.filter(rows, fn [_c, _w, evidence, _s] -> evidence_cites?(evidence, id) end)

        expected = Map.fetch!(@state_to_status, state)

        cond do
          matching == [] -> [{id, :no_row} | acc]
          Enum.all?(matching, fn [_, _, _, s] -> status_kind(s) == expected end) -> acc
          true -> [{id, :status_mismatch} | acc]
        end
    end
  end

  defp evidence_cites?(evidence, id), do: String.contains?(evidence, "`" <> id <> "`")

  # Pure helper: backticked tokens that look like repository file paths.
  defp cited_paths(content) do
    ~r/`([A-Za-z0-9_.\/-]+\.(?:exs|ex|json|md|sha256|svg))`/
    |> Regex.scan(content, capture: :all_but_first)
    |> List.flatten()
    |> Enum.uniq()
  end

  describe "title and the same-name package" do
    test "the record exists and its first line is an H1 with the title phrase" do
      # Arrange
      path = Path.join(root(), @record)

      # Act
      first_line = path |> File.read!() |> String.split("\n", parts: 2) |> hd()

      # Assert
      assert File.regular?(path)
      assert String.starts_with?(first_line, "# ")
      assert String.contains?(first_line, @title_phrase)
    end

    test "it names crosswake_sigra with its facts and asks the maintainer to confirm" do
      # Arrange
      content = record()

      # Act
      confirms? =
        String.contains?(content, "maintainer to confirm") or
          String.contains?(content, "pending maintainer confirmation")

      # Assert
      assert String.contains?(content, "crosswake_sigra")
      assert String.contains?(content, "0.1.3")
      assert String.contains?(content, "Apache-2.0")
      assert String.contains?(content, "2026-07-03")
      assert String.contains?(content, "same GitHub owner as this repository's `source_url`")
      assert confirms?
    end

    test "the lookup table covers every registry that was searched" do
      # Arrange
      table = section(record(), "Lookup table")

      # Act
      missing =
        Enum.reject(
          ["Hex", "npm", "PyPI", "RubyGems", "crates.io", "GitHub", "2026-11-13"],
          fn t ->
            String.contains?(table, t)
          end
        )

      # Assert
      assert missing == []
    end
  end

  describe "forbidden wording" do
    test "the record carries no clearance wording and no mark symbols" do
      # Arrange
      content = record()

      # Act
      found = forbidden_wording(content)

      # Assert
      assert found == []
    end

    test "positive control: the helper flags each forbidden form in planted text" do
      # Arrange
      planted = %{
        "the word cleared" => "The name is Cleared for use.",
        "registered trademark" => "Sigra is a registered  trademark.",
        "trademark symbol" => "Sigra™",
        "registered-mark symbol" => "Sigra®"
      }

      # Act
      results = Map.new(planted, fn {label, text} -> {label, forbidden_wording(text)} end)

      # Assert
      for {label, found} <- results, do: assert(found == [label])
      assert forbidden_wording("This is a search log, not a clearance.") == []
    end

    test "the record spells no GitHub owner handle and no GitHub URL" do
      # Arrange
      content = record()
      owner = source_owner()

      # Act
      spells_owner? = mentions?(content, owner)

      # Assert
      assert owner != ""
      refute spells_owner?
      refute String.contains?(content, "github.com/")
    end

    test "positive control: the owner check sees the derived handle in planted text" do
      # Arrange
      owner = source_owner()
      planted = "see the repository of #{String.upcase(owner)} for details"

      # Act and Assert
      assert mentions?(planted, owner)
      refute mentions?("see the repository for details", owner)
    end
  end

  describe "claims register covers the surface registry" do
    test "the prose-only library claim is no longer an open registry surface" do
      # Arrange
      ids = Enum.map(surfaces(), & &1["id"])

      # Assert
      refute @closed_library_claim_id in ids
    end

    test "every non-parity registry id appears in backticks in the record" do
      # Arrange
      ids = non_parity_ids()

      # Act
      missing = missing_ids(record(), ids)

      # Assert
      assert ids != []
      assert missing == [], "ids missing from the claims register: #{inspect(missing)}"
    end

    test "every parity registry id also appears, as a bounded claim" do
      # Arrange
      ids = parity_ids()

      # Act
      missing = missing_ids(record(), ids)

      # Assert
      assert ids != []
      assert missing == [], "parity ids missing from the claims register: #{inspect(missing)}"
    end

    test "positive control: removing one id from an in-memory copy reports exactly that id" do
      # Arrange
      [victim | _] = non_parity_ids()
      mutated = String.replace(record(), "`" <> victim <> "`", "")

      # Act
      missing = missing_ids(mutated, non_parity_ids())

      # Assert
      assert missing == [victim]
      assert missing_ids(record(), ["planted-surface-id"]) == ["planted-surface-id"]
    end

    test "every register row has four cells and a status from the fixed vocabulary" do
      # Arrange
      register = section(record(), "Claims register")

      # Act
      rows = table_rows(register)
      bad_width = Enum.reject(rows, &(length(&1) == 4))
      bad_status = Enum.filter(rows, fn row -> status_kind(List.last(row)) == nil end)

      # Assert
      assert length(rows) >= 20
      assert bad_width == []
      assert bad_status == []
    end

    test "status labels reject word-prefix collisions and allow documented explanations" do
      assert status_kind("bounded") == "bounded"
      assert status_kind("not proven (divergence asserted)") == "not proven"
      assert status_kind("bounded — single request") == "bounded"

      for invalid <- ["provenance pending", "boundedness", "not provenance", "proven pending"] do
        assert status_kind(invalid) == nil
      end
    end

    test "the register's status agrees with each registry state" do
      # Arrange
      rows = record() |> section("Claims register") |> table_rows()

      # Act
      violations = status_violations(rows, states())

      # Assert
      assert violations == []
    end

    test "positive control: a non-parity row read as bounded, or a missing row, is reported" do
      # Arrange
      rows = [
        ["claim a", "where", "`a`: nothing compared", "bounded"],
        ["claim b", "where", "`b`: one request", "bounded"]
      ]

      states = %{"a" => "not_proven", "b" => "parity", "c" => "by_design"}

      # Act
      violations = status_violations(rows, states)

      # Assert
      assert Enum.sort(violations) == [{"a", :status_mismatch}, {"c", :no_row}]
    end

    test "the register names the policy and source claims and their evidence" do
      # Arrange
      register = section(record(), "Claims register")
      terms = ~w(
        test/sigra/brand/install_snippet_test.exs
        brand.sha256
        test/sigra/brand/source_pin_test.exs
        test/sigra/brand/frozen_surface_test.exs
        test/sigra/brand/copy_contract_test.exs
      )

      # Act
      missing = Enum.reject(terms, &String.contains?(register, &1))

      # Assert
      assert missing == []
      assert String.contains?(register, "Sigra makes no trademark claim")
    end
  end

  describe "limits, decisions and citations" do
    test "the record states the example-host limitation" do
      # Arrange
      content = record()

      # Act
      limitations = section(content, "Claims register")

      # Assert
      assert String.contains?(limitations, "hand-maintained")
      assert String.contains?(limitations, "example host")
      assert String.contains?(limitations, "generated host")
    end

    test "both decisions carry their labels and the confirmed-as-recommended status with a date" do
      # Arrange
      content = record()
      status = "confirmed as recommended by owner, 2026-11-15"
      lines = String.split(content, "\n")

      # Act
      missing =
        Enum.reject(["clear-space", "logo-use", status], fn term ->
          String.contains?(content, term)
        end)

      clear_space_line = Enum.find(lines, &String.starts_with?(&1, "Label: clear-space."))
      logo_use_line = Enum.find(lines, &String.starts_with?(&1, "Label: logo-use."))

      # Assert
      assert missing == []
      refute String.contains?(content, "owner confirmation pending")
      assert is_binary(clear_space_line) and String.contains?(clear_space_line, status)
      assert is_binary(logo_use_line) and String.contains?(logo_use_line, status)
      assert String.contains?(content, "300 units")
      assert String.contains?(content, "233.75")
      assert String.contains?(content, "logo.clearSpace")
    end

    test "every file path the record cites exists in the repository" do
      # Arrange
      paths = cited_paths(record()) |> Enum.reject(&String.starts_with?(&1, ".planning/"))

      # Act
      missing =
        Enum.reject(paths, fn path ->
          File.exists?(Path.join(root(), path))
        end)

      # Assert
      assert length(paths) >= 10
      assert missing == [], "cited paths that do not exist: #{inspect(missing)}"
    end

    test "positive control: cited_paths picks file paths and ignores other code spans" do
      # Arrange
      planted = "see `a/b_test.exs` and `x.json`, `~> 1.7.0`, `crosswake_sigra` and `no path`"

      # Act
      paths = cited_paths(planted)

      # Assert
      assert paths == ["a/b_test.exs", "x.json"]
    end
  end

  describe "local release announcement" do
    test "the announcement is marked as a draft and makes no name-clearance claim" do
      content = read!(@announcement)

      assert content =~ "LOCAL DRAFT"
      assert forbidden_wording(content) == []
      refute mentions?(content, source_owner())
    end
  end
end
