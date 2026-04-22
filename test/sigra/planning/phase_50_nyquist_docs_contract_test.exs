defmodule Sigra.Planning.Phase50NyquistDocsContractTest do
  @moduledoc """
  Nyquist validation for phase 50 documentation + CI wiring (no subprocess harness).

  Encodes the grep / structure checks from `.planning/phases/50-nyquist-ci-gate-hygiene/50-VALIDATION.md`.
  Full installer golden execution remains `mix ci.install_golden` / `install_golden_contract`.
  """

  use ExUnit.Case, async: true

  @re_validation ~r/nyquist_compliant:|phase 50|waiver/

  defp root do
    Path.expand("../../..", __DIR__)
  end

  defp read!(rel) do
    root() |> Path.join(rel) |> File.read!()
  end

  test "50-01-01 .. 50-01-04: 41-44 VALIDATION files still carry Nyquist honesty markers" do
    for rel <-
          ~w(.planning/phases/41-backup-codes-ga-product-closure/41-VALIDATION.md
             .planning/phases/42-human-ga-matrix-evidence/42-VALIDATION.md
             .planning/phases/43-audit-inventory-auth-atomic-batch/43-VALIDATION.md
             .planning/phases/44-mfa-account-api-atomic-batches/44-VALIDATION.md) do
      body = read!(rel)

      assert Regex.match?(@re_validation, body),
             "expected #{rel} to match nyquist_compliant:|phase 50|waiver (see 50-VALIDATION.md 50-01-0x)"
    end
  end

  test "50-01-05: MAINTAINING Nyquist policy section cites phases 41 and 44 paths" do
    md = read!("MAINTAINING.md")
    assert md =~ "## Nyquist policy (phases 41-44)"
    assert md =~ "41-backup-codes"
    assert md =~ "44-mfa-account-api"
  end

  test "50-02-01: ci.install_golden alias and workflow cite both install harness modules" do
    aliases = Keyword.fetch!(Mix.Project.config(), :aliases)
    cmd = aliases |> Keyword.fetch!(:"ci.install_golden") |> List.first()

    assert cmd =~ "test/sigra/install/golden_diff_test.exs"
    assert cmd =~ "test/sigra/install/idempotency_test.exs"

    yml = read!(".github/workflows/ci.yml")
    assert yml =~ "install_golden_contract:"
    assert yml =~ "golden_diff_test.exs"
    assert yml =~ "idempotency_test.exs"
    assert yml =~ "postgres:15"
  end

  test "50-02-02: MAINTAINING documents golden / install contract wall-clock class" do
    md = read!("MAINTAINING.md")
    assert Regex.match?(~r/golden_diff|install_golden|300_000/, md)
  end

  test "50-02 plan: 41-VALIDATION cites mix ci.install_golden contract post phase 50" do
    body = read!(".planning/phases/41-backup-codes-ga-product-closure/41-VALIDATION.md")
    assert body =~ "ci.install_golden"
  end

  test "50-02 plan: 42-VALIDATION waiver points at v1.4-GA-UAT and stays nyquist_compliant false" do
    body = read!(".planning/phases/42-human-ga-matrix-evidence/42-VALIDATION.md")
    assert body =~ "v1.4-GA-UAT"
    assert body =~ ~r/GA-02|human/i
    assert body =~ ~r/^nyquist_compliant: false/m
  end

  test "50-02 plan: 43/44 VALIDATION cite MAINTAINING closure and scoped VERIFICATION paths" do
    p43 = read!(".planning/phases/43-audit-inventory-auth-atomic-batch/43-VALIDATION.md")
    p44 = read!(".planning/phases/44-mfa-account-api-atomic-batches/44-VALIDATION.md")

    assert p43 =~ "MAINTAINING"
    assert p44 =~ "MAINTAINING"
    assert p43 =~ "43-VERIFICATION"
    assert p44 =~ "44-VERIFICATION"
  end

  test "50-02 plan: 50-VERIFICATION merge gate receipt vs passed posture" do
    body = read!(".planning/phases/50-nyquist-ci-gate-hygiene/50-VERIFICATION.md")
    assert body =~ "mix ci.install_golden"
    assert body =~ "git rev-parse HEAD"

    if body =~ ~r/^status: passed/m do
      assert body =~ "PASS"
    else
      assert body =~ ~r/^status: draft/m
    end
  end
end
