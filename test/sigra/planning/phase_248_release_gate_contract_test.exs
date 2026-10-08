defmodule Sigra.Planning.Phase248ReleaseGateContractTest do
  use ExUnit.Case, async: true

  defp root, do: Path.expand("../../..", __DIR__)

  defp read!(rel), do: root() |> Path.join(rel) |> File.read!()

  defp job!(workflow, name) do
    [_before, rest] = String.split(workflow, "  #{name}:\n", parts: 2)

    case String.split(rest, ~r/^  [a-zA-Z_][a-zA-Z0-9_-]*:\s*$/m, parts: 2) do
      [job, _after] -> job
      [job] -> job
    end
  end

  test "primary release evaluation is main-only, run-unique, and non-cancelling" do
    workflow = read!(".github/workflows/release-please.yml")
    release_job = job!(workflow, "release-please")
    gate_job = job!(workflow, "gate-ci-green")

    assert workflow =~ ~r/^permissions:\n(?:  [a-z-]+: read\n)+/m
    assert workflow =~ ~r/^  group: .*github\.run_id.*github\.run_attempt/m
    assert workflow =~ "cancel-in-progress: false"
    assert release_job =~ "if: ${{ github.ref == 'refs/heads/main' }}"
    assert release_job =~ "environment: release-automation"
    assert release_job =~ "token: ${{ secrets.RELEASE_PLEASE_TOKEN }}"
    refute release_job =~ "github.token"
    assert gate_job =~ "timeout-minutes: 75"
    assert gate_job =~ "actions: write"
    assert gate_job =~ "contents: read"
    assert gate_job =~ "--max-attempts 120"
  end

  test "manual recovery runs trusted workflow code from main and cannot publish during dry-run" do
    workflow = read!(".github/workflows/hex-publish.yml")
    publish_job = job!(workflow, "publish")

    assert workflow =~ "if: ${{ github.ref == 'refs/heads/main' }}"
    assert workflow =~ ~r/^  group: .*github\.run_id.*github\.run_attempt/m
    assert workflow =~ "cancel-in-progress: false"
    assert publish_job =~ "environment: hex-publish"
    assert publish_job =~ "ref: ${{ inputs.tag }}"
    assert publish_job =~ "inputs.dry_run == true || steps.idempotency.outputs.skip != 'true'"
    assert publish_job =~ "inputs.dry_run != true && steps.idempotency.outputs.skip != 'true'"
    assert publish_job =~ "inputs.dry_run != true"
  end

  test "merge and publish credentials are environment-bound and step-scoped" do
    release = read!(".github/workflows/release-please.yml")
    merge = read!(".github/workflows/release-pr-automerge.yml")
    recovery = read!(".github/workflows/hex-publish.yml")
    merge_job = job!(merge, "guarded-merge")
    publish_job = job!(recovery, "publish")
    primary_publish = job!(release, "publish-hex")

    assert merge_job =~ "environment: release-automation"
    assert merge =~ "GH_TOKEN: ${{ secrets.RELEASE_PLEASE_TOKEN }}"
    assert merge_job =~ "actions: read"
    assert publish_job =~ "environment: hex-publish"
    assert primary_publish =~ "environment: hex-publish"

    assert release =~ "HEX_API_KEY: ${{ secrets.HEX_DRY_RUN_API_KEY }}"
    assert release =~ "HEX_API_KEY: ${{ secrets.HEX_API_KEY }}"
    assert recovery =~ "HEX_API_KEY: ${{ secrets.HEX_DRY_RUN_API_KEY }}"
    assert recovery =~ "HEX_API_KEY: ${{ secrets.HEX_API_KEY }}"
    ci = read!(".github/workflows/ci.yml") |> String.replace(~r/^\s*#.*$/m, "")
    refute ci =~ ~r/(RELEASE_PLEASE_TOKEN|HEX_(?:DRY_RUN_)?API_KEY)/
  end

  test "only authorized workflows call the environment policy preflight with read permissions" do
    release = read!(".github/workflows/release-please.yml")
    merge = read!(".github/workflows/release-pr-automerge.yml")
    recovery = read!(".github/workflows/hex-publish.yml")

    for {workflow, job_name} <- [
          {release, "release-please"},
          {merge, "guarded-merge"},
          {recovery, "publish"}
        ] do
      job = job!(workflow, job_name)
      assert job =~ "actions: read"
      assert job =~ "release-environment-preflight.sh"
    end

    assert job!(release, "release-please") =~
             ~r/RELEASE_PLEASE_TOKEN_PRESENT:.*secrets\.RELEASE_PLEASE_TOKEN != ''/

    assert job!(recovery, "publish") =~
             ~r/HEX_DRY_RUN_API_KEY_PRESENT:.*secrets\.HEX_DRY_RUN_API_KEY != ''/
  end

  test "every privileged transition checks credential presence without passing values" do
    release = read!(".github/workflows/release-please.yml")
    merge = read!(".github/workflows/release-pr-automerge.yml")
    recovery = read!(".github/workflows/hex-publish.yml")

    callers = [
      {job!(release, "release-please"), "RELEASE_PLEASE_TOKEN", "release-token"},
      {job!(merge, "guarded-merge"), "RELEASE_PLEASE_TOKEN", "release-token"},
      {job!(release, "publish-hex"), "HEX_DRY_RUN_API_KEY", "hex-dry-run-key"},
      {job!(release, "publish-hex"), "HEX_API_KEY", "hex-publish-key"},
      {job!(recovery, "publish"), "HEX_DRY_RUN_API_KEY", "hex-dry-run-key"},
      {job!(recovery, "publish"), "HEX_API_KEY", "hex-publish-key"}
    ]

    for {job, secret, argument} <- callers do
      variable = "#{secret}_PRESENT"
      assert job =~ "#{variable}: ${{ secrets.#{secret} != '' }}"
      assert job =~ "--require-#{argument} \"$#{variable}\""
      refute job =~ ~r/--require-[a-z-]+\s+\$\{\{\s*secrets\./
    end
  end

  test "workflow contracts preserve exact-source release and exact-head CI boundaries" do
    release = read!(".github/workflows/release-please.yml")
    merge = read!(".github/workflows/release-pr-automerge.yml")
    ci = read!(".github/workflows/ci.yml")
    poller = read!("scripts/ci/wait-for-ci-gate.sh")

    assert release =~ "bash scripts/ci/release-exact-source.sh"
    assert release =~ "--max-attempts 120"
    assert poller =~ "MAX_ATTEMPTS=120"
    assert poller =~ "WAIT_SECONDS=30"
    assert merge =~ "--match-head-commit"
    assert ci =~ "release-please--branches--main"
    ci = String.replace(ci, ~r/^\s*#.*$/m, "")
    refute ci =~ ~r/(RELEASE_PLEASE_TOKEN|HEX_(?:DRY_RUN_)?API_KEY)/
  end
end
