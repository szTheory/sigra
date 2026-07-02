defmodule ExampleWeb.OrganizationsLive.Index do
  @moduledoc """
  Unified organizations landing LiveView at `/organizations`.

  This is the Phase 14 `:no_active_org` redirect target (D-09), and it
  funnels every "user lands without a usable active org" flow into a
  single mount with three render branches keyed on
  `{memberships, pending_invitations}`:

    * `([], [])` — Branch A: zero-state hero + inline create form
      (also the post-signup destination via ORG-UX-09's zero-line
      registration path)
    * `([], [_|_])` — Branch B: pending invitations list (Phase 17
      wires Accept; Phase 16 renders Accept disabled)
    * `([_|_], _)` — Branch C: picker with per-row switch forms

  Edit freely — this file is your code.
  """

  use ExampleWeb, :live_view

  alias Example.Organizations
  alias ExampleWeb.Layouts

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user
    memberships = Organizations.list_organizations_for_user(user)
    pending = Organizations.list_pending_invitations_for_user(user)

    socket =
      socket
      |> assign(:memberships, memberships)
      |> assign(:pending_invitations, pending)
      |> assign(:form, to_form(%{"name" => ""}, as: :organization))
      |> assign(:slug_preview, "")
      |> assign(:page_title, "Organizations")

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
    assigns =
      assign(assigns, :branch, pick_branch(assigns.memberships, assigns.pending_invitations))

    ~H"""
    <Layouts.app
      flash={@flash}
      current_scope={@current_scope}
      user_organizations={@memberships}
    >
      <section class="vt-page-intro" data-testid="app-organizations-index">
        <div :if={@branch == :a}>{render_branch_a(assigns)}</div>
        <div :if={@branch == :b}>{render_branch_b(assigns)}</div>
        <div :if={@branch == :c}>{render_branch_c(assigns)}</div>
      </section>
    </Layouts.app>
    """
  end

  defp pick_branch([], []), do: :a
  defp pick_branch([], [_ | _]), do: :b
  defp pick_branch([_ | _], _), do: :c

  # Branch A — zero memberships, zero pending invitations
  defp render_branch_a(assigns) do
    ~H"""
    <section class="vt-panel">
      <div class="vt-panel__header">
        <div>
          <p class="vt-kicker">Organizations</p>
          <h1 class="vt-panel__title">Create your first organization</h1>
          <p class="vt-copy">
            You don't belong to any teams yet. Create one to start sharing secrets.
          </p>
        </div>
      </div>

      <.form
        for={@form}
        id="organization-create-form"
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

      <p><.link navigate={~p"/app"} class="vt-link">Skip for now</.link></p>
    </section>
    """
  end

  # Branch B — zero memberships, 1+ pending invitations
  defp render_branch_b(assigns) do
    ~H"""
    <section class="vt-panel">
      <div class="vt-panel__header">
        <div>
          <p class="vt-kicker">Invitations</p>
          <h1 class="vt-panel__title">
            You have {length(@pending_invitations)} pending invitation(s)
          </h1>
        </div>
      </div>

      <div id="pending-invitations-list" class="vt-seed-list">
        <div
          :for={invitation <- @pending_invitations}
          style="display:flex;align-items:center;justify-content:space-between;gap:var(--sg-space-2)"
        >
          <span>{invitation.organization.name}</span>
          <button type="button" class="vt-btn" disabled title="Available in the next release">
            Accept
          </button>
        </div>
      </div>

      <details class="vt-auth__disclosure">
        <summary>Or create your own organization →</summary>
        {render_branch_a(assigns)}
      </details>
    </section>
    """
  end

  # Branch C — 1+ memberships (picker)
  defp render_branch_c(assigns) do
    ~H"""
    <section class="vt-panel">
      <div class="vt-panel__header">
        <div>
          <p class="vt-kicker">Organizations</p>
          <h1 class="vt-panel__title">Your organizations</h1>
        </div>
        <.link navigate={~p"/organizations/new"} class="vt-btn vt-btn--primary">
          New organization
        </.link>
      </div>

      <div id="organizations-picker-list" class="vt-seed-list">
        <div
          :for={{org, role} <- @memberships}
          style="display:flex;align-items:center;justify-content:space-between;gap:var(--sg-space-2)"
        >
          <div>
            <strong>{org.name}</strong>
            <span class="vt-status-pill vt-status-pill--ok">{humanize_role(role)}</span>
          </div>

          <form action={~p"/organizations/switch"} method="post">
            <input type="hidden" name="_csrf_token" value={Phoenix.Controller.get_csrf_token()} />
            <input type="hidden" name="organization_id" value={org.id} />
            <input type="hidden" name="return_to" value="/" />
            <button type="submit" class="vt-btn vt-btn--secondary" aria-label={"Open " <> org.name}>
              Open
            </button>
          </form>
        </div>
      </div>

      <section>
        <p class="vt-kicker">Pending invitations</p>
        <p :if={@pending_invitations == []} class="vt-copy">No pending invitations.</p>
      </section>
    </section>
    """
  end

  defp humanize_role(role) when is_atom(role),
    do: role |> Atom.to_string() |> String.capitalize()

  defp humanize_role(role), do: to_string(role)

  defp create_error_flash(%Ecto.Changeset{} = changeset) do
    case Keyword.get(changeset.errors, :slug) do
      {"is reserved and cannot be used", _} -> "That slug is reserved. Try another."
      {"has already been taken", _} -> "That slug is already in use. Try another."
      {msg, _} -> msg
      _ -> "Could not create organization."
    end
  end
end
