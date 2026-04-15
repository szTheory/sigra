defmodule SigraInstallGoldenTmpWeb.OrganizationsLive.New do
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

  use SigraInstallGoldenTmpWeb, :live_view

  alias SigraInstallGoldenTmp.Organizations

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:form, to_form(%{"name" => ""}, as: :organization))
      |> assign(:slug_preview, "")

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
    <.flash_group flash={@flash} />

    <div class="mx-auto max-w-md py-16">
      <.header>
        Create organization
      </.header>

      <.form
        for={@form}
        id="organization-new-form"
        phx-change="validate"
        phx-submit="create"
        class="mt-8"
      >
        <.input field={@form[:name]} type="text" label="Organization name" required />

        <p
          id="slug-preview"
          class="text-sm text-base-content/70 mt-1"
          aria-live="polite"
        >
          {@slug_preview}
        </p>

        <.button
          type="submit"
          phx-disable-with="Creating..."
          class="btn btn-primary w-full mt-4"
        >
          Create organization
        </.button>
      </.form>

      <div class="mt-6 text-center">
        <.link navigate={~p"/organizations"} class="link link-hover text-sm">
          Cancel
        </.link>
      </div>
    </div>
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
