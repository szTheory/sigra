defmodule Mix.Tasks.Sigra.Fixture.ReblessGolden do
  @shortdoc "Regenerates test/fixtures/install_golden/ from a fresh tmp app"

  @moduledoc """
  Regenerates the `test/fixtures/install_golden/` baseline driven by the
  `Sigra.Test.InstallFixture` harness, then prints a structured delta report
  grouped by top-level directory so the operator can review what changed
  without eyeballing a 20+ file raw diff.

  This automates the manual iex-driven runbook in
  `.planning/phases/24-repair-phase-16-17-organizations-generator-templates/24-01-repair-phase-16-17-org-templates-PLAN.md:953-1025`
  and the older runbook in
  `.planning/phases/11-generator-feature-system/11-01-SUMMARY.md`.

  ## Usage

      MIX_ENV=test mix sigra.fixture.rebless_golden
      MIX_ENV=test mix sigra.fixture.rebless_golden --check

  `--check` writes to a tmp dir and diffs against the committed fixture without
  modifying `test/fixtures/install_golden/`. Exits 2 if drift is detected. This
  mode is suitable for a CI drift-detector job.

  The task does NOT stage, commit, or amend. After a normal (non-check) run,
  review `git diff test/fixtures/install_golden/` before committing.
  """

  use Mix.Task

  # Sigra.Test.InstallFixture only compiles under :test env (test/support),
  # but this mix task lives in lib/ and is therefore compiled in every env.
  # Suppress the "function undefined" compile warning — the run/1 function
  # refuses to proceed unless MIX_ENV=test, at which point the module is
  # loaded. Without this attribute `mix docs --warnings-as-errors` fails
  # on three distinct "module is not available" warnings from the doc-mode
  # compile pass.
  @compile {:no_warn_undefined, Sigra.Test.InstallFixture}

  alias Sigra.Test.InstallFixture

  @fixture_dir "test/fixtures/install_golden"
  @fixture_tree_dir Path.join(@fixture_dir, "tree")
  @fixture_stdout Path.join(@fixture_dir, "STDOUT.txt")

  @impl Mix.Task
  def run(argv) do
    {opts, _, _} = OptionParser.parse(argv, strict: [check: :boolean])
    check? = Keyword.get(opts, :check, false)

    Mix.env(:test)
    Mix.Task.run("loadpaths")
    Mix.Task.run("compile")
    ensure_test_support_loaded!()

    Mix.shell().info(
      "==> sigra.fixture.rebless_golden: scaffolding fresh tmp app via InstallFixture"
    )

    {:ok, %{app_dir: tmp_dir, stdout: raw, baseline_paths: baseline}} =
      InstallFixture.setup_tmp_app()

    tree = InstallFixture.normalize_tree(tmp_dir, baseline)
    stdout = InstallFixture.normalize_stdout(raw, tmp_dir)

    target_tree_dir = if check?, do: tmp_target_dir("tree"), else: @fixture_tree_dir
    target_stdout = if check?, do: tmp_target_dir("STDOUT.txt"), else: @fixture_stdout

    write_tree!(target_tree_dir, tree)
    File.mkdir_p!(Path.dirname(target_stdout))
    File.write!(target_stdout, stdout)

    File.rm_rf!(Path.dirname(tmp_dir))

    if check? do
      run_check!(target_tree_dir, target_stdout)
    else
      report_delta!(@fixture_dir)
    end
  end

  defp ensure_test_support_loaded! do
    # Sigra.Test.InstallFixture is compiled only when elixirc_paths includes
    # test/support — which only happens in :test env. `Mix.Task.run("compile")`
    # above already used the chosen env, but surface a clear error if it was
    # not run in :test.
    unless Code.ensure_loaded?(InstallFixture) do
      Mix.raise("""
      Sigra.Test.InstallFixture is not loaded.

      Run this task with MIX_ENV=test:

          MIX_ENV=test mix sigra.fixture.rebless_golden
      """)
    end
  end

  defp write_tree!(target_tree_dir, tree) do
    # Replace — not merge — so stale leaf files from a prior rebless cannot
    # linger. The fixture layout mirrors the normalized tree exactly.
    File.rm_rf!(target_tree_dir)
    File.mkdir_p!(target_tree_dir)

    for {rel_path, content} <- tree do
      abs = Path.join(target_tree_dir, rel_path)
      File.mkdir_p!(Path.dirname(abs))
      File.write!(abs, content)
    end
  end

  defp tmp_target_dir(suffix) do
    base =
      Path.join(
        System.tmp_dir!(),
        "sigra_rebless_check_#{:erlang.unique_integer([:positive])}"
      )

    Path.join(base, suffix)
  end

  defp run_check!(target_tree_dir, target_stdout) do
    # Compare target vs committed. In --check mode we never write into the
    # repo, so any difference here is real drift from the committed fixture.
    {tree_diff, _tree_code} =
      System.cmd("diff", ["-qr", @fixture_tree_dir, target_tree_dir], stderr_to_stdout: true)

    stdout_equal? =
      File.read!(@fixture_stdout) == File.read!(target_stdout)

    File.rm_rf!(Path.dirname(target_tree_dir))

    cond do
      tree_diff == "" and stdout_equal? ->
        Mix.shell().info("OK: fixture is up-to-date (check mode).")
        :ok

      true ->
        Mix.shell().error("DRIFT DETECTED:")
        if tree_diff != "", do: Mix.shell().error(tree_diff)

        unless stdout_equal?,
          do: Mix.shell().error("  STDOUT.txt differs from regenerated output")

        exit({:shutdown, 2})
    end
  end

  defp report_delta!(fixture_dir) do
    # Use git to enumerate what actually changed in the repo under the fixture
    # directory. This is the same source of truth the operator will see when
    # they run `git status` / `git diff`, so the report can't lie.
    {status_raw, 0} =
      System.cmd("git", ["status", "--porcelain=v1", "--", fixture_dir], stderr_to_stdout: true)

    entries =
      status_raw
      |> String.split("\n", trim: true)
      |> Enum.map(&parse_status_line/1)

    {added, modified, removed, untracked} = bucketize(entries)

    Mix.shell().info("")
    Mix.shell().info("================================================================")
    Mix.shell().info(" Golden fixture regenerated — delta report")
    Mix.shell().info("================================================================")
    Mix.shell().info("")
    Mix.shell().info("Totals:")
    Mix.shell().info("  added:     #{length(added ++ untracked)}")
    Mix.shell().info("  modified:  #{length(modified)}")
    Mix.shell().info("  removed:   #{length(removed)}")
    Mix.shell().info("")

    print_bucket("ADDED (tracked)", added)
    print_bucket("ADDED (untracked — new files)", untracked)
    print_bucket("MODIFIED", modified)
    print_bucket("REMOVED", removed)

    Mix.shell().info("")
    Mix.shell().info("Next steps:")
    Mix.shell().info("  1. git diff --stat #{fixture_dir}")
    Mix.shell().info("  2. Spot-check a few files, especially new ones in unexpected dirs.")
    Mix.shell().info("  3. MIX_ENV=test mix test test/sigra/install/golden_diff_test.exs")
    Mix.shell().info("  4. If green and the delta looks right, commit.")
    Mix.shell().info("")
  end

  defp parse_status_line(line) do
    # porcelain v1: XY<space>path   (X = staged, Y = unstaged)
    # We only care about the Y column here because nothing should be staged
    # during a rebless.
    code = String.slice(line, 0, 2)
    path = line |> String.slice(3..-1//1) |> String.trim()
    {code, path}
  end

  defp bucketize(entries) do
    Enum.reduce(entries, {[], [], [], []}, fn {code, path}, {a, m, r, u} ->
      cond do
        String.starts_with?(code, "??") -> {a, m, r, [path | u]}
        String.contains?(code, "A") -> {[path | a], m, r, u}
        String.contains?(code, "M") -> {a, [path | m], r, u}
        String.contains?(code, "D") -> {a, m, [path | r], u}
        true -> {a, m, r, u}
      end
    end)
    |> then(fn {a, m, r, u} ->
      {Enum.sort(a), Enum.sort(m), Enum.sort(r), Enum.sort(u)}
    end)
  end

  defp print_bucket(_label, []), do: :ok

  defp print_bucket(label, paths) do
    Mix.shell().info("#{label} (#{length(paths)}):")

    paths
    |> Enum.group_by(&top_level_category/1)
    |> Enum.sort_by(fn {k, _} -> k end)
    |> Enum.each(fn {category, files} ->
      Mix.shell().info("  #{category} (#{length(files)})")

      Enum.each(files, fn f ->
        Mix.shell().info("    #{f}")
      end)
    end)

    Mix.shell().info("")
  end

  defp top_level_category(path) do
    # Group by the first 3-4 path segments so the report clusters related
    # files without collapsing everything into "tree/".
    parts = Path.split(path)

    case parts do
      ["test", "fixtures", "install_golden", "tree", a, b, c | _] ->
        Path.join(["tree", a, b, c])

      ["test", "fixtures", "install_golden", "tree", a, b | _] ->
        Path.join(["tree", a, b])

      ["test", "fixtures", "install_golden", "tree", a | _] ->
        Path.join(["tree", a])

      ["test", "fixtures", "install_golden", rest] ->
        rest

      _ ->
        path
    end
  end
end
