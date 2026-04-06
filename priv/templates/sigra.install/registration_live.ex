defmodule <%= web_module %>.RegistrationLive do
  use <%= web_module %>, :live_view

  alias <%= context_module %>.<%= schema_alias %>

  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-sm">
      <.header>
        Register
        <:subtitle>
          Already registered?
          <.link navigate={~p"/users/log_in"} class="font-semibold text-brand hover:underline">
            Log in
          </.link>
          to your account now.
        </:subtitle>
      </.header>

      <.form
        :let={f}
        for={@form}
        id="registration_form"
        phx-submit="save"
        phx-change="validate"
        phx-trigger-action={@trigger_submit}
        action={~p"/users/log_in?_action=registered"}
        method="post"
      >
        <p :if={@check_errors} class="alert alert-danger">
          Oops, something went wrong! Please check the errors below.
        </p>

        <.input field={f[:email]} type="email" label="Email" autocomplete="username" required />
        <.input field={f[:password]} type="password" label="Password" autocomplete="new-password" required />

        <.button phx-disable-with="Creating account..." class="btn btn-primary w-full">
          Create an account <span aria-hidden="true">→</span>
        </.button>
      </.form>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    changeset = <%= context_module %>.change_user_registration(%<%= schema_alias %>{})
    socket = socket |> assign(trigger_submit: false, check_errors: false) |> assign_form(changeset)
    {:ok, socket, temporary_assigns: [form: nil]}
  end

  def handle_event("save", %{"user" => user_params}, socket) do
    case <%= context_module %>.register_user(user_params) do
      {:ok, user} ->
        # Phase 3 will send confirmation email here
        changeset = <%= context_module %>.change_user_registration(user)
        {:noreply, socket |> assign(trigger_submit: true) |> assign_form(changeset)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, socket |> assign(check_errors: true) |> assign_form(changeset)}
    end
  end

  def handle_event("validate", %{"user" => user_params}, socket) do
    changeset = <%= context_module %>.change_user_registration(%<%= schema_alias %>{}, user_params)
    {:noreply, assign_form(socket, Map.put(changeset, :action, :validate))}
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    form = to_form(changeset, as: "user")

    if changeset.valid? do
      assign(socket, form: form, check_errors: false)
    else
      assign(socket, form: form)
    end
  end
end
