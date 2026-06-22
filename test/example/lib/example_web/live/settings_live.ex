defmodule ExampleWeb.SettingsLive do
  @moduledoc """
  Tasklane account settings — the host app's own, fully-functional account screen
  built on Sigra's account-management functions.

  Sections:
  - **Profile** — edit display name (`Example.Accounts.update_display_name/2`)
  - **Email** — request a change (with a real confirmation link delivered to the
    new address via the dev mailbox), see the pending state, cancel
  - **Password** — change with current password, or set one for OAuth-only users
  - **Delete account** — schedule deletion with the configured grace period, cancel

  Rendered inside `Layouts.app` (the authenticated Tasklane chrome) and styled with
  the `vt-*` design system. Adapted from the `mix sigra.install` settings template.
  """
  use ExampleWeb, :live_view

  alias Example.Accounts, as: Auth
  alias Example.Organizations
  alias ExampleWeb.Layouts

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user

    {:ok,
     socket
     |> assign(
       page_title: "Account settings",
       pending_email_change?: user.pending_email != nil,
       deletion_status: Auth.deletion_status(user),
       scheduled_deletion_date: scheduled_deletion_date(user),
       has_password?: user.hashed_password != nil,
       force_password_change?: Auth.must_change_password?(user),
       user_organizations: Organizations.list_organizations_for_user(user),
       profile_form: to_form(Auth.change_display_name(user), as: "profile"),
       email_form: to_form(%{"email" => ""}, as: "email"),
       password_form: to_form(%{}, as: "password")
     )}
  end

  @impl true
  def handle_params(%{"token" => token}, _uri, %{assigns: %{live_action: :confirm_email}} = socket) do
    case Auth.confirm_email_change(token) do
      {:ok, _user} ->
        {:noreply,
         socket
         |> put_flash(:info, "Your email has been updated.")
         |> push_navigate(to: ~p"/users/settings")}

      _ ->
        {:noreply,
         socket
         |> put_flash(
           :error,
           "This confirmation link is invalid or has expired. Request a new email change from your settings."
         )
         |> push_navigate(to: ~p"/users/settings")}
    end
  end

  def handle_params(_params, _uri, socket), do: {:noreply, socket}

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_scope={@current_scope}
      user_organizations={@user_organizations}
    >
      <section class="vt-page-intro" data-testid="app-settings">
        <header class="vt-panel__header">
          <div>
            <p class="vt-kicker">Account</p>
            <h1 class="vt-panel__title">Account settings</h1>
            <p class="vt-copy">Manage your profile, email, password, and account.</p>
          </div>
          <a href={~p"/app"} class="vt-btn vt-btn--ghost">Back to dashboard</a>
        </header>

        <div :if={@force_password_change?} class="vt-alert vt-alert--warning">
          You must change your password before you can continue using your account.
        </div>

        <div class="vt-card-grid">
          <%!-- Profile --%>
          <section class="vt-panel" data-testid="settings-profile">
            <div class="vt-panel__header">
              <div>
                <p class="vt-kicker">Profile</p>
                <h2 class="vt-panel__title">Display name</h2>
              </div>
            </div>
            <.form for={@profile_form} phx-submit="update_profile" class="vt-form">
              <.input
                field={@profile_form[:display_name]}
                type="text"
                label="Display name"
                placeholder={@current_scope.user.email}
              />
              <p class="vt-copy">Shown across Tasklane. Leave blank to use your email.</p>
              <.button class="vt-btn vt-btn--primary">Save profile</.button>
            </.form>
          </section>

          <%!-- Email --%>
          <section class="vt-panel" data-testid="settings-email">
            <div class="vt-panel__header">
              <div>
                <p class="vt-kicker">Email</p>
                <h2 class="vt-panel__title">Email address</h2>
              </div>
            </div>
            <p class="vt-copy">
              Current: <code class="vt-code">{@current_scope.user.email}</code>
            </p>

            <div
              :if={@pending_email_change?}
              class="vt-alert vt-alert--info"
              data-testid="settings-email-pending"
            >
              <div>
                <strong>Changing to {@current_scope.user.pending_email}</strong>
                <p class="vt-copy">
                  We sent a confirmation link to {@current_scope.user.pending_email}. Your current
                  email stays active until you confirm (check the
                  <a href={~p"/dev/mailbox"} class="vt-link">dev mailbox</a>).
                </p>
                <button type="button" phx-click="cancel_email_change" class="vt-btn vt-btn--ghost">
                  Cancel email change
                </button>
              </div>
            </div>

            <.form
              :if={!@pending_email_change?}
              for={@email_form}
              phx-submit="request_email_change"
              class="vt-form"
            >
              <.input field={@email_form[:email]} type="email" label="New email" required />
              <.button class="vt-btn vt-btn--primary">Update email</.button>
            </.form>
          </section>

          <%!-- Password --%>
          <section class="vt-panel" data-testid="settings-password">
            <div class="vt-panel__header">
              <div>
                <p class="vt-kicker">Security</p>
                <h2 class="vt-panel__title">Password</h2>
              </div>
            </div>
            <.form
              :if={@has_password?}
              for={@password_form}
              phx-submit="change_password"
              class="vt-form"
            >
              <.input
                field={@password_form[:current_password]}
                type="password"
                label="Current password"
                autocomplete="current-password"
                required
              />
              <.input
                field={@password_form[:password]}
                type="password"
                label="New password"
                autocomplete="new-password"
                required
              />
              <.input
                field={@password_form[:password_confirmation]}
                type="password"
                label="Confirm new password"
                autocomplete="new-password"
                required
              />
              <.button class="vt-btn vt-btn--primary">Change password</.button>
            </.form>

            <div :if={!@has_password?}>
              <p class="vt-copy">
                You signed in with a social provider. Set a password to enable email login.
              </p>
              <.form for={@password_form} phx-submit="set_password" class="vt-form">
                <.input
                  field={@password_form[:password]}
                  type="password"
                  label="New password"
                  autocomplete="new-password"
                  required
                />
                <.input
                  field={@password_form[:password_confirmation]}
                  type="password"
                  label="Confirm new password"
                  autocomplete="new-password"
                  required
                />
                <.button class="vt-btn vt-btn--primary">Set a password</.button>
              </.form>
            </div>
          </section>

          <%!-- Delete --%>
          <section class="vt-panel" data-testid="settings-delete">
            <div class="vt-panel__header">
              <div>
                <p class="vt-kicker">Danger zone</p>
                <h2 class="vt-panel__title">Delete account</h2>
              </div>
            </div>
            <%= case @deletion_status do %>
              <% {:scheduled, _days} -> %>
                <div class="vt-alert vt-alert--danger">
                  Your account is scheduled for deletion on {@scheduled_deletion_date}.
                </div>
                <button type="button" phx-click="cancel_deletion" class="vt-btn vt-btn--ghost">
                  Cancel deletion
                </button>
              <% :not_scheduled -> %>
                <p class="vt-copy">
                  Schedule account deletion according to your configured strategy. After the
                  grace period, Sigra finalizes the account lifecycle.
                </p>
                <button
                  type="button"
                  phx-click="confirm_delete"
                  data-confirm="Are you sure? Your account will be deactivated immediately and all sessions signed out."
                  class="vt-btn vt-btn--danger-solid"
                >
                  Delete my account
                </button>
              <% _ -> %>
            <% end %>
          </section>
        </div>
      </section>
    </Layouts.app>
    """
  end

  # -- Event handlers --

  @impl true
  def handle_event("update_profile", %{"profile" => params}, socket) do
    user = socket.assigns.current_scope.user

    case Auth.update_display_name(user, params) do
      {:ok, updated} ->
        {:noreply,
         socket
         |> put_flash(:info, "Profile updated.")
         |> assign(
           current_scope: %{socket.assigns.current_scope | user: updated},
           profile_form: to_form(Auth.change_display_name(updated), as: "profile")
         )}

      {:error, changeset} ->
        {:noreply, assign(socket, profile_form: to_form(changeset, as: "profile"))}
    end
  end

  def handle_event("request_email_change", %{"email" => %{"email" => new_email}}, socket) do
    user = socket.assigns.current_scope.user

    case Auth.request_email_change(user, new_email) do
      {:ok, _user, token} ->
        Auth.deliver_email_change_confirmation(
          user,
          new_email,
          url(~p"/users/settings/confirm-email/#{token}")
        )

        {:noreply,
         socket
         |> put_flash(
           :info,
           "We sent a confirmation link to #{new_email}. Your current email stays active until you confirm."
         )
         |> assign(pending_email_change?: true)}

      {:error, changeset} ->
        {:noreply, assign(socket, email_form: to_form(changeset, as: "email"))}
    end
  end

  def handle_event("cancel_email_change", _params, socket) do
    user = socket.assigns.current_scope.user

    case Auth.cancel_email_change(user) do
      {:ok, _user} ->
        {:noreply,
         socket
         |> put_flash(:info, "Email change cancelled. Your email remains #{user.email}.")
         |> assign(pending_email_change?: false)}

      {:error, _changeset} ->
        {:noreply,
         put_flash(socket, :error, "Something went wrong while processing your request. Please try again.")}
    end
  end

  def handle_event("change_password", %{"password" => params}, socket) do
    user = socket.assigns.current_scope.user
    current_password = params["current_password"]
    attrs = Map.take(params, ["password", "password_confirmation"])

    case Auth.change_password(user, current_password, attrs) do
      {:ok, _user} ->
        {:noreply,
         socket
         |> put_flash(:info, "Your password has been changed. All other sessions have been signed out.")
         |> assign(force_password_change?: false, password_form: to_form(%{}, as: "password"))}

      {:error, changeset} ->
        {:noreply, assign(socket, password_form: to_form(changeset, as: "password"))}
    end
  end

  def handle_event("set_password", %{"password" => params}, socket) do
    user = socket.assigns.current_scope.user
    attrs = Map.take(params, ["password", "password_confirmation"])

    case Auth.set_password(user, attrs) do
      {:ok, _user} ->
        {:noreply,
         socket
         |> put_flash(:info, "Password set successfully. You can now sign in with email and password.")
         |> assign(has_password?: true, password_form: to_form(%{}, as: "password"))}

      {:error, changeset} ->
        {:noreply, assign(socket, password_form: to_form(changeset, as: "password"))}
    end
  end

  def handle_event("confirm_delete", _params, socket) do
    user = socket.assigns.current_scope.user

    case Auth.schedule_deletion(user) do
      {:ok, updated_user, scheduled_date} ->
        {:noreply,
         socket
         |> put_flash(:info, "Your account is scheduled for deletion on #{scheduled_date}. You can cancel this from your settings.")
         |> assign(
           current_scope: %{socket.assigns.current_scope | user: updated_user},
           deletion_status: Auth.deletion_status(updated_user),
           scheduled_deletion_date: to_string(scheduled_date)
         )}

      {:error, reason} ->
        message =
          case reason do
            :already_scheduled -> "Your account is already scheduled for deletion."
            :cooldown -> "You recently cancelled a deletion request. Please wait before requesting again."
            _ -> "Something went wrong while processing your request. Please try again."
          end

        {:noreply, put_flash(socket, :error, message)}
    end
  end

  def handle_event("cancel_deletion", _params, socket) do
    user = socket.assigns.current_scope.user

    case Auth.cancel_deletion(user) do
      {:ok, updated_user} ->
        {:noreply,
         socket
         |> put_flash(:info, "Account deletion cancelled. Your account is active again.")
         |> assign(
           current_scope: %{socket.assigns.current_scope | user: updated_user},
           deletion_status: :not_scheduled,
           scheduled_deletion_date: nil
         )}

      {:error, _reason} ->
        {:noreply,
         put_flash(socket, :error, "Something went wrong while processing your request. Please try again.")}
    end
  end

  # -- Helpers --

  defp scheduled_deletion_date(%{scheduled_deletion_at: nil}), do: nil

  defp scheduled_deletion_date(%{scheduled_deletion_at: dt}),
    do: Calendar.strftime(dt, "%B %d, %Y")

  defp scheduled_deletion_date(_), do: nil
end
