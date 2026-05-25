defmodule ExampleWeb.PasskeyMFAChallengeLiveTest do
  use ExampleWeb.ConnCase, async: false

  import Example.AccountsFixtures
  import Phoenix.LiveViewTest

  describe "/users/mfa passkey-first challenge" do
    test "MFA pending user with passkey sees passkey-first actions and real route targets", %{
      conn: conn
    } do
      %{user: user} = mfa_pending_session_fixture()
      passkey_fixture(user)

      conn =
        conn
        |> log_in_user(user, type: :mfa_pending)
        |> put_session(:mfa_pending, true)

      {:ok, _view, html} = live(conn, "/users/mfa")

      assert html =~ "Continue with passkey"
      assert html =~ "Use authenticator code instead"
      assert html =~ "Use a backup code"
      assert html =~ "PasskeyAuthenticate"
      assert html =~ ~s(action="/users/mfa/passkey")
      refute html =~ ~s(role="tablist")

      assert route_info("POST", "/users/mfa/passkey/options").plug_opts == :passkey_mfa_options
      assert route_info("POST", "/users/mfa/passkey").plug_opts == :complete_mfa_passkey
    end

    test "unsupported and abort guidance remain MFA-truthful with recovery action", %{conn: conn} do
      %{user: user} = mfa_pending_session_fixture()
      passkey_fixture(user)

      conn =
        conn
        |> log_in_user(user, type: :mfa_pending)
        |> put_session(:mfa_pending, true)

      {:ok, view, _html} = live(conn, "/users/mfa")

      assert render_click(view, "begin_passkey_authentication") =~ "Waiting for passkey"

      html = render_hook(view, "sigra:passkey-authenticate:aborted", %{})

      assert html =~ "Nothing changed."
      assert html =~ "Try again or use another way."

      html =
        render_hook(view, "sigra:passkey-authenticate:error", %{
          "name" => "NotSupportedError",
          "message" => "unsupported"
        })

      assert html =~ "Use another way"
      assert html =~ "Passkeys aren"
      assert html =~ "available in this browser."

      assert html =~
               "Use your authenticator code, a backup code, or a device/browser that supports passkeys."

      assert html =~ "Continue with passkey"
      assert html =~ "Use authenticator code instead"
      assert html =~ "Use a backup code"
      refute html =~ "password"
      refute html =~ "magic link"
      refute html =~ "NotSupportedError"
      refute html =~ ~s(role="tablist")
    end
  end

  defp route_info(method, path) do
    Phoenix.Router.route_info(ExampleWeb.Router, method, path, "localhost")
  end
end
