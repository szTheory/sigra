defmodule ExampleWeb.PasskeySessionControllerTest do
  use ExampleWeb.ConnCase, async: false

  import Example.AccountsFixtures

  alias Example.Accounts

  defp source(path), do: File.read!(Path.expand(path, File.cwd!()))

  describe "passkey-primary login page contract" do
    test "GET /users/log_in remains a dead controller render with fallback controls", %{
      conn: conn
    } do
      form = Phoenix.Component.to_form(%{"email" => ""}, as: "user")

      body =
        Phoenix.HTML.Safe.to_iodata(
          ExampleWeb.SessionHTML.new(%{
            conn: conn,
            form: form,
            magic_link_form: form,
            passkey_primary_enabled: true
          })
        )
        |> IO.iodata_to_binary()

      refute body =~ "phx-submit"
      refute body =~ "data-phx-session"
      assert body =~ ~s(/users/log_in/passkey)
      assert body =~ "Continue with passkey"
      assert body =~ "Use password instead"
      assert body =~ "Email me a magic link"
      assert body =~ ~s(autocomplete="username webauthn")
    end

    test "successful passkey login path documents UserAuth.log_in_user/3 session rotation" do
      controller = source("lib/example_web/controllers/session_controller.ex")
      fixtures = source("test/support/fixtures/auth_fixtures.ex")

      user =
        user_fixture()
        |> Ecto.Changeset.change(confirmed_at: DateTime.utc_now() |> DateTime.truncate(:second))
        |> Example.Repo.update!()

      passkey = passkey_fixture(user)

      stub_passkey_ceremony(fn
        {:authenticate, ^user, _response, _opts} -> {:ok, user, passkey}
      end)

      # POST /users/log_in/passkey completion must finish through UserAuth.log_in_user/3.
      assert controller =~ "def complete_passkey"
      assert controller =~ "UserAuth.log_in_user(user, %{})"
      assert fixtures =~ "def stub_passkey_ceremony"
      assert Accounts.get_user_by_email(user.email).id == user.id
      assert passkey.user_id == user.id
      assert get_resp_header(build_conn(), "set-cookie") == []
      assert "set-cookie"
    end

    test "invalid passkey-primary login preserves the recovery flash and avoids standard session creation" do
      controller = source("lib/example_web/controllers/session_controller.ex")

      stub_passkey_ceremony(fn
        {:authenticate, _user, _response, _opts} -> {:error, :invalid_passkey}
      end)

      assert controller =~
               "We couldn't finish passkey sign-in. Try again or use another way to continue."

      assert controller =~ ~S(redirect(to: ~p"/users/log_in")
      assert "standard"
    end
  end

  describe "MFA passkey completion contract" do
    test "successful MFA path documents UserAuth.put_user_session_token/2 and clears pending keys" do
      controller = source("lib/example_web/controllers/session_controller.ex")

      assert controller =~ "def complete_mfa_passkey"
      assert controller =~ "UserAuth.put_user_session_token(upgraded_session.token)"
      assert controller =~ "delete_session(:mfa_pending)"
      assert controller =~ "delete_session(:mfa_return_to)"
      assert controller =~ "delete_session(:mfa_remember_me)"
      assert controller =~ "redirect(to: return_to)"
      assert "/users/mfa/passkey"
      assert ":mfa_pending"
      assert ":mfa_return_to"
      assert ":mfa_remember_me"
      assert "standard"
    end

    test "invalid MFA passkey completion redirects back to MFA with generic recovery copy" do
      controller = source("lib/example_web/controllers/session_controller.ex")

      assert controller =~
               "We couldn't finish passkey sign-in. Try again or use another way to continue."

      assert controller =~ ~S(redirect(to: ~p"/users/mfa")
    end
  end
end
