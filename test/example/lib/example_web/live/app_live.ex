defmodule ExampleWeb.AppLive do
  @moduledoc """
  Vaultr authenticated account home (`/app`).

  The post-login landing for every persona: a thin, Vaultr-branded hub that
  greets the signed-in user and routes them into Sigra's real surfaces
  (account settings, active sessions, organizations) with operator/admin cards
  shown only when the persona's scope allows. This is the demo's proof that a
  host app consuming Sigra gives each persona a coherent, least-surprise
  experience instead of dead-ending on an admin door they cannot open.

  All data is real Sigra state (`Example.Accounts` / `Example.Organizations` /
  `Example.SigraAdminPolicy`), so each persona's page differs by their actual
  security posture, memberships, and roles — not by hardcoded copy.
  """
  use ExampleWeb, :live_view

  import Ecto.Query, only: [from: 2]

  alias Example.Accounts
  alias Example.Organizations
  alias Example.SigraAdminPolicy
  alias ExampleWeb.Layouts

  @impl true
  def mount(_params, _session, socket) do
    scope = socket.assigns.current_scope
    user = scope.user

    {:ok,
     socket
     |> assign(:page_title, "Your Vaultr account")
     |> assign(:greeting_name, user.display_name || user.email)
     |> assign(:mfa_enabled?, Accounts.mfa_enabled?(user))
     |> assign(:passkey_count, Accounts.passkey_count_for_user(user))
     |> assign(:oauth_providers, oauth_providers(user))
     |> assign(:user_organizations, Organizations.list_organizations_for_user(user))
     |> assign(:platform_admin?, SigraAdminPolicy.platform_admin?(scope))
     |> assign(:admin_org_ids, MapSet.new(SigraAdminPolicy.admin_org_ids(scope)))
     |> assign(:deletion_scheduled?, not is_nil(user.deleted_at))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_scope={@current_scope}
      user_organizations={@user_organizations}
    >
      <section class="vt-page-intro" data-testid="app-account-home">
        <header class="vt-panel__header">
          <div>
            <p class="vt-kicker">Your Vaultr account</p>
            <h1 class="vt-panel__title">Welcome back, {@greeting_name}</h1>
            <p class="vt-copy">{@current_scope.user.email}</p>
          </div>
          <.link
            href={~p"/users/log_out"}
            method="delete"
            class="vt-btn vt-btn--ghost"
            data-testid="app-log-out"
          >
            Log out
          </.link>
        </header>

        <div
          :if={@deletion_scheduled?}
          class="vt-panel"
          data-testid="app-deletion-notice"
        >
          <p class="vt-kicker">Account scheduled for deletion</p>
          <h2 class="vt-panel__title">Reactivate your Vaultr account</h2>
          <p class="vt-copy">
            This account is scheduled for deletion. You can cancel it and keep your data.
          </p>
          <a href={~p"/users/reactivation"} class="vt-btn vt-btn--primary">
            Review &amp; reactivate
          </a>
        </div>

        <div class="vt-panel" data-testid="app-security">
          <div class="vt-panel__header">
            <div>
              <p class="vt-kicker">Security</p>
              <h2 class="vt-panel__title">Your sign-in protection</h2>
            </div>
            <a href={~p"/users/settings"} class="vt-btn vt-btn--ghost">Manage security</a>
          </div>
          <ul class="vt-seed-list" data-testid="app-security-factors">
            <li>
              <strong>Password</strong>
              <span class="vt-status-pill vt-status-pill--ok">Set</span>
            </li>
            <li>
              <strong>Two-factor (TOTP)</strong>
              <span :if={@mfa_enabled?} class="vt-status-pill vt-status-pill--ok">On</span>
              <span :if={!@mfa_enabled?} class="vt-status-pill">Add for stronger protection</span>
            </li>
            <li :if={@passkey_count > 0}>
              <strong>Passkeys</strong>
              <span class="vt-status-pill vt-status-pill--ok">
                {@passkey_count} registered
              </span>
            </li>
            <li :for={provider <- @oauth_providers}>
              <strong>Linked identity</strong>
              <span class="vt-status-pill vt-status-pill--ok">
                Connected with {String.capitalize(provider)}
              </span>
            </li>
          </ul>
        </div>

        <div class="vt-card-grid vt-card-grid--three" data-testid="app-quick-actions">
          <a href={~p"/users/settings"} class="vt-panel">
            <p class="vt-kicker">Account</p>
            <h2 class="vt-panel__title">Settings</h2>
            <p class="vt-copy">Update your email, password, and account preferences.</p>
          </a>
          <a href={~p"/users/sessions"} class="vt-panel">
            <p class="vt-kicker">Devices</p>
            <h2 class="vt-panel__title">Active sessions</h2>
            <p class="vt-copy">Review where you're signed in and revoke sessions.</p>
          </a>
          <a href={~p"/users/settings/mfa"} class="vt-panel">
            <p class="vt-kicker">Protect</p>
            <h2 class="vt-panel__title">Two-factor &amp; passkeys</h2>
            <p class="vt-copy">Manage TOTP and passkeys (re-auth required).</p>
          </a>
        </div>

        <div
          :if={@user_organizations != []}
          class="vt-panel"
          data-testid="app-organizations"
        >
          <div class="vt-panel__header">
            <div>
              <p class="vt-kicker">Organizations</p>
              <h2 class="vt-panel__title">Where you work in Vaultr</h2>
            </div>
            <a href={~p"/organizations"} class="vt-btn vt-btn--ghost">View all</a>
          </div>
          <ul class="vt-seed-list">
            <li :for={{org, role} <- @user_organizations} data-testid={"app-org-#{org.slug}"}>
              <div>
                <strong>{org.name}</strong>
                <span class="vt-status-pill vt-status-pill--ok">{role}</span>
              </div>
              <a
                :if={MapSet.member?(@admin_org_ids, org.id)}
                href={~p"/admin/organizations/#{org.slug}"}
                class="vt-btn vt-btn--secondary"
              >
                Open admin console
              </a>
            </li>
          </ul>
        </div>

        <div :if={@platform_admin?} class="vt-panel" data-testid="app-platform-admin">
          <p class="vt-kicker">Operator</p>
          <h2 class="vt-panel__title">Sigra Admin</h2>
          <p class="vt-copy">
            You have platform admin access — search users, review sessions, investigate
            audit trails, and manage every organization.
          </p>
          <a href={~p"/admin"} class="vt-btn vt-btn--primary">Open Sigra Admin</a>
        </div>
      </section>
    </Layouts.app>
    """
  end

  # Distinct OAuth providers linked to this user (e.g. "github"). Scoped query —
  # no association preload needed and no PII beyond the provider name.
  defp oauth_providers(user) do
    Example.Repo.all(
      from(i in Example.Accounts.UserIdentity,
        where: i.user_id == ^user.id,
        distinct: true,
        order_by: i.provider,
        select: i.provider
      )
    )
  end
end
