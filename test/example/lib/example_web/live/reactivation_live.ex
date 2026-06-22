defmodule ExampleWeb.ReactivationLive do
  @moduledoc """
  LiveView for account reactivation during the deletion grace period.
  """
  use ExampleWeb, :live_view

  alias Example.Accounts, as: Auth

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user

    scheduled_deletion_date =
      if user.scheduled_deletion_at do
        Calendar.strftime(user.scheduled_deletion_at, "%B %d, %Y")
      else
        "unknown"
      end

    {:ok,
     assign(socket,
       page_title: "Account Scheduled for Deletion",
       scheduled_deletion_date: scheduled_deletion_date
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <section class="vt-auth" data-theme="system" data-testid="reactivation">
      <div class="vt-auth__panel">
        <a href={~p"/"} class="vt-brand">
          <img src={~p"/images/vaultr-mark.svg"} alt="Vaultr logo" class="vt-brand__mark" />
          <span>
            <span class="vt-brand__name">Vaultr</span>
            <span class="vt-brand__tag">Team secrets vault</span>
          </span>
        </a>

        <div class="vt-auth__intro">
          <p class="vt-kicker">Account</p>
          <h1 class="vt-auth__title">Account scheduled for deletion</h1>
          <p class="vt-auth__copy">
            If you'd like to keep your Vaultr account, you can cancel the deletion now.
          </p>
        </div>

        <div class="vt-alert vt-alert--danger">
          Scheduled for deletion on {@scheduled_deletion_date}. Finalization will follow the
          configured deletion strategy.
        </div>

        <div class="vt-auth__form">
          <.button phx-click="cancel_deletion" class="vt-btn vt-btn--primary vt-btn--block">
            Cancel deletion and keep my account
          </.button>
          <.link href={~p"/users/log_out"} method="delete" class="vt-link">
            I understand, sign me out
          </.link>
        </div>
      </div>
    </section>
    """
  end

  @impl true
  def handle_event("cancel_deletion", _params, socket) do
    user = socket.assigns.current_scope.user

    case Auth.cancel_deletion(user, scope: socket.assigns.current_scope) do
      {:ok, _user} ->
        {:noreply,
         socket
         |> put_flash(:info, "Account deletion cancelled. Your account is active again.")
         |> push_navigate(to: ~p"/users/settings")}

      {:error, :impersonation_forbidden} ->
        {:noreply,
         put_flash(
           socket,
           :error,
           "You can't change account security settings while impersonating."
         )}

      {:error, _reason} ->
        {:noreply,
         socket
         |> put_flash(
           :error,
           "Something went wrong while processing your request. Please try again."
         )}
    end
  end
end
