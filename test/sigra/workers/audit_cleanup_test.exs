defmodule Sigra.Workers.AuditCleanupTest do
  use ExUnit.Case, async: true

  # Wave 0 scaffold for Sigra.Workers.AuditCleanup (D-10 retention worker).
  # Plan 04 implements the worker. Tests are RED until then.

  alias Sigra.Workers.AuditCleanup

  defmodule StubRepo do
    @moduledoc false
    # Records calls so tests can assert behavior without a real DB.
    def delete_all(_query) do
      send(self(), {:delete_all_called})
      {0, nil}
    end

    def aggregate(_q, :count, _f), do: 0
  end

  describe "cleanup/3" do
    test "is exported with arity 3 (repo, schema, retention_days)" do
      Code.ensure_loaded!(AuditCleanup)
      assert function_exported?(AuditCleanup, :cleanup, 3)
    end

    test "nil retention is a no-op (D-09 default = keep forever)" do
      result = AuditCleanup.cleanup(StubRepo, Sigra.Test.AuditEvent, nil)
      assert result == :ok
      refute_received {:delete_all_called}
    end

    test "positive retention triggers a delete query" do
      _ = AuditCleanup.cleanup(StubRepo, Sigra.Test.AuditEvent, 30)
      assert_received {:delete_all_called}
    end
  end

  describe "Oban.Worker integration" do
    test "perform/1 is exported (D-10)" do
      Code.ensure_loaded!(AuditCleanup)
      assert function_exported?(AuditCleanup, :perform, 1)
    end

    test "max_attempts of 1 (cron jobs should not retry)" do
      changeset = AuditCleanup.new(%{})
      assert changeset.changes[:max_attempts] == 1
    end
  end
end
