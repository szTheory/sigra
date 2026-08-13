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
          "callback/state/S256",
          "two-caller exchange",
          "fault rollback",
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
end
