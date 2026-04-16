defmodule Sigra.Passkeys.Registration do
  @moduledoc """
  WebAuthn registration ceremony helpers.

  This module stays Plug.Conn-free. The caller owns challenge storage and
  passes the challenge back explicitly for verification.
  """

  alias Sigra.Passkeys.CoseKey

  @type attestation_params :: %{
          required(:attestation_object) => binary(),
          required(:client_data_json) => binary(),
          required(:challenge) => Wax.Challenge.t(),
          optional(:nickname) => String.t() | nil,
          optional(:device_hint) => String.t() | nil,
          optional(:transports) => [String.t()]
        }

  @spec new_challenge(Sigra.Config.t(), keyword()) :: Wax.Challenge.t()
  def new_challenge(%Sigra.Config{} = config, opts \\ []) do
    passkeys = config.passkeys
    bytes = Keyword.get(opts, :bytes) || :crypto.strong_rand_bytes(32)

    Wax.new_registration_challenge(
      origin: Keyword.get(passkeys, :origin),
      rp_id: Keyword.get(passkeys, :rp_id),
      user_verification: passkeys |> Keyword.get(:user_verification, :preferred) |> to_string(),
      attestation: passkeys |> Keyword.get(:attestation, :none) |> to_string(),
      timeout: Keyword.get(passkeys, :timeout_ms, 60_000),
      bytes: bytes
    )
  end

  @spec verify(Sigra.Config.t(), map(), attestation_params(), keyword()) ::
          {:ok, map()} | {:error, term()}
  def verify(%Sigra.Config{} = config, _user, params, _opts \\ []) when is_map(params) do
    attestation_object = Map.fetch!(params, :attestation_object)
    client_data_json = Map.fetch!(params, :client_data_json)
    challenge = Map.fetch!(params, :challenge)

    case Wax.register(attestation_object, client_data_json, challenge) do
      {:ok, {auth_data, _attestation_result}} ->
        acd = auth_data.attested_credential_data

        {:ok,
         %{
           credential_id: acd.credential_id,
           public_key: CoseKey.serialize(acd.credential_public_key),
           sign_count: auth_data.sign_count,
           aaguid: normalize_aaguid(Wax.AuthenticatorData.get_aaguid(auth_data)),
           nickname: Map.get(params, :nickname),
           device_hint: Map.get(params, :device_hint),
           transports: Map.get(params, :transports, []),
           rp_id: Keyword.get(config.passkeys, :rp_id)
         }}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp normalize_aaguid(nil), do: nil
  defp normalize_aaguid(<<0::128>>), do: nil

  defp normalize_aaguid(raw_aaguid) when is_binary(raw_aaguid) do
    case Ecto.UUID.cast(raw_aaguid) do
      {:ok, uuid} -> uuid
      :error -> nil
    end
  end
end
