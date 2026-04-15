defmodule Sigra.Install.TemplateSyntaxTest do
  @moduledoc """
  D-06.3 regression guard for Phase 24.

  For every `.ex` template under `priv/templates/sigra.install/**/`:

  1. Extract every `~H\"\"\"..\"\"\"` heredoc.
  2. Assert the heredoc body contains NO raw `<%=` / `<%` EEx tag whose
     body references an HEEx assigns variable (`@identifier`). The
     DEF-18-01 fingerprint is `<%= case @branch do %>` — a raw EEx tag
     inside `~H` referencing `@branch`, which EEx tries to expand to
     `var!(assigns).branch` at generator-render time and fails because
     `assigns` is not in the EEx binding.

     Escaped `<%%=` / `<%%` tags are permitted (they render as literal
     `<%=` / `<%` and bypass EEx evaluation). String-literal-only EEx
     tags like `<%= \"{@field}\" %>` are also permitted — they evaluate
     to a plain string at generator time and the literal `{@field}`
     reaches HEEx at runtime.

  This is the narrowest possible guard for the exact DEF-18-01 bug
  (HEEx-inside-EEx evaluation collision). Catches the bug class at
  file-read time without paying the full render-test cost.
  """
  use ExUnit.Case, async: true

  @moduletag :install

  @template_root "priv/templates/sigra.install"

  # Matches a `~H\"\"\"..\"\"\"` heredoc. Captures the body.
  @heredoc_re ~r/~H"""(.*?)"""/s

  # Matches a RAW EEx tag (not escaped `<%%`) whose body opens an Elixir
  # control-flow construct (`case`, `if`, `unless`, `cond`, `for`, `with`)
  # against an HEEx assigns variable like `@branch`. The negative
  # lookbehind `(?<!%)` ensures escaped `<%%=` / `<%%` are NOT matched.
  # This is the EXACT DEF-18-01 fingerprint: control-flow inside an EEx
  # tag inside a `~H` heredoc, referencing an assigns variable that EEx
  # cannot resolve at generator-render time. Excludes benign
  # `<%= "literal" %>` patterns and bare `<%= @field %>` interpolations
  # (which are still wrong but are caught by the render test, not this
  # fast narrow guard).
  @raw_eex_re ~r/(?<!%)<%=?\s*(case|if|unless|cond|for|with)\s+@[a-zA-Z_]/

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
