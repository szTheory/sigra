defmodule Example.Accounts.Auth.AppSessions do
  @moduledoc "Example-owned facade over Sigra's opaque app-session lifecycle."

  def sigra_config, do: Example.Accounts.sigra_config()
  def start_hosted(params), do: Sigra.AppLogin.start_hosted(sigra_config(), params)

  def approve_hosted(continuation, user, decision),
    do: Sigra.AppLogin.approve_hosted(sigra_config(), continuation, user, decision)

  def exchange_hosted(code, verifier, profile_id, callback) do
    case Enum.find(Example.Accounts.FirstPartyApps.profiles(), &(&1.id == profile_id)) do
      %{id: _id, client_ref: _client_ref} = profile ->
        Sigra.AppLogin.exchange_hosted(sigra_config(), code, verifier, profile, callback)

      _ ->
        {:error, :invalid_code}
    end
  end

  def refresh(raw_refresh_token), do: Sigra.AppSession.refresh(sigra_config(), raw_refresh_token)

  def revoke_family(user, family_id),
    do: Sigra.AppSession.revoke_family_for_user(sigra_config(), user, family_id)

  def revoke_all(user), do: Sigra.AppSession.revoke_all_for_user(sigra_config(), user)
end
