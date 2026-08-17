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

  test "generated-host proof targets sigra_test unless its caller supplies a database" do
    harness = read!(@harness)

    assert harness =~ "export PGDATABASE=\"${PGDATABASE:-sigra_test}\""
  end

  test "generated-host proof assigns each disposable mode database in both dev and test configs" do
    harness = read!(@harness)

    [patch_host] =
      Regex.run(~r/(patch_host\(\) \{.*?\n\})/s, harness, capture: :all_but_first)

    assert patch_host =~ "config/dev.exs"
    assert patch_host =~ "config/test.exs"
    assert patch_host =~ "database: \"'\"${database}\"'\""

    patch_offset = :binary.match(harness, "patch_host \"$database\"") |> elem(0)
    create_offset = :binary.match(harness, "run \"$APP_DIR\" mix ecto.create") |> elem(0)
    assert patch_offset < create_offset
  end

  test "generated-host proof disables only disposable development asset watchers" do
    harness = read!(@harness)

    assert harness =~ "config/dev.exs"
    assert harness =~ "watchers: [],"
    refute harness =~ "chmod"
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

  test "fresh-host proof rotates through the emitted public refresh route without retaining credentials" do
    harness = read!(@harness)

    for marker <- [
          "prove_refresh_rotation",
          "/api/app-login/refresh",
          "replacement access token did not authenticate",
          "refresh credential authenticated as an access credential",
          "refresh response was not the exact credential shape"
        ] do
      assert harness =~ marker, "fresh-host refresh proof missing #{inspect(marker)}"
    end

    refute harness =~ "sleep", "refresh proof must use the existing bounded readiness flow"
  end

  test "refresh reuse proof follows routed replay with typed state and next-auth denial" do
    harness = read!(@harness)

    for marker <- [
          "assert_access_denied()",
          "prove_refresh_reuse_revocation()",
          "refresh-reuse.json",
          "refresh_replay=unauthenticated",
          "family=revoked",
          "control_family=active",
          "next_access=denied",
          "UserAppSessionFamily",
          "UserAppSessionToken",
          "assert_access_denied refresh",
          "prove_fetch_app_session refresh-control"
        ] do
      assert harness =~ marker, "refresh reuse proof missing #{inspect(marker)}"
    end

    refresh_offset = :binary.match(harness, "prove_refresh_rotation") |> elem(0)
    reuse_offset = :binary.match(harness, "prove_refresh_reuse_revocation") |> elem(0)
    deny_offset = :binary.match(harness, "assert_access_denied refresh") |> elem(0)

    assert refresh_offset < reuse_offset and reuse_offset < deny_offset,
           "refresh proof must rotate, replay, inspect typed state, then deny the next access"

    refute harness =~ "reuse_detected"
  end

  test "browser-required proof checks persisted state without comparing command output" do
    harness = read!(@harness)

    assert harness =~ "grep -Fxq '{\"error\":\"browser_required\"}'"
    assert harness =~ "assert_one_family direct direct_mfa"
    refute harness =~ "families_before_browser_required"
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

    assert harness =~ "pushd \"$APP_DIR\" >/dev/null\n  PORT=",
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
             "export CLOAK_KEY\n  set_stage \"${mode}_server_start\"\n  pushd \"$APP_DIR\" >/dev/null",
           "the generated Phoenix process must inherit the exported ephemeral Vault key"

    assert harness =~ "kill -0 \"$SERVER_PID\"",
           "readiness must immediately detect a server process that already exited"

    assert harness =~ "generated host process exited before readiness; see ${APP_DIR}/server.log",
           "readiness failures must point to the retained, credential-free server diagnostic"
  end

  test "generated-host launch explicitly exports and clears its ephemeral Vault key" do
    harness = read!(@harness)

    assert harness =~ "export CLOAK_KEY",
           "the generated server must inherit the ephemeral key across launcher boundaries"

    assert harness =~ "unset CLOAK_KEY",
           "the ephemeral key must be cleared after the generated server stops"

    {_, 0} =
      System.cmd("bash", [
        "-c",
        "set -euo pipefail; CLOAK_KEY=$(openssl rand -base64 32); export CLOAK_KEY; bash -c 'test -n \"$CLOAK_KEY\"'; unset CLOAK_KEY"
      ])
  end

  test "generated-host fixtures persist confirmation timestamps with second precision" do
    harness = read!(@harness)

    confirmation = "confirmed_at: DateTime.utc_now() |> DateTime.truncate(:second)"

    assert :binary.matches(harness, confirmation) |> length() == 2,
           "both hosted and direct fixtures must satisfy generated :utc_datetime precision"

    refute harness =~ "confirmed_at: DateTime.utc_now())",
           "fixture confirmation timestamps must not retain microseconds"
  end

  test "generated-host proof extracts CSRF tokens from Phoenix hidden inputs regardless of attribute order" do
    harness = read!(@harness)
    phoenix_hidden_input = ~s(<input name="_csrf_token" type="hidden" hidden value="csrf-probe">)

    refute harness =~ ~s(name="_csrf_token" value="),
           "the positional parser that failed in hosted proof must not remain in the harness"

    parser =
      """
      while (/<input\\b(?=[^>]*\\bname="_csrf_token")(?=[^>]*\\bvalue="([^"]+)")[^>]*>/g) { print "$1\\n"; last }
      """
      |> String.trim()

    {token, 0} =
      System.cmd("bash", [
        "-c",
        ~s(printf %s "$1" | perl -0ne "$2"),
        "--",
        phoenix_hidden_input,
        parser
      ])

    assert token == "csrf-probe\n"

    assert harness =~ "perl -0ne",
           "the harness must use an order-independent parser for Phoenix CSRF inputs"
  end

  test "generated-host MFA transition retains the pending-session form contract" do
    harness = read!(@harness)
    user_auth = read!("priv/templates/sigra.install/core/user_auth.ex")
    mfa_live = read!("priv/templates/sigra.install/core/mfa_challenge_live.ex")

    assert mfa_live =~ ~s(mfa_pending = session["mfa_pending"]),
           "the generated LiveView must only render its MFA form for a pending session"

    assert mfa_live =~ "name=\"_csrf_token\" value={Plug.CSRFProtection.get_csrf_token()}",
           "the generated MFA form must expose its CSRF token in the initial HTML response"

    assert user_auth =~ "maybe_put_mfa_pending(user)",
           "password login must persist the pending-MFA flag required by the generated LiveView"

    assert harness =~ ~s(set_stage "hosted_mfa_form"),
           "the proof must distinguish MFA form parsing from the completed login form"
  end

  test "generated password login creates the persisted MFA-pending session that survives the next request" do
    user_auth = read!("priv/templates/sigra.install/core/user_auth.ex")
    fetch_session = read!("lib/sigra/plug/fetch_session.ex")
    mfa_live = read!("priv/templates/sigra.install/core/mfa_challenge_live.ex")

    assert user_auth =~ "type: mfa_session_type(user)",
           "password login must mint an MFA-pending persisted session, not only a transient Plug flag"

    assert user_auth =~ "defp mfa_session_type(user)" and
             user_auth =~ "%{enabled: true} -> :mfa_pending",
           "the generated helper must select the persisted pending type from MFA enrollment"

    assert fetch_session =~ "if session.type == :mfa_pending do" and
             fetch_session =~ "Plug.Conn.put_session(conn, :mfa_pending, true)",
           "the next request must serialize the persisted pending type for the LiveView"

    assert mfa_live =~ ~s(mfa_pending = session["mfa_pending"]) and
             mfa_live =~ "if mfa_pending != true do",
           "the generated MFA LiveView must continue to reject every non-pending session"
  end

  test "generated MFA completion accepts the backup verifier success tuple" do
    controller = read!("priv/templates/sigra.install/core/mfa_challenge_controller.ex")

    assert controller =~ "{:ok, _} ->" and controller =~ "{:ok, _, _} ->",
           "the generated MFA controller must continue both TOTP and backup-code successes"
  end

  test "generated-host proof classifies the hosted app-login start response" do
    harness = read!(@harness)
    app_login_classifier = harness |> String.split("hosted_app_login_response_diagnostic()", parts: 2) |> List.last()

    for marker <- [
          "hosted-app-login.headers",
          "hosted app-login response status=",
          "app_login_approval",
          "hosted_app_login_response_diagnostic",
          "undefined_function_signature"
        ] do
      assert harness =~ marker,
             "hosted app-login diagnostics missing #{inspect(marker)}"
    end

    for marker <- [
          "FunctionClauseError",
          "CaseClauseError",
          "UndefinedFunctionError",
          ".AppLoginHTML.header/1",
          "AppLoginContinuation.",
          "AppLoginContinuation.put/3",
          "Plug.Conn.put_session/3",
          "Phoenix.Token.sign/3",
          ".Endpoint.config/1",
          "AppLoginHTML.",
          "Auth.AppSessions.",
          "Sigra.AppLogin.",
          "Sigra.Branding.",
          "Phoenix.Token."
        ] do
      assert app_login_classifier =~ marker,
            "hosted app-login error classification missing #{inspect(marker)}"
    end
  end

  test "generated-host proof classifies hosted exchange failures without retaining protocol values" do
    harness = read!(@harness)

    for marker <- [
          "hosted_exchange_response_diagnostic()",
          "hosted exchange response status=",
          "content_type=%s",
          "body=%s",
          "undefined_function_signature=%s",
          "hosted-exchange.headers",
          "hosted-replay.headers",
          "hosted_exchange_response_diagnostic \"$status\" \"${APP_DIR}/hosted-replay.headers\""
        ] do
      assert harness =~ marker,
             "hosted exchange diagnostics missing #{inspect(marker)}"
    end

    exchange_classifier =
      harness
      |> String.split("hosted_exchange_response_diagnostic()", parts: 2)
      |> List.last()
      |> String.split("json_field()", parts: 2)
      |> List.first()

    for marker <- ["UndefinedFunctionError", "FunctionClauseError", "CaseClauseError", "Internal Server Error"] do
      assert exchange_classifier =~ marker,
             "hosted exchange error classification missing #{inspect(marker)}"
    end

    refute exchange_classifier =~ "code_verifier",
           "hosted exchange diagnostics must not retain a verifier"
    refute exchange_classifier =~ "access_token",
           "hosted exchange diagnostics must not retain an access token"
  end

  test "generated hosted app-login approval uses the runtime CSRF helper" do
    approval = read!("priv/templates/sigra.install/app_sessions/app_login_approve.html.heex")

    assert approval =~ "Plug.CSRFProtection.get_csrf_token()"
    refute approval =~ "Phoenix.Controller.get_csrf_token()"
  end

  test "generated-host proof classifies the MFA HTTP response before extracting its token" do
    harness = read!(@harness)

    for marker <- [
          "fetch_mfa_form()",
          "hosted-mfa.headers",
          "hosted-mfa.content-type",
          "mfa response status=",
          "redirect=%s",
          "users_mfa",
          "users_log_in",
          "body=%s",
          "mfa_form",
          "csrf_meta_only",
          "other"
        ] do
      assert harness =~ marker, "MFA HTTP response diagnostics missing #{inspect(marker)}"
    end

    refute harness =~ "location=\\\"$(sed",
           "MFA diagnostics must classify redirect targets instead of retaining raw locations"
  end

  test "generated-host proof classifies the MFA completion response before asserting its redirect" do
    harness = read!(@harness)

    for marker <- [
          "hosted-mfa-completion.headers",
          "hosted-mfa-completion.html",
          "diagnostic_prefix=\"mfa completion response\"",
          "FunctionClauseError",
          "CaseClauseError",
          "UndefinedFunctionError",
          "server_error",
          "mfa_response_diagnostic \"completion\"",
          "^30[23]$"
        ] do
      assert harness =~ marker,
             "MFA completion diagnostics missing #{inspect(marker)}"
    end
  end

  test "generated direct MFA proof emits only a redacted response classification" do
    harness = read!(@harness)

    assert harness =~ "direct_mfa_response_diagnostic \"$status\" \"$mfa_body\""
    assert harness =~ "generated host proof direct_mfa status=%s body=%s"

    for forbidden <- ["$challenge", "$backup_code", "direct-proof@example.test"] do
      refute harness =~ "direct_mfa status=%s body=%s #{forbidden}"
    end
  end

  test "generated-host proof emits redacted stage diagnostics without replacing failure status" do
    harness = read!(@harness)

    for marker <- [
          "set -Eeuo pipefail",
          "CURRENT_STAGE=\"bootstrap\"",
          "set_stage()",
          "failure_diagnostic()",
          "trap 'failure_diagnostic \"$?\" \"$LINENO\"' ERR",
          "trap cleanup EXIT",
          "trap - EXIT ERR INT TERM"
        ] do
      assert harness =~ marker, "failure diagnostics missing #{inspect(marker)}"
    end

    probe = """
    set -Eeuo pipefail
    CURRENT_STAGE="bootstrap"
    set_stage() { CURRENT_STAGE="$1"; }
    failure_diagnostic() {
      local rc="$1"
      local line="$2"
      printf 'generated host proof failed stage=%s line=%s exit=%s\\n' "$CURRENT_STAGE" "$line" "$rc" >&2
    }
    cleanup() {
      local rc=$?
      trap - EXIT ERR INT TERM
      :
      exit "$rc"
    }
    trap 'failure_diagnostic "$?" "$LINENO"' ERR
    trap cleanup EXIT
    set_stage fixture_seed
    false
    """

    {output, 1} = System.cmd("bash", ["-c", probe], stderr_to_stdout: true)

    assert output =~ ~r/generated host proof failed stage=fixture_seed line=\d+ exit=1/

    for forbidden <- ["false", "CLOAK_KEY", "password", "token", "cookie", "postgres"] do
      refute output =~ forbidden, "terminal diagnostics must not expose #{inspect(forbidden)}"
    end
  end

  test "generated-host proof names post-ceremony contract stages before each run wrapper" do
    harness = read!(@harness)

    assert harness =~ "set_stage \"${mode}_post_ceremony_${contract}\""
    assert harness =~ "set_stage \"all_cross_ceremony_contracts\""
    assert harness =~ "run \"$SIGRA_REPO\" env MIX_ENV=test mix test"
  end

  test "generated-host proof assigns every post-ceremony contract a fixed stage" do
    harness = read!(@harness)

    for contract <- ["app_login", "app_login_direct", "app_login_direct_fault", "app_login_concurrency", "fetch_app_session"] do
      assert harness =~ "${mode}_post_ceremony_${contract}"
    end

    refute harness =~ "${mode}_post_ceremony_contracts"
  end

  test "generated-host proof prepares the root test database before root contracts" do
    harness = read!(@harness)
    postgres_repo = read!("test/support/postgres_test_repo.ex")

    [root_setup] =
      Regex.run(~r/(ensure_root_test_db\(\) \{.*?\n\})/s, harness, capture: :all_but_first)

    assert harness =~ "ensure_root_test_db()"
    assert harness =~ "root_test_db_uuid_ossp"
    assert harness =~ "CREATE EXTENSION IF NOT EXISTS \"uuid-ossp\""
    assert harness =~ "env MIX_ENV=test mix run --no-start -r test/support/postgres_test_repo.ex"
    assert root_setup =~ "config = Sigra.Test.PostgresRepo.default_config()"
    assert root_setup =~ "Ecto.Adapters.Postgres.storage_up(config)"
    assert root_setup =~ "{:error, :already_up} -> :ok"
    assert root_setup =~ "Sigra.Test.PostgresRepo.start_link(bootstrap_config)"
    assert root_setup =~ "bootstrap_config = Keyword.put(config, :pool, DBConnection.ConnectionPool)"
    assert harness =~ "Ecto.Adapters.SQL.query!(Sigra.Test.PostgresRepo"
    assert postgres_repo =~ "database: System.get_env(\"SIGRA_TEST_PG_DATABASE\", \"sigra_test\")"
    refute root_setup =~ "psql"
    refute root_setup =~ "IO.puts"
    refute harness =~ "DROP "
    refute harness =~ "RESET "
    refute root_setup =~ "mix ecto.create"
    refute root_setup =~ "mix ecto.migrate"
    assert root_setup =~ "GenServer.stop(pid)"
    refute root_setup =~ "Sandbox.checkout"
    refute root_setup =~ "Sandbox.checkin"

    root_setup_offset = :binary.match(harness, "ensure_root_test_db()") |> elem(0)
    root_contract_offset = :binary.match(harness, "for contract in app_login") |> elem(0)
    assert root_setup_offset < root_contract_offset
    assert harness =~ "ensure_root_test_db\n  for contract in app_login"
  end

  test "generated-host proof migrates the canonical root app-session schema before root scenarios" do
    harness = read!(@harness)

    [root_setup] =
      Regex.run(~r/(ensure_root_test_db\(\) \{.*?\n\})/s, harness, capture: :all_but_first)

    assert root_setup =~ "test/support/root_app_session_schema.ex"
    assert root_setup =~ "Ecto.Migrator.up("
    assert root_setup =~ "Sigra.Test.PostgresRepo"
    assert root_setup =~ "Sigra.Test.RootAppSessionSchema"

    root_setup_offset = :binary.match(harness, "ensure_root_test_db()") |> elem(0)
    root_contract_offset = :binary.match(harness, "for contract in app_login") |> elem(0)
    assert root_setup_offset < root_contract_offset
  end

  test "canonical root app-session migration preserves UTC microsecond timestamps" do
    schema = read!("test/support/root_app_session_schema.ex")

    assert schema =~ "timestamps(type: :utc_datetime_usec)"
    assert schema =~ "add :expires_at, :utc_datetime_usec, null: false"
    assert schema =~ "add :occurred_at, :utc_datetime_usec, null: false"
    refute schema =~ ":naive_datetime"
  end

  test "generated-host proof isolates every fixed app-login scenario" do
    harness = read!(@harness)

    for line <- [77, 103, 144, 175, 209, 251, 287] do
      assert harness =~ "${mode}_app_login_scenario_${scenario}"
      assert harness =~ "app_login_test.exs:${scenario}"
      assert harness =~ Integer.to_string(line)
    end
  end

  test "generated-host proof attributes replay family assertions before their database run" do
    harness = read!(@harness)

    assert harness =~ "set_stage \"${label}_family_count_aggregate\""
    assert harness =~ "EXPECTED_KIND=\"$expected_kind\" EXPECTED_LABEL=\"$label\" run"
  end

  test "family assertion reports only allowlisted count classes" do
    harness = read!(@harness)

    for marker <- [
          "family_class = case count",
          "attempt_class = case attempt_count",
          "family_count family=~s attempt=~s",
          "zero when zero <= 0 -> \"zero\"",
          "1 -> \"one\"",
          "_ -> \"many\""
        ] do
      assert harness =~ marker, "family count diagnostic missing #{inspect(marker)}"
    end

    refute harness =~ "family_count family=~s attempt=~s id=",
           "family assertion must not retain identifiers"
  end

  test "family assertion compares its trusted kind without constructing an atom" do
    harness = read!(@harness)

    refute harness =~ "String.to_existing_atom(System.fetch_env!(\"EXPECTED_KIND\"))"
    assert harness =~ "is_atom(attempt.kind) and Atom.to_string(attempt.kind) == expected_kind"
    assert harness =~ "fn attempt ->"
    refute harness =~ "&(is_atom(attempt.kind)"
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
