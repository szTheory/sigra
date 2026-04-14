import Config

# Speed up Argon2 hashing in tests
config :argon2_elixir, t_cost: 1, m_cost: 8

# Swoosh test adapter captures emails for assert_email_sent/1 in any
# in-library mailer tests. The example test app owns its own mailer
# configuration at `test/example/config/test.exs`; this stanza exists
# so tests that exercise `Sigra.Mailer` directly (Phase 17+) can rely
# on a no-op delivery path.
config :sigra, Sigra.Mailer, adapter: Swoosh.Adapters.Test
