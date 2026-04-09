defmodule Sigra.Audit.CursorTest do
  use ExUnit.Case, async: true

  # Wave 0 scaffold. Sigra.Audit.Cursor lands in Plan 02.

  alias Sigra.Audit.Cursor

  describe "encode/decode roundtrip" do
    test "roundtrips a known (DateTime, UUID) pair" do
      dt = DateTime.from_unix!(1_712_665_200_123_456, :microsecond)
      id = "01234567-89ab-cdef-0123-456789abcdef"

      cursor = Cursor.encode(dt, id)
      assert is_binary(cursor)
      assert {:ok, {decoded_dt, decoded_id}} = Cursor.decode(cursor)
      assert DateTime.compare(decoded_dt, dt) == :eq
      assert decoded_id == id
    end
  end

  describe "decode error handling" do
    test "rejects garbage" do
      assert {:error, :invalid_cursor} = Cursor.decode("not-base64!!!")
    end

    test "rejects empty string" do
      assert {:error, :invalid_cursor} = Cursor.decode("")
    end

    test "rejects nil" do
      assert {:error, :invalid_cursor} = Cursor.decode(nil)
    end
  end
end
