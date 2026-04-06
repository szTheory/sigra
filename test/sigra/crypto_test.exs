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

  describe "verify_with_upgrade/2" do
    test "returns {:ok, :valid} for correct password with current argon2id hash" do
      hashed = Crypto.hash_password("mysecurepassword")

      assert {:ok, :valid} = Crypto.verify_with_upgrade("mysecurepassword", hashed)
    end

    test "returns {:error, :invalid} for wrong password with argon2id hash" do
      hashed = Crypto.hash_password("mysecurepassword")

      assert {:error, :invalid} = Crypto.verify_with_upgrade("wrongpassword", hashed)
    end

    test "returns {:error, :invalid} for nil hash (runs timing protection)" do
      assert {:error, :invalid} = Crypto.verify_with_upgrade("anypassword", nil)
    end

    test "returns {:error, :invalid} for unrecognized hash format" do
      assert {:error, :invalid} = Crypto.verify_with_upgrade("anypassword", "not-a-valid-hash")
    end

    test "returns {:ok, :valid, new_hash} for correct password with stale argon2id params" do
      # Hash with non-default params to simulate stale hash
      hashed = Crypto.hash_password("mysecurepassword")

      # Force needs_rehash to return true by passing different config
      result =
        Crypto.verify_with_upgrade("mysecurepassword", hashed,
          m_cost: 99,
          t_cost: 99,
          parallelism: 99
        )

      assert {:ok, :valid, new_hash} = result
      assert String.starts_with?(new_hash, "$argon2id$")
    end
  end

  describe "verify_with_upgrade/2 with bcrypt" do
    # Pre-computed bcrypt hash for "password123" using $2b$ format
    # Generated with: Bcrypt.hash_pwd_salt("password123")
    @bcrypt_hash "$2b$12$WApznUPhDubN0oeveSXHp.Raz0RCbZCjJjVEqMlKsXXYb.1VZFBi2"

    test "detects bcrypt hash prefix $2b$" do
      assert Crypto.bcrypt_hash?(@bcrypt_hash)
    end

    test "detects bcrypt hash prefix $2a$" do
      hash_2a = "$2a$12$WApznUPhDubN0oeveSXHp.Raz0RCbZCjJjVEqMlKsXXYb.1VZFBi2"
      assert Crypto.bcrypt_hash?(hash_2a)
    end

    test "does not detect argon2id as bcrypt" do
      hashed = Crypto.hash_password("test")
      refute Crypto.bcrypt_hash?(hashed)
    end

    if Code.ensure_loaded?(Bcrypt) do
      test "returns {:ok, :valid, new_hash} for correct password with bcrypt hash" do
        bcrypt_hash = Bcrypt.hash_pwd_salt("password123")

        result = Crypto.verify_with_upgrade("password123", bcrypt_hash)

        assert {:ok, :valid, new_hash} = result
        assert String.starts_with?(new_hash, "$argon2id$")
      end

      test "returns {:error, :invalid} for wrong password with bcrypt hash" do
        bcrypt_hash = Bcrypt.hash_pwd_salt("password123")

        assert {:error, :invalid} = Crypto.verify_with_upgrade("wrongpassword", bcrypt_hash)
      end
    end
  end

  describe "argon2_hash?/1" do
    test "detects argon2id hash" do
      hashed = Crypto.hash_password("test")
      assert Crypto.argon2_hash?(hashed)
    end

    test "does not detect bcrypt as argon2" do
      refute Crypto.argon2_hash?("$2b$12$something")
    end

    test "does not detect random string as argon2" do
      refute Crypto.argon2_hash?("not-a-hash")
    end
  end

  describe "needs_rehash?/2" do
    test "returns false for hash with matching current params" do
      hashed = Crypto.hash_password("testpassword")

      # Use the same params that argon2_elixir defaults to in test config
      m_cost = Application.get_env(:argon2_elixir, :m_cost, 16)
      t_cost = Application.get_env(:argon2_elixir, :t_cost, 3)
      parallelism = Application.get_env(:argon2_elixir, :parallelism, 4)

      refute Crypto.needs_rehash?(hashed, m_cost: m_cost, t_cost: t_cost, parallelism: parallelism)
    end

    test "returns true when t_cost differs" do
      hashed = Crypto.hash_password("testpassword")

      assert Crypto.needs_rehash?(hashed, t_cost: 99)
    end

    test "returns true when m_cost differs" do
      hashed = Crypto.hash_password("testpassword")

      assert Crypto.needs_rehash?(hashed, m_cost: 99)
    end

    test "returns true for non-argon2 hash" do
      assert Crypto.needs_rehash?("$2b$12$something")
    end

    test "returns true for unparseable hash" do
      assert Crypto.needs_rehash?("garbage")
    end
  end
end
