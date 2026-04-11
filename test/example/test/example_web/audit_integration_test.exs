defmodule ExampleWeb.AuditIntegrationTest do
  @moduledoc """
  B8 (Plan 10.1.1-05) — Locks the fix for the users.id / audit_events.actor_id
  type mismatch that silently dropped every audit insert referencing a user.
  After this plan, `users.id` is `binary_id` so the existing
  `audit_events.actor_id :binary_id` column FK-references it without type
  coercion, and `Sigra.Auth.create_session/4` is able to emit the
  `session.create` audit row via `Sigra.Audit.log_safe/2`.

  Depends on Plan 10.1.1-03 (B6 session store unification) because the audit
  row is written as a side effect of `Sigra.Auth.create_session/4`. If B6 is
  not in place, `UserAuth.log_in_user` never reaches `create_session` and no
  audit row is ever produced.
  """
  use ExampleWeb.ConnCase, async: true

  import Ecto.Query

  alias Example.Accounts
  alias Example.Repo

  @moduletag :example_app

  setup do
    {:ok, user} =
      Accounts.register_user(%{
        email: "b8-#{System.unique_integer([:positive])}@example.test",
        password: "CorrectHorseBattery123!"
      })

    %{user: user}
  end

  describe "B8: audit_events insert on login" do
    test "log_in_user inserts at least one audit_events row", %{conn: conn, user: user} do
      before_count = audit_count()

      conn
      |> Plug.Test.init_test_session(%{})
      |> ExampleWeb.UserAuth.log_in_user(user)

      assert audit_count() > before_count,
             "expected audit_events row count to increase after log_in_user — B8 type mismatch or missing audit wiring"
    end

    test "audit row has action=session.create and matching actor_id", %{
      conn: conn,
      user: user
    } do
      conn
      |> Plug.Test.init_test_session(%{})
      |> ExampleWeb.UserAuth.log_in_user(user)

      row =
        Repo.one(
          from(a in "audit_events",
            where: a.action == "session.create",
            select: %{action: a.action, actor_id: a.actor_id},
            limit: 1
          )
        )

      assert row != nil,
             "expected at least one audit_events row with action=session.create after login"

      assert row.action == "session.create"

      assert row.actor_id == user.id,
             "actor_id mismatch — B8 type mismatch likely still present (got #{inspect(row.actor_id)} vs #{inspect(user.id)})"
    end
  end

  defp audit_count do
    Repo.aggregate(from(a in "audit_events"), :count)
  end
end
