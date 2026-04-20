defmodule Sigra.Passkeys.CoseKey do
  @moduledoc """
  Serialize / deserialize COSE public keys (integer-keyed maps returned by
  wax_ via `Wax.AttestedCredentialData.credential_public_key`).

  Uses Erlang External Term Format (`:erlang.term_to_binary/1`) because:
  - wax_ returns `%{integer() => ...}` — Jason cannot encode integer keys.
  - CBOR would be spec-correct but adds a dependency for data wax_ already
    decoded from CBOR upstream.
  - ETF preserves integer keys exactly and round-trips through
    Cloak encrypt/decrypt unchanged.

  The `:safe` flag on `binary_to_term/2` is mandatory — it blocks atom-creation
  DoS on tampered ciphertext (decrypt still succeeds for authenticated
  ciphertext under Cloak AES-GCM, but defense-in-depth).
  """

  @spec serialize(map()) :: binary()
  def serialize(%{} = cose_key) when is_map(cose_key), do: :erlang.term_to_binary(cose_key)

  @spec deserialize(binary()) :: map()
  def deserialize(bin) when is_binary(bin), do: :erlang.binary_to_term(bin, [:safe])
end
