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
end
