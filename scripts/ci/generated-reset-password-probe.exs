defmodule <%= app_module %>.GeneratedResetPasswordProbeTest do
  use <%= app_module %>Web.ConnCase, async: false

  import Ecto.Query, only: [from: 2]
  import Phoenix.LiveViewTest

  alias <%= app_module %>.Accounts.UserToken
  alias <%= app_module %>.AccountsFixtures
  alias <%= app_module %>.Repo

  @reset_flash "If your email is in our system, you will receive reset instructions shortly."

  test "generated reset request renders and responds alike for known and unknown addresses", %{
    conn: conn
  } do
    user = AccountsFixtures.user_fixture()
    unknown_email = AccountsFixtures.unique_user_email()

    assert reset_tokens_for(user.id) == []

    {existing_redirect, existing_flash} = submit_reset_request(conn, user.email)
    {unknown_redirect, unknown_flash} = submit_reset_request(build_conn(), unknown_email)

    assert existing_redirect == "/users/log_in"
    assert unknown_redirect == existing_redirect
    assert existing_flash == unknown_flash
    assert existing_flash["info"] == @reset_flash

    assert [%UserToken{context: "reset_password", sent_to: sent_to}] =
             reset_tokens_for(user.id)

    assert sent_to == user.email
    assert reset_tokens_for_email(unknown_email) == []
  end

  defp submit_reset_request(conn, email) do
    {:ok, view, html} = live(conn, "/users/reset-password")
    assert html =~ ~s(id="reset_password_request_form")

    outcome =
      view
      |> form("#reset_password_request_form", user: %{email: email})
      |> render_submit()

    assert {:error, {:redirect, %{to: "/users/log_in"}}} = outcome
    flash = assert_redirect(view, "/users/log_in")
    {"/users/log_in", flash}
  end

  defp reset_tokens_for(user_id) do
    Repo.all(
      from token in UserToken,
        where: token.context == "reset_password" and token.user_id == ^user_id
    )
  end

  defp reset_tokens_for_email(email) do
    Repo.all(
      from token in UserToken,
        where: token.context == "reset_password" and token.sent_to == ^email
    )
  end
end
