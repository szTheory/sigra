defmodule Sigra.Audit.QueryIndexTest do
  @moduledoc """
  Postgres-only EXPLAIN check that the `(organization_id, inserted_at)`
  composite index is hit for the org-scoped audit query.

  Wave 0 stub: skipped until a real Postgres sandbox repo fixture lands
  in a later wave. Plan 15-01 Task 0 created this file; Plan 15-01 Task 1
  does NOT un-skip it (no live repo in the library test suite).
  """
  use ExUnit.Case, async: true

  @moduletag :postgres
  @moduletag :skip

  @tag :skip
  test "EXPLAIN shows (organization_id, inserted_at) index hit" do
    # Stub for a future Postgres-backed test. When un-skipped, this should:
    #
    #   1. Acquire a Postgres-backed sandboxed TestRepo
    #   2. Run:
    #        EXPLAIN SELECT * FROM audit_events
    #          WHERE organization_id = $1
    #          ORDER BY inserted_at DESC LIMIT 50
    #   3. Assert the plan text contains:
    #        "Index Scan using audit_events_organization_id_inserted_at_index"
    #
    # Kept as a Wave 0 scaffold so the file exists when the fixture lands.
    flunk("Wave 0 stub — un-skipped when Postgres sandbox repo is wired in")
  end
end
