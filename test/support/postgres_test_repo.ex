if Code.ensure_loaded?(Postgrex) do
  defmodule Sigra.Test.PostgresRepo do
    @moduledoc """
    Minimal Postgres-backed Ecto.Repo used by the tests that need a real
    Postgres query planner to assert DB-level invariants (e.g.
    `Sigra.Audit.QueryIndexTest` checking index hits).

    This repo is **not** started by the Sigra application — tests that need
    it must call `Sigra.Test.PostgresRepo.start_link/0` in their own setup
    (or use `start_supervised!/1`). There is **no** `:postgres` tag
    exclusion: these tests run in the default `mix test` suite, matching CI
    (see `test/test_helper.exs` and CLAUDE.md). A missing database fails
    fast rather than silently skipping.

    Connection config is read from environment variables so CI and local
    dev can override without touching source:

      * `SIGRA_TEST_PG_HOSTNAME` — default `localhost`
      * `SIGRA_TEST_PG_USERNAME` — default `postgres`
      * `SIGRA_TEST_PG_PASSWORD` — default `postgres`
      * `SIGRA_TEST_PG_DATABASE` — default `sigra_test`
    """

    use Ecto.Repo, otp_app: :sigra, adapter: Ecto.Adapters.Postgres

    @doc false
    def default_config do
      [
        hostname: System.get_env("SIGRA_TEST_PG_HOSTNAME", "localhost"),
        username: System.get_env("SIGRA_TEST_PG_USERNAME", "postgres"),
        password: System.get_env("SIGRA_TEST_PG_PASSWORD", "postgres"),
        database: System.get_env("SIGRA_TEST_PG_DATABASE", "sigra_test"),
        pool_size: 2,
        log: false
      ]
    end
  end
end
