defmodule Sigra.CryptoTest do
  use ExUnit.Case, async: true

  alias Sigra.Crypto

  describe "hash_password/2" do
    test "produces an Argon2id hash" do
      hashed = Crypto.hash_password("password123!")

      assert is_binary(hashed)
      assert String.starts_with?(hashed, "$argon2id$")
    end

    test "produces different hashes for the same password (salted)" do
      hash1 = Crypto.hash_password("password123!")
      hash2 = Crypto.hash_password("password123!")

      refute hash1 == hash2
    end
  end

  describe "verify_password/3" do
    test "returns true for matching password" do
      hashed = Crypto.hash_password("password123!")

      assert Crypto.verify_password("password123!", hashed) == true
    end

    test "returns false for non-matching password" do
      hashed = Crypto.hash_password("password123!")

      assert Crypto.verify_password("wrong_password", hashed) == false
    end
  end

  describe "no_user_verify/1" do
    test "returns false" do
      result = Crypto.no_user_verify()

      assert result == false
    end

    test "does not return nil or :ok" do
      result = Crypto.no_user_verify()

      refute is_nil(result)
      refute result == :ok
    end
  end
end
