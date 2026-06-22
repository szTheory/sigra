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
passkey_origin =
  System.get_env("SIGRA_EXAMPLE_URL") ||
    "http://localhost:#{System.get_env("PORT", "4000")}"

passkey_rp_id =
  System.get_env("SIGRA_PASSKEY_RP_ID") ||
    (URI.parse(passkey_origin).host || "localhost")

config :example, :sigra,
  repo: Example.Repo,
  user_schema: Example.Accounts.User

config :sigra, :otp_app, :example

config :example, :sigra_config,
  repo: Example.Repo,
  user_schema: Example.Accounts.User,
  branding: [
    product_name: "Tasklane",
    email_from_name: "Tasklane",
    email_from_address: "noreply@example.com",
    accent_color: "#9a3412",
    accent_foreground: "#ffffff",
    background_color: "#f7f4ee",
    surface_color: "#ffffff",
    text_color: "#171717",
    muted_color: "#6b6258",
    border_color: "#ded8cf",
    theme: :system
  ],
  session: [
    store: Sigra.SessionStores.Ecto,
    session_schema: Example.Accounts.UserSession
  ],
  audit: [
    audit_schema: Example.Accounts.AuditEvent,
    forwarders: [
      [
        module: Sigra.Audit.Forwarders.Threadline,
        id: :default,
        # dispatch: :auto resolves to :sync when Oban is not supervised (the
        # case in this example app). Pin dispatch: :sync in attach/1 calls for
        # deterministic inline insertion.
        dispatch: :auto,
        # Threadline 0.5+ is DB-based; writes audit_actions via repo: — no HTTP
        # endpoint or api_key required.
        repo: Example.Repo
      ]
    ]
  ],
  passkeys: [
    rp_id: passkey_rp_id,
    rp_name: "Sigra Example",
    origin: passkey_origin,
    timeout_ms: 60_000,
    attestation: :none,
    user_verification: :preferred,
    ceremony_rate_limit: [limit: 5, window_ms: 60_000],
    passkey_primary_enabled: true,
    user_passkey_schema: Example.Accounts.UserPasskey
  ]

# Sigra worker runtime config (used by Oban workers)
config :sigra,
  repo: Example.Repo,
  user_schema: Example.Accounts.User,
  email_module: Example.Accounts.Emails,
  mailer: Example.Accounts.Mailer

import_config "#{config_env()}.exs"
