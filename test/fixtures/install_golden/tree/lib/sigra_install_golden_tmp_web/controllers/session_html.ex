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
      <div class="mx-auto max-w-sm">
        <.header>
          {dgettext("sigra", "Log in")}
          <:subtitle>
            {dgettext("sigra", "New here?")}
            <.link navigate={~p"/users/register"} class="font-semibold text-brand hover:underline">
              {dgettext("sigra", "Create an account.")}
            </.link>
          </:subtitle>
        </.header>


      <%= if @passkey_primary_enabled do %>
        <% # Passkey-primary section %>
        <.form
          :let={f}
          for={@form}
          id="passkey_login_form"
          action={~p"/users/log_in/passkey"}
          method="post"
          data-options-path={~p"/users/log_in/passkey/options"}
        >
          <.input field={f[:email]} type="email" label={dgettext("sigra", "Email")} autocomplete="username webauthn" required />
          <input type="hidden" name="passkey[response]" id="passkey_login_response" />
          <p
            data-passkey-login-status
            data-passkey-status=""
            class="text-sm text-base-content/70"
            aria-live="polite"
          >
          </p>

          <.button type="button" id="passkey_login_button" class="btn btn-primary w-full">
            {dgettext("sigra", "Use a passkey")}
          </.button>
        </.form>

        <div class="mt-3">
          <a href="#login_form" class="btn btn-secondary w-full">
            {dgettext("sigra", "Use password instead")}
          </a>
        </div>

        <p class="mt-3 text-sm text-base-content/70">
          {dgettext("sigra", "Passkeys are not break-glass sign-in for SSO-only organizations.")}
        </p>

        <% # Magic link recovery remains visible in passkey-primary mode. %>
        <.form :let={f} for={@magic_link_form} id="magic_link_form" action={~p"/users/log_in"} method="post" class="mt-3">
          <input type="hidden" name="_action" value="magic_link" />
          <.input field={f[:email]} type="email" label={dgettext("sigra", "Email for recovery link")} autocomplete="username" required />

          <.button class="btn btn-outline w-full">
            {dgettext("sigra", "Email me a magic link")}
          </.button>
        </.form>

        <p class="mt-2 text-sm text-base-content/70">
          {dgettext("sigra", "Magic links are not break-glass recovery for SSO-only organizations.")}
        </p>

        <% # Password fallback stays on the same controller-rendered page. %>
        <div class="relative my-6">
          <div class="absolute inset-0 flex items-center">
            <hr class="w-full" />
          </div>
          <div class="relative flex justify-center text-sm">
            <span class="bg-white px-2 text-gray-500">
              {dgettext("sigra", "or use your password")}
            </span>
          </div>
        </div>

        <.form :let={f} for={@form} id="login_form" action={~p"/users/log_in"} method="post">
          <.input field={f[:email]} type="email" label={dgettext("sigra", "Email")} autocomplete="username" required />
          <.input field={f[:password]} type="password" label={dgettext("sigra", "Password")} autocomplete="current-password" required />

          <div class="flex items-center justify-between">
            <label class="flex items-center gap-2 text-sm">
              <input type="checkbox" name={f[:remember_me].name} value="true" class="checkbox" />
              {dgettext("sigra", "Keep me signed in")}
            </label>
          </div>

          <.button class="btn btn-primary w-full">
            {dgettext("sigra", "Log in")} <span aria-hidden="true">&rarr;</span>
          </.button>
        </.form>
      <% else %>

        <% # Magic link section %>
        <.form :let={f} for={@magic_link_form} id="magic_link_form" action={~p"/users/log_in"} method="post">
          <input type="hidden" name="_action" value="magic_link" />
          <.input field={f[:email]} type="email" label={dgettext("sigra", "Email")} autocomplete="username" required />

          <.button class="btn btn-primary w-full">
            {dgettext("sigra", "Send magic link")} <span aria-hidden="true">&rarr;</span>
          </.button>
        </.form>

        <p class="mt-2 text-sm text-base-content/70">
          {dgettext("sigra", "Magic links are not break-glass recovery for SSO-only organizations.")}
        </p>

        <% # Divider %>
        <div class="relative my-6">
          <div class="absolute inset-0 flex items-center">
            <hr class="w-full" />
          </div>
          <div class="relative flex justify-center text-sm">
            <span class="bg-white px-2 text-gray-500">
              {dgettext("sigra", "or sign in with password")}
            </span>
          </div>
        </div>

        <% # Password section %>
        <.form :let={f} for={@form} id="login_form" action={~p"/users/log_in"} method="post">
          <.input field={f[:email]} type="email" label={dgettext("sigra", "Email")} autocomplete="username" required />
          <.input field={f[:password]} type="password" label={dgettext("sigra", "Password")} autocomplete="current-password" required />

          <div class="flex items-center justify-between">
            <label class="flex items-center gap-2 text-sm">
              <input type="checkbox" name={f[:remember_me].name} value="true" class="checkbox" />
              {dgettext("sigra", "Keep me signed in")}
            </label>
          </div>

          <.button class="btn btn-primary w-full">
            {dgettext("sigra", "Log in")} <span aria-hidden="true">&rarr;</span>
          </.button>
        </.form>

      <% end %>


      <div class="relative my-6">
        <div class="absolute inset-0 flex items-center">
          <hr class="w-full" />
        </div>
        <div class="relative flex justify-center text-sm">
          <span class="bg-white px-2 text-gray-500">
            {dgettext("sigra", "or continue with enterprise SSO")}
          </span>
        </div>
      </div>

      <section class="rounded-2xl border border-base-300 bg-base-100 p-5 shadow-sm">
        <div class="space-y-1">
          <h2 class="text-base font-semibold text-base-content">
            {dgettext("sigra", "Enterprise sign-in")}
          </h2>
          <p class="text-sm text-base-content/70">
            {dgettext("sigra", "Enter your work email. If Sigra finds one exact active organization match, it will send you to the canonical enterprise sign-in route for that organization.")}
          </p>
        </div>

        <.form :let={f} for={@form} id="enterprise_login_form" action={~p"/users/log_in"} method="post" class="mt-4 space-y-4">
          <input type="hidden" name="_action" value="enterprise" />
          <.input field={f[:email]} type="email" label={dgettext("sigra", "Work email")} autocomplete="username" required />

          <.button class="btn btn-outline w-full">
            {dgettext("sigra", "Continue with enterprise SSO")}
          </.button>
        </.form>

        <p class="mt-3 text-sm text-base-content/70">
          {dgettext("sigra", "If your organization enforces SSO-only, break-glass stays limited to password sign-in and password reset.")}
        </p>
        </section>
      </div>
    </.sigra_auth_page>
    """
  end
end
