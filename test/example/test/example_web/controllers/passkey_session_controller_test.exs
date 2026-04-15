defmodule ExampleWeb.PasskeySessionControllerTest do
  use ExampleWeb.ConnCase, async: false

  import Ecto.Query, only: [from: 2]
  import Example.AccountsFixtures

  alias Example.Accounts
  alias Example.Accounts.UserSession
  alias Example.Repo

  setup :ensure_passkey_config_secret

  describe "passkey-primary login page" do
    test "GET /users/log_in remains a dead controller render with fallback controls", %{
      conn: conn
    } do
      conn = get(conn, ~p"/users/log_in")
      body = html_response(conn, 200)

      refute body =~ "phx-submit"
      refute body =~ "data-phx-session"
      assert body =~ ~s(id="passkey_login_form")
      assert body =~ ~s(action="/users/log_in/passkey")
      assert body =~ "Continue with passkey"
      assert body =~ "Use password instead"
      assert body =~ "Email me a magic link"
      assert body =~ ~s(autocomplete="username webauthn")
    end

    test "successful passkey login rotates the Plug session and authenticates the next request",
         %{
           conn: conn
         } do
      user =
        user_fixture()
        |> Ecto.Changeset.change(confirmed_at: DateTime.utc_now() |> DateTime.truncate(:second))
        |> Repo.update!()

      passkey = passkey_fixture(user)

      conn = issue_passkey_challenge(conn, :authentication)

      stub_passkey_ceremony(fn
        {:authenticate, authenticated_user, _response, _opts} ->
          assert authenticated_user.id == user.id
          {:ok, authenticated_user, passkey}
      end)

      conn =
        post(conn, ~p"/users/log_in/passkey", %{
          "user" => %{"email" => user.email},
          "passkey" => %{
            "response" => encoded_passkey_response(%{credential_id: passkey.credential_id})
          }
        })

      assert redirected_to(conn) == ~p"/"
      assert get_resp_header(conn, "set-cookie") != []

      user_token = Plug.Conn.get_session(conn, :user_token)
      assert is_binary(user_token)
      assert Accounts.get_user_by_session_token(user_token).id == user.id

      follow_up_conn = get(recycle(conn), ~p"/users/log_in")
      assert redirected_to(follow_up_conn) == ~p"/"
    end

    test "invalid passkey-primary login redirects with recovery copy and no standard session", %{
      conn: conn
    } do
      user =
        user_fixture()
        |> Ecto.Changeset.change(confirmed_at: DateTime.utc_now() |> DateTime.truncate(:second))
        |> Repo.update!()

      passkey = passkey_fixture(user)

      conn = issue_passkey_challenge(conn, :authentication)

      stub_passkey_ceremony(fn
        {:authenticate, authenticated_user, _response, _opts} ->
          assert authenticated_user.id == user.id
          {:error, :invalid_passkey}
      end)

      conn =
        post(conn, ~p"/users/log_in/passkey", %{
          "user" => %{"email" => user.email},
          "passkey" => %{
            "response" => encoded_passkey_response(%{credential_id: passkey.credential_id})
          }
        })

      assert redirected_to(conn) == ~p"/users/log_in"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "We couldn't finish passkey sign-in. Try again or use another way to continue."

      refute Plug.Conn.get_session(conn, :user_token)
    end
  end

  describe "MFA passkey completion" do
    test "successful MFA passkey completion writes upgraded session and clears pending keys", %{
      conn: conn
    } do
      %{user: user} = mfa_pending_session_fixture()
      passkey = passkey_fixture(user)

      conn =
        conn
        |> log_in_with_mfa_pending_session(user)
        |> assign(:current_scope, Example.Accounts.Scope.for_user(user))
        |> put_private(:sigra_session, mfa_pending_sigra_session(user))
        |> put_session(:mfa_pending, true)
        |> put_session(:mfa_return_to, "/users/settings")
        |> put_session(:mfa_remember_me, true)
        |> issue_passkey_challenge(:authentication)
        |> Phoenix.Controller.fetch_flash()

      stub_passkey_ceremony(fn
        {:authenticate, authenticated_user, _response, _opts} ->
          assert authenticated_user.id == user.id
          {:ok, authenticated_user, passkey}
      end)

      conn =
        ExampleWeb.SessionController.complete_mfa_passkey(conn, %{
          "passkey" => %{
            "response" => encoded_passkey_response(%{credential_id: passkey.credential_id})
          }
        })

      assert redirected_to(conn) == "/users/settings"
      refute Plug.Conn.get_session(conn, :mfa_pending)
      refute Plug.Conn.get_session(conn, :mfa_return_to)
      refute Plug.Conn.get_session(conn, :mfa_remember_me)

      user_token = Plug.Conn.get_session(conn, :user_token)
      assert is_binary(user_token)
      assert {_user, %{type: :remember_me}} = Accounts.get_user_and_session_by_token(user_token)
    end

    test "invalid MFA passkey completion redirects back to MFA with generic recovery copy", %{
      conn: conn
    } do
      %{user: user} = mfa_pending_session_fixture()
      passkey = passkey_fixture(user)

      conn =
        conn
        |> log_in_with_mfa_pending_session(user)
        |> put_session(:mfa_pending, true)
        |> issue_passkey_challenge(:authentication)

      stub_passkey_ceremony(fn
        {:authenticate, authenticated_user, _response, _opts} ->
          assert authenticated_user.id == user.id
          {:error, :invalid_passkey}
      end)

      conn =
        post(conn, ~p"/users/mfa/passkey", %{
          "passkey" => %{
            "response" => encoded_passkey_response(%{credential_id: passkey.credential_id})
          }
        })

      assert redirected_to(conn) == ~p"/users/mfa"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "We couldn't finish passkey sign-in. Try again or use another way to continue."
    end
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

  defp log_in_with_mfa_pending_session(conn, user) do
    raw_token = :crypto.strong_rand_bytes(32)
    session_token = Base.url_encode64(raw_token, padding: false)
    now = DateTime.utc_now()

    %UserSession{}
    |> Ecto.Changeset.change(%{
      user_id: user.id,
      hashed_token: Sigra.Token.hash_token(raw_token),
      type: "mfa_pending",
      ip: "127.0.0.1",
      user_agent: "ExUnit/1.0",
      last_active_at: now,
      inserted_at: now
    })
    |> Repo.insert!()

    conn
    |> Phoenix.ConnTest.init_test_session(%{})
    |> put_session(:user_token, session_token)
  end

  defp mfa_pending_sigra_session(user) do
    db_session =
      from(s in UserSession,
        where: s.user_id == ^user.id and s.type == "mfa_pending",
        order_by: [desc: s.inserted_at],
        limit: 1
      )
      |> Repo.one!()

    %Sigra.Session{
      id: db_session.id,
      user_id: user.id,
      hashed_token: db_session.hashed_token,
      type: :mfa_pending,
      ip: db_session.ip,
      user_agent: db_session.user_agent,
      last_active_at: db_session.last_active_at,
      inserted_at: db_session.inserted_at
    }
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
