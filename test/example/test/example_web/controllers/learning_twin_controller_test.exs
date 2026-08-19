defmodule ExampleWeb.LearningTwinControllerTest do
  use ExampleWeb.ConnCase, async: false

  import Example.AccountsFixtures

  alias Example.LearningTwin.{Lease, ReplayReceipt}
  alias Example.Repo

  setup do
    {_, nil} = Repo.delete_all(ReplayReceipt)
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

  test "replay requires the authenticated browser CSRF boundary and derives partition from scope", %{
    conn: conn
  } do
    user = user_fixture()
    foreign_user = user_fixture()
    insert_lease(user, "lt_replay", DateTime.add(DateTime.utc_now(), 1, :hour))

    unauthenticated = post(conn, ~p"/app/lesson/replay", replay_params())
    assert redirected_to(unauthenticated) =~ "/users/log_in"
    assert Repo.aggregate(ReplayReceipt, :count) == 0

    foreign =
      conn
      |> log_in_user(foreign_user)
      |> post(~p"/app/lesson/replay", replay_params())

    assert foreign.status in [403, 422]
    assert Repo.aggregate(ReplayReceipt, :count) == 0

    authenticated_conn =
      conn
      |> log_in_user(user)
      |> get(~p"/app/lesson")

    csrf_token = Plug.CSRFProtection.get_csrf_token()

    response =
      authenticated_conn
      |> recycle()
      |> put_req_header("x-csrf-token", csrf_token)
      |> post(~p"/app/lesson/replay", Map.put(replay_params(), "account_partition", "lt_foreign"))

    assert %{"error" => "invalid_replay"} = json_response(response, 422)
    assert Repo.aggregate(ReplayReceipt, :count) == 0
  end

  test "replay exposes only stable learner-safe terminal result fields", %{conn: conn} do
    user = user_fixture()
    insert_lease(user, "lt_response", DateTime.add(DateTime.utc_now(), 1, :hour))

    conn =
      conn
      |> log_in_user(user)
      |> get(~p"/app/lesson")

    csrf_token = Plug.CSRFProtection.get_csrf_token()

    params = replay_params()

    first =
      conn
      |> recycle()
      |> put_req_header("x-csrf-token", csrf_token)
      |> post(~p"/app/lesson/replay", params)

    assert %{
             "status" => "accepted",
             "terminal_at" => terminal_at,
             "client_mutation_id" => "mutation-controller"
           } = json_response(first, 200)

    assert Map.keys(json_response(first, 200)) |> Enum.sort() ==
             ["client_mutation_id", "status", "terminal_at"]

    duplicate =
      conn
      |> recycle()
      |> put_req_header("x-csrf-token", csrf_token)
      |> post(~p"/app/lesson/replay", params)

    assert %{"status" => "accepted", "terminal_at" => ^terminal_at} = json_response(duplicate, 200)
    assert Repo.aggregate(ReplayReceipt, :count) == 1
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

  defp replay_params do
    %{
      "client_mutation_id" => "mutation-controller",
      "idempotency_key" => "idempotency-controller",
      "base_checkpoint" => "market-morning-v1",
      "action" => "answer",
      "answer" => "apples"
    }
  end
end
