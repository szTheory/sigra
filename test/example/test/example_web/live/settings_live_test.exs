defmodule ExampleWeb.SettingsLiveTest do
  @moduledoc """
  E2E coverage of the email-change confirmation route a real user hits:
  `/users/settings/confirm-email/:token`. Regression guard for 260622-nft, where
  clicking the confirmation link always showed "invalid or has expired".

  A successful confirm invalidates the user's sessions (D-07), so the success
  path is asserted via the redirect + the persisted email change; the failure
  path (which does not touch the session) is asserted via the rendered flash.
  """
  use ExampleWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Example.Accounts
  alias Example.Accounts.User
  alias Example.Repo

  setup :register_and_log_in_user

  defp new_email, do: "confirmed#{System.unique_integer([:positive])}@example.com"

  describe "/users/settings/confirm-email/:token" do
    test "a valid token confirms the change and updates the email", %{conn: conn, user: user} do
      target = new_email()
      {:ok, _user, token} = Accounts.request_email_change(user, target)

      # Visiting the confirm route applies the change and redirects to settings.
      assert {:error, {:live_redirect, %{to: to}}} =
               live(conn, ~p"/users/settings/confirm-email/#{token}")

      assert to == ~p"/users/settings"

      # The email actually changed — the regression this guards against.
      assert Repo.get!(User, user.id).email == target
    end

    test "an invalid token shows the error flash and leaves the email unchanged",
         %{conn: conn, user: user} do
      result = live(conn, ~p"/users/settings/confirm-email/this-is-not-a-valid-token")

      assert {:ok, _lv, html} = follow_redirect(result, conn)
      assert html =~ "invalid or has expired"

      assert Repo.get!(User, user.id).email == user.email
    end
  end
end
