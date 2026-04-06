defmodule <%= web_module %>.LoginLive do
  use <%= web_module %>, :live_view

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
          Log in <span aria-hidden="true">→</span>
        </.button>
      </.form>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    email = Phoenix.Flash.get(socket.assigns.flash, :email)
    form = to_form(%{"email" => email}, as: "user")
    {:ok, assign(socket, form: form), temporary_assigns: [form: form]}
  end
end
