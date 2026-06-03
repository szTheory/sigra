defmodule Sigra.Planning.Phase147UpgradeMigrationLanesTest do
  @moduledoc """
  Nyquist validation for Phase 147 upgrade and migration lane contracts.

  These tests lock the fast structural proof around the slower upgrade smoke
  lane and the public docs/evidence routes that explain migration boundaries.
  """

  use ExUnit.Case, async: true

  defp root do
    Path.expand("../../..", __DIR__)
  end

  defp read!(rel) do
    root() |> Path.join(rel) |> File.read!()
  end

  test "147-01: upgrade smoke lane remains distinct and proves published-source to local-candidate posture" do
    ci = read!(".github/workflows/ci.yml")
    script = read!("scripts/ci/upgrade-smoke.sh")

    assert ci =~ ~r/^  install_smoke:$/m
    assert ci =~ ~r/^  upgrade_smoke:$/m
    assert ci =~ "Upgrade smoke (published source series -> local candidate)"
    assert ci =~ "needs: release_ref_guard"
    assert ci =~ "run: scripts/ci/upgrade-smoke.sh"

    assert script =~ ~S(SOURCE_SERIES="${SIGRA_UPGRADE_SOURCE_SERIES:-1}")
    assert script =~ "SIGRA_UPGRADE_SMOKE_START_VERSION"
    assert script =~ "resolve_latest_sigra_source"
    assert script =~ "mix sigra.install --yes Accounts User users"
    assert script =~ "mix sigra.upgrade --allow-dirty --yes"
    assert script =~ "mix compile --warnings-as-errors"
    assert script =~ "mix ecto.migrate"
    assert script =~ "find_free_port"
    assert script =~ "http://127.0.0.1:${PORT}/users/log_in"
  end

  test "147-02 and 147-03: upgrade and migration guides publish through README, changelog, and ExDoc" do
    readme = read!("README.md")
    changelog = read!("CHANGELOG.md")
    mix_exs = read!("mix.exs")

    upgrade = read!("guides/introduction/upgrading-to-v1.0.md")
    phx = read!("guides/introduction/migrating-from-phx-gen-auth.md")
    ecosystem = read!("guides/introduction/migrating-from-pow-guardian-ueberauth.md")

    assert readme =~ "pre-1.0 -> v1.0"
    assert readme =~ "Migration lanes"
    assert readme =~ "guides/introduction/migrating-from-phx-gen-auth.md"
    assert readme =~ "guides/introduction/migrating-from-pow-guardian-ueberauth.md"

    for path <- [
          "guides/introduction/upgrading-to-v1.0.md",
          "guides/introduction/migrating-from-phx-gen-auth.md",
          "guides/introduction/migrating-from-pow-guardian-ueberauth.md"
        ] do
      assert changelog =~ path
      assert mix_exs =~ ~s("#{path}")
    end

    assert mix_exs =~ "Introduction: ~r{guides/introduction/.?}"

    assert upgrade =~ "SIGRA_UPGRADE_SOURCE_SERIES=0.3"
    assert upgrade =~ "mix sigra.upgrade --yes"
    assert upgrade =~ "mix test test/upgrade_test.exs -x"
    assert upgrade =~ "bash scripts/ci/upgrade-smoke.sh"
    assert upgrade =~ "Rollback notes"

    assert phx =~ "Who should migrate now"
    assert phx =~ "Who should not migrate yet"
    assert phx =~ "current_scope"
    assert phx =~ "magic links"
    assert phx =~ "sudo mode"
    assert phx =~ "Rollback posture"

    assert ecosystem =~ "Pow"
    assert ecosystem =~ "Guardian"
    assert ecosystem =~ "Ueberauth"
    assert ecosystem =~ "Assent"
    assert ecosystem =~ "Cutover patterns"
    assert ecosystem =~ "Ownership boundary table"
    assert ecosystem =~ "Non-goals"
    assert ecosystem =~ "compatibility shims"
  end

  test "147-04: release evidence separates machine upgrade proof from editorial migration review" do
    runbook = read!("docs/release-runbook-v1-0.md")
    coverage = read!("docs/uat-ci-coverage.md")
    evidence = read!("docs/ga-evidence.md")

    assert runbook =~
             "| Upgrade smoke | `CI` / `upgrade_smoke` | release tag | `Gate=upgrade_smoke`, run URL/log, pass status | Same waiver fields required |"

    assert runbook =~ "| upgrade_smoke | `CI` / `upgrade_smoke` | `v1.0.0` |"

    assert coverage =~ "## v1.0 upgrade and migration proof"
    assert coverage =~ "UPGRADE-02 (machine-closed)"
    assert coverage =~ "`CI` / `upgrade_smoke`"
    assert coverage =~ "scripts/ci/upgrade-smoke.sh"
    assert coverage =~ "UPGRADE-01, MIGRATE-01, MIGRATE-02 (published-doc truths)"
    assert coverage =~ "Residual human review boundary"
    assert coverage =~ "does not claim executable migration cutover automation"

    assert evidence =~ "## Upgrade and migration proof"
    assert evidence =~ "[Upgrading to v1.0](upgrading-to-v1.0.html)"
    assert evidence =~ "[Migrating from phx.gen.auth](migrating-from-phx-gen-auth.html)"

    assert evidence =~
             "[Migrating from Pow, Guardian, and Ueberauth](migrating-from-pow-guardian-ueberauth.html)"

    assert evidence =~ "`CI` / `upgrade_smoke` plus `scripts/ci/upgrade-smoke.sh`"
    refute evidence =~ "## Release Gate Matrix"
  end
end
