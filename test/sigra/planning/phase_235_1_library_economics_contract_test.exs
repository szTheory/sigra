defmodule Sigra.Planning.Phase2351LibraryEconomicsContractTest do
  use ExUnit.Case, async: false

  @receipt_path "/tmp/sigra-library-economics.json"

  setup do
    File.rm(@receipt_path)
    on_exit(fn -> File.rm(@receipt_path) end)
    :ok
  end

  test "production verifier accepts exact evidence and both equality boundaries" do
    assert_receipt_accepted!(valid_receipt(ordinary_ms: 2_000, install_ms: 1_000))
    assert_receipt_accepted!(valid_receipt(ordinary_ms: 1_000, install_ms: 1_000))
  end

  test "production verifier rejects every truth-bearing mutation and edge shape" do
    receipt = valid_receipt()

    mutations = [
      Map.delete(receipt, "schema_version"),
      Map.put(receipt, "unexpected", true),
      Map.put(receipt, "schema_version", "sigra.library-economics/v0"),
      Map.put(receipt, "timing_receipt_path", "/tmp/forged.json"),
      Map.put(receipt, "install_leg_ran", false),
      Map.put(receipt, "install_leg_ran", "true"),
      Map.put(receipt, "classes", %{}),
      put_in(receipt, ["classes", "install_scaffold"], nil),
      update_in(receipt, ["classes"], &Map.delete(&1, "install_scaffold")),
      put_in(receipt, ["classes", "forged"], receipt["classes"]["ordinary"]),
      put_in(receipt, ["classes", "ordinary", "duration_ms"], 0),
      put_in(receipt, ["classes", "ordinary", "duration_ms"], 1_001),
      put_in(receipt, ["classes", "ordinary", "start_ms"], -1),
      put_in(receipt, ["classes", "ordinary", "end_ms"], 1_000.5),
      put_in(receipt, ["classes", "ordinary", "conclusion"], "failure"),
      put_in(receipt, ["classes", "ordinary", "exit_status"], 1),
      put_in(receipt, ["classes", "ordinary", "verified"], true),
      put_in(receipt, ["classes", "install_scaffold", "duration_ms"], 2_001),
      put_in(receipt, ["classes", "install_scaffold", "end_ms"], 12_001),
      valid_receipt(ordinary_ms: 1_000, install_ms: 1_001)
    ]

    Enum.each(mutations, &assert_receipt_rejected!/1)
    assert_missing_receipt_rejected!()
    assert_raw_receipt_rejected!("")
    assert_raw_receipt_rejected!("null")
  end

  test "current contributor and workflow topology has one measured owner and two fail-closed receipts" do
    assert_current_topology!()
  end

  test "same ordinary run consumes the formatter and preserves deterministic unique timing evidence" do
    assert_formatter_contract!()
  end
end
