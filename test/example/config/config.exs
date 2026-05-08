# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

example_base_url = System.get_env("SIGRA_EXAMPLE_URL", "http://localhost:4000")

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

config :sigra, :otp_app, :example

config :example, :sigra_config,
  repo: Example.Repo,
  user_schema: Example.Accounts.User,
  session: [
    store: Sigra.SessionStores.Ecto,
    session_schema: Example.Accounts.UserSession
  ],
  audit: [
    audit_schema: Example.Accounts.AuditEvent
  ],
  webhooks: [
    enabled: true,
    webhook_subscription_schema: Example.Accounts.WebhookSubscription,
    webhook_event_schema: Example.Accounts.WebhookEvent,
    webhook_delivery_schema: Example.Accounts.WebhookDelivery,
    webhook_delivery_attempt_schema: Example.Accounts.WebhookDeliveryAttempt,
    endpoint_policy: &Example.Accounts.webhook_endpoint_policy/1,
    oban_queue: "sigra_webhooks",
    oban_concurrency: 10,
    signature_tolerance: 300
  ],
  passkeys: [
    rp_id: "localhost",
    rp_name: "Sigra Example",
    origin: example_base_url,
    timeout_ms: 60_000,
    attestation: :none,
    user_verification: :preferred,
    ceremony_rate_limit: [limit: 5, window_ms: 60_000],
    passkey_primary_enabled: true,
    user_passkey_schema: Example.Accounts.UserPasskey
  ]

config :example, Oban,
  repo: Example.Repo,
  engine: Oban.Engines.Basic,
  notifier: Oban.Notifiers.Postgres,
  queues: [sigra_webhooks: 10]

# Sigra worker runtime config (used by Oban workers)
config :sigra,
  repo: Example.Repo,
  user_schema: Example.Accounts.User,
  email_module: Example.Accounts.Emails,
  mailer: Example.Accounts.Mailer,
  webhooks: [
    enabled: true,
    webhook_subscription_schema: Example.Accounts.WebhookSubscription,
    webhook_event_schema: Example.Accounts.WebhookEvent,
    webhook_delivery_schema: Example.Accounts.WebhookDelivery,
    webhook_delivery_attempt_schema: Example.Accounts.WebhookDeliveryAttempt,
    endpoint_policy: &Example.Accounts.webhook_endpoint_policy/1,
    oban_queue: "sigra_webhooks",
    oban_concurrency: 10,
    signature_tolerance: 300
  ]

# Sigra OAuth providers
# Move secrets to config/runtime.exs for production
config :example, :sigra,
  oauth: [
    providers: [
      google: [
        client_id: System.get_env("GOOGLE_CLIENT_ID"),
        client_secret: System.get_env("GOOGLE_CLIENT_SECRET"),
        redirect_uri: "#{example_base_url}/auth/google/callback"
      ]
    ]
  ]

import_config "#{config_env()}.exs"
