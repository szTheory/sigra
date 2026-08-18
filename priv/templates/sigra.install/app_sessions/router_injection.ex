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

# Refresh rotation and replay are a single security ceremony. Keep its bounded
# budget independent from the hosted approval/exchange ceremony so a consumed
# refresh credential always reaches the controller and can revoke its family.
pipeline :app_login_refresh do
  plug Sigra.Plug.RateLimit,
    limiter: Sigra.RateLimiters.Hammer,
    error_handler: <%= web_module %>.AuthErrorHandler,
    key_prefix: "app_login_refresh",
    limit: 4,
    window: 60_000,
    limit_config_key: :app_login_refresh_rate_limit,
    window_config_key: :app_login_refresh_rate_limit_window
end

<%= if Keyword.get(Keyword.get(binding(), :opts, []), :app_password_login, false) do %>
pipeline :app_login_direct do
  plug Sigra.Plug.RateLimit,
    limiter: Sigra.RateLimiters.Hammer,
    error_handler: <%= web_module %>.AuthErrorHandler,
    key_prefix: "app_login_direct",
    limit: 4,
    window: 60_000,
    limit_config_key: :app_login_direct_rate_limit,
    window_config_key: :app_login_direct_rate_limit_window
end

<% end %>


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
end

scope "/api/app-login", <%= web_module %> do
  pipe_through [:api, :app_login_refresh]

  post "/refresh", AppLoginController, :refresh
end

<%= if Keyword.get(Keyword.get(binding(), :opts, []), :app_password_login, false) do %>
scope "/api/app-login", <%= web_module %> do
  pipe_through [:api, :app_login_direct]

  post "/direct", AppLoginController, :direct
  post "/direct/mfa", AppLoginController, :complete_direct_mfa
end
<% end %>
