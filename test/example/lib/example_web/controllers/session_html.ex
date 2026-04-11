defmodule ExampleWeb.SessionHTML do
  @moduledoc """
  Controller-mode login templates (non-LiveView).

  Per Phase 10.1.1 D-12 / B9, the login page is a plain controller + HEEx
  template rather than a LiveView. This dodges `Phoenix.Component.form/1`'s
  default `phx-submit` registration which was swallowing the browser form
  submit during UAT — with no LiveView process on the page, `<.form>`
  renders a plain `<form action="..." method="post">` and the browser
  performs a real HTTP POST to `SessionController.create/2`.

  Two separate form assigns (`@form` and `@magic_link_form`) isolate
  validation/flash state so an error on one form does not corrupt the other.
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

      <%!-- Magic link section --%>
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

      <%!-- Divider --%>
      <div class="relative my-6">
        <div class="absolute inset-0 flex items-center">
          <hr class="w-full" />
        </div>
        <div class="relative flex justify-center text-sm">
          <span class="bg-white px-2 text-gray-500">or sign in with password</span>
        </div>
      </div>

      <%!-- Password section --%>
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
            <input type="checkbox" name="user[remember_me]" value="true" class="checkbox" />
            Keep me logged in
          </label>
        </div>

        <.button class="btn btn-primary w-full">
          Log in <span aria-hidden="true">&rarr;</span>
        </.button>
      </.form>
    </div>
    """
  end
end
