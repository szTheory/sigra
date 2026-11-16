defmodule ExampleWeb.ConfirmationLiveTest do
  @moduledoc """
  Regression suite for the email confirmation page (`/users/confirm`).

  The page used to be uncompletable in BOTH session states. A signed-in visitor was
  redirected away before the page mounted (the route sat in a scope that redirects
  authenticated users), and an anonymous visitor mounted with no current scope and
  crashed with a `BadMapError` the moment they clicked "Didn't receive a code?" or
  submitted a code. These tests fail by name on each half of that defect.

  Every state-changing test ends on database state (`confirmed_at`, confirmation
  tokens), never on a response status alone: a status-only assertion passes while
  confirming nothing.
  """
  use ExampleWeb.ConnCase, async: false

  import Ecto.Query, only: [from: 2]
  import Example.AccountsFixtures
  import Phoenix.LiveViewTest
  import Swoosh.TestAssertions

  @moduletag :example_app

  @confirmation_contexts ["confirm", "confirm_code"]

  defp route_info(method, path),
    do: Phoenix.Router.route_info(ExampleWeb.Router, method, path, "localhost")

  # The confirm and confirm_code tokens stored for one account (`user_id:`).
  defp confirmation_tokens(filter) do
    Example.Repo.all(
      from(t in Example.Accounts.UserToken,
        where: t.context in ^@confirmation_contexts,
        where: ^filter
      )
    )
  end

  defp confirmed_at(user), do: Example.Repo.get!(Example.Accounts.User, user.id).confirmed_at

  defp confirm!(user) do
    user
    |> Ecto.Changeset.change(confirmed_at: DateTime.truncate(DateTime.utc_now(), :second))
    |> Example.Repo.update!()
  end

  # Delivers the confirmation email in the test process and returns the 6-digit code
  # it carries, so a test can submit the real code through the page.
  defp deliver_and_read_code(user) do
    me = self()

    {:ok, :sent} =
      Example.Accounts.deliver_user_confirmation_instructions(user, fn token ->
        "http://localhost/users/confirm/" <> token
      end)

    assert_email_sent(fn email ->
      [_whole, code] = Regex.run(~r/Your confirmation code:\s*(\d{6})/, email.text_body)
      send(me, {:emailed_code, code})
      true
    end)

    assert_received {:emailed_code, code}
    code
  end

  defp click_resend(view) do
    view |> element("a[phx-click=resend]") |> render_click()
  end

  defp submit_code(view, code) do
    view |> form("#confirmation_form", confirmation: %{code: code}) |> render_submit()
  end

  # The flash held by the LiveView process (an in-place re-render does not put it in
  # the page markup that `render_*` returns).
  defp live_flash(view), do: :sys.get_state(view.pid).socket.assigns.flash

  describe "routing" do
    test "GET /users/confirm is a LiveView in the :confirmation session and /users/confirm/:token stays a controller" do
      page = route_info("GET", "/users/confirm")
      link = route_info("GET", "/users/confirm/example-token")

      assert page.plug == Phoenix.LiveView.Plug

      assert {ExampleWeb.ConfirmationLive, _action, _opts, %{name: :confirmation}} =
               page.phoenix_live_view

      assert link.plug == ExampleWeb.ConfirmationController
      assert link.plug_opts == :confirm
    end
  end

  describe "anonymous visitor" do
    test "mounts the confirm page without crashing or redirecting", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/users/confirm")

      assert html =~ "Confirm your email"
      assert has_element?(view, "#confirmation_form")
      assert has_element?(view, "a[phx-click=resend]")
    end

    test "resend redirects to log in with an error flash and creates no confirmation token", %{
      conn: conn
    } do
      user = user_fixture()
      tokens_before = confirmation_tokens([])
      {:ok, view, _html} = live(conn, ~p"/users/confirm")

      assert {:error, {:redirect, %{to: "/users/log_in"}}} = click_resend(view)

      flash = assert_redirect(view, ~p"/users/log_in")
      assert flash["error"] == "Log in to request a new confirmation email."
      assert confirmation_tokens([]) == tokens_before
      assert confirmation_tokens(user_id: user.id) == []
      assert confirmed_at(user) == nil
    end

    test "resend ignores an email carried in the event payload", %{conn: conn} do
      user = user_fixture()
      {:ok, view, _html} = live(conn, ~p"/users/confirm")

      assert {:error, {:redirect, %{to: "/users/log_in"}}} =
               render_click(view, "resend", %{"email" => user.email})

      assert assert_redirect(view, ~p"/users/log_in")["error"] ==
               "Log in to request a new confirmation email."

      assert confirmation_tokens(sent_to: user.email) == []
    end

    test "submitting a code redirects to log in and confirms no account, even the right code", %{
      conn: conn
    } do
      user = user_fixture()
      real_code = deliver_and_read_code(user)
      tokens_before = confirmation_tokens(user_id: user.id)
      assert tokens_before != [], "setup: delivering instructions stored confirmation tokens"
      {:ok, view, _html} = live(conn, ~p"/users/confirm")

      assert {:error, {:redirect, %{to: "/users/log_in"}}} = submit_code(view, real_code)

      flash = assert_redirect(view, ~p"/users/log_in")
      assert flash["error"] == "Log in to confirm your email with a code."
      assert confirmed_at(user) == nil
      assert confirmation_tokens(user_id: user.id) == tokens_before
    end
  end

  describe "signed-in visitor" do
    test "an unconfirmed visitor mounts the page and a resend delivers a new confirmation", %{
      conn: conn
    } do
      user = user_fixture()
      assert confirmation_tokens(user_id: user.id) == [], "setup: no tokens before the resend"

      {:ok, view, html} = conn |> log_in_user(user) |> live(~p"/users/confirm")
      assert html =~ "Confirm your email"

      click_resend(view)

      assert live_flash(view)["info"] == "A new confirmation email has been sent."
      assert confirmation_tokens(user_id: user.id) != []
      assert confirmed_at(user) == nil
    end

    test "a confirmed visitor's resend redirects home as already confirmed and sends nothing", %{
      conn: conn
    } do
      user = confirm!(user_fixture())

      {:ok, view, _html} = conn |> log_in_user(user) |> live(~p"/users/confirm")

      assert {:error, {:redirect, %{to: "/"}}} = click_resend(view)

      flash = assert_redirect(view, ~p"/")
      assert flash["info"] == "Your email is already confirmed."
      assert confirmation_tokens(user_id: user.id) == []
    end

    test "the correct emailed code confirms the account", %{conn: conn} do
      user = user_fixture()
      code = deliver_and_read_code(user)
      assert confirmed_at(user) == nil, "setup: the account starts unconfirmed"

      {:ok, view, _html} = conn |> log_in_user(user) |> live(~p"/users/confirm")

      assert {:error, {:redirect, %{to: "/"}}} = submit_code(view, code)

      flash = assert_redirect(view, ~p"/")
      assert flash["info"] == "Your email has been confirmed."
      assert %DateTime{} = confirmed_at(user)
    end

    test "a wrong code shows the error flash and leaves the account unconfirmed", %{conn: conn} do
      user = user_fixture()
      real_code = deliver_and_read_code(user)
      wrong_code = if real_code == "000000", do: "111111", else: "000000"

      {:ok, view, _html} = conn |> log_in_user(user) |> live(~p"/users/confirm")

      submit_code(view, wrong_code)

      assert live_flash(view)["error"] == "Invalid confirmation code. Please try again."
      assert confirmed_at(user) == nil
    end
  end
end
