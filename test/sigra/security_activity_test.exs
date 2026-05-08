defmodule Sigra.SecurityActivityTest do
  use ExUnit.Case, async: true

  alias Sigra.SecurityActivity

  defmodule TestAuditEvent do
    use Ecto.Schema

    @primary_key {:id, :binary_id, autogenerate: false}
    schema "audit_events" do
      field :action, :string
      field :outcome, :string
      field :ip_address, :string
      field :metadata, :map
      field :target_id, :binary_id
      field :effective_user_id, :binary_id
      field :inserted_at, :utc_datetime_usec
    end
  end

  defmodule TestSession do
    use Ecto.Schema

    @primary_key {:id, :binary_id, autogenerate: false}
    schema "user_sessions" do
      field :type, :string
      field :ip, :string
      field :geo_city, :string
      field :geo_country_code, :string
    end
  end

  defmodule StubRepo do
    @moduledoc false

    def reset do
      Process.put({__MODULE__, :audit_rows}, [])
      Process.put({__MODULE__, :session_rows}, [])
      Process.put({__MODULE__, :queries}, [])
    end

    def put_audit_rows(rows), do: Process.put({__MODULE__, :audit_rows}, rows)
    def put_session_rows(rows), do: Process.put({__MODULE__, :session_rows}, rows)
    def queries, do: Enum.reverse(Process.get({__MODULE__, :queries}, []))

    def all(%Ecto.Query{} = query) do
      Process.put({__MODULE__, :queries}, [query | Process.get({__MODULE__, :queries}, [])])

      case query.from.source do
        {"audit_events", TestAuditEvent} -> Process.get({__MODULE__, :audit_rows}, [])
        {"user_sessions", TestSession} -> Process.get({__MODULE__, :session_rows}, [])
      end
    end
  end

  @config %Sigra.Config{
    repo: StubRepo,
    user_schema: Sigra.TestUser,
    session: [session_schema: TestSession],
    audit: [audit_schema: TestAuditEvent]
  }

  setup do
    StubRepo.reset()
    :ok
  end

  test "builds a subject-scoped deterministic descending query" do
    now = DateTime.utc_now()

    StubRepo.put_audit_rows([
      %TestAuditEvent{
        id: "evt-1",
        action: "session.revoke_others",
        outcome: "success",
        target_id: "user-1",
        effective_user_id: "user-1",
        inserted_at: now,
        metadata: %{}
      }
    ])

    _rows = SecurityActivity.list_recent_activity(@config, "user-1", limit: 5)

    [audit_query] = StubRepo.queries()
    assert audit_query.limit.expr == {:^, [], [0]}
    assert audit_query.limit.params |> hd() |> elem(0) == 15

    order_text =
      audit_query.order_bys
      |> Enum.map(&Macro.to_string(&1.expr))
      |> Enum.join("\n")

    assert order_text =~ "inserted_at"
    assert order_text =~ "id"

    where_text =
      audit_query.wheres
      |> Enum.map(&Macro.to_string(&1.expr))
      |> Enum.join("\n")

    assert where_text =~ "effective_user_id"
    assert where_text =~ "target_id"
    assert where_text =~ "action"
  end

  test "normalizes labels, keeps bounded metadata, and suppresses duplicate MFA sign-in rows" do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    StubRepo.put_audit_rows([
      %TestAuditEvent{
        id: "evt-logout",
        action: "auth.logout",
        outcome: "success",
        ip_address: "4.4.4.4",
        target_id: "user-1",
        effective_user_id: "user-1",
        inserted_at: now,
        metadata: %{session_id: "session-1", type: :standard}
      },
      %TestAuditEvent{
        id: "evt-mfa",
        action: "auth.mfa_verified",
        outcome: "success",
        target_id: "user-1",
        effective_user_id: "user-1",
        inserted_at: DateTime.add(now, -1, :second),
        metadata: %{session_id: "session-2", type: :remember_me}
      },
      %TestAuditEvent{
        id: "evt-session-create",
        action: "session.create",
        outcome: "success",
        ip_address: "3.3.3.3",
        target_id: "user-1",
        effective_user_id: "user-1",
        inserted_at: DateTime.add(now, -2, :second),
        metadata: %{session_id: "session-2", type: :remember_me}
      },
      %TestAuditEvent{
        id: "evt-suspicious",
        action: "security.suspicious_login",
        outcome: "failure",
        ip_address: "9.9.9.9",
        target_id: "user-1",
        effective_user_id: "user-1",
        inserted_at: DateTime.add(now, -3, :second),
        metadata: %{geo_city: "Berlin", geo_country_code: "DE"}
      }
    ])

    StubRepo.put_session_rows([
      %TestSession{id: "session-1", type: "standard", ip: "4.4.4.4"},
      %TestSession{id: "session-2", type: "remember_me", ip: "3.3.3.3"}
    ])

    rows = SecurityActivity.list_recent_activity(@config, "user-1", limit: 10)

    assert Enum.map(rows, & &1.action) == [
             "auth.logout",
             "auth.mfa_verified",
             "security.suspicious_login"
           ]

    assert Enum.map(rows, & &1.action_label) == [
             "Signed out",
             "Completed multi-factor verification",
             "Suspicious sign-in attempt"
           ]

    assert Enum.map(rows, & &1.kind) == [:logout, :mfa_verified, :suspicious_login]
    assert Enum.all?(rows, &(Map.keys(&1) -- ~w(action action_label geo_city geo_country_code id ip_address kind occurred_at outcome session_id session_type)a == []))
    assert Enum.at(rows, 1).session_type in [:remember_me, "remember_me"]
    assert Enum.at(rows, 2).geo_city == "Berlin"
    assert Enum.at(rows, 2).geo_country_code == "DE"
  end
end
