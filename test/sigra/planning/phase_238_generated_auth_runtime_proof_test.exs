defmodule Sigra.Planning.Phase238GeneratedAuthRuntimeProofTest do
  use ExUnit.Case, async: true

  @config "test/example/priv/playwright/playwright.config.ts"
  @harness "scripts/ci/generated-auth-runtime-proof.sh"
  @mailbox "test/example/priv/playwright/fixtures/mailbox.ts"
  @journey "test/example/priv/playwright/tests/generated-auth.spec.ts"
  @oauth_probe "test/example/priv/playwright/tests/generated-auth-oauth-probe.spec.ts"
  @workflow ".github/workflows/generated-auth-runtime-proof.yml"
  @registration_live "priv/templates/sigra.install/core/registration_live.ex"

  defp read!(path), do: File.read!(path)

  defp assert_contains!(source, marker, context) do
    assert String.contains?(source, marker), "#{context} is missing #{inspect(marker)}"
  end

  test "Generated Auth Runtime Proof isolates the complete suite in its own Chromium project" do
    config = read!(@config)

    for marker <- [
          "const GENERATED_AUTH_SPECS =",
          "generated-auth\\.spec\\.ts|generated-auth-oauth-probe\\.spec\\.ts",
          "name: 'generated-auth'",
          "testMatch: GENERATED_AUTH_SPECS",
          "...devices['Desktop Chrome']",
          "video: checkpointVideo"
        ] do
      assert_contains!(config, marker, "dedicated generated-auth project")
    end

    for project <- ["chromium", "mobile"] do
      assert Regex.match?(
               ~r/name: '#{project}'[\s\S]*?testIgnore: \[[\s\S]*?GENERATED_AUTH_SPECS/m,
               config
             ),
             "#{project} must ignore generated-auth specs so it cannot run them against test/example"
    end

    assert Regex.match?(~r/name: 'admin-generated'[\s\S]*?testMatch: ADMIN_GENERATED_SPEC/m, config),
           "admin-generated must remain a separate admin parity partition"
  end

  test "Generated Auth Runtime Proof locks the local OAuth, mailbox, journey, and accessibility evidence" do
    harness = read!(@harness)
    mailbox = read!(@mailbox)
    journey = read!(@journey)
    oauth_probe = read!(@oauth_probe)

    for marker <- [
          "base_url: \"http://127.0.0.1:${PORT}/oidc\"",
          "client_id: \"sigra-oauth-proof-client\"",
          "client_secret: \"sigra-oauth-proof-secret\"",
          "id_token_signed_response_alg: \"HS256\"",
          "code_verifier: true",
          "OidcDoubleController, :discovery",
          "OidcDoubleController, :authorize",
          "OidcDoubleController, :token",
          "require Logger",
          "@callback_url \"http://127.0.0.1:${PORT}/auth/google/callback\"",
          ":crypto.mac(:hmac, :sha256, @client_secret, signing_input)",
          "--project=generated-auth",
          "--retries=0",
          "\"--all\") SPEC_FILES=(\"tests/generated-auth.spec.ts\" \"tests/generated-auth-oauth-probe.spec.ts\")"
        ] do
      assert_contains!(harness, marker, "fresh-host OAuth harness")
    end

    assert_contains!(mailbox, "expect.poll(", "mailbox fixture")
    assert_contains!(mailbox, "intervals: [250, 500, 1_000]", "mailbox fixture")
    refute String.contains?(mailbox, "waitForTimeout"), "mailbox fixture must not use fixed browser sleeps"
    refute Regex.match?(~r/\bsleep\s*\(/, mailbox), "mailbox fixture must not use fixed delays"

    for marker <- [
          "generated B2C email authentication journey",
          "registration",
          "magic-link sent",
          "reset token form",
          "Google collision login",
          "new AxeBuilder({ page })",
          ".include('main.sigra-auth')",
          "labels: []",
          "unlabeledControls: []",
          "duplicateIds: []"
        ] do
      assert_contains!(journey, marker, "complete generated-auth journey")
    end

    for marker <- [
          "generated /auth/google preserves signed state and PKCE",
          "code_challenge_method",
          "An account with this email exists. Log in to link your google account."
        ] do
      assert_contains!(oauth_probe, marker, "OAuth probe")
    end
  end

  test "Generated Auth Runtime Proof retains its contract lookup after entering the disposable host" do
    harness = read!(@harness)

    assert Regex.match?(
             ~r/assert_locked_contract\(\)\s*\{[\s\S]*?\$\{CI_DIR\}\/generated-auth-runtime-proof\.sh/m,
             harness
           ),
           "assert_locked_contract must read the retained harness through CI_DIR after boot_and_run_spec changes into APP_DIR"

    assert_contains!(harness, "grep -Eq", "portable retained-harness contract checks")
    refute String.contains?(harness, "rg -q"),
           "retained-harness contract checks must not depend on rg being installed in the CI runner"
  end

  test "generated registration preserves a concrete virtual password change for the triggered sign-in" do
    registration_live = read!(@registration_live)

    assert_contains!(
      registration_live,
      "Ecto.Changeset.change(user, password: user_params[\"password\"])",
      "post-registration native sign-in form"
    )
  end

  test "Generated Auth Runtime Proof has a dispatchable isolated workflow with only its prerequisite guard" do
    workflow = read!(@workflow)

    for marker <- [
          "name: Generated auth runtime proof",
          "workflow_dispatch:",
          "phase-238-generated-auth-proof-*",
          "release_ref_guard:",
          "EVIDENCE_REF: ${{ inputs.evidence_ref }}",
          "GITHUB_REF_NAME: ${{ github.ref_name }}"
        ] do
      assert_contains!(workflow, marker, "isolated generated-auth workflow")
    end

    job =
      case Regex.run(~r/^  generated_auth_runtime_proof:\s*$([\s\S]*?)(?=^  [a-zA-Z0-9_-]+:\s*$|\z)/m, workflow) do
        [_, block] -> block
        _ -> flunk("generated_auth_runtime_proof job block not found")
      end

    for marker <- [
          "name: Generated auth runtime proof",
          "needs: release_ref_guard",
          "timeout-minutes: 25",
          "image: postgres:15",
          "version-type: strict",
          "node-version: '20'",
          "cache-dependency-path: 'test/example/priv/playwright/package-lock.json'",
          "mix archive.install --force hex phx_new 1.8.8",
          "npm ci",
          "npx playwright install --with-deps chromium",
          "GITHUB_WORKSPACE=\"$PWD\" scripts/ci/generated-auth-runtime-proof.sh --all",
          "GENERATED_AUTH_RUNTIME_PROOF_ARTIFACT_DIR",
          "playwright-report/",
          "test-results/",
          "generated-auth-runtime-proof/",
          "retention-days: 7",
          "if-no-files-found: warn"
        ] do
      assert_contains!(job, marker, "generated-auth CI job")
    end

    refute String.contains?(workflow, "admin_eval_render:"),
           "isolated runtime proof workflow must not wait for unrelated admin evaluation"

    refute String.contains?(job, "GOOGLE_CLIENT_ID"),
           "generated-auth runtime proof must not inject provider credentials"

    refute String.contains?(job, "GOOGLE_CLIENT_SECRET"),
           "generated-auth runtime proof must not inject provider credentials"
  end
end
