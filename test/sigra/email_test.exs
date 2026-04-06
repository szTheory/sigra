defmodule Sigra.EmailTest do
  use ExUnit.Case, async: true

  alias Sigra.Email

  describe "normalize/1" do
    test "trims whitespace" do
      assert Email.normalize("  foo@bar.com  ") == "foo@bar.com"
    end

    test "downcases email" do
      assert Email.normalize("FOO@Bar.COM") == "foo@bar.com"
    end

    test "applies NFKC normalization" do
      # NFKC normalizes compatibility characters
      # U+2126 (OHM SIGN) normalizes to U+03A9 (GREEK CAPITAL LETTER OMEGA)
      # which then downcases to U+03C9 (omega)
      result = Email.normalize("user@\u2126.com")
      expected = String.normalize("user@\u2126.com", :nfkc) |> String.downcase()
      assert result == expected
    end

    test "preserves plus-addressing" do
      assert Email.normalize("user+tag@example.com") == "user+tag@example.com"
    end

    test "handles combined trim, downcase, and NFKC" do
      assert Email.normalize("  FOO@Bar.COM  ") == "foo@bar.com"
    end
  end

  describe "validate_format/1" do
    test "accepts valid email" do
      assert Email.validate_format("user@example.com") == :ok
    end

    test "accepts email with plus addressing" do
      assert Email.validate_format("user+tag@example.com") == :ok
    end

    test "accepts email with dots in local part" do
      assert Email.validate_format("first.last@example.com") == :ok
    end

    test "rejects string without @" do
      assert {:error, _reason} = Email.validate_format("no-at-sign")
    end

    test "rejects string with spaces" do
      assert {:error, _reason} = Email.validate_format("has spaces@x.com")
    end

    test "rejects empty string" do
      assert {:error, _reason} = Email.validate_format("")
    end

    test "rejects string over 160 chars" do
      long_local = String.duplicate("a", 150)
      long_email = "#{long_local}@example.com"
      assert {:error, _reason} = Email.validate_format(long_email)
    end

    test "accepts string exactly at 160 chars" do
      local = String.duplicate("a", 148)
      email = "#{local}@example.com"
      assert byte_size(email) == 160
      assert Email.validate_format(email) == :ok
    end

    test "rejects email with no local part" do
      assert {:error, _reason} = Email.validate_format("@example.com")
    end

    test "rejects email with no domain" do
      assert {:error, _reason} = Email.validate_format("user@")
    end
  end
end
