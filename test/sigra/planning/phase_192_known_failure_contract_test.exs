defmodule Sigra.Planning.Phase192KnownFailureContractTest do
  @moduledoc """
  Self-healing contract: if any quarantined known failure starts passing,
  remove its tag and resolve the tracking todo. This test fails CI if a tracked
  quarantine tag is removed without retiring its assertion here, forcing cleanup.

  Phase 192 originally quarantined three known failures. Two were resolved on
  2026-06-18 and their assertions retired (see below); one remains:
    1. (RESOLVED 2026-06-18, quick task 260618-gdf) golden_diff_test.exs — was a
       local phx_new 1.8.8 vs CI-pinned 1.8.7 env drift, not a stale fixture.
    2. (RESOLVED 2026-06-18, quick task 260618-fch) vault_promotion_test.exs —
       installer templates emitted `<.button type=...>`; the `type` attr is now
       stripped and the test passes.
    3. test/example/priv/playwright/tests/admin-design.spec.ts MG-5/6 — data-dependent
       pagination (still quarantined; tracked todo still pending). Phase 197 (D-11b,
       f174d84d) migrated the quarantine marker from `test.fail()` to `test.skip(...)`
       with a recorded reason; this contract now locks the `test.skip(` marker.

  Modeled on test/sigra/planning/phase_51_install_golden_ci_contract_test.exs.
  """

  use ExUnit.Case, async: true

  defp root do
    Path.expand("../../..", __DIR__)
  end

  defp read!(rel) do
    root() |> Path.join(rel) |> File.read!()
  end

  test "192-KF-03: admin-design.spec.ts MG-5/6 test has test.skip() quarantine marker" do
    content = read!("test/example/priv/playwright/tests/admin-design.spec.ts")

    mg56_block =
      content
      |> String.split("MG-5 and MG-6 desktop and mobile representations are content-equivalent")
      |> List.last()

    assert mg56_block =~ "test.skip(",
           "admin-design.spec.ts MG-5/6 test is missing its test.skip(...) quarantine marker — " <>
             "if the test is now passing, remove the marker and resolve " <>
             ".planning/todos/pending/2026-06-17-admin-design-mg5-6-content-equivalence-data-dependent.md"
  end
end
