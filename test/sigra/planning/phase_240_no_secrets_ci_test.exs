defmodule Sigra.Planning.Phase240NoSecretsCiTest do
  use ExUnit.Case, async: true

  @ci_workflow ".github/workflows/ci.yml"
  @runtime_workflow ".github/workflows/generated-auth-runtime-proof.yml"
  @generator_harness "scripts/ci/passkeys-opt-out-smoke.sh"
  @runtime_harness "scripts/ci/generated-auth-runtime-proof.sh"
  @coverage ".planning/phases/240-alpha-operations-rehearsal/COVERAGE.md"

  defp read!(path), do: File.read!(path)

  defp assert_contains!(source, marker, context) do
    assert String.contains?(source, marker), "#{context} is missing #{inspect(marker)}"
  end

  defp assert_no_secret_injection!(source, context) do
    refute Regex.match?(~r/\$\{\{\s*secrets\./i, source),
           "#{context} must not inject GitHub secrets"

    refute Regex.match?(
             ~r/(?:GOOGLE|POSTMARK|MAILGUN|SENDGRID|DEPLOY)[A-Z_]*\s*[:=].*\$\{/i,
             source
           ),
           "#{context} must not inject provider, mail, or deployment credentials"
  end

  test "fresh generation and rendered runtime remain distinct credential-free lanes" do
    ci = read!(@ci_workflow)
    runtime_workflow = read!(@runtime_workflow)
    generator = read!(@generator_harness)
    runtime = read!(@runtime_harness)

    assert_contains!(ci, "passkeys-opt-out-smoke.sh", "fresh-generator workflow lane")

    assert_contains!(
      runtime_workflow,
      "generated-auth-runtime-proof.sh",
      "rendered-runtime workflow lane"
    )

    assert_contains!(generator, "sigra_b2c_alpha", "fresh canonical B2C harness")
    assert_contains!(runtime, "--project=generated-auth", "rendered runtime harness")

    refute String.contains?(ci, "generated-auth-runtime-proof.sh"),
           "the rendered runtime lane must not be merged into the legacy aggregate"
  end

  test "workflow and harness regions never inject secrets and unset inherited Google values first" do
    ci = read!(@ci_workflow)
    runtime_workflow = read!(@runtime_workflow)
    generator = read!(@generator_harness)
    runtime = read!(@runtime_harness)

    for {source, context} <- [
          {ci, "fresh-generator workflow"},
          {runtime_workflow, "rendered-runtime workflow"},
          {generator, "fresh-generator harness"},
          {runtime, "rendered-runtime harness"}
        ] do
      assert_no_secret_injection!(source, context)
    end

    assert Regex.match?(
             ~r/unset GOOGLE_CLIENT_ID GOOGLE_CLIENT_SECRET[\s\S]*?boot_and_run_spec\(\)/,
             runtime
           ),
           "rendered-runtime harness must unset inherited Google credentials before boot"
  end

  test "fixed values are named disposable fixtures and local-only proof claims stay bounded" do
    generator = read!(@generator_harness)
    runtime = read!(@runtime_harness)

    for {source, marker, context} <- [
          {generator, "CLOAK_KEY", "fresh-generator fixture"},
          {runtime, "CLOAK_KEY", "rendered-runtime fixture"},
          {runtime, "sigra-oauth-proof-secret", "loopback OIDC fixture"}
        ] do
      assert Regex.match?(~r/#{Regex.escape(marker)}[\s\S]{0,180}disposable fixture/i, source),
             "#{context} must label #{inspect(marker)} as a disposable fixture"
    end

    for forbidden_claim <- [
          "Google Console success",
          "mail provider success",
          "DNS/TLS deployment success",
          "reverse proxy success",
          "physical-device success"
        ] do
      refute String.contains?(generator <> runtime, forbidden_claim),
             "local proof must not claim #{forbidden_claim}"
    end
  end

  test "phase coverage declares only local evidence without detector-backed status" do
    coverage = read!(@coverage)

    assert coverage |> String.split("\n") |> Enum.at(2) ==
             "No external API integration: this phase configures generated-host rate limiting and verifies local evidence without adding or expanding an external API client.",
           "COVERAGE.md must remain the exact local-only declaration"

    refute Regex.match?(~r/\b(?:detector|scan|passed|green)\b/i, coverage),
           "COVERAGE.md must not claim detector-backed status"
  end
end
