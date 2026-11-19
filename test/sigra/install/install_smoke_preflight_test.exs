defmodule Sigra.Install.InstallSmokePreflightTest do
  use ExUnit.Case, async: true

  test "rejects an invalid Phoenix app basename before touching the temp path" do
    root = Path.expand("../../..", __DIR__)
    script = Path.join(root, "scripts/ci/install-smoke.sh")
    tmp_app_dir = "/tmp/sigra-invalid-#{System.unique_integer([:positive])}-name"

    refute File.exists?(tmp_app_dir)

    {output, status} =
      System.cmd("bash", [script],
        env: [{"TMP_APP_DIR", tmp_app_dir}, {"GITHUB_WORKSPACE", root}],
        stderr_to_stdout: true
      )

    assert status == 1
    assert output =~ "TMP_APP_DIR basename must be a valid Phoenix app name"
    refute File.exists?(tmp_app_dir)
  end

  test "rejects an outside symlink before creating a parent through it" do
    root = Path.expand("../../..", __DIR__)
    script = Path.join(root, "scripts/ci/install-smoke.sh")
    id = System.unique_integer([:positive])
    link = "/tmp/sigra-install-smoke-link-#{id}"
    outside_parent = Path.join([root, ".planning", "install-smoke-preflight-#{id}"])
    tmp_app_dir = Path.join([link, "created-parent", "sigra_smoke_app"])

    assert :ok = File.ln_s(Path.join(root, ".planning"), link)
    refute File.exists?(outside_parent)

    on_exit(fn ->
      File.rm_rf(outside_parent)
      File.rm(link)
    end)

    {output, status} =
      System.cmd("bash", [script],
        env: [{"TMP_APP_DIR", tmp_app_dir}, {"GITHUB_WORKSPACE", root}],
        stderr_to_stdout: true
      )

    assert status == 1
    assert output =~ "TMP_APP_DIR parent resolves inside the Sigra checkout"
    refute File.exists?(outside_parent)
  end
end
