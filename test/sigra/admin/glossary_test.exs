defmodule Sigra.Admin.GlossaryTest do
  use ExUnit.Case, async: true
  @moduledoc false

  # ---------------------------------------------------------------------------
  # Admin Glossary Drift Guard (D-07)
  #
  # Parses the 9 in-scope admin source files for banned synonym terms.
  # Violations fail with: file:line — found '#{term}' — use '#{canonical}' instead (#{description})
  #
  # Scope (D-08): exactly the 8 admin LiveViews + components.ex.
  # Generated auth forms/emails under priv/templates/sigra.install/ are host-owned, never scanned.
  #
  # Carve-out (D-09): branding_live.ex auth-replica block (class="sigra-auth sigra-auth--preview")
  # is exempt — it mirrors host-generated auth copy which may intentionally say "Log in".
  # The admin chrome heading "Login preview" (line 583) sits ABOVE the carve-out and IS scanned.
  #
  # This test ships with the library so adopters who customize admin copy inherit the drift guard.
  # ---------------------------------------------------------------------------

  @in_scope_files [
    "lib/sigra/admin/live/index_live.ex",
    "lib/sigra/admin/live/organization_live.ex",
    "lib/sigra/admin/live/users_index_live.ex",
    "lib/sigra/admin/live/user_show_live.ex",
    "lib/sigra/admin/live/user_sessions_live.ex",
    "lib/sigra/admin/live/branding_live.ex",
    "lib/sigra/admin/live/audit_index_live.ex",
    "lib/sigra/admin/live/audit_user_live.ex",
    "lib/sigra/admin/components.ex"
  ]

  describe "admin glossary drift guard" do
    test "no banned synonyms in admin chrome source files" do
      violations =
        @in_scope_files
        |> Enum.flat_map(&check_file/1)

      assert violations == [],
             """
             Banned synonym violations found in admin source files.
             Fix the copy before merging — use the canonical term from guides/reference/admin-glossary.md.

             #{Enum.join(violations, "\n")}
             """
    end
  end

  describe "strip_non_copy_lines regression — action= human copy" do
    test "action=\"...\" lines with human copy survive stripping and are scanned" do
      # Build a synthetic indexed_lines list in memory (no file I/O).
      # "logins" is a banned term (canonical: "sessions") — it should be caught
      # when it appears inside an action="..." component attribute value.
      indexed_lines = [{"          action=\"Review logins\"", 99}]

      # The line must NOT be stripped — action="{" is stripped, not action="..."
      surviving = strip_non_copy_lines(indexed_lines)
      assert surviving != [], "Expected action=\"...\" line to survive strip_non_copy_lines/1"

      # The surviving line must trigger a banned-term violation for "logins"
      violations =
        Enum.flat_map(surviving, fn {line, _line_num} ->
          banned_terms()
          |> Enum.flat_map(fn {pattern, _canonical, _description} ->
            regex = Regex.compile!(pattern, [:caseless])
            Regex.scan(regex, line) |> Enum.map(fn [matched | _] -> matched end)
          end)
        end)

      assert Enum.any?(violations, &String.match?(&1, ~r/logins/i)),
             "Expected banned term 'logins' to be caught in action=\"...\" value, got: #{inspect(violations)}"
    end
  end

  # ---------------------------------------------------------------------------
  # Core helpers
  # ---------------------------------------------------------------------------

  # Reads a file, strips the carve-out region (branding_live.ex only), strips
  # non-copy lines, then checks every remaining line for banned terms.
  # Returns a list of violation strings: "file:line — found '...' — use '...' instead (...)"
  defp check_file(file_path) do
    content = File.read!(file_path)

    # Split into {line_content, original_1-based_line_number} pairs
    indexed_lines =
      content
      |> String.split("\n")
      |> Enum.with_index(1)

    indexed_lines
    |> strip_carve_outs(file_path)
    |> strip_non_copy_lines()
    |> Enum.flat_map(fn {line, line_num} ->
      banned_terms()
      |> Enum.flat_map(fn {pattern, canonical, description} ->
        regex = Regex.compile!(pattern, [:caseless])

        Regex.scan(regex, line)
        |> Enum.map(fn [matched | _] ->
          "#{file_path}:#{line_num} — found '#{matched}' — use '#{canonical}' instead (#{description})"
        end)
      end)
    end)
  end

  # ---------------------------------------------------------------------------
  # Carve-out: branding_live.ex auth-replica block
  #
  # Uses DOM-marker anchoring — NOT hardcoded line numbers — so the carve-out
  # remains correct even if lines above or below the block shift due to future edits.
  #
  # State machine:
  #   - INACTIVE until a line containing "sigra-auth sigra-auth--preview" is seen
  #     (the class attribute on the opening <div> of the auth-replica block).
  #   - When the marker is found: mark ACTIVE, begin skipping (including the marker line).
  #   - While ACTIVE: track <div> nesting depth (increment on lines containing "<div",
  #     decrement on lines containing "</div>"). When depth returns to 0 after the opening
  #     marker was consumed, the closing </div> has been reached — skip it and mark INACTIVE.
  #   - Lines before the opening marker (e.g. line 583 "<h2>Login preview</h2>") and lines
  #     after the closing </div> are kept and remain subject to scanning.
  # ---------------------------------------------------------------------------

  defp strip_carve_outs(indexed_lines, "lib/sigra/admin/live/branding_live.ex") do
    {result, _state} =
      Enum.reduce(indexed_lines, {[], :inactive}, fn {line, line_num}, {acc, state} ->
        case state do
          :inactive ->
            if String.contains?(line, "sigra-auth sigra-auth--preview") do
              # This is the carve-out opening marker line — skip it, enter active state
              # depth starts at 1 because we just consumed one opening <div
              depth = count_div_depth(line)
              {acc, {:active, depth}}
            else
              {[{line, line_num} | acc], :inactive}
            end

          {:active, depth} ->
            new_depth = depth + count_div_delta(line)

            if new_depth <= 0 do
              # The closing </div> for the carve-out block — skip it, return to inactive
              {acc, :inactive}
            else
              # Still inside the carve-out block — skip the line
              {acc, {:active, new_depth}}
            end
        end
      end)

    Enum.reverse(result)
  end

  defp strip_carve_outs(indexed_lines, _file), do: indexed_lines

  # Count net div depth change from a line
  # +1 for each <div occurrence, -1 for each </div> occurrence
  defp count_div_delta(line) do
    opens = line |> String.split("<div") |> length() |> Kernel.-(1)
    closes = line |> String.split("</div>") |> length() |> Kernel.-(1)
    opens - closes
  end

  # Count only opens (for the initial marker line)
  defp count_div_depth(line) do
    opens = line |> String.split("<div") |> length() |> Kernel.-(1)
    closes = line |> String.split("</div>") |> length() |> Kernel.-(1)
    # Start depth at 1 because the carve-out opening marker IS a <div we are tracking
    max(1, opens - closes)
  end

  # ---------------------------------------------------------------------------
  # Strip non-copy lines
  #
  # Rejects lines that contain technical Elixir/HEEx patterns rather than
  # visible rendered copy. Without stripping, module names, function names,
  # CSS class strings, and data attributes produce false positives.
  # ---------------------------------------------------------------------------

  @strip_patterns [
    # Module / function declarations
    ~r/^\s*(defmodule|def\s|defp\s)/,
    # Module directives
    ~r/^\s*(alias|import|use|require)\s/,
    # Module attributes and doc strings (strips @doc, @moduledoc, @attr, etc.)
    ~r/^\s*@/,
    # Comments — Elixir single-line (#) and HEEx block comment open (<%!--)
    ~r/^\s*#/,
    ~r/<%!--/,
    # Test IDs (kebab-case identifiers, not visible copy) — both data-testid= and *_testid= attrs
    ~r/data-testid=/,
    ~r/\w+_testid=/,
    # Design-system data attributes
    ~r/data-sg-/,
    # CSS class attribute values — strip lines where class= is the only content interest.
    # Exclude lines that have visible text between HTML tags (e.g. <h2 class="...">Text</h2>)
    # so that headings/labels with class= attributes are still scanned for banned terms.
    ~r/class=(?!.*>\s*[A-Za-z][^<]+<)/,
    # URL / event HTML attributes — strip Elixir-expression form actions (action={...})
    # and href/phx-* attrs; but leave action="..." string literals live so component
    # copy values (e.g. action="Review users") are scanned for banned terms.
    ~r/(href=|action=\{|phx-\w+=)/,
    # Input name attributes
    ~r/(name=|input\s+.*name)=/,
    # Elixir pipeline expressions
    ~r/\|>/,
    # Regex literals inside source
    ~r/~r\//,
    # Struct patterns
    ~r/(%\{|%Ecto|__struct__)/,
    # Elixir inspect calls (function heads with inspect — not end-user copy)
    ~r/inspect\(/,
    # Raise guards
    ~r/raise\s+[A-Z]/,
    # Component attribute / slot declarations
    ~r/^\s+(attr|slot)\s+:/
  ]

  # ---------------------------------------------------------------------------
  # Strip multi-line doc blocks and HEEx comment blocks
  #
  # This runs BEFORE strip_non_copy_lines/1 to remove content lines inside:
  #   - @doc """...""" and @moduledoc """...""" (Elixir heredoc doc strings)
  #   - <%!-- ... --%> (HEEx comment blocks)
  #
  # Without this, content lines inside doc strings are not prefixed with "@"
  # and thus not caught by the @strip_patterns line-by-line filter.
  # ---------------------------------------------------------------------------

  defp strip_doc_and_heex_comment_blocks(indexed_lines) do
    {result, _state} =
      Enum.reduce(indexed_lines, {[], :copy}, fn {line, line_num}, {acc, state} ->
        case state do
          :copy ->
            cond do
              # Elixir @doc / @moduledoc heredoc open (e.g. @doc """ or @moduledoc ~S"""
              Regex.match?(~r/^\s*@(doc|moduledoc)\s+(~[A-Z])?"""/, line) ->
                # Strip this line too; enter doc state
                {acc, :doc}

              # HEEx block comment open — strip from this line through --%>
              String.contains?(line, "<%!--") ->
                if String.contains?(line, "--%>") do
                  # Single-line comment — strip and stay in :copy
                  {acc, :copy}
                else
                  {acc, :heex_comment}
                end

              true ->
                {[{line, line_num} | acc], :copy}
            end

          :doc ->
            # Strip lines until we see the closing """ on its own
            if Regex.match?(~r/^\s*"""/, line) do
              {acc, :copy}
            else
              {acc, :doc}
            end

          :heex_comment ->
            # Strip lines until we see --%>
            if String.contains?(line, "--%>") do
              {acc, :copy}
            else
              {acc, :heex_comment}
            end
        end
      end)

    Enum.reverse(result)
  end

  defp strip_non_copy_lines(indexed_lines) do
    indexed_lines
    |> strip_doc_and_heex_comment_blocks()
    |> Enum.reject(fn {line, _line_num} ->
      Enum.any?(@strip_patterns, &Regex.match?(&1, line))
    end)
  end

  # ---------------------------------------------------------------------------
  # Banned terms
  #
  # Each entry: {regex_pattern, canonical_replacement, description}
  # Patterns use word-boundary anchors (\b) and are matched case-insensitively.
  #
  # IMPORTANT: "account" is NOT in this list. It has too many legitimate uses
  # ("account takeover" as a security idiom, first-person "your account", etc.)
  # The 6 account-as-person-noun violations are handled by per-file edits in Wave 2.
  # See RESEARCH.md §Pitfall 1 for rationale.
  # ---------------------------------------------------------------------------

  defp banned_terms do
    [
      # Auth verb violations — D-02: "sign in" / "sign out" are the canonical verbs
      {"\\blog\\s+in\\b", "sign in", "log in (verb)"},
      {"\\blog\\s+out\\b", "sign out", "log out (verb)"},
      {"\\blogout\\b", "sign out", "logout"},
      {"\\bsignin\\b", "sign in", "signin"},
      {"\\bsign\\s+off\\b", "sign out", "sign off"},
      # Auth noun violations — D-02: "sign-in" is the canonical modifier/noun
      # Note: \blogin\b is also triggered by the "Login preview" heading (admin chrome, line 583)
      # which IS intentionally caught — that heading sits above the carve-out.
      {"\\blogin\\b", "sign-in", "login (noun or modifier)"},
      # Plural sessions — D-02: "sessions" replaces "logins"
      {"\\blogins\\b", "sessions", "logins (plural noun)"},
      # Organization abbreviation in visible copy — D-02: org only in code/slugs
      # \borg\b does NOT match inside "Organization" because \b is a word boundary —
      # "Organization" has no word boundary between "org" and "anization".
      # This pattern catches "org" used standalone in prose copy.
      {"\\borg\\b", "organization", "org (abbreviation — use the full word in visible copy)"},
      # Person-noun violations in org surfaces — D-02: "member(s)" replaces "teammate(s)"
      {"\\bteammates?\\b", "member(s)", "teammate(s)"},
      # Other banned person-noun synonyms (D-02)
      {"\\bcollaborators?\\b", "member(s)", "collaborator(s)"},
      {"\\bseat\\b", "member", "seat (as person-noun)"}
    ]
  end
end
