defmodule Sigra.Install.GeneratedRateLimitContractTest do
  use ExUnit.Case, async: true

  @core_feature "lib/sigra/install/features/core.ex"
  @rate_limit_template "priv/templates/sigra.install/core/rate_limit.ex"
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
      "hostname: System.get_env(\"PGHOST\", \"localhost\")",
      "generated-host database hostname override"
    )

    assert_contains!(
      smoke,
      "port: String.to_integer(System.get_env(\"PGPORT\", \"5432\"))",
      "generated-host database port override"
    )
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
