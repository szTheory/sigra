defmodule Sigra.Planning.Phase260PngParkContractTest do
  use ExUnit.Case, async: true

  # Phase 260 (BGEN-06, ADR 005 decision 7): pins the PNG-compare "park" so it is
  # mechanically enforced rather than reviewed. The park skips ONLY the
  # `toHaveScreenshot` comparison on pull_request/push/schedule runs, through the
  # explicit env switch `SIGRA_PNG_COMPARE_SKIP` (`1` = skip; unset or anything
  # else = compare). Axe scans and behavior specs keep running on the PR path.
  #
  # No YAML or TypeScript parser exists in this suite and none is added: these
  # are string/regex assertions over the raw file contents, following the
  # phase_230_design_gallery_split_test.exs idiom. Paths resolve from __DIR__,
  # never the working directory.
  #
  # Every guard below is proven red once by a planted control (see the
  # "compare_gated?/2 positive controls" describe): a source whose screenshot
  # call is unconditional must NOT satisfy the gate.
  @repo_root Path.expand("../../..", __DIR__)
  @ci_path Path.join(@repo_root, ".github/workflows/ci.yml")
  @playwright_tests Path.join(@repo_root, "test/example/priv/playwright/tests")
  @checkpoints_spec Path.join(@playwright_tests, "admin-checkpoints.spec.ts")
  @demo_spec Path.join(@playwright_tests, "demo-showcase.spec.ts")
  @design_spec Path.join(@playwright_tests, "admin-design.spec.ts")
  @pages_path Path.join(@repo_root, ".github/workflows/playwright-github-pages.yml")
  @maintaining_path Path.join(@repo_root, "MAINTAINING.md")
  @drift_script Path.join(@repo_root, "scripts/ci/run-playwright-drift.sh")
  @recapture_gate_script Path.join(@repo_root, "scripts/ci/snapshot-recapture-gate.sh")

  # The single expression every parked step carries. Only `github.event_name`
  # (a fixed GitHub enum) is used, and only through `env:` (never inside `run:`),
  # so there is no workflow-expression injection surface (T-260-03).
  @skip_env_line "SIGRA_PNG_COMPARE_SKIP: ${{ github.event_name == 'workflow_dispatch' && '0' || '1' }}"

  # The three PNG-comparing steps of the `example_playwright_shard` job.
  @parked_steps [
    "Run admin checkpoints",
    "Run design gallery behavior and snapshots",
    "Run demo showcase"
  ]

  # Ruleset-required job names (ruleset 14941512). Renaming any of these strands
  # a required context, so the park must leave all five byte-identical.
  @required_job_names [
    "Library tests",
    "Example unit smoke (ExUnit + ConnTest)",
    "Install smoke (fresh phx.new + sigra.install)",
    "Example HTTP smoke (boot + curl critical routes)",
    "Example Playwright smoke (full lifecycle)"
  ]

  # `skipPngCompare` is declared once per spec from the env switch. Specs differ
  # in quote style, so accept either.
  @skip_const_regex ~r/^const skipPngCompare = process\.env\.SIGRA_PNG_COMPARE_SKIP === ['"]1['"];$/m
  @annotation_regex ~r/type: ['"]png-compare['"]/

  # Extracts a top-level `ci.yml` job's body (from its `<job_id>:` line up to,
  # but not including, the next top-level job's `<job_id>:` line, or end of
  # file if it is the last job). Copied from the phase 230 contract test.
  defp extract_job(content, job_id) do
    job_ids =
      ~r/^  ([a-z_]+):$/m
      |> Regex.scan(content, capture: :all_but_first)
      |> List.flatten()

    idx = Enum.find_index(job_ids, &(&1 == job_id))

    assert idx, "job `#{job_id}:` not found in #{@ci_path}"

    case Enum.at(job_ids, idx + 1) do
      nil ->
        [_, body] = Regex.run(~r/^  #{job_id}:$(.*)\z/ms, content)
        body

      next_id ->
        [_, body] = Regex.run(~r/^  #{job_id}:$(.*?)^  #{next_id}:$/ms, content)
        body
    end
  end

  # Extracts a step body (everything after its `- name: <step_name>` line up to
  # the next `      - name:` line or the end of the given job text). The name
  # match is exact (anchored by the newline), so `Run design gallery behavior`
  # does not swallow `Run design gallery behavior and snapshots`.
  defp extract_step(job_text, step_name) do
    pattern = ~r/^      - name: #{Regex.escape(step_name)}\n(.*?)(?=^      - name:|\z)/ms

    case Regex.run(pattern, job_text, capture: :all_but_first) do
      [body] -> body
      nil -> flunk("step `#{step_name}` not found in the given job text")
    end
  end

  # Splits a step body into the metadata before `run: |` and the shell script.
  defp split_run(step) do
    [meta, run] = String.split(step, ~r/^        run: \|\n/m, parts: 2)
    {meta, run}
  end

  # The step's `env:` map entries (the 10-space-indented lines under `env:`).
  defp env_map(step_meta) do
    case Regex.run(~r/^        env:\n((?:          [^\n]*\n)+)/m, step_meta,
           capture: :all_but_first
         ) do
      [env] -> env
      nil -> flunk("step has no env: map")
    end
  end

  defp count_occurrences(text, needle),
    do: text |> String.split(needle) |> length() |> Kernel.-(1)

  # Asserts one shard step passes the skip switch through its env: map exactly
  # once and never mentions it, or any workflow expression, inside run:.
  defp assert_switch_via_env_only(shard_job, step_name) do
    {meta, run} = shard_job |> extract_step(step_name) |> split_run()
    env = env_map(meta)

    assert env =~ @skip_env_line,
           "`#{step_name}` must set #{@skip_env_line} in its env: map"

    assert count_occurrences(env, "SIGRA_PNG_COMPARE_SKIP:") == 1,
           "`#{step_name}`: the skip switch must appear exactly once in the env: map"

    refute run =~ "SIGRA_PNG_COMPARE_SKIP",
           "`#{step_name}`: the skip switch must reach the spec through env: only, never inside run:"

    refute run =~ "github.event_name",
           "`#{step_name}`: no workflow expression may be interpolated into run: (T-260-03)"
  end

  defp function_body(source, function_name) do
    case Regex.run(~r/async function #{Regex.escape(function_name)}\(.*?\n\}\n/s, source,
           capture: :first
         ) do
      [body] -> body
      nil -> nil
    end
  end

  # Pure gate check over a TypeScript source string. True only when, inside the
  # named function body:
  #   * the compare is guarded by `if (skipPngCompare)` (with a `return` before
  #     the screenshot call) or by `if (!skipPngCompare)` (screenshot after it);
  #   * `toHaveScreenshot(` appears after that guard; and
  #   * every `assertNoAxeViolations(` call appears BEFORE the guard, so the
  #     axe scan can never be parked along with the pixel compare.
  defp compare_gated?(source, function_name) do
    with body when is_binary(body) <- function_body(source, function_name),
         [{guard_at, guard_len}, {_neg_at, neg_len}] <-
           Regex.run(~r/if \(\s*(!?)skipPngCompare\s*\)/, body, return: :index),
         {shot_at, _} <- :binary.match(body, "toHaveScreenshot(") do
      guard_end = guard_at + guard_len
      shot_after_guard? = shot_at > guard_at
      negated? = neg_len == 1

      between =
        if shot_after_guard?, do: binary_part(body, guard_end, shot_at - guard_end), else: ""

      guards_screenshot? =
        if negated?, do: shot_after_guard?, else: shot_after_guard? and between =~ "return"

      axe_before_guard? =
        ~r/assertNoAxeViolations\(/
        |> Regex.scan(body, return: :index)
        |> Enum.all?(fn [{axe_at, _}] -> axe_at < guard_at end)

      guards_screenshot? and axe_before_guard?
    else
      _ -> false
    end
  end

  describe "admin_checkpoints lane (tracer)" do
    test "Run admin checkpoints passes the skip switch through env only" do
      @ci_path
      |> File.read!()
      |> extract_job("example_playwright_shard")
      |> assert_switch_via_env_only("Run admin checkpoints")
    end

    test "assertCheckpointScreenshot keeps axe and parks only the toHaveScreenshot compare" do
      spec = File.read!(@checkpoints_spec)

      assert spec =~ @skip_const_regex,
             "admin-checkpoints.spec.ts must declare skipPngCompare at module scope"

      body = function_body(spec, "assertCheckpointScreenshot")
      assert body, "assertCheckpointScreenshot not found in #{@checkpoints_spec}"

      assert body =~ "assertNoAxeViolations(page,",
             "the axe scan must stay inside assertCheckpointScreenshot (ADR 005 decision 7)"

      assert compare_gated?(spec, "assertCheckpointScreenshot"),
             "toHaveScreenshot must be guarded by skipPngCompare and the axe call must precede the guard"

      assert spec =~ @annotation_regex,
             "a skipped compare must record a Playwright annotation so it is visible in reports"
    end
  end

  describe "demo_showcase and design_gallery @snapshot lanes (expansion)" do
    test "Run demo showcase and Run design gallery behavior and snapshots carry the switch" do
      shard = @ci_path |> File.read!() |> extract_job("example_playwright_shard")

      assert_switch_via_env_only(shard, "Run demo showcase")
      assert_switch_via_env_only(shard, "Run design gallery behavior and snapshots")
    end

    test "exactly the three PNG-comparing shard steps carry the switch" do
      ci = File.read!(@ci_path)
      shard = extract_job(ci, "example_playwright_shard")

      assert count_occurrences(ci, "SIGRA_PNG_COMPARE_SKIP:") == length(@parked_steps),
             "the switch must be set in exactly #{length(@parked_steps)} places in ci.yml"

      assert count_occurrences(shard, "SIGRA_PNG_COMPARE_SKIP:") == length(@parked_steps),
             "all #{length(@parked_steps)} switch settings must live in example_playwright_shard"

      # The PR-lane design step runs --grep-invert '@snapshot' and compares
      # nothing, so it must stay unparked.
      {meta, _run} = shard |> extract_step("Run design gallery behavior") |> split_run()
      refute meta =~ "SIGRA_PNG_COMPARE_SKIP"
    end

    test "assertDemoScreenshot keeps the demo behavior tests and parks only the compare" do
      spec = File.read!(@demo_spec)

      assert spec =~ @skip_const_regex,
             "demo-showcase.spec.ts must declare skipPngCompare at module scope"

      assert compare_gated?(spec, "assertDemoScreenshot"),
             "toHaveScreenshot must be guarded by skipPngCompare in assertDemoScreenshot"

      assert spec =~ @annotation_regex,
             "a skipped demo compare must record a Playwright annotation"

      for title <- [
            "the real login is locked to Tasklane",
            "home page orients evaluators before login",
            "documented evaluator path reaches authenticated flow within ten minutes"
          ] do
        assert spec =~ title, "demo behavior test `#{title}` must still exist"
      end
    end

    test "admin-design board tests test.skip before the compare and the loop shape is unchanged" do
      spec = File.read!(@design_spec)

      assert spec =~ @skip_const_regex,
             "admin-design.spec.ts must declare skipPngCompare at module scope"

      assert spec =~
               "for (const boardId of [...COMPONENT_BOARDS, ...GROUP_BOARDS, ...CONFIG_BOARDS]) {",
             "the board loop header must stay byte-identical (phase 230 pins its shape)"

      board_test_prefix = "test(`board: ${boardId}`, { tag: '@snapshot' }, async"

      assert spec =~ board_test_prefix,
             "the @snapshot board test declaration prefix must stay byte-identical"

      [_before, callback] = String.split(spec, board_test_prefix, parts: 2)
      callback = callback |> String.split("test('axe: full-page", parts: 2) |> hd()

      assert {skip_at, _} = :binary.match(callback, "test.skip(skipPngCompare,"),
             "the board test callback must call test.skip(skipPngCompare, ...) so Playwright reports skipped"

      assert {shot_at, _} = :binary.match(callback, "assertBoardScreenshot(")
      assert skip_at < shot_at, "test.skip must come before assertBoardScreenshot"
    end

    test "the untagged design-gallery axe test is still present" do
      spec = File.read!(@design_spec)

      assert spec =~
               "test('axe: full-page WCAG 2.1/2.2 AA on the design gallery', async ({ page }) => {"
    end
  end

  describe "compare stays on where the switch is not set" do
    test "recapture jobs, drift scripts and the Pages workflow do not set the switch" do
      ci = File.read!(@ci_path)

      for job <- ["admin_design_recapture", "admin_checkpoint_recapture"] do
        job_body = extract_job(ci, job)

        refute job_body =~ "SIGRA_PNG_COMPARE_SKIP",
               "#{job} must not set the switch: unset means compare, and it runs --update-snapshots"

        assert job_body =~ "--update-snapshots",
               "#{job} must still recapture baselines"
      end

      for path <- [@pages_path, @drift_script, @recapture_gate_script] do
        refute File.read!(path) =~ "SIGRA_PNG_COMPARE_SKIP",
               "#{Path.relative_to(path, @repo_root)} needs no edit: compare-on is the default"
      end
    end
  end

  describe "required checks and the canary are untouched" do
    test "the five ruleset-required job names are unchanged" do
      ci = File.read!(@ci_path)

      for name <- @required_job_names do
        assert ci =~ ~r/^    name: #{Regex.escape(name)}\s*(#.*)?$/m,
               "required job name `#{name}` must remain a `name:` value in #{@ci_path}"
      end
    end

    test "fast_checks still runs the impersonation-banner canary guard (never allowlisted)" do
      fast = @ci_path |> File.read!() |> extract_job("fast_checks")

      assert fast =~ "scripts/ci/snapshot-canary-guard.sh"
    end
  end

  describe "MAINTAINING.md documentation" do
    test "the PNG compare switch paragraph states the switch and the dispatch reality" do
      doc = File.read!(@maintaining_path)

      assert [paragraph] = Regex.run(~r/\*\*PNG compare switch.*?(?:\n\n|\z)/s, doc)

      for needle <- [
            "SIGRA_PNG_COMPARE_SKIP",
            "release_ref_guard",
            "phase_244_final_main",
            "recapture_branch",
            "playwright-github-pages.yml",
            "snapshot-canary-guard.sh"
          ] do
        assert paragraph =~ needle, "the paragraph must mention `#{needle}`"
      end
    end
  end

  describe "compare_gated?/2 positive controls" do
    @gated_source """
    async function assertShot(page: Page, testInfo: TestInfo, slug: string) {
      await assertNoAxeViolations(page, `axe:${slug}`);
      if (skipPngCompare) {
        testInfo.annotations.push({ type: 'png-compare', description: 'parked' });
        return;
      }
      await expect(page).toHaveScreenshot(`${slug}.png`, { fullPage: false });
    }
    """

    test "accepts a source that guards the compare after the axe scan (non-vacuity)" do
      assert compare_gated?(@gated_source, "assertShot")
    end

    test "accepts the negated if (!skipPngCompare) block form" do
      source = """
      async function assertShot(page: Page) {
        await assertNoAxeViolations(page, 'axe');
        if (!skipPngCompare) {
          await expect(page).toHaveScreenshot('a.png');
        }
      }
      """

      assert compare_gated?(source, "assertShot")
    end

    test "rejects a source whose toHaveScreenshot call is unconditional" do
      source = """
      async function assertShot(page: Page) {
        await assertNoAxeViolations(page, 'axe');
        await expect(page).toHaveScreenshot('a.png');
      }
      """

      refute compare_gated?(source, "assertShot")
    end

    test "rejects a source that mentions skipPngCompare without an if guard" do
      source = """
      async function assertShot(page: Page) {
        await assertNoAxeViolations(page, 'axe');
        const parked = skipPngCompare;
        await expect(page).toHaveScreenshot('a.png');
      }
      """

      refute compare_gated?(source, "assertShot")
    end

    test "rejects a source whose axe call comes after the guard" do
      source = """
      async function assertShot(page: Page) {
        if (skipPngCompare) {
          return;
        }
        await assertNoAxeViolations(page, 'axe');
        await expect(page).toHaveScreenshot('a.png');
      }
      """

      refute compare_gated?(source, "assertShot")
    end

    test "rejects a source that names a function that does not exist" do
      refute compare_gated?(@gated_source, "assertMissing")
    end
  end
end
