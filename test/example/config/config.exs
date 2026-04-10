# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :example,
  ecto_repos: [Example.Repo],
  generators: [timestamp_type: :utc_datetime]

# Configure the endpoint
config :example, ExampleWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: ExampleWeb.ErrorHTML, json: ExampleWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Example.PubSub,
  live_view: [signing_salt: "cZ8qNLxr"]

# Configure Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.

# Sigra authentication
config :example, :sigra,
  repo: Example.Repo,
  user_schema: Example.Accounts.User

# Sigra worker runtime config (used by Oban workers)
config :sigra,
  repo: Example.Repo,
  user_schema: Example.Accounts.User,
  email_module: Example.Accounts.Emails,
  mailer: Example.Accounts.Mailer

import_config "#{config_env()}.exs"
