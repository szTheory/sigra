defmodule <%= web_module %>.RegistrationController do
  @moduledoc """
  Controller-mode user registration for installs created with `--no-live`.
  """
  use <%= web_module %>, :controller

  alias <%= context_module %>, as: Auth

  def new(conn, _params) do
    form = Phoenix.Component.to_form(Auth.change_user_registration(%<%= context_module %>.<%= schema_alias %>{}), as: "user")
    render(conn, :new, form: form)
  end

  def create(conn, %{"user" => user_params}) do
    case Auth.register_user(user_params,
           confirmation_url_fun: &url(conn, ~p"/users/confirm/#{&1}")
         ) do
      {:ok, _user} ->
        conn
        |> put_flash(:info, "Check your email to confirm your account.")
        |> redirect(to: ~p"/users/log_in")

      {:error, changeset} ->
        conn
        |> put_flash(:error, "Please correct the errors below.")
        |> render(:new, form: Phoenix.Component.to_form(changeset, as: "user"))
    end
  end
end
