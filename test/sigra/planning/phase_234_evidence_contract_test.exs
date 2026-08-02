defmodule Sigra.Planning.Phase234EvidenceContractTest do
  use ExUnit.Case, async: true

  @evidence_path ".planning/phases/234-hygiene-supply-chain-and-contributor-dx/234-EVIDENCE.json"
  @validation_path ".planning/phases/234-hygiene-supply-chain-and-contributor-dx/234-VALIDATION.md"
  @quick_run_paths [
    "test/sigra/planning/phase_198_contributor_dx_contract_test.exs",
    "test/sigra/planning/phase_233_library_economics_contract_test.exs",
    "test/sigra/planning/phase_234_action_pinning_contract_test.exs",
    "test/sigra/planning/phase_234_dependabot_contract_test.exs",
    "test/sigra/planning/phase_234_playwright_inventory_contract_test.exs",
    "test/sigra/planning/phase_234_evidence_contract_test.exs"
  ]
  @command_receipt_commands [
    "mix test test/sigra/planning/phase_234_evidence_contract_test.exs --only final_evidence",
    "mix test test/sigra/planning/phase_198_contributor_dx_contract_test.exs test/sigra/planning/phase_233_library_economics_contract_test.exs test/sigra/planning/phase_234_action_pinning_contract_test.exs test/sigra/planning/phase_234_dependabot_contract_test.exs test/sigra/planning/phase_234_playwright_inventory_contract_test.exs test/sigra/planning/phase_234_evidence_contract_test.exs --exclude validation_signoff",
    "mix test test/sigra/planning/ --exclude validation_signoff",
    "mix format --check-formatted",
    "test -z \"$(git diff --name-only -- test/fixtures/install_golden/tree)\" && mix test test/sigra/install/golden_diff_test.exs test/sigra/install/idempotency_test.exs"
  ]
  @required_gap_task_receipts [
    {"234-19-01", "mix test test/sigra/planning/phase_234_playwright_inventory_contract_test.exs",
     "✅ green"},
    {"234-19-02",
     "mix test test/sigra/planning/phase_234_playwright_inventory_contract_test.exs && mix test test/sigra/planning/phase_232_playwright_economics_test.exs",
     "✅ green"},
    {"234-20-01",
     "mix test test/sigra/planning/phase_234_evidence_contract_test.exs --only validation_signoff --only final_evidence",
     "✅ green"},
    {"234-20-02",
     "mix test test/sigra/planning/phase_234_evidence_contract_test.exs --only validation_signoff && mix test test/sigra/planning/phase_234_evidence_contract_test.exs --only final_evidence && mix test test/sigra/planning/phase_234_playwright_inventory_contract_test.exs",
     "✅ green"},
    {"234-21-01",
     "mix test test/sigra/planning/phase_234_evidence_contract_test.exs --only validation_signoff && mix test test/sigra/planning/phase_234_evidence_contract_test.exs && mix test test/sigra/planning/phase_234_playwright_inventory_contract_test.exs",
     "✅ green"}
  ]
  @mix_ci_legs [
    "format --check-formatted",
    "deps.get --check-locked",
    "deps.unlock --check-unused",
    "compile --warnings-as-errors",
    "test",
    "ci.install_golden",
    "sigra.dep_off"
  ]
  @dependabot_tuples [
    {"github-actions", "/"},
    {"mix", "/"},
    {"npm", "/test/example/priv/playwright"}
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
      assert :ok = validate_local_mix_ci_receipt!(receipt)
    end)
  end

  @tag :local_mix_ci
  test "local mix ci receipt fails closed when contributor cleanup measurements are mutated" do
    receipt = evidence()["local_mix_ci"]

    assert :ok = validate_local_mix_ci_receipt!(receipt)

    mutations = [
      {"mismatched lock hashes",
       Map.put(receipt, "mix_lock_sha256_after", String.duplicate("0", 64)), "mix_lock_sha256"},
      {"mismatched status hashes",
       Map.put(receipt, "git_status_sha256_after", String.duplicate("0", 64)),
       "git_status_sha256"},
      {"dependency restoration false", Map.put(receipt, "dependency_restore_verified", false),
       "dependency_restore_verified"},
      {"golden/idempotency red", Map.put(receipt, "golden_idempotency_status", "failed"),
       "golden_idempotency_status"}
    ]

    for {name, mutated, field} <- mutations do
      error =
        assert_raise ExUnit.AssertionError, fn ->
          validate_local_mix_ci_receipt!(mutated)
        end

      assert error.message =~ field, "#{name}: #{error.message}"
    end
  end

  defp validate_local_mix_ci_receipt!(receipt) do
    assert receipt["conclusion"] == "success"
    assert receipt["clean_before"] == true, "clean_before must be true"
    assert receipt["clean_after"] == true, "clean_after must be true"
    assert receipt["detached_worktree"] == true, "detached_worktree must be true"

    assert receipt["dependency_restore_verified"] == true,
           "dependency_restore_verified must be true"

    assert receipt["golden_idempotency_status"] == "passed",
           "golden_idempotency_status must be passed"

    assert receipt["exit_status"] == 0
    assert receipt["command"] == "MIX_ENV=test mix ci"
    assert receipt["ordered_legs"] == @mix_ci_legs
    assert receipt["formatter_check"] == "passed"
    assert receipt["golden_tree"] == "unchanged"

    for key <- [
          "commit_sha",
          "started_at",
          "completed_at",
          "command_output_path",
          "mix_lock_sha256_before",
          "mix_lock_sha256_after",
          "git_status_sha256_before",
          "git_status_sha256_after"
        ] do
      assert_non_empty_string!(receipt, key)
    end

    assert receipt["commit_sha"] =~ ~r/\A[0-9a-f]{40}\z/
    assert_sha256!(receipt["log_sha256"], "log_sha256")
    assert_sha256!(receipt["mix_lock_sha256_before"], "mix_lock_sha256_before")
    assert_sha256!(receipt["mix_lock_sha256_after"], "mix_lock_sha256_after")
    assert_sha256!(receipt["git_status_sha256_before"], "git_status_sha256_before")
    assert_sha256!(receipt["git_status_sha256_after"], "git_status_sha256_after")

    assert receipt["mix_lock_sha256_before"] == receipt["mix_lock_sha256_after"],
           "mix_lock_sha256 before/after must match"

    assert receipt["git_status_sha256_before"] == receipt["git_status_sha256_after"],
           "git_status_sha256 before/after must match"

    :ok
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

    assert receipt["run_url"] =~
             ~r/\Ahttps:\/\/github\.com\/szTheory\/sigra\/actions\/runs\/\d+\z/

    assert receipt["job_url"] =~
             ~r/\Ahttps:\/\/github\.com\/szTheory\/sigra\/actions\/runs\/\d+\/job\/\d+\z/

    assert_sha256!(receipt["log_sha256"], "release.log_sha256")
  end

  @tag :dependabot
  test "Dependabot successful processed-job receipts reject exact-set and field mutations" do
    receipt = successful_dependabot_receipt()

    assert :ok = validate_dependabot_receipt!(receipt)

    mutations = [
      {"duplicate tuple", put_in(receipt, ["slots", Access.at(1), "ecosystem"], "github-actions"),
       "tuple"},
      {"missing tuple", %{receipt | "slots" => Enum.take(receipt["slots"], 2)}, "tuple"},
      {"extra tuple", %{receipt | "slots" => receipt["slots"] ++ [List.first(receipt["slots"])]},
       "tuple"},
      {"red status", put_in(receipt, ["slots", Access.at(0), "processed_status"], "failed"),
       "processed_status"},
      {"empty job ID", put_in(receipt, ["slots", Access.at(0), "job_id"], ""), "job_id"},
      {"malformed timestamp", put_in(receipt, ["slots", Access.at(0), "timestamp"], "yesterday"),
       "timestamp"},
      {"wrong job URL",
       put_in(receipt, ["slots", Access.at(0), "job_log_url"], "https://example.com/job"),
       "job_log_url"},
      {"malformed receipt hash",
       put_in(receipt, ["slots", Access.at(0), "capture_sha256"], "hash"), "capture_sha256"},
      {"no PR without successful no-update proof",
       put_in(receipt, ["slots", Access.at(0), "status_summary"], "Processed dependency update"),
       "status_summary"},
      {"config mismatch", Map.put(receipt, "config_sha256", String.duplicate("0", 64)),
       "config_sha256"}
    ]

    for {name, mutated, field} <- mutations do
      error =
        assert_raise ExUnit.AssertionError, fn ->
          validate_dependabot_receipt!(mutated)
        end

      assert error.message =~ field, "#{name}: #{error.message}"
    end
  end

  test "Dependabot evidence has the exact configured tuple set and fails closed when job logs are unavailable" do
    receipt = evidence()["dependabot"]

    assert receipt["default_branch_sha"] =~ ~r/\A[0-9a-f]{40}\z/
    assert_sha256!(receipt["config_sha256"], "dependabot.config_sha256")
    assert receipt["diagnostic_url"] == "https://github.com/szTheory/sigra/network/updates"
    assert_non_empty_string!(receipt, "diagnostics")

    slots = receipt["slots"]

    assert Enum.map(slots, &{&1["ecosystem"], &1["directory"]}) == [
             {"github-actions", "/"},
             {"mix", "/"},
             {"npm", "/test/example/priv/playwright"}
           ]

    case receipt["status"] do
      "success" ->
        assert :ok = validate_dependabot_receipt!(receipt)

      "failed" ->
        for slot <- slots do
          assert slot["status"] == "failed"
          assert_non_empty_string!(slot, "reason")
          assert_non_empty_string!(slot, "diagnostic_url")
          assert slot["diagnostic_url"] =~ ~r/\Ahttps:\/\/github\.com\//
          assert_sha256!(slot["capture_sha256"], "dependabot.capture_sha256")
        end

      other ->
        flunk(
          "Dependabot evidence must be success or failed with durable diagnostics, got: #{inspect(other)}"
        )
    end
  end

  defp successful_dependabot_receipt do
    %{
      "status" => "success",
      "default_branch_sha" => "4935fe65aa80b69fffd3f0efc02911a8515a86f5",
      "config_sha256" => "a6894c6df4edc32b84883c7c9ffab761266c4078a1383ca813f6286c3fbf44e0",
      "slots" =>
        Enum.map(@dependabot_tuples, fn {ecosystem, directory} ->
          %{
            "ecosystem" => ecosystem,
            "directory" => directory,
            "status" => "success",
            "job_id" => "123456789",
            "timestamp" => "2026-08-01T23:59:59Z",
            "processed_status" => "processed_successfully",
            "status_summary" => "Successfully processed; no dependency updates available.",
            "job_log_url" =>
              "https://github.com/szTheory/sigra/network/updates/123456789?ecosystem=#{ecosystem}",
            "capture_sha256" => String.duplicate("a", 64)
          }
        end)
    }
  end

  defp validate_dependabot_receipt!(receipt) do
    assert receipt["status"] == "success", "dependabot.status must be success"

    assert receipt["default_branch_sha"] == "4935fe65aa80b69fffd3f0efc02911a8515a86f5",
           "default_branch_sha must match the authenticated default-branch receipt"

    assert receipt["config_sha256"] ==
             "a6894c6df4edc32b84883c7c9ffab761266c4078a1383ca813f6286c3fbf44e0",
           "config_sha256 must match the decoded default-branch Dependabot configuration"

    slots = receipt["slots"]

    assert is_list(slots), "slots must be a list"

    assert Enum.map(slots, &{&1["ecosystem"], &1["directory"]}) == @dependabot_tuples,
           "tuple set must contain exactly the ordered configured ecosystems/directories"

    Enum.each(slots, &validate_dependabot_slot!/1)
    :ok
  end

  defp validate_dependabot_slot!(slot) do
    assert slot["status"] == "success", "status must name a successful tuple receipt"
    assert_non_empty_string!(slot, "job_id")
    assert slot["job_id"] =~ ~r/\A\d+\z/, "job_id must be numeric"
    assert_non_empty_string!(slot, "timestamp")

    assert match?({:ok, _datetime, 0}, DateTime.from_iso8601(slot["timestamp"])),
           "timestamp must be a UTC ISO-8601 timestamp"

    assert_non_empty_string!(slot, "processed_status")

    assert slot["processed_status"] =~ ~r/processed.*success|success.*processed/i,
           "processed_status must name successful processing"

    assert_non_empty_string!(slot, "status_summary")
    assert_non_empty_string!(slot, "job_log_url")

    assert slot["job_log_url"] =~
             ~r/\Ahttps:\/\/github\.com\/szTheory\/sigra\/network\/updates\/\d+/,
           "job_log_url must be a GitHub Dependabot job-log URL"

    assert_sha256!(slot["capture_sha256"], "dependabot.capture_sha256")

    if is_nil(slot["associated_pr_url"]) do
      assert slot["status_summary"] =~ ~r/no (dependency )?updates?|up[- ]to[- ]date/i,
             "status_summary must prove the successful no-update outcome when associated_pr_url is absent"
    else
      assert is_binary(slot["associated_pr_url"]) and
               slot["associated_pr_url"] =~
                 ~r/\Ahttps:\/\/github\.com\/szTheory\/sigra\/pull\/\d+\z/,
             "associated_pr_url must be a GitHub pull-request URL"
    end
  end

  @tag :gallery
  test "gallery receipt proves the retry-free shared-boot consumer and isolates a non-gating evaluation diagnostic" do
    receipt = evidence()["gallery"]
    historical = evidence()["historical_gallery"]

    assert receipt["status"] == "success"
    assert receipt["event"] == "workflow_dispatch"
    assert receipt["commit_sha"] =~ ~r/\A[0-9a-f]{40}\z/
    assert receipt["job_conclusion"] == "success"
    assert receipt["shared_boot_step_name"] == "Boot example app through shared action"
    assert receipt["shared_boot_conclusion"] == "success"
    assert receipt["retry_count"] == 0
    assert receipt["design_test_count"] == 126
    assert receipt["design_test_result"] == "126 passed (5.4m)"
    assert receipt["snapshot_canary"] == "PASS (0 changed slug(s), all within allowlist)"

    for key <- [
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

    assert receipt["run_id"] =~ ~r/\A\d+\z/
    assert receipt["job_id"] =~ ~r/\A\d+\z/

    assert receipt["run_url"] =~
             ~r/\Ahttps:\/\/github\.com\/szTheory\/sigra\/actions\/runs\/\d+\z/

    assert receipt["job_url"] =~
             ~r/\Ahttps:\/\/github\.com\/szTheory\/sigra\/actions\/runs\/\d+\/job\/\d+\z/

    assert_sha256!(receipt["log_sha256"], "gallery.log_sha256")

    # The dispatch is not globally green because admin_eval_render is deliberately
    # non-gating. Its diagnostic must be named instead of being misattributed to the
    # successful gallery receipt.
    assert receipt["workflow_conclusion"] == "failure"
    admin_eval = receipt["non_gating_admin_eval"]
    assert admin_eval["conclusion"] == "failure"
    assert admin_eval["failure_step"] == "Fail the job if harness did not PASS"
    assert admin_eval["job_id"] =~ ~r/\A\d+\z/

    assert admin_eval["job_url"] =~
             ~r/\Ahttps:\/\/github\.com\/szTheory\/sigra\/actions\/runs\/\d+\/job\/\d+\z/

    assert_non_empty_string!(admin_eval, "diagnostics")

    assert historical["status"] == "success"
    assert historical["run_id"] == "30659282026"
    assert historical["design_test_count"] == 126
    assert_non_empty_string!(historical, "diagnostics")
  end

  @tag :final_evidence
  test "final evidence names every GitHub-owned slot as successful only with a valid Dependabot receipt" do
    receipts = evidence()

    for slot <- [
          "local_mix_ci",
          "pr_ci",
          "release",
          "dependabot",
          "gallery",
          "historical_gallery"
        ] do
      assert is_map(receipts[slot]), "missing evidence slot #{slot}"
      assert_non_empty_string!(receipts[slot], "status")
    end

    assert receipts["release"]["status"] == "success"
    assert receipts["gallery"]["status"] == "success"
    assert receipts["historical_gallery"]["status"] == "success"
    assert receipts["dependabot"]["status"] == "success"
    assert_non_empty_string!(receipts["dependabot"], "diagnostics")
  end

  defp validate_pr_ci_receipt!(receipt) do
    assert receipt["status"] == "success", "pr_ci.status must be success"
    assert receipt["event"] == "pull_request", "pr_ci.event must be pull_request"
    assert receipt["conclusion"] == "success", "pr_ci.conclusion must be success"
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
    assert_sha256!(receipt["log_sha256"], "pr_ci.log_sha256")
    :ok
  end

  defp validate_release_receipt!(receipt) do
    assert receipt["status"] == "success", "release.status must be success"
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

    assert receipt["run_url"] =~
             ~r/\Ahttps:\/\/github\.com\/szTheory\/sigra\/actions\/runs\/\d+\z/

    assert receipt["job_url"] =~
             ~r/\Ahttps:\/\/github\.com\/szTheory\/sigra\/actions\/runs\/\d+\/job\/\d+\z/

    assert_sha256!(receipt["log_sha256"], "release.log_sha256")
    :ok
  end

  defp validate_gallery_receipt!(receipt) do
    assert receipt["status"] == "success", "gallery.status must be success"
    assert receipt["event"] == "workflow_dispatch"
    assert receipt["commit_sha"] =~ ~r/\A[0-9a-f]{40}\z/
    assert receipt["job_conclusion"] == "success"
    assert receipt["shared_boot_step_name"] == "Boot example app through shared action"
    assert receipt["shared_boot_conclusion"] == "success"
    assert receipt["retry_count"] == 0
    assert receipt["design_test_count"] == 126
    assert receipt["design_test_result"] == "126 passed (5.4m)"
    assert receipt["snapshot_canary"] == "PASS (0 changed slug(s), all within allowlist)"

    for key <- [
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

    assert receipt["run_id"] =~ ~r/\A\d+\z/
    assert receipt["job_id"] =~ ~r/\A\d+\z/

    assert receipt["run_url"] =~
             ~r/\Ahttps:\/\/github\.com\/szTheory\/sigra\/actions\/runs\/\d+\z/

    assert receipt["job_url"] =~
             ~r/\Ahttps:\/\/github\.com\/szTheory\/sigra\/actions\/runs\/\d+\/job\/\d+\z/

    assert_sha256!(receipt["log_sha256"], "gallery.log_sha256")
    assert receipt["workflow_conclusion"] == "failure"
    admin_eval = receipt["non_gating_admin_eval"]
    assert admin_eval["conclusion"] == "failure"
    assert admin_eval["failure_step"] == "Fail the job if harness did not PASS"
    assert admin_eval["job_id"] =~ ~r/\A\d+\z/

    assert admin_eval["job_url"] =~
             ~r/\Ahttps:\/\/github\.com\/szTheory\/sigra\/actions\/runs\/\d+\/job\/\d+\z/

    assert_non_empty_string!(admin_eval, "diagnostics")
    :ok
  end

  defp validate_historical_gallery_receipt!(receipt) do
    assert receipt["status"] == "success", "historical_gallery.status must be success"
    assert receipt["run_id"] == "30659282026"
    assert receipt["design_test_count"] == 126
    assert_non_empty_string!(receipt, "diagnostics")
    :ok
  end

  defp validate_required_evidence!(receipts) do
    required =
      MapSet.new([
        "local_mix_ci",
        "pr_ci",
        "release",
        "dependabot",
        "gallery",
        "historical_gallery"
      ])

    assert MapSet.new(Map.keys(Map.delete(receipts, "schema_version"))) == required,
           "evidence must contain the exact required six-slot set"

    for {slot, validator} <- [
          {"local_mix_ci", &validate_local_mix_ci_receipt!/1},
          {"pr_ci", &validate_pr_ci_receipt!/1},
          {"release", &validate_release_receipt!/1},
          {"dependabot", &validate_dependabot_receipt!/1},
          {"gallery", &validate_gallery_receipt!/1},
          {"historical_gallery", &validate_historical_gallery_receipt!/1}
        ] do
      try do
        assert :ok = validator.(receipts[slot])
      rescue
        error in ExUnit.AssertionError -> flunk("#{slot} receipt invalid: #{error.message}")
      end
    end

    :ok
  end

  @tag :validation_signoff
  test "validation sign-off parses the exact green inventory before authorizing completion" do
    validation = File.read!(@validation_path)

    assert %{
             frontmatter: %{
               "status" => "complete",
               "nyquist_compliant" => "true",
               "wave_0_complete" => "true",
               "reviewed_commit_sha" => reviewed_commit_sha,
               "reviewed_at" => reviewed_at
             },
             quick_run_paths: @quick_run_paths,
             wave_0_items: wave_0_items,
             task_statuses: task_statuses,
             command_receipts: command_receipts,
             gap_task_receipts: @required_gap_task_receipts,
             approval: approval
           } = parsed = parse_validation!(validation)

    assert reviewed_commit_sha =~ ~r/\A[0-9a-f]{40}\z/
    assert match?({:ok, _, 0}, DateTime.from_iso8601(reviewed_at))

    assert Enum.all?(wave_0_items, & &1.complete)
    assert Enum.all?(task_statuses, &(&1 == "✅ green"))

    assert :complete =
             assert_transition_allowed!(parsed.frontmatter, evidence(), command_receipts)

    assert approval =~ "machine evidence ratified"
    assert approval =~ "234-19-01, 234-19-02, 234-20-01, 234-20-02, and 234-21-01"
  end

  @tag :validation_signoff
  test "a stale quick-run contract path fails closed with the named path" do
    validation = File.read!(@validation_path)

    stale_path = "test/sigra/planning/stale_phase_234_contract_test.exs"

    stale_validation =
      String.replace(
        validation,
        "test/sigra/planning/phase_234_dependabot_contract_test.exs",
        stale_path,
        global: false
      )
      |> String.replace("| 1 |", "| 0 |")

    error =
      assert_raise ExUnit.AssertionError, fn ->
        parse_validation!(stale_validation)
      end

    assert error.message =~ stale_path
  end

  @tag :validation_signoff
  test "validation sign-off binds every receipt to one reviewed snapshot" do
    parsed = parse_validation!(File.read!(@validation_path))

    assert parsed.frontmatter["reviewed_commit_sha"] =~ ~r/\A[0-9a-f]{40}\z/

    assert parsed.frontmatter["reviewed_at"] =~ ~r/\A\d{4}-\d\d-\d\dT\d\d:\d\d:\d\dZ\z/

    assert Enum.all?(parsed.command_receipts, fn receipt ->
             receipt.commit_sha == parsed.frontmatter["reviewed_commit_sha"]
           end)
  end

  @tag :validation_signoff
  test "production transition rejects bare and partial successful evidence receipts" do
    complete = %{
      "status" => "complete",
      "nyquist_compliant" => "true",
      "wave_0_complete" => "true",
      "reviewed_commit_sha" => String.duplicate("b", 40),
      "reviewed_at" => "2026-08-02T04:00:00Z"
    }

    green_commands = green_command_receipts()
    green_evidence = evidence()

    assert :complete = assert_transition_allowed!(complete, green_evidence, green_commands)

    for {slot, missing_field} <- [
          {"local_mix_ci", "conclusion"},
          {"pr_ci", "run_id"},
          {"release", "merge_sha"},
          {"dependabot", "slots"},
          {"gallery", "run_id"},
          {"historical_gallery", "run_id"}
        ],
        mutation <- [
          %{"status" => "success"},
          Map.delete(green_evidence[slot], missing_field)
        ] do
      error =
        assert_raise ExUnit.AssertionError, fn ->
          assert_transition_allowed!(
            complete,
            Map.put(green_evidence, slot, mutation),
            green_commands
          )
        end

      assert error.message =~ slot or error.message =~ missing_field
    end
  end

  @tag :validation_signoff
  test "production transition rejects every unexpected seventh evidence slot" do
    complete = %{
      "status" => "complete",
      "nyquist_compliant" => "true",
      "wave_0_complete" => "true",
      "reviewed_commit_sha" => String.duplicate("b", 40),
      "reviewed_at" => "2026-08-02T04:00:00Z"
    }

    green_commands = green_command_receipts()
    green_evidence = evidence()

    assert :complete = assert_transition_allowed!(complete, green_evidence, green_commands)

    for {slot, receipt} <- [
          {"unexpected_failed", %{"status" => "failed"}},
          {"unexpected_malformed_success", %{"status" => "success"}}
        ] do
      error =
        assert_raise ExUnit.AssertionError, fn ->
          assert_transition_allowed!(
            complete,
            Map.put(green_evidence, slot, receipt),
            green_commands
          )
        end

      assert error.message =~ "exact required six-slot set" or error.message =~ slot
    end
  end

  @tag :validation_signoff
  test "validation contract rejects every invalid 234-21-01 row mutation" do
    validation = File.read!(@validation_path)

    row =
      "| 234-21-01 | 21 | 12 | DX-01/DX-02/DX-03/DX-04/DX-06 | T-234-21-01 | Production completion admits exactly the six named evidence keys and rejects every additional slot | evidence transition | mix test test/sigra/planning/phase_234_evidence_contract_test.exs --only validation_signoff && mix test test/sigra/planning/phase_234_evidence_contract_test.exs && mix test test/sigra/planning/phase_234_playwright_inventory_contract_test.exs | ✅ existing file revised | ✅ green |"

    for mutated <- [
          String.replace(validation, row <> "\n", "", global: false),
          String.replace(validation, row, row <> "\n" <> row, global: false),
          String.replace(
            validation,
            "mix test test/sigra/planning/phase_234_evidence_contract_test.exs --only validation_signoff && mix test test/sigra/planning/phase_234_evidence_contract_test.exs && mix test test/sigra/planning/phase_234_playwright_inventory_contract_test.exs",
            "mix test test/sigra/planning/phase_234_evidence_contract_test.exs",
            global: false
          ),
          String.replace(validation, row, String.replace(row, "✅ green", "⬜ pending"),
            global: false
          )
        ] do
      error = assert_raise ExUnit.AssertionError, fn -> parse_validation!(mutated) end

      assert error.message =~ "234-21-01"
    end
  end

  @tag :validation_signoff
  test "shared exact command receipt validator rejects every incomplete mutation and transition stays draft" do
    slots = ["local_mix_ci", "pr_ci", "release", "dependabot", "gallery", "historical_gallery"]
    green_evidence = evidence()
    green_commands = green_command_receipts()

    complete = %{
      "status" => "complete",
      "nyquist_compliant" => "true",
      "wave_0_complete" => "true",
      "reviewed_commit_sha" => String.duplicate("b", 40),
      "reviewed_at" => "2026-08-02T04:00:00Z"
    }

    draft = %{
      "status" => "draft",
      "nyquist_compliant" => "false",
      "wave_0_complete" => "false",
      "reviewed_commit_sha" => String.duplicate("b", 40),
      "reviewed_at" => "2026-08-02T04:00:00Z"
    }

    assert :complete = assert_transition_allowed!(complete, green_evidence, green_commands)

    mutations =
      [
        {"zero rows", [], "exactly five"}
        | Enum.map(0..4, fn index ->
            {"missing #{index}", List.delete_at(green_commands, index), "exactly five"}
          end)
      ] ++
        [
          {"extra row", green_commands ++ [List.last(green_commands)], "exactly five"},
          {"duplicate command", List.replace_at(green_commands, 1, List.first(green_commands)),
           "exact ordered command inventory"},
          {"reordered rows", Enum.reverse(green_commands), "exact ordered command inventory"},
          {"empty command",
           List.replace_at(green_commands, 0, %{List.first(green_commands) | command: ""}),
           "exact ordered command inventory"},
          {"malformed timestamp",
           List.replace_at(green_commands, 0, %{
             List.first(green_commands)
             | timestamp: "yesterday"
           }), "UTC ISO-8601"},
          {"malformed hash",
           List.replace_at(green_commands, 0, %{List.first(green_commands) | output_hash: "hash"}),
           "lowercase SHA-256"},
          {"nonzero exit",
           List.replace_at(green_commands, 0, %{List.first(green_commands) | exit_status: "1"}),
           "exit_status"},
          {"stale command",
           List.replace_at(green_commands, 0, %{
             List.first(green_commands)
             | command: "mix test stale"
           }), "exact ordered command inventory"},
          {"wrong commit SHA",
           List.replace_at(green_commands, 0, %{
             List.first(green_commands)
             | commit_sha: String.duplicate("c", 40)
           }), "commit_sha"},
          {"stale timestamp",
           List.replace_at(green_commands, 0, %{
             List.first(green_commands)
             | timestamp: "2026-08-02T03:29:59Z"
           }), "freshness"},
          {"future timestamp",
           List.replace_at(green_commands, 0, %{
             List.first(green_commands)
             | timestamp: "2026-08-02T04:00:01Z"
           }), "freshness"},
          {"non-monotonic timestamp",
           List.replace_at(green_commands, 1, %{
             Enum.at(green_commands, 1)
             | timestamp: "2026-08-02T03:59:59Z"
           }), "nondecreasing"}
        ]

    for {name, commands, error_message} <- mutations do
      error =
        assert_raise ExUnit.AssertionError, fn ->
          assert_transition_allowed!(draft, green_evidence, commands)
        end

      assert error.message =~ error_message, "#{name}: #{error.message}"
    end

    for slot <- slots do
      assert :blocked =
               assert_transition_allowed!(
                 draft,
                 Map.put(green_evidence, slot, %{"status" => "failed"}),
                 green_commands
               )

      assert :blocked =
               assert_transition_allowed!(draft, Map.delete(green_evidence, slot), green_commands)
    end
  end

  defp green_command_receipts do
    Enum.map(@command_receipt_commands, fn command ->
      %{
        command: command,
        timestamp: "2026-08-02T04:00:00Z",
        exit_status: "0",
        output_hash: String.duplicate("a", 64),
        commit_sha: String.duplicate("b", 40)
      }
    end)
  end

  defp parse_validation!(validation) do
    [frontmatter, body] = String.split(validation, "---\n", parts: 3) |> Enum.drop(1)
    frontmatter = parse_frontmatter!(frontmatter)
    quick_run_paths = parse_quick_run_paths!(body)
    wave_0_items = parse_wave_0_items!(body)
    task_statuses = parse_task_statuses!(body)
    gap_task_receipts = parse_gap_task_receipts!(body)
    command_receipts = parse_command_receipts!(body)
    approval = parse_approval!(body)

    assert :ok = validate_review_fields!(frontmatter)

    assert :ok =
             validate_command_receipts!(
               command_receipts,
               frontmatter["reviewed_commit_sha"],
               frontmatter["reviewed_at"]
             )

    assert :ok = validate_gap_task_receipts!(gap_task_receipts)

    assert quick_run_paths == @quick_run_paths,
           "quick-run contract inventory must equal the exact six focused contract paths; got: #{inspect(quick_run_paths)}"

    assert Enum.uniq(quick_run_paths) == quick_run_paths,
           "quick-run contract inventory contains duplicates"

    Enum.each(quick_run_paths, fn path ->
      assert File.exists?(path), "quick-run contract path does not exist: #{path}"
    end)

    %{
      frontmatter: frontmatter,
      quick_run_paths: quick_run_paths,
      wave_0_items: wave_0_items,
      task_statuses: task_statuses,
      gap_task_receipts: gap_task_receipts,
      command_receipts: command_receipts,
      approval: approval
    }
  end

  defp parse_frontmatter!(frontmatter) do
    frontmatter
    |> String.split("\n", trim: true)
    |> Enum.reduce(%{}, fn line, fields ->
      case String.split(line, ":", parts: 2) do
        [key, value] -> Map.put(fields, key, String.trim(value))
        _ -> flunk("malformed validation frontmatter: #{inspect(line)}")
      end
    end)
  end

  defp parse_quick_run_paths!(body) do
    [command] =
      Regex.run(~r/\| \*\*Quick run command\*\* \| `([^`]+)` \|/, body, capture: :all_but_first)

    case String.split(command, " ") do
      ["mix", "test" | paths] when paths != [] -> paths
      _ -> flunk("Quick run command must be a mix test command with paths")
    end
  end

  defp parse_wave_0_items!(body) do
    Regex.scan(~r/^- \[([ x])\] (.+)$/m, body, capture: :all_but_first)
    |> Enum.map(fn [mark, item] -> %{complete: mark == "x", item: item} end)
    |> case do
      [] -> flunk("validation must contain a Wave 0 checklist")
      items -> items
    end
  end

  defp parse_task_statuses!(body) do
    Regex.scan(~r/^\| 234-[^|]+\|.*?\| (✅ green|⬜ pending|❌ red|⚠️ flaky) \|$/m, body,
      capture: :all_but_first
    )
    |> List.flatten()
    |> case do
      [] -> flunk("validation must contain task-map status rows")
      statuses -> statuses
    end
  end

  defp parse_command_receipts!(body) do
    Regex.scan(
      ~r/^\| `(.+?)` \| (\d{4}-\d\d-\d\dT\d\d:\d\d:\d\dZ) \| (\d+) \| `([0-9a-f]{64})` \| `([0-9a-f]{40})` \|$/m,
      body,
      capture: :all_but_first
    )
    |> Enum.map(fn [command, timestamp, exit_status, output_hash, commit_sha] ->
      %{
        command: command,
        timestamp: timestamp,
        exit_status: exit_status,
        output_hash: output_hash,
        commit_sha: commit_sha
      }
    end)
  end

  defp parse_gap_task_receipts!(body) do
    Regex.scan(
      ~r/^\| (234-(?:19|20|21)-\d\d) \| [^|]* \| [^|]* \| [^|]* \| [^|]* \| [^|]* \| [^|]* \| (.+?) \| [^|]* \| (✅ green|⬜ pending|❌ red|⚠️ flaky) \|$/m,
      body,
      capture: :all_but_first
    )
    |> Enum.map(fn [task_id, command, status] -> {task_id, command, status} end)
  end

  defp parse_approval!(body) do
    case Regex.run(~r/^\*\*Approval:\*\* (.+)$/m, body, capture: :all_but_first) do
      [approval] -> approval
      _ -> flunk("validation must name an approval state")
    end
  end

  defp validate_review_fields!(frontmatter) do
    assert frontmatter["reviewed_commit_sha"] =~ ~r/\A[0-9a-f]{40}\z/,
           "reviewed_commit_sha must be a lowercase 40-character SHA"

    assert is_binary(frontmatter["reviewed_at"]) and
             match?({:ok, _, 0}, DateTime.from_iso8601(frontmatter["reviewed_at"])),
           "reviewed_at must be a UTC ISO-8601 timestamp"

    :ok
  end

  defp validate_gap_task_receipts!(gap_task_receipts) do
    assert gap_task_receipts == @required_gap_task_receipts,
           "gap task verification rows must equal #{inspect(@required_gap_task_receipts)}; got: #{inspect(gap_task_receipts)}"

    :ok
  end

  defp validate_command_receipts!(command_receipts, reviewed_commit_sha, reviewed_at)
       when is_list(command_receipts) do
    assert length(command_receipts) == length(@command_receipt_commands),
           "command receipt inventory must contain exactly five rows"

    assert Enum.map(command_receipts, & &1.command) == @command_receipt_commands,
           "command receipt inventory must equal the exact ordered command inventory"

    assert Enum.uniq_by(command_receipts, & &1.command) == command_receipts,
           "command receipt inventory must not contain duplicate commands"

    {:ok, reviewed_at, 0} = DateTime.from_iso8601(reviewed_at)
    earliest = DateTime.add(reviewed_at, -1_800, :second)

    Enum.each(command_receipts, fn receipt ->
      assert is_binary(receipt.command) and String.trim(receipt.command) != "",
             "command receipt command must be non-empty"

      assert is_binary(receipt.timestamp) and
               match?({:ok, _datetime, 0}, DateTime.from_iso8601(receipt.timestamp)),
             "command receipt timestamp must be a UTC ISO-8601 timestamp"

      assert receipt.exit_status == "0", "command receipt exit_status must be 0"

      assert is_binary(receipt.output_hash) and receipt.output_hash =~ ~r/\A[0-9a-f]{64}\z/,
             "command receipt output_hash must be a lowercase SHA-256"

      assert receipt.commit_sha == reviewed_commit_sha,
             "command receipt commit_sha must equal reviewed_commit_sha"

      {:ok, timestamp, 0} = DateTime.from_iso8601(receipt.timestamp)

      assert DateTime.compare(timestamp, earliest) != :lt and
               DateTime.compare(timestamp, reviewed_at) != :gt,
             "command receipt freshness must be within the reviewed 1,800-second interval"
    end)

    timestamps =
      Enum.map(command_receipts, fn receipt ->
        {:ok, timestamp, 0} = DateTime.from_iso8601(receipt.timestamp)
        timestamp
      end)

    assert timestamps == Enum.sort(timestamps, {:asc, DateTime}),
           "command receipt timestamps must be nondecreasing"

    :ok
  end

  defp validate_command_receipts!(_command_receipts, _reviewed_commit_sha, _reviewed_at),
    do: flunk("command receipt inventory must be a list")

  defp assert_transition_allowed!(frontmatter, receipts, command_receipts) do
    transition_fields = Map.take(frontmatter, ["status", "nyquist_compliant", "wave_0_complete"])

    assert :ok = validate_review_fields!(frontmatter)

    assert :ok =
             validate_command_receipts!(
               command_receipts,
               frontmatter["reviewed_commit_sha"],
               frontmatter["reviewed_at"]
             )

    evidence_statuses_green? =
      Enum.all?(
        ["local_mix_ci", "pr_ci", "release", "dependabot", "gallery", "historical_gallery"],
        fn slot -> is_map(receipts[slot]) and receipts[slot]["status"] == "success" end
      )

    commands_green? = Enum.all?(command_receipts, &(&1.exit_status == "0"))

    if evidence_statuses_green? and commands_green? do
      assert :ok = validate_required_evidence!(receipts)

      assert transition_fields == %{
               "status" => "complete",
               "nyquist_compliant" => "true",
               "wave_0_complete" => "true"
             }

      :complete
    else
      assert transition_fields == %{
               "status" => "draft",
               "nyquist_compliant" => "false",
               "wave_0_complete" => "false"
             }

      :blocked
    end
  end
end
