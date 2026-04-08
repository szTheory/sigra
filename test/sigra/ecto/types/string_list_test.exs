defmodule Sigra.Ecto.Types.StringListTest do
  use ExUnit.Case, async: true

  alias Sigra.Ecto.Types.StringList

  describe "type/0" do
    test "returns :string" do
      assert StringList.type() == :string
    end
  end

  describe "cast/1" do
    test "casts a list of strings" do
      assert StringList.cast(["a", "b"]) == {:ok, ["a", "b"]}
    end

    test "casts a comma-separated string" do
      assert StringList.cast("a,b") == {:ok, ["a", "b"]}
    end

    test "casts a single-element string" do
      assert StringList.cast("a") == {:ok, ["a"]}
    end

    test "casts empty list" do
      assert StringList.cast([]) == {:ok, []}
    end

    test "returns error for non-string, non-list" do
      assert StringList.cast(123) == :error
    end

    test "returns error for nil" do
      assert StringList.cast(nil) == :error
    end

    test "trims empty entries from comma-separated string" do
      assert StringList.cast("a,,b") == {:ok, ["a", "b"]}
    end
  end

  describe "dump/1" do
    test "dumps list to comma-separated string" do
      assert StringList.dump(["a", "b"]) == {:ok, "a,b"}
    end

    test "dumps empty list to empty string" do
      assert StringList.dump([]) == {:ok, ""}
    end

    test "returns error for non-list" do
      assert StringList.dump("not a list") == :error
    end
  end

  describe "load/1" do
    test "loads comma-separated string to list" do
      assert StringList.load("a,b") == {:ok, ["a", "b"]}
    end

    test "loads nil as empty list" do
      assert StringList.load(nil) == {:ok, []}
    end

    test "loads empty string as empty list" do
      assert StringList.load("") == {:ok, []}
    end

    test "returns error for non-string, non-nil" do
      assert StringList.load(123) == :error
    end
  end
end
