defmodule ExampleWeb.ThreadlineForwarderTest do
  @moduledoc """
  Integration test proving the full Sigra → Threadline audit projection chain.

  Drives a real login via ExampleWeb.UserAuth.log_in_user/2, then asserts that
  the resulting Sigra session.create audit event materializes as a real
  Threadline.Semantics.AuditAction row joined on correlation_id == audit_event.id.

  The forwarder is attached in test setup (the example Application never calls
  Sigra.Application.attach_forwarders/0). dispatch: :sync ensures the inline
  insert lands on the SQL Sandbox-owned connection before the query runs.
  """
  use ExampleWeb.ConnCase, async: true

  import Ecto.Query

  alias Example.{Accounts, Repo}
  alias Example.Accounts.AuditEvent
  alias Threadline.Semantics.AuditAction

  @moduletag :example_app

  setup do
    # Register BEFORE attaching the forwarder so registration-time events are
    # not forwarded (per RESEARCH Open Question 2).
    {:ok, user} =
      Accounts.register_user(%{
        email: "tl-#{System.unique_integer([:positive])}@example.test",
        password: "CorrectHorseBattery123!"
      })

    # Sigra.Application.attach_forwarders/0 already attached a :default handler
    # at boot (because config.exs carries the forwarders: block). Explicitly
    # detach it before re-attaching with dispatch: :sync and repo: Example.Repo
    # so there is exactly one handler during the test (prevents double projection).
    :telemetry.detach({Sigra.Audit.Forwarders.Threadline, :default})

    # Attach with dispatch: :sync (D-06) and repo: Example.Repo (D-08) so the
    # inline record_action/2 call lands on the SQL Sandbox-owned connection.
    :ok =
      Sigra.Audit.Forwarders.Threadline.attach(
        repo: Example.Repo,
        id: :test,
        dispatch: :sync,
        actor_type: :user
      )

    on_exit(fn -> :telemetry.detach({Sigra.Audit.Forwarders.Threadline, :test}) end)

    %{user: user}
  end

  test "login audit event materializes as a Threadline audit_actions row",
       %{conn: conn, user: user} do
    # Act — drive the real auth path (not a direct Sigra.Audit call)
    conn
    |> Plug.Test.init_test_session(%{})
    |> ExampleWeb.UserAuth.log_in_user(user)

    # Assert source row exists — gives the join key audit_event.id
    audit_event =
      Repo.one(
        from a in AuditEvent,
          where: a.action == "session.create" and a.actor_id == ^user.id,
          order_by: [desc: a.inserted_at],
          limit: 1
      )

    assert audit_event, "no Sigra audit row for session.create — forwarder has nothing to project"

    # Assert projection row materialized — joined on correlation_id (the join key)
    action =
      Repo.one(from a in AuditAction, where: a.correlation_id == ^audit_event.id)

    assert action, "Threadline audit_actions row did not materialize"
    assert action.name == "session.create"
    assert action.status == :ok
    assert action.actor_ref.id == user.id
    assert action.actor_ref.type == :user
  end
end
