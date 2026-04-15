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

        <%% # Add custom fields here (e.g., :name, :company) %>
        <.input field={f[:email]} type="email" label="Email" autocomplete="username" required />
        <.input field={f[:password]} type="password" label="Password" autocomplete="new-password" required />

        <label
          :if={@passkey_primary_enabled}
          class="mb-4 flex items-start gap-3 rounded border border-gray-200 bg-gray-50 p-3 text-sm"
        >
          <input
            type="checkbox"
            name="user[enroll_passkey]"
            value="true"
            checked={@enroll_passkey_after_signup}
            class="checkbox mt-0.5"
          />
          <span>
            <span class="font-semibold">Add a passkey after creating your account</span>
            <span class="block text-gray-600">
              After confirming your email, you will continue to passkey setup.
            </span>
          </span>
        </label>

        <%% # Password strength indicator %>
        <div :if={@password_strength} class="mt-1 mb-4">
          <div class="flex items-center gap-2">
            <div class="flex-1 h-2 rounded-full bg-gray-200">
              <div
                class={[
                  "h-2 rounded-full transition-all duration-300",
                  password_strength_color(@password_strength)
                ]}
                style={"width: #{password_strength_width(@password_strength)}%"}
              />
            </div>
            <span class={"text-xs font-medium #{password_strength_text_color(@password_strength)}"}>
              {password_strength_label(@password_strength)}
            </span>
          </div>
          <ul :if={@password_suggestions != []} class="mt-1 text-xs text-gray-500 list-disc list-inside">
            <li :for={suggestion <- @password_suggestions}>{suggestion}</li>
          </ul>
        </div>

        <.button phx-disable-with="Creating account..." class="btn btn-primary w-full">
          Create an account <span aria-hidden="true">&rarr;</span>
        </.button>
      </.form>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    changeset = <%= context_module %>.change_user_registration(%<%= schema_alias %>{})

    socket =
      socket
      |> assign(trigger_submit: false, check_errors: false)
      |> assign(passkey_primary_enabled: <%= context_module %>.passkey_primary_enabled?())
      |> assign(enroll_passkey_after_signup: false)
      |> assign(password_strength: nil, password_suggestions: [])
      |> assign_form(changeset)

    {:ok, socket, temporary_assigns: [form: nil]}
  end

  def handle_event("save", %{"user" => user_params}, socket) do
    enroll_passkey = Map.get(user_params, "enroll_passkey") in ["true", true, "on", "1"]

    case <%= context_module %>.register_user(user_params) do
      {:ok, user} ->
        # D-05: deliver confirmation email (B5 repair; helper exists at <%= context_module %>.deliver_user_confirmation_instructions/2)
        confirmation_url_fun = fn token ->
          if enroll_passkey do
            url(socket, ~p"/users/confirm/#{token}?enroll_passkey=1")
          else
            url(socket, ~p"/users/confirm/#{token}")
          end
        end

        case <%= context_module %>.deliver_user_confirmation_instructions(user, confirmation_url_fun) do
          {:ok, :sent} -> :ok
          {:error, :already_confirmed} -> :ok
        end

        changeset = <%= context_module %>.change_user_registration(user)
        {:noreply, socket |> assign(trigger_submit: true) |> assign_form(changeset)}

      {:error, :email_taken} ->
        # Enumeration-safe: show generic message
        changeset = <%= context_module %>.change_user_registration(%<%= schema_alias %>{})

        {:noreply,
         socket
         |> put_flash(:info, "If this email is available, your account has been created. Please check your email.")
         |> assign_form(changeset)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, socket |> assign(check_errors: true) |> assign_form(changeset)}
    end
  end

  def handle_event("validate", %{"user" => user_params}, socket) do
    changeset = <%= context_module %>.change_user_registration(%<%= schema_alias %>{}, user_params)
    enroll_passkey = Map.get(user_params, "enroll_passkey") in ["true", true, "on", "1"]

    # Real-time password strength feedback
    {strength, suggestions} =
      case Map.get(user_params, "password", "") do
        "" -> {nil, []}
        password -> Sigra.PasswordPolicy.check_strength(password)
      end

    {:noreply,
     socket
     |> assign(password_strength: strength, password_suggestions: suggestions)
     |> assign(enroll_passkey_after_signup: enroll_passkey)
     |> assign_form(Map.put(changeset, :action, :validate))}
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    form = to_form(changeset, as: "user")

    if changeset.valid? do
      assign(socket, form: form, check_errors: false)
    else
      assign(socket, form: form)
    end
  end

  defp password_strength_color(:weak), do: "bg-red-500"
  defp password_strength_color(:fair), do: "bg-yellow-500"
  defp password_strength_color(:strong), do: "bg-green-500"
  defp password_strength_color(_), do: "bg-gray-300"

  defp password_strength_width(:weak), do: 33
  defp password_strength_width(:fair), do: 66
  defp password_strength_width(:strong), do: 100
  defp password_strength_width(_), do: 0

  defp password_strength_label(:weak), do: "Weak"
  defp password_strength_label(:fair), do: "Fair"
  defp password_strength_label(:strong), do: "Strong"
  defp password_strength_label(_), do: ""

  defp password_strength_text_color(:weak), do: "text-red-600"
  defp password_strength_text_color(:fair), do: "text-yellow-600"
  defp password_strength_text_color(:strong), do: "text-green-600"
  defp password_strength_text_color(_), do: "text-gray-400"
end
