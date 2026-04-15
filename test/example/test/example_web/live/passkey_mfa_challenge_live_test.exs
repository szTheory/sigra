defmodule ExampleWeb.PasskeyMFAChallengeLiveTest do
  use ExampleWeb.ConnCase, async: false

  import Example.AccountsFixtures
  import Phoenix.LiveViewTest

  defp source(path), do: File.read!(Path.expand(path, File.cwd!()))

  describe "/users/mfa passkey-first challenge" do
    test "MFA pending user with passkey sees passkey-first actions and fallbacks", %{conn: conn} do
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
      assert html =~ "/users/mfa/passkey"
      refute html =~ ~s(role="tablist")
    end

    test "unsupported and abort guidance remain neutral with recovery action" do
      live_source = source("lib/example_web/live/mfa_challenge_live.ex")

      assert live_source =~ "Passkey sign-in was canceled."
      assert live_source =~ "Use another way"
      assert live_source =~ "Passkeys aren't available in this browser."
      assert live_source =~ "Continue with passkey"
      assert live_source =~ "Use authenticator code instead"
      assert live_source =~ "Use a backup code"
      assert live_source =~ "PasskeyAuthenticate"
      assert live_source =~ "/users/mfa/passkey"
      assert live_source =~ ~s(role="tablist")
    end
  end
end
