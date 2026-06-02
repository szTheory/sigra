if Code.ensure_loaded?(Postgrex) do
  defmodule Sigra.Test.AuditQueryIndexScratchRepo do
    @moduledoc """
    Isolated Postgres repo for the storage-destructive audit query index proof.

    This repo points at `sigra_audit_query_index_scratch` and is never used by
    the shared SQL Sandbox harness for library live-DB tests.
    """

    use Ecto.Repo, otp_app: :sigra, adapter: Ecto.Adapters.Postgres

    @doc false
    def default_config do
      Sigra.Test.PostgresRepo.default_config()
      |> Keyword.put(:database, "sigra_audit_query_index_scratch")
      |> Keyword.delete(:pool)
      |> Keyword.delete(:ownership_timeout)
      |> Keyword.put(:pool_size, 1)
    end
  end
end
