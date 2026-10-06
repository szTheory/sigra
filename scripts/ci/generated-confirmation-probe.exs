defmodule <%= app_module %>.GeneratedConfirmationProbeTest do
  use <%= app_module %>Web.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias <%= app_module %>.Accounts.{User, UserSession, UserToken}
  alias <%= app_module %>.Accounts, as: Auth
  alias <%= app_module %>.AccountsFixtures
  alias <%= app_module %>.Repo

  test "anonymous link confirmation is explicit, persisted, and single-use", %{conn: conn} do
    user = AccountsFixtures.user_fixture()

    {signed_token, _code, link_token, code_token} =
      Sigra.Auth.generate_confirmation_token(Repo, user,
        secret_key_base: <%= app_module %>Web.Endpoint.config(:secret_key_base),
        user_token_schema: UserToken
      )

    Repo.insert!(link_token)
    Repo.insert!(code_token)

    assert is_nil(Repo.get!(User, user.id).confirmed_at)
    assert Repo.aggregate(UserSession, :count, :id) == 0

    {:ok, view, html} = live(conn, "/users/confirm/#{signed_token}")
    assert html =~ ~s(id="confirmation_link_form")
    assert html =~ "Confirm email"
    assert is_nil(Repo.get!(User, user.id).confirmed_at)
    IO.puts("PASS confirmation probe: GET rendered explicit action and left confirmed_at unchanged")

    submitted_html = view |> element("#confirmation_link_form") |> render_submit()
    assert submitted_html =~ ~s(role="status")
    assert submitted_html =~ "Your email has been confirmed."
    confirmed_user = Repo.get!(User, user.id)
    assert confirmed_user.confirmed_at
    assert Repo.aggregate(UserSession, :count, :id) == 0
    IO.puts("PASS confirmation probe: submit persisted confirmed_at without creating a session")

    {:ok, replay_view, _replay_html} = live(build_conn(), "/users/confirm/#{signed_token}")
    replay_html = replay_view |> element("#confirmation_link_form") |> render_submit()
    assert replay_html =~ "This confirmation link is invalid or has expired."
    assert Repo.get!(User, user.id).confirmed_at == confirmed_user.confirmed_at
    IO.puts("PASS confirmation probe: consumed link could not be replayed")
  end

  test "signed-in visitor remains signed in while confirming the link owner's account", %{conn: conn} do
    owner = AccountsFixtures.user_fixture()
    visitor = AccountsFixtures.user_fixture()

    visitor =
      Repo.update!(
        Ecto.Changeset.change(visitor,
          confirmed_at: DateTime.utc_now() |> DateTime.truncate(:second)
        )
      )

    {signed_token, _code, link_token, code_token} =
      Sigra.Auth.generate_confirmation_token(Repo, owner,
        secret_key_base: <%= app_module %>Web.Endpoint.config(:secret_key_base),
        user_token_schema: UserToken
      )

    Repo.insert!(link_token)
    Repo.insert!(code_token)

    visitor_conn = log_in_user(conn, visitor)
    visitor_token = get_session(visitor_conn, :user_token)
    visitor_confirmed_at = visitor.confirmed_at

    assert is_nil(Repo.get!(User, owner.id).confirmed_at)
    assert {session_user, _session} = Auth.get_user_and_session_by_token(visitor_token)
    assert session_user.id == visitor.id
    assert Repo.aggregate(UserSession, :count, :id) == 1

    {:ok, view, html} = live(visitor_conn, "/users/confirm/#{signed_token}")
    assert html =~ ~s(id="confirmation_link_form")
    assert is_nil(Repo.get!(User, owner.id).confirmed_at)
    assert Repo.get!(User, visitor.id).confirmed_at == visitor_confirmed_at
    assert {session_user, _session} = Auth.get_user_and_session_by_token(visitor_token)
    assert session_user.id == visitor.id

    submitted_html = view |> element("#confirmation_link_form") |> render_submit()
    assert submitted_html =~ "Your email has been confirmed."
    assert Repo.get!(User, owner.id).confirmed_at
    assert Repo.get!(User, visitor.id).confirmed_at == visitor_confirmed_at
    assert {session_user, _session} = Auth.get_user_and_session_by_token(visitor_token)
    assert session_user.id == visitor.id
    assert Repo.aggregate(UserSession, :count, :id) == 1
    IO.puts("PASS confirmation probe: signed-in visitor session remained bound to visitor")
  end

  test "anonymous code and resend events show sign-in guidance without changing an account", %{conn: conn} do
    user = AccountsFixtures.user_fixture()

    {_signed_token, code, link_token, code_token} =
      Sigra.Auth.generate_confirmation_token(Repo, user,
        secret_key_base: <%= app_module %>Web.Endpoint.config(:secret_key_base),
        user_token_schema: UserToken
      )

    Repo.insert!(link_token)
    Repo.insert!(code_token)

    {:ok, code_view, _html} = live(conn, "/users/confirm")

    code_html =
      code_view
      |> element("#confirmation_form")
      |> render_submit(%{"confirmation" => %{"code" => code, "user_id" => to_string(user.id)}})

    assert code_html =~ "Please sign in to confirm your email."
    assert code_html =~ ~s(href="/users/log_in")
    assert is_nil(Repo.get!(User, user.id).confirmed_at)
    assert Repo.aggregate(UserSession, :count, :id) == 0

    {:ok, resend_view, _html} = live(conn, "/users/confirm")
    resend_html = resend_view |> element("button[phx-click=resend]") |> render_click()

    assert resend_html =~ "Please sign in to confirm your email."
    assert resend_html =~ ~s(href="/users/log_in")
    assert is_nil(Repo.get!(User, user.id).confirmed_at)
    assert Repo.aggregate(UserSession, :count, :id) == 0
    IO.puts("PASS confirmation probe: anonymous code and resend showed sign-in guidance")
  end

  test "client account identifiers cannot choose the code confirmation target", %{conn: conn} do
    owner = AccountsFixtures.user_fixture()
    visitor = AccountsFixtures.user_fixture()

    {_signed_token, owner_code, link_token, code_token} =
      Sigra.Auth.generate_confirmation_token(Repo, owner,
        secret_key_base: <%= app_module %>Web.Endpoint.config(:secret_key_base),
        user_token_schema: UserToken
      )

    Repo.insert!(link_token)
    Repo.insert!(code_token)

    visitor_conn = log_in_user(conn, visitor)
    {:ok, view, _html} = live(visitor_conn, "/users/confirm")

    response_html =
      view
      |> element("#confirmation_form")
      |> render_submit(%{
        "confirmation" => %{"code" => owner_code, "user_id" => to_string(owner.id)}
      })

    assert response_html =~ "Invalid confirmation code. Please try again."
    assert is_nil(Repo.get!(User, owner.id).confirmed_at)
    assert is_nil(Repo.get!(User, visitor.id).confirmed_at)
    IO.puts("PASS confirmation probe: client account identifier did not select confirmation target")
  end
end
