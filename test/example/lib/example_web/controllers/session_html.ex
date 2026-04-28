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
    <div class="mx-auto max-w-sm">
      <.header>
        Log in
        <:subtitle>
          Don't have an account?
          <.link navigate={~p"/users/register"} class="font-semibold text-brand hover:underline">
            Sign up
          </.link>
          for an account now.
        </:subtitle>
      </.header>

      <%= if @passkey_primary_enabled do %>
        <% # Passkey-primary section %>
        <.form
          :let={f}
          for={@form}
          id="passkey_login_form"
          action="/users/log_in/passkey"
          method="post"
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
            class="min-h-5 text-sm text-base-content/70"
            aria-live="polite"
          >
          </p>

          <.button type="button" id="passkey_login_button" class="btn btn-primary w-full">
            Continue with passkey
          </.button>
        </.form>

        <div class="mt-3">
          <a href="#login_form" class="btn btn-secondary w-full">Use password instead</a>
        </div>

        <% # Magic link recovery remains visible in passkey-primary mode. %>
        <.form
          :let={f}
          for={@magic_link_form}
          id="magic_link_form"
          action={~p"/users/log_in"}
          method="post"
          class="mt-3"
        >
          <input type="hidden" name="_action" value="magic_link" />
          <.input
            field={f[:email]}
            type="email"
            label="Email for recovery link"
            autocomplete="username"
            required
          />

          <.button class="btn btn-outline w-full">
            Email me a magic link
          </.button>
        </.form>

        <% # Password fallback stays on the same controller-rendered page. %>
        <div class="relative my-6">
          <div class="absolute inset-0 flex items-center">
            <hr class="w-full" />
          </div>
          <div class="relative flex justify-center text-sm">
            <span class="bg-white px-2 text-gray-500">or use your password</span>
          </div>
        </div>

        <.form :let={f} for={@form} id="login_form" action={~p"/users/log_in"} method="post">
          <.input field={f[:email]} type="email" label="Email" autocomplete="username" required />
          <.input
            field={f[:password]}
            type="password"
            label="Password"
            autocomplete="current-password"
            required
          />

          <div class="flex items-center justify-between">
            <label class="flex items-center gap-2 text-sm">
              <input type="checkbox" name={f[:remember_me].name} value="true" class="checkbox" />
              Keep me logged in
            </label>
          </div>

          <.button class="btn btn-primary w-full">
            Log in <span aria-hidden="true">&rarr;</span>
          </.button>
        </.form>

        <%= if @oauth_providers != [] do %>
          <div class="relative my-6">
            <div class="absolute inset-0 flex items-center">
              <hr class="w-full" />
            </div>
            <div class="relative flex justify-center text-sm">
              <span class="bg-white px-2 text-gray-500">or continue with</span>
            </div>
          </div>

          <div class="space-y-3">
            <%= for {provider, _config} <- @oauth_providers do %>
              <a
                href={~p"/auth/#{provider}"}
                class="w-full h-10 flex items-center justify-center gap-2 rounded-lg border border-gray-300 bg-white hover:bg-gray-50 text-sm font-medium transition-colors"
              >
                <%= ExampleWeb.OAuthHTML.oauth_provider_icon(provider) %>
                <span>Continue with <%= ExampleWeb.OAuthHTML.oauth_provider_name(provider) %></span>
              </a>
            <% end %>
          </div>
        <% end %>
      <% else %>
        <% # Magic link section %>
        <.form
          :let={f}
          for={@magic_link_form}
          id="magic_link_form"
          action={~p"/users/log_in"}
          method="post"
        >
          <input type="hidden" name="_action" value="magic_link" />
          <.input field={f[:email]} type="email" label="Email" autocomplete="username" required />

          <.button class="btn btn-primary w-full">
            Send magic link <span aria-hidden="true">&rarr;</span>
          </.button>
        </.form>

        <% # Divider %>
        <div class="relative my-6">
          <div class="absolute inset-0 flex items-center">
            <hr class="w-full" />
          </div>
          <div class="relative flex justify-center text-sm">
            <span class="bg-white px-2 text-gray-500">or sign in with password</span>
          </div>
        </div>

        <% # Password section %>
        <.form :let={f} for={@form} id="login_form" action={~p"/users/log_in"} method="post">
          <.input field={f[:email]} type="email" label="Email" autocomplete="username" required />
          <.input
            field={f[:password]}
            type="password"
            label="Password"
            autocomplete="current-password"
            required
          />

          <div class="flex items-center justify-between">
            <label class="flex items-center gap-2 text-sm">
              <input type="checkbox" name={f[:remember_me].name} value="true" class="checkbox" />
              Keep me logged in
            </label>
          </div>

          <.button class="btn btn-primary w-full">
            Log in <span aria-hidden="true">&rarr;</span>
          </.button>
        </.form>

        <%= if @oauth_providers != [] do %>
          <div class="relative my-6">
            <div class="absolute inset-0 flex items-center">
              <hr class="w-full" />
            </div>
            <div class="relative flex justify-center text-sm">
              <span class="bg-white px-2 text-gray-500">or continue with</span>
            </div>
          </div>

          <div class="space-y-3">
            <%= for {provider, _config} <- @oauth_providers do %>
              <a
                href={~p"/auth/#{provider}"}
                class="w-full h-10 flex items-center justify-center gap-2 rounded-lg border border-gray-300 bg-white hover:bg-gray-50 text-sm font-medium transition-colors"
              >
                <%= ExampleWeb.OAuthHTML.oauth_provider_icon(provider) %>
                <span>Continue with <%= ExampleWeb.OAuthHTML.oauth_provider_name(provider) %></span>
              </a>
            <% end %>
          </div>
        <% end %>
      <% end %>
    </div>
    """
  end
end
