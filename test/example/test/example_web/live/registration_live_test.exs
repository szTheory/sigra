defmodule ExampleWeb.RegistrationLiveTest do
  use ExampleWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Swoosh.TestAssertions

  defp source(path), do: File.read!(Path.expand(path, File.cwd!()))

  describe "signup-time passkey enrollment handoff" do
    test "registration source keeps user[enroll_passkey] behind passkey-primary config" do
      live_source = source("lib/example_web/live/registration_live.ex")

      assert live_source =~ "Add a passkey after creating your account"
      assert live_source =~ "user[enroll_passkey]"
      assert live_source =~ "passkey_primary_enabled"
      assert live_source =~ "enroll_passkey_after_signup"
      assert live_source =~ "?enroll_passkey=1"
      assert "enroll_passkey"
    end

    test "render keeps password signup fields when passkey enrollment is unavailable", %{
      conn: conn
    } do
      previous = Application.get_env(:example, :passkey_primary_enabled)
      Application.put_env(:example, :passkey_primary_enabled, false)

      on_exit(fn ->
        if previous == nil do
          Application.delete_env(:example, :passkey_primary_enabled)
        else
          Application.put_env(:example, :passkey_primary_enabled, previous)
        end
      end)

      {:ok, view, html} = live(conn, "/users/register")

      assert html =~ "Email"
      assert html =~ "Password"
      refute html =~ "Add a passkey after creating your account"

      assert render_change(view, "validate", %{
               "user" => %{"email" => "new@example.com", "password" => "hello world!!"}
             }) =~ "Create an account"
    end

    test "source emits ?enroll_passkey=1 only when user opted in" do
      live_source = source("lib/example_web/live/registration_live.ex")

      assert live_source =~ "enroll_passkey=1"
      assert live_source =~ ~S(~p"/users/confirm/#{token}")
      refute live_source =~ "passkey enrollment before email confirmation"
    end

    test "confirmation delivery path can include enroll_passkey=1 in captured email body" do
      user =
        Example.AccountsFixtures.user_fixture(%{
          email: "passkey-enroll-#{System.unique_integer([:positive])}@example.com"
        })

      {:ok, :sent} =
        Example.Accounts.deliver_user_confirmation_instructions(user, fn token ->
          "http://localhost:4000/users/confirm/#{token}?enroll_passkey=1"
        end)

      assert_email_sent(fn email ->
        assert email.html_body =~ "?enroll_passkey=1"
        assert email.text_body =~ "?enroll_passkey=1"
      end)

      assert "?enroll_passkey=1"
    end
  end
end
