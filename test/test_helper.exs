# `mix test` here requires a live Postgres at localhost:5432 with
# postgres/postgres — this matches the CI `library_tests` job's postgres
# service. No default tag exclusions: every test that runs in CI also runs
# locally, so there's no "silently skipped" blind spot. See CLAUDE.md for
# the dev prereq docker one-liner.

# Graceful preflight skip for UpgradeIntegrationTest (D-19).
# The upgrade test shells out to `mix phx.new` — requires the phx_new 1.8.8 archive.
# CI installs the archive (see .github/workflows/ci.yml); local dev without the archive
# gets a clean skip, not a crash. NOT a blanket :postgres exclusion — CLAUDE.md forbids
# that pattern. The :upgrade exclusion is conditional on archive absence only.
phx_new_ok? =
  case System.cmd("mix", ["archive"], stderr_to_stdout: true) do
    {output, 0} -> String.contains?(output, "phx_new-1.8.8")
    _ -> false
  end

required_gate? = System.get_env("SIGRA_CI_REQUIRED") == "1"

if required_gate? and not phx_new_ok? do
  raise "SIGRA_CI_REQUIRED=1: required phx_new 1.8.8 archive is unavailable; install it with `mix archive.install --force hex phx_new 1.8.8`"
end

unless phx_new_ok? do
  ExUnit.configure(exclude: [:upgrade])
end

if System.get_env("SIGRA_EXUNIT_TIMING_JSON") not in [nil, ""] do
  unless Code.ensure_loaded?(Sigra.Test.CITimingFormatter) do
    Code.require_file("support/ci_timing_formatter.ex", __DIR__)
  end

  ExUnit.configure(formatters: [ExUnit.CLIFormatter, Sigra.Test.CITimingFormatter])
end

ExUnit.start()

if Code.ensure_loaded?(Postgrex) and Code.ensure_loaded?(Sigra.Test.PostgresRepo) do
  {:ok, _pid} = Sigra.Test.PostgresRepo.start_link(Sigra.Test.PostgresRepo.default_config())
  Ecto.Adapters.SQL.Sandbox.mode(Sigra.Test.PostgresRepo, :manual)

  if required_gate? do
    try do
      :ok = Ecto.Adapters.SQL.Sandbox.checkout(Sigra.Test.PostgresRepo)

      try do
        Ecto.Adapters.SQL.query!(Sigra.Test.PostgresRepo, "SELECT 1", [])
      after
        Ecto.Adapters.SQL.Sandbox.checkin(Sigra.Test.PostgresRepo)
      end
    rescue
      error ->
        raise "SIGRA_CI_REQUIRED=1: required test PostgreSQL query failed: #{Exception.message(error)}"
    end
  end
end

# Define Mox mocks for Sigra.Auth tests
Mox.defmock(Sigra.MockRepo, for: Sigra.MockRepo.Behaviour)
Mox.defmock(Sigra.MockRateLimiter, for: Sigra.RateLimiter)
Mox.defmock(Sigra.MockMailer, for: Sigra.Mailer)
Mox.defmock(Sigra.MockSessionStore, for: Sigra.SessionStore)
Mox.defmock(Sigra.MockGeoIP, for: Sigra.GeoIP)
Mox.defmock(Sigra.MockEmailTemplates, for: Sigra.EmailTemplates)
