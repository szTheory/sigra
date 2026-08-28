defmodule Example.Accounts.FirstPartyApps do
  @moduledoc "Finite native-proof public-client policy with literal callback allowlists."

  @profiles [
    %{
      id: "ios-native-proof",
      client_ref: "ios-native-proof",
      callback_uris: ["sigra-native-proof://auth/callback"],
      direct_login: :browser_required
    },
    %{
      id: "android-native-proof",
      client_ref: "android-native-proof",
      callback_uris: ["sigra-native-proof://auth/android"],
      direct_login: :browser_required
    }
  ]

  def profiles, do: @profiles
end
