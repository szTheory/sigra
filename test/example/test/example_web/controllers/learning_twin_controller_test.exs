defmodule ExampleWeb.LearningTwinControllerTest do
  use ExampleWeb.ConnCase, async: false

  import Example.AccountsFixtures

  alias Example.LearningTwin.Lease
  alias Example.Repo

  setup do
    {_, nil} = Repo.delete_all(Lease)
    :ok
  end

  test "unauthenticated bootstrap remains behind the existing login redirect", %{conn: conn} do
    conn = get(conn, ~p"/app/lesson/bootstrap")

    assert redirected_to(conn) =~ "/users/log_in"
    refute conn.resp_body =~ "Market morning"
  end

  test "derives bootstrap ownership from current scope and rejects a foreign partition", %{
    conn: conn
  } do
    account_a = user_fixture()
    account_b = user_fixture()
    partition_a = "lt_account_a"
    now = DateTime.utc_now() |> DateTime.truncate(:microsecond)
    insert_lease(account_a, partition_a, DateTime.add(now, 1, :hour))

    account_a_response =
      conn
      |> log_in_user(account_a)
      |> get(~p"/app/lesson/bootstrap?account_partition=#{partition_a}")

    assert %{"partition" => ^partition_a, "lesson" => %{"title" => "Market morning"}} =
             json_response(account_a_response, 200)

    account_b_response =
      conn
      |> log_in_user(account_b)
      |> get(~p"/app/lesson/bootstrap?account_partition=#{partition_a}")

    assert %{"outcome" => "unavailable"} = json_response(account_b_response, 403)
    refute response(account_b_response, 403) =~ partition_a
    refute response(account_b_response, 403) =~ account_a.id
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
