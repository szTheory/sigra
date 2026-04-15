if Code.ensure_loaded?(Postgrex) do
  defmodule Sigra.Test.PostgresRepo do
    @moduledoc """
    Minimal Postgres-backed Ecto.Repo used exclusively by the opt-in
    `:postgres` tagged tests (e.g. `Sigra.Audit.QueryIndexTest`) that need a
    real Postgres query planner to assert index-hit invariants.

    This repo is **not** started by the Sigra application — tests that need
    it must call `Sigra.Test.PostgresRepo.start_link/0` in their own setup
    (or use `start_supervised!/1`). Excluded from the default `mix test`
    run via the `:postgres` module tag in `test/test_helper.exs`.

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
