defmodule Sigra.Planning.Phase238GeneratedAuthRuntimeProofTest do
  use ExUnit.Case, async: true

  @config "test/example/priv/playwright/playwright.config.ts"
  @harness "scripts/ci/generated-auth-runtime-proof.sh"
  @mailbox "test/example/priv/playwright/fixtures/mailbox.ts"
  @journey "test/example/priv/playwright/tests/generated-auth.spec.ts"
  @oauth_probe "test/example/priv/playwright/tests/generated-auth-oauth-probe.spec.ts"

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

    refute Regex.match?(~r/name: 'admin-generated'[\s\S]*?GENERATED_AUTH_SPECS/m, config),
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
          "get \"/.well-known/openid-configuration\"",
          "get \"/authorize\"",
          "post \"/token\"",
          "--project=generated-auth",
          "--retries=0"
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
end
