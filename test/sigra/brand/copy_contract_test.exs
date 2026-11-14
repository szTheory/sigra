defmodule Sigra.Brand.CopyContractTest do
  use ExUnit.Case, async: true

  @moduledoc """
  Copy contract (BCOPY-02): brand-book wording must not creep back into shipped
  copy.

  Scopes, each with its own rules (`Sigra.Test.Brand.CopyScan`):

    * `lexicon` - `README.md`, `guides/introduction/*.md`, `guides/flows/*.md`.
      Lexicon only: the book's "Do not say" words, read from the pinned
      `brand/brand.json`.

  A hit is the matched text, so no line numbers are involved. The committed
  baseline `test/fixtures/brand/copy-baseline.json` holds the hits that exist
  today (the repo's own negations such as "a hosted identity product" in a
  "when to leave" list). It is shrink-only:

    * a hit that is not in the baseline fails: fix the copy, never baseline a
      new violation;
    * a baseline entry with no matching hit fails: remove that entry by hand in
      a reviewed commit.

  Initialization is opt-in and only fills scopes that are not yet listed in the
  baseline's `initialized_scopes`:

      SIGRA_BRAND_COPY_BASELINE=init mix test test/sigra/brand/copy_contract_test.exs

  `test/sigra/admin/glossary_test.exs` is a separate, older guard and is not
  touched by this one.
  """

  alias Sigra.Test.Brand.CopyScan

  setup_all do
    if CopyScan.init_requested?(), do: CopyScan.init_baseline!()
    :ok
  end

  describe "lexicon_words/0" do
    test "reads the ten Do-not-say terms from the pinned brand book" do
      assert CopyScan.lexicon_words() ==
               [
                 "hosted",
                 "managed",
                 "bank-grade",
                 "military-grade",
                 "unbreakable",
                 "zero trust",
                 "seamless",
                 "robust",
                 "compliant",
                 "certified"
               ]
    end
  end

  describe "scan_lines/3 over scope :lexicon (planted terms, no file I/O)" do
    test "flags a lexicon word in prose" do
      hits = CopyScan.scan_lines(:lexicon, "README.md", ["Sigra is a hosted service"])

      assert [%{scope: "lexicon", kind: "lexicon", file: "README.md", line: line}] = hits
      assert line == "Sigra is a hosted service"
    end

    test "returns nothing for prose without a lexicon word" do
      assert CopyScan.scan_lines(:lexicon, "README.md", ["nothing here"]) == []
    end

    test "matches case-insensitively and keeps the original case in the hit" do
      assert [%{line: "A Seamless flow"}] =
               CopyScan.scan_lines(:lexicon, "x.md", ["A   Seamless  flow"])
    end

    test "matches whole words only" do
      assert CopyScan.scan_lines(:lexicon, "x.md", ["the managed_by column", "unmanaged hosts"]) ==
               []
    end

    test "matches multi-word and hyphenated phrases whichever separator is used" do
      lines = ["a zero trust network", "a zero-trust network", "bank grade", "Bank-Grade crypto"]

      assert length(CopyScan.scan_lines(:lexicon, "x.md", lines)) == 4
    end

    test "ignores words inside fenced code blocks and HTML comments" do
      lines = [
        "Plain prose.",
        "```bash",
        "mix hosted.install --managed",
        "```",
        "<!-- a robust note -->",
        "<!--",
        "  seamless",
        "-->",
        "~~~",
        "certified",
        "~~~"
      ]

      assert CopyScan.scan_lines(:lexicon, "x.md", lines) == []
    end

    test "still scans prose after a fenced block closes" do
      lines = ["```", "hosted", "```", "after the fence: robust"]

      assert [%{line: "after the fence: robust"}] = CopyScan.scan_lines(:lexicon, "x.md", lines)
    end

    test "yields at most one hit per line even with two lexicon words" do
      assert [_one] = CopyScan.scan_lines(:lexicon, "x.md", ["hosted and managed"])
    end
  end

  describe "normalize/1" do
    test "trims and collapses whitespace, and carries no line number" do
      assert CopyScan.normalize("  a \t b\n c  ") == "a b c"
    end
  end

  describe "diff_baseline/2 (planted hits and entries)" do
    @hit %{scope: "lexicon", kind: "lexicon", file: "README.md", line: "a hosted thing"}

    test "equal hits and entries produce no difference" do
      assert CopyScan.diff_baseline([@hit], [@hit]) == [new: [], stale: []]
    end

    test "a hit with no baseline entry is new" do
      assert [new: [@hit], stale: []] = CopyScan.diff_baseline([@hit], [])
    end

    test "a baseline entry with no hit is stale" do
      assert [new: [], stale: [@hit]] = CopyScan.diff_baseline([], [@hit])
    end

    test "a second occurrence of an already baselined line is new" do
      assert [new: [@hit], stale: []] = CopyScan.diff_baseline([@hit, @hit], [@hit])
    end

    test "an entry baselined twice is stale once when only one hit remains" do
      assert [new: [], stale: [@hit]] = CopyScan.diff_baseline([@hit], [@hit, @hit])
    end

    test "kind and scope are part of the identity" do
      other = %{@hit | kind: "banned_term"}

      assert [new: [^other], stale: [@hit]] = CopyScan.diff_baseline([other], [@hit])
    end
  end

  describe "init_baseline/3 (opt-in, never rewrites an initialized scope)" do
    @existing %{scope: "lexicon", kind: "lexicon", file: "a.md", line: "kept"}

    test "fills only scopes that are not initialized and records them" do
      scanned = fn
        :lexicon -> [%{@existing | line: "SHOULD NOT BE ADDED"}]
        :admin -> [%{@existing | scope: "admin", line: "added"}]
      end

      result =
        CopyScan.init_baseline(
          %{initialized_scopes: ["lexicon"], entries: [@existing]},
          [:lexicon, :admin],
          scanned
        )

      assert result.initialized_scopes == ["lexicon", "admin"]
      assert result.entries == [@existing, %{@existing | scope: "admin", line: "added"}]
    end

    test "a scope with zero hits still becomes initialized" do
      result =
        CopyScan.init_baseline(
          %{initialized_scopes: [], entries: []},
          [:generated],
          fn :generated ->
            []
          end
        )

      assert result == %{initialized_scopes: ["generated"], entries: []}
    end

    test "an initialized scope is never shrunk or re-scanned" do
      result =
        CopyScan.init_baseline(
          %{initialized_scopes: ["lexicon"], entries: [@existing]},
          [:lexicon],
          fn _scope -> flunk("an initialized scope must not be scanned") end
        )

      assert result == %{initialized_scopes: ["lexicon"], entries: [@existing]}
    end
  end

  describe "render_baseline/2 (deterministic, line-oriented)" do
    test "writes one entry per line, one scope per line, with sorted keys" do
      entries = [
        %{scope: "lexicon", kind: "lexicon", file: "b.md", line: "second \"quoted\""},
        %{scope: "lexicon", kind: "lexicon", file: "a.md", line: "first"}
      ]

      lines = CopyScan.render_baseline(["lexicon"], entries) |> String.split("\n")

      assert "    {\"file\": \"a.md\", \"kind\": \"lexicon\", \"line\": \"first\", \"scope\": \"lexicon\"}," in lines

      assert Enum.count(lines, &String.starts_with?(&1, "    {\"file\"")) == 2
      assert "    \"lexicon\"" in lines
      assert "  \"schema_version\": \"sigra.brand-copy-baseline/v1\"" in lines
    end

    test "is the same text however the input is ordered, and round-trips through JSON" do
      a = %{scope: "lexicon", kind: "lexicon", file: "a.md", line: "x"}
      b = %{scope: "admin", kind: "banned_term", file: "b.ex", line: "y"}

      assert CopyScan.render_baseline(["lexicon", "admin"], [a, b]) ==
               CopyScan.render_baseline(["admin", "lexicon"], [b, a])

      decoded = CopyScan.render_baseline(["lexicon"], [a]) |> JSON.decode!()
      assert decoded["initialized_scopes"] == ["lexicon"]

      assert decoded["entries"] == [
               %{"file" => "a.md", "kind" => "lexicon", "line" => "x", "scope" => "lexicon"}
             ]
    end

    test "an empty scope renders as an empty array and the file ends with a newline" do
      text = CopyScan.render_baseline(["generated"], [])

      assert text =~ "\"entries\": [],"
      assert String.ends_with?(text, "}\n")
    end
  end

  describe "committed baseline (shrink-only)" do
    test "the baseline file is exactly what the renderer would write" do
      %{initialized_scopes: scopes, entries: entries} = CopyScan.load_baseline()

      assert File.read!(CopyScan.baseline_path()) == CopyScan.render_baseline(scopes, entries),
             "copy-baseline.json is not in rendered form; it is generated, not hand-formatted"
    end

    test "every scope the scanner implements is initialized" do
      %{initialized_scopes: initialized} = CopyScan.load_baseline()

      missing =
        for scope <- CopyScan.scopes(), Atom.to_string(scope) not in initialized, do: scope

      assert missing == [],
             "scopes not initialized in the baseline: #{inspect(missing)}. Initialize once with:\n  #{CopyScan.init_command()}"
    end
  end

  describe "real scan of scope :lexicon (README + top guides)" do
    test "non-vacuous: the file list is real and the baseline has entries" do
      files = CopyScan.files_for(:lexicon)

      assert "README.md" in files
      assert "guides/introduction/contract.md" in files
      assert Enum.any?(files, &String.starts_with?(&1, "guides/flows/"))

      %{entries: entries} = CopyScan.load_baseline()
      assert Enum.count(entries, &(&1.scope == "lexicon")) >= 1
    end

    test "hits equal the committed baseline exactly (no new, no stale)" do
      assert_scope_matches_baseline(:lexicon)
    end
  end

  defp assert_scope_matches_baseline(scope) do
    name = Atom.to_string(scope)
    %{entries: entries} = CopyScan.load_baseline()
    baselined = Enum.filter(entries, &(&1.scope == name))

    [new: new, stale: stale] = CopyScan.diff_baseline(CopyScan.scan(scope), baselined)

    new_report =
      Enum.map_join(new, "\n", fn hit ->
        "new banned term in #{hit.file}: #{hit.line} - fix the copy, do not baseline new violations"
      end)

    stale_report =
      Enum.map_join(stale, "\n", fn entry ->
        "baseline entry no longer matches any hit - remove this entry (shrink-only): " <>
          "#{entry.scope}/#{entry.kind} #{entry.file}: #{entry.line}"
      end)

    assert new == [], new_report
    assert stale == [], stale_report
  end
end
