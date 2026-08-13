defmodule <%= context_module %>.FirstPartyApps do
  @moduledoc """
  Finite host-owned policy records for this application's public first-party
  clients. Callback strings are literal allowlist entries, never patterns.
  """

  @profiles [
    %{
      id: "ios-primary",
      client_ref: "ios-primary",
      callback_uris: ["com.sigra.app:/login", "http://127.0.0.1:49152/callback"],
      direct_login: :browser_required
    },
    %{
      id: "android-primary",
      client_ref: "android-primary",
      callback_uris: ["com.sigra.app:/login"],
      direct_login: :password_allowed
    }
  ]

  @doc "Returns the static server-selected profile registry."
  def profiles, do: @profiles
end
