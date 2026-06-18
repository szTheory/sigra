if Code.ensure_loaded?(Postgrex) do
  defmodule Sigra.Test.PostgresRepo do
    @moduledoc """
    Minimal Postgres-backed Ecto.Repo used by the tests that need a real
    Postgres query planner to assert DB-level invariants (e.g.
    `Sigra.Audit.QueryIndexTest` checking index hits).

    This repo is **not** started by the Sigra application. `test/test_helper.exs`
    starts it once for the library test suite and puts it in manual SQL Sandbox
    mode. Tests that need live Postgres should use `Sigra.Test.PostgresCase` so
    each test gets an owner process and rollback cleanup.

    Connection config is read from environment variables so CI and local
    dev can override without touching source:

      * `SIGRA_TEST_PG_HOSTNAME` — default `localhost`
      * `SIGRA_TEST_PG_PORT` — default `5432` (point at a Dockerized Postgres on a
        dynamic host port; `scripts/db/up.sh` writes this into `tmp/db.env`)
      * `SIGRA_TEST_PG_USERNAME` — default `postgres`
      * `SIGRA_TEST_PG_PASSWORD` — default `postgres`
      * `SIGRA_TEST_PG_DATABASE` — default `sigra_test`
    """

    use Ecto.Repo, otp_app: :sigra, adapter: Ecto.Adapters.Postgres

    @doc false
    def default_config do
      [
        hostname: System.get_env("SIGRA_TEST_PG_HOSTNAME", "localhost"),
        port: String.to_integer(System.get_env("SIGRA_TEST_PG_PORT", "5432")),
        username: System.get_env("SIGRA_TEST_PG_USERNAME", "postgres"),
        password: System.get_env("SIGRA_TEST_PG_PASSWORD", "postgres"),
        database: System.get_env("SIGRA_TEST_PG_DATABASE", "sigra_test"),
        pool: Ecto.Adapters.SQL.Sandbox,
        pool_size: 4,
        ownership_timeout: 120_000,
        log: false
      ]
    end
  end
end
