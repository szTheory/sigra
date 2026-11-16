defmodule Sigra.Brand.ClaimsDocsTest do
  @moduledoc """
  BCOPY-07 honest-claims contract for published enumeration statements.

  The published docs may claim only what the enumeration parity harness proves:
  an existing and an unknown address get the same status, redirect, flash and
  page for ONE attempt on the sign-in, magic-link and password reset request
  screens, in Sigra's example application. Timing, repeated attempts (lockout
  and rate-limit state), registration success versus a duplicate, passkey
  sign-in and the code generated into an adopter's own application are not
  covered, and the docs must say so instead of promising safety.

  This module holds five kinds of checks, each with a planted control so it can
  go red:

    * the retired unbounded phrases are gone from the files that carried them;
    * the three flow guides each carry a paragraph that opens with the bold
      words "Scope of this claim:" and names the uncovered dimensions;
    * `unbounded?/1` recognises an unbounded enumeration claim in prose;
    * a sweep over `README.md`, every `guides/**/*.md` and `test/example/README.md`
      flags any claim unit (fenced code and HTML comments stripped) that makes
      an unbounded claim without a qualifier phrase in the SAME unit. A unit is
      a prose paragraph, a table row or a list item with its continuation lines,
      so a properly scoped row or item never excuses its siblings. The sweep
      allow-list is shrink-only and every hit is fixed by rewording the doc,
      never by adding an entry;
    * the edited docs cite no planning artifact, todo file or registry id (one
      explicit, shrink-only, pre-existing allow-list entry).

  Pure filesystem; no database is touched. The repo root is resolved from
  `__DIR__`, never from the working directory.
  """
  use ExUnit.Case, async: true

  @root Path.expand("../../..", __DIR__)

  @readme "README.md"
  @registration "guides/flows/registration.md"
  @password_reset "guides/flows/password-reset.md"
  @login_logout "guides/flows/login-and-logout.md"
  @getting_started "guides/introduction/getting-started.md"
  @architecture "guides/introduction/architecture.md"
  @walkthrough "guides/introduction/code-walkthrough.md"
  @demo_showcase "guides/introduction/demo-showcase.md"
  @example_readme "test/example/README.md"

  @scope_opener "**Scope of this claim:**"

  # A claim unit (paragraph, table row or list item) that makes an unbounded
  # claim is allowed when it also carries one of these phrases, because the
  # phrase ties the claim to what the harness compares. Generic wording such as
  # "not covered" is deliberately absent: it can bound anything, so it would let
  # an unrelated sentence launder a claim.
  @qualifiers [
    "Scope of this claim",
    "single attempt",
    "compared case",
    "not part of that comparison"
  ]

  # Files whose wording this plan owns, grouped by the task that edits them.
  @flow_guides [@registration, @password_reset, @login_logout]
  @intro_guides [@getting_started, @architecture, @walkthrough]
  @demo_files [@demo_showcase, @example_readme]
  @files [@readme | @flow_guides] ++ @intro_guides ++ @demo_files

  # Sweep allow-list: `{file, normalized substring}` pairs naming a paragraph
  # that may stay unqualified. It starts empty and every hit is fixed by
  # rewording the doc; it is shrink-only (a stale entry fails), so it can never
  # quietly cover a paragraph that no longer exists.
  @sweep_allow_list []

  # The password reset guide's old statement that Sigra's tests run no comparison
  # of the request screen. It became false once the parity harness compared that
  # screen in the example application, so it is retired as a false statement. It
  # is not an unbounded enumeration claim, so the sweep families do not describe
  # it and the retired-phrase check alone owns it.
  @retired_false_clause "which Sigra's own tests do not currently run"

  # The exact old strings captured from the docs before they were reworded. A
  # retired string coming back is a regression, so these are never allow-listed.
  @retired %{
    @readme => [
      "Safer defaults on account discovery flows",
      "to show the same message for an existing and an unknown address",
      "Each flow guide on HexDocs states its own scope"
    ],
    @registration => [
      "enumeration-safe registration flow",
      "enumeration-safe `{:error, :email_taken}`",
      "enumeration prevention, and audit logging",
      "## Enumeration-safe error handling"
    ],
    @password_reset => [
      "Enumeration-safe: returns",
      "**Enumeration prevention** is the critical property",
      "returns `:ok` (enumeration-safe)",
      "Enumeration-safe: same response whether or not the email exists",
      @retired_false_clause
    ],
    @login_logout => ["enumeration-safe lookup"],
    @getting_started => ["prevents enumeration attacks"],
    @architecture => ["public failures remain enumeration-safe"],
    @walkthrough => [
      "enumeration-safe public failure",
      "it does not reveal whether an unknown email was the cause"
    ],
    @demo_showcase => ["enumeration-resistant login behavior"],
    @example_readme => [
      "enumeration-resistant response",
      "The error does not reveal whether the account exists, is locked, or is unconfirmed"
    ]
  }

  # Pre-existing planning citations that this plan neither edits nor may edit.
  # One `{file, substring}` pair; a stale entry (the substring no longer in the
  # file) fails, so the list can only shrink.
  @allowed_planning_citations [
    {@readme, "live in `.planning/PROJECT.md` under **North Star (milestones)**"}
  ]

  # --- pure helpers -------------------------------------------------------

  defp read!(rel), do: @root |> Path.join(rel) |> File.read!()

  defp collapse(text), do: text |> String.replace(~r/\s+/u, " ") |> String.trim()

  # Paragraphs of a Markdown text, split on blank lines, each trimmed.
  defp paragraphs(text) do
    text
    |> String.split(~r/\n[ \t]*\n/)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end

  # The unbounded claim families. Regexes live in functions, not module
  # attributes, so they are not escaped into function bodies at compile time.
  #
  # Family A: a safety, resistance, prevention or protection label on
  # enumeration, or a verb that promises to stop it.
  defp family_a_regexes do
    [
      ~r/\benumeration[\s-]+(?:safe\w*|safety|resistan\w*|prevent\w*|protect\w*)/i,
      ~r/\b(?:prevent(?:s|ing)?|protects?\s+against|safe\s+(?:from|against))\s+(?:(?:user|account|email)\s+)?enumeration/i
    ]
  end

  # Family B: the non-existence promise ("does not reveal whether ...").
  defp family_b_regex do
    ~r/\b(?:does\s+not|doesn['’]t|never|without)\s+(?:reveal|disclos|leak|expos|indicat|confirm)\w*\s+(?:whether|if)\b/iu
  end

  # Family C: the same promise made without a verb ("indistinguishable",
  # "regardless of whether the account exists").
  defp family_c_regexes do
    [~r/\bindistinguishable\b/i, ~r/\bregardless\s+of\s+whether\b/i]
  end

  # True when `text` makes an unbounded enumeration claim, whatever else the
  # surrounding text says. Whitespace is collapsed first so a claim wrapped
  # across lines is still seen.
  defp unbounded?(text) do
    flat = collapse(text)

    Enum.any?(family_a_regexes(), &Regex.match?(&1, flat)) or
      Regex.match?(family_b_regex(), flat) or
      Enum.any?(family_c_regexes(), &Regex.match?(&1, flat))
  end

  # Retired phrases still present in `text`.
  defp retired_present(text, phrases), do: Enum.filter(phrases, &String.contains?(text, &1))

  # Prose of a Markdown text: fenced code blocks, then HTML comments, removed.
  # Indented code is kept on purpose: a reader still sees it, so a claim in an
  # indented example counts and is reworded rather than exempted.
  defp prose(text) do
    text
    |> then(&Regex.replace(~r/^[ \t]*(`{3,}|~{3,})[^\n]*\n.*?^[ \t]*\1[ \t]*$/ms, &1, "\n"))
    |> then(&Regex.replace(~r/<!--.*?-->/s, &1, ""))
  end

  # True when the unit carries one of the qualifier phrases (case-blind).
  defp qualified?(unit, qualifiers) do
    flat = unit |> collapse() |> String.downcase()
    Enum.any?(qualifiers, &String.contains?(flat, String.downcase(&1)))
  end

  # The claim units of a Markdown text: its prose paragraphs, with every table
  # row and every list item (and its continuation lines) a unit of its own. A
  # table or a list is one blank-line paragraph, so judging it whole would let one
  # properly scoped row or item excuse every sibling.
  defp claim_units(text), do: text |> prose() |> paragraphs() |> Enum.flat_map(&split_units/1)

  defp split_units(paragraph) do
    {units, current} =
      paragraph
      |> String.split("\n")
      |> Enum.reduce({[], []}, fn line, {units, current} ->
        cond do
          table_row?(line) -> {[line | close_unit(units, current)], []}
          list_item?(line) -> {close_unit(units, current), [line]}
          true -> {units, [line | current]}
        end
      end)

    units |> then(&close_unit(&1, current)) |> Enum.reverse()
  end

  defp close_unit(units, []), do: units
  defp close_unit(units, lines), do: [lines |> Enum.reverse() |> Enum.join("\n") | units]

  defp table_row?(line), do: line |> String.trim_leading() |> String.starts_with?("|")
  defp list_item?(line), do: Regex.match?(~r/^\s*(?:[-*+]|\d{1,9}[.)])\s+\S/, line)

  # The claim units of `text` that make an unbounded enumeration claim and carry
  # none of the `qualifiers`, with whitespace collapsed.
  defp unbounded_units(text, qualifiers) do
    for unit <- claim_units(text),
        unbounded?(unit),
        not qualified?(unit, qualifiers),
        do: collapse(unit)
  end

  # Drops the paragraphs a `{file, substring}` allow-list entry for `file`
  # covers (substring compared after whitespace is collapsed).
  defp apply_sweep_allow_list(file, paragraphs, allow_list) do
    covered =
      for {allowed_file, substring} <- allow_list, allowed_file == file, do: collapse(substring)

    Enum.reject(paragraphs, fn paragraph ->
      Enum.any?(covered, &String.contains?(paragraph, &1))
    end)
  end

  # Allow-list entries whose substring no longer matches any prose paragraph of
  # its file; `reader` maps a relative path to its text.
  defp stale_sweep_entries(allow_list, reader) do
    Enum.reject(allow_list, fn {file, substring} ->
      needle = collapse(substring)

      reader.(file)
      |> prose()
      |> paragraphs()
      |> Enum.any?(&String.contains?(collapse(&1), needle))
    end)
  end

  # Every file the sweep covers, relative to the repo root, sorted.
  defp sweep_files do
    guides =
      @root
      |> Path.join("guides/**/*.md")
      |> Path.wildcard()
      |> Enum.map(&Path.relative_to(&1, @root))

    [@readme, @example_readme | guides]
    |> Enum.filter(&File.regular?(Path.join(@root, &1)))
    |> Enum.uniq()
    |> Enum.sort()
  end

  # The paragraph that opens with the bold scope words, when exactly one does.
  defp scope_paragraphs(text) do
    text |> paragraphs() |> Enum.filter(&String.starts_with?(&1, @scope_opener))
  end

  # Planning references left in `text` of `file` after removing the allow-listed
  # citations for that file: the literal `.planning` and `public-surfaces`.
  defp planning_refs(file, text, allowed) do
    stripped =
      for {allowed_file, substring} <- allowed, allowed_file == file, reduce: text do
        acc -> String.replace(acc, substring, "")
      end

    for needle <- [".planning", "public-surfaces"], String.contains?(stripped, needle), do: needle
  end

  defp stale_allow_entries(allowed, reader) do
    Enum.reject(allowed, fn {file, substring} -> String.contains?(reader.(file), substring) end)
  end

  # The first argument of every call to the generated reset-instructions function
  # in `text`. The regex lives in the function, not a module attribute.
  defp reset_call_args(text) do
    ~r/deliver_user_reset_password_instructions\(\s*([^,\s)]+)\s*,/
    |> Regex.scan(text, capture: :all_but_first)
    |> List.flatten()
  end

  # True when a call argument is a user struct rather than an email address: the
  # generated context's only function head requires a binary email.
  defp user_struct_arg?(arg), do: Regex.match?(~r/\A@?(?:\w+\.)*(?:current_)?user\z/, arg)

  # The files of `files` whose text carries a scope paragraph (`reader` maps a
  # relative path to its text), sorted.
  defp scope_carrying(files, reader) do
    files |> Enum.filter(&(scope_paragraphs(reader.(&1)) != [])) |> Enum.sort()
  end

  defp flow_guide_files do
    @root
    |> Path.join("guides/flows/*.md")
    |> Path.wildcard()
    |> Enum.map(&Path.relative_to(&1, @root))
    |> Enum.sort()
  end

  # The text after "Not covered" up to the end of that sentence: the list itself,
  # not a later sentence in the same table cell.
  defp not_covered_list(after_marker) do
    after_marker |> String.split(~r/\.\s+(?=[A-Z])/, parts: 2) |> hd()
  end

  defp readme_enumeration_row do
    @readme
    |> read!()
    |> String.split("\n")
    |> Enum.find(&String.starts_with?(&1, "| **Enumeration** |"))
  end

  # --- the retired phrases are gone --------------------------------------

  describe "retired unbounded phrases" do
    test "none of the edited files still carries a retired phrase" do
      offenders =
        for file <- @files,
            phrase <- retired_present(read!(file), Map.fetch!(@retired, file)),
            do: "#{file}: #{inspect(phrase)}"

      assert offenders == [],
             "Retired unbounded enumeration phrases are back:\n#{Enum.join(offenders, "\n")}"
    end

    test "every edited file has retired phrases registered, so the check is not vacuous" do
      for file <- @files do
        assert [_ | _] = Map.fetch!(@retired, file), "#{file} has no retired phrases"
      end
    end

    test "positive control: a planted retired phrase is reported" do
      planted = "Intro. This flow is enumeration-safe lookup for adopters."

      assert retired_present(planted, Map.fetch!(@retired, @login_logout)) ==
               ["enumeration-safe lookup"]

      assert retired_present("Nothing retired here.", Map.fetch!(@retired, @login_logout)) == []
    end

    test "positive control: every registered retired phrase is reported when planted" do
      for {file, phrases} <- @retired do
        planted = "Intro. " <> Enum.join(phrases, " and ") <> " End."

        assert retired_present(planted, phrases) == phrases,
               "#{file}: a planted retired phrase went unreported"
      end
    end

    test "the introduction guides are part of the retired-phrase check" do
      for file <- @intro_guides do
        assert Map.has_key?(@retired, file), "#{file} is not covered by the retired-phrase map"
        assert file in @files
      end
    end

    test "the retired false clause is registered for the password reset guide and reported when planted" do
      assert @retired_false_clause in Map.fetch!(@retired, @password_reset)

      planted = "Intro. An automated comparison, #{@retired_false_clause}, so check it. End."

      assert retired_present(planted, Map.fetch!(@retired, @password_reset)) ==
               [@retired_false_clause]

      assert retired_present(read!(@password_reset), [@retired_false_clause]) == []
    end

    test "the README keeps its Enumeration row, now with scope" do
      row =
        @readme
        |> read!()
        |> String.split("\n")
        |> Enum.find(&String.starts_with?(&1, "| **Enumeration** |"))

      assert row, "README.md lost its Enumeration row in the security posture table"
      assert row =~ "single attempt"
      assert row =~ "Not covered"
    end

    test "the README row names password-reset requests as tested, not under Not covered" do
      row =
        @readme
        |> read!()
        |> String.split("\n")
        |> Enum.find(&String.starts_with?(&1, "| **Enumeration** |"))

      [tested, after_marker] = String.split(row, "Not covered", parts: 2)
      not_covered = not_covered_list(after_marker)

      assert tested =~ "password-reset requests"
      assert tested =~ "example application"
      # What is claimed is what the harness compares, not that a message is visible.
      assert tested =~ "the same status, redirect, flash message and page"
      refute not_covered =~ ~r/password[\s-]reset/i

      # The row still lists what is not compared.
      assert not_covered =~ "timing"
      assert not_covered =~ "passkey sign-in"
      assert not_covered =~ "generated into your own application"
    end

    test "positive control: the Not covered split reports a reset request left in the list" do
      stale =
        "| **Enumeration** | Sign-in requests are tested. Not covered: timing, password reset requests. |"

      [_tested, after_marker] = String.split(stale, "Not covered", parts: 2)

      assert not_covered_list(after_marker) =~ ~r/password[\s-]reset/i
    end

    test "positive control: the Not covered list ends at its own sentence, a later sentence is not part of it" do
      later =
        "| **Enumeration** | Tested. Not covered: timing. The password-reset guide has a scope. |"

      [_tested, after_marker] = String.split(later, "Not covered", parts: 2)

      refute not_covered_list(after_marker) =~ ~r/password[\s-]reset/i
      assert not_covered_list(after_marker) =~ "timing"
    end
  end

  # --- the scope paragraphs ----------------------------------------------

  describe "Scope of this claim paragraphs" do
    test "each flow guide has exactly one paragraph that opens with the bold scope words" do
      for file <- @flow_guides do
        assert [_one] = scope_paragraphs(read!(file)),
               "#{file} must carry exactly one paragraph opening with #{@scope_opener}"

        assert length(String.split(read!(file), "Scope of this claim:")) == 2,
               "#{file} mentions 'Scope of this claim:' more than once"
      end
    end

    test "each scope paragraph names timing as not covered" do
      for file <- @flow_guides do
        [paragraph] = scope_paragraphs(read!(file))

        assert paragraph =~ ~r/timing/i, "#{file}: scope paragraph does not mention timing"
        assert paragraph =~ ~r/not covered/i, "#{file}: scope paragraph has no 'not covered'"
      end
    end

    test "the registration scope says a duplicate differs from a successful sign-in" do
      [paragraph] = scope_paragraphs(read!(@registration))

      assert paragraph =~ ~r/duplicate/i
      assert paragraph =~ ~r/signs? the (new )?user in/i
      assert paragraph =~ ~r/flash/i
    end

    test "the password reset scope bounds the claim to one attempt and names rate limits" do
      [paragraph] = scope_paragraphs(read!(@password_reset))

      assert paragraph =~ "single attempt"
      assert paragraph =~ ~r/rate limit/i
    end

    test "the password reset scope bounds the comparison to the example application" do
      [paragraph] = scope_paragraphs(read!(@password_reset))

      assert paragraph =~ "example application"
      assert paragraph =~ "single attempt"
      assert paragraph =~ "generated into your app"
      refute paragraph =~ @retired_false_clause
    end

    test "positive control: a scope paragraph that claims no comparison is not bounded to the example application" do
      planted =
        "#{@scope_opener} the form shows one message, which Sigra's own tests do not currently run."

      refute planted =~ "example application"
      assert retired_present(planted, [@retired_false_clause]) == [@retired_false_clause]
    end

    test "the sign-in scope bounds the claim to one attempt and names lockout" do
      [paragraph] = scope_paragraphs(read!(@login_logout))

      assert paragraph =~ "single attempt"
      assert paragraph =~ ~r/lockout/i
    end

    test "positive control: a planted file without the opener has no scope paragraph" do
      assert scope_paragraphs("# Guide\n\nScope of this claim: not bold.\n") == []
      assert scope_paragraphs("# Guide\n\n#{@scope_opener} bounded.\n\nOther.\n") != []
    end

    test "the README names exactly the flow guides that carry a scope paragraph" do
      flow_files = flow_guide_files()

      assert scope_carrying(flow_files, &read!/1) == Enum.sort(@flow_guides)

      assert readme_enumeration_row() =~
               "The registration, sign-in and password-reset guides on HexDocs each state their own scope"
    end

    test "positive control: a scope paragraph in a fourth flow guide changes the carrying set" do
      reader = fn
        "guides/flows/mfa.md" -> "# MFA\n\n#{@scope_opener} bounded.\n"
        file -> read!(file)
      end

      assert "guides/flows/mfa.md" in flow_guide_files()
      assert scope_carrying(flow_guide_files(), reader) != Enum.sort(@flow_guides)

      texts = %{
        "a.md" => "# A\n\n#{@scope_opener} bounded.\n",
        "b.md" => "# B\n\nNo scope here.\n",
        "c.md" => "# C\n\nScope of this claim: not bold.\n"
      }

      assert scope_carrying(Map.keys(texts), &Map.fetch!(texts, &1)) == ["a.md"]
    end
  end

  # --- the unbounded-claim recogniser ------------------------------------

  describe "unbounded?/1 (planted controls)" do
    test "flags a planted unqualified claim" do
      assert unbounded?(
               "By design the form shows one message; this prevents enumeration attacks."
             )
    end

    test "does not flag a planted bounded statement" do
      refute unbounded?("The page shows the same message for the compared case.")
    end

    test "flags every family A wording" do
      for text <- [
            "The flow is enumeration-safe.",
            "Enumeration safety is built in.",
            "an enumeration-resistant response",
            "enumeration resistance by default",
            "**Enumeration prevention** is the critical property",
            "enumeration protection for every screen",
            "this prevents enumeration",
            "preventing user enumeration",
            "it protects against account enumeration",
            "safe from enumeration",
            "safe against email enumeration"
          ] do
        assert unbounded?(text), "should have been flagged: #{inspect(text)}"
      end
    end

    test "flags every family B wording, including a claim wrapped across lines" do
      for text <- [
            "The error does not reveal whether the account exists.",
            "It never discloses if the address is registered.",
            "It works without revealing whether a user exists.",
            "It doesn't leak whether the account is locked.",
            "It does not expose if the account is locked.",
            "The error does not\nreveal whether the account exists.",
            "The page does not indicate whether the account is locked.",
            "It never confirms if the address is registered."
          ] do
        assert unbounded?(text), "should have been flagged: #{inspect(text)}"
      end
    end

    test "flags every family C wording, which makes the promise without a verb" do
      for text <- [
            "The two responses are indistinguishable.",
            "It answers the same regardless of whether the account exists.",
            "Regardless of\nwhether the address is registered, the page is the same."
          ] do
        assert unbounded?(text), "should have been flagged: #{inspect(text)}"
      end
    end

    test "does not flag threat descriptions or neutral wording" do
      for text <- [
            "Reset requests are a common enumeration vector.",
            "The enumeration boundary needs a generic message.",
            "The page reveals whether the address exists.",
            "A claim about safety with no enumeration mention."
          ] do
        refute unbounded?(text), "should not have been flagged: #{inspect(text)}"
      end
    end
  end

  # --- the repo-wide sweep -----------------------------------------------

  describe "unbounded-claim sweep over README.md, guides/**/*.md and test/example/README.md" do
    test "the sweep cannot pass vacuously" do
      files = sweep_files()

      assert @readme in files
      assert @example_readme in files
      assert Enum.any?(files, &String.starts_with?(&1, "guides/flows/"))
      assert Enum.any?(files, &String.starts_with?(&1, "guides/introduction/"))
      assert Enum.any?(files, &String.starts_with?(&1, "guides/reference/"))
      assert length(files) > 20

      for file <- files do
        assert read!(file) != "", "#{file} is empty; the sweep would pass vacuously"
      end
    end

    test "no claim unit (paragraph, table row or list item) makes an unqualified enumeration claim" do
      offenders =
        for file <- sweep_files(),
            paragraph <-
              file
              |> read!()
              |> unbounded_units(@qualifiers)
              |> then(&apply_sweep_allow_list(file, &1, @sweep_allow_list)),
            do: "#{file}: #{String.slice(paragraph, 0, 200)}"

      assert offenders == [],
             """
             Unbounded enumeration claims found. Reword each paragraph, table row or list
             item so that the same unit names the compared case it is bounded to; do not add
             an allow-list entry.

             #{Enum.join(offenders, "\n")}
             """
    end

    test "the sweep allow-list is shrink-only: every entry still matches a paragraph" do
      assert stale_sweep_entries(@sweep_allow_list, &read!/1) == []
    end

    test "the files this plan edited are inside the sweep" do
      files = sweep_files()

      for file <- @files do
        assert file in files, "#{file} is not covered by the sweep"
      end
    end
  end

  describe "sweep helpers (planted controls)" do
    test "a planted unqualified paragraph is flagged" do
      planted =
        "Intro.\n\nBy design the form shows one message; this prevents enumeration attacks.\n"

      assert unbounded_units(planted, @qualifiers) ==
               ["By design the form shows one message; this prevents enumeration attacks."]
    end

    test "a planted family B paragraph is flagged, and qualified it is not" do
      bare = "It does not reveal whether an unknown email was the cause."
      qualified = bare <> " This holds at a single attempt."

      assert unbounded_units(bare, @qualifiers) == [bare]
      assert unbounded_units(qualified, @qualifiers) == []
    end

    test "each qualifier phrase bounds a planted claim, whatever its case" do
      for qualifier <- @qualifiers do
        planted = "The flow is enumeration-safe. " <> String.upcase(qualifier) <> "."

        assert unbounded_units(planted, @qualifiers) == [],
               "qualifier #{inspect(qualifier)} did not bound the paragraph"
      end
    end

    test "a generic 'not covered' no longer bounds a claim, because it can bound anything" do
      planted = "Sigra is enumeration-safe. Windows is not covered."

      assert unbounded_units(planted, @qualifiers) == [collapse(planted)]
      refute "not covered" in Enum.map(@qualifiers, &String.downcase/1)
    end

    test "a claim in a sibling table row of a scoped row is still flagged" do
      planted = """
      | Property | Status |
      | --- | --- |
      | **Enumeration** | Same message for the compared case, single attempt. |
      | **Registration** | Registration is enumeration-safe. |
      """

      assert unbounded_units(planted, @qualifiers) ==
               ["| **Registration** | Registration is enumeration-safe. |"]
    end

    test "the same sibling row inserted under the real README Enumeration row is flagged" do
      readme = read!(@readme)
      row = "| **Registration** | Registration is enumeration-safe. |"

      mutated =
        Regex.replace(~r/^(\| \*\*Enumeration\*\* \|[^\n]*\n)/m, readme, "\\1#{row}\n")

      assert mutated != readme, "the README Enumeration row moved; update this control"
      assert unbounded_units(readme, @qualifiers) == []
      assert unbounded_units(mutated, @qualifiers) == [row]
    end

    test "a claim in a sibling list item of a scoped item is still flagged" do
      planted = """
      - Sign-in shows one message for the compared case.
      - Registration is enumeration-safe.
      """

      assert unbounded_units(planted, @qualifiers) == ["- Registration is enumeration-safe."]
    end

    test "a list item keeps its own continuation lines, and a qualifier in them counts" do
      planted = """
      - Registration is enumeration-safe
        for a single attempt.
      - Another item.
      """

      assert unbounded_units(planted, @qualifiers) == []
    end

    test "a table row carrying its own qualifier is not flagged" do
      planted =
        "| **Enumeration** | Safe for a single attempt, not part of that comparison: timing. |\n"

      assert unbounded_units(planted, @qualifiers) == []
    end

    test "a qualifier in a different paragraph does not bound the claim" do
      planted = "The flow is enumeration-safe.\n\nNot covered: timing.\n"

      assert unbounded_units(planted, @qualifiers) == ["The flow is enumeration-safe."]
    end

    test "a claim wrapped across lines is flagged as one collapsed paragraph" do
      planted = "The error does not\nreveal whether the account exists."

      assert unbounded_units(planted, @qualifiers) ==
               ["The error does not reveal whether the account exists."]
    end

    test "fenced code and HTML comments are stripped, indented code is not" do
      fenced = "Prose.\n\n```elixir\n# this prevents enumeration attacks\n```\n\nAfter.\n"
      tilde = "Prose.\n\n~~~\nenumeration-safe\n~~~\n\nAfter.\n"
      comment = "Prose. <!-- enumeration-resistant -->\n\n<!--\nenumeration-safe\n-->\n\nAfter.\n"
      indented = "Prose:\n\n    # Enumeration-safe: same response\n    redirect(to: \"/\")\n"

      assert unbounded_units(fenced, @qualifiers) == []
      assert unbounded_units(tilde, @qualifiers) == []
      assert unbounded_units(comment, @qualifiers) == []
      assert [_one] = unbounded_units(indented, @qualifiers)
    end

    test "prose after a fenced block closes is still scanned" do
      planted = "```\ncode\n```\n\nThis is enumeration-safe.\n"

      assert unbounded_units(planted, @qualifiers) == ["This is enumeration-safe."]
    end

    test "the retired strings are flagged when planted in memory" do
      retired = @retired |> Map.values() |> List.flatten()
      detectable = Enum.filter(retired, &unbounded?/1)

      # Every retired phrase is either recognised as an unbounded claim by the
      # sweep or caught by the retired-phrase check; plant each in memory. The
      # only retired phrases the sweep families do not describe are the README's
      # vague "Safer defaults" row and the password reset guide's false "tests do
      # not run a comparison" clause, which the retired-phrase check owns.
      assert Enum.sort(retired -- detectable) ==
               Enum.sort(Map.fetch!(@retired, @readme) ++ [@retired_false_clause])

      for phrase <- detectable do
        planted = "Intro.\n\nThe guide says #{phrase} here.\n"

        assert [_one] = unbounded_units(planted, @qualifiers),
               "planted #{inspect(phrase)} was not flagged by the sweep"
      end

      for phrase <- retired -- detectable do
        assert retired_present("Intro #{phrase} end.", [phrase]) == [phrase]
      end
    end

    test "an allow-list entry drops only its own paragraph in its own file" do
      paragraphs = ["The flow is enumeration-safe.", "This prevents enumeration attacks."]
      allow = [{"a.md", "The flow is  enumeration-safe"}]

      assert apply_sweep_allow_list("a.md", paragraphs, allow) == [
               "This prevents enumeration attacks."
             ]

      assert apply_sweep_allow_list("b.md", paragraphs, allow) == paragraphs
    end

    test "a stale allow-list entry is reported, a live one is not" do
      reader = fn "a.md" -> "Intro.\n\nThe flow is enumeration-safe.\n" end

      live = {"a.md", "The flow is enumeration-safe"}
      stale = {"a.md", "text that is not in the file"}

      assert stale_sweep_entries([live, stale], reader) == [stale]
      assert stale_sweep_entries([live], reader) == []
    end

    test "an allow-list entry for text inside a fenced block is stale" do
      reader = fn "a.md" -> "Intro.\n\n```\nThe flow is enumeration-safe\n```\n" end

      entry = {"a.md", "The flow is enumeration-safe"}

      assert stale_sweep_entries([entry], reader) == [entry]
    end
  end

  # --- the reset call shape in published code samples ---------------------

  describe "reset instructions call shape" do
    test "no published guide passes a user struct to deliver_user_reset_password_instructions" do
      offenders =
        for file <- sweep_files(),
            arg <- reset_call_args(read!(file)),
            user_struct_arg?(arg),
            do: "#{file}: deliver_user_reset_password_instructions(#{arg}, ...)"

      assert offenders == [],
             """
             The generated context takes the email address as a string; a sample that
             passes a user struct raises a FunctionClauseError for an address that has an
             account and returns normally for one that does not.

             #{Enum.join(offenders, "\n")}
             """
    end

    test "the check sees the samples: the password reset guide passes the email in both of its calls" do
      args = reset_call_args(read!(@password_reset))

      assert args == ["email", "user.email"]
      refute Enum.any?(args, &user_struct_arg?/1)
    end

    test "positive control: a planted user struct argument is reported, an email is not" do
      one_line = "    Accounts.deliver_user_reset_password_instructions(user, &url/1)\n"

      wrapped =
        "    Accounts.deliver_user_reset_password_instructions(\n      @user,\n      &url/1\n    )\n"

      assigns = "deliver_user_reset_password_instructions(socket.assigns.user, &url/1)"
      current = "deliver_user_reset_password_instructions(current_user, &url/1)"

      for planted <- [one_line, wrapped, assigns, current] do
        assert [arg] = reset_call_args(planted)
        assert user_struct_arg?(arg), "planted #{inspect(planted)} went unreported"
      end

      for planted <- [
            "deliver_user_reset_password_instructions(email, &url/1)",
            "deliver_user_reset_password_instructions(user.email, &url/1)",
            "deliver_user_reset_password_instructions(params[\"email\"], &url/1)"
          ] do
        assert [arg] = reset_call_args(planted)
        refute user_struct_arg?(arg), "planted #{inspect(planted)} was wrongly reported"
      end

      # A mention of the function with no call is not a call.
      assert reset_call_args("`deliver_user_reset_password_instructions/2` sends the email.") ==
               []
    end
  end

  # --- no planning references in published text --------------------------

  describe "planning references" do
    test "the files under test cite no planning artifact, todo file or registry id" do
      offenders =
        for file <- @files,
            needle <- planning_refs(file, read!(file), @allowed_planning_citations),
            do: "#{file}: #{needle}"

      assert offenders == [],
             "Published docs must not cite planning artifacts:\n#{Enum.join(offenders, "\n")}"
    end

    test "the allow-list is shrink-only: every entry still occurs in its file" do
      assert stale_allow_entries(@allowed_planning_citations, &read!/1) == []
    end

    test "the allow-list stays at one pre-existing entry" do
      assert length(@allowed_planning_citations) == 1
    end

    test "positive controls: planted citations are flagged, the allow-listed one is not" do
      [{_, allowed_text}] = @allowed_planning_citations

      assert planning_refs(@readme, "see .planning/todos/x.md", @allowed_planning_citations) ==
               [".planning"]

      assert planning_refs(@registration, "id public-surfaces row", []) == ["public-surfaces"]

      assert planning_refs(@readme, "Maintainers #{allowed_text}.", @allowed_planning_citations) ==
               []

      # The allow-list is per file: the same text in another file is flagged.
      assert planning_refs(@registration, allowed_text, @allowed_planning_citations) ==
               [".planning"]
    end

    test "positive control: a stale allow-list entry is reported" do
      stale = [{@readme, "text that is not in the README"}]

      assert stale_allow_entries(stale, &read!/1) == stale
    end
  end
end
