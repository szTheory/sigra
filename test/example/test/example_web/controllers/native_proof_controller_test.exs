defmodule ExampleWeb.NativeProofControllerTest do
  use ExampleWeb.ConnCase, async: false

  import Example.AccountsFixtures

  alias Example.Accounts.Auth.AppSessions
  alias Example.Accounts.FirstPartyApps
  alias Example.Accounts.UserAppSessionFamily
  alias Example.Accounts.UserAppLoginAttempt
  alias Example.LearningTwin.{Lease, ReplayReceipt}
  alias Example.Repo

  setup do
    {_, nil} = Repo.delete_all(ReplayReceipt)
    {_, nil} = Repo.delete_all(Lease)
    :ok
  end

  test "native proof profiles are finite, exact, and browser-required" do
    assert FirstPartyApps.profiles() == [
             %{
               id: "ios-native-proof",
               client_ref: "ios-native-proof",
               callback_uris: ["sigra-native-proof://auth/callback"],
               direct_login: :browser_required
             },
             %{
               id: "android-native-proof",
               client_ref: "android-native-proof",
               callback_uris: ["sigra-native-proof://auth/android"],
               direct_login: :browser_required
             }
           ]
  end

  test "bearer app session reaches host-owned native lesson surfaces", %{conn: conn} do
    user = user_fixture()

    assert {:ok, credentials} =
             Sigra.AppSession.issue(AppSessions.sigra_config(), user, "ios-native-proof")

    bootstrap =
      conn |> bearer(credentials.access_token) |> get("/api/native-proof/lesson/bootstrap")

    assert %{"lesson" => %{"title" => "Market morning"}, "partition" => partition} =
             json_response(bootstrap, 200)

    image =
      conn |> bearer(credentials.access_token) |> get("/api/native-proof/lesson/media/image/v1")

    assert image.status == 200
    assert get_resp_header(image, "content-type") == ["image/svg+xml; charset=utf-8"]

    replay =
      conn
      |> bearer(credentials.access_token)
      |> post("/api/native-proof/lesson/replay", replay_params())

    assert %{"status" => "accepted", "client_mutation_id" => "native-mutation"} =
             json_response(replay, 200)

    foreign = user_fixture()

    assert {:ok, other} =
             Sigra.AppSession.issue(AppSessions.sigra_config(), foreign, "ios-native-proof")

    denied =
      conn
      |> bearer(other.access_token)
      |> get("/api/native-proof/lesson/bootstrap?account_partition=#{partition}")

    assert %{"outcome" => "unavailable"} = json_response(denied, 403)
  end

  test "missing, revoked, and superseded access credentials are JSON 401", %{conn: conn} do
    user = user_fixture()

    assert {:ok, credentials} =
             Sigra.AppSession.issue(AppSessions.sigra_config(), user, "android-native-proof")

    assert %{"error" => "unauthenticated"} =
             conn |> get("/api/native-proof/lesson/bootstrap") |> json_response(401)

    assert {:ok, replacement} = AppSessions.refresh(credentials.refresh_token)

    assert %{"error" => "unauthenticated"} =
             conn
             |> bearer(credentials.access_token)
             |> get("/api/native-proof/lesson/bootstrap")
             |> json_response(401)

    assert %{"lesson" => %{}} =
             conn
             |> bearer(replacement.access_token)
             |> get("/api/native-proof/lesson/bootstrap")
             |> json_response(200)

    assert {:ok, _} = AppSessions.revoke_family(user, replacement.family_id)

    assert %{"error" => "unauthenticated"} =
             conn
             |> bearer(replacement.access_token)
             |> get("/api/native-proof/lesson/bootstrap")
             |> json_response(401)
  end

  test "native logout derives and revokes only the current family", %{conn: conn} do
    user = user_fixture()

    assert {:ok, current} =
             Sigra.AppSession.issue(AppSessions.sigra_config(), user, "ios-native-proof")

    assert {:ok, sibling} =
             Sigra.AppSession.issue(AppSessions.sigra_config(), user, "ios-native-proof")

    response = conn |> bearer(current.access_token) |> post("/api/native-proof/logout", %{})
    assert %{"ok" => true} = json_response(response, 200)
    assert Repo.get!(UserAppSessionFamily, current.family_id).revoked_at
    refute Repo.get!(UserAppSessionFamily, sibling.family_id).revoked_at

    assert {:ok, %{family_id: family_id}} =
             Sigra.AppSession.authenticate(AppSessions.sigra_config(), sibling.access_token)

    assert family_id == sibling.family_id
  end

  test "hosted PKCE ceremony exchanges once, rotates, and rejects callback, verifier, and replay" do
    user = user_fixture()
    verifier = String.duplicate("v", 43)
    callback = "sigra-native-proof://auth/callback"
    state = "native-state-248"

    params = %{
      "profile_id" => "ios-native-proof",
      "callback" => callback,
      "state" => state,
      "code_challenge" => Sigra.AppLogin.PKCE.challenge(verifier),
      "code_challenge_method" => "S256"
    }

    assert {:error, :invalid_request} =
             AppSessions.start_hosted(
               Map.put(params, "callback", "sigra-native-proof://auth/android")
             )

    assert {:ok, %{continuation: continuation, approval_required: true}} =
             AppSessions.start_hosted(params)

    assert {:ok, %{code: code, callback: ^callback, state: ^state}} =
             AppSessions.approve_hosted(continuation, user, :approve)

    assert {:error, :invalid_continuation} =
             AppSessions.approve_hosted(continuation, user, :approve)

    assert {:error, :invalid_code} =
             AppSessions.exchange_hosted(
               code,
               String.duplicate("x", 43),
               "ios-native-proof",
               callback
             )

    assert {:ok, credentials} =
             AppSessions.exchange_hosted(code, verifier, "ios-native-proof", callback)

    assert {:error, :invalid_code} =
             AppSessions.exchange_hosted(code, verifier, "ios-native-proof", callback)

    assert {:ok, replacement} = AppSessions.refresh(credentials.refresh_token)
    assert replacement.family_id == credentials.family_id

    assert {:ok, %{family_id: family_id}} =
             Sigra.AppSession.authenticate(AppSessions.sigra_config(), replacement.access_token)

    assert family_id == credentials.family_id
    assert Repo.aggregate(UserAppLoginAttempt, :count) == 1
  end

  test "native return uses server-selected route and exposes no identity or credential", %{
    conn: conn
  } do
    user = user_fixture()

    assert {:ok, credentials} =
             Sigra.AppSession.issue(AppSessions.sigra_config(), user, "android-native-proof")

    response =
      conn
      |> bearer(credentials.access_token)
      |> post("/api/native-proof/return", %{
        "platform" => "android",
        "transport" => "custom_scheme",
        "link_verification" => "not_applicable",
        "callback_binding" => "matched",
        "replay" => "not_seen",
        "native_assertion_ref" => "android-proof-run"
      })

    assert %{"status" => "allow", "session_version" => version} = json_response(response, 200)
    assert is_integer(version)
    assert Map.keys(json_response(response, 200)) |> Enum.sort() == ["session_version", "status"]
    refute response.resp_body =~ user.id
    refute response.resp_body =~ credentials.access_token
    refute response.resp_body =~ credentials.family_id

    smuggled =
      conn
      |> bearer(credentials.access_token)
      |> post("/api/native-proof/return", %{
        "platform" => "android",
        "transport" => "custom_scheme",
        "link_verification" => "not_applicable",
        "callback_binding" => "matched",
        "replay" => "not_seen",
        "native_assertion_ref" => "android-proof-run",
        "route_id" => "client-selected",
        "outcome" => "accepted"
      })

    assert %{"status" => "deny"} = json_response(smuggled, 403)
  end

  test "router exposes no direct-password app-login endpoint" do
    router = File.read!(Path.expand("../../../lib/example_web/router.ex", __DIR__))

    profiles =
      File.read!(Path.expand("../../../lib/example/accounts/first_party_apps.ex", __DIR__))

    refute router =~ "/api/app-login/direct"
    refute router =~ "complete_direct_mfa"
    refute profiles =~ ":password_allowed"
    assert router =~ "Sigra.Plug.FetchAppSession"
    assert router =~ "credential_kind: :app_session"
  end

  test "hosted browser start renders explicit approval and controller exchange is one-time", %{
    conn: conn
  } do
    user = user_fixture()
    verifier = String.duplicate("b", 43)

    approval =
      conn
      |> log_in_user(user)
      |> get("/users/app-login", %{
        "profile_id" => "ios-native-proof",
        "callback" => "sigra-native-proof://auth/callback",
        "state" => "browser-state-248",
        "code_challenge" => Sigra.AppLogin.PKCE.challenge(verifier),
        "code_challenge_method" => "S256"
      })

    assert html_response(approval, 200) =~ ~s(data-testid="app-login-approval")
    csrf_token = Plug.CSRFProtection.get_csrf_token()

    approved =
      approval
      |> recycle()
      |> put_req_header("x-csrf-token", csrf_token)
      |> post("/users/app-login/approve", %{})

    location = get_resp_header(approved, "location") |> List.first()
    assert String.starts_with?(location, "sigra-native-proof://auth/callback?")
    query = location |> URI.parse() |> Map.fetch!(:query) |> URI.decode_query()
    assert query["state"] == "browser-state-248"

    exchange =
      conn
      |> post("/api/app-login/exchange", %{
        "code" => query["code"],
        "code_verifier" => verifier,
        "profile_id" => "ios-native-proof",
        "callback" => "sigra-native-proof://auth/callback"
      })

    assert %{"access_token" => access, "refresh_token" => refresh, "family_id" => family_id} =
             json_response(exchange, 200)

    assert is_binary(access) and is_binary(refresh) and is_binary(family_id)

    replay =
      conn
      |> post("/api/app-login/exchange", %{
        "code" => query["code"],
        "code_verifier" => verifier,
        "profile_id" => "ios-native-proof",
        "callback" => "sigra-native-proof://auth/callback"
      })

    assert %{"error" => "invalid_request"} = json_response(replay, 400)
  end

  defp bearer(conn, access_token),
    do: put_req_header(conn, "authorization", "Bearer " <> access_token)

  defp replay_params do
    %{
      "client_mutation_id" => "native-mutation",
      "idempotency_key" => "native-idempotency",
      "base_checkpoint" => "market-morning-v1",
      "action" => "answer",
      "answer" => "apples"
    }
  end
end
