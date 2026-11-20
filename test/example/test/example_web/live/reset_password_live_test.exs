defmodule ExampleWeb.ResetPasswordLiveTest do
  @moduledoc """
  Regression suite for the password reset request page (`/users/reset-password`).

  The request page queues before account lookup, returns one acknowledgment when
  dispatch accepts the request, and fails closed without a synchronous fallback.
  """
  use ExampleWeb.ConnCase, async: false

  import Ecto.Query, only: [from: 2]
  import Example.AccountsFixtures
  import Phoenix.LiveViewTest

  @moduletag :example_app

  @flash "If your email is in our system, you will receive reset instructions shortly."

  setup tags do
    if tags[:recovery_oban] do
      start_supervised!(
        {Oban, name: Oban, repo: Example.Repo, queues: false, plugins: false, testing: :manual}
      )
    end

    :ok
  end

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

  defp recovery_jobs do
    Example.Repo.all(
      from(job in Oban.Job,
        where: job.worker == "Sigra.Workers.RecoveryRequest",
        where: job.queue == "sigra_recovery"
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

    @tag :recovery_oban
    test "submitting an existing account queues a reset without writing a token", %{conn: conn} do
      user = user_fixture()
      expected_email = user.email
      assert reset_tokens(user_id: user.id) == [], "setup: the account starts with no reset token"

      view = submit_request(conn, user.email)

      flash = assert_redirect(view, ~p"/users/log_in")
      assert flash["info"] == @flash
      assert reset_tokens(user_id: user.id) == []
      assert [job] = recovery_jobs()
      assert job.args["host_id"] == "example"

      assert {:ok, {:reset, ^expected_email}} =
               Sigra.Recovery.decrypt_envelope(
                 job.args["envelope"],
                 "example",
                 Example.Accounts.recovery_secret_key_base()
               )

      refute Map.has_key?(job.args, "email")
      refute Map.has_key?(job.args, "token")
    end

    @tag :recovery_oban
    test "unknown email gets the same acknowledgment and is queued without a token", %{conn: conn} do
      unknown_email = unique_user_email()

      assert reset_tokens(sent_to: unknown_email) == [],
             "setup: nothing is stored for the address"

      view = submit_request(conn, unknown_email)

      flash = assert_redirect(view, ~p"/users/log_in")
      assert flash["info"] == @flash
      assert reset_tokens(sent_to: unknown_email) == []
      assert [job] = recovery_jobs()

      assert {:ok, {:reset, ^unknown_email}} =
               Sigra.Recovery.decrypt_envelope(
                 job.args["envelope"],
                 "example",
                 Example.Accounts.recovery_secret_key_base()
               )
    end

    @tag :recovery_oban
    test "an email in a different letter case is normalized before queueing", %{
      conn: conn
    } do
      user = user_fixture()
      shouted = String.upcase(user.email)
      refute shouted == user.email, "setup: the submitted address differs in case"
      assert reset_tokens(user_id: user.id) == [], "setup: the account starts with no reset token"

      view = submit_request(conn, shouted)

      flash = assert_redirect(view, ~p"/users/log_in")
      assert flash["info"] == @flash
      assert reset_tokens(user_id: user.id) == []
      assert [job] = recovery_jobs()

      assert {:ok, {:reset, normalized}} =
               Sigra.Recovery.decrypt_envelope(
                 job.args["envelope"],
                 "example",
                 Example.Accounts.recovery_secret_key_base()
               )

      assert normalized == user.email
    end

    test "unavailable dispatch gives known and unknown addresses the same error without account work",
         %{
           conn: conn
         } do
      user = user_fixture()
      unknown_email = unique_user_email()

      flashes =
        for email <- [user.email, unknown_email] do
          view = submit_request(conn, email)
          flash = assert_redirect(view, ~p"/users/log_in")

          assert flash["error"] ==
                   "We couldn't send your request right now. Please try again later."

          refute flash["info"]
          flash
        end

      assert Enum.uniq(flashes) |> length() == 1
      assert reset_tokens(user_id: user.id) == []
      assert reset_tokens(sent_to: unknown_email) == []
      assert recovery_jobs() == []
    end

    test "a signed-in visitor is redirected away from the page", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      assert {:error, {:redirect, %{to: to}}} = live(conn, ~p"/users/reset-password")
      assert to == ~p"/app"
    end
  end
end
