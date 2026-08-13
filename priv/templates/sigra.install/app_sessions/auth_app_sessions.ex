defmodule <%= context_module %>.Auth.AppSessions do
  @moduledoc """
  Thin host-policy facade for first-party app login ceremonies.

  All code, challenge, MFA, and opaque credential lifecycle authority remains
  in `Sigra.AppLogin` and `Sigra.AppSession`.
  """

  @doc false
  def sigra_config do
    base_config = <%= context_module %>.sigra_config()

    %{
      base_config
      | app_session: [
          family_schema: <%= context_module %>.UserAppSessionFamily,
          token_schema: <%= context_module %>.UserAppSessionToken,
          app_login_code_schema: <%= context_module %>.UserAppLoginAttempt,
          app_login_challenge_schema: <%= context_module %>.UserAppLoginAttempt,
          first_party_profiles: <%= context_module %>.FirstPartyApps.profiles(),
          access_ttl: 900,
          refresh_idle_ttl: 2_592_000,
          absolute_ttl: 7_776_000
        ]
    }
  end

  def start_hosted(params), do: Sigra.AppLogin.start_hosted(sigra_config(), params)

  def approve_hosted(continuation, user, decision),
    do: Sigra.AppLogin.approve_hosted(sigra_config(), continuation, user, decision)

  def exchange_hosted(code, verifier, profile, callback),
    do: Sigra.AppLogin.exchange_hosted(sigra_config(), code, verifier, profile, callback)

  def refresh(raw_refresh_token), do: Sigra.AppSession.refresh(sigra_config(), raw_refresh_token)

  def revoke_family(user, family_id),
    do: Sigra.AppSession.revoke_family_for_user(sigra_config(), user, family_id)

  def revoke_all(user), do: Sigra.AppSession.revoke_all_for_user(sigra_config(), user)

<%= if Keyword.get(Keyword.get(binding(), :opts, []), :app_password_login, false) do %>  @doc false
  def start_direct(profile_id, email, password) do
    Sigra.AppLogin.start_direct(sigra_config(), profile_id, email, password,
      authenticate_user: &<%= context_module %>.authenticate_user/2,
      mfa_verify: &<%= context_module %>.mfa_verify/2,
      mfa_verify_backup: &<%= context_module %>.mfa_verify_backup/2
    )
  end

  @doc false
  def complete_direct_mfa(challenge, code, factor) do
    Sigra.AppLogin.complete_direct_mfa(sigra_config(), challenge, code,
      factor: factor,
      mfa_verify: &<%= context_module %>.mfa_verify/2,
      mfa_verify_backup: &<%= context_module %>.mfa_verify_backup/2
    )
  end
<% end %>end
