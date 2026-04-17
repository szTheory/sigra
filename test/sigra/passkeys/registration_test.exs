defmodule Sigra.Passkeys.RegistrationTest do
  use ExUnit.Case, async: true

  alias Sigra.Passkeys.{CoseKey, Registration}
  alias Sigra.Test.Support.PasskeyFixtures

  defmodule TestUser do
    defstruct [:id]
  end

  defp config(overrides \\ []) do
    Sigra.Config.new!(
      Keyword.merge(
        [
          repo: Sigra.MockRepo,
          user_schema: TestUser,
          passkeys: [
            origin: "https://dev.dontneeda.pw",
            rp_id: "dev.dontneeda.pw",
            attestation: :none,
            user_verification: :preferred,
            timeout_ms: 60_000
          ]
        ],
        overrides
      )
    )
  end

  test "new_challenge/2 reflects passkey config" do
    challenge = Registration.new_challenge(config(), bytes: "challenge-bytes")

    assert challenge.origin == "https://dev.dontneeda.pw"
    assert challenge.rp_id == "dev.dontneeda.pw"
    assert challenge.user_verification == "preferred"
    assert challenge.bytes == "challenge-bytes"
  end

  test "verify/4 extracts registration persistence fields from wax_" do
    {attestation_object, client_data_json, _origin, _rp_id, challenge_value} =
      PasskeyFixtures.simplewebauthn_registration_fixture()

    challenge = Registration.new_challenge(config(), bytes: challenge_value)

    params = %{
      attestation_object: attestation_object,
      client_data_json: client_data_json,
      challenge: challenge,
      nickname: "MacBook Touch ID",
      device_hint: "macOS",
      transports: ["internal", "hybrid"]
    }

    assert {:ok, extracted} =
             Registration.verify(config(), %TestUser{id: Ecto.UUID.generate()}, params)

    assert is_binary(extracted.credential_id)
    assert is_binary(extracted.public_key)
    assert CoseKey.deserialize(extracted.public_key) |> is_map()
    assert extracted.sign_count == 0
    assert extracted.aaguid == nil
    assert extracted.nickname == "MacBook Touch ID"
    assert extracted.device_hint == "macOS"
    assert extracted.transports == ["internal", "hybrid"]
    assert extracted.rp_id == "dev.dontneeda.pw"
  end
end
