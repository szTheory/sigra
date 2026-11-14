defmodule Sigra.Brand.InstructionPointersTest do
  @moduledoc """
  Doc-contract test for the instruction-file pointer fix (BPOL-06).

  Executors read the instruction files and the admin guides before touching
  admin UI. Those files must point at the v1.51 brand book in `brand/`, never
  at the retired `brandbook/` source, and must not claim that admin token
  values already match the new book (they move in a later phase).
  """
  use ExUnit.Case, async: true

  # Files covered by the pointer fix. The two admin guides join this list in
  # the second task of the plan.
  @instruction_files [
    "CLAUDE.md",
    "AGENTS.md"
  ]

  # Pure matchers, one per defect class. Each is applied line by line so a
  # failure names the offending line.
  #
  # 1. "Rail Accent" followed on the same line by a backticked brandbook path.
  # 2. The retired tokens path (the retired book directory, a slash, tokens).
  # 3. A claim that admin token values already align with the new book.
  @retired_pointer ~r/Rail Accent.*`[^`]*brandbook[^`]*`/
  @retired_tokens ~r{brandbook/tokens}
  @alignment_claim ~r/already align|stay aligned with/i

  @new_book_pointer ~r{`brand/[^`]*`}

  defp root, do: Path.expand("../../..", __DIR__)
  defp read!(rel), do: root() |> Path.join(rel) |> File.read!()

  # Pure helper: every {reason, line} the content violates. An empty list
  # means the content is clean.
  defp violations(content) do
    content
    |> String.split("\n")
    |> Enum.flat_map(fn line ->
      [
        {:retired_pointer, @retired_pointer},
        {:retired_tokens, @retired_tokens},
        {:alignment_claim, @alignment_claim}
      ]
      |> Enum.filter(fn {_reason, regex} -> Regex.match?(regex, line) end)
      |> Enum.map(fn {reason, _regex} -> {reason, line} end)
    end)
  end

  # Pure helper: the first line of `content` that contains `needle`, or "".
  defp line_with(content, needle) do
    content
    |> String.split("\n")
    |> Enum.find("", &String.contains?(&1, needle))
  end

  describe "instruction files point at the new brand book" do
    test "every covered file has content" do
      for file <- @instruction_files do
        assert byte_size(read!(file)) > 0,
               "#{file} is empty, so the checks below would be vacuous"
      end
    end

    test "no file instructs the retired brandbook source or tokens path" do
      for file <- @instruction_files do
        retired =
          file
          |> read!()
          |> violations()
          |> Enum.filter(fn {reason, _line} -> reason in [:retired_pointer, :retired_tokens] end)

        assert retired == [],
               "#{file} still points at the retired brandbook source: #{inspect(retired)}"
      end
    end

    test "each file contains a backticked brand/ pointer" do
      for file <- @instruction_files do
        assert Regex.match?(@new_book_pointer, read!(file)),
               "#{file} has no backticked `brand/` pointer to the v1.51 brand book"
      end
    end

    test "no file claims admin token values already align with the book" do
      for file <- @instruction_files do
        claims =
          file
          |> read!()
          |> violations()
          |> Enum.filter(fn {reason, _line} -> reason == :alignment_claim end)

        assert claims == [], "#{file} claims token values already align: #{inspect(claims)}"
      end
    end
  end

  describe "preserved wording" do
    test "CLAUDE.md keeps the sg-* design system, theme support and says token values move later" do
      line = line_with(read!("CLAUDE.md"), "When changing Sigra admin UI")

      assert line != "", "CLAUDE.md lost its Admin UI Direction paragraph"
      assert line =~ "`sg-*` cascade-layer/BEM design system"
      assert line =~ "Light/Dark/System"
      assert line =~ "browser tests deterministic"
      assert line =~ "`brand/BRAND.md`"
      assert line =~ "`brand/tokens.json`"
      assert line =~ "`--sg-*` token names stay"
      assert line =~ "later phase"
    end

    test "AGENTS.md keeps the sg-* design system and theme bullets next to the pointer" do
      content = read!("AGENTS.md")

      assert content =~ "Preserve the `sg-*` cascade-layer/BEM design system."
      assert content =~ "Support Light, Dark, and System modes."
      assert content =~ "Keep Playwright/admin UI tests deterministic"
    end
  end

  describe "violations/1 positive control" do
    test "flags a planted retired Rail Accent pointer" do
      planted = "- Use the Rail Accent brand assets from `brandbook/`."

      assert [{:retired_pointer, ^planted}] = violations(planted)
    end

    test "flags a planted retired tokens path" do
      planted = "Use brand tokens from `brandbook/tokens.*` as the value reference."

      assert {:retired_tokens, planted} in violations(planted)
    end

    test "flags a planted alignment claim" do
      planted = "Token values should stay aligned with the book."

      assert [{:alignment_claim, ^planted}] = violations(planted)
    end

    test "does not flag a line pointing at the new book" do
      planted = "Use the brand book in `brand/` (identity rules in `brand/BRAND.md`)."

      assert violations(planted) == []
    end
  end
end
