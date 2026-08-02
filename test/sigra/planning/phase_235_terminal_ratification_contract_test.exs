defmodule Sigra.Planning.Phase235TerminalRatificationContractTest do
  use ExUnit.Case, async: true

  @ledger_path ".planning/phases/235-terminal-ratification-measured-not-read/235-TERMINAL-RATIFICATION.json"

  test "the terminal ratification ledger uses the versioned schema" do
    ledger = @ledger_path |> File.read!() |> Jason.decode!()

    assert ledger["schema_version"] == "sigra.terminal-ratification/v1"
  end
end
