defmodule Sigra.Passkeys.WaxRoundtripTest do
  use ExUnit.Case, async: true

  alias Sigra.Passkeys.CoseKey
  alias Sigra.Test.Support.PasskeyFixtures

  @tag :passkey_smoke
  test "D-16 smoke exercises Wax register and authenticate against upstream fixtures" do
    {attestation_object, client_data_json, origin, rp_id, challenge_value} =
      PasskeyFixtures.simplewebauthn_registration_fixture()

    registration_challenge =
      Wax.new_registration_challenge(
        origin: origin,
        rp_id: rp_id,
        attestation: "none",
        user_verification: "preferred",
        bytes: challenge_value
      )

    assert {:ok,
            {%Wax.AuthenticatorData{
               attested_credential_data: %Wax.AttestedCredentialData{
                 credential_id: credential_id,
                 credential_public_key: cose_key
               }
             }, _attestation_result}} =
             Wax.register(attestation_object, client_data_json, registration_challenge)

    assert CoseKey.deserialize(CoseKey.serialize(cose_key)) == cose_key

    {authenticator_data, assertion_client_data_json, signature, auth_origin, auth_rp_id,
     auth_challenge_value, assertion_credential_id, assertion_public_key} =
      PasskeyFixtures.simplewebauthn_assertion_fixture()

    authentication_challenge =
      Wax.new_authentication_challenge(
        origin: auth_origin,
        rp_id: auth_rp_id,
        bytes: auth_challenge_value
      )

    {:ok, decoded_assertion_public_key, ""} = Wax.Utils.CBOR.decode(assertion_public_key)

    credentials =
      [
        {assertion_credential_id,
         CoseKey.deserialize(CoseKey.serialize(decoded_assertion_public_key))}
      ]

    assert {:ok, %Wax.AuthenticatorData{}} =
             Wax.authenticate(
               assertion_credential_id,
               authenticator_data,
               signature,
               assertion_client_data_json,
               authentication_challenge,
               credentials
             )

    assert is_binary(credential_id)
  end
end
