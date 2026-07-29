defmodule Sigra.Planning.Phase230DesignGallerySplitTest do
  use ExUnit.Case, async: true

  # Phase 230 (FAST-02 / D-01): pins the admin-design.spec.ts PR/non-PR
  # partition so it is mechanically enforced rather than reviewed. A board
  # added without the @snapshot tag silently lands on the PR critical path;
  # a tag accidentally placed on test.describe would sweep the WCAG scan and
  # every behavior test off PR along with the pixel diffs. No YAML or
  # TypeScript parser exists in this suite and none is added here -- these
  # are string/regex assertions over the raw file contents, following the
  # phase_153_infra_stability_contract_test.exs idiom.
  @spec_path "test/example/priv/playwright/tests/admin-design.spec.ts"
  @ci_path ".github/workflows/ci.yml"
  @recapture_gate_path "scripts/ci/snapshot-recapture-gate.sh"

  # Plan 230-03: the six seam ids the aggregator must enumerate. A future
  # seventh seam added without an aggregator entry fails this list, not just
  # a hand-written assertion.
  @aggregated_seam_ids [
    "admin_behavior",
    "admin_checkpoints",
    "design_gallery",
    "design_gallery_snapshots",
    "non_admin_smoke",
    "demo_showcase"
  ]

  # Extracts a top-level `ci.yml` job's body (from its `<job_id>:` line up to,
  # but not including, the next top-level job's `<job_id>:` line, or end of
  # file if it is the last job). No YAML parser is used -- this mirrors the
  # phase_153_infra_stability_contract_test.exs File.read! + regex idiom.
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

  test "board loop tags every board test @snapshot and iterates the full board catalog" do
    spec = File.read!(@spec_path)

    assert spec =~
             ~r/for \(const boardId of \[\.\.\.COMPONENT_BOARDS, \.\.\.GROUP_BOARDS, \.\.\.CONFIG_BOARDS\]\) \{\s*\n\s*test\(`board: \$\{boardId\}`, \{ tag: '@snapshot' \}, async/,
           "the board-generation loop must tag every board test @snapshot via the " <>
             "Playwright details-object form and must still iterate the spread of " <>
             "COMPONENT_BOARDS, GROUP_BOARDS and CONFIG_BOARDS -- a board added to any " <>
             "of those arrays without going through this loop, or a loop that loses the " <>
             "tag, silently lands that board test on the PR critical path"
  end

  test "test.describe is not tagged, so tagging cannot sweep all 41 tests per project" do
    spec = File.read!(@spec_path)

    refute spec =~ ~r/test\.describe\('Design gallery board snapshots',\s*\{/,
           "test.describe('Design gallery board snapshots', ...) must not carry a tag " <>
             "details object -- a tag there would sweep all 41 tests per project, " <>
             "including the 12 behavior tests and the new axe test, off the PR lane " <>
             "along with the pixel diffs, silently dropping the WCAG signal from PRs"

    assert spec =~ "test.describe('Design gallery board snapshots', () => {",
           "test.describe should be declared with the plain title+function form"
  end

  test "assertBoardScreenshot no longer calls the axe helper" do
    spec = File.read!(@spec_path)

    # Scope strictly to the assertBoardScreenshot function body (up to the next
    # top-level RESPONSIVE_WIDTHS constant) so the helper's own definition and
    # the new axe test's call site elsewhere in the file cannot defeat this
    # assertion.
    match =
      Regex.run(~r/(async function assertBoardScreenshot.*?)const RESPONSIVE_WIDTHS/s, spec)

    assert match, "assertBoardScreenshot function region not found in #{@spec_path}"
    [_, body] = match

    refute body =~ "assertNoAxeViolations",
           "assertBoardScreenshot must assert a screenshot only -- the WCAG scan was " <>
             "relocated to a dedicated per-design-project axe test so it is not " <>
             "silently re-run once per board again"
  end

  test "the full-page axe test exists and is untagged" do
    spec = File.read!(@spec_path)

    assert spec =~
             "test('axe: full-page WCAG 2.1/2.2 AA on the design gallery', async ({ page }) => {",
           "the dedicated full-page axe test must exist with this exact title so " <>
             "FAST-02's before/after CI proof can find it executing"

    refute spec =~
             ~r/test\('axe: full-page WCAG 2\.1\/2\.2 AA on the design gallery',\s*\{\s*tag:/,
           "the axe test must not carry an @snapshot tag -- it must run on every lane, " <>
             "including PR, or the WCAG accessibility signal silently disappears from PRs"
  end

  test "board catalogs still hold 13 + 11 + 4 = 28 entries" do
    spec = File.read!(@spec_path)

    component_match = Regex.run(~r/const COMPONENT_BOARDS = \[(.*?)\];/s, spec)
    group_match = Regex.run(~r/const GROUP_BOARDS = \[(.*?)\] as const;/s, spec)
    config_match = Regex.run(~r/const CONFIG_BOARDS = \[(.*?)\] as const;/s, spec)

    assert component_match, "COMPONENT_BOARDS array not found in #{@spec_path}"
    assert group_match, "GROUP_BOARDS array not found in #{@spec_path}"
    assert config_match, "CONFIG_BOARDS array not found in #{@spec_path}"

    [_, component_body] = component_match
    [_, group_body] = group_match
    [_, config_body] = config_match

    count_boards = fn body -> body |> then(&Regex.scan(~r/'board-[a-zA-Z0-9_-]+'/, &1)) |> length() end

    component_count = count_boards.(component_body)
    group_count = count_boards.(group_body)
    config_count = count_boards.(config_body)

    assert component_count == 13,
           "COMPONENT_BOARDS must hold exactly 13 entries (got #{component_count}) -- the " <>
             "CI executed-test arithmetic (28 tagged tests per project) depends on this count"

    assert group_count == 11,
           "GROUP_BOARDS must hold exactly 11 entries (got #{group_count}) -- the CI " <>
             "executed-test arithmetic (28 tagged tests per project) depends on this count"

    assert config_count == 4,
           "CONFIG_BOARDS must hold exactly 4 entries (got #{config_count}) -- the CI " <>
             "executed-test arithmetic (28 tagged tests per project) depends on this count"

    assert component_count + group_count + config_count == 28,
           "the three board catalogs must total exactly 28 boards -- this is the number " <>
             "of @snapshot-tagged tests every design project must report per phase 230-02"
  end

  test "admin_design_recapture and snapshot-recapture-gate.sh stay ungrepped" do
    ci = File.read!(@ci_path)
    recapture_job = extract_job(ci, "admin_design_recapture")

    assert recapture_job =~ "tests/admin-design.spec.ts",
           "admin_design_recapture must still invoke #{@spec_path}"

    assert recapture_job =~ "--update-snapshots",
           "admin_design_recapture must still pass --update-snapshots so it recaptures " <>
             "the full board inventory"

    refute recapture_job =~ "--grep",
           "admin_design_recapture must NOT pass any --grep/--grep-invert flag -- a " <>
             "grepped recapture lane recaptures nothing (Pitfall 1) and reports green " <>
             "having regenerated zero baselines"

    gate = File.read!(@recapture_gate_path)

    design_match =
      Regex.run(~r/\(a2\) compare-mode admin design gallery.*?\(c\) ExUnit/s, gate)

    assert design_match,
           "the design-gallery invocation block ((a2)/(b2)) was not found in " <>
             "#{@recapture_gate_path} -- expected markers between " <>
             "\"(a2) compare-mode admin design gallery\" and \"(c) ExUnit\""

    [design_block] = design_match

    assert design_block =~ "tests/admin-design.spec.ts",
           "#{@recapture_gate_path}'s design-gallery block must still invoke #{@spec_path}"

    refute design_block =~ "--grep",
           "#{@recapture_gate_path}'s design-gallery block must NOT pass any --grep/" <>
             "--grep-invert flag -- the local compare-mode gate must keep the full set, " <>
             "or it silently stops comparing the 84 snapshot boards it exists to protect"
  end

  test "the PR lane is filtered and the snapshot lane is event-gated" do
    ci = File.read!(@ci_path)
    job = extract_job(ci, "example_playwright_smoke")

    assert job =~ "design_gallery_snapshots",
           "example_playwright_smoke must contain the design_gallery_snapshots step id"

    gallery_match =
      Regex.run(~r/id: design_gallery\n.*?run: \|(.*?)- name:/s, job)

    assert gallery_match, "design_gallery step's run: block not found in #{@ci_path}"
    [_, gallery_run] = gallery_match

    assert gallery_run =~ "--grep-invert",
           "the design_gallery step's invocation must carry --grep-invert so the PR " <>
             "lane excludes the 84 @snapshot pixel-diff tests"

    snapshots_match =
      Regex.run(~r/id: design_gallery_snapshots\n(.*?)- name: Run non-admin/s, job)

    assert snapshots_match,
           "design_gallery_snapshots step body not found in #{@ci_path}"

    [_, snapshots_body] = snapshots_match

    assert snapshots_body =~ "github.event_name != 'pull_request'",
           "the design_gallery_snapshots step's if: must carry " <>
             "github.event_name != 'pull_request' -- without it the 84-test pixel lane " <>
             "would also run on every PR, defeating the whole demotion"
  end

  test "the aggregator enumerates every seam id" do
    ci = File.read!(@ci_path)
    job = extract_job(ci, "example_playwright_smoke")

    aggregator_match =
      Regex.run(~r/Aggregate Playwright step outcomes.*?\z/s, job)

    assert aggregator_match, "Aggregate Playwright step outcomes step not found in #{@ci_path}"
    [aggregator_region] = aggregator_match

    for seam_id <- @aggregated_seam_ids do
      assert aggregator_region =~ "steps.#{seam_id}.outcome",
             "the seam-outcome aggregator must reference steps.#{seam_id}.outcome -- a " <>
               "seam id missing from this loop has its failures silently discarded on " <>
               "push/schedule/dispatch runs, which is the v1.42 failure mode this " <>
               "milestone exists to remove"
    end
  end
end
