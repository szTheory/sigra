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
      "default_branch_sha" => "fe33154088053ce9ccc0e9301348a2841c87745c",
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

    assert receipt["default_branch_sha"] == "fe33154088053ce9ccc0e9301348a2841c87745c",
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
  test "final evidence names every GitHub-owned slot without treating a failed residual as success" do
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
    assert receipts["dependabot"]["status"] == "failed"
    assert_non_empty_string!(receipts["dependabot"], "diagnostics")
  end

  @tag :validation_signoff
  test "validation sign-off parses its exact contract inventory before allowing a status transition" do
    validation = File.read!(@validation_path)

    assert %{
             frontmatter: %{
               "status" => "draft",
               "nyquist_compliant" => "false",
               "wave_0_complete" => "false"
             },
             quick_run_paths: @quick_run_paths,
             wave_0_items: wave_0_items,
             task_statuses: task_statuses,
             command_receipts: command_receipts,
             approval: approval
           } = parsed = parse_validation!(validation)

    assert Enum.all?(wave_0_items, & &1.complete),
           "every Wave 0 artifact must be checked before sign-off"

    assert Enum.all?(task_statuses, &(&1 == "✅ green")),
           "every task-map row must be green before sign-off"

    assert length(command_receipts) == 5
    assert Enum.count(command_receipts, &(&1.exit_status == "0")) == 4
    assert Enum.count(command_receipts, &(&1.exit_status == "1")) == 1
    assert Enum.all?(command_receipts, &valid_command_receipt?/1)
    assert approval =~ "Dependabot residual"
    assert approval =~ "golden fixture residual"

    assert {:residual, "dependabot"} = signoff_state(evidence())
    assert :blocked = assert_transition_allowed!(parsed.frontmatter, evidence(), command_receipts)
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

    error =
      assert_raise ExUnit.AssertionError, fn ->
        parse_validation!(stale_validation)
      end

    assert error.message =~ stale_path
  end

  @tag :validation_signoff
  test "missing or red evidence and command receipts force every completion field to remain false" do
    slots = ["local_mix_ci", "pr_ci", "release", "dependabot", "gallery", "historical_gallery"]
    green_evidence = Map.new(slots, &{&1, %{"status" => "success"}})
    green_commands = List.duplicate(%{exit_status: "0"}, 5)

    complete = %{
      "status" => "complete",
      "nyquist_compliant" => "true",
      "wave_0_complete" => "true"
    }

    draft = %{"status" => "draft", "nyquist_compliant" => "false", "wave_0_complete" => "false"}

    assert :complete = assert_transition_allowed!(complete, green_evidence, green_commands)

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

    assert :blocked =
             assert_transition_allowed!(draft, green_evidence, [
               %{exit_status: "1"} | tl(green_commands)
             ])
  end

  defp parse_validation!(validation) do
    [frontmatter, body] = String.split(validation, "---\n", parts: 3) |> Enum.drop(1)
    frontmatter = parse_frontmatter!(frontmatter)
    quick_run_paths = parse_quick_run_paths!(body)
    wave_0_items = parse_wave_0_items!(body)
    task_statuses = parse_task_statuses!(body)
    command_receipts = parse_command_receipts!(body)
    approval = parse_approval!(body)

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
      ~r/^\| `(.+?)` \| (\d{4}-\d\d-\d\dT\d\d:\d\d:\d\dZ) \| (\d+) \| `([0-9a-f]{64})` \|$/m,
      body,
      capture: :all_but_first
    )
    |> Enum.map(fn [command, timestamp, exit_status, output_hash] ->
      %{
        command: command,
        timestamp: timestamp,
        exit_status: exit_status,
        output_hash: output_hash
      }
    end)
  end

  defp parse_approval!(body) do
    case Regex.run(~r/^\*\*Approval:\*\* (.+)$/m, body, capture: :all_but_first) do
      [approval] -> approval
      _ -> flunk("validation must name an approval state")
    end
  end

  defp valid_command_receipt?(%{exit_status: exit_status, output_hash: hash})
       when exit_status in ["0", "1"] do
    hash =~ ~r/\A[0-9a-f]{64}\z/
  end

  defp valid_command_receipt?(_receipt), do: false

  defp signoff_state(receipts) do
    required_slots = [
      "local_mix_ci",
      "pr_ci",
      "release",
      "dependabot",
      "gallery",
      "historical_gallery"
    ]

    case Enum.find(required_slots, &(receipts[&1]["status"] != "success")) do
      nil -> :complete
      slot -> {:residual, slot}
    end
  end

  defp assert_transition_allowed!(frontmatter, receipts, command_receipts) do
    transition_fields = Map.take(frontmatter, ["status", "nyquist_compliant", "wave_0_complete"])

    evidence_green? =
      Enum.all?(
        ["local_mix_ci", "pr_ci", "release", "dependabot", "gallery", "historical_gallery"],
        fn slot -> is_map(receipts[slot]) and receipts[slot]["status"] == "success" end
      )

    commands_green? = Enum.all?(command_receipts, &(&1.exit_status == "0"))

    if evidence_green? and commands_green? do
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
