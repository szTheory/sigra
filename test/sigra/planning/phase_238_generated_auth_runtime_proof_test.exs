defmodule Sigra.Planning.Phase238GeneratedAuthRuntimeProofTest do
  use ExUnit.Case, async: true

  @config "test/example/priv/playwright/playwright.config.ts"
  @harness "scripts/ci/generated-auth-runtime-proof.sh"
  @mailbox "test/example/priv/playwright/fixtures/mailbox.ts"
  @journey "test/example/priv/playwright/tests/generated-auth.spec.ts"
  @oauth_probe "test/example/priv/playwright/tests/generated-auth-oauth-probe.spec.ts"
  @workflow ".github/workflows/generated-auth-runtime-proof.yml"
  @auth_template "priv/templates/sigra.install/core/auth.ex"
  @registration_live "priv/templates/sigra.install/core/registration_live.ex"
  @reset_password_live "priv/templates/sigra.install/core/reset_password_live.ex"
  @audit_migration "priv/templates/sigra.install/core/create_audit_events.exs"
  @confirmation_live "priv/templates/sigra.install/core/confirmation_live.ex"
  @oauth_controller "priv/templates/sigra.gen.oauth/oauth_controller.ex"
  @session_controller "priv/templates/sigra.install/core/session_controller.ex"
  @auth_components "priv/templates/sigra.install/core/sigra_auth_components.ex"
  @auth_flash_views [
    "priv/templates/sigra.install/core/confirmation_html.ex",
    "priv/templates/sigra.install/core/confirmation_live.ex",
    "priv/templates/sigra.install/core/login_html.ex",
    "priv/templates/sigra.install/core/mfa_challenge_html.ex",
    "priv/templates/sigra.install/core/mfa_challenge_live.ex",
    "priv/templates/sigra.install/core/mfa_settings_html.ex",
    "priv/templates/sigra.install/core/mfa_settings_live.ex",
    "priv/templates/sigra.install/core/reactivation_live.ex",
    "priv/templates/sigra.install/core/registration_html.ex",
    "priv/templates/sigra.install/core/registration_live.ex",
    "priv/templates/sigra.install/core/reset_password_html.ex",
    "priv/templates/sigra.install/core/reset_password_live.ex",
    "priv/templates/sigra.install/core/session_live.ex",
    "priv/templates/sigra.install/core/settings_live.ex",
    "priv/templates/sigra.install/core/sudo_html.ex"
  ]

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

    assert Regex.match?(
             ~r/name: 'admin-generated'[\s\S]*?testMatch: ADMIN_GENERATED_SPEC/m,
             config
           ),
           "admin-generated must remain a separate admin parity partition"
  end

  test "Generated Auth Runtime Proof locks the local OAuth, mailbox, journey, and accessibility evidence" do
    harness = read!(@harness)
    mailbox = read!(@mailbox)
    journey = read!(@journey)
    oauth_probe = read!(@oauth_probe)
    auth_template = read!(@auth_template)

    assert_contains!(
      auth_template,
      "secret_key_base: <%= web_module %>.Endpoint.config(:secret_key_base)",
      "generated Auth configuration"
    )

    for marker <- [
          "base_url: \"http://127.0.0.1:${PORT}/oidc\"",
          "client_id: \"sigra-oauth-proof-client\"",
          "client_secret: \"sigra-oauth-proof-secret\"",
          "id_token_signed_response_alg: \"HS256\"",
          "code_verifier: true",
          "{:assent,",
          "OidcDoubleController, :discovery",
          "OidcDoubleController, :authorize",
          "OidcDoubleController, :token",
          "require Logger",
          "@callback_url \"http://127.0.0.1:${PORT}/auth/google/callback\"",
          ":crypto.mac(:hmac, :sha256, @client_secret, signing_input)",
          ":crypto.hash(:sha256, verifier)",
          "--project=generated-auth",
          "--retries=0",
          "\"--all\") SPEC_FILES=(\"tests/generated-auth.spec.ts\" \"tests/generated-auth-oauth-probe.spec.ts\")"
        ] do
      assert_contains!(harness, marker, "fresh-host OAuth harness")
    end

    assert_contains!(mailbox, "expect.poll(", "mailbox fixture")
    assert_contains!(mailbox, "intervals: [250, 500, 1_000]", "mailbox fixture")

    refute String.contains?(mailbox, "waitForTimeout"),
           "mailbox fixture must not use fixed browser sleeps"

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
      "assign(trigger_submit: true, submitted_password: user_params[\"password\"])",
      "post-registration native sign-in form"
    )

    assert_contains!(
      registration_live,
      ":if={!@trigger_submit}",
      "native sign-in password control"
    )

    assert_contains!(
      registration_live,
      ":if={@trigger_submit}",
      "native sign-in password handoff"
    )

    assert_contains!(
      registration_live,
      "value={@submitted_password}",
      "native sign-in password value"
    )
  end

  test "generated base audit migration supports the logged-in runtime handoff without organizations" do
    audit_migration = read!(@audit_migration)

    assert_contains!(
      audit_migration,
      "add :effective_user_id, :binary_id, null: true",
      "credential-free generated host audit schema"
    )
  end

  test "generated anonymous confirmation and OAuth routes resolve their runtime dependencies" do
    confirmation_live = read!(@confirmation_live)
    auth_template = read!(@auth_template)
    oauth_controller = read!(@oauth_controller)

    refute String.contains?(confirmation_live, "_user = socket.assigns.current_scope.user"),
           "email confirmation links must work without an authenticated current_scope"

    assert_contains!(
      oauth_controller,
      "alias <%= context_module %>, as: Auth",
      "OAuth controller"
    )

    assert_contains!(oauth_controller, "config = Auth.sigra_config()", "OAuth controller")

    assert_contains!(
      auth_template,
      "identity_schema: <%= context_module %>.UserIdentity",
      "generated OAuth identity schema config"
    )

    refute String.contains?(oauth_controller, "conn.assigns[:sigra_config]"),
           "OAuth controller must not require an unassigned conn config"

    assert Regex.match?(
             ~r/session_params = %\{\s*sigra_state: get_session\(conn, :sigra_oauth_state\)/s,
             oauth_controller
           ),
           "OAuth callback must restore the Sigra state under Sigra's :sigra_state session key"

    assert_contains!(
      oauth_controller,
      "state: get_session(conn, :sigra_oauth_state)",
      "OAuth callback Assent session state"
    )

    assert_contains!(
      oauth_controller,
      "code_verifier: get_session(conn, :sigra_oauth_code_verifier)",
      "OAuth callback Assent session"
    )
  end

  test "generated magic-link requests deliver the newly-issued URL to the host mailbox" do
    auth_template = read!(@auth_template)
    session_controller = read!(@session_controller)

    for marker <- [
          "def deliver_user_magic_link_instructions(email, magic_link_url_fun)",
          "<%= context_module %>.Emails.magic_link_email(user, url)",
          "Sigra.Delivery.deliver(:magic_link",
          "url: url"
        ] do
      assert_contains!(auth_template, marker, "generated magic-link delivery")
    end

    assert_contains!(
      session_controller,
      "Auth.deliver_user_magic_link_instructions(email, url_fun)",
      "generated magic-link controller delivery"
    )
  end

  test "generated reset-password requests accept their route action and deliver by email" do
    reset_password_live = read!(@reset_password_live)

    for marker <- [
          "def render(%{live_action: live_action} = assigns) when live_action in [nil, :new] do",
          "deliver_user_reset_password_instructions(\n      email,",
          "&url(socket, ~p\"/users/reset-password/\#{&1}\")"
        ] do
      assert_contains!(reset_password_live, marker, "generated reset-password request")
    end
  end

  test "generated auth shell renders controller flash messages after redirects" do
    auth_components = read!(@auth_components)

    for marker <- [
          "attr :flash, :map, default: %{}",
          "Phoenix.Flash.get(@flash, :info)",
          "Phoenix.Flash.get(@flash, :error)",
          "role=\"status\"",
          "role=\"alert\""
        ] do
      assert_contains!(auth_components, marker, "generated auth flash surface")
    end

    for path <- @auth_flash_views do
      assert_contains!(
        read!(path),
        "<.sigra_auth_page flash={@flash}>",
        "generated auth flash forwarding in #{path}"
      )
    end
  end

  test "Generated Auth Runtime Proof has a dispatchable isolated workflow with only its prerequisite guard" do
    workflow = read!(@workflow)

    for marker <- [
          "name: Generated auth runtime proof",
          "workflow_dispatch:",
          "release_ref_guard:",
          "EVIDENCE_REF: ${{ inputs.evidence_ref }}",
          "GITHUB_REF_NAME: ${{ github.ref_name }}",
          "test \"$EVIDENCE_REF\" = \"$GITHUB_REF_NAME\""
        ] do
      assert_contains!(workflow, marker, "isolated generated-auth workflow")
    end

    refute String.contains?(workflow, "push:"),
           "isolated runtime proof must be explicitly workflow-dispatched at its evidence ref"

    refute String.contains?(workflow, "phase-238-generated-auth-proof-*"),
           "tag inference cannot be used to correlate Phase 238 proof evidence"

    job =
      case Regex.run(
             ~r/^  generated_auth_runtime_proof:\s*$([\s\S]*?)(?=^  [a-zA-Z0-9_-]+:\s*$|\z)/m,
             workflow
           ) do
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
