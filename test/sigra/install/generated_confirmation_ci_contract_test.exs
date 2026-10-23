defmodule Sigra.Install.GeneratedConfirmationCIContractTest do
  use ExUnit.Case, async: true

  @root Path.expand("../../..", __DIR__)

  test "the required generated-host job runs the confirmation Chromium target on pull requests" do
    workflow = committed_read(".github/workflows/ci.yml")
    job = section(workflow, "  generated_admin_playwright_smoke:\n", "  ci-gate:\n")
    job_header = job |> String.split("    services:\n") |> hd()

    assert job =~ "run: scripts/ci/admin-acceptance-smoke.sh --test all"

    refute job_header =~ "if:",
           "generated-host acceptance must run on pull requests as well as other CI events"

    ci_gate = section(workflow, "  ci-gate:\n", nil)

    needs =
      ci_gate |> String.split("    needs:\n") |> Enum.at(1) |> String.split("    if:") |> hd()

    assert needs =~ "- install_smoke",
           "the persisted-state generated-host probe must stay on the required ci-gate"

    assert needs =~ "- generated_admin_playwright_smoke",
           "the browser confirmation journey must stay on the required ci-gate"
  end

  test "the all target invokes the isolated confirmation browser scenario on its live host" do
    script = read("scripts/ci/admin-acceptance-smoke.sh")
    all_target = section(script, "  all)\n", "  chrome)\n")

    assert all_target =~ "RUN_CONFIRMATION=true"
    assert script =~ "if [[ \"${RUN_CONFIRMATION:-false}\" == \"true\" ]]"
    assert script =~ "--project=generated-host-chromium"
    assert script =~ "--output test-results/generated-confirmation"
    assert script =~ "tests/generated-confirmation.spec.ts"
  end

  test "the confirmation project cannot drift into general example browser lanes" do
    config = read("test/example/priv/playwright/playwright.config.ts")
    spec = read("test/example/priv/playwright/tests/generated-confirmation.spec.ts")

    assert config =~ "GENERATED_CONFIRMATION_SPEC"
    assert config =~ "GENERATED_CONFIRMATION_SPEC, DEMO_SHOWCASE_SPEC"
    assert config =~ "name: 'generated-host-chromium'"
    assert config =~ "testMatch: GENERATED_CONFIRMATION_SPEC"
    assert spec =~ "[data-phx-session].phx-connected"
    assert spec =~ "expect\n    .poll"
    assert spec =~ "getByRole(\"alert\")"
    assert spec =~ "getByRole(\"status\")"
    assert spec =~ "ControlOrMeta+V"
    refute spec =~ "waitForTimeout"
  end

  defp read(path), do: File.read!(Path.join(@root, path))

  defp committed_read(path) do
    {contents, 0} =
      System.cmd("git", ["show", "HEAD:#{path}"], cd: @root, stderr_to_stdout: true)

    contents
  end

  defp section(source, start_marker, nil) do
    source |> String.split(start_marker) |> Enum.at(1)
  end

  defp section(source, start_marker, end_marker) do
    source
    |> String.split(start_marker)
    |> Enum.at(1)
    |> String.split(end_marker)
    |> hd()
  end
end
