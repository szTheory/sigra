defmodule <%= app_module %>.GeneratedConfirmationProbeTest do
  use <%= app_module %>Web.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias <%= app_module %>.Accounts.{User, UserSession, UserToken}
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
end
