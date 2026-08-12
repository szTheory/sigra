defmodule Sigra.Install.GeneratedRateLimitContractTest do
  use ExUnit.Case, async: true

  @core_feature "lib/sigra/install/features/core.ex"
  @rate_limit_template "priv/templates/sigra.install/core/rate_limit.ex"
  @settings_controller_template "priv/templates/sigra.install/core/settings_controller.ex"
  @mfa_settings_html_template "priv/templates/sigra.install/core/mfa_settings_html.ex"
  @smoke "scripts/ci/passkeys-opt-out-smoke.sh"

  defp read!(path), do: File.read!(path)

  defp assert_contains!(source, marker, context) do
    assert String.contains?(source, marker), "#{context} is missing #{inspect(marker)}"
  end

  test "canonical B2C output owns Hammer instead of falling back to Noop" do
    core = read!(@core_feature)
    template = read!(@rate_limit_template)

    for marker <- [
          "{:hammer, \"~> 7.4\"}",
          "rate_limit.ex",
          "hammer_module: \#{app_module}.RateLimit",
          "Sigra.RateLimiters.Hammer",
          "rate_limit_pipelines(web_module)",
          "rate_limited_scopes(web_module, live?)"
        ] do
      assert_contains!(core, marker, "generated Core ownership")
    end

    for marker <- ["defmodule \#{app_module}.RateLimit", "use Hammer, backend: :ets"] do
      assert_contains!(template, marker, "generated Hammer owner")
    end

    assert Regex.match?(
             ~r/\{\#\{app_module\}\.RateLimit,[\s\S]*?\{\#\{web_module\}\.Endpoint,/,
             core
           ),
           "generated RateLimit child must start before the generated Endpoint"
  end

  test "generated limiter boundary names deterministic threshold and ceiling-rounding proof" do
    core = read!(@core_feature)
    smoke = read!(@smoke)

    assert Regex.match?(
             ~r/limit:\s*3,[\s\S]*?window:\s*60_000/,
             core
           ),
           "the generated login route must pin integer low-bound testable defaults"

    for marker <- [
          "generated_rate_limit_probe_test.exs",
          "attempt N + 1",
          "retry-after",
          "1_000ms -> 1",
          "1_001ms -> 2",
          "30_500ms -> 31"
        ] do
      assert_contains!(smoke, marker, "bounded generated-host probe")
    end

    refute Regex.match?(~r/\bsleep\b|waitForTimeout|Process\.sleep/, smoke),
           "the bounded limiter probe must never wait for a rate window"
  end

  test "generated-host compile lanes cover both LiveView and controller router output" do
    core = read!(@core_feature)
    smoke = read!(@smoke)
    runtime = read!("scripts/ci/generated-auth-runtime-proof.sh")

    assert_contains!(core, "pipeline :\#{pipeline}", "generated rate-limit pipeline")
    assert_contains!(core, "limit_config_key", "request-time rate-limit configuration")
    assert_contains!(core, "window_config_key", "request-time rate-limit configuration")

    assert_contains!(
      smoke,
      "run_leg \"--no-admin --no-organizations --no-passkeys\" \"sigra_b2c_alpha\"",
      "canonical LiveView B2C generated-host compile lane"
    )

    assert_contains!(
      smoke,
      "run_leg \"--no-admin --no-organizations --no-passkeys --no-live\" \"sigra_b2c_controller\"",
      "controller-router generated-host compile lane"
    )

    assert_contains!(smoke, "mix compile --warnings-as-errors", "controller-router compilation")
    assert_contains!(runtime, "mix sigra.install", "LiveView generated-host lane")

    refute String.contains?(runtime, "--no-live"),
           "LiveView compile lane must retain LiveView output"

    assert_contains!(runtime, "mix compile --warnings-as-errors", "LiveView router compilation")
  end

  test "fresh-host smoke refreshes generated dependencies before probing or compiling" do
    smoke = read!(@smoke)
    install = "MIX_ENV=dev mix sigra.install Accounts User users ${flags} --yes"
    refresh = "MIX_ENV=dev mix deps.get"
    probe = "install_generated_rate_limit_probe"
    compile = "MIX_ENV=dev mix compile --warnings-as-errors"

    {install_at, _} = :binary.match(smoke, install)
    after_install_at = install_at + byte_size(install)
    after_install = binary_part(smoke, after_install_at, byte_size(smoke) - after_install_at)
    {refresh_relative_at, _} = :binary.match(after_install, refresh)
    {probe_relative_at, _} = :binary.match(after_install, "\n    " <> probe <> "\n")
    {compile_relative_at, _} = :binary.match(after_install, compile)

    refresh_at = after_install_at + refresh_relative_at
    probe_at = after_install_at + probe_relative_at
    compile_at = after_install_at + compile_relative_at

    assert install_at && refresh_at && probe_at && compile_at,
           "fresh-host smoke must retain its install, dependency refresh, probe, and compile lifecycle"

    assert install_at < refresh_at and refresh_at < probe_at and refresh_at < compile_at,
           "dependencies injected by sigra.install must be fetched before the probe and compilation"
  end

  test "fresh-host smoke routes generated databases to the supplied local Postgres endpoint" do
    smoke = read!(@smoke)

    assert_contains!(
      smoke,
      "hostname: System.get_env(\\\"PGHOST\\\", \\\"localhost\\\")",
      "generated-host database hostname override"
    )

    assert_contains!(
      smoke,
      "port: String.to_integer(System.get_env(\\\"PGPORT\\\", \\\"5432\\\"))",
      "generated-host database port override"
    )

    assert_contains!(
      smoke,
      "for path <- [\"config/dev.exs\", \"config/test.exs\"]",
      "generated-host dev and test database endpoint isolation"
    )
  end

  test "controller MFA route probe preserves explicit rendering, exact-session sudo, and lane isolation" do
    controller = read!(@settings_controller_template)
    mfa_html = read!(@mfa_settings_html_template)
    smoke = read!(@smoke)
    runtime = read!("scripts/ci/generated-auth-runtime-proof.sh")

    assert Regex.match?(
             ~r/def mfa\(conn, _params\) do[\s\S]*?status = Auth\.mfa_status\(conn\.assigns\.current_scope\.user\)[\s\S]*?put_view\(html: <%= web_module %>\.MFASettingsHTML\)[\s\S]*?render\(:mfa_settings,/,
             controller
           ),
           "mfa must explicitly select MFASettingsHTML after status lookup and before rendering"

    for marker <- [
          "def mfa_settings(assigns)",
          "@mfa_enabled",
          "@backup_remaining",
          "@enrollment_step",
          "@svg",
          "@base32_secret",
          "@backup_codes",
          "@show_disable"
        ] do
      assert_contains!(mfa_html, marker, "controller MFA HTML assign contract")
    end

    for marker <- [
          "install_generated_mfa_settings_route_probe",
          "generated_mfa_settings_route_probe_test.exs",
          "Plug.Conn.get_session(conn, :user_token)",
          "Accounts.get_user_and_session_by_token(token)",
          "Repo.get_by!(hashed_token: session.hashed_token)",
          "Ecto.Changeset.change(sudo_at: DateTime.utc_now())",
          "html_response(200)",
          "Two-Factor Authentication",
          "MIX_ENV=test mix test test/generated_mfa_settings_route_probe_test.exs",
          "SIGRA_PASSKEYS_OPT_OUT_LEG=sigra_b2c_controller GITHUB_WORKSPACE=\"$(pwd)\" scripts/ci/passkeys-opt-out-smoke.sh"
        ] do
      assert_contains!(smoke, marker, "controller MFA route proof")
    end

    controller_branch = "if [[ \"${label}\" == \"sigra_b2c_controller\" ]]; then"
    {branch_at, _} = :binary.match(smoke, controller_branch)
    controller_branch_source = binary_part(smoke, branch_at, byte_size(smoke) - branch_at)
    {migration_at, _} = :binary.match(controller_branch_source, "MIX_ENV=test mix ecto.migrate")

    {probe_at, _} =
      :binary.match(
        controller_branch_source,
        "MIX_ENV=test mix test test/generated_mfa_settings_route_probe_test.exs"
      )

    assert branch_at && migration_at && probe_at && migration_at < probe_at,
           "the controller probe must remain after the generated test migration in its controller-only branch"

    assert_contains!(
      smoke,
      "SIGRA_PASSKEYS_OPT_OUT_LEG=\"${SIGRA_PASSKEYS_OPT_OUT_LEG:-all}\"",
      "focused-leg default"
    )

    for label <- [
          "all",
          "sigra_no_passkeys",
          "sigra_no_organizations_no_passkeys",
          "sigra_b2c_alpha",
          "sigra_b2c_controller"
        ] do
      assert_contains!(smoke, label, "focused-leg allowlist")
    end

    assert_contains!(smoke, "SIGRA_PASSKEYS_OPT_OUT_LEG must be", "invalid focused-leg rejection")

    for invocation <- [
          "run_leg \"--no-passkeys\" \"sigra_no_passkeys\"",
          "run_leg \"--no-organizations --no-passkeys\" \"sigra_no_organizations_no_passkeys\"",
          "run_leg \"--no-admin --no-organizations --no-passkeys\" \"sigra_b2c_alpha\"",
          "run_leg \"--no-admin --no-organizations --no-passkeys --no-live\" \"sigra_b2c_controller\""
        ] do
      assert_contains!(smoke, invocation, "default four-leg smoke topology")
    end

    for action <- ["disable", "regenerate", "revoke_trust", "enroll", "confirm", "complete"] do
      assert_contains!(
        controller,
        "def #{action}(conn, _params), do: unavailable(conn)",
        "controller MFA mutation deferral"
      )
    end

    refute Regex.match?(~r/\bsleep\b|waitForTimeout|Process\.sleep/, smoke),
           "the controller MFA route proof must not use fixed waits"

    refute String.contains?(runtime, "--no-live"),
           "the canonical LiveView runtime lane must remain independent from controller mode"
  end

  test "credential-free generated LiveView host proves bounded registration exhaustion" do
    runtime = read!("scripts/ci/generated-auth-runtime-proof.sh")

    for marker <- [
          "install_generated_liveview_rate_limit_probe",
          "generated_liveview_rate_limit_probe_test.exs",
          "Phoenix.LiveViewTest",
          "render_submit()",
          "N + 1 denial",
          "Sigra.RateLimiters.Hammer.check_rate",
          "MIX_ENV=test mix test test/generated_liveview_rate_limit_probe_test.exs"
        ] do
      assert_contains!(runtime, marker, "generated LiveView exhaustion proof")
    end

    refute Regex.match?(~r/\bsleep\b|waitForTimeout|Process\.sleep/, runtime),
           "the generated LiveView limiter proof must not wait for a rate window"
  end

  test "reapplying generated ownership is protected by unique idempotency markers" do
    core = read!(@core_feature)

    for marker <- [
          "sigra:rate-limit:dependency",
          "sigra:rate-limit:file",
          "sigra:rate-limit:application",
          "sigra:rate-limit:config",
          "sigra:rate-limit:\#{key_prefix}-route"
        ] do
      assert_contains!(core, marker, "generated rate-limit idempotency")
    end
  end
end
