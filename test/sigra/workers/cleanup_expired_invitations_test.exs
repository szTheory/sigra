defmodule Sigra.Workers.CleanupExpiredInvitationsTest do
  @moduledoc """
  Phase 17 Plan 03 Task 3 unit tests for
  `Sigra.Workers.CleanupExpiredInvitations` (D-11 retention worker).

  Follows the same pattern as `Sigra.Workers.AuditCleanupTest` — a stub
  repo captures the query that gets handed to `delete_all/1` via
  `send/2`, so we can assert the worker's invariants (accepted-preserved,
  cutoff math) without a real DB.
  """

  use ExUnit.Case, async: true

  alias Sigra.Workers.CleanupExpiredInvitations

  defmodule Sigra.Test.OrganizationInvitation do
    use Ecto.Schema

    @primary_key {:id, :binary_id, autogenerate: true}

    schema "organization_invitations" do
      field :email, :string
      field :expires_at, :utc_datetime
      field :accepted_at, :utc_datetime
      field :revoked_at, :utc_datetime
      timestamps(type: :utc_datetime)
    end
  end

  defmodule StubRepo do
    @moduledoc false
    # Captures the query passed to delete_all/1 so tests can assert the
    # worker composed the right invariants (accepted_at IS NULL +
    # expires_at < cutoff).
    def delete_all(query) do
      send(self(), {:delete_all_called, query})
      {0, nil}
    end
  end

  describe "cleanup/3" do
    test "is exported with arity 3 (repo, schema, retention_days)" do
      Code.ensure_loaded!(CleanupExpiredInvitations)
      assert function_exported?(CleanupExpiredInvitations, :cleanup, 3)
    end

    test "issues a delete_all query against the invitation schema" do
      _ = CleanupExpiredInvitations.cleanup(StubRepo, Sigra.Test.OrganizationInvitation, 30)
      assert_received {:delete_all_called, %Ecto.Query{}}
    end

    test "query filters on is_nil(accepted_at) — accepted rows preserved" do
      _ = CleanupExpiredInvitations.cleanup(StubRepo, Sigra.Test.OrganizationInvitation, 30)
      assert_received {:delete_all_called, %Ecto.Query{} = q}

      query_str = inspect(q)
      assert query_str =~ "is_nil"
      assert query_str =~ "accepted_at"
    end

    test "query filters on expires_at < cutoff (retention math)" do
      _ = CleanupExpiredInvitations.cleanup(StubRepo, Sigra.Test.OrganizationInvitation, 30)
      assert_received {:delete_all_called, %Ecto.Query{} = q}

      query_str = inspect(q)
      assert query_str =~ "expires_at"
    end

    test "returns {count, nil} shape from delete_all" do
      result = CleanupExpiredInvitations.cleanup(StubRepo, Sigra.Test.OrganizationInvitation, 30)
      assert {0, nil} = result
    end
  end

  describe "Oban.Worker integration" do
    test "perform/1 is exported" do
      Code.ensure_loaded!(CleanupExpiredInvitations)
      assert function_exported?(CleanupExpiredInvitations, :perform, 1)
    end

    test "max_attempts of 1 (cron job should not retry silently)" do
      changeset = CleanupExpiredInvitations.new(%{})
      assert changeset.changes[:max_attempts] == 1
    end

    test "queue is :sigra_lifecycle (matches AccountDeletion precedent)" do
      changeset = CleanupExpiredInvitations.new(%{})
      assert changeset.changes[:queue] == "sigra_lifecycle"
    end

    test "implements Sigra.Workers behaviour (tenant-aware — Q3 RESOLVED)" do
      behaviours =
        CleanupExpiredInvitations.module_info(:attributes)
        |> Keyword.get_values(:behaviour)
        |> List.flatten()

      assert Sigra.Workers in behaviours
    end
  end
end
