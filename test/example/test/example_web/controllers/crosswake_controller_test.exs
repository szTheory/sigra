defmodule ExampleWeb.CrosswakeControllerTest do
  use ExampleWeb.ConnCase, async: false

  import Example.AccountsFixtures

  @moduletag :example_app

  @tag :crosswake_runtime_tracer
  test "crosswake_runtime_tracer: local AuthReturn state and PKCE correlation permits one same-session return",
       %{conn: conn} do
    user = user_fixture()
    evaluator = fn route, context, opts ->
      send(self(), {:crosswake_evaluator_called, route, context, opts})
      {:allow, %{}}
    end

    Application.put_env(:example, :crosswake_evaluator, evaluator)

    on_exit(fn ->
      Application.delete_env(:example, :crosswake_evaluator)
    end)

    start_conn =
      conn
      |> log_in_user(user)
      |> post(~p"/crosswake/start")

    assert start_conn.status == 303

    location = redirected_to(start_conn)
    %URI{path: "/crosswake/return", query: query} = URI.parse(location)
    params = URI.decode_query(query)

    assert Map.keys(params) |> Enum.sort() == ["continuation", "pkce_verifier", "state"]

    return_conn = get(start_conn, ~p"/crosswake/return?#{query}")

    assert return_conn.status == 303
    assert redirected_to(return_conn) == ~p"/app"

    assert_receive {:crosswake_evaluator_called, route, context,
                    [expected_session_version: session_version]}

    assert route.id == "crosswake-hosted-account"
    assert route.path == "/app"
    assert context.org_id == nil
    assert is_integer(session_version)
  end
end
