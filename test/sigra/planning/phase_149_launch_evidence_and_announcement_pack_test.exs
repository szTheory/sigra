defmodule Sigra.Planning.Phase149LaunchEvidenceAndAnnouncementPackTest do
  @moduledoc """
  Nyquist validation for Phase 149 launch evidence and announcement contracts.
  """

  use ExUnit.Case, async: true

  defp root do
    Path.expand("../../..", __DIR__)
  end

  defp read!(rel) do
    root() |> Path.join(rel) |> File.read!()
  end

  test "149-01: launch pack content stays bounded, version-clear, and attachable" do
    announcement = read!("docs/launch/v1.0/announcement.md")
    alternatives = read!("docs/launch/v1.0/alternatives.md")
    evidence = read!("docs/launch/v1.0/evidence.md")

    for heading <- [
          "## Problem framing",
          "## Why Sigra's hybrid model",
          "## Explicit non-goals",
          "## Proof links",
          "## Who should upgrade now",
          "## Who should wait"
        ] do
      assert announcement =~ heading
    end

    assert announcement =~ "Hex 1.0.0"
    refute announcement =~ "v1.32"

    for category <- ["phx.gen.auth", "Pow", "Guardian", "Ueberauth", "hosted auth", "Sigra's hybrid model"] do
      assert alternatives =~ category
    end

    assert alternatives =~ "## Comparison axes"
    assert alternatives =~ "## Ownership boundary table"
    assert alternatives =~ "## When not to choose Sigra"
    assert alternatives =~ "This comparison does not claim"

    for placeholder <- [
          "POST_PUBLISH_HEX_VISIBILITY_URL",
          "POST_PUBLISH_HEXDOCS_VERSION_URL",
          "POST_PUBLISH_GITHUB_RELEASE_URL",
          "POST_PUBLISH_RELEASE_REF_CI_URLS"
        ] do
      assert evidence =~ placeholder
    end

    assert evidence =~ "## What this does not prove"
    assert evidence =~ "main blob URLs"
    assert evidence =~ "generated-host local modifications"
  end

  test "149-02: public and AI routes converge on the canonical launch pack" do
    readme = read!("README.md")
    changelog = read!("CHANGELOG.md")
    mix_exs = read!("mix.exs")
    next_steps = read!("docs/NEXT-STEPS-MANUAL.md")
    llms = read!("doc/llms.txt")
    root_llms = read!("llms.txt")

    for path <- [
          "docs/launch/v1.0/announcement.md",
          "docs/launch/v1.0/alternatives.md",
          "docs/launch/v1.0/evidence.md"
        ] do
      assert mix_exs =~ ~s("#{path}")
    end

    assert mix_exs =~ "Docs: ~r{^docs/|^SECURITY\\.md$}"

    assert readme =~ "docs/launch/v1.0/announcement.md"
    assert readme =~ "docs/launch/v1.0/alternatives.md"
    assert readme =~ "docs/launch/v1.0/evidence.md"

    assert changelog =~ "docs/launch/v1.0/announcement.md"
    assert changelog =~ "Hex 1.0.0"
    refute changelog =~ "v1.32"

    assert next_steps =~ "docs/launch/v1.0/announcement.md"
    assert next_steps =~ "docs/launch/v1.0/evidence.md"

    for entry <- ["announcement.md", "alternatives.md", "evidence.md", "changelog.md", "security.md"] do
      assert llms =~ entry
    end

    assert root_llms =~ "doc/llms.txt"
    assert root_llms =~ "https://hexdocs.pm/sigra/llms.txt"
    refute root_llms =~ "## Pages"
  end

  test "149-03: threat boundaries reject overclaims and split AI vocabulary" do
    launch_docs =
      [
        read!("docs/launch/v1.0/announcement.md"),
        read!("docs/launch/v1.0/alternatives.md"),
        read!("docs/launch/v1.0/evidence.md")
      ]
      |> Enum.join("\n")

    root_llms = read!("llms.txt")
    script = read!("scripts/ci/launch-pack-contract.sh")

    for phrase <- [
          "automatic migration guarantee",
          "drop-in replacement",
          "hosted auth replacement",
          "provider certification included",
          "compliance certification included"
        ] do
      refute String.contains?(String.downcase(launch_docs), phrase)
      assert script =~ phrase
    end

    assert script =~ "scripts/ci/launch-pack-contract.sh"
    assert script =~ "launch-pack-contract"
    assert script =~ "announcement.md"
    assert script =~ "llms.txt"

    refute root_llms =~ "## Pages"
  end
end
