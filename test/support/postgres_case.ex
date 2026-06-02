if Code.ensure_loaded?(Postgrex) do
  defmodule Sigra.Test.PostgresCase do
    @moduledoc """
    Case template for library tests that use the shared Postgres test repo.

    The repo is started once by `test/test_helper.exs`. Each test gets a SQL
    Sandbox owner, and data cleanup comes from owner rollback on exit.
    """

    use ExUnit.CaseTemplate

    using do
      quote do
        alias Sigra.Test.PostgresRepo

        import Ecto
        import Ecto.Changeset
        import Ecto.Query
      end
    end

    setup tags do
      sandbox_owner =
        Ecto.Adapters.SQL.Sandbox.start_owner!(
          Sigra.Test.PostgresRepo,
          shared: not tags[:async]
        )

      on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(sandbox_owner) end)

      {:ok, repo: Sigra.Test.PostgresRepo, sandbox_owner: sandbox_owner}
    end

    @doc """
    Runs `fun` against the test repo with a real, **non-sandboxed** connection.

    Use this for one-time DDL (e.g. `CREATE TABLE IF NOT EXISTS` in `setup_all`).
    A plain `Sandbox.checkout/1` wraps the work in the per-test transaction that
    the sandbox rolls back, so DDL never persists — it only appears to work on a
    dev database that already happens to hold the tables from an earlier run. On
    a fresh database (CI) those tables are absent and every test in the module
    fails with `relation "..." does not exist`. `unboxed_run/2` runs outside the
    sandbox so the DDL commits durably; per-test row inserts still roll back via
    each test's own sandbox owner.
    """
    def checkout_repo!(fun) when is_function(fun, 1) do
      Ecto.Adapters.SQL.Sandbox.unboxed_run(Sigra.Test.PostgresRepo, fn ->
        fun.(Sigra.Test.PostgresRepo)
      end)
    end
  end
end
