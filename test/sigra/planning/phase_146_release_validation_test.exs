defmodule Sigra.Planning.Phase146ReleaseValidationTest do
  @moduledoc """
  Nyquist validation for Phase 146 release-gate and maintainer-runbook contracts.

  These tests keep the release workflow truth checks and canonical runbook routing
  from regressing after the phase summaries have been archived.
  """

  use ExUnit.Case, async: true

  defp root do
    Path.expand("../../..", __DIR__)
  end

  defp read!(rel) do
    root() |> Path.join(rel) |> File.read!()
  end

  test "146-01-01: CI remains dispatchable on release refs with canonical gate job ids" do
    ci = read!(".github/workflows/ci.yml")

    assert ci =~ ~r/^  workflow_dispatch:$/m
    assert ci =~ ~r/release-ref evidence path/i
    assert ci =~ ~s(gh workflow run "CI" --ref v1.32.0)
    assert ci =~ ~r/^  push:\n    branches: \[main\]/m
    assert ci =~ ~r/^  pull_request:\n    branches: \[main\]/m

    for job_id <-
          ~w(install_golden_contract library_tests library_tests_dep_off install_smoke example_http_smoke example_playwright_smoke generated_admin_playwright_smoke) do
      assert ci =~ ~r/^  #{Regex.escape(job_id)}:$/m
    end
  end

  test "146-01-02: publish workflows enforce version, package, dry-run, publish, and visibility gates" do
    release_please = read!(".github/workflows/release-please.yml")
    hex_publish = read!(".github/workflows/hex-publish.yml")
    post_publish_verify = read!("scripts/ci/release-post-publish-verify.sh")

    assert post_publish_verify =~ "release-post-publish-verify.sh --version <version> --tag <tag>"
    assert post_publish_verify =~ "https://hex.pm/api/packages/${PACKAGE}/releases/${VERSION}"
    assert post_publish_verify =~ "https://hexdocs.pm/${PACKAGE}/${VERSION}"
    assert post_publish_verify =~ "github.com/${REPOSITORY}/blob/${TAG}/"
    assert post_publish_verify =~ "hexdocs_source_link_points_to_main"

    for workflow <- [release_please, hex_publish] do
      assert workflow =~ "release-please-manifest"
      assert workflow =~ ~S(source_ref: "v#{@version}")
      assert workflow =~ "mix docs --warnings-as-errors"
      assert workflow =~ "mix hex.build --unpack --output sigra-hex-inspect"
      assert workflow =~ "test -f sigra-hex-inspect/README.md"
      assert workflow =~ "test -f sigra-hex-inspect/CHANGELOG.md"
      assert workflow =~ "test -f sigra-hex-inspect/mix.exs"
      assert workflow =~ "test -d sigra-hex-inspect/lib"
      assert workflow =~ "sigra-hex-inspect/.planning"
      assert workflow =~ "mix hex.publish --dry-run --yes"
      assert workflow =~ "mix hex.publish --yes"
      assert workflow =~ "Verify version on Hex.pm"
      assert workflow =~ "Verify HexDocs source links after publish"
      assert workflow =~ "scripts/ci/release-post-publish-verify.sh"
      assert workflow =~ "--evidence-file release-post-publish-evidence.json"
      assert workflow =~ "Upload release post-publish evidence"
      assert workflow =~ "release-post-publish-evidence-"
    end

    assert release_please =~ "Verify tag matches release version"
    assert release_please =~ ~r/tag_name.*version/s
    assert hex_publish =~ "Validate manual release inputs"
    assert hex_publish =~ "Verify manual ref provenance"
    assert hex_publish =~ "must be v<release_version> or commit SHA"
  end

  test "146-02-01: canonical runbook covers release gates, evidence, recovery, and hotfix policy" do
    runbook = read!("docs/release-runbook-v1-0.md")

    for heading <- [
          "## Release Gate Matrix",
          "## Release Evidence Checklist",
          "## Dry Run And Package Inspection",
          "## Publish Paths",
          "## Post-Publish Visibility",
          "## Recovery Decision Tree",
          "## First 14 Days Hotfix Policy",
          "## Post-1.32 Release Please Cleanup"
        ] do
      assert runbook =~ heading
    end

    for gate <-
          ~w(library_tests install_golden_contract install_smoke example_http_smoke example_playwright_smoke generated_admin_playwright_smoke library_tests_dep_off) do
      assert runbook =~ gate
    end

    assert runbook =~ "Release Please"
    assert runbook =~ "Hex publish (manual recovery)"

    assert runbook =~
             "Gate | Workflow/job or command | Release ref | Evidence URL or log | Reviewer | Waiver? | Notes"

    assert runbook =~ ~s(gh workflow run "CI" --ref v1.32.0)

    assert runbook =~
             ~S|gh workflow run "Hex publish (manual recovery)" -f tag=v1.32.0 -f release_version=1.32.0|

    assert runbook =~ "mix hex.build --unpack --output sigra-hex-inspect"
    assert runbook =~ "mix hex.publish --dry-run --yes"
    assert runbook =~
             "scripts/ci/release-post-publish-verify.sh --package sigra --version 1.32.0 --tag v1.32.0"

    assert runbook =~ "automated post-publish"
    assert runbook =~ "release-post-publish-evidence-1.32.0"
    refute runbook =~ "manual post-publish"
    assert runbook =~ ~S(source_ref: "v#{@version}")
    assert runbook =~ ~s(release-as: "1.32.0")
    assert runbook =~ "mix hex.publish --replace"
    assert runbook =~ "mix hex.publish --revert"
    assert runbook =~ "24 hours"
    assert runbook =~ "1 hour"

    for severity <- ~w(P0 P1 P2 P3) do
      assert runbook =~ severity
    end

    assert runbook =~ "same business day"
    assert runbook =~ "within 24 hours"
    assert runbook =~ "next planned patch window"
    assert runbook =~ "Deferred feature ideas remain out of scope"
  end

  test "146-02-02: maintainer router docs point to the runbook and avoid stale evidence routes" do
    maintaining = read!("MAINTAINING.md")
    next_steps = read!("docs/NEXT-STEPS-MANUAL.md")
    ga_evidence = read!("docs/ga-evidence.md")

    assert maintaining =~ "docs/release-runbook-v1-0.md"
    assert maintaining =~ "Keep this file as the maintainer entry-point index"
    assert next_steps =~ "docs/release-runbook-v1-0.md"
    assert next_steps =~ "Hex publish (manual recovery)"
    assert next_steps =~ "local trusted-machine publish fallback only"
    assert ga_evidence =~ "release-runbook-v1-0"
    assert ga_evidence =~ "uat-ci-coverage"
    assert ga_evidence =~ "pinned `v<version>` links"
    assert ga_evidence =~ "Do not use `main` blob URLs"

    refute ga_evidence =~ "v1.4 GA narrative"
    refute ga_evidence =~ "144-VERIFICATION.md"
    refute ga_evidence =~ "blob/main/.planning/phases/144"
  end
end
