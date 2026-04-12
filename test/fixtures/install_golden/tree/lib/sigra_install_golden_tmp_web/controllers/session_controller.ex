defmodule SigraInstallGoldenTmpWeb.SessionController do
  use SigraInstallGoldenTmpWeb, :controller

  alias SigraInstallGoldenTmp.Accounts, as: Auth
  alias SigraInstallGoldenTmpWeb.UserAuth

  def new(conn, _params) do
    email = Phoenix.Flash.get(conn.assigns.flash, :email) || ""
    form = Phoenix.Component.to_form(%{"email" => email}, as: "user")
    magic_link_form = Phoenix.Component.to_form(%{"email" => email}, as: "user")
    render(conn, :new, form: form, magic_link_form: magic_link_form)
  end

  def create(conn, %{"_action" => "magic_link", "user" => %{"email" => email}}) do
    url_fun = fn token -> url(conn, ~p"/users/log_in/#{token}") end

    case Auth.request_magic_link(email, url_fun) do
      {:ok, _} -> :ok
      {:error, :rate_limited} -> :ok
    end

    # Always show same message for enumeration prevention
    conn
    |> put_flash(:info, "If your email is registered, you will receive a magic link shortly.")
    |> redirect(to: ~p"/users/log_in")
  end

  def create(conn, %{"_action" => "registered"} = params) do
    create(conn, params, "Account created successfully!")
  end

  def create(conn, params) do
    create(conn, params, "Welcome back!")
  end

  defp create(conn, %{"user" => user_params}, info) do
    %{"email" => email, "password" => password} = user_params

    if user = Auth.get_user_by_email_and_password(email, password) do
      conn
      |> put_flash(:info, info)
      |> UserAuth.log_in_user(user, user_params)
    else
      # In order to prevent user enumeration attacks, don't disclose whether the email is registered.
      conn
      |> put_flash(:error, "Invalid email or password")
      |> put_flash(:email, String.slice(email, 0, 160))
      |> redirect(to: ~p"/users/log_in")
    end
  end

  def magic_link(conn, %{"token" => token}) do
    case Auth.verify_magic_link(token) do
      {:ok, user} ->
        conn
        |> put_flash(:info, "Welcome!")
        |> UserAuth.log_in_user(user)

      {:error, _} ->
        conn
        |> put_flash(:error, "Magic link is invalid or has expired.")
        |> redirect(to: ~p"/users/log_in")
    end
  end

  def delete(conn, _params) do
    Sigra.Telemetry.event(
      [:sigra, :auth, :logout, :stop],
      %{},
      %{user_id: conn.assigns[:current_scope] && conn.assigns.current_scope.user.id}
    )

    conn
    |> put_flash(:info, "Logged out successfully.")
    |> UserAuth.log_out_user()
  end
end
