defmodule Sigra.GuidesDx02Test do
  @moduledoc """
  Automated verification for plan 10-05 Task 3 (DX-02 acceptance bar).

  Replaces the original manual 30-minute checkpoint with measurable
  structural + accuracy checks against three key guides:

    - guides/introduction/getting-started.md
    - guides/flows/mfa.md
    - guides/recipes/testing.md

  This test is the DX-02 tripwire: it catches guide drift from shipped
  code, budget regressions, and structural gaps. The original manual
  walkthrough is deferred to plan 10-06, which exercises the code blocks
  end-to-end against test/example/.
  """

  use ExUnit.Case, async: true

  @guides_root "guides"
  @getting_started Path.join([@guides_root, "introduction", "getting-started.md"])
  @upgrade_guide Path.join([@guides_root, "introduction", "upgrading-to-v1.1.md"])
  @mfa_guide Path.join([@guides_root, "flows", "mfa.md"])
  @testing_guide Path.join([@guides_root, "recipes", "testing.md"])
  @multi_tenant_guide Path.join([@guides_root, "recipes", "multi-tenant.md"])
  @passkeys_guide Path.join([@guides_root, "recipes", "passkeys.md"])
  @subdomain_guide Path.join([@guides_root, "recipes", "subdomain-auth.md"])
  @templates_root Path.join(["priv", "templates", "sigra.install", "core"])

  # Technical-prose reading speed (words per minute). 200 wpm is a
  # conservative estimate for careful technical reading; code blocks are
  # counted separately below at a fixed skim budget.
  @words_per_minute 200

  # Per fenced code block skim budget (seconds). Reading walkthroughs
  # assumes the reader skims code rather than parsing line-by-line.
  @seconds_per_code_block 20

  # Hard ceiling for DX-02 reading time (seconds). 30 minutes.
  @budget_seconds 30 * 60

  # Minimum numbered steps in getting-started.md. Plan claims 10 steps;
  # 8 gives editorial room while still enforcing the walkthrough shape.
  @min_numbered_steps 8

  # Known drift: functions referenced by guides that do not (yet) exist
  # in lib/sigra/ at any arity. Tracked here so the broad signature sweep
  # still reports NEW drift as a failure while acknowledging current
  # state. These are documented follow-ups for a later guide revision.
  #
  # IMPORTANT: Do not add to this list casually. Each entry is a known
  # guide-vs-code mismatch and should be resolved by fixing either the
  # guide or the library.
  @known_library_drift []

  # Generated-host-app helpers that guides reference via the `Sigra.Testing.`
  # prefix for illustrative purposes but which actually live in the
  # generated `MyApp.AuthFixtures` module (priv/templates/sigra.install/
  # auth_fixtures.ex). Verified via template grep below.
  @template_backed_testing_helpers [
    :user_fixture,
    :mfa_complete_fixture
  ]

  # phx.gen.auth helper names that must appear in the install templates.
  # These are the names referenced by getting-started.md code blocks.
  @phx_gen_auth_helpers [
    "register_user",
    "log_in_user",
    "deliver_user_reset_password_instructions",
    "reset_user_password",
    "deliver_user_confirmation_instructions",
    "get_user_by_email_and_password",
    "get_user_by_reset_password_token",
    "delete_user_session_token"
  ]

  # Explicit DX-02 critical allow-list. Every entry must resolve at any
  # arity 0..8 against the loaded module.
  @dx02_allow_list [
    {Sigra.Testing, :setup_totp},
    {Sigra.Testing, :create_api_token},
    {Sigra.MFA, :enroll},
    {Sigra.MFA, :verify_totp},
    {Sigra.Auth, :normalize_email},
    {Sigra.Auth, :valid_email?}
    # Note: Sigra.Auth.register_user is a phx.gen.auth helper that lives
    # in generated host-app code (priv/templates/sigra.install/auth.ex),
    # not in the library. Verified separately in the template sweep below.
  ]

  describe "DX-02 reading time budget (getting-started.md)" do
    test "estimated reading time is under 30 minutes" do
      raw = File.read!(@getting_started)

      {prose, code_block_count} = strip_code_blocks_and_frontmatter(raw)
      word_count = count_words(prose)

      prose_seconds = word_count / @words_per_minute * 60
      code_seconds = code_block_count * @seconds_per_code_block
      total_seconds = prose_seconds + code_seconds

      total_minutes = Float.round(total_seconds / 60, 2)
      prose_minutes = Float.round(prose_seconds / 60, 2)
      code_minutes = Float.round(code_seconds / 60, 2)

      # Stash the metric so failures print a useful diff and passing
      # runs still log the number for SUMMARY.md capture.
      IO.puts(
        "\n[DX-02] getting-started.md reading estimate: " <>
          "#{total_minutes} min total " <>
          "(#{word_count} words / #{prose_minutes} min prose + " <>
          "#{code_block_count} code blocks / #{code_minutes} min skim)"
      )

      assert total_seconds < @budget_seconds,
             """
             getting-started.md exceeds the DX-02 30-minute reading budget.

               Estimated: #{total_minutes} minutes (#{trunc(total_seconds)} seconds)
               Budget:    #{div(@budget_seconds, 60)} minutes
               Overage:   #{Float.round((total_seconds - @budget_seconds) / 60, 2)} minutes

               Prose words:     #{word_count} (@ #{@words_per_minute} wpm)
               Code blocks:     #{code_block_count} (@ #{@seconds_per_code_block}s each)

             Trim prose or consolidate code blocks to fit under the DX-02 bar.
             """
    end

    test "getting-started.md has at least #{@min_numbered_steps} numbered steps" do
      raw = File.read!(@getting_started)

      # Match markdown headers beginning with `## N.` where N is 1-2 digits.
      # This is the walkthrough shape the plan mandates.
      step_count =
        raw
        |> String.split("\n")
        |> Enum.count(fn line ->
          Regex.match?(~r/^##\s+\d{1,2}\.\s+/, line)
        end)

      assert step_count >= @min_numbered_steps,
             "getting-started.md has #{step_count} numbered steps (## N.), " <>
               "expected at least #{@min_numbered_steps}."
    end
  end

  describe "DX-02 signature accuracy" do
    test "explicit allow-list resolves against loaded modules" do
      failures =
        for {mod, fun} <- @dx02_allow_list,
            not function_exported_any_arity?(mod, fun) do
          "#{inspect(mod)}.#{fun}"
        end

      assert failures == [],
             "DX-02 allow-listed references not resolvable at any arity: " <>
               Enum.join(failures, ", ")
    end

    test "Sigra.* references in measured guides match shipped code (or known drift)" do
      guides = [
        @getting_started,
        @upgrade_guide,
        @mfa_guide,
        @testing_guide,
        @multi_tenant_guide,
        @passkeys_guide
      ]

      references =
        guides
        |> Enum.flat_map(&extract_sigra_refs/1)
        |> Enum.uniq()

      # Each reference must either (a) exist in the library at any arity,
      # (b) be a known template-backed testing helper, or (c) appear on
      # the @known_library_drift list. Anything else is new drift and
      # fails this test.
      unresolved =
        for {mod, fun} <- references,
            not function_exported_any_arity?(mod, fun),
            not template_backed?(mod, fun),
            not known_drift?(mod, fun) do
          "#{inspect(mod)}.#{fun}"
        end

      assert unresolved == [],
             """
             Guide references drifted from shipped code:

               #{Enum.join(unresolved, "\n  ")}

             Either: (1) fix the guide to reference a real function,
                     (2) add the function to the library, or
                     (3) if intentional, add it to @known_library_drift
                         in this test with a justification comment.
             """
    end

    test "phx.gen.auth helpers referenced in guides exist in install templates" do
      missing =
        for helper <- @phx_gen_auth_helpers,
            not helper_in_templates?(helper) do
          helper
        end

      assert missing == [],
             "phx.gen.auth helpers referenced by guides but missing from " <>
               "priv/templates/sigra.install/: #{Enum.join(missing, ", ")}"
    end
  end

  describe "DX-02 structural checks" do
    test "mix.exs docs config sets main: \"getting-started\"" do
      mix_contents = File.read!("mix.exs")

      assert mix_contents =~ ~r/main:\s*"getting-started"/,
             "mix.exs must set docs main: \"getting-started\" (plan 10-05 Task 1 Step F)"
    end

    test "all 17 expected guide files exist" do
      expected =
        [
          "introduction/getting-started.md",
          "introduction/installation.md",
          "introduction/upgrading-to-v1.1.md",
          "flows/registration.md",
          "flows/login-and-logout.md",
          "flows/password-reset.md",
          "flows/mfa.md",
          "flows/oauth.md",
          "flows/api-authentication.md",
          "flows/account-lifecycle.md",
          "flows/audit-logging.md",
          "recipes/testing.md",
          "recipes/custom-user-fields.md",
          "recipes/multi-tenant.md",
          "recipes/passkeys.md",
          "recipes/deployment.md",
          "recipes/subdomain-auth.md"
        ]
        |> Enum.map(&Path.join(@guides_root, &1))

      missing = Enum.reject(expected, &File.exists?/1)

      assert missing == [],
             "Missing expected guide files: #{Enum.join(missing, ", ")}"

      assert length(expected) == 17
    end

    test "subdomain-auth.md mentions cookie_domain (10-03 -> 10-04 consistency)" do
      raw = File.read!(@subdomain_guide)

      assert raw =~ "cookie_domain",
             "guides/recipes/subdomain-auth.md must reference cookie_domain " <>
               "(cross-plan consistency with plan 10-03)"
    end

    test "getting-started keeps the organizations and passkeys continuation concise and default-on" do
      raw = File.read!(@getting_started)

      assert raw =~ "## 10. Organizations & Passkeys"
      assert raw =~ "mix sigra.install"
      assert raw =~ "--no-organizations"
      assert raw =~ "--no-passkeys"
      assert raw =~ "Sigra.Organizations.Query.for_org/2"
    end

    test "upgrade guide documents the exercised command paths" do
      raw = File.read!(@upgrade_guide)

      assert raw =~ "mix sigra.upgrade --yes"
      assert raw =~ "mix sigra.upgrade --backfill-personal-orgs --yes"
      assert raw =~ "mix test test/upgrade_test.exs"
      assert raw =~ "passkey_primary_enabled: true"
    end

    test "multi-tenant guide matches the shipped logical-org posture" do
      raw = File.read!(@multi_tenant_guide)

      assert raw =~ "logical multi-tenancy"
      assert raw =~ "Sigra.Organizations.Query.for_org/2"
      assert raw =~ "PG schema-per-tenant"
      refute raw =~ "Sigra does not ship multi-tenancy as a first-class feature"
    end

    test "passkeys guide covers config, rename, and recovery posture" do
      raw = File.read!(@passkeys_guide)

      assert raw =~ "passkey_primary_enabled"
      assert raw =~ "RP ID"
      assert raw =~ "origin"
      assert raw =~ "rename"
      assert raw =~ "magic link"
    end
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  # Strips YAML frontmatter (if any) and fenced code blocks. Returns
  # {prose_string, code_block_count} so callers can budget both.
  defp strip_code_blocks_and_frontmatter(raw) do
    without_frontmatter =
      case Regex.run(~r/\A---\n.*?\n---\n/s, raw) do
        nil -> raw
        [match] -> String.replace_prefix(raw, match, "")
      end

    # Count and strip fenced code blocks (```lang ... ``` style).
    fenced_pattern = ~r/```[^\n]*\n.*?\n```/s
    fenced = Regex.scan(fenced_pattern, without_frontmatter) |> length()
    stripped_fenced = Regex.replace(fenced_pattern, without_frontmatter, "")

    # Also strip 4-space-indented code blocks (markdown indented style,
    # used throughout the Sigra guides). We count them as code blocks
    # too, one per contiguous indented region.
    {no_indented, indented_count} = strip_indented_code(stripped_fenced)

    {no_indented, fenced + indented_count}
  end

  defp strip_indented_code(text) do
    lines = String.split(text, "\n")

    {rev_kept, count, _in_block} =
      Enum.reduce(lines, {[], 0, false}, fn line, {kept, count, in_block} ->
        indented? = Regex.match?(~r/^    \S/, line)
        blank? = line == "" or Regex.match?(~r/^\s*$/, line)

        cond do
          indented? and not in_block ->
            # Start of a new indented block.
            {kept, count + 1, true}

          indented? and in_block ->
            {kept, count, true}

          blank? and in_block ->
            # Blank line inside an indented block; keep collapsing.
            {kept, count, true}

          true ->
            {[line | kept], count, false}
        end
      end)

    {rev_kept |> Enum.reverse() |> Enum.join("\n"), count}
  end

  defp count_words(text) do
    text
    |> String.split(~r/\s+/, trim: true)
    |> length()
  end

  defp function_exported_any_arity?(mod, fun) do
    try do
      Code.ensure_loaded!(mod)
    rescue
      _ -> false
    else
      _ ->
        Enum.any?(0..8, fn arity -> function_exported?(mod, fun, arity) end)
    end
  end

  defp template_backed?(Sigra.Testing, fun) do
    fun in @template_backed_testing_helpers and
      helper_in_templates?(Atom.to_string(fun))
  end

  defp template_backed?(_mod, _fun), do: false

  defp known_drift?(mod, fun) do
    {mod, fun} in @known_library_drift
  end

  defp helper_in_templates?(helper_name) when is_binary(helper_name) do
    pattern = "def #{helper_name}"

    @templates_root
    |> Path.join("*.ex")
    |> Path.wildcard()
    |> Enum.any?(fn file ->
      case File.read(file) do
        {:ok, contents} -> String.contains?(contents, pattern)
        _ -> false
      end
    end)
  end

  # Extracts every `Sigra.Module[.Submod].function` reference from a
  # markdown file. Returns [{Module, :function}, ...] with Module being
  # the fully-qualified alias as an Elixir module atom.
  defp extract_sigra_refs(path) do
    raw = File.read!(path)

    Regex.scan(
      ~r/Sigra(?:\.[A-Z][A-Za-z0-9_]*)+\.([a-z_][a-z0-9_]*[?!]?)/,
      raw
    )
    |> Enum.map(fn [full_match, fun_name] ->
      # Trim the trailing `.function` to isolate the module path.
      mod_string = String.replace_suffix(full_match, "." <> fun_name, "")
      mod = Module.concat([mod_string])
      {mod, String.to_atom(fun_name)}
    end)
  end
end
