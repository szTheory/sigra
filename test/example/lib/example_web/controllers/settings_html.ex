defmodule ExampleWeb.SettingsHTML do
  use ExampleWeb, :html

  def edit(assigns) do
    ~H"""
    <div class="mx-auto max-w-2xl space-y-10">
      <Layouts.flash_group flash={@flash} />

      <section>
        <.header>
          Account Settings
          <:subtitle>Manage your password and connected sign-in methods.</:subtitle>
        </.header>

        <div class="mt-6 rounded-lg border border-gray-200 bg-white p-6">
          <h2 class="text-base font-semibold text-gray-900">Password</h2>

          <%= if @has_password do %>
            <p class="mt-2 text-sm text-gray-600">Password set. You can use email and password to sign in.</p>
          <% else %>
            <p class="mt-2 text-sm text-gray-600">No password set. Add one to keep access to your account if you unlink your only OAuth provider.</p>

            <.form :let={f} for={@password_form} action={~p"/users/settings/password"} method="post" class="mt-4 space-y-4">
              <.input field={f[:password]} type="password" label="New password" required />
              <.input field={f[:password_confirmation]} type="password" label="Confirm password" required />
              <.button class="btn btn-primary">Set password</.button>
            </.form>
          <% end %>
        </div>
      </section>

      <section>
        <.header>
          Connected Accounts
          <:subtitle>Manage your linked sign-in providers.</:subtitle>
        </.header>

        <div class="mt-6 space-y-4">
          <%= if @identities == [] do %>
            <div class="rounded-lg border border-dashed border-gray-300 bg-gray-50 px-4 py-8 text-center">
              <p class="text-sm font-semibold text-gray-900">No connected accounts</p>
              <p class="mt-1 text-sm text-gray-500">Link a sign-in provider for faster access.</p>
            </div>
          <% else %>
            <%= for identity <- @identities do %>
              <div class="flex items-start justify-between rounded-lg border border-gray-200 bg-gray-50 p-4">
                <div>
                  <div class="flex items-center gap-2">
                    <%= ExampleWeb.OAuthHTML.oauth_provider_icon(ExampleWeb.OAuthHTML.safe_provider_atom(identity.provider)) %>
                    <span class="text-sm font-semibold"><%= ExampleWeb.OAuthHTML.oauth_provider_name(ExampleWeb.OAuthHTML.safe_provider_atom(identity.provider)) %></span>
                    <span class="text-sm text-gray-500"><%= identity.provider_email %></span>
                  </div>
                </div>

                <div>
                  <%= if @can_unlink do %>
                    <.form for={%{}} action={~p"/users/settings/oauth/identities/#{identity.id}"} method="post">
                      <input type="hidden" name="_method" value="delete" />
                      <button
                        type="submit"
                        data-confirm={"Unlink #{ExampleWeb.OAuthHTML.oauth_provider_name(ExampleWeb.OAuthHTML.safe_provider_atom(identity.provider))}? You'll still be able to log in with: #{@remaining_methods_text}."}
                        class="rounded-md bg-red-50 px-3 py-1.5 text-sm text-red-600 hover:bg-red-100"
                      >
                        Unlink
                      </button>
                    </.form>
                  <% else %>
                    <button
                      disabled
                      title="Set a password first to keep access to your account."
                      class="cursor-not-allowed rounded-md bg-red-50 px-3 py-1.5 text-sm text-red-600 opacity-50"
                    >
                      Unlink
                    </button>
                  <% end %>
                </div>
              </div>
            <% end %>
          <% end %>

          <%= if @unlinked_providers != [] do %>
            <div class="pt-4">
              <h3 class="text-sm font-semibold">Add a sign-in method</h3>
              <div class="mt-3 space-y-3">
                <%= for {provider, _config} <- @unlinked_providers do %>
                  <a
                    href={~p"/auth/#{provider}"}
                    class="flex h-10 w-full items-center justify-center gap-2 rounded-lg border border-gray-300 bg-white text-sm font-medium transition-colors hover:bg-gray-50"
                  >
                    <%= ExampleWeb.OAuthHTML.oauth_provider_icon(provider) %>
                    <span>Continue with <%= ExampleWeb.OAuthHTML.oauth_provider_name(provider) %></span>
                  </a>
                <% end %>
              </div>
            </div>
          <% end %>
        </div>
      </section>
    </div>
    """
  end
end
