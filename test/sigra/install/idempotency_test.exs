defmodule Sigra.Install.IdempotencyTest do
  @moduledoc """
  Phase 11 Wave 4 GEN-04 proof: running `mix sigra.install` twice on
  the same app produces zero new file writes and zero new injections
  on the second invocation.

  Scaffolds a fresh Phoenix tmp app via `Sigra.Test.InstallFixture`,
  runs the installer once (the fixture helper does this as part of
  `setup_tmp_app/1`), then runs it a second time and asserts:

    * the sha256-hashed file tree is byte-identical before/after
      the second run (no rewrite of existing files)
    * on-disk mtimes are unchanged (stronger: proves the runner
      does not even re-open the existing files)
    * the second run's stdout reports at least one skip line via
      the walker's `* skipping <path> (already exists)` /
      `* already injected <path>` emissions
  """
  use ExUnit.Case, async: false

  alias Sigra.Test.InstallFixture

  @moduletag :integration
  @moduletag :idempotency
  @moduletag timeout: 300_000
  @moduletag :scaffold

  setup_all do
    {:ok, %{app_dir: app_dir, stdout: first_stdout}} = InstallFixture.setup_tmp_app()

    on_exit(fn ->
      File.rm_rf!(Path.dirname(app_dir))
    end)

    %{app_dir: app_dir, first_stdout: first_stdout}
  end

  test "second invocation produces zero new file writes and zero new injections",
       %{app_dir: app_dir} do
    snapshot_before = hash_snapshot(app_dir)
    mtimes_before = collect_mtimes(app_dir)

    {second_out, status} =
      System.cmd(
        "mix",
        ["sigra.install", "Accounts", "User", "users", "--yes"],
        cd: app_dir,
        stderr_to_stdout: true,
        env: [{"MIX_ENV", "dev"}]
      )

    assert status == 0, "second sigra.install failed:\n#{second_out}"

    snapshot_after = hash_snapshot(app_dir)
    mtimes_after = collect_mtimes(app_dir)

    # Byte-identity: no file content changed between runs.
    missing_or_changed =
      snapshot_before
      |> Enum.reject(fn {path, hash} -> Map.get(snapshot_after, path) == hash end)
      |> Enum.map(&elem(&1, 0))

    assert missing_or_changed == [],
           "second install run changed file contents — GEN-04 broken:\n" <>
             Enum.join(missing_or_changed, "\n")

    # No new files either.
    new_files =
      snapshot_after
      |> Map.keys()
      |> Kernel.--(Map.keys(snapshot_before))

    assert new_files == [],
           "second install run wrote new files — GEN-04 broken:\n" <>
             Enum.join(new_files, "\n")

    # Stronger check: mtimes are stable — the runner did not even
    # re-open existing files.
    changed_mtimes =
      mtimes_before
      |> Enum.reject(fn {path, mtime} -> Map.get(mtimes_after, path) == mtime end)
      |> Enum.map(&elem(&1, 0))

    assert changed_mtimes == [],
           "second install run touched file mtimes — runner is not skipping existing files:\n" <>
             Enum.join(changed_mtimes, "\n")

    # Second run's output should mention at least one skip
    # (either a file "already exists" or an injection "already injected").
    assert second_out =~ "already exists" or second_out =~ "already injected",
           "second install output did not indicate any skip:\n#{second_out}"
  end

  test "first invocation wrote real files (sanity floor for GEN-04)", %{
    first_stdout: first_stdout
  } do
    assert first_stdout =~ "* creating",
           "first sigra.install run did not report any file creation — harness is broken"
  end

  # -- helpers --------------------------------------------------------------

  defp hash_snapshot(app_dir) do
    tracked = ["lib", "priv/repo/migrations", "config", "test/support"]

    for sub <- tracked,
        abs_sub = Path.join(app_dir, sub),
        File.dir?(abs_sub),
        abs_path <- Path.wildcard(Path.join(abs_sub, "**"), match_dot: true),
        File.regular?(abs_path),
        into: %{} do
      rel = Path.relative_to(abs_path, app_dir)
      {rel, :crypto.hash(:sha256, File.read!(abs_path))}
    end
  end

  defp collect_mtimes(app_dir) do
    tracked = ["lib", "priv/repo/migrations", "config", "test/support"]

    for sub <- tracked,
        abs_sub = Path.join(app_dir, sub),
        File.dir?(abs_sub),
        abs_path <- Path.wildcard(Path.join(abs_sub, "**"), match_dot: true),
        File.regular?(abs_path),
        into: %{} do
      rel = Path.relative_to(abs_path, app_dir)
      %File.Stat{mtime: mtime} = File.stat!(abs_path)
      {rel, mtime}
    end
  end
end
