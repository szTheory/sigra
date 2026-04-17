defmodule Sigra.Admin.Audit.QueryTest do
  use ExUnit.Case, async: false

  alias Ecto.Adapters.SQL
  alias Sigra.Admin.Audit.Query
  alias Sigra.Admin.Audit.QueryParams
  alias Sigra.Admin.Scope

  @repo Sigra.Test.PostgresRepo

  defmodule AuditEvent do
    use Ecto.Schema

    @primary_key {:id, :binary_id, autogenerate: false}
    schema "admin_audit_query_events" do
      field :action, :string
      field :outcome, :string
      field :actor_id, :binary_id
      field :target_id, :binary_id
      field :target_type, :string
      field :organization_id, :binary_id
      field :effective_user_id, :binary_id
      timestamps(type: :utc_datetime_usec, updated_at: false)
    end
  end

  setup_all do
    start_supervised!({@repo, @repo.default_config()})

    SQL.query!(
      @repo,
      """
      CREATE TABLE IF NOT EXISTS admin_audit_query_events (
        id uuid PRIMARY KEY,
        action text NOT NULL,
        outcome text,
        actor_id uuid,
        target_id uuid,
        target_type text,
        organization_id uuid,
        effective_user_id uuid,
        inserted_at timestamp NOT NULL
      )
      """,
      []
    )

    :ok
  end

  setup do
    SQL.query!(@repo, "TRUNCATE TABLE admin_audit_query_events RESTART IDENTITY CASCADE", [])

    org_id = Ecto.UUID.generate()
    subject_user_id = Ecto.UUID.generate()
    actor_id = Ecto.UUID.generate()
    other_user_id = Ecto.UUID.generate()

    insert_event(%{
      id: Ecto.UUID.generate(),
      action: "session.create",
      actor_id: actor_id,
      effective_user_id: subject_user_id,
      organization_id: org_id
    })

    insert_event(%{
      id: Ecto.UUID.generate(),
      action: "session.delete",
      actor_id: actor_id,
      target_id: subject_user_id,
      effective_user_id: subject_user_id,
      organization_id: org_id
    })

    insert_event(%{
      id: Ecto.UUID.generate(),
      action: "auth.login.success",
      actor_id: other_user_id,
      effective_user_id: other_user_id,
      organization_id: org_id
    })

    %{
      org_id: org_id,
      actor_id: actor_id,
      subject_user_id: subject_user_id,
      other_user_id: other_user_id,
      global_scope: global_scope(),
      org_scope: org_scope(org_id)
    }
  end

  describe "subject-user queries" do
    test "include rows matched through effective_user_id as well as target_id", %{
      subject_user_id: subject_user_id
    } do
      results =
        AuditEvent
        |> Query.for_subject_user(subject_user_id)
        |> @repo.all()

      assert Enum.map(results, & &1.action) |> Enum.sort() == ["session.create", "session.delete"]
    end

    test "do not leak rows where the user is neither effective nor target" do
      uninvolved_user_id = Ecto.UUID.generate()

      results =
        AuditEvent
        |> Query.for_subject_user(uninvolved_user_id)
        |> @repo.all()

      assert results == []
    end
  end

  describe "normalize/2" do
    test "keeps only the shared explorer/export filter contract", %{actor_id: actor_id, org_scope: org_scope} do
      params = %{
        "actor" => actor_id,
        "effective_user" => Ecto.UUID.generate(),
        "organization" => org_scope.organization_id,
        "action_prefix" => "session.",
        "outcome" => "success",
        "from" => "2026-04-15T12:00:00Z",
        "to" => "2026-04-16T12:00:00Z",
        "cursor" => Sigra.Audit.Cursor.encode(~U[2026-04-16 12:00:00Z], Ecto.UUID.generate()),
        "page_size" => "75",
        "subject_user" => Ecto.UUID.generate(),
        "unknown" => "widen-me"
      }

      assert {:ok, normalized} = QueryParams.normalize(params, org_scope)
      refute Map.has_key?(normalized, :unknown)
      refute Map.has_key?(normalized, "unknown")
      assert normalized.actor_id == actor_id
      assert normalized.organization_scope == {:only, org_scope.organization_id}
      assert normalized.action_prefix == "session."
      assert normalized.outcome == "success"
      assert %DateTime{} = normalized.from
      assert %DateTime{} = normalized.to
      assert {%DateTime{}, _id} = normalized.cursor
      assert normalized.limit == 75
      assert normalized.subject_user_id
    end

    test "rejects malformed cursors instead of widening the query", %{global_scope: global_scope} do
      assert {:error, {:cursor, :invalid}} =
               QueryParams.normalize(%{"cursor" => "not-a-valid-cursor"}, global_scope)
    end

    test "reuses the same normalized output for explorer and export callers", %{actor_id: actor_id, global_scope: global_scope} do
      params = %{"actor" => actor_id, "page_size" => "25", "action_prefix" => "session."}

      assert {:ok, normalized} = QueryParams.normalize(params, global_scope)

      assert normalized == %{
               actor_id: actor_id,
               action_prefix: "session.",
               cursor: nil,
               limit: 25
             }
    end

    test "rejects malformed actor UUIDs instead of widening to all actors", %{global_scope: global_scope} do
      assert {:error, {:actor_id, :invalid}} =
               QueryParams.normalize(%{"actor" => "not-a-uuid"}, global_scope)
    end

    test "rejects malformed effective_user UUIDs instead of widening", %{global_scope: global_scope} do
      assert {:error, {:effective_user_id, :invalid}} =
               QueryParams.normalize(%{"effective_user" => "nope"}, global_scope)
    end

    test "rejects malformed organization UUIDs at the global scope", %{global_scope: global_scope} do
      assert {:error, {:organization_id, :invalid}} =
               QueryParams.normalize(%{"organization" => "bogus"}, global_scope)
    end

    test "rejects malformed subject_user UUIDs rather than silently ignoring them", %{global_scope: global_scope} do
      assert {:error, {:subject_user_id, :invalid}} =
               QueryParams.normalize(%{"subject_user" => "??"}, global_scope)
    end

    test "rejects malformed ISO-8601 date ranges on `from`", %{global_scope: global_scope} do
      assert {:error, {:from, :invalid}} =
               QueryParams.normalize(%{"from" => "yesterday"}, global_scope)
    end

    test "rejects malformed ISO-8601 date ranges on `to`", %{global_scope: global_scope} do
      assert {:error, {:to, :invalid}} =
               QueryParams.normalize(%{"to" => "never"}, global_scope)
    end

    test "rejects zero or negative page_size rather than treating it as a default", %{global_scope: global_scope} do
      assert {:error, {:page_size, :invalid}} =
               QueryParams.normalize(%{"page_size" => "0"}, global_scope)

      assert {:error, {:page_size, :invalid}} =
               QueryParams.normalize(%{"page_size" => "-10"}, global_scope)
    end

    test "rejects page_size above the maximum even if it parses as an integer", %{global_scope: global_scope} do
      assert {:error, {:page_size, :invalid}} =
               QueryParams.normalize(%{"page_size" => "101"}, global_scope)
    end

    test "rejects non-integer page_size instead of silently falling back to default", %{global_scope: global_scope} do
      assert {:error, {:page_size, :invalid}} =
               QueryParams.normalize(%{"page_size" => "ten"}, global_scope)
    end

    test "collapses org-admin scope onto the resolved organization id regardless of missing param", %{org_scope: org_scope} do
      assert {:ok, normalized} = QueryParams.normalize(%{"actor" => nil}, org_scope)

      assert normalized.organization_scope == {:only, org_scope.organization_id}
      refute Map.has_key?(normalized, :organization_id)
    end

    test "denies an org admin attempt to cross-scope by supplying a different organization filter", %{org_scope: org_scope} do
      other_org_id = Ecto.UUID.generate()

      assert {:error, {:organization, :out_of_scope}} =
               QueryParams.normalize(%{"organization" => other_org_id}, org_scope)
    end

    test "strips empty-string filters so empty inputs do not widen or constrain queries", %{global_scope: global_scope} do
      params = %{
        "actor" => "",
        "effective_user" => "",
        "organization" => "",
        "action" => "",
        "action_prefix" => "",
        "outcome" => "",
        "from" => "",
        "to" => "",
        "cursor" => "",
        "page_size" => "",
        "subject_user" => ""
      }

      assert {:ok, normalized} = QueryParams.normalize(params, global_scope)

      assert normalized == %{cursor: nil, limit: 25}
    end
  end

  defp insert_event(attrs) do
    now = DateTime.utc_now()

    @repo.insert!(struct!(AuditEvent, Map.put_new(attrs, :inserted_at, now)))
  end

  defp global_scope do
    %Scope{
      mode: :global,
      scope: %{user: %{id: Ecto.UUID.generate()}},
      organization: nil,
      organization_id: nil,
      organization_slug: nil,
      platform_admin?: true,
      admin_org_ids: []
    }
  end

  defp org_scope(org_id) do
    %Scope{
      mode: :organization,
      scope: %{user: %{id: Ecto.UUID.generate()}},
      organization: %{id: org_id, name: "Acme Ops", slug: "acme"},
      organization_id: org_id,
      organization_slug: "acme",
      platform_admin?: false,
      admin_org_ids: [org_id]
    }
  end
end
