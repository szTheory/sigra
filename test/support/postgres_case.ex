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
  end
end
