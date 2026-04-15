defmodule Sigra.Install.TemplateSyntaxTest do
  @moduledoc """
  D-06.3 regression guard for Phase 24.

  For every `.ex` template under `priv/templates/sigra.install/**/`:

  1. Extract every `~H\"\"\"..\"\"\"` heredoc.
  2. Assert the heredoc body contains NO raw `<%=` or `<%` EEx tags.
     (Escaped `<%%=` and `<%%` are permitted — they render as literal
     `<%=` / `<%` and bypass EEx evaluation.)

  This is the narrowest possible guard for the exact DEF-18-01 bug
  (HEEx-inside-EEx evaluation collision). Catches the bug class at
  file-read time without paying the full render-test cost.
  """
  use ExUnit.Case, async: true

  @moduletag :install

  @template_root "priv/templates/sigra.install"

  # Matches a `~H\"\"\"..\"\"\"` heredoc. Captures the body.
  @heredoc_re ~r/~H"""(.*?)"""/s

  # Matches any raw EEx tag: `<%=` or `<%` NOT preceded by a second `%`.
  # Negative lookbehind `(?<!%)` allows `<%%=` / `<%%` (escaped) to pass.
  @raw_eex_re ~r/(?<!%)<%=?/

  describe "HEEx-inside-EEx guard" do
    for path <- Path.wildcard(Path.join([@template_root, "**", "*.ex"])) do
      @path path

      test "no raw EEx tags inside ~H heredocs: #{@path}" do
        content = File.read!(@path)

        heredocs = Regex.scan(@heredoc_re, content, capture: :all_but_first)

        for [body] <- heredocs do
          refute Regex.match?(@raw_eex_re, body),
                 "#{@path} contains a raw `<%=` or `<%` inside a ~H heredoc. " <>
                   "This will fail at generator-render time because EEx evaluates " <>
                   "the heredoc body before HEEx compilation. Fix by either " <>
                   "(a) lifting the logic into Elixir and using `{...}` curly-brace " <>
                   "HEEx interpolation, or (b) escaping the tag as `<%%=` / `<%%`.\n\n" <>
                   "Offending heredoc body:\n#{body}"
        end
      end
    end
  end
end
