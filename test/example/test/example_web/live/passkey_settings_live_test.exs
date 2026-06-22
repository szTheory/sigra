defmodule ExampleWeb.PasskeySettingsLiveTest do
  use ExampleWeb.ConnCase, async: false

  import Example.AccountsFixtures
  import Phoenix.LiveViewTest
  import Swoosh.TestAssertions

  alias Example.Accounts
  alias Example.Accounts.UserPasskey
  alias Example.Accounts.UserSession
  alias Example.Repo

  setup :ensure_passkey_config_secret

  describe "/users/settings/mfa passkey management" do
    test "logged-in user sees passkeys card, empty state, and no raw metadata", %{conn: conn} do
      user = user_fixture()
      passkey_fixture(user)

      {:ok, _view, html} =
        conn
        |> log_in_with_sudo(user)
        |> live("/users/settings/mfa")

      assert html =~ ~s(id="passkeys")
      assert html =~ "Passkeys"
      assert html =~ "Add passkey"
      assert html =~ "Use Face ID, Touch ID, Windows Hello"
      assert html =~ "Test passkey"
      refute html =~ "credential_id"
      refute html =~ "rp_id"
      refute html =~ "transports"
    end

    test "empty state renders No passkeys added yet", %{conn: conn} do
      user = user_fixture()

      {:ok, _view, html} =
        conn
        |> log_in_with_sudo(user)
        |> live("/users/settings/mfa")

      assert html =~ "No passkeys added yet"
    end

    test "stale sudo rejects enrollment options and completion without changing passkeys", %{
      conn: conn
    } do
      user = user_fixture()
      before_count = Accounts.passkey_count_for_user(user)

      conn =
        conn
        |> log_in_user(user)
        |> post(~p"/users/settings/mfa/passkeys/options")

      assert redirected_to(conn) =~ "/users/sudo"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "Please re-enter your password to continue."

      assert Accounts.passkey_count_for_user(user) == before_count

      conn =
        build_conn()
        |> log_in_user(user)
        |> post(~p"/users/settings/mfa/passkeys", %{
          "passkey" => %{"response" => encoded_passkey_response()}
        })

      assert redirected_to(conn) =~ "/users/sudo"
      assert Accounts.passkey_count_for_user(user) == before_count
    end

    test "fresh sudo enrollment completion inserts passkey and sends registration notification",
         %{
           conn: conn
         } do
      user = user_fixture()
      before_count = Accounts.passkey_count_for_user(user)

      conn =
        conn
        |> log_in_with_sudo(user)
        |> issue_passkey_challenge(:registration)

      stub_passkey_ceremony(fn
        {:register, ^user, _response, _opts} ->
          {:ok, passkey_fixture(user, nickname: "MacBook Touch ID")}
      end)

      conn =
        post(conn, ~p"/users/settings/mfa/passkeys", %{
          "passkey" => %{"response" => encoded_passkey_response()}
        })

      assert redirected_to(conn) == ~p"/users/settings/mfa#passkeys"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) == "Passkey added."
      assert Accounts.passkey_count_for_user(user) == before_count + 1

      assert_email_sent(fn email ->
        assert email.subject =~ "New passkey added"
        assert email.text_body =~ "A new passkey was added to your account"
      end)
    end

    test "duplicate enrollment through real route preserves count and shows duplicate copy", %{
      conn: conn
    } do
      user = user_fixture()
      passkey_fixture(user)
      before_count = Accounts.passkey_count_for_user(user)

      conn =
        conn
        |> log_in_with_sudo(user)
        |> issue_passkey_challenge(:registration)

      stub_passkey_ceremony(fn
        {:register, ^user, _response, _opts} -> {:error, :duplicate_passkey}
      end)

      conn =
        post(conn, ~p"/users/settings/mfa/passkeys", %{
          "passkey" => %{"response" => encoded_passkey_response()}
        })

      assert redirected_to(conn) == ~p"/users/settings/mfa#passkeys"

      assert Phoenix.Flash.get(conn.assigns.flash, :warning) ==
               "This passkey is already registered."

      assert Accounts.passkey_count_for_user(user) == before_count
    end

    test "fresh sudo cap rejection through completion route preserves count", %{conn: conn} do
      user = user_fixture()

      for index <- 1..10 do
        passkey_fixture(user,
          credential_id: "credential-cap-#{index}",
          nickname: "Passkey #{index}"
        )
      end

      before_count = Accounts.passkey_count_for_user(user)

      conn =
        conn
        |> log_in_with_sudo(user)
        |> issue_passkey_challenge(:registration)

      stub_passkey_ceremony(fn
        {:register, ^user, _response, _opts} ->
          {:error, :passkey_cap_reached}
      end)

      conn =
        post(conn, ~p"/users/settings/mfa/passkeys", %{
          "passkey" => %{"response" => encoded_passkey_response()}
        })

      assert redirected_to(conn) == ~p"/users/settings/mfa#passkeys"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "We couldn't finish adding this passkey. Try again or use another way to continue."

      assert Accounts.passkey_count_for_user(user) == before_count
    end

    test "delete route rejects stale sudo and deletes row with fresh sudo", %{conn: conn} do
      user = user_fixture()
      passkey = passkey_fixture(user)
      encoded_id = Base.url_encode64(passkey.credential_id, padding: false)

      conn =
        conn
        |> log_in_user(user)
        |> post(~p"/users/settings/mfa/passkeys/#{encoded_id}/delete")

      assert redirected_to(conn) =~ "/users/sudo"
      assert Repo.get(UserPasskey, passkey.id)

      conn =
        build_conn()
        |> log_in_with_sudo(user)
        |> post(~p"/users/settings/mfa/passkeys/#{encoded_id}/delete")

      assert redirected_to(conn) == ~p"/users/settings/mfa#passkeys"

      assert Phoenix.Flash.get(conn.assigns.flash, :info) ==
               "Last passkey deleted. Next time, sign in with your password, authenticator code, backup code, or magic link until you add another passkey."

      refute Repo.get(UserPasskey, passkey.id)
    end

    test "rename event saves the new passkey name in the database", %{conn: conn} do
      user = user_fixture()
      passkey = passkey_fixture(user, nickname: "Old name")
      encoded_id = Base.url_encode64(passkey.credential_id, padding: false)

      {:ok, view, _html} =
        conn
        |> log_in_with_sudo(user)
        |> live("/users/settings/mfa")

      assert render_click(view, "open_passkey_rename", %{"id" => encoded_id}) =~
               "Old name"

      assert render_submit(view, "save_passkey_name", %{
               "passkey" => %{"id" => encoded_id, "nickname" => "Travel key"}
             }) =~ "Travel key"

      assert Repo.reload!(passkey).nickname == "Travel key"
    end

    test "delete confirmation warns when removing the last passkey", %{conn: conn} do
      user = user_fixture()
      passkey = passkey_fixture(user, nickname: "Laptop key")
      encoded_id = Base.url_encode64(passkey.credential_id, padding: false)

      {:ok, view, _html} =
        conn
        |> log_in_with_sudo(user)
        |> live("/users/settings/mfa")

      html =
        render_click(view, "confirm_passkey_delete", %{"id" => encoded_id})

      assert html =~ "Delete this passkey?"
      assert html =~ "last recovery option."
      assert html =~ "You&#39;re removing your last passkey."
      assert html =~ "password, authenticator code, backup code, or magic link."
    end
  end

  defp log_in_with_sudo(conn, user) do
    conn = log_in_user(conn, user)
    token = Plug.Conn.get_session(conn, :user_token)
    {^user, session} = Accounts.get_user_and_session_by_token(token)

    UserSession
    |> Repo.get_by!(hashed_token: session.hashed_token)
    |> Ecto.Changeset.change(sudo_at: DateTime.utc_now())
    |> Repo.update!()

    conn
  end

  defp issue_passkey_challenge(conn, ceremony) do
    conn =
      if conn.private[:plug_session] do
        conn
      else
        Phoenix.ConnTest.init_test_session(conn, %{})
      end

    bytes = "test-#{ceremony}-challenge"

    {conn, _challenge} =
      Sigra.Plug.PasskeyChallenge.issue(conn, ceremony, Sigra.Passkeys.config(), bytes: bytes)

    conn
  end

  defp ensure_passkey_config_secret(_context) do
    old_config = Application.get_env(:example, :sigra_config)
    old_otp_app = Application.get_env(:sigra, :otp_app)

    Application.put_env(:sigra, :otp_app, :example)

    Application.put_env(
      :example,
      :sigra_config,
      Keyword.put(old_config, :secret_key_base, ExampleWeb.Endpoint.config(:secret_key_base))
    )

    Sigra.Passkeys.reset_cached_config()

    on_exit(fn ->
      restore_env(:sigra, :otp_app, old_otp_app)
      restore_env(:example, :sigra_config, old_config)
      Sigra.Passkeys.reset_cached_config()
    end)

    :ok
  end

  defp restore_env(app, key, nil), do: Application.delete_env(app, key)
  defp restore_env(app, key, value), do: Application.put_env(app, key, value)
end
