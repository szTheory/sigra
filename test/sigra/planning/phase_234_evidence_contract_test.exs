defmodule Sigra.Planning.Phase234EvidenceContractTest do
  use ExUnit.Case, async: true

  @evidence_path ".planning/phases/234-hygiene-supply-chain-and-contributor-dx/234-EVIDENCE.json"
  @mix_ci_legs [
    "format --check-formatted",
    "deps.get --check-locked",
    "deps.unlock --check-unused",
    "compile --warnings-as-errors",
    "test",
    "ci.install_golden",
    "sigra.dep_off"
  ]

  defp evidence do
    @evidence_path
    |> File.read!()
    |> Jason.decode!()
  end

  defp assert_non_empty_string!(receipt, key) do
    assert is_binary(receipt[key]) and String.trim(receipt[key]) != "",
           "expected #{key} to be a non-empty string, got: #{inspect(receipt[key])}"
  end

  defp assert_sha256!(value, key) do
    assert is_binary(value) and value =~ ~r/\A[0-9a-f]{64}\z/,
           "expected #{key} to be a lowercase SHA-256, got: #{inspect(value)}"
  end

  defp assert_capture_or_success!(receipt, receipt_name, success_assertion) do
    case receipt["status"] do
      "pending" ->
        assert_non_empty_string!(receipt, "diagnostics")

      "success" ->
        success_assertion.()

      other ->
        flunk(
          "#{receipt_name} must be explicitly pending during capture or successful after capture, got: #{inspect(other)}"
        )
    end
  end

  @tag :local_mix_ci
  test "local mix ci receipt is explicitly pending during capture or complete after a clean detached execution" do
    receipt = evidence()["local_mix_ci"]

    assert_capture_or_success!(receipt, "local_mix_ci", fn ->
      assert receipt["conclusion"] == "success"
      assert receipt["clean_before"] == true
      assert receipt["detached_worktree"] == true
      assert receipt["exit_status"] == 0
      assert receipt["command"] == "MIX_ENV=test mix ci"
      assert receipt["ordered_legs"] == @mix_ci_legs
      assert receipt["formatter_check"] == "passed"
      assert receipt["golden_tree"] == "unchanged"

      for key <- ["commit_sha", "started_at", "completed_at", "command_output_path"] do
        assert_non_empty_string!(receipt, key)
      end

      assert receipt["commit_sha"] =~ ~r/\A[0-9a-f]{40}\z/
      assert_sha256!(receipt["log_sha256"], "log_sha256")
    end)
  end

  @tag :pr_ci
  test "PR CI receipt is explicitly pending during capture or complete with one successful owner and aggregate" do
    receipt = evidence()["pr_ci"]

    assert_capture_or_success!(receipt, "pr_ci", fn ->
      assert receipt["event"] == "pull_request"
      assert receipt["conclusion"] == "success"
      assert receipt["direct_mix_ci_step_count"] == 1
      assert receipt["library_suite_owner_count"] == 1
      assert receipt["retired_library_suite_execution_count"] == 0
      assert receipt["continue_on_error_count"] == 0
      assert receipt["library_tests_conclusion"] == "success"
      assert receipt["library_tests_skipped"] == false

      for key <- [
            "commit_sha",
            "run_id",
            "job_id",
            "url",
            "started_at",
            "completed_at",
            "direct_mix_ci_step_name"
          ] do
        assert_non_empty_string!(receipt, key)
      end

      assert receipt["commit_sha"] =~ ~r/\A[0-9a-f]{40}\z/
      assert receipt["run_id"] =~ ~r/\A\d+\z/
      assert receipt["job_id"] =~ ~r/\A\d+\z/
      assert receipt["url"] =~ ~r/\Ahttps:\/\//
      assert_sha256!(receipt["log_sha256"], "log_sha256")
    end)
  end

  @tag :release
  test "release receipt binds the immutable main merge to an executed pinned action" do
    receipt = evidence()["release"]

    assert receipt["status"] == "success"
    assert receipt["event"] == "push"
    assert receipt["workflow_conclusion"] == "success"
    assert receipt["job_conclusion"] == "success"
    assert receipt["action_step_name"] == "Run Release Please"
    assert receipt["action_step_conclusion"] == "success"
    assert receipt["action_ref"] ==
             "googleapis/release-please-action@45996ed1f6d02564a971a2fa1b5860e934307cf7"
    assert receipt["token_source"] == "Actions"
    assert receipt["permissions"] == [
             "actions:write",
             "contents:write",
             "issues:write",
             "pull-requests:write"
           ]
    assert receipt["release_created"] == false

    assert receipt["downstream_jobs"] == %{
             "gate_ci_green" => "skipped_no_release_created",
             "publish_hex" => "skipped_no_release_created"
           }

    for key <- [
          "pr_number",
          "pr_url",
          "merge_sha",
          "run_id",
          "run_url",
          "job_id",
          "job_url",
          "started_at",
          "completed_at",
          "diagnostics"
        ] do
      assert_non_empty_string!(receipt, key)
    end

    assert receipt["pr_number"] =~ ~r/\A\d+\z/
    assert receipt["merge_sha"] =~ ~r/\A[0-9a-f]{40}\z/
    assert receipt["run_id"] =~ ~r/\A\d+\z/
    assert receipt["job_id"] =~ ~r/\A\d+\z/
    assert receipt["pr_url"] =~ ~r/\Ahttps:\/\/github\.com\/szTheory\/sigra\/pull\/\d+\z/
    assert receipt["run_url"] =~ ~r/\Ahttps:\/\/github\.com\/szTheory\/sigra\/actions\/runs\/\d+\z/
    assert receipt["job_url"] =~ ~r/\Ahttps:\/\/github\.com\/szTheory\/sigra\/actions\/runs\/\d+\/job\/\d+\z/
    assert_sha256!(receipt["log_sha256"], "release.log_sha256")
  end
end
