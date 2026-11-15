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

  # The single expression every parked step carries. Only `github.event_name`
  # (a fixed GitHub enum) is used, and only through `env:` (never inside `run:`),
  # so there is no workflow-expression injection surface (T-260-03).
  @skip_env_line "SIGRA_PNG_COMPARE_SKIP: ${{ github.event_name == 'workflow_dispatch' && '0' || '1' }}"

  @skip_const "const skipPngCompare = process.env.SIGRA_PNG_COMPARE_SKIP === '1';"

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

  defp count_occurrences(text, needle), do: text |> String.split(needle) |> length() |> Kernel.-(1)

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
      step =
        @ci_path
        |> File.read!()
        |> extract_job("example_playwright_shard")
        |> extract_step("Run admin checkpoints")

      {meta, run} = split_run(step)
      env = env_map(meta)

      assert env =~ @skip_env_line,
             "`Run admin checkpoints` must set #{@skip_env_line} in its env: map"

      assert count_occurrences(env, "SIGRA_PNG_COMPARE_SKIP:") == 1,
             "the skip switch must appear exactly once in the step's env: map"

      refute run =~ "SIGRA_PNG_COMPARE_SKIP",
             "the skip switch must reach the spec through env: only, never inside run:"

      refute run =~ "github.event_name",
             "no workflow expression may be interpolated into the run: script (T-260-03)"
    end

    test "assertCheckpointScreenshot keeps axe and parks only the toHaveScreenshot compare" do
      spec = File.read!(@checkpoints_spec)

      assert spec =~ @skip_const,
             "admin-checkpoints.spec.ts must declare skipPngCompare at module scope"

      body = function_body(spec, "assertCheckpointScreenshot")
      assert body, "assertCheckpointScreenshot not found in #{@checkpoints_spec}"

      assert body =~ "assertNoAxeViolations(page,",
             "the axe scan must stay inside assertCheckpointScreenshot (ADR 005 decision 7)"

      assert compare_gated?(spec, "assertCheckpointScreenshot"),
             "toHaveScreenshot must be guarded by skipPngCompare and the axe call must precede the guard"

      assert spec =~ "type: 'png-compare'",
             "a skipped compare must record a Playwright annotation so it is visible in reports"
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
