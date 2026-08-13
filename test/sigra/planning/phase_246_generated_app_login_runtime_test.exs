defmodule Sigra.Planning.Phase246GeneratedAppLoginRuntimeTest do
  use ExUnit.Case, async: true

  @harness "scripts/ci/generated-app-login-runtime-proof.sh"
  @workflow ".github/workflows/generated-app-login-runtime-proof.yml"

  defp read!(path), do: File.cwd!() |> Path.join(path) |> File.read!()

  test "fresh-host proof is bounded, route-based, and receipt-last" do
    harness = read!(@harness)

    for marker <- [
          "mix phx.new",
          "sigra.install",
          "--app-sessions",
          "--app-password-login",
          "ecto.migrate",
          "FetchAppSession",
          "app_login_public",
          "code_challenge_method=S256",
          "app_login/concurrency_test.exs",
          "app_login_direct_fault_test.exs",
          "receipt-last",
          "sha256sum",
          "curl --fail --silent --show-error",
          "app-login/approve",
          "api/app-login/exchange",
          "prove_direct_mfa_ceremony",
          "api/app-login/direct/mfa",
          "backup_code",
          "direct-mfa challenge was not consumed",
          "backup code was not consumed",
          "cookie-jar",
          "hosted_code",
          "pg_isready"
        ] do
      assert harness =~ marker, "fresh-host harness missing #{inspect(marker)}"
    end

    refute Regex.match?(~r/\bsleep\b/, harness),
           "proof must use bounded readiness rather than sleeps"
  end

  test "fresh-host proof authenticates generated credentials and rejects replays over HTTP" do
    harness = read!(@harness)

    for marker <- [
          "install_proof_route",
          "Sigra.Plug.FetchAppSession",
          "/api/app-login-proof",
          "prove_fetch_app_session",
          "prove_hosted_replay",
          "prove_direct_replay",
          "hosted credential did not remain valid after replay",
          "direct credential did not remain valid after replay",
          "assert_one_family hosted hosted_code",
          "assert_one_family direct direct_mfa"
        ] do
      assert harness =~ marker, "fresh-host harness missing #{inspect(marker)}"
    end

    refute harness =~ "FetchAppSession' \"$router\" || true",
           "the protected generated route must be installed, not merely mentioned"
  end

  test "generated-host proof refreshes dependencies after installer mutations" do
    harness = read!(@harness)

    first_install =
      :binary.match(harness, ~s(run "$APP_DIR" mix sigra.install Accounts User users))

    assert first_install != :nomatch, "fresh host must run the installer"

    {install_offset, _} = first_install
    after_install = binary_part(harness, install_offset, byte_size(harness) - install_offset)

    assert String.contains?(after_install, "run \"$APP_DIR\" mix deps.get"),
           "installer-added dependencies must be fetched before later Mix invocations"
  end

  test "workflow is a credential-free PostgreSQL evidence lane" do
    workflow = read!(@workflow)

    for marker <- [
          "name: Generated app-login runtime proof",
          "workflow_dispatch:",
          "image: postgres:15",
          "mix archive.install --force hex phx_new 1.8.8",
          "scripts/ci/generated-app-login-runtime-proof.sh",
          "generated-app-login-runtime-proof",
          "if: always()",
          "retention-days: 7"
        ] do
      assert workflow =~ marker, "app-login workflow missing #{inspect(marker)}"
    end

    refute workflow =~ "GOOGLE_CLIENT_SECRET"
    refute workflow =~ "GOOGLE_CLIENT_ID"
  end

  test "runtime receipt is versioned, causal, source-bound, and parsed before upload" do
    harness = read!(@harness)
    workflow = read!(@workflow)

    for marker <- [
          "sigra.generated-app-login-runtime-proof/v3",
          "sigra.generated-app-login-runtime-proof/v3",
          "CONTROLLER_MFA_SESSION_UPGRADED",
          "LIVEVIEW_MFA_SESSION_UPGRADED",
          "APPROVAL_REPLAY_REJECTED",
          "DIRECT_BACKUP_CODE_SUCCEEDED",
          "HOSTED_REPLAY_REJECTED",
          "DIRECT_REPLAY_REJECTED",
          "FETCH_APP_SESSION_EQUIVALENT",
          "BROWSER_REQUIRED_BEFORE_AUTHENTICATION",
          "CONTROLLER_MFA_SESSION_UPGRADED",
          "LIVEVIEW_MFA_SESSION_UPGRADED",
          "APPROVAL_REPLAY_REJECTED",
          "DIRECT_BACKUP_CODE_SUCCEEDED",
          "BROWSER_REQUIRED_BEFORE_AUTHENTICATION",
          "FETCH_APP_SESSION_EQUIVALENT",
          "phase_246_runtime_evidence_contract_test.exs",
          "lib/sigra/app_login.ex",
          "priv/templates/sigra.install/app_sessions/router_injection.ex",
          "priv/templates/sigra.install/core/mfa_challenge_live.ex",
          "phase_246_runtime_evidence_contract_test.exs",
          "runtime-proof.json.tmp",
          "mv \"$receipt_tmp\" \"$receipt\"",
          "write_receipt_last"
        ] do
      assert harness =~ marker, "runtime receipt harness missing #{inspect(marker)}"
    end

    assert workflow =~ "Validate generated app-login runtime receipt"
    assert workflow =~ "sigra.generated-app-login-runtime-proof/v3"
    assert workflow =~ "runtime-proof.json"
  end
end
