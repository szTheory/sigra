defmodule Sigra.Audit.QueryIndexTest do
  @moduledoc """
  Postgres-only EXPLAIN check that the `(organization_id, inserted_at)`
  composite index is hit for the org-scoped audit query built by
  `Sigra.Audit.Query.build/2` with an `:organization_id` filter.

  This test is tagged `:postgres` at the module level and is excluded by
  default in `test/test_helper.exs`. To run it:

      # Boot a local Postgres (or rely on CI Postgres service). The test
      # creates/drops an isolated DB named `sigra_audit_query_index_scratch`
      # via `storage_up` / `storage_down` — not the shared `sigra_test` DB.

      docker run --rm -d -p 5432:5432 \\
        -e POSTGRES_PASSWORD=postgres \\
        --name sigra-test-pg postgres:16

      mix test test/sigra/audit/query_index_test.exs

  The test spins up a throwaway `Sigra.Test.AuditQueryIndexScratchRepo`, creates the
  minimal `audit_events` + `organizations` schema inline (enough for the
  FK target + composite index to exist), runs `EXPLAIN` on the query, and
  asserts the plan text substring-matches
  `audit_events_organization_id_inserted_at_index`.

  Uses `SET LOCAL enable_seqscan = off` before the EXPLAIN so the planner
  prefers the index even with an empty table — at zero rows Postgres
  would otherwise pick a seq scan regardless of index presence (the
  tiny-table heuristic). The `LOCAL` scope means the setting is
  transaction-bound and never leaks to other tests.
  """
  use ExUnit.Case, async: false

  @moduletag :postgres

  alias Sigra.Audit.Query
  alias Sigra.Test.AuditQueryIndexScratchRepo

  @index_name "audit_events_organization_id_inserted_at_index"

  setup_all do
    repo = AuditQueryIndexScratchRepo
    config = repo.default_config()

    # Drop + create an isolated scratch database so repeated runs are idempotent.
    _ = Ecto.Adapters.Postgres.storage_down(config)
    :ok = Ecto.Adapters.Postgres.storage_up(config)

    {:ok, pid} = repo.start_link(config)

    # Create the minimal schema inline: organizations (FK target) +
    # audit_events with the same column set the generator template emits,
    # plus the composite index under test. We do NOT run the installer's
    # full migration set — just enough to reproduce the index-hit scenario.
    exec!(repo, """
    CREATE TABLE IF NOT EXISTS organizations (
      id UUID PRIMARY KEY,
      inserted_at TIMESTAMP NOT NULL DEFAULT now(),
      updated_at TIMESTAMP NOT NULL DEFAULT now()
    )
    """)

    exec!(repo, """
    CREATE TABLE IF NOT EXISTS audit_events (
      id UUID PRIMARY KEY,
      occurred_at TIMESTAMP NOT NULL DEFAULT now(),
      action VARCHAR(255) NOT NULL,
      outcome VARCHAR(32) NOT NULL DEFAULT 'success',
      actor_id UUID,
      actor_type VARCHAR(64) NOT NULL DEFAULT 'user',
      target_id UUID,
      target_type VARCHAR(64),
      ip_address VARCHAR(64),
      user_agent VARCHAR(512),
      metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
      organization_id UUID REFERENCES organizations(id) ON DELETE SET NULL,
      effective_user_id UUID,
      inserted_at TIMESTAMP NOT NULL DEFAULT now()
    )
    """)

    exec!(repo, """
    CREATE INDEX IF NOT EXISTS #{@index_name}
      ON audit_events (organization_id, inserted_at)
    """)

    on_exit(fn ->
      if Process.alive?(pid), do: GenServer.stop(pid)
      _ = Ecto.Adapters.Postgres.storage_down(config)
    end)

    {:ok, repo: repo}
  end

  test "Query.build/2 with :organization_id hits the composite index under EXPLAIN",
       %{repo: repo} do
    org_id = Ecto.UUID.generate()

    query = Query.build(Sigra.Test.AuditEvent, organization_id: org_id)
    {sql, params} = Ecto.Adapters.SQL.to_sql(:all, repo, query)

    # Force the planner to prefer the index even against an empty table
    # (zero-row tables trigger the planner's seq-scan fallback regardless
    # of index availability). LOCAL keeps the setting transaction-scoped.
    repo.transaction(fn ->
      Ecto.Adapters.SQL.query!(repo, "SET LOCAL enable_seqscan = off", [])

      %Postgrex.Result{rows: rows} =
        Ecto.Adapters.SQL.query!(repo, "EXPLAIN " <> sql, params)

      plan_text = rows |> List.flatten() |> Enum.join("\n")

      assert plan_text =~ @index_name,
             "Expected (organization_id, inserted_at) composite index hit " <>
               "(#{@index_name}) in the EXPLAIN plan, got:\n#{plan_text}"
    end)
  end

  defp exec!(repo, sql), do: Ecto.Adapters.SQL.query!(repo, sql, [])
end
