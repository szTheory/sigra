defmodule Sigra.Test.PhxNewArchiveTest do
  use ExUnit.Case, async: true

  alias Sigra.Test.PhxNewArchive

  test "an exact phx_new 1.8.8 archive is available" do
    assert PhxNewArchive.resolve({"* phx_new-1.8.8\n", 0}, false) == :available
  end

  test "a successful listing without the pinned archive is an explicit local skip" do
    assert {:skip, reason} = PhxNewArchive.resolve({"* phx_new-1.8.7\n", 0}, false)
    assert reason =~ "phx_new-1.8.8"
    assert reason =~ "mix archive.install"
  end

  test "a similarly named archive does not satisfy the pin" do
    assert {:skip, _reason} = PhxNewArchive.resolve({"* phx_new-1.8.80\n", 0}, false)
  end

  test "a required run errors when the pinned archive is missing" do
    assert {:error, reason} = PhxNewArchive.resolve({"* phx_new-1.8.7\n", 0}, true)
    assert reason =~ "SIGRA_CI_REQUIRED=1"
    assert reason =~ "phx_new-1.8.8"
  end

  test "a failed archive command preserves diagnostics and follows required policy" do
    command_result = {"** (Mix) The task archive.list could not be found\n", 1}

    assert {:skip, local_reason} = PhxNewArchive.resolve(command_result, false)
    assert local_reason =~ "command failed with exit status"
    assert local_reason =~ "archive.list"

    assert {:error, required_reason} = PhxNewArchive.resolve(command_result, true)
    assert required_reason =~ "SIGRA_CI_REQUIRED=1"
    assert required_reason =~ "archive.list"
  end
end
