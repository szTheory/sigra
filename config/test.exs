import Config

# Speed up Argon2 hashing in tests
config :argon2_elixir, t_cost: 1, m_cost: 8
