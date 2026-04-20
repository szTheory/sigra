defmodule Sigra.Test.Support.PasskeyFixtures do
  @moduledoc false

  alias Sigra.Passkeys.Credential

  # Registration and assertion vectors sourced from:
  # https://github.com/MasterKale/SimpleWebAuthn/blob/8b7622948c87c4c26e74b24f218e80b2e72adf70/packages/server/src/{registration,authentication}/verify*Response.test.ts
  def valid_cose_key do
    %{
      1 => 2,
      3 => -7,
      -1 => 1,
      -2 => :crypto.strong_rand_bytes(32),
      -3 => :crypto.strong_rand_bytes(32)
    }
  end

  def passkey_fixture(user_id) do
    now = DateTime.utc_now()

    %Credential{
      id: Ecto.UUID.generate(),
      user_id: user_id,
      credential_id: :crypto.strong_rand_bytes(32),
      public_key: :erlang.term_to_binary(valid_cose_key()),
      sign_count: 42,
      aaguid: Ecto.UUID.generate(),
      nickname: "MacBook Touch ID",
      device_hint: "macOS",
      transports: ["internal", "hybrid"],
      rp_id: "localhost",
      last_used_at: now,
      inserted_at: now,
      updated_at: now
    }
  end

  def simplewebauthn_registration_fixture do
    {
      base64url_decode!(
        "o2NmbXRkbm9uZWdhdHRTdG10oGhhdXRoRGF0YVjFPdxHEOnAiLIp26idVjIguzn3Ipr_RlsKZWsa-5qK-KBFAAAAAAAAAAAAAAAAAAAAAAAAAAAAQQHSlyRHIdWleVqO24-6ix7JFWODqDWo_arvEz3Se5EgIFHkcVjZ4F5XDSBreIHsWRilRnKmaaqlqK3V2_4XtYs2pQECAyYgASFYID5PQTZQQg6haZFQWFzqfAOyQ_ENsMH8xxQ4GRiNPsqrIlggU8IVUOV8qpgk_Jh-OTaLuZL52KdX1fTht07X4DiQPow"
      ),
      base64url_decode!(
        "eyJ0eXBlIjoid2ViYXV0aG4uY3JlYXRlIiwiY2hhbGxlbmdlIjoiYUVWalkxQlhkWHBwVURBd1NEQndOV2Q0YURKZmRUVmZVRU0wVG1WWloyUSIsIm9yaWdpbiI6Imh0dHBzOlwvXC9kZXYuZG9udG5lZWRhLnB3IiwiYW5kcm9pZFBhY2thZ2VOYW1lIjoib3JnLm1vemlsbGEuZmlyZWZveCJ9"
      ),
      "https://dev.dontneeda.pw",
      "dev.dontneeda.pw",
      "hEccPWuziP00H0p5gxh2_u5_PC4NeYgd"
    }
  end

  def simplewebauthn_assertion_fixture do
    {
      base64url_decode!("PdxHEOnAiLIp26idVjIguzn3Ipr_RlsKZWsa-5qK-KABAAAAkA"),
      base64url_decode!(
        "eyJjaGFsbGVuZ2UiOiJkRzkwWVd4c2VWVnVhWEYxWlZaaGJIVmxSWFpsY25sVWFXMWwiLCJjbGllbnRFeHRlbnNpb25zIjp7fSwiaGFzaEFsZ29yaXRobSI6IlNIQS0yNTYiLCJvcmlnaW4iOiJodHRwczovL2Rldi5kb250bmVlZGEucHciLCJ0eXBlIjoid2ViYXV0aG4uZ2V0In0"
      ),
      base64url_decode!(
        "MEUCIQDYXBOpCWSWq2Ll4558GJKD2RoWg958lvJSB_GdeokxogIgWuEVQ7ee6AswQY0OsuQ6y8Ks6jhd45bDx92wjXKs900"
      ),
      "https://dev.dontneeda.pw",
      "dev.dontneeda.pw",
      "totallyUniqueValueEveryTime",
      base64url_decode!(
        "KEbWNCc7NgaYnUyrNeFGX9_3Y-8oJ3KwzjnaiD1d1LVTxR7v3CaKfCz2Vy_g_MHSh7yJ8yL0Pxg6jo_o0hYiew"
      ),
      base64url_decode!(
        "pQECAyYgASFYIIheFp-u6GvFT2LNGovf3ZrT0iFVBsA_76rRysxRG9A1Ilgg8WGeA6hPmnab0HAViUYVRkwTNcN77QBf_RR0dv3lIvQ"
      )
    }
  end

  defp base64url_decode!(value) do
    value
    |> Base.url_decode64!(padding: false)
  end
end
