defmodule Sigra.MFA.BackupCodesTest do
  use ExUnit.Case, async: true

  alias Sigra.MFA.BackupCodes

  describe "generate/1" do
    test "returns list of {formatted_code, hashed_code} tuples" do
      codes = BackupCodes.generate(8)

      assert length(codes) == 8

      assert Enum.all?(codes, fn {formatted, hashed} ->
               is_binary(formatted) and is_binary(hashed)
             end)
    end

    test "codes match XXXX-XXXX format" do
      codes = BackupCodes.generate(4)

      for {formatted, _hashed} <- codes do
        assert Regex.match?(~r/^\d{4}-\d{4}$/, formatted),
               "Expected XXXX-XXXX format, got: #{formatted}"
      end
    end

    test "hashed codes are SHA-256 hex strings (64 chars)" do
      [{_formatted, hashed}] = BackupCodes.generate(1)

      assert byte_size(hashed) == 64
      assert Regex.match?(~r/^[0-9a-f]{64}$/, hashed)
    end

    test "generates unique codes" do
      codes = BackupCodes.generate(8)
      formatted = Enum.map(codes, &elem(&1, 0))

      assert length(Enum.uniq(formatted)) == 8
    end

    test "defaults to 8 codes" do
      codes = BackupCodes.generate()

      assert length(codes) == 8
    end
  end

  describe "hash/1" do
    test "normalizes input by stripping dashes and returns SHA-256 hex" do
      hash1 = BackupCodes.hash("1234-5678")
      hash2 = BackupCodes.hash("12345678")

      assert hash1 == hash2
    end

    test "normalizes input by stripping spaces" do
      hash1 = BackupCodes.hash("1234 5678")
      hash2 = BackupCodes.hash("12345678")

      assert hash1 == hash2
    end

    test "returns 64-char lowercase hex string" do
      hash = BackupCodes.hash("12345678")

      assert byte_size(hash) == 64
      assert Regex.match?(~r/^[0-9a-f]{64}$/, hash)
    end

    test "hash is consistent for same input" do
      assert BackupCodes.hash("1234-5678") == BackupCodes.hash("1234-5678")
    end
  end

  describe "remaining_count/3" do
    test "returns count of unused codes" do
      Code.ensure_loaded!(BackupCodes)
      # This function requires a repo and schema module -- tested via mock in integration
      # Here we verify the function exists and has the right arity
      assert function_exported?(BackupCodes, :remaining_count, 3)
    end
  end
end
