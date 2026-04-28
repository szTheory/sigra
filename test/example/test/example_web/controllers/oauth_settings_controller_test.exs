defmodule ExampleWeb.OAuthSettingsControllerTest do
  use ExampleWeb.ConnCase, async: true

  import Ecto.Query
  import Example.AccountsFixtures
  import Swoosh.TestAssertions

  alias Example.Accounts

  @moduletag :example_app

  setup do
    user = user_fixture()
    %{conn: log_in_user(build_conn(), user), user: user}
  end

  test "login page renders configured OAuth provider buttons" do
    conn = get(build_conn(), ~p"/users/log_in")
    body = html_response(conn, 200)

    assert body =~ "Continue with Google"
    assert body =~ ~s(href="/auth/google")
  end

  test "settings page shows disabled unlink tooltip for oauth-only users", %{user: user} do
    Example.Repo.update_all(
      from(u in Example.Accounts.User, where: u.id == ^user.id),
      set: [hashed_password: nil]
    )

    {:ok, _identity} =
      Accounts.create_identity(%{
        user_id: user.id,
        provider: "google",
        provider_uid: "google-only-user",
        provider_email: user.email
      })

    user = Accounts.get_user!(user.id)
    conn = log_in_user(build_conn(), user)
    body = conn |> get(~p"/users/settings") |> html_response(200)

    assert body =~ "Set a password first to keep access to your account."
  end

  test "password login consumes oauth link intent and sends linked email", %{user: user} do
    password = valid_user_password()

    conn =
      build_conn()
      |> init_test_session(%{
        sigra_oauth_link_intent: %{
          "provider" => "google",
          "provider_uid" => "google-link-intent-123",
          "email" => user.email,
          "expires_at" => DateTime.add(DateTime.utc_now(), 900, :second) |> DateTime.to_iso8601()
        }
      })
      |> post(~p"/users/log_in", %{
        "user" => %{"email" => user.email, "password" => password}
      })

    assert redirected_to(conn) == ~p"/"

    identities = Accounts.list_user_identities(Accounts.get_user!(user.id))

    assert Enum.any?(
             identities,
             &(&1.provider == "google" and &1.provider_uid == "google-link-intent-123")
           )

    assert_email_sent(fn email ->
      body = [email.html_body || "", email.text_body || ""] |> Enum.join("\n")

      email.subject =~ "Google linked to your account" and
        body =~ "Google was linked to your account."
    end)
  end
end
