defmodule Sigra.MFA.TrustTest do
  use ExUnit.Case, async: true

  alias Sigra.MFA.Trust

  @secret_key_base String.duplicate("a", 64)
  @trust_ttl 2_592_000

  describe "sign/4" do
    test "returns a binary cookie value" do
      cookie = Trust.sign(@secret_key_base, 42, 0, @trust_ttl)

      assert is_binary(cookie)
      assert byte_size(cookie) > 0
    end
  end

  describe "verify/5" do
    test "returns {:ok, user_id} for valid cookie with matching epoch" do
      cookie = Trust.sign(@secret_key_base, 42, 1, @trust_ttl)

      assert {:ok, 42} = Trust.verify(@secret_key_base, cookie, 42, 1, @trust_ttl)
    end

    test "returns {:error, :invalid} for wrong epoch (revoked)" do
      cookie = Trust.sign(@secret_key_base, 42, 1, @trust_ttl)

      # Epoch incremented (revoked)
      assert {:error, :invalid} = Trust.verify(@secret_key_base, cookie, 42, 2, @trust_ttl)
    end

    test "returns {:error, :invalid} for expired cookie" do
      # Sign with very short TTL
      cookie = Trust.sign(@secret_key_base, 42, 0, 0)

      # Wait briefly (cookie already expired with TTL=0)
      Process.sleep(10)

      assert {:error, :invalid} = Trust.verify(@secret_key_base, cookie, 42, 0, 0)
    end

    test "returns {:error, :invalid} for different user_id" do
      cookie = Trust.sign(@secret_key_base, 42, 0, @trust_ttl)

      # Verify with different user_id
      assert {:error, :invalid} = Trust.verify(@secret_key_base, cookie, 99, 0, @trust_ttl)
    end

    test "returns {:error, :invalid} for tampered cookie" do
      assert {:error, :invalid} = Trust.verify(@secret_key_base, "tampered", 42, 0, @trust_ttl)
    end

    test "returns {:error, :invalid} for different secret_key_base" do
      cookie = Trust.sign(@secret_key_base, 42, 0, @trust_ttl)
      other_secret = String.duplicate("b", 64)

      assert {:error, :invalid} = Trust.verify(other_secret, cookie, 42, 0, @trust_ttl)
    end
  end

  describe "cookie_name/0" do
    test "returns the cookie name constant" do
      assert Trust.cookie_name() == "_sigra_mfa_trust"
    end
  end

  describe "cookie_opts/1" do
    test "returns secure cookie options for a nil cookie_domain" do
      opts = Trust.cookie_opts(%Sigra.Config{cookie_domain: nil})

      assert opts[:http_only] == true
      assert opts[:secure] == true
      assert opts[:same_site] == "Lax"
      refute Keyword.has_key?(opts, :domain)
    end
  end

  describe "cookie_opts/0 (removed)" do
    test "raises with a migration message" do
      assert_raise RuntimeError, ~r/cookie_opts\/0 was removed/, fn ->
        apply(Trust, :cookie_opts, [])
      end
    end
  end
end
