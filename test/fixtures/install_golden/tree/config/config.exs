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

# Configure the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :sigra_install_golden_tmp, SigraInstallGoldenTmp.Mailer, adapter: Swoosh.Adapters.Local

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

# Runtime keyword consumed by Sigra admin LiveViews (UsersIndexLive, etc.)
# via Application.get_env/2 — keep in sync with SigraInstallGoldenTmp.Accounts.sigra_config/0.
config :sigra_install_golden_tmp, :sigra_config,
  repo: SigraInstallGoldenTmp.Repo,
  user_schema: SigraInstallGoldenTmp.Accounts.User,
  session: [
    store: Sigra.SessionStores.Ecto,
    session_schema: SigraInstallGoldenTmp.Accounts.UserSession
  ],
  audit: [
    audit_schema: SigraInstallGoldenTmp.Accounts.AuditEvent
  ]

# Sigra worker runtime config (used by Oban workers)
config :sigra,
  otp_app: :sigra_install_golden_tmp,
  repo: SigraInstallGoldenTmp.Repo,
  user_schema: SigraInstallGoldenTmp.Accounts.User,
  email_module: SigraInstallGoldenTmp.Accounts.Emails,
  mailer: SigraInstallGoldenTmp.Accounts.Mailer


# Sigra passkeys
config :sigra_install_golden_tmp, :sigra_config,
  passkeys: [
    rp_id: "localhost",
    rp_name: "SigraInstallGoldenTmp",
    origin: "http://localhost:4000",
    timeout_ms: 60_000,
    attestation: :none,
    user_verification: :preferred,
    ceremony_rate_limit: [limit: 5, window_ms: 60_000],
    passkey_primary_enabled: true,
    user_passkey_schema: SigraInstallGoldenTmp.Accounts.UserPasskey
  ]

import_config "#{config_env()}.exs"
