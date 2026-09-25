defmodule Sigra.Planning.Phase242ShiftLeftContractTest do
  use ExUnit.Case, async: true

  @public_install_files [
    "README.md",
    "guides/introduction/installation.md",
    "guides/introduction/getting-started.md",
    "guides/introduction/first-hour.md",
    "guides/recipes/companion-libs/accrue.md",
    "guides/recipes/companion-libs/lockspire.md",
    "guides/recipes/companion-libs/mailglass.md",
    "guides/recipes/companion-libs/relyra.md",
    "guides/recipes/companion-libs/rulestead.md",
    "guides/recipes/companion-libs/threadline.md"
  ]

  @halt_summaries %{
    "242-03-SUMMARY.md" => "f9659699640d7f145a46289b17da6313d6c30158eb47424e40609bd5febaab97",
    "242-10-SUMMARY.md" => "4046bad1b171594760ec8faf0d9439829bc4fca34c41a9c38c753637fa4b08fc",
    "242-12-SUMMARY.md" => "035979fd2e6db7b058f42c5f0a3dabf797009e7b8137d2aa02f0c005a1a96187"
  }

  defp root, do: Path.expand("../../..", __DIR__)

  test "public install snippets use the bounded maintained line" do
    Enum.each(@public_install_files, fn relative_path ->
      content = root() |> Path.join(relative_path) |> File.read!()

      assert content =~ "{:sigra, \"~> 1.5.0\"}", "#{relative_path} lacks the supported tuple"
      refute content =~ "{:sigra, \"~> 1.4.0\"}", "#{relative_path} retains the stale tuple"
    end)
  end

  test "retired Hex mutation automation cannot be dispatched from this repository" do
    refute File.exists?(Path.join(root(), ".github/workflows/hex-remediate-phantom.yml"))
    refute File.exists?(Path.join(root(), "scripts/ci/prohibitions/p22-hex-remediation.test.mjs"))
  end

  test "safety closeout preserves raw halt evidence and makes no external success claim" do
    phase_dir = Path.join(root(), ".planning/phases/242-hex-retire-docs-revert-pinned-install-adr-cut-1-5-1")
    closeout = phase_dir |> Path.join("242-SAFETY-CLOSEOUT.md") |> File.read!()
    requirements = root() |> Path.join(".planning/REQUIREMENTS.md") |> File.read!()

    Enum.each(@halt_summaries, fn {filename, expected_hash} ->
      summary = phase_dir |> Path.join(filename) |> File.read!()
      actual_hash = :crypto.hash(:sha256, summary) |> Base.encode16(case: :lower)

      assert actual_hash == expected_hash, "#{filename} no longer matches its recorded halt evidence"
      assert closeout =~ expected_hash, "closeout does not link #{filename}'s raw evidence hash"
    end)

    assert closeout =~ "remain unproven"
    assert closeout =~ "fresh explicit authorization"
    assert requirements =~ "REL-03, REL-04, and REL-06 are superseded-not-satisfied"
    assert requirements =~ "REL-05 is limited to the delivered source safeguard"
  end
end
