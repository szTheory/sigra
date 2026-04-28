defmodule Sigra.Planning.Phase52MilestoneHonestyContractTest do
  @moduledoc """
  Encodes 52-VALIDATION / 52-RESEARCH ROADMAP honesty checks for v1.4 milestone presentation.
  """

  use ExUnit.Case, async: true

  defp root do
    Path.expand("../../..", __DIR__)
  end

  defp read!(rel) do
    root() |> Path.join(rel) |> File.read!()
  end

  test "ROADMAP: v1.4 shipped and defers detail table to archive" do
    md = read!(".planning/ROADMAP.md")

    assert md =~ "v1.4 GA readiness"
    assert md =~ "shipped **2026-04-22**"
    assert md =~ "milestones/v1.4-ROADMAP.md"
  end

  test "archived v1.4 ROADMAP retains reader note and completed 44/45 rows" do
    md = read!(".planning/milestones/v1.4-ROADMAP.md")

    assert md =~ "## Reader note (AUD closure)"
    assert md =~ "| **44** ✅ (2026-04-21) |"
    assert md =~ "| **45** ✅ (2026-04-21) |"
  end

  test "verification files exist for phases 43–45" do
    for rel <-
          ~w(.planning/phases/43-audit-inventory-auth-atomic-batch/43-VERIFICATION.md
             .planning/phases/44-mfa-account-api-atomic-batches/44-VERIFICATION.md
             .planning/phases/45-oauth-ops-c1-signoff/45-VERIFICATION.md) do
      path = Path.join(root(), rel)
      assert File.exists?(path), "expected #{rel} to exist"
    end
  end

  test "milestone audit disposition heading present" do
    md = read!(".planning/milestones/v1.4-MILESTONE-AUDIT.md")
    assert md =~ "## Tech debt disposition (phase 52)"
  end
end
