defmodule SigraInstallGoldenTmpWeb.OrganizationsLive.Index do
  @moduledoc """
  Unified organizations landing LiveView at `/organizations`.

  This is the `:no_active_org` redirect target, and it
  funnels every "user lands without a usable active org" flow into a
  single mount with three render branches keyed on
  `{memberships, pending_invitations}`:

    * `([], [])` — Branch A: zero-state hero + inline create form
      (also the post-signup destination via the zero-line
      registration path)
    * `([], [_|_])` — Branch B: pending invitations list with an Accept
      action for each invitation
    * `([_|_], _)` — Branch C: picker with per-row switch forms

  Edit freely — this file is your code.
  """

  use SigraInstallGoldenTmpWeb, :live_view

  alias SigraInstallGoldenTmp.Organizations

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
    assigns = assign(assigns, :branch, pick_branch(assigns.memberships, assigns.pending_invitations))

    ~H"""
    <Layouts.flash_group flash={@flash} />
    <div :if={@branch == :a}>{render_branch_a(assigns)}</div>
    <div :if={@branch == :b}>{render_branch_b(assigns)}</div>
    <div :if={@branch == :c}>{render_branch_c(assigns)}</div>
    """
  end

  # Branch selection — three render arms keyed on (memberships, pending_invites).
  defp pick_branch([], []), do: :a
  defp pick_branch([], [_ | _]), do: :b
  defp pick_branch([_ | _], _), do: :c

  # ──────────────────────────────────────────────────────────────────────
  # Branch A — zero memberships, zero pending invitations
  # ──────────────────────────────────────────────────────────────────────
  defp render_branch_a(assigns) do
    ~H"""
    <div class="sigra-auth-flow">
      <.header>
        Create your first organization
        <:subtitle>
          You don't belong to any organizations yet. Create one to get started.
        </:subtitle>
      </.header>

      <.form
        for={@form}
        id="organization-create-form"
        phx-change="validate"
        phx-submit="create"
        class="sigra-auth-stack"
      >
        <.input field={@form[:name]} type="text" label="Organization name" required />

        <p
          id="slug-preview"
          class="sigra-auth-copy sigra-auth-copy--muted"
          aria-live="polite"
        >
          {@slug_preview}
        </p>

        <.button
          phx-disable-with="Creating..."
          class="sigra-auth-action sigra-auth-action--primary sigra-auth-action--block"
        >
          Create organization
        </.button>
      </.form>

      <div class="sigra-auth-cluster sigra-auth-cluster--center">
        <.link navigate={~p"/"} class="sigra-auth-action sigra-auth-action--ghost">
          Skip for now
        </.link>
      </div>
    </div>
    """
  end

  # ──────────────────────────────────────────────────────────────────────
  # Branch B — zero memberships, 1+ pending invitations
  # ──────────────────────────────────────────────────────────────────────
  defp render_branch_b(assigns) do
    ~H"""
    <div class="sigra-auth-flow">
      <.header>
        You have {length(@pending_invitations)} pending invitation(s)
      </.header>

      <ul id="pending-invitations-list" class="sigra-auth-stack">
        <li :for={invitation <- @pending_invitations} class="sigra-auth-split">
          <span>{invitation.organization.name}</span>
          <button
            type="button"
            class="sigra-auth-action sigra-auth-action--primary sigra-auth-action--small"
            disabled
            title="Available in the next release"
          >
            Accept
          </button>
        </li>
      </ul>

      <details class="sigra-auth-disclosure">
        <summary class="sigra-auth-action sigra-auth-action--secondary">
          Or create your own organization →
        </summary>
        <div class="sigra-auth-stack">
          {render_branch_a(assigns)}
        </div>
      </details>
    </div>
    """
  end

  # ──────────────────────────────────────────────────────────────────────
  # Branch C — 1+ memberships (picker)
  # ──────────────────────────────────────────────────────────────────────
  defp render_branch_c(assigns) do
    ~H"""
    <div class="sigra-auth-flow sigra-auth-flow--wide">
      <.header>
        Your organizations
        <:actions>
          <.link navigate={~p"/organizations/new"} class="sigra-auth-action sigra-auth-action--primary">
            + New organization
          </.link>
        </:actions>
      </.header>

      <ul id="organizations-picker-list" class="sigra-auth-stack">
        <li :for={{org, role} <- @memberships} class="sigra-auth-split">
          <div>
            <div class="sigra-auth-copy">{org.name}</div>
            <span class="sigra-auth-status">{humanize_role(role)}</span>
          </div>

          <form action={~p"/organizations/switch"} method="post" class="sigra-auth-stack">
            <input
              type="hidden"
              name="_csrf_token"
              value={Phoenix.Controller.get_csrf_token()}
            />
            <input type="hidden" name="organization_id" value={org.id} />
            <input type="hidden" name="return_to" value="/" />
            <button type="submit" class="sigra-auth-action sigra-auth-action--secondary sigra-auth-action--small" aria-label={"Open " <> org.name}>
              Open
            </button>
          </form>
        </li>
      </ul>

      <section class="sigra-auth-stack">
        <h2 class="sigra-auth-heading sigra-auth-copy--muted">Pending invitations</h2>
        <p
          :if={@pending_invitations == []}
          class="sigra-auth-copy sigra-auth-copy--muted"
        >
          No pending invitations.
        </p>
      </section>
    </div>
    """
  end

  defp humanize_role(role) when is_atom(role),
    do: role |> Atom.to_string() |> String.capitalize()

  defp humanize_role(role), do: to_string(role)

  # Surface the first slug error verbatim so the inline field error text
  # matches the expected copy exactly.
  defp create_error_flash(%Ecto.Changeset{} = changeset) do
    case Keyword.get(changeset.errors, :slug) do
      {"is reserved and cannot be used", _} -> "That slug is reserved. Try another."
      {"has already been taken", _} -> "That slug is already in use. Try another."
      {msg, _} -> msg
      _ -> "Could not create organization."
    end
  end
end
