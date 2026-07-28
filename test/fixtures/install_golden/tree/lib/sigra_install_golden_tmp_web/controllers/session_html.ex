defmodule SigraInstallGoldenTmpWeb.SessionHTML do
  @moduledoc """
  Controller-mode login templates.

  Per Phase 10.1.1 D-12 / B9, the login page is a plain controller +
  HEEx template in BOTH `--live` and `--no-live` installs. LiveView's
  LiveView form submission attributes were swallowing the browser form
  submit during UAT. With no LiveView process on the page, the browser
  performs a real HTTP POST to `SessionController.create/2`.

  Two separate form assigns (`@form` and `@magic_link_form`) isolate
  validation/flash state so an error on one form does not corrupt the
  other.
  """
  use SigraInstallGoldenTmpWeb, :html
  import SigraInstallGoldenTmpWeb.SigraAuthComponents
  use Gettext, backend: SigraInstallGoldenTmpWeb.Gettext

  def new(assigns) do
    ~H"""
    <.sigra_auth_page>
      <div class="sigra-auth-flow sigra-auth-stack sigra-auth-stack--6">
        <.header>
          {dgettext("sigra", "Sign in")}
          <:subtitle>
            {dgettext("sigra", "New here?")}
            <.link navigate={~p"/users/register"}>
              {dgettext("sigra", "Create an account")}
            </.link>
          </:subtitle>
        </.header>


      <%= if @passkey_primary_enabled do %>
        <.form
          :let={f}
          for={@form}
          id="passkey_login_form"
          action={~p"/users/log_in/passkey"}
          method="post"
          data-options-path={~p"/users/log_in/passkey/options"}
          class="sigra-auth-stack sigra-auth-stack--4"
        >
          <.input field={f[:email]} type="email" label={dgettext("sigra", "Email")} autocomplete="username webauthn" required />
          <input type="hidden" name="passkey[response]" id="passkey_login_response" />
          <p
            data-passkey-login-status
            data-passkey-status=""
            class="sigra-auth-notice"
            aria-live="polite"
          >
          </p>

          <button
            type="button"
            id="passkey_login_button"
            class="sigra-auth-action sigra-auth-action--primary sigra-auth-action--block"
          >
            {dgettext("sigra", "Continue with a passkey")}
          </button>
        </.form>

        <details class="sigra-auth-disclosure">
          <summary>{dgettext("sigra", "Other ways to sign in")}</summary>
          <div class="sigra-auth-stack sigra-auth-stack--6">
            <.form :let={f} for={@magic_link_form} id="magic_link_form" action={~p"/users/log_in"} method="post" class="sigra-auth-stack sigra-auth-stack--4">
              <input type="hidden" name="_action" value="magic_link" />
              <.input field={f[:email]} type="email" label={dgettext("sigra", "Email for sign-in link")} autocomplete="username" required />
              <.sigra_auth_button class="sigra-auth-action sigra-auth-action--secondary sigra-auth-action--block">
                {dgettext("sigra", "Email me a sign-in link")}
              </.sigra_auth_button>
            </.form>

            <div class="sigra-auth-divider">{dgettext("sigra", "or use a password")}</div>
            <%= password_form(assigns) %>

            <div class="sigra-auth-divider">{dgettext("sigra", "or use work sign-in")}</div>
            <%= enterprise_form(assigns) %>
          </div>
        </details>
      <% else %>

        <.form :let={f} for={@magic_link_form} id="magic_link_form" action={~p"/users/log_in"} method="post" class="sigra-auth-stack sigra-auth-stack--4">
          <input type="hidden" name="_action" value="magic_link" />
          <.input field={f[:email]} type="email" label={dgettext("sigra", "Email")} autocomplete="username" required />

          <.sigra_auth_button class="sigra-auth-action sigra-auth-action--primary sigra-auth-action--block">
            {dgettext("sigra", "Email me a sign-in link")} <span aria-hidden="true">&rarr;</span>
          </.sigra_auth_button>
        </.form>

        <details class="sigra-auth-disclosure">
          <summary>{dgettext("sigra", "Other ways to sign in")}</summary>
          <div class="sigra-auth-stack sigra-auth-stack--6">
            <%= password_form(assigns) %>
            <div class="sigra-auth-divider">{dgettext("sigra", "or use work sign-in")}</div>
            <%= enterprise_form(assigns) %>
          </div>
        </details>

      <% end %>

      </div>
    </.sigra_auth_page>
    """
  end

  defp password_form(assigns) do
    ~H"""
    <.form :let={f} for={@form} id="login_form" action={~p"/users/log_in"} method="post" class="sigra-auth-stack sigra-auth-stack--4">
      <.input field={f[:email]} type="email" label={dgettext("sigra", "Email")} autocomplete="username" required />
      <.input field={f[:password]} type="password" label={dgettext("sigra", "Password")} autocomplete="current-password" required />

      <label class="sigra-auth-cluster">
        <input type="checkbox" name={f[:remember_me].name} value="true" class="sigra-auth-check" />
        {dgettext("sigra", "Keep me signed in")}
      </label>

      <.sigra_auth_button class="sigra-auth-action sigra-auth-action--secondary sigra-auth-action--block">
        {dgettext("sigra", "Sign in with password")}
      </.sigra_auth_button>
    </.form>
    """
  end

  defp enterprise_form(assigns) do
    ~H"""
    <section class="sigra-auth-section" aria-labelledby="enterprise-sign-in-title">
      <div class="sigra-auth-stack sigra-auth-stack--2">
        <h2 id="enterprise-sign-in-title">{dgettext("sigra", "Work sign-in")}</h2>
        <p>{dgettext("sigra", "Enter your work email. We'll continue to your organization's sign-in page when there is an exact active match.")}</p>
      </div>

      <.form :let={f} for={@form} id="enterprise_login_form" action={~p"/users/log_in"} method="post" class="sigra-auth-stack sigra-auth-stack--4">
        <input type="hidden" name="_action" value="enterprise" />
        <.input field={f[:email]} type="email" label={dgettext("sigra", "Work email")} autocomplete="username" required />
        <.sigra_auth_button class="sigra-auth-action sigra-auth-action--secondary sigra-auth-action--block">
          {dgettext("sigra", "Continue with work sign-in")}
        </.sigra_auth_button>
      </.form>
    </section>
    """
  end
end
