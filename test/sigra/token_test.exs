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

  describe "generate_invite_envelope/2 + verify_invite_envelope/3" do
    @invite_purpose "sigra-org-invite-token"

    test "round-trips to {:ok, %{raw_token, bound_email, hashed_token}}" do
      {encoded, hashed} = Token.generate_invite_envelope(@secret, "user@example.com")

      assert is_binary(encoded)
      assert byte_size(hashed) == 32

      assert {:ok, %{raw_token: raw, bound_email: "user@example.com", hashed_token: got_hashed}} =
               Token.verify_invite_envelope(@secret, encoded, 3600)

      assert is_binary(raw)
      assert got_hashed == hashed
    end

    test "downcases bound email on generate" do
      {encoded, _} = Token.generate_invite_envelope(@secret, "USER@EXAMPLE.COM")

      assert {:ok, %{bound_email: "user@example.com"}} =
               Token.verify_invite_envelope(@secret, encoded, 3600)
    end

    test "rejects tampered payload with :invalid" do
      {encoded, _} = Token.generate_invite_envelope(@secret, "user@example.com")

      {:ok, signed} = Base.url_decode64(encoded, padding: false)
      mid = div(byte_size(signed), 2)
      <<prefix::binary-size(mid), byte, suffix::binary>> = signed
      tampered_signed = <<prefix::binary, Bitwise.bxor(byte, 0x01)::8, suffix::binary>>
      tampered = Base.url_encode64(tampered_signed, padding: false)

      assert {:error, :invalid} = Token.verify_invite_envelope(@secret, tampered, 3600)
    end

    test "rejects wrong purpose with :invalid" do
      {raw, _hashed} = Token.generate_hashed_token()
      payload = %{"t" => raw, "e" => "user@example.com"}
      signed = Plug.Crypto.sign(@secret, "wrong-purpose", payload)
      encoded = Base.url_encode64(signed, padding: false)

      assert {:error, :invalid} = Token.verify_invite_envelope(@secret, encoded, 3600)
    end

    test "returns :expired when max_age exceeded" do
      {encoded, _} = Token.generate_invite_envelope(@secret, "user@example.com")
      # Sleep ~1s and verify with max_age: 0 which is immediate expiry per Plug.Crypto
      Process.sleep(1100)

      assert {:error, :expired} = Token.verify_invite_envelope(@secret, encoded, 1)
    end

    test "returns :invalid for base64 garbage" do
      assert {:error, :invalid} =
               Token.verify_invite_envelope(@secret, "not-valid-base64!!!", 3600)
    end

    test "returns :invalid for wrong payload shape" do
      # Sign a raw binary (not a string-keyed map) with the correct purpose
      signed = Plug.Crypto.sign(@secret, @invite_purpose, "just-a-bare-binary")
      encoded = Base.url_encode64(signed, padding: false)

      assert {:error, :invalid} = Token.verify_invite_envelope(@secret, encoded, 3600)
    end

    test "decoded payload uses only string keys (atom-flood defense)" do
      {encoded, _} = Token.generate_invite_envelope(@secret, "user@example.com")

      assert {:ok, %{raw_token: raw, bound_email: email}} =
               Token.verify_invite_envelope(@secret, encoded, 3600)

      assert is_binary(raw)
      assert is_binary(email)
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
