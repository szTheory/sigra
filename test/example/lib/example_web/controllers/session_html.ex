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
    <section
      class="vt-auth vt-auth--login"
      data-testid="vaultr-login"
      data-demo-brand-surface
      data-demo-brand-presets={@demo_brand_presets_json}
      data-demo-brand-default={@demo_brand_default_id}
      data-demo-brand-theme-default={to_string(@demo_brand_default_theme)}
      data-theme={to_string(@demo_brand_default_theme)}
      style={@demo_brand_default_style}
    >
      <div class="vt-auth__panel">
        <a href={~p"/"} class="vt-brand">
          <img
            src={@demo_brand_default_profile.logo_url || ""}
            alt={
              if @demo_brand_default_profile.logo_url,
                do: @demo_brand_default_profile.logo_alt,
                else: ""
            }
            class="vt-brand__mark"
            data-demo-brand-logo
            hidden={is_nil(@demo_brand_default_profile.logo_url)}
          />
          <span
            class="vt-brand__mark vt-brand__mark--generated"
            data-demo-brand-initial
            data-demo-brand-fallback-mark
            hidden={not is_nil(@demo_brand_default_profile.logo_url)}
          >
            {String.slice(@demo_brand_default_profile.product_name, 0, 1)}
          </span>
          <span>
            <span class="vt-brand__name" data-demo-brand-text="product_name">
              {@demo_brand_default_profile.product_name}
            </span>
          </span>
        </a>

        <div class="vt-auth__intro">
          <p class="vt-kicker">Sign in</p>
          <h1 class="vt-auth__title">
            Log in to
            <span data-demo-brand-text="product_name">
              {@demo_brand_default_profile.product_name}
            </span>
          </h1>
          <p class="vt-auth__copy">
            New to <span data-demo-brand-text="product_name">
              {@demo_brand_default_profile.product_name}
            </span>?
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
