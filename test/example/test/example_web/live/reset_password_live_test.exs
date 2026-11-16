defmodule ExampleWeb.ResetPasswordLiveTest do
  @moduledoc """
  Regression suite for the password reset request page (`/users/reset-password`).

  The request page answers every submitted address with one flash and one redirect,
  whether or not the address belongs to an account. Two defects used to keep it from
  mounting and delivering at all: the route carried no `:new` live action (mount raised
  a `CaseClauseError`), and the submit handler passed a user struct to a context
  function whose only head takes a binary email (a `FunctionClauseError` for an
  existing account). These tests fail by name if either regresses.
  """
  use ExampleWeb.ConnCase, async: false

  import Ecto.Query, only: [from: 2]
  import Example.AccountsFixtures
  import Phoenix.LiveViewTest

  @moduletag :example_app

  @flash "If your email is in our system, you will receive reset instructions shortly."

  defp route_info(method, path),
    do: Phoenix.Router.route_info(ExampleWeb.Router, method, path, "localhost")

  # The reset_password tokens stored for one account, read straight from the repo.
  defp reset_tokens(filter) do
    Example.Repo.all(
      from(t in Example.Accounts.UserToken,
        where: t.context == "reset_password",
        where: ^filter
      )
    )
  end

  defp submit_request(conn, email) do
    {:ok, view, _html} = live(conn, ~p"/users/reset-password")

    view
    |> form("#reset_password_request_form", user: %{email: email})
    |> render_submit()

    view
  end

  describe "request page" do
    test "GET /users/reset-password routes to ResetPasswordLive with the :new live action" do
      info = route_info("GET", "/users/reset-password")

      assert info.plug == Phoenix.LiveView.Plug
      assert info.plug_opts == :new
      assert {ExampleWeb.ResetPasswordLive, :new, _opts, _meta} = info.phoenix_live_view
    end

    test "an anonymous visitor mounts the page and sees the request form", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/users/reset-password")

      assert has_element?(view, "#reset_password_request_form")
      assert has_element?(view, "#reset_password_request_form input[type=email]")
      assert has_element?(view, "#reset_password_request_form button", "Send reset instructions")
      assert html =~ "Forgot your password?"
    end

    test "submitting an existing account's email redirects to log in and writes one reset token",
         %{conn: conn} do
      user = user_fixture()
      assert reset_tokens(user_id: user.id) == [], "setup: the account starts with no reset token"

      view = submit_request(conn, user.email)

      flash = assert_redirect(view, ~p"/users/log_in")
      assert flash["info"] == @flash
      assert [%{sent_to: sent_to}] = reset_tokens(user_id: user.id)
      assert sent_to == user.email
    end

    test "submitting an address with no account redirects with the identical flash and writes no token",
         %{conn: conn} do
      unknown_email = unique_user_email()

      assert reset_tokens(sent_to: unknown_email) == [],
             "setup: nothing is stored for the address"

      view = submit_request(conn, unknown_email)

      flash = assert_redirect(view, ~p"/users/log_in")
      assert flash["info"] == @flash
      assert reset_tokens(sent_to: unknown_email) == []
    end

    test "an email in a different letter case than the stored one still reaches the account", %{
      conn: conn
    } do
      user = user_fixture()
      shouted = String.upcase(user.email)
      refute shouted == user.email, "setup: the submitted address differs in case"
      assert reset_tokens(user_id: user.id) == [], "setup: the account starts with no reset token"

      view = submit_request(conn, shouted)

      flash = assert_redirect(view, ~p"/users/log_in")
      assert flash["info"] == @flash
      assert [_one_token] = reset_tokens(user_id: user.id)
    end

    test "a signed-in visitor is redirected away from the page", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      assert {:error, {:redirect, %{to: to}}} = live(conn, ~p"/users/reset-password")
      assert to == ~p"/app"
    end
  end
end
