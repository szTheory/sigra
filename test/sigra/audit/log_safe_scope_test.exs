defmodule Sigra.Audit.LogSafeScopeTest do
  @moduledoc """
  Wave 0 tests for `Sigra.Audit.log_safe/3` scope-aware emission.

  Created as failing stubs by Plan 15-01 Task 0; un-skipped by Plan 15-01
  Task 1 once `log_safe/3` is implemented.

  These tests use an in-process capture repo to observe the changeset that
  `log_safe/3` passes to `Repo.insert/1`, then assert on the cast changes.
  That gives us real coverage of scope_fields + changeset merge without
  requiring a live database.
  """
  use ExUnit.Case, async: true

  alias Sigra.Test.AuditEvent, as: AuditTestEvent

  defmodule Scope do
    @moduledoc false
    defstruct [:user, :active_organization, :membership, :impersonating_from]
  end

  defmodule CaptureRepo do
    @moduledoc false
    # Captures the changeset passed to insert/1 and replies via send/2.

    def insert(%Ecto.Changeset{} = cs) do
      send(self(), {:captured_changeset, cs})

      if cs.valid? do
        row = Ecto.Changeset.apply_changes(cs)
        {:ok, Map.put(row, :id, Ecto.UUID.generate())}
      else
        {:error, cs}
      end
    end
  end

  defp base_opts do
    [
      repo: CaptureRepo,
      audit_schema: AuditTestEvent,
      actor_type: "user",
      metadata: %{},
      occurred_at: DateTime.utc_now()
    ]
  end

  defp captured_changes! do
    receive do
      {:captured_changeset, cs} -> cs.changes
    after
      0 -> flunk("no changeset captured by CaptureRepo")
    end
  end

  @tag :skip
  test "log_safe/3 with nil scope writes nil organization_id + nil effective_user_id" do
    assert :ok = Sigra.Audit.log_safe("test.nil_scope", nil, base_opts())

    changes = captured_changes!()
    assert changes.action == "test.nil_scope"
    # nil values are NOT cast onto the changeset (Ecto drops nil casts); their
    # absence means the column is written as NULL, which is the invariant.
    refute Map.has_key?(changes, :organization_id)
    refute Map.has_key?(changes, :effective_user_id)
  end

  @tag :skip
  test "log_safe/3 with full scope writes organization_id from scope.active_organization.id and effective_user_id from scope.user.id" do
    user_id = Ecto.UUID.generate()
    org_id = Ecto.UUID.generate()

    scope = %Scope{
      user: %{id: user_id},
      active_organization: %{id: org_id},
      membership: nil,
      impersonating_from: nil
    }

    assert :ok = Sigra.Audit.log_safe("test.full_scope", scope, base_opts())

    changes = captured_changes!()
    assert changes.organization_id == org_id
    assert changes.effective_user_id == user_id
    assert changes.actor_id == user_id
  end

  @tag :skip
  test "log_safe/3 duck-types scope on %{user, active_organization, impersonating_from} keys (no Sigra.Scope struct match)" do
    user_id = Ecto.UUID.generate()
    org_id = Ecto.UUID.generate()

    # Plain map — not a Sigra.Scope struct. log_safe/3 must still extract
    # ids via duck typing per D-03.
    scope = %{
      user: %{id: user_id},
      active_organization: %{id: org_id},
      impersonating_from: nil
    }

    assert :ok = Sigra.Audit.log_safe("test.duck_scope", scope, base_opts())

    changes = captured_changes!()
    assert changes.organization_id == org_id
    assert changes.effective_user_id == user_id
  end

  @tag :skip
  test "log_safe/3 caller-supplied :organization_id in opts wins over scope-derived value (D-06 caller-wins merge)" do
    user_id = Ecto.UUID.generate()
    scope_org_id = Ecto.UUID.generate()
    override_org_id = Ecto.UUID.generate()

    scope = %Scope{
      user: %{id: user_id},
      active_organization: %{id: scope_org_id},
      membership: nil,
      impersonating_from: nil
    }

    opts = Keyword.put(base_opts(), :organization_id, override_org_id)
    assert :ok = Sigra.Audit.log_safe("test.caller_wins", scope, opts)

    changes = captured_changes!()
    assert changes.organization_id == override_org_id
    refute changes.organization_id == scope_org_id
  end
end
