# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :sigra_install_golden_tmp,
  ecto_repos: [SigraInstallGoldenTmp.Repo],
  generators: [timestamp_type: :utc_datetime]

# Configure the endpoint
config :sigra_install_golden_tmp, SigraInstallGoldenTmpWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: SigraInstallGoldenTmpWeb.ErrorHTML, json: SigraInstallGoldenTmpWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: SigraInstallGoldenTmp.PubSub,
  live_view: [signing_salt: "<LIVE_VIEW_SALT>"]

# Configure Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.

# Sigra authentication
config :sigra_install_golden_tmp, :sigra,
  repo: SigraInstallGoldenTmp.Repo,
  user_schema: SigraInstallGoldenTmp.Accounts.User

# Sigra worker runtime config (used by Oban workers)
config :sigra,
  repo: SigraInstallGoldenTmp.Repo,
  user_schema: SigraInstallGoldenTmp.Accounts.User,
  email_module: SigraInstallGoldenTmp.Accounts.Emails,
  mailer: SigraInstallGoldenTmp.Accounts.Mailer

import_config "#{config_env()}.exs"
