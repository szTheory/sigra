defmodule Sigra.Planning.Phase192KnownFailureContractTest do
  @moduledoc """
  Self-healing contract: if any quarantined known failure starts passing,
  remove its tag and resolve the tracking todo. This test goes green (fails CI)
  if any quarantine tag is removed, forcing cleanup.

  The three quarantined known failures for Phase 192 are:
    1. test/sigra/install/golden_diff_test.exs — generated-tree byte diff vs committed fixture
    2. test/sigra/install/vault_promotion_test.exs — undefined attribute for CoreComponents.button/1
    3. test/example/priv/playwright/tests/admin-design.spec.ts MG-5/6 — data-dependent pagination

  Modeled on test/sigra/planning/phase_51_install_golden_ci_contract_test.exs.
  """

  use ExUnit.Case, async: true

  defp root do
    Path.expand("../../..", __DIR__)
  end

  defp read!(rel) do
    root() |> Path.join(rel) |> File.read!()
  end

  test "192-KF-01: golden_diff_test.exs has @moduletag known_failure quarantine tag" do
    content = read!("test/sigra/install/golden_diff_test.exs")

    assert content =~ "@moduletag known_failure:",
           "golden_diff_test.exs is missing its @moduletag known_failure tag — " <>
             "if the test is now passing, remove the tag and resolve " <>
             ".planning/todos/pending/2026-06-18-install-golden-diff-known-failure.md"
  end

  test "192-KF-02: vault_promotion_test.exs has @moduletag known_failure quarantine tag" do
    content = read!("test/sigra/install/vault_promotion_test.exs")

    assert content =~ "@moduletag known_failure:",
           "vault_promotion_test.exs is missing its @moduletag known_failure tag — " <>
             "if the test is now passing, remove the tag and resolve " <>
             ".planning/todos/pending/2026-06-18-install-vault-promotion-known-failure.md"
  end

  test "192-KF-03: admin-design.spec.ts MG-5/6 test has test.fail() quarantine marker" do
    content = read!("test/example/priv/playwright/tests/admin-design.spec.ts")

    mg56_block =
      content
      |> String.split("MG-5 and MG-6 desktop and mobile representations are content-equivalent")
      |> List.last()

    assert mg56_block =~ "test.fail()",
           "admin-design.spec.ts MG-5/6 test is missing test.fail() — " <>
             "if the test is now passing, remove the marker and resolve " <>
             ".planning/todos/pending/2026-06-17-admin-design-mg5-6-content-equivalence-data-dependent.md"
  end
end
