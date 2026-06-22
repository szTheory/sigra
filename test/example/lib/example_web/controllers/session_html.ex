defmodule ExampleWeb.SessionHTML do
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
  use ExampleWeb, :html

  def new(assigns) do
    ~H"""
    <%!--
      The real login is the Vaultr app's own auth surface: a plain Vaultr page on
      the global Vaultr palette + OS light/dark (no data-theme / inline brand style
      needed — same as the homepage). It carries NO data-demo-brand-* hooks, so
      neither the brand cookie nor demo_branding.js can re-skin it; the homepage
      brand-lab is a preview only. "Vaultr" is hard-coded here exactly as the
      homepage header and app shell hard-code it.
    --%>
    <%!--
      data-theme="system" makes the auth surface follow the OS light/dark
      color-scheme (via the .vt-auth[data-theme="system"] rules) — it carries NO
      brand mapping (that needs [data-demo-brand-surface]) and no JS hook (that
      needs data-demo-brand-presets), so it stays plain Vaultr.
    --%>
    <section
      class="vt-auth vt-auth--login"
      data-testid="vaultr-login"
      data-theme="system"
    >
      <div class="vt-auth__panel">
        <a href={~p"/"} class="vt-brand">
          <img src={~p"/images/vaultr-mark.svg"} alt="Vaultr logo" class="vt-brand__mark" />
          <span>
            <span class="vt-brand__name">Vaultr</span>
            <span class="vt-brand__tag">Team secrets vault</span>
          </span>
        </a>

        <div class="vt-auth__intro">
          <p class="vt-kicker">Sign in</p>
          <h1 class="vt-auth__title">Log in to Vaultr</h1>
          <p class="vt-auth__copy">
            New to Vaultr?
            <.link navigate={~p"/users/register"} class="vt-link">
              Create an account.
            </.link>
          </p>
        </div>

        <.form
          :let={f}
          for={@form}
          id="login_form"
          action={~p"/users/log_in"}
          method="post"
          class="vt-auth__form vt-auth__form--primary"
        >
          <.input
            field={f[:email]}
            type="email"
            label="Email"
            autocomplete="username webauthn"
            required
          />
          <.input
            field={f[:password]}
            type="password"
            label="Password"
            autocomplete="current-password"
            required
          />

          <div class="vt-remember-row">
            <label>
              <input type="checkbox" name={f[:remember_me].name} value="true" class="checkbox" />
              Keep me signed in
            </label>
          </div>

          <.button class="vt-btn vt-btn--primary vt-btn--block">
            Log in <span aria-hidden="true">&rarr;</span>
          </.button>
        </.form>

        <%= if @passkey_primary_enabled do %>
          <.form
            for={@form}
            id="passkey_login_form"
            action="/users/log_in/passkey"
            method="post"
            class="vt-auth__method"
            data-options-path="/users/log_in/passkey/options"
            data-email-input="#login_form input[name='user[email]']"
          >
            <input type="hidden" name="user[email]" data-passkey-email-shadow />
            <input type="hidden" name="passkey[response]" id="passkey_login_response" />

            <p
              data-passkey-login-status
              data-passkey-status=""
              class="vt-auth__status"
              aria-live="polite"
            >
            </p>

            <button
              type="button"
              id="passkey_login_button"
              class="vt-auth__method-button"
            >
              <span aria-hidden="true" class="vt-auth__method-icon">PK</span>
              <span>Use a passkey</span>
            </button>
          </.form>
        <% end %>

        <details class="vt-auth__disclosure">
          <summary>Email me a magic link</summary>
          <.form
            :let={f}
            for={@magic_link_form}
            id="magic_link_form"
            action={~p"/users/log_in"}
            method="post"
            class="vt-auth__form"
          >
            <input type="hidden" name="_action" value="magic_link" />
            <.input
              field={f[:email]}
              type="email"
              label="Email"
              autocomplete="username"
              required
            />

            <.button class="vt-btn vt-btn--ghost vt-btn--block">
              Send magic link
            </.button>
          </.form>
        </details>

        <details class="vt-auth__disclosure">
          <summary>Enterprise SSO</summary>

          <.form
            :let={f}
            for={@form}
            id="enterprise_login_form"
            action={~p"/users/log_in"}
            method="post"
            class="vt-auth__form"
          >
            <input type="hidden" name="_action" value="enterprise" />
            <.input
              field={f[:email]}
              type="email"
              label="Work email"
              autocomplete="username"
              required
            />

            <.button class="vt-btn vt-btn--ghost vt-btn--block">
              Continue with enterprise SSO
            </.button>
          </.form>
        </details>
      </div>
    </section>
    """
  end
end
