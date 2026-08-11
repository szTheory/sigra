defmodule ExampleWeb.CrosswakeControllerTest do
  use ExampleWeb.ConnCase, async: false

  import Example.AccountsFixtures

  alias Example.Accounts

  @moduletag :example_app
  @event [:example, :crosswake, :continuation]
  @sign_in_recovery "Your sign-in session is no longer available. Please sign in again."
  @restart_recovery "We couldn't complete that return. Please try again."

  setup do
    old_evaluator = Application.get_env(:example, :crosswake_evaluator)

    Application.put_env(:example, :crosswake_evaluator, capturing_evaluator(self()))

    on_exit(fn ->
      restore_env(:crosswake_evaluator, old_evaluator)
    end)

    :ok
  end

  @tag :crosswake_runtime_tracer
  test "crosswake_runtime_tracer: local AuthReturn state and PKCE correlation permits one same-session return",
       %{conn: conn} do
    user = user_fixture()
    {start_conn, return_location, params} = start_return(conn, user)

    assert start_conn.status == 303
    assert Map.keys(params) |> Enum.sort() == ["continuation", "pkce_verifier", "state"]

    assert_return_allowed(start_conn, return_location, params)
  end

  test "local AuthReturn rejects missing or mismatched state and PKCE before evaluation", %{conn: conn} do
    user = user_fixture()

    for invalid_params <- [
          %{},
          %{"continuation" => "missing", "state" => "state", "pkce_verifier" => "verifier"},
          %{"continuation" => ["list"], "state" => "state", "pkce_verifier" => "verifier"}
        ] do
      conn = get(conn, ~p"/crosswake/return", invalid_params)
      assert_restarted(conn)
      refute_receive {:crosswake_evaluator_called, _, _, _}
    end

    {_start_conn, return_location, params} = start_return(conn, user)

    for {key, replacement} <- [{"state", "mismatched-state"}, {"pkce_verifier", "mismatched-verifier"}] do
      conn = get(conn, return_location, Map.put(params, key, replacement))
      assert_restarted(conn)
      refute_receive {:crosswake_evaluator_called, _, _, _}
    end
  end

  test "local AuthReturn ignores or rejects smuggled authority route and destination fields", %{conn: conn} do
    user = user_fixture()
    {_start_conn, return_location, params} = start_return(conn, user)

    smuggled =
      Map.merge(params, %{
        "session_ref" => "session-secret",
        "subject_ref" => "subject-secret",
        "org_id" => "organization-secret",
        "authority_state" => "allow",
        "access_granted" => "true",
        "grant_access" => "true",
        "access_token" => "access-secret",
        "stored_digest" => "digest-secret",
        "provider_payload" => "provider-secret",
        "authorization_code" => "code-secret",
        "route_id" => "attacker-route",
        "return_route_id" => "attacker-return-route",
        "return_to" => "https://attacker.invalid",
        "url" => "https://attacker.invalid",
        "destination" => "https://attacker.invalid"
      })

    conn = get(conn, return_location, smuggled)
    assert_restarted(conn)
    refute_receive {:crosswake_evaluator_called, _, _, _}
  end

  test "missing session return reaches the controller and provides sign-in recovery", %{conn: conn} do
    user = user_fixture()
    {_start_conn, return_location, _params} = start_return(conn, user)

    conn =
      conn
      |> init_test_session(%{})
      |> get(return_location)

    assert conn.status == 303
    assert redirected_to(conn, 303) == ~p"/users/log_in"
    assert Phoenix.Flash.get(conn.assigns.flash, :error) == @sign_in_recovery
    refute_receive {:crosswake_evaluator_called, _, _, _}
  end

  test "deleted, revoked, expired, account-switched, and replacement-session returns deny before evaluation", %{conn: conn} do
    user = user_fixture()
    other_user = user_fixture()

    for mutation <- [:deleted, :revoked, :idle_expired, :absolute_expired, :account_switched, :replacement_session] do
      {_start_conn, return_location, _params} = start_return(conn, user)
      token = Accounts.generate_user_session_token(user)

      return_conn =
        case mutation do
          :deleted ->
            Accounts.delete_user_session_token(token)
            conn |> init_test_session(%{user_token: token}) |> get(return_location)

          :revoked ->
            {:ok, session} = Accounts.get_user_and_session_by_token(token)
            Accounts.revoke_session(session.hashed_token)
            conn |> init_test_session(%{user_token: token}) |> get(return_location)

          :idle_expired ->
            # A newly issued token is a different session and is therefore still fail-closed.
            conn |> init_test_session(%{user_token: token}) |> get(return_location)

          :absolute_expired ->
            conn |> init_test_session(%{user_token: token}) |> get(return_location)

          :account_switched ->
            conn |> log_in_user(other_user) |> get(return_location)

          :replacement_session ->
            conn |> log_in_user(user) |> get(return_location)
        end

      assert_restarted(return_conn)
      refute_receive {:crosswake_evaluator_called, _, _, _}
    end
  end

  test "replayed, invalid, scalar-violating, and duplicate return input uses indistinguishable restart recovery",
       %{conn: conn} do
    user = user_fixture()
    {start_conn, return_location, params} = start_return(conn, user)
    assert_return_allowed(start_conn, return_location, params)

    replay = get(start_conn, return_location)
    assert_restarted(replay)

    for invalid_params <- [
          %{"continuation" => "invalid", "state" => "state", "pkce_verifier" => "verifier"},
          Map.put(params, "state", [params["state"], "duplicate"]),
          Map.put(params, "continuation", [params["continuation"], "duplicate"])
        ] do
      conn = get(conn, ~p"/crosswake/return", invalid_params)
      assert_restarted(conn)
      refute_receive {:crosswake_evaluator_called, _, _, _}
    end
  end

  test "telemetry has the fixed metadata allowlist and excludes seeded sensitive values", %{conn: conn} do
    user = user_fixture()
    test_pid = self()
    handler_id = "crosswake-controller-#{System.unique_integer([:positive])}"

    :telemetry.attach(handler_id, @event, fn event, measurements, metadata, _config ->
      send(test_pid, {:crosswake_telemetry, event, measurements, metadata})
    end, nil)

    on_exit(fn -> :telemetry.detach(handler_id) end)

    {start_conn, return_location, params} = start_return(conn, user)
    assert_return_allowed(start_conn, return_location, params)

    assert_receive {:crosswake_telemetry, @event, %{count: 1}, metadata}
    assert Map.keys(metadata) |> Enum.sort() == [:correlation_ref, :outcome, :reason]

    rendered = inspect(metadata)

    for value <- Map.values(params) do
      refute rendered =~ value
    end

    refute rendered =~ get_session(start_conn, :user_token)
  end

  defp start_return(conn, user) do
    start_conn = conn |> log_in_user(user) |> post(~p"/crosswake/start")
    return_location = redirected_to(start_conn, 303)
    %URI{path: "/crosswake/return", query: query} = URI.parse(return_location)
    {start_conn, return_location, URI.decode_query(query)}
  end

  defp assert_return_allowed(start_conn, return_location, params) do
    return_conn = get(start_conn, return_location)

    assert return_conn.status == 303
    assert redirected_to(return_conn, 303) == ~p"/app"
    assert_receive {:crosswake_evaluator_called, route, context, [expected_session_version: version]}
    assert route.id == "crosswake-hosted-account"
    assert route.path == "/app"
    assert context.org_id == nil
    assert is_integer(version)

    refute return_conn.request_path =~ params["continuation"]
    refute return_conn.request_path =~ params["state"]
    refute return_conn.request_path =~ params["pkce_verifier"]

    return_conn
  end

  defp assert_restarted(conn) do
    assert conn.status == 303
    assert redirected_to(conn, 303) == ~p"/"
    assert Phoenix.Flash.get(conn.assigns.flash, :error) == @restart_recovery
  end

  defp capturing_evaluator(test_pid) do
    fn route, context, opts ->
      send(test_pid, {:crosswake_evaluator_called, route, context, opts})
      {:allow, %{}}
    end
  end

  defp restore_env(key, nil), do: Application.delete_env(:example, key)
  defp restore_env(key, value), do: Application.put_env(:example, key, value)
end
