import Config

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :example, Example.Repo,
  username: System.get_env("PGUSER", "postgres"),
  password: System.get_env("PGPASSWORD", "postgres"),
  hostname: System.get_env("PGHOST", "localhost"),
  port: String.to_integer(System.get_env("PGPORT", "5432")),
  database: "example_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :example, ExampleWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  # Test-only deterministic key base -- NEVER reused in prod. See T-10-03.
  secret_key_base: "test-only-key-base-" <> String.duplicate("a", 64),
  server: false

# Swoosh test adapter captures emails for assert_email_sent/1.
config :example, Example.Mailer, adapter: Swoosh.Adapters.Test
config :swoosh, :api_client, false

# Explicit cookie_domain for test env (Phase 10 D-09).
config :sigra, cookie_domain: nil

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

# Sort query params output of verified routes for robust url comparisons
config :phoenix,
  sort_verified_routes_query_params: true

# Sigra authentication
# Speed up password hashing in tests
config :argon2_elixir, t_cost: 1, m_cost: 8
