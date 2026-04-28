defmodule ExampleWeb.SettingsController do
  use ExampleWeb, :controller

  alias Example.Accounts

  def edit(conn, _params) do
    user = conn.assigns.current_scope.user
    identities = Accounts.list_user_identities(user)
    oauth_providers = Accounts.oauth_providers()
    linked_providers = MapSet.new(Enum.map(identities, &String.to_atom(&1.provider)))

    unlinked_providers =
      Enum.reject(oauth_providers, fn {provider, _} ->
        MapSet.member?(linked_providers, provider)
      end)

    has_password = not is_nil(user.hashed_password) and user.hashed_password != ""
    can_unlink = has_password or length(identities) > 1

    render(conn, :edit,
      user: user,
      identities: identities,
      has_password: has_password,
      can_unlink: can_unlink,
      unlinked_providers: unlinked_providers,
      remaining_methods_text: remaining_methods_text(user, identities),
      password_form: Phoenix.Component.to_form(%{}, as: "user")
    )
  end

  def update_password(conn, %{"user" => user_params}) do
    user = conn.assigns.current_scope.user

    case Accounts.set_password(user, user_params) do
      {:ok, _user} ->
        conn
        |> put_flash(:info, "Password set.")
        |> redirect(to: ~p"/users/settings")

      {:error, changeset} ->
        identities = Accounts.list_user_identities(user)
        oauth_providers = Accounts.oauth_providers()
        linked_providers = MapSet.new(Enum.map(identities, &String.to_atom(&1.provider)))

        unlinked_providers =
          Enum.reject(oauth_providers, fn {provider, _} ->
            MapSet.member?(linked_providers, provider)
          end)

        has_password = not is_nil(user.hashed_password) and user.hashed_password != ""
        can_unlink = has_password or length(identities) > 1

        conn
        |> put_status(:unprocessable_entity)
        |> render(:edit,
          user: user,
          identities: identities,
          has_password: has_password,
          can_unlink: can_unlink,
          unlinked_providers: unlinked_providers,
          remaining_methods_text: remaining_methods_text(user, identities),
          password_form: Phoenix.Component.to_form(changeset, as: "user")
        )
    end
  end

  def delete_identity(conn, %{"id" => id}) do
    user = conn.assigns.current_scope.user

    case Accounts.unlink_oauth_identity(user, id) do
      {:ok, :unlinked} ->
        conn
        |> put_flash(:info, "Provider unlinked.")
        |> redirect(to: ~p"/users/settings")

      {:error, :last_provider} ->
        conn
        |> put_flash(:error, "Set a password first to keep access to your account.")
        |> redirect(to: ~p"/users/settings")
    end
  end

  defp remaining_methods_text(user, identities) do
    methods =
      []
      |> maybe_add_method(
        not is_nil(user.hashed_password) and user.hashed_password != "",
        "password"
      )
      |> maybe_add_method(length(identities) > 1, "another OAuth provider")

    case methods do
      [] -> "password"
      [one] -> one
      [one, two] -> "#{one} or #{two}"
      many -> Enum.join(many, ", ")
    end
  end

  defp maybe_add_method(methods, true, label), do: methods ++ [label]
  defp maybe_add_method(methods, false, _label), do: methods
end
