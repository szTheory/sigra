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
    <section class="vt-auth" data-testid="vaultr-login">
      <div class="vt-auth__panel">
        <a href={~p"/"} class="vt-brand">
          <img src={~p"/images/vaultr-mark.svg"} width="36" height="36" alt="" class="vt-brand__mark" />
          <span>
            <span class="vt-brand__name">Vaultr</span>
            <span class="vt-brand__tag">Fictional cohort app</span>
          </span>
        </a>

        <div class="vt-auth__intro">
          <p class="vt-kicker">Shared Vaultr login</p>
          <h1 class="vt-auth__title">Log in to Vaultr</h1>
          <p class="vt-auth__copy">
            This is the shared demo login for Vaultr users and Sigra Admin operators.
            Use <code class="vt-code">admin@demo.vaultr.test</code>
            for the platform-operator path into <code class="vt-code">/admin</code>.
            Don't have an account?
            <.link navigate={~p"/users/register"} class="vt-link">
              Sign up
            </.link>
            for an account now.
          </p>
        </div>

        <%= if @passkey_primary_enabled do %>
          <% # Passkey-primary section %>
          <.form
            :let={f}
            for={@form}
            id="passkey_login_form"
            action="/users/log_in/passkey"
            method="post"
            class="vt-auth__form"
            data-options-path="/users/log_in/passkey/options"
          >
            <.input
              field={f[:email]}
              type="email"
              label="Email"
              autocomplete="username webauthn"
              required
            />
            <input type="hidden" name="passkey[response]" id="passkey_login_response" />
            <p
              data-passkey-login-status
              data-passkey-status=""
              class="vt-auth__copy"
              aria-live="polite"
            >
            </p>

            <.button
              type="button"
              id="passkey_login_button"
              class="vt-btn vt-btn--primary vt-btn--block"
            >
              Continue with passkey
            </.button>
          </.form>

          <div class="vt-auth__form">
            <a href="#login_form" class="vt-btn vt-btn--secondary vt-btn--block">
              Use password instead
            </a>
          </div>

          <p class="vt-auth__copy">
            Passkeys are not break-glass sign-in for SSO-only organizations.
          </p>

          <% # Magic link recovery remains visible in passkey-primary mode. %>
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
              label="Email for recovery link"
              autocomplete="username"
              required
            />

            <.button class="vt-btn vt-btn--ghost vt-btn--block">
              Email me a magic link
            </.button>
          </.form>

          <p class="vt-auth__copy">
            Magic links are not break-glass recovery for SSO-only organizations.
          </p>

          <% # Password fallback stays on the same controller-rendered page. %>
          <div class="vt-divider">
            <span>or use your password</span>
          </div>

          <.form
            :let={f}
            for={@form}
            id="login_form"
            action={~p"/users/log_in"}
            method="post"
            class="vt-auth__form"
          >
            <.input field={f[:email]} type="email" label="Email" autocomplete="username" required />
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
                Keep me logged in
              </label>
            </div>

            <.button class="vt-btn vt-btn--primary vt-btn--block">
              Log in <span aria-hidden="true">&rarr;</span>
            </.button>
          </.form>
        <% else %>
          <% # Magic link section %>
          <.form
            :let={f}
            for={@magic_link_form}
            id="magic_link_form"
            action={~p"/users/log_in"}
            method="post"
            class="vt-auth__form"
          >
            <input type="hidden" name="_action" value="magic_link" />
            <.input field={f[:email]} type="email" label="Email" autocomplete="username" required />

            <.button class="vt-btn vt-btn--primary vt-btn--block">
              Send magic link <span aria-hidden="true">&rarr;</span>
            </.button>
          </.form>

          <p class="vt-auth__copy">
            Magic links are not break-glass recovery for SSO-only organizations.
          </p>

          <% # Divider %>
          <div class="vt-divider">
            <span>or sign in with password</span>
          </div>

          <% # Password section %>
          <.form
            :let={f}
            for={@form}
            id="login_form"
            action={~p"/users/log_in"}
            method="post"
            class="vt-auth__form"
          >
            <.input field={f[:email]} type="email" label="Email" autocomplete="username" required />
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
                Keep me logged in
              </label>
            </div>

            <.button class="vt-btn vt-btn--primary vt-btn--block">
              Log in <span aria-hidden="true">&rarr;</span>
            </.button>
          </.form>
        <% end %>

        <div class="vt-divider">
          <span>or continue with enterprise SSO</span>
        </div>

        <section class="vt-auth__secondary">
          <div class="vt-auth__intro">
            <h2 class="vt-auth__title">Enterprise sign-in</h2>
            <p class="vt-auth__copy">
              Enter your work email. If Sigra finds one exact active organization match, it will send you to the
              canonical enterprise sign-in route for that organization.
            </p>
          </div>

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

          <p class="vt-auth__copy">
            If your organization enforces SSO-only, break-glass stays limited to password sign-in
            and password reset.
          </p>
        </section>
      </div>
    </section>
    """
  end
end
