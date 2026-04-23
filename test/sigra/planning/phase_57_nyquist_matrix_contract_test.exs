defmodule Sigra.Planning.Phase57NyquistMatrixContractTest do
  @moduledoc """
  Structural contract for phase **57** Nyquist posture matrix (verify, don't rewrite).

  Anchors the canonical **`.planning/nyquist-phases-41-44-matrix.md`** file and the
  **`MAINTAINING.md`** link + heading required by **57-02-PLAN** / **D-11**.
  """

  use ExUnit.Case, async: true

  defp root do
    Path.expand("../../..", __DIR__)
  end

  defp read!(rel) do
    root() |> Path.join(rel) |> File.read!()
  end

  test "57-01: canonical matrix exists and lists all four GA slugs with UNCHANGED disposition" do
    body = read!(".planning/nyquist-phases-41-44-matrix.md")

    for slug <-
          ~w(41-backup-codes-ga-product-closure
             42-human-ga-matrix-evidence
             43-audit-inventory-auth-atomic-batch
             44-mfa-account-api-atomic-batches) do
      assert body =~ slug, "expected matrix to mention #{slug}"
    end

    assert body =~ "UNCHANGED"
  end

  test "57-01: MAINTAINING links to matrix and keeps Nyquist policy heading" do
    md = read!("MAINTAINING.md")
    assert md =~ "## Nyquist policy (phases 41-44)"
    assert md =~ ".planning/nyquist-phases-41-44-matrix.md"
  end
end
