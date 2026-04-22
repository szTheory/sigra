defmodule Sigra.Planning.Phase51InstallGoldenCiContractTest do
  @moduledoc """
  Structural lock: the extended installer PR path `grep -qE` pattern in
  `.github/workflows/ci.yml` must stay identical in both
  `installer_milestone_audit` and `install_golden_contract` (phase 51).
  """

  use ExUnit.Case, async: true

  @path_detector_regex "^priv/templates/sigra\\.install/|^lib/sigra/install/|^lib/sigra/mfa(\\.ex|/)|^lib/sigra/oauth(\\.ex|/)|^lib/sigra/account(\\.ex|/)|^lib/sigra/passkeys(\\.ex|/)"

  defp root do
    Path.expand("../../..", __DIR__)
  end

  defp read!(rel) do
    root() |> Path.join(rel) |> File.read!()
  end

  test "51-01: installer PR path detector extended and duplicated across both jobs" do
    yml = read!(".github/workflows/ci.yml")
    escaped = Regex.escape(@path_detector_regex)

    assert length(Regex.scan(~r/#{escaped}/, yml)) == 2,
           "expected the canonical path detector substring exactly twice (both CI jobs)"

    assert yml =~ "install_golden_contract:"
    assert yml =~ "installer_milestone_audit:"
  end

  test "51-02: GA waiver docs tie waived rows to installer golden attestation" do
    maintaining = read!("MAINTAINING.md")
    ga_uat = read!(".planning/v1.4-GA-UAT.md")

    assert maintaining =~ "v1.4-GA-UAT.md"
    assert maintaining =~ "50-VERIFICATION.md"
    assert maintaining =~ "install_golden_contract"
    assert maintaining =~ "mix ci.install_golden"

    assert ga_uat =~ "50-VERIFICATION.md"
    assert ga_uat =~ "install_golden_contract"
    assert ga_uat =~ "mix ci.install_golden"
  end
end
