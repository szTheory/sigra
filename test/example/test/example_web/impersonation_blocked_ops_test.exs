defmodule ExampleWeb.ImpersonationBlockedOpsTest do
  use ExampleWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Example.Accounts
  alias Example.AccountsFixtures
  alias ExampleWeb.UserAuth

  describe "controller and LiveView mutations while impersonating" do
    setup %{conn: conn} do
      admin = AccountsFixtures.user_fixture(%{email: "platform-admin-blocked@example.com"})
      user = AccountsFixtures.user_fixture()

      conn =
        conn
        |> log_in_user(admin)
        |> impersonate_as(user, admin)

      %{conn: conn, admin: admin, user: user}
    end

    test "blocks passkey registration with explicit feedback", %{conn: conn} do
      conn =
        post(conn, ~p"/users/settings/mfa/passkeys", %{
          "passkey" => %{"id" => "credential-id"}
        })

      assert redirected_to(conn) == ~p"/users/settings/mfa#passkeys"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "while impersonating"
    end

    test "blocks passkey rename and MFA disable LiveView events", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/users/settings/mfa")

      assert view
             |> render_submit("disable_mfa", %{"disable" => %{"code" => "123456"}}) =~
               "while impersonating"

      assert view
             |> render_submit("save_passkey_name", %{
               "passkey" => %{"credential_id" => "cred", "nickname" => "Renamed"}
             }) =~ "while impersonating"
    end
  end

  describe "direct accounts mutations while impersonating" do
    setup do
      admin = AccountsFixtures.user_fixture(%{email: "platform-admin-direct@example.com"})
      user = AccountsFixtures.user_fixture()

      %{admin: admin, user: user}
    end

    test "rejects password, MFA, passkey, and reactivation operations", %{admin: admin, user: user} do
      scope = %{user: user, impersonating_from: admin}

      assert {:error, :impersonation_forbidden} =
               apply(Accounts, :update_user_password, [
                 user,
                 "hello world!",
                 %{
                   current_password: "hello world!",
                   password: "new valid password",
                   password_confirmation: "new valid password"
                 },
                 [scope: scope]
               ])

      assert {:error, :impersonation_forbidden} =
               Accounts.mfa_disable(user, "123456", scope: scope)

      assert {:error, :impersonation_forbidden} =
               Accounts.register_passkey(user, %{"id" => "cred"}, %{scope: scope})

      assert {:error, :impersonation_forbidden} =
               apply(Accounts, :rename_passkey, [user, "cred", "Renamed", [scope: scope]])

      assert {:error, :impersonation_forbidden} =
               apply(Accounts, :delete_passkey, [user, "cred", [scope: scope]])

      assert {:error, :impersonation_forbidden} =
               apply(Accounts, :schedule_deletion, [user, [scope: scope]])
    end
  end

  defp impersonate_as(conn, user, admin) do
    impersonation_token = Accounts.generate_user_session_token(user)
    admin_token = Accounts.generate_user_session_token(admin)

    conn
    |> UserAuth.begin_impersonation(impersonation_token, admin_token, return_to: "/admin/users")
    |> recycle()
    |> fetch_session()
    |> UserAuth.fetch_current_scope([])
  end
end
