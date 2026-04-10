defmodule ExampleWeb.LoginLive do
  use ExampleWeb, :live_view

  def render(assigns) do
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

        <.button phx-disable-with="Sending link..." class="btn btn-primary w-full">
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
      <.form :let={f} for={@form} id="login_form" action={~p"/users/log_in"} phx-update="ignore">
        <.input field={f[:email]} type="email" label="Email" autocomplete="username" required />
        <.input field={f[:password]} type="password" label="Password" autocomplete="current-password" required />

        <div class="flex items-center justify-between">
          <label class="flex items-center gap-2 text-sm">
            <input type="checkbox" name={f[:remember_me].name} value="true" class="checkbox" />
            Keep me logged in
          </label>
        </div>

        <.button phx-disable-with="Logging in..." class="btn btn-primary w-full">
          Log in <span aria-hidden="true">&rarr;</span>
        </.button>
      </.form>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    email = Phoenix.Flash.get(socket.assigns.flash, :email)
    form = to_form(%{"email" => email}, as: "user")
    magic_link_form = to_form(%{"email" => email}, as: "user")

    {:ok, assign(socket, form: form, magic_link_form: magic_link_form),
     temporary_assigns: [form: form, magic_link_form: magic_link_form]}
  end
end
