defmodule Sigra.Passkeys.CoseSerializationTest do
  use ExUnit.Case, async: true

  alias Sigra.Passkeys.CoseKey
  alias Sigra.Test.Support.PasskeyFixtures

  describe "round-trip" do
    test "serialize/1 and deserialize/1 preserve integer COSE keys" do
      cose_key = PasskeyFixtures.valid_cose_key()

      assert CoseKey.serialize(cose_key) |> CoseKey.deserialize() == cose_key
    end

    test "deserialize/1 uses :safe when decoding ETF" do
      assert CoseKey.deserialize(:erlang.term_to_binary(:sigra_known_atom)) == :sigra_known_atom

      assert_raise ArgumentError, fn ->
        CoseKey.deserialize(<<131, 119, 20, "sigra_unknown_atom_1">>)
      end
    end
  end
end
