import Config

# Speed up Argon2 hashing in tests
config :argon2_elixir, t_cost: 1, m_cost: 8

# Swoosh test adapter captures emails for assert_email_sent/1 in any
# in-library mailer tests. The example test app owns its own mailer
# configuration at `test/example/config/test.exs`; this stanza exists
# so tests that exercise `Sigra.Mailer` directly (Phase 17+) can rely
# on a no-op delivery path.
config :sigra, Sigra.Mailer, adapter: Swoosh.Adapters.Test

# Chimeway.Application unconditionally supervises Chimeway.Repo at boot.
# No Sigra test exercises Chimeway.Repo, but it needs valid config to start
# cleanly in the test env — without it, Chimeway.Repo logs DB connection
# errors on every test run. Point it at the same test DB used by Sigra tests.
config :chimeway, Chimeway.Repo,
  hostname: System.get_env("SIGRA_TEST_PG_HOSTNAME", "localhost"),
  port: String.to_integer(System.get_env("SIGRA_TEST_PG_PORT", "5432")),
  username: System.get_env("SIGRA_TEST_PG_USERNAME", "postgres"),
  password: System.get_env("SIGRA_TEST_PG_PASSWORD", "postgres"),
  database: System.get_env("SIGRA_TEST_PG_DATABASE", "sigra_test"),
  pool: Ecto.Adapters.SQL.Sandbox
