defmodule Sigra.Brand.CatalogDiffTest do
  @moduledoc """
  Protects `scripts/brand/catalog-diff.sh`, the before/after text-diff report
  (BGEN-07).

  The report is the review artifact for the Phase 262 regeneration, so it has
  to be able to say both things: `no differences` for identical trees and an
  exact changed/added/removed account otherwise. Every case runs the real
  script over planted before/after trees under `System.tmp_dir!/0`; nothing
  here reads the environment and no file under `test/fixtures/brand/before`
  is written (the last two cases only read it and copy it into a temp tree).

  Planted controls, each asserted by its exact lines:

    * identical nested trees: exit 0 and `no differences`
    * one changed line: a `-`/`+` pair and `changed: 1, added: 0, removed: 0`
    * one removed file and one added file, each under its own heading
    * a differing `MANIFEST.json` alone: still `no differences`
    * `--fail-on-diff`: exit 1 on a changed tree, exit 0 without the flag
    * a missing directory argument: exit 2 and a usage message
    * the real committed before directory against a copy of itself, plus the
      same copy with one planted byte (so the report on the real tree is
      shown able to fail)
  """

  use ExUnit.Case, async: true

  @script Path.expand("../../../scripts/brand/catalog-diff.sh", __DIR__)
  @real_before Path.expand("../../fixtures/brand/before", __DIR__)

  setup do
    root =
      Path.join(
        System.tmp_dir!(),
        "sigra_catalog_diff_#{System.unique_integer([:positive])}"
      )

    File.rm_rf!(root)
    File.mkdir_p!(root)
    on_exit(fn -> File.rm_rf!(root) end)

    %{root: root, before: Path.join(root, "before"), after: Path.join(root, "after")}
  end

  defp put!(dir, rel, content) do
    path = Path.join(dir, rel)
    File.mkdir_p!(Path.dirname(path))
    File.write!(path, content)
  end

  defp run(args), do: System.cmd("bash", [@script | args], stderr_to_stdout: true)

  # Two identical trees shaped like the real lanes (nested dirs, several files).
  defp plant_identical!(before, after_dir) do
    for dir <- [before, after_dir] do
      put!(dir, "tier1-library-admin/users-index.html", "<h1>Users</h1>\n<p>Active</p>\n")
      put!(dir, "tier2-example-admin/admin-audit-index.html", "<h1>Audit</h1>\n")
      put!(dir, "generated-host-emails/confirmation.txt", "Confirm your address.\n")
    end
  end

  test "the script exists, is executable and parses as bash" do
    assert File.regular?(@script)
    assert {:ok, %File.Stat{mode: mode}} = File.stat(@script)
    assert Bitwise.band(mode, 0o111) != 0, "scripts/brand/catalog-diff.sh must be executable"
    assert {"", 0} = System.cmd("bash", ["-n", @script], stderr_to_stdout: true)
  end

  describe "identical trees" do
    test "exit 0 and `no differences`", %{before: before, after: after_dir} do
      plant_identical!(before, after_dir)

      {output, status} = run([before, after_dir])

      assert status == 0
      assert output =~ "no differences"
      refute output =~ "Summary:"
    end

    test "--fail-on-diff still exits 0 when nothing differs", %{before: before, after: after_dir} do
      plant_identical!(before, after_dir)

      {output, status} = run(["--fail-on-diff", before, after_dir])

      assert status == 0
      assert output =~ "no differences"
    end
  end

  describe "a changed file" do
    setup %{before: before, after: after_dir} do
      plant_identical!(before, after_dir)

      put!(
        after_dir,
        "tier1-library-admin/users-index.html",
        "<h1>Users</h1>\n<p>Verified</p>\n"
      )

      :ok
    end

    test "is reported as a -/+ pair under its relative path and counted", %{
      before: before,
      after: after_dir
    } do
      {output, status} = run([before, after_dir])

      assert status == 0, "the default mode reports and exits 0"
      assert output =~ "--- before/tier1-library-admin/users-index.html"
      assert output =~ "+++ after/tier1-library-admin/users-index.html"
      assert output =~ "-<p>Active</p>"
      assert output =~ "+<p>Verified</p>"
      assert output =~ "changed: 1, added: 0, removed: 0"
      refute output =~ "no differences"
    end

    test "the report echoes no absolute input path", %{
      root: root,
      before: before,
      after: after_dir
    } do
      {output, 0} = run([before, after_dir])

      refute output =~ root, "the report must print paths relative to each input directory"
      refute output =~ System.tmp_dir!(), "no temp directory path may leak into the report"
    end

    test "--fail-on-diff turns the same tree into exit 1", %{before: before, after: after_dir} do
      {output, status} = run(["--fail-on-diff", before, after_dir])

      assert status == 1
      assert output =~ "changed: 1, added: 0, removed: 0"
    end
  end

  describe "removed and added files" do
    test "a file present only in before is listed as removed", %{before: before, after: after_dir} do
      plant_identical!(before, after_dir)
      put!(before, "tier1-library-admin/only-before.html", "<p>gone</p>\n")

      {output, status} = run([before, after_dir])

      assert status == 0
      assert output =~ "Removed files (1)"
      assert output =~ "  tier1-library-admin/only-before.html"
      refute output =~ "Added files"
      assert output =~ "changed: 0, added: 0, removed: 1"
    end

    test "a file present only in after is listed as added", %{before: before, after: after_dir} do
      plant_identical!(before, after_dir)
      put!(after_dir, "generated-host-pages/only-after.html", "<p>new</p>\n")

      {output, status} = run([before, after_dir])

      assert status == 0
      assert output =~ "Added files (1)"
      assert output =~ "  generated-host-pages/only-after.html"
      refute output =~ "Removed files"
      assert output =~ "changed: 0, added: 1, removed: 0"
    end

    test "all three kinds in one run are each counted once", %{before: before, after: after_dir} do
      plant_identical!(before, after_dir)
      put!(before, "tier1-library-admin/only-before.html", "<p>gone</p>\n")
      put!(after_dir, "generated-host-pages/only-after.html", "<p>new</p>\n")
      put!(after_dir, "tier2-example-admin/admin-audit-index.html", "<h1>Audit log</h1>\n")

      {output, status} = run(["--fail-on-diff", before, after_dir])

      assert status == 1
      assert output =~ "changed: 1, added: 1, removed: 1"
    end
  end

  describe "ignored files" do
    test "a differing MANIFEST.json alone yields `no differences`", %{
      before: before,
      after: after_dir
    } do
      plant_identical!(before, after_dir)
      put!(before, "MANIFEST.json", ~s({"schema": 1, "pinned": "aaaa"}\n))
      put!(after_dir, "MANIFEST.json", ~s({"schema": 1, "pinned": "bbbb"}\n))

      {output, status} = run(["--fail-on-diff", before, after_dir])

      assert status == 0
      assert output =~ "no differences"
    end

    test "a MANIFEST.json present on only one side is not reported as added or removed", %{
      before: before,
      after: after_dir
    } do
      plant_identical!(before, after_dir)
      put!(before, "MANIFEST.json", "{}\n")
      put!(after_dir, ".DS_Store", "clutter")

      {output, status} = run([before, after_dir])

      assert status == 0
      assert output =~ "no differences"
    end

    test "the manifest is ignored but a real change beside it is still reported", %{
      before: before,
      after: after_dir
    } do
      plant_identical!(before, after_dir)
      put!(before, "MANIFEST.json", "{\"a\": 1}\n")
      put!(after_dir, "MANIFEST.json", "{\"a\": 2}\n")
      put!(after_dir, "generated-host-emails/confirmation.txt", "Confirm your account.\n")

      {output, 0} = run([before, after_dir])

      assert output =~ "-Confirm your address."
      assert output =~ "+Confirm your account."
      assert output =~ "changed: 1, added: 0, removed: 0"
      refute output =~ "MANIFEST.json"
    end
  end

  describe "usage errors exit 2" do
    test "a missing after directory", %{before: before, root: root} do
      File.mkdir_p!(before)

      {output, status} = run([before, Path.join(root, "does-not-exist")])

      assert status == 2
      assert output =~ "Usage: catalog-diff.sh"
      assert output =~ "after directory does not exist"
    end

    test "a missing before directory", %{after: after_dir, root: root} do
      File.mkdir_p!(after_dir)

      {output, status} = run([Path.join(root, "does-not-exist"), after_dir])

      assert status == 2
      assert output =~ "Usage: catalog-diff.sh"
      assert output =~ "before directory does not exist"
    end

    test "a single directory argument", %{before: before} do
      File.mkdir_p!(before)

      {output, status} = run([before])

      assert status == 2
      assert output =~ "Usage: catalog-diff.sh"
      assert output =~ "exactly two"
    end

    test "an unknown flag" do
      {output, status} = run(["--no-such-flag"])

      assert status == 2
      assert output =~ "Usage: catalog-diff.sh"
      assert output =~ "unknown argument: --no-such-flag"
    end

    test "--help prints usage and exits 0" do
      {output, status} = run(["--help"])

      assert status == 0
      assert output =~ "Usage: catalog-diff.sh"
      assert output =~ "--fail-on-diff"
    end
  end

  describe "the real committed before directory" do
    test "is present and non-vacuous" do
      files = Path.wildcard(Path.join(@real_before, "**/*")) |> Enum.filter(&File.regular?/1)

      assert length(files) > 1,
             "test/fixtures/brand/before is empty or missing: the real-tree control below would be vacuous"
    end

    test "compared with a copy of itself reports `no differences`", %{root: root} do
      copy = Path.join(root, "before-copy")
      File.cp_r!(@real_before, copy)

      {output, status} = run(["--fail-on-diff", @real_before, copy])

      assert status == 0
      assert output =~ "no differences"
    end

    test "one planted byte in the copy is reported (the report on the real tree can fail)", %{
      root: root
    } do
      copy = Path.join(root, "before-copy")
      File.cp_r!(@real_before, copy)

      target =
        Path.wildcard(Path.join(copy, "**/*.html"))
        |> Enum.sort()
        |> List.first()

      assert target, "no .html file in the real before directory to mutate"

      File.write!(target, File.read!(target) <> "<!-- planted -->\n")

      {output, status} = run(["--fail-on-diff", @real_before, copy])

      assert status == 1
      assert output =~ "+<!-- planted -->"
      assert output =~ "changed: 1, added: 0, removed: 0"
    end
  end
end
