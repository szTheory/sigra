defmodule Sigra.Planning.Phase246RuntimeEvidenceContractTest do
  use ExUnit.Case, async: true

  @phase_dir ".planning/phases/246-hosted-and-direct-login-ceremonies"
  @receipt_path Path.join(@phase_dir, "246-RUNTIME-PROOF.json")
  @provenance_path Path.join(@phase_dir, "246-RUNTIME-PROOF-RUN.json")

  @required_behaviors ~w(
    controller_mfa_session_upgraded
    liveview_mfa_session_upgraded
    approval_replay_rejected
    direct_backup_code_succeeded
    hosted_replay_rejected
    direct_replay_rejected
    fetch_app_session_equivalent
    browser_required_before_authentication
  )

  @sources %{
    "app_login" => "lib/sigra/app_login.ex",
    "fetch_app_session" => "lib/sigra/plug/fetch_app_session.ex",
    "app_login_controller" => "priv/templates/sigra.install/app_sessions/app_login_controller.ex",
    "app_login_continuation" => "priv/templates/sigra.install/app_sessions/app_login_continuation.ex",
    "app_login_attempt_schema" =>
      "priv/templates/sigra.install/app_sessions/user_app_login_attempt.ex",
    "app_sessions_migration" =>
      "priv/templates/sigra.install/app_sessions/app_sessions_migration.exs",
    "auth_app_sessions" => "priv/templates/sigra.install/app_sessions/auth_app_sessions.ex",
    "router_injection" => "priv/templates/sigra.install/app_sessions/router_injection.ex",
    "mfa_challenge_controller" => "priv/templates/sigra.install/core/mfa_challenge_controller.ex",
    "mfa_challenge_live" => "priv/templates/sigra.install/core/mfa_challenge_live.ex",
    "runtime_script" => "scripts/ci/generated-app-login-runtime-proof.sh",
    "workflow" => ".github/workflows/generated-app-login-runtime-proof.yml",
    "runtime_source_contract_test" =>
      "test/sigra/planning/phase_246_generated_app_login_runtime_test.exs",
    "runtime_evidence_contract_test" =>
      "test/sigra/planning/phase_246_runtime_evidence_contract_test.exs",
    "mfa_session_upgrade_test" => "test/sigra/install/app_sessions_mfa_session_upgrade_test.exs",
    "approval_concurrency_test" => "test/sigra/app_login/concurrency_test.exs"
  }

  test "v3 fixture validates exact source bindings and immutable prior-run provenance" do
    receipt = valid_receipt()
    provenance = valid_provenance(receipt)

    assert :ok = validate(receipt, provenance)
  end

  test "v3 receipt and provenance fail closed for every evidence mutation" do
    receipt = valid_receipt()
    provenance = valid_provenance(receipt)

    assert {:error, _} = validate(Map.put(receipt, "schema", "stale"), provenance)
    assert {:error, _} = validate(Map.put(receipt, "hosted_replay_rejected", false), provenance)
    assert {:error, _} = validate(Map.put(receipt, "access_token", "secret"), provenance)

    assert {:error, _} =
             validate(
               put_in(receipt, ["sources", "app_login"], String.duplicate("0", 64)),
               provenance
             )

    assert {:error, _} = validate(receipt, Map.put(provenance, "event", "push"))

    assert {:error, _} =
             validate(receipt, Map.put(provenance, "head_sha", String.duplicate("0", 40)))

    assert {:error, _} =
             validate(receipt, Map.put(provenance, "receipt_sha256", String.duplicate("0", 64)))

    assert {:error, _} = validate(receipt, Map.put(provenance, "conclusion", "failure"))
  end

  test "canonical retained evidence uses the same fail-closed parser when present" do
    if File.exists?(@receipt_path) do
      assert File.exists?(@provenance_path), "provenance must not exist without receipt"
      assert :ok = validate(decode!(@receipt_path), decode!(@provenance_path))
    else
      if File.exists?(@provenance_path) do
        provenance = decode!(@provenance_path)
        refute provenance["conclusion"] == "success", "successful provenance requires a receipt"
      end
    end
  end

  defp valid_receipt do
    %{
      "schema" => "sigra.generated-app-login-runtime-proof/v3",
      "status" => "passed",
      "controller_mfa_session_upgraded" => true,
      "liveview_mfa_session_upgraded" => true,
      "approval_replay_rejected" => true,
      "direct_backup_code_succeeded" => true,
      "hosted_replay_rejected" => true,
      "direct_replay_rejected" => true,
      "fetch_app_session_equivalent" => true,
      "browser_required_before_authentication" => true,
      "sources" => Map.new(@sources, fn {key, path} -> {key, sha256_at!(git_head!(), path)} end)
    }
  end

  defp valid_provenance(receipt) do
    %{
      "repository" => "szTheory/sigra",
      "workflow_path" => ".github/workflows/generated-app-login-runtime-proof.yml",
      "event" => "workflow_dispatch",
      "dispatch_attempts" => 1,
      "watch_interval_seconds" => 60,
      "run_id" => 24617,
      "run_url" => "https://github.com/szTheory/sigra/actions/runs/24617",
      "conclusion" => "success",
      "head_sha" => git_head!(),
      "implementation_ref" => "gsd/238-generated-auth-runtime-proof-evidence",
      "artifact_name" => "generated-app-login-runtime-proof",
      "receipt_sha256" => sha256_json!(receipt),
      "coverage_statement" =>
        "This artifact proves the prior immutable implementation head, not the subsequent evidence-only commit."
    }
  end

  defp validate(receipt, provenance) do
    with :ok <-
           exact_keys(receipt, MapSet.new(["schema", "status", "sources" | @required_behaviors])),
         "sigra.generated-app-login-runtime-proof/v3" <- receipt["schema"],
         "passed" <- receipt["status"],
         true <- Enum.all?(@required_behaviors, &(receipt[&1] == true)),
         :ok <- exact_keys(receipt["sources"], MapSet.new(Map.keys(@sources))),
         :ok <- valid_provenance?(receipt, provenance),
         true <-
           Enum.all?(@sources, fn {key, path} ->
             receipt["sources"][key] == sha256_at!(provenance["head_sha"], path)
           end) do
      :ok
    else
      _ -> {:error, :invalid_runtime_evidence}
    end
  end

  defp valid_provenance?(receipt, provenance) when is_map(provenance) do
    required =
      ~w(repository workflow_path event dispatch_attempts watch_interval_seconds run_id run_url conclusion head_sha implementation_ref artifact_name receipt_sha256 coverage_statement)

    with :ok <- exact_keys(provenance, MapSet.new(required)),
         "szTheory/sigra" <- provenance["repository"],
         ".github/workflows/generated-app-login-runtime-proof.yml" <- provenance["workflow_path"],
         "workflow_dispatch" <- provenance["event"],
         1 <- provenance["dispatch_attempts"],
         60 <- provenance["watch_interval_seconds"],
         run_id when is_integer(run_id) and run_id > 0 <- provenance["run_id"],
         "success" <- provenance["conclusion"],
         true <- Regex.match?(~r/\A[0-9a-f]{40}\z/, provenance["head_sha"]),
         true <- provenance["receipt_sha256"] == sha256_json!(receipt),
         true <-
           String.contains?(
             provenance["coverage_statement"],
             "prior immutable implementation head"
           ) do
      :ok
    else
      _ -> {:error, :invalid_runtime_provenance}
    end
  end

  defp valid_provenance?(_, _), do: {:error, :invalid_runtime_provenance}

  defp exact_keys(map, expected) when is_map(map),
    do: if(MapSet.new(Map.keys(map)) == expected, do: :ok, else: {:error, :unexpected_fields})

  defp exact_keys(_, _), do: {:error, :invalid_fields}
  defp decode!(path), do: path |> File.read!() |> Jason.decode!()

  defp sha256_at!(sha, path),
    do:
      "git show #{sha}:#{path}"
      |> String.to_charlist()
      |> :os.cmd()
      |> to_string()
      |> then(&:crypto.hash(:sha256, &1))
      |> Base.encode16(case: :lower)

  defp sha256_json!(value),
    do:
      value |> Jason.encode!() |> then(&:crypto.hash(:sha256, &1)) |> Base.encode16(case: :lower)

  defp git_head!,
    do: "git rev-parse HEAD" |> String.to_charlist() |> :os.cmd() |> to_string() |> String.trim()
end
