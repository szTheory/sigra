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

  test "proof router defers app-session config until the endpoint is running" do
    harness = read!(@harness)

    assert harness =~
             "config: \\&SigraAppLoginProof.Accounts.Auth.AppSessions.sigra_config\\/0",
           "router compilation must retain a config function instead of reading Endpoint ETS"

    refute harness =~
             "config: SigraAppLoginProof.Accounts.Auth.AppSessions.sigra_config(),",
           "router compilation must not call sigra_config before Endpoint startup"
  end

  test "generated-host proof refreshes dependencies after installer mutations" do
    harness = read!(@harness)

    install = ~s(run "$APP_DIR" mix sigra.install Accounts User users "${flags[@]}")
    refresh = ~s(run "$APP_DIR" mix deps.get)
    installs = :binary.matches(harness, install)
    refreshes = :binary.matches(harness, refresh)

    assert length(installs) == 2, "fresh host must verify an idempotent second installation"

    [{first_install, _}, {second_install, _}] = installs

    assert Enum.any?(refreshes, fn {refresh_offset, _} ->
             first_install < refresh_offset and refresh_offset < second_install
           end),
           "installer-added dependencies must be fetched before the idempotent installer reruns Mix"
  end

  test "generated-host server launch captures its PID inside the application cwd" do
    harness = read!(@harness)

    assert harness =~ "pushd \"$APP_DIR\" >/dev/null\n  CLOAK_KEY=",
           "the server process must start from the generated host cwd"

    assert harness =~ "SERVER_PID=$!\n  popd >/dev/null",
           "the server process and PID capture must share the generated host cwd"

    refute harness =~
             "(cd \"$APP_DIR\" && PORT=\"$PORT\" PHX_SERVER=true mix phx.server > server.log 2>&1 & echo $! > server.pid)",
           "backgrounding the cd-and-server list writes server.pid outside APP_DIR"

    refute harness =~ "cat \"${APP_DIR}/server.pid\"",
           "read the PID from the launch shell instead of relying on a misplaced pid file"
  end

  test "generated-host readiness supplies an ephemeral Vault key and fails fast on server exit" do
    harness = read!(@harness)

    assert harness =~ "CLOAK_KEY=\"$(openssl rand -base64 32)\"",
           "the disposable generated host must receive an ephemeral Vault key"

    assert harness =~
             "CLOAK_KEY=\"$CLOAK_KEY\" PORT=\"$PORT\" PHX_SERVER=true mix phx.server > server.log 2>&1 &",
           "the generated Phoenix process must inherit the ephemeral Vault key"

    assert harness =~ "kill -0 \"$SERVER_PID\"",
           "readiness must immediately detect a server process that already exited"

    assert harness =~ "generated host process exited before readiness; see ${APP_DIR}/server.log",
           "readiness failures must point to the retained, credential-free server diagnostic"
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
