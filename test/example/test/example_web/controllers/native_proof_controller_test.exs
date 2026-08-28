defmodule ExampleWeb.NativeProofControllerTest do
  use ExampleWeb.ConnCase, async: false

  import Example.AccountsFixtures

  alias Example.Accounts.Auth.AppSessions
  alias Example.Accounts.FirstPartyApps
  alias Example.Accounts.UserAppSessionFamily
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
    assert {:ok, credentials} = Sigra.AppSession.issue(AppSessions.sigra_config(), user, "ios-native-proof")

    bootstrap = conn |> bearer(credentials.access_token) |> get("/api/native-proof/lesson/bootstrap")
    assert %{"lesson" => %{"title" => "Market morning"}, "partition" => partition} = json_response(bootstrap, 200)

    image = conn |> bearer(credentials.access_token) |> get("/api/native-proof/lesson/media/image/v1")
    assert image.status == 200
    assert get_resp_header(image, "content-type") == ["image/svg+xml; charset=utf-8"]

    replay =
      conn
      |> bearer(credentials.access_token)
      |> post("/api/native-proof/lesson/replay", replay_params())

    assert %{"status" => "accepted", "client_mutation_id" => "native-mutation"} = json_response(replay, 200)

    foreign = user_fixture()
    assert {:ok, other} = Sigra.AppSession.issue(AppSessions.sigra_config(), foreign, "ios-native-proof")

    denied =
      conn
      |> bearer(other.access_token)
      |> get("/api/native-proof/lesson/bootstrap?account_partition=#{partition}")

    assert %{"outcome" => "unavailable"} = json_response(denied, 403)
  end

  test "missing, revoked, and superseded access credentials are JSON 401", %{conn: conn} do
    user = user_fixture()
    assert {:ok, credentials} = Sigra.AppSession.issue(AppSessions.sigra_config(), user, "android-native-proof")

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
    assert {:ok, current} = Sigra.AppSession.issue(AppSessions.sigra_config(), user, "ios-native-proof")
    assert {:ok, sibling} = Sigra.AppSession.issue(AppSessions.sigra_config(), user, "ios-native-proof")

    response = conn |> bearer(current.access_token) |> post("/api/native-proof/logout", %{})
    assert %{"ok" => true} = json_response(response, 200)
    assert Repo.get!(UserAppSessionFamily, current.family_id).revoked_at
    refute Repo.get!(UserAppSessionFamily, sibling.family_id).revoked_at

    assert {:ok, %{family_id: family_id}} = Sigra.AppSession.authenticate(AppSessions.sigra_config(), sibling.access_token)
    assert family_id == sibling.family_id
  end

  defp bearer(conn, access_token), do: put_req_header(conn, "authorization", "Bearer " <> access_token)

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
