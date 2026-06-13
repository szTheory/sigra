defmodule Sigra.AdminTest do
  use ExUnit.Case, async: true

  alias Sigra.Admin

  describe "needs_review/1" do
    test "sums locked and deleted counts when both keys are present" do
      counts = %{locked: 3, deleted: 4}

      assert Admin.needs_review(counts) == 7
    end

    test "sums new posture keys when summary_stats are used" do
      counts = %{locked_out: 3, deletion_scheduled: 4}

      assert Admin.needs_review(counts) == 7
    end

    test "returns the locked count when deleted key is absent" do
      counts = %{locked: 5}

      assert Admin.needs_review(counts) == 5
    end

    test "returns the deleted count when locked key is absent" do
      counts = %{deleted: 2}

      assert Admin.needs_review(counts) == 2
    end

    test "returns 0 when neither locked nor deleted key is present" do
      counts = %{confirmed: 9, mfa: 4}

      assert Admin.needs_review(counts) == 0
    end

    test "returns 0 for an empty map" do
      assert Admin.needs_review(%{}) == 0
    end
  end
end
