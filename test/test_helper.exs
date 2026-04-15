# `mix test` here requires a live Postgres at localhost:5432 with
# postgres/postgres — this matches the CI `library_tests` job's postgres
# service. No default tag exclusions: every test that runs in CI also runs
# locally, so there's no "silently skipped" blind spot. See CLAUDE.md for
# the dev prereq docker one-liner.
ExUnit.start()

# Define Mox mocks for Sigra.Auth tests
Mox.defmock(Sigra.MockRepo, for: Sigra.MockRepo.Behaviour)
Mox.defmock(Sigra.MockRateLimiter, for: Sigra.RateLimiter)
Mox.defmock(Sigra.MockMailer, for: Sigra.Mailer)
Mox.defmock(Sigra.MockSessionStore, for: Sigra.SessionStore)
Mox.defmock(Sigra.MockGeoIP, for: Sigra.GeoIP)
Mox.defmock(Sigra.MockEmailTemplates, for: Sigra.EmailTemplates)
