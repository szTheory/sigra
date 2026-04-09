defmodule Sigra.AuditTest do
  use ExUnit.Case, async: true

  # Wave 0 scaffold for the top-level Sigra.Audit API surface (D-12).
  # The Sigra.Audit module is implemented in Plan 02. Tests are RED until then.
  #
  # NOTE: Sigra has no host repo or DataCase. We use a minimal in-process
  # stub repo that behaves enough like Ecto.Repo for the changeset/insert path.
  # Once Plan 02 lands and a real test repo is wired (or a sandbox per Plan 02),
  # the stub can be replaced.

  alias Sigra.Audit
  alias Sigra.Test.AuditEvent

  defmodule StubRepo do
    @moduledoc false
    def insert(changeset) do
      if changeset.valid? do
        {:ok, Ecto.Changeset.apply_changes(changeset)}
      else
        {:error, changeset}
      end
    end

    def all(_query), do: []
    def stream(_query), do: Stream.map([], & &1)
    def aggregate(_q, :count, _f), do: 0
    def transaction(fun) when is_function(fun, 0), do: {:ok, fun.()}
  end

  describe "log/3 standalone" do
    test "inserts a single audit row and returns {:ok, event}" do
      assert {:ok, event} =
               Audit.log("billing.charge.succeeded",
                 repo: StubRepo,
                 audit_schema: AuditEvent,
                 actor_id: Ecto.UUID.generate(),
                 metadata: %{amount: 99}
               )

      assert event.action == "billing.charge.succeeded"
      assert event.outcome == "success"
    end

    test "rejects invalid action with {:error, changeset}" do
      assert {:error, cs} =
               Audit.log("BAD!!!", repo: StubRepo, audit_schema: AuditEvent)

      refute cs.valid?
    end

    test "rejects reserved prefix for public callers" do
      assert {:error, cs} =
               Audit.log("auth.login.success", repo: StubRepo, audit_schema: AuditEvent)

      refute cs.valid?
    end

    test "default outcome is success when unspecified (D-22)" do
      assert {:ok, event} =
               Audit.log("billing.charge.succeeded",
                 repo: StubRepo,
                 audit_schema: AuditEvent
               )

      assert event.outcome == "success"
    end
  end

  describe "query/1 composability (D-12)" do
    test "returns an Ecto.Query" do
      q = Audit.query(audit_schema: AuditEvent, actor_id: "abc")
      assert %Ecto.Query{} = q
    end
  end

  describe "count/2" do
    test "returns an integer" do
      assert is_integer(Audit.count([audit_schema: AuditEvent], repo: StubRepo))
    end
  end

  describe "list/2 pagination contract" do
    test "returns %{entries: list, next_cursor: nil | binary}" do
      result = Audit.list([audit_schema: AuditEvent], repo: StubRepo, limit: 50)
      assert %{entries: entries, next_cursor: cursor} = result
      assert is_list(entries)
      assert is_nil(cursor) or is_binary(cursor)
    end
  end

  describe "stream/2" do
    test "returns an Enumerable inside a transaction" do
      {:ok, count} =
        StubRepo.transaction(fn ->
          [audit_schema: AuditEvent]
          |> Audit.stream(repo: StubRepo)
          |> Enum.count()
        end)

      assert is_integer(count)
    end
  end
end
