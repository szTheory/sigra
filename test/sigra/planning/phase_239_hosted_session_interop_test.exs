defmodule Sigra.Planning.Phase239HostedSessionInteropTest do
  use ExUnit.Case, async: true

  @proof ".planning/phases/239-hosted-session-interop/239-CROSSWAKE-RELEASE-PROOF.json"
  @release ".planning/phases/239-hosted-session-interop/239-CROSSWAKE-RELEASE.json"
  @coverage ".planning/phases/239-hosted-session-interop/COVERAGE.md"
  @recipe "guides/recipes/b2c-alpha.md"
  @root_mix "mix.exs"
  @example_mix "test/example/mix.exs"
  @adapter "test/example/lib/example/accounts/crosswake_session_adapter.ex"
  @adapter_test "test/example/test/example/accounts/crosswake_session_adapter_test.exs"
  @runner "scripts/ci/hosted-session-interop-proof.sh"

  @commands [
    "mix format --check-formatted packages/crosswake_sigra/test/crosswake/companions/sigra/contracts_test.exs packages/crosswake_sigra/test/crosswake/proof/phase57_auth_return_boundaries_test.exs",
    "cd packages/crosswake_sigra && mix test test/crosswake/companions/sigra/contracts_test.exs",
    "cd packages/crosswake_sigra && mix test test/crosswake/proof/phase57_auth_return_boundaries_test.exs",
    "cd packages/crosswake_sigra && mix test"
  ]

  defp read!(path), do: File.read!(path)
  defp decode!(path), do: path |> read!() |> Jason.decode!()

  test "Wave 0 proof is ordered, complete, and release-aligned" do
    proof = decode!(@proof)
    release = decode!(@release)

    assert proof["schema"] == "sigra.phase239.crosswake-release-proof.v1"

    for key <-
          ~w(repository package version requirement git_tag git_sha hex_checksum published_at verified_at) do
      assert is_binary(proof[key]) and proof[key] != "", "proof is missing #{key}"
      assert proof[key] == release[key], "release coordinate #{key} drifted"
    end

    assert proof["package"] == "crosswake_sigra"
    assert proof["version"] == "0.1.3"
    assert proof["requirement"] == "~> 0.1.3"
    assert Regex.match?(~r/\A[0-9a-f]{40}\z/, proof["git_sha"])
    assert Regex.match?(~r/\A[0-9a-f]{64}\z/, proof["hex_checksum"])

    assert Enum.map(proof["commands"], & &1["command"]) == @commands
    assert length(proof["commands"]) == 4

    for command <- proof["commands"] do
      assert is_number(command["exit_status"])
      assert command["exit_status"] == 0
      assert command["outcome"] == "passed"
    end

    assert read!(@example_mix) =~ "{:crosswake_sigra, \"~> 0.1.3\"}"
    refute read!(@root_mix) =~ "crosswake_sigra"
  end

  test "adapter suite contains the complete fail-closed host boundary" do
    adapter = read!(@adapter)
    adapter_test = read!(@adapter_test)

    for marker <- [
          "Accounts.get_user_and_session_by_token(raw_token)",
          "org_id: nil",
          "session_ref:",
          "subject_ref:",
          "session_version:",
          "validate_current_session",
          "match_binding",
          "evaluator(opts)",
          "AuthReturn.new_envelope(return_input)",
          "Map.put(result, :evidence, evidence)"
        ] do
      assert adapter =~ marker, "adapter is missing #{inspect(marker)}"
    end

    for marker <- [
          "host-binding failures deny before invoking the injected evaluator",
          "a serialized binding cannot revive a deleted session",
          "deny exactly at the idle boundary",
          "deny exactly at the absolute boundary",
          "only a complete host-owned binding can reach the evaluator",
          "a valid replacement account or session cannot replace the continuation binding",
          "approved hosted-return evidence cannot admit a route without a current session",
          "approved hosted-return evidence cannot revive expired, revoked, or switched host state",
          "released AuthReturn rejects every authority or credential smuggling field",
          "refute_receive :crosswake_evaluator_called"
        ] do
      assert adapter_test =~ marker, "adapter test is missing #{inspect(marker)}"
    end
  end

  test "recipe, coverage declaration, and adapter region preserve the authority boundary" do
    recipe = read!(@recipe)
    coverage = read!(@coverage)
    adapter = read!(@adapter)
    adapter_test = read!(@adapter_test)

    for marker <- [
          "`crosswake_sigra` `~> 0.1.3`",
          "`org_id: nil`",
          "cannot select a session",
          "cannot select a session, replace fresh host resolution, grant authority",
          "cd test/example && mix test test/example/accounts/crosswake_session_adapter_test.exs"
        ] do
      assert recipe =~ marker, "recipe is missing #{inspect(marker)}"
    end

    assert coverage =~ "`detected: false`"
    assert coverage =~ "Re-run trigger:"

    assert coverage =~
             "Crosswake network endpoint, SDK client, webhook, hosted API, or remote authentication"

    for forbidden <- [
          "default-org",
          "personal-org",
          "stored_digest",
          "provider_payload",
          "oauth_credential"
        ] do
      refute adapter =~ forbidden, "adapter must not introduce #{forbidden}"
    end

    refute Regex.match?(~r/\b(?:sleep|manual[ _-]?uat)\b/i, adapter)
    refute Regex.match?(~r/\b(?:sleep|manual[ _-]?uat)\b/i, adapter_test)
  end

  test "proof runner is bounded, failure-propagating, and writes receipt last" do
    runner = read!(@runner)

    for marker <- [
          "set -euo pipefail",
          "MIX_ENV=test mix test test/sigra/planning/phase_239_hosted_session_interop_test.exs",
          "mix test test/example/accounts/crosswake_session_adapter_test.exs",
          "perl -e",
          "write_evidence",
          "git -C \"${ROOT_DIR}\" rev-parse HEAD"
        ] do
      assert runner =~ marker, "runner is missing #{inspect(marker)}"
    end

    refute Regex.match?(~r/\b(?:sleep|watch|manual[ _-]?uat)\b/i, runner)
  end
end
