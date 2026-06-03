defmodule Sigra.OptionalDepsTest do
  use ExUnit.Case, async: true

  # SOT unit tests for Sigra.OptionalDeps (Phase 137, Plan 01 — OD-01).
  # Strategy: drift-catching equality assertions — each predicate is asserted
  # equal to a freshly-evaluated Code.ensure_loaded?(Mod). This tautology stays
  # valid in both the all-deps library_tests lane (asserts == true for present
  # deps) and any dep-off CI lane (e.g. threadline dep-off: threadline_available?/0
  # == false). Do NOT hardcode true/false.
  #
  # AAA voice + describe-per-public-function per CLAUDE.md + house-style D-ID
  # references in test names.

  describe "oban_available?/0" do
    test "equals Code.ensure_loaded?(Oban) — D-01, D-03" do
      assert Sigra.OptionalDeps.oban_available?() == Code.ensure_loaded?(Oban)
    end
  end

  describe "bcrypt_available?/0" do
    test "equals Code.ensure_loaded?(Bcrypt) — D-01, D-03" do
      assert Sigra.OptionalDeps.bcrypt_available?() == Code.ensure_loaded?(Bcrypt)
    end
  end

  describe "eqrcode_available?/0" do
    test "equals Code.ensure_loaded?(EQRCode) — D-01, D-03" do
      assert Sigra.OptionalDeps.eqrcode_available?() == Code.ensure_loaded?(EQRCode)
    end
  end

  describe "threadline_available?/0" do
    test "equals Code.ensure_loaded?(Threadline) — D-01, D-03" do
      assert Sigra.OptionalDeps.threadline_available?() == Code.ensure_loaded?(Threadline)
    end
  end

  describe "assent_available?/0" do
    test "equals Code.ensure_loaded?(Assent) — D-01, D-03" do
      assert Sigra.OptionalDeps.assent_available?() == Code.ensure_loaded?(Assent)
    end
  end

  describe "swoosh_available?/0" do
    test "equals Code.ensure_loaded?(Swoosh) — D-01, D-03" do
      assert Sigra.OptionalDeps.swoosh_available?() == Code.ensure_loaded?(Swoosh)
    end
  end

  describe "joken_available?/0" do
    test "equals Code.ensure_loaded?(Joken) — D-01, D-03" do
      assert Sigra.OptionalDeps.joken_available?() == Code.ensure_loaded?(Joken)
    end
  end

  describe "hammer_available?/0" do
    test "equals Code.ensure_loaded?(Hammer) — D-01, D-03" do
      assert Sigra.OptionalDeps.hammer_available?() == Code.ensure_loaded?(Hammer)
    end
  end

  describe "req_available?/0" do
    test "equals Code.ensure_loaded?(Req) — D-01, D-03" do
      assert Sigra.OptionalDeps.req_available?() == Code.ensure_loaded?(Req)
    end
  end

  describe "encryption_active?/1" do
    # Fixture modules mirror the upgrade_test.exs:229-260 pattern.
    # The derivation in Sigra.OptionalDeps.encrypted_binary_module/1 drops the
    # last segment of :user_schema and appends ["Encrypted", "Binary"], so
    # StubVault.User -> StubVault.Encrypted.Binary
    # RealVault.User -> RealVault.Encrypted.Binary

    defmodule StubVault.Encrypted.Binary do
      def __sigra_encryption_mode__, do: :stub
    end

    defmodule RealVault.Encrypted.Binary do
      def __sigra_encryption_mode__, do: :vault
    end

    # Throwaway schema modules — only the derived *.Encrypted.Binary sibling matters
    defmodule StubVault.User do
    end

    defmodule RealVault.User do
    end

    test "returns false for stub mode — mirrors stub-vs-real config check, D-07" do
      # When *.Encrypted.Binary reports :stub, encryption is NOT active.
      refute Sigra.OptionalDeps.encryption_active?(user_schema: StubVault.User)
    end

    test "returns true for real vault mode — mirrors stub-vs-real config check, D-07" do
      # When *.Encrypted.Binary reports :vault (or any non-:stub value), encryption IS active.
      assert Sigra.OptionalDeps.encryption_active?(user_schema: RealVault.User)
    end

    test "returns false when no :user_schema key is present — D-07" do
      # Without :user_schema, encrypted_binary_module/1 returns nil -> false.
      refute Sigra.OptionalDeps.encryption_active?([])
    end
  end
end
