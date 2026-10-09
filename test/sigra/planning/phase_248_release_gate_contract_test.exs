defmodule Sigra.Planning.Phase248ReleaseGateContractTest do
  use ExUnit.Case, async: true

  defp root, do: Path.expand("../../..", __DIR__)

  defp read!(rel), do: root() |> Path.join(rel) |> File.read!()

  defp run_bodies(workflow) do
    {bodies, current} =
      workflow
      |> String.split("\n")
      |> Enum.reduce({[], nil}, fn line, {bodies, current} ->
        indent = line |> String.replace(~r/[^ ].*$/, "") |> String.length()

        case Regex.run(~r/^( *)run:\s*(.*)$/, line) do
          [_, spaces, inline] ->
            previous =
              if current,
                do: [Enum.reverse(current.lines) |> Enum.join("\n") | bodies],
                else: bodies

            body = if inline in ["", "|", ">", "|-", ">-"], do: [], else: [inline]
            {previous, %{indent: String.length(spaces), lines: body}}

          nil ->
            cond do
              current && (String.trim(line) == "" || indent > current.indent) ->
                {bodies, %{current | lines: [line | current.lines]}}

              current ->
                {[Enum.reverse(current.lines) |> Enum.join("\n") | bodies], nil}

              true ->
                {bodies, nil}
            end
        end
      end)

    final =
      if current, do: [Enum.reverse(current.lines) |> Enum.join("\n") | bodies], else: bodies

    Enum.reverse(final)
  end

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

  test "manual recovery inputs enter shell scripts through quoted environment variables" do
    workflow = read!(".github/workflows/hex-publish.yml")
    raw_input_expression = ~r/\$\{\{\s*inputs\.(?:tag|release_version)\s*\}\}/

    assert workflow =~ "INPUT_TAG: ${{ inputs.tag }}"
    assert workflow =~ "INPUT_VERSION: ${{ inputs.release_version }}"
    assert workflow =~ "RELEASE_VERSION: ${{ inputs.release_version }}"
    assert run_bodies(workflow) != []

    assert Enum.all?(run_bodies(workflow), fn body ->
             not Regex.match?(raw_input_expression, body)
           end)

    assert workflow =~ "input_ref=\"$INPUT_TAG\""
    assert workflow =~ "input_version=\"$INPUT_VERSION\""
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

  test "failed gate receipts never substitute the release run for CI identity" do
    release = read!(".github/workflows/release-please.yml")
    gate_job = job!(release, "gate-ci-green")
    record_job = job!(release, "record-release-result")

    assert gate_job =~
             "GATE_RUN_ID=\"$(jq -r 'if .run_id == null then \"\" else (.run_id | tostring) end'"

    refute gate_job =~ "GATE_RUN_ID=\"$GITHUB_RUN_ID\""
    refute record_job =~ "GATE_RUN_ID=\"${GATE_RUN_ID:-$RELEASE_RUN_ID}\""
    assert record_job =~ "run_id:(if $gate_id == \"\" then null else $gate_id end)"
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
    assert merge =~ "248-AUTOMERGE-CLAIMS.json"
    assert merge =~ "contents/${path}?ref=${head_sha}"
    assert merge =~ "--claims \"$work_dir/claims.json\""
    assert merge =~ "--source-blobs \"$source_blobs\""
    assert ci =~ "release-please--branches--main"
    ci = String.replace(ci, ~r/^\s*#.*$/m, "")
    refute ci =~ ~r/(RELEASE_PLEASE_TOKEN|HEX_(?:DRY_RUN_)?API_KEY)/
  end

  test "primary terminal receipt is retained before supplementary issue notification" do
    workflow = read!(".github/workflows/release-please.yml")
    receipt_job = job!(workflow, "record-release-result")
    notifier_job = job!(workflow, "notify-release-failure")

    assert receipt_job =~ "if: always()"
    assert receipt_job =~ "needs: [release-please, gate-ci-green, publish-hex]"
    assert receipt_job =~ "release-receipt.sh"
    assert receipt_job =~ "github.event_name"
    assert receipt_job =~ "needs.gate-ci-green.result"
    assert receipt_job =~ "needs.publish-hex.result"
    assert receipt_job =~ "actions/upload-artifact@043fb46d1a93c77aae656e7c1c64a875d1fc6a0a"
    assert receipt_job =~ "retention-days: 90"

    assert notifier_job =~
             "needs: [release-please, gate-ci-green, publish-hex, record-release-result]"

    assert notifier_job =~ "if: >-\n      always()"
    assert notifier_job =~ "notify-failure-issue.sh"
  end

  test "manual recovery stores dry-run and publish outcomes in a source-event receipt" do
    workflow = read!(".github/workflows/hex-publish.yml")
    receipt_job = job!(workflow, "record-recovery-result")
    publish_job = job!(workflow, "publish")

    assert receipt_job =~ "if: always()"
    assert receipt_job =~ "needs: publish"
    assert receipt_job =~ "release-receipt.sh"
    assert workflow =~ "workflow_dispatch"
    assert receipt_job =~ "SOURCE_EVENT: ${{ github.event_name }}"
    assert publish_job =~ "inputs.dry_run"
    assert receipt_job =~ "PUBLISH_OUTCOME: ${{ needs.publish.outputs.publish_outcome }}"
    assert receipt_job =~ "actions/upload-artifact@043fb46d1a93c77aae656e7c1c64a875d1fc6a0a"
    assert receipt_job =~ "retention-days: 90"
    assert receipt_job =~ "SOURCE_SHA_OUTPUT: ${{ needs.publish.outputs.source_sha }}"
    assert receipt_job =~ "refs/tags/${SOURCE_TAG}:refs/tags/${SOURCE_TAG}"
    assert receipt_job =~ "release_input_rejection"
    assert receipt_job =~ "source_identity_unavailable"
    assert receipt_job =~ "terminal_verdict:\"failure\""
    assert workflow =~ "PUBLISH_RESULT=\"dry_run\""
    assert workflow =~ "elif [[ \"$DRY_RUN\" == \"true\" ]]"
    assert workflow =~ "PREFLIGHT_OUTCOME: ${{ steps.credential-preflight.outcome }}"
    assert workflow =~ "SOURCE_CHECKOUT_OUTCOME: ${{ steps.source-checkout.outcome }}"
    assert workflow =~ "credential_preflight_failed"
  end
end
