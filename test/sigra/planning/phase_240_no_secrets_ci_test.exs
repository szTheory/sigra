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

  defp workflow_job!(workflow, job) do
    [_, region] = Regex.run(~r/^  #{job}:\n([\s\S]*?)(?=^  [a-zA-Z0-9_\-]+:|\z)/m, workflow)
    region
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

    generator_job = workflow_job!(ci, "passkeys_opt_out_smoke")
    runtime_job = workflow_job!(ci, "generated_auth_runtime_proof")
    ci_gate = workflow_job!(ci, "ci-gate")

    assert_contains!(generator_job, "passkeys-opt-out-smoke.sh", "fresh-generator workflow lane")

    assert_contains!(
      runtime_workflow,
      "generated-auth-runtime-proof.sh",
      "rendered-runtime workflow lane"
    )

    assert_contains!(generator, "sigra_b2c_alpha", "fresh canonical B2C harness")
    assert_contains!(runtime, "--project=generated-auth", "rendered runtime harness")

    for source <- [generator_job, runtime_job, runtime_workflow] do
      assert_contains!(
        source,
        "No host staging success is claimed",
        "credential-free workflow boundary"
      )
    end

    refute String.contains?(generator_job, "generated-auth-runtime-proof.sh"),
           "the fresh-generator lane must not substitute the rendered-runtime proof"

    refute String.contains?(runtime_job, "passkeys-opt-out-smoke.sh"),
           "the rendered-runtime lane must not substitute the fresh-generator proof"

    refute String.contains?(ci_gate, "generated_auth_runtime_proof"),
           "the rendered runtime lane must remain outside the legacy skip-tolerant aggregate"
  end

  test "workflow and harness regions never inject secrets and unset inherited Google values first" do
    ci = read!(@ci_workflow)
    runtime_workflow = read!(@runtime_workflow)
    generator = read!(@generator_harness)
    runtime = read!(@runtime_harness)

    generator_job = workflow_job!(ci, "passkeys_opt_out_smoke")
    runtime_job = workflow_job!(ci, "generated_auth_runtime_proof")

    for {source, context} <- [
          {generator_job, "fresh-generator workflow"},
          {runtime_job, "rendered-runtime CI workflow"},
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

    for allowed_claim <- [
          "generator shape, compile, boot",
          "local OIDC state/PKCE/callback",
          "rendered B2C behavior"
        ] do
      assert_contains!(generator <> runtime, allowed_claim, "bounded local-proof claim")
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

  test "proof sources retain deterministic local boundaries without browser state mutation or waivers" do
    runtime = read!(@runtime_harness)

    for source <- [
          runtime,
          read!("test/example/priv/playwright/tests/generated-auth.spec.ts"),
          read!("test/example/priv/playwright/tests/generated-auth-oauth-probe.spec.ts")
        ] do
      refute Regex.match?(~r/\b(?:clearCookies|addCookies|storageState)\s*\(/, source),
             "proof sources must not mutate browser cookies or storage state"

      refute Regex.match?(
               ~r/\b(?:localStorage|sessionStorage)\s*\.\s*(?:clear|setItem|removeItem)\s*\(/,
               source
             ),
             "proof sources must not mutate browser Web Storage"

      refute Regex.match?(~r/\b(?:waitForTimeout|sleep)\b/, source),
             "proof sources must not contain fixed sleeps"

      refute Regex.match?(~r/--retries=(?:[1-9]\d*)/, source),
             "proof sources must not use retry-based waivers"
    end
  end
end
