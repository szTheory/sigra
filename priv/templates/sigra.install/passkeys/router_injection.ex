# Sigra passkeys
scope "/users", <%= web_module %> do
  pipe_through [:browser, :require_mfa_capability, :require_passkeys_capability]

  post "/mfa/passkey", SessionController, :complete_mfa_passkey
  post "/mfa/passkey/options", SessionController, :passkey_mfa_options
end

scope "/users", <%= web_module %> do
  pipe_through [:browser, :require_passkeys_capability, :redirect_if_user_is_authenticated]

  post "/log_in/passkey", SessionController, :complete_passkey
  post "/log_in/passkey/options", SessionController, :passkey_authentication_options
end

scope "/users", <%= web_module %> do
  pipe_through [:browser, :require_passkeys_capability, :require_authenticated, :require_sudo]

  post "/settings/mfa/passkeys/options", SessionController, :passkey_registration_options
  post "/settings/mfa/passkeys", SessionController, :complete_passkey_registration
  post "/settings/mfa/passkeys/:id/delete", SessionController, :delete_passkey
end
