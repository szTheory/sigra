# Sigra app login
pipeline :app_login_public do
  plug Sigra.Plug.RateLimit,
    limiter: Sigra.RateLimiters.Hammer,
    error_handler: <%= web_module %>.AuthErrorHandler,
    key_prefix: "app_login_public",
    limit: 4,
    window: 60_000,
    limit_config_key: :app_login_public_rate_limit,
    window_config_key: :app_login_public_rate_limit_window
end

scope "/users", <%= web_module %> do
  pipe_through [:browser, :app_login_public]

  get "/app-login", AppLoginController, :start
  get "/app-login/continue", AppLoginController, :continue
  post "/app-login/approve", AppLoginController, :approve
  post "/app-login/cancel", AppLoginController, :cancel
end

scope "/users", <%= web_module %> do
  pipe_through [:browser, :require_authenticated, :require_sudo]

  post "/app-sessions/revoke", AppLoginController, :revoke_family
  post "/app-sessions/revoke-all", AppLoginController, :revoke_all
end

scope "/api/app-login", <%= web_module %> do
  pipe_through [:api, :app_login_public]

  post "/exchange", AppLoginController, :exchange
  post "/refresh", AppLoginController, :refresh
<%= if Keyword.get(Keyword.get(binding(), :opts, []), :app_password_login, false) do %>  post "/direct", AppLoginController, :direct
  post "/direct/mfa", AppLoginController, :complete_direct_mfa
<% end %>end
