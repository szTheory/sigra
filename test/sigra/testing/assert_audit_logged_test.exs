defmodule Sigra.Testing.AssertAuditLoggedTest do
  use ExUnit.Case, async: true

  # Plan 15-02 Task 3 implements `assert_audit_logged/2` as a thin alias
  # for `assert_audit_event/2` with signature `(map, keyword)` — NOT
  # `(repo, fields)` (see D-31 refinement in plan frontmatter).

  import Sigra.Testing, only: [assert_audit_logged: 2, assert_audit_logged_for_org: 2]

  alias Sigra.Test.AuditEvent

  # In-module fake repo. `assert_audit_event/2` (which
  # `assert_audit_logged/2` delegates to) builds an Ecto query and calls
  # `repo.one/1`. We stash the "event to return" in the process dictionary
  # keyed on `:fake_repo_next_event` so each test can control the outcome
  # without needing a real Ecto.Repo / sandbox.
  defmodule FakeRepo do
    def one(_query), do: Process.get(:fake_repo_next_event)
  end

  setup do
    Process.delete(:fake_repo_next_event)
    :ok
  end

  describe "assert_audit_logged/2 happy path" do
    test "passes when latest row matches given map fields" do
      event = %AuditEvent{
        action: "test.event",
        actor_id: "actor-1",
        organization_id: "org-1",
        effective_user_id: "effective-1",
        metadata: %{}
      }

      Process.put(:fake_repo_next_event, event)

      assert assert_audit_logged(
               %{action: "test.event", actor_id: "actor-1"},
               repo: FakeRepo,
               audit_schema: AuditEvent
             ) == true
    end
  end

  describe "assert_audit_logged/2 mismatch path" do
    test "fails with a clear ExUnit.AssertionError when a field does not match" do
      event = %AuditEvent{
        action: "test.event",
        actor_id: "actor-1",
        metadata: %{}
      }

      Process.put(:fake_repo_next_event, event)

      assert_raise ExUnit.AssertionError, ~r/Expected action/, fn ->
        assert_audit_logged(
          %{action: "other.event"},
          repo: FakeRepo,
          audit_schema: AuditEvent
        )
      end
    end
  end

  describe "assert_audit_logged/2 guards" do
    test "raises FunctionClauseError when first arg is not a map" do
      # Guard enforcement: `is_map(expected) and is_list(opts)` must reject
      # a keyword-list passed where the map is expected.
      assert_raise FunctionClauseError, fn ->
        assert_audit_logged(
          [action: "test.event"],
          repo: FakeRepo,
          audit_schema: AuditEvent
        )
      end
    end

    test "raises KeyError when opts is missing :audit_schema" do
      # Delegates to assert_audit_event/2 which does
      # `Keyword.fetch!(opts, :audit_schema)`.
      assert_raise KeyError, fn ->
        assert_audit_logged(%{action: "test.event"}, repo: FakeRepo)
      end
    end
  end

  describe "assert_audit_logged_for_org/2" do
    test "passes when the latest audit event matches the organization id" do
      event = %AuditEvent{
        action: "test.event",
        actor_id: "actor-1",
        organization_id: "org-1",
        metadata: %{}
      }

      Process.put(:fake_repo_next_event, event)

      assert assert_audit_logged_for_org("org-1",
               repo: FakeRepo,
               audit_schema: AuditEvent
             ) == true
    end

    test "raises with a clear message when organization_id does not match" do
      event = %AuditEvent{
        action: "test.event",
        actor_id: "actor-1",
        organization_id: "org-1",
        metadata: %{}
      }

      Process.put(:fake_repo_next_event, event)

      assert_raise ExUnit.AssertionError, ~r/organization_id/, fn ->
        assert_audit_logged_for_org("org-2",
          repo: FakeRepo,
          audit_schema: AuditEvent
        )
      end
    end
  end
end
