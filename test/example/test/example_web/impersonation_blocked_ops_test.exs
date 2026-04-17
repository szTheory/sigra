defmodule ExampleWeb.ImpersonationBlockedOpsTest do
  use ExampleWeb.ConnCase, async: true

  alias Example.Accounts
  alias Example.AccountsFixtures
  alias Example.Accounts.UserSession
  alias Example.Repo
  alias ExampleWeb.MFASettingsLive
  alias Phoenix.LiveView.Socket

  describe "controller and LiveView mutations while impersonating" do
    setup %{conn: conn} do
      admin = AccountsFixtures.user_fixture(%{email: "platform-admin-blocked@example.com"})
      %{user: user} = AccountsFixtures.mfa_user_fixture()
      passkey = AccountsFixtures.passkey_fixture(user)

      conn =
        conn
        |> log_in_user(admin)
        |> impersonate_as(user, admin)

      %{conn: conn, admin: admin, user: user, passkey: passkey}
    end

    test "blocks passkey registration with explicit feedback", %{conn: conn} do
      conn =
        post(conn, ~p"/users/settings/mfa/passkeys", %{
          "passkey" => %{"id" => "credential-id"}
        })

      assert redirected_to(conn) == ~p"/users/settings/mfa#passkeys"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "while impersonating"
    end

    test "blocks passkey rename LiveView events", %{user: user, passkey: passkey, admin: admin} do
      socket = impersonating_socket(user, admin)

      assert {:noreply, socket} =
               MFASettingsLive.handle_event(
                 "save_passkey_name",
                 %{"passkey" => %{"id" => passkey.credential_id, "nickname" => "Renamed"}},
                 socket
               )

      assert Phoenix.Flash.get(socket.assigns.flash, :error) =~ "while impersonating"

      assert Enum.any?(Accounts.passkeys_for_user(user), fn credential ->
               credential.credential_id == passkey.credential_id and
                 credential.nickname == passkey.nickname
             end)
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
               apply(Accounts, :cancel_deletion, [user, [scope: scope]])
    end
  end

  defp impersonate_as(conn, user, admin) do
    impersonation_token = Accounts.generate_user_session_token(user)
    admin_token = Accounts.generate_user_session_token(admin)

    {_user, session} = Accounts.get_user_and_session_by_token(impersonation_token)

    UserSession
    |> Repo.get_by!(hashed_token: session.hashed_token)
    |> Ecto.Changeset.change(sudo_at: DateTime.utc_now())
    |> Repo.update!()

    Plug.Test.init_test_session(conn, %{
      user_token: impersonation_token,
      impersonator_user_token: admin_token,
      impersonation_return_to: "/admin/users"
    })
  end

  defp impersonating_socket(user, admin) do
    %Socket{
      assigns: %{
        __changed__: %{},
        current_scope: %{user: user, impersonating_from: admin},
        flash: %{}
      }
    }
  end
end
