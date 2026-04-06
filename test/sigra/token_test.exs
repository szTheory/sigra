defmodule Sigra.TokenTest do
  use ExUnit.Case, async: true

  alias Sigra.Token

  @secret String.duplicate("a", 64)

  describe "generate/4 and verify/4" do
    test "round-trips with correct data" do
      token = Token.generate(@secret, "session", 42)

      assert {:ok, 42} = Token.verify(@secret, "session", token, max_age: 86400)
    end

    test "generates a non-empty binary" do
      token = Token.generate(@secret, "session", 1)

      assert is_binary(token)
      assert byte_size(token) > 0
    end

    test "returns error for wrong secret" do
      token = Token.generate(@secret, "session", 42)
      wrong_secret = String.duplicate("b", 64)

      assert {:error, :invalid} = Token.verify(wrong_secret, "session", token, max_age: 86400)
    end

    test "returns error for wrong purpose" do
      token = Token.generate(@secret, "session", 42)

      assert {:error, :invalid} = Token.verify(@secret, "email", token, max_age: 86400)
    end

    test "returns error for garbage token" do
      assert {:error, :invalid} = Token.verify(@secret, "session", "garbage", max_age: 86400)
    end

    test "returns error for expired token" do
      token = Token.generate(@secret, "session", 42, signed_at: System.system_time(:second) - 10)

      assert {:error, :expired} = Token.verify(@secret, "session", token, max_age: 1)
    end
  end

  describe "generate_hashed_token/0" do
    test "returns {raw_string, 32-byte-binary} tuple" do
      {raw, hashed} = Token.generate_hashed_token()

      assert is_binary(raw)
      assert byte_size(hashed) == 32
    end

    test "raw token is URL-safe base64" do
      {raw, _hashed} = Token.generate_hashed_token()

      # URL-safe base64 should decode without error
      assert {:ok, decoded} = Base.url_decode64(raw, padding: false)
      assert byte_size(decoded) == 32
    end

    test "hashed is SHA-256 of raw" do
      {raw, hashed} = Token.generate_hashed_token()

      {:ok, decoded} = Base.url_decode64(raw, padding: false)
      assert :crypto.hash(:sha256, decoded) == hashed
    end

    test "generates different tokens each call" do
      {raw1, _} = Token.generate_hashed_token()
      {raw2, _} = Token.generate_hashed_token()

      refute raw1 == raw2
    end
  end

  describe "hash_token/1" do
    test "returns a 32-byte SHA-256 hash" do
      hashed = Token.hash_token("some-raw-token")

      assert byte_size(hashed) == 32
    end

    test "is deterministic" do
      hash1 = Token.hash_token("same-token")
      hash2 = Token.hash_token("same-token")

      assert hash1 == hash2
    end
  end

  describe "secure_compare/2" do
    test "returns true for equal strings" do
      assert Token.secure_compare("abc", "abc") == true
    end

    test "returns false for unequal strings" do
      assert Token.secure_compare("abc", "def") == false
    end

    test "returns false for different lengths" do
      assert Token.secure_compare("abc", "abcd") == false
    end
  end
end
