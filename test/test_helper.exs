# The `:postgres` tag marks tests that require a live Postgres database
# (e.g. EXPLAIN-plan assertions in test/sigra/audit/query_index_test.exs).
# These are excluded by default so `mix test` stays hermetic; run them via
#   mix test --include postgres
# after booting Postgres (docker-compose up -d postgres) or on CI.
ExUnit.start(exclude: [:postgres])

# Define Mox mocks for Sigra.Auth tests
Mox.defmock(Sigra.MockRepo, for: Sigra.MockRepo.Behaviour)
Mox.defmock(Sigra.MockRateLimiter, for: Sigra.RateLimiter)
Mox.defmock(Sigra.MockMailer, for: Sigra.Mailer)
Mox.defmock(Sigra.MockSessionStore, for: Sigra.SessionStore)
Mox.defmock(Sigra.MockGeoIP, for: Sigra.GeoIP)
Mox.defmock(Sigra.MockEmailTemplates, for: Sigra.EmailTemplates)
