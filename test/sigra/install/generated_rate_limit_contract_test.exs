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
    assert_contains!(smoke, "--no-live", "controller-router generated-host compile lane")
    assert_contains!(smoke, "mix compile --warnings-as-errors", "controller-router compilation")
    assert_contains!(runtime, "mix sigra.install", "LiveView generated-host lane")

    refute String.contains?(runtime, "--no-live"),
           "LiveView compile lane must retain LiveView output"

    assert_contains!(runtime, "mix compile --warnings-as-errors", "LiveView router compilation")
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
