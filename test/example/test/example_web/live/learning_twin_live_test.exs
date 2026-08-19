defmodule ExampleWeb.LearningTwinLiveTest do
  use ExampleWeb.ConnCase, async: false

  import Example.AccountsFixtures
  import Phoenix.LiveViewTest

  alias Example.LearningTwin.Lease
  alias Example.Repo

  @expired_copy "Offline study has expired. Connect and sign in to continue."

  setup do
    {_, nil} = Repo.delete_all(Lease)
    :ok
  end

  test "redirects unauthenticated visitors without lesson payload", %{conn: conn} do
    assert {:error, {:redirect, %{to: path}}} = live(conn, ~p"/app/lesson")
    assert path =~ "/users/log_in"
  end

  test "renders only the current account lesson and does not expose bootstrap credentials", %{
    conn: conn
  } do
    user = user_fixture()
    conn = log_in_user(conn, user)

    {:ok, _view, html} = live(conn, ~p"/app/lesson")

    assert html =~ ~s(data-testid="twin-lesson")
    assert html =~ "Market morning"
    refute html =~ "account_partition"
    refute html =~ "sha256"
    refute html =~ user.id
    refute html =~ "user_token"
    refute html =~ "access_token"
  end

  test "replaces expired or foreign partition content and focuses its heading", %{conn: conn} do
    account_a = user_fixture()
    account_b = user_fixture()
    partition_a = "lt_account_a"
    now = DateTime.utc_now() |> DateTime.truncate(:microsecond)
    insert_lease(account_a, partition_a, now)

    {:ok, _expired_view, expired_html} =
      conn
      |> log_in_user(account_a)
      |> live(~p"/app/lesson?account_partition=#{partition_a}")

    assert expired_html =~ @expired_copy
    assert expired_html =~ ~s(id="twin-expired-heading")
    assert expired_html =~ ~s(tabindex="-1")
    refute expired_html =~ "twin-lesson"
    refute expired_html =~ "Market morning"
    refute expired_html =~ "twin-replay-receipts"

    {:ok, _foreign_view, foreign_html} =
      conn
      |> log_in_user(account_b)
      |> live(~p"/app/lesson?account_partition=#{partition_a}")

    assert foreign_html =~ @expired_copy
    refute foreign_html =~ "Market morning"
    refute foreign_html =~ partition_a
    refute foreign_html =~ account_a.id
  end

  defp insert_lease(user, partition, expires_at) do
    now = DateTime.utc_now() |> DateTime.truncate(:microsecond)

    Repo.insert!(%Lease{
      user_id: user.id,
      account_partition: partition,
      issued_at: now,
      expires_at: expires_at
    })
  end
end
