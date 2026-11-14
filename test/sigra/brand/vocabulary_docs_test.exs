defmodule Sigra.Brand.VocabularyDocsTest do
  use ExUnit.Case, async: true

  @moduledoc """
  Doc contract for the brand book vocabulary reconciliation (BCOPY-01) in
  `guides/reference/admin-glossary.md`.

  The glossary carries one H2, "Brand book v2.0 reconciliation", between the
  Canonical Terms rules and the Voice Rubric. Its table reuses the glossary's
  four columns, and every row opens its Context rule cell with "Agrees" or
  "Differs" so the reconciliation is explicit per row.

  What this test pins, and the failure each pin stops:

    * placement: the H1 stays, the H2 occurs once and sits where it should;
    * the row marker: a row cannot say nothing about whether the book and the
      glossary agree;
    * the required terms: every ruling keeps its word in the section;
    * anchors: a product-truth anchor is a full repo path plus a line number
      (`lib/...` or `test/example/lib/...`). The Voice Rubric's older
      short-name form (a bare file name and a line number) never counts. An
      anchor must name a file that exists, a line inside it, and a line that
      still holds the term the row cites, so a later edit that moves the copy
      turns this test red instead of leaving a stale citation;
    * the anchor floor: a section with too few anchors fails;
    * hygiene: the published section carries no planning citation, and the
      Enforcement column names a test file that exists or the word "editorial".

  Every pure helper below is shown to fail on a planted bad input before its
  verdict on the real section is trusted.
  """

  @glossary "guides/reference/admin-glossary.md"
  @heading "## Brand book v2.0 reconciliation"
  @columns ["Canonical", "Banned synonyms", "Context rule", "Enforcement"]

  # One word or phrase per ruling the section records. A ruling that loses its
  # word from the section fails here.
  @required_terms ["Suspended", "Deletion scheduled", "Locked", "sign in"]

  # Fewer full-path anchors than this in the section is a failure.
  @min_anchors 2

  # {term, file}: the section must cite, for the file, at least one line that
  # holds the term.
  @anchor_pairs [
    {"Locked", "lib/sigra/admin/live/user_show_live.ex"},
    {"Deletion scheduled", "lib/sigra/admin/live/user_show_live.ex"},
    {"unlock below", "lib/sigra/admin/live/user_show_live.ex"},
    {"auto-unlocks", "lib/sigra/lockout.ex"},
    {"Log in", "test/example/lib/example_web/controllers/session_html.ex"}
  ]

  # --- file and text helpers ------------------------------------------------

  defp root, do: Path.expand("../../..", __DIR__)
  defp read!(rel), do: root() |> Path.join(rel) |> File.read!()
  defp glossary, do: read!(@glossary)

  defp byte_index!(body, needle) do
    case :binary.match(body, needle) do
      {index, _length} -> index
      :nomatch -> flunk("missing expected text in #{@glossary}: #{inspect(needle)}")
    end
  end

  defp line_count(rel), do: root() |> Path.join(rel) |> File.stream!() |> Enum.count()

  # The 1-based line numbers of `rel` whose text contains `term` (case-sensitive).
  defp term_lines(rel, term) do
    root()
    |> Path.join(rel)
    |> File.stream!()
    |> Stream.with_index(1)
    |> Enum.flat_map(fn {line, number} ->
      if String.contains?(line, term), do: [number], else: []
    end)
    |> MapSet.new()
  end

  # --- pure helpers over a glossary string ------------------------------------

  # The text after the heading line, up to the next H2 or horizontal rule.
  # Returns "" when the heading is absent, so callers assert on the content.
  defp section_slice(content, heading) do
    case :binary.split(content, "\n" <> heading <> "\n") do
      [_before, rest] -> rest |> String.split(~r/\n(?:## |---\n)/, parts: 2) |> hd()
      [_whole] -> ""
    end
  end

  # The terms from `terms` that `slice` does not contain.
  defp missing_terms(slice, terms), do: Enum.reject(terms, &String.contains?(slice, &1))

  # The cells of one table line. Cells carry no pipe character.
  defp cells(line) do
    line |> String.trim() |> String.trim("|") |> String.split("|") |> Enum.map(&String.trim/1)
  end

  defp table_rows(slice) do
    slice
    |> String.split("\n")
    |> Enum.filter(&String.starts_with?(&1, "|"))
    |> Enum.map(&cells/1)
  end

  defp separator?(cells) do
    cells != [] and Enum.all?(cells, &Regex.match?(~r/^:?-{3,}:?$/, &1))
  end

  defp body_rows(slice) do
    slice |> table_rows() |> Enum.reject(&(&1 == @columns or separator?(&1)))
  end

  defp marked?([_canonical, _banned, rule, _enforcement]),
    do: Regex.match?(~r/^(?:Agrees|Differs)\b/, rule)

  defp marked?(_cells), do: false

  # The Canonical cell of every body row whose Context rule does not open with
  # "Agrees" or "Differs".
  defp row_marker_violations(slice) do
    for cells <- body_rows(slice), not marked?(cells), do: List.first(cells)
  end

  # Full-repo-path anchors: `lib/...` or `test/example/lib/...`, a `.ex` or
  # `.exs` file, a colon and a line number. The lookbehind keeps a longer path
  # from matching on its tail (`priv/lib/x.ex:3`).
  defp anchor_regex do
    ~r{(?<![A-Za-z0-9_/.\-])((?:test/example/lib|lib)/[A-Za-z0-9_/]+\.exs?):(\d+)}
  end

  defp anchors(text) do
    anchor_regex()
    |> Regex.scan(text)
    |> Enum.map(fn [_whole, file, line] -> {file, String.to_integer(line)} end)
  end

  # The short-name form (a bare file name and a line number), which names no
  # directory and so cannot be checked.
  defp short_anchors(text) do
    ~r/(?<![A-Za-z0-9_\/.\-])[A-Za-z0-9_]+\.exs?:\d+/
    |> Regex.scan(text)
    |> List.flatten()
  end

  # Anchors that do not point at a real line of a real file.
  defp bad_anchors(text) do
    for {file, line} <- anchors(text),
        problem = anchor_problem(file, line),
        do: {file, line, problem}
  end

  defp anchor_problem(file, line) do
    cond do
      not File.regular?(Path.join(root(), file)) -> :missing_file
      line < 1 or line > line_count(file) -> :line_out_of_range
      true -> nil
    end
  end

  # How many anchors short of `minimum` the text is (0 when it has enough).
  defp anchor_shortfall(text, minimum), do: max(minimum - length(anchors(text)), 0)

  # The anchors in `text` that name `file` at one of `lines`.
  defp anchor_hits(text, file, lines) do
    for {anchor_file, line} = anchor <- anchors(text),
        anchor_file == file,
        line in lines,
        do: anchor
  end

  # Planning citations that do not belong in a published guide.
  defp forbidden_citations(slice) do
    ~r/Plan 259|\.planning|ADR 0/ |> Regex.scan(slice) |> List.flatten()
  end

  # A test file path, as written in an Enforcement cell.
  defp test_path_regex, do: ~r{test/[A-Za-z0-9_/.\-]+\.exs}

  defp test_paths(text),
    do: test_path_regex() |> Regex.scan(text) |> List.flatten() |> Enum.uniq()

  # Paths in `paths` that are not regular files under the repo root.
  defp missing_files(paths), do: Enum.reject(paths, &File.regular?(Path.join(root(), &1)))

  # Enforcement cells that name neither a test file path nor the word
  # "editorial".
  defp enforcement_violations(slice) do
    for [canonical, _banned, _rule, enforcement] <- body_rows(slice),
        not String.contains?(enforcement, "editorial"),
        not Regex.match?(test_path_regex(), enforcement),
        do: canonical
  end

  # Every test path named in an Enforcement cell of the section.
  defp enforcement_paths(slice) do
    for [_canonical, _banned, _rule, enforcement] <- body_rows(slice),
        path <- test_paths(enforcement),
        uniq: true,
        do: path
  end

  # --- tests -----------------------------------------------------------------

  describe "placement" do
    test "keeps the H1 and places the reconciliation once, between Canonical Terms and Voice Rubric" do
      # Arrange
      content = glossary()
      heading = "\n" <> @heading <> "\n"

      # Act
      first_line = content |> String.split("\n") |> hd()
      occurrences = length(:binary.matches(content, heading))

      # Assert
      assert first_line == "# Admin Glossary"
      assert occurrences == 1

      canonical = byte_index!(content, "\n## Canonical Terms\n")
      security = byte_index!(content, "**Security idiom exception:**")
      here = byte_index!(content, heading)
      voice = byte_index!(content, "\n## Voice Rubric\n")

      assert canonical < security
      assert security < here
      assert here < voice
    end
  end

  describe "table shape" do
    test "the section carries the four-column header and at least one body row" do
      # Arrange
      slice = section_slice(glossary(), @heading)

      # Act
      rows = table_rows(slice)

      # Assert
      assert slice != "", "the section #{inspect(@heading)} is missing from #{@glossary}"
      assert @columns in rows, "the four-column header is missing: #{inspect(@columns)}"
      assert body_rows(slice) != []
    end

    test "every table row opens its Context rule with Agrees or Differs" do
      # Arrange
      slice = section_slice(glossary(), @heading)

      # Act
      violations = row_marker_violations(slice)

      # Assert
      assert slice != ""
      assert violations == [], "rows without an Agrees/Differs marker: #{inspect(violations)}"
    end

    test "planted control: a row without the marker is reported" do
      # Arrange
      slice = """
      | Canonical | Banned synonyms | Context rule | Enforcement |
      |-----------|-----------------|--------------|-------------|
      | **marked** | x | Agrees with the book. | editorial |
      | **also marked** | x | Differs from the book. | editorial |
      | **planted** | x | All surfaces: no marker here. | editorial |
      """

      # Act
      violations = row_marker_violations(slice)

      # Assert
      assert violations == ["**planted**"]
    end
  end

  describe "required terms" do
    test "the section holds a word for every ruling" do
      # Arrange
      slice = section_slice(glossary(), @heading)

      # Act
      missing = missing_terms(slice, @required_terms)

      # Assert
      assert slice != ""
      assert missing == [], "rulings missing from the section: #{inspect(missing)}"
    end

    test "planted control: an in-memory section that omits one term reports exactly that term" do
      # Arrange
      slice = "Suspended, Deletion scheduled and sign in only."

      # Act
      missing = missing_terms(slice, @required_terms)

      # Assert
      assert missing == ["Locked"]
    end
  end

  describe "anchors" do
    test "every anchor names a file that exists and a line inside it" do
      # Arrange
      slice = section_slice(glossary(), @heading)

      # Act
      bad = bad_anchors(slice)

      # Assert
      assert slice != ""
      assert bad == [], "anchors that do not resolve: #{inspect(bad)}"
    end

    test "planted control: a line past the end of a real file and a missing file are both reported" do
      # Arrange
      text =
        "`lib/sigra/admin/live/user_show_live.ex:99999` and `lib/sigra/admin/live/no_such_file.ex:3`"

      # Act
      bad = bad_anchors(text)

      # Assert
      assert {"lib/sigra/admin/live/user_show_live.ex", 99_999, :line_out_of_range} in bad
      assert {"lib/sigra/admin/live/no_such_file.ex", 3, :missing_file} in bad
    end

    test "the section carries at least the minimum number of anchors" do
      # Arrange
      slice = section_slice(glossary(), @heading)

      # Act
      shortfall = anchor_shortfall(slice, @min_anchors)

      # Assert
      assert slice != ""

      assert shortfall == 0,
             "the section has #{length(anchors(slice))} anchors, #{shortfall} short of #{@min_anchors}"
    end

    test "planted control: a section with no anchors reports the whole minimum as a shortfall" do
      # Arrange
      slice = "A section that cites user_show_live.ex:81 in the short form and nothing else."

      # Act
      shortfall = anchor_shortfall(slice, @min_anchors)

      # Assert
      assert shortfall == @min_anchors
    end

    test "the section uses full repo paths, never the short-name form" do
      # Arrange
      slice = section_slice(glossary(), @heading)

      # Act
      short = short_anchors(slice)

      # Assert
      assert slice != ""
      assert short == [], "short-name anchors cannot be checked: #{inspect(short)}"
    end

    test "planted control: the short-name form is reported and a full path is not" do
      # Arrange
      text = "short user_show_live.ex:81 and full `lib/sigra/admin/live/user_show_live.ex:81`"

      # Act
      short = short_anchors(text)

      # Assert
      assert short == ["user_show_live.ex:81"]
    end

    test "each cited term sits on a line the section actually cites" do
      # Arrange
      slice = section_slice(glossary(), @heading)

      for {term, file} <- @anchor_pairs do
        # Act
        lines = term_lines(file, term)
        hits = anchor_hits(slice, file, lines)

        # Assert
        assert MapSet.size(lines) > 0, "#{file} no longer contains #{inspect(term)}"

        assert hits != [],
               "no anchor in the section points at a line of #{file} that contains #{inspect(term)}; " <>
                 "the lines that do are #{inspect(Enum.sort(lines))}"
      end
    end

    test "planted control: an anchor to a line that lacks the term reports a miss" do
      # Arrange
      file = "lib/sigra/admin/live/user_show_live.ex"
      lines = term_lines(file, "Locked")
      lacking = Enum.find(1..line_count(file), &(&1 not in lines))
      text = "`#{file}:#{lacking}`"

      # Act
      hits = anchor_hits(text, file, lines)

      # Assert
      assert MapSet.size(lines) > 0
      assert hits == []
    end
  end

  describe "published-text hygiene" do
    test "the section cites no plan, planning path or decision record" do
      # Arrange
      slice = section_slice(glossary(), @heading)

      # Act
      citations = forbidden_citations(slice)

      # Assert
      assert slice != ""
      assert citations == [], "planning citations in a published guide: #{inspect(citations)}"
    end

    test "planted control: a plan number, a planning path and a decision number are flagged" do
      # Arrange
      text = "Plan 259-08 says so, see .planning/x.md and ADR 005."

      # Act
      citations = forbidden_citations(text)

      # Assert
      assert citations == ["Plan 259", ".planning", "ADR 0"]
    end

    test "every Enforcement cell names an existing test file or the word editorial" do
      # Arrange
      slice = section_slice(glossary(), @heading)

      # Act
      unnamed = enforcement_violations(slice)
      paths = enforcement_paths(slice)
      missing = missing_files(paths)

      # Assert
      assert slice != ""

      assert unnamed == [],
             "Enforcement cells naming neither a test file nor 'editorial': #{inspect(unnamed)}"

      assert paths != []
      assert missing == [], "Enforcement test paths that do not exist: #{inspect(missing)}"
    end

    test "planted control: a test path that does not exist and a cell with no enforcement are reported" do
      # Arrange
      slice = """
      | Canonical | Banned synonyms | Context rule | Enforcement |
      |-----------|-----------------|--------------|-------------|
      | **real** | x | Agrees. | test/sigra/brand/copy_contract_test.exs |
      | **fake** | x | Agrees. | test/sigra/brand/no_such_test.exs |
      | **vague** | x | Agrees. | somebody checks it |
      """

      # Act
      missing = slice |> enforcement_paths() |> missing_files()
      unnamed = enforcement_violations(slice)

      # Assert
      assert missing == ["test/sigra/brand/no_such_test.exs"]
      assert unnamed == ["**vague**"]
    end
  end
end
