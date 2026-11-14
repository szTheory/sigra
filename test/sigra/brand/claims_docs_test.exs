defmodule Sigra.Brand.ClaimsDocsTest do
  @moduledoc """
  BCOPY-07 honest-claims contract for published enumeration statements.

  The published docs may claim only what the enumeration parity harness proves:
  an existing and an unknown address get the same status, redirect, flash and
  page for ONE attempt on the sign-in and magic-link request screens. Timing,
  repeated attempts (lockout and rate-limit state), registration success versus
  a duplicate, password reset requests and passkey sign-in are not covered, and
  the docs must say so instead of promising safety.

  This module holds four kinds of checks, each with a planted control so it can
  go red:

    * the retired unbounded phrases are gone from the files that carried them;
    * the three flow guides each carry a paragraph that opens with the bold
      words "Scope of this claim:" and names the uncovered dimensions;
    * `unbounded?/1` recognises an unbounded enumeration claim in prose;
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

  @scope_opener "**Scope of this claim:**"

  # Files whose wording this plan owns, grouped by the task that edits them.
  @flow_guides [@registration, @password_reset, @login_logout]
  @files [@readme | @flow_guides]

  # The exact old strings captured from the docs before they were reworded. A
  # retired string coming back is a regression, so these are never allow-listed.
  @retired %{
    @readme => ["Safer defaults on account discovery flows"],
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
      "Enumeration-safe: same response whether or not the email exists"
    ],
    @login_logout => ["enumeration-safe lookup"]
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
    ~r/\b(?:does\s+not|doesn['’]t|never|without)\s+(?:reveal|disclos|leak|expos)\w*\s+(?:whether|if)\b/iu
  end

  # True when `text` makes an unbounded enumeration claim, whatever else the
  # surrounding text says. Whitespace is collapsed first so a claim wrapped
  # across lines is still seen.
  defp unbounded?(text) do
    flat = collapse(text)

    Enum.any?(family_a_regexes(), &Regex.match?(&1, flat)) or
      Regex.match?(family_b_regex(), flat)
  end

  # Retired phrases still present in `text`.
  defp retired_present(text, phrases), do: Enum.filter(phrases, &String.contains?(text, &1))

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

    test "the sign-in scope bounds the claim to one attempt and names lockout" do
      [paragraph] = scope_paragraphs(read!(@login_logout))

      assert paragraph =~ "single attempt"
      assert paragraph =~ ~r/lockout/i
    end

    test "positive control: a planted file without the opener has no scope paragraph" do
      assert scope_paragraphs("# Guide\n\nScope of this claim: not bold.\n") == []
      assert scope_paragraphs("# Guide\n\n#{@scope_opener} bounded.\n\nOther.\n") != []
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
            "The error does not\nreveal whether the account exists."
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
