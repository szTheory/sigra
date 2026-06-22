defmodule ExampleWeb.OrganizationsLive.New do
  @moduledoc """
  Dedicated create-organization LiveView at `/organizations/new`.

  Parallel to Branch A of `OrganizationsLive.Index` — same form fields,
  same live slug preview, same changeset error mapping — but rendered
  on its own page with a top-level header and a Cancel link back to
  `/organizations`. Per D-07, the installer ships both the unified
  landing LV AND a dedicated new route so hosts can link directly to
  `/organizations/new` without first landing on the picker.

  Edit freely — this file is your code.
  """

  use ExampleWeb, :live_view

  alias Example.Organizations
  alias ExampleWeb.Layouts

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user

    socket =
      socket
      |> assign(:form, to_form(%{"name" => ""}, as: :organization))
      |> assign(:slug_preview, "")
      |> assign(:user_organizations, Organizations.list_organizations_for_user(user))
      |> assign(:page_title, "New organization")

    {:ok, socket}
  end

  @impl true
  def handle_event("validate", %{"organization" => %{"name" => name}}, socket) do
    {:noreply, assign(socket, :slug_preview, Sigra.Organizations.Slug.generate(name))}
  end

  @impl true
  def handle_event("create", %{"organization" => %{"name" => name}}, socket) do
    scope = socket.assigns.current_scope

    case Organizations.create_organization(scope, %{name: name}) do
      {:ok, org} ->
        {:noreply,
         socket
         |> put_flash(:info, "Organization created.")
         |> redirect(to: ~p"/organizations/#{org.slug}/members")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply,
         socket
         |> assign(:form, to_form(changeset, as: :organization))
         |> assign(:slug_preview, Sigra.Organizations.Slug.generate(name))
         |> put_flash(:error, create_error_flash(changeset))}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_scope={@current_scope}
      user_organizations={@user_organizations}
    >
      <section class="vt-page-intro" data-testid="app-organization-new">
        <section class="vt-panel">
          <div class="vt-panel__header">
            <div>
              <p class="vt-kicker">Organizations</p>
              <h1 class="vt-panel__title">Create organization</h1>
            </div>
          </div>

          <.form
            for={@form}
            id="organization-new-form"
            phx-change="validate"
            phx-submit="create"
            class="vt-form"
          >
            <.input field={@form[:name]} type="text" label="Organization name" required />
            <p id="slug-preview" class="vt-copy" aria-live="polite">{@slug_preview}</p>
            <.button phx-disable-with="Creating..." class="vt-btn vt-btn--primary">
              Create organization
            </.button>
          </.form>

          <p><.link navigate={~p"/organizations"} class="vt-link">Cancel</.link></p>
        </section>
      </section>
    </Layouts.app>
    """
  end

  defp create_error_flash(%Ecto.Changeset{} = changeset) do
    case Keyword.get(changeset.errors, :slug) do
      {"is reserved and cannot be used", _} -> "That slug is reserved. Try another."
      {"has already been taken", _} -> "That slug is already in use. Try another."
      {msg, _} -> msg
      _ -> "Could not create organization."
    end
  end
end
