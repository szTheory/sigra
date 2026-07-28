defmodule <%= web_module %>.RegistrationLive do
  use <%= web_module %>, :live_view
  import <%= web_module %>.SigraAuthComponents

  alias <%= context_module %>.<%= schema_alias %>

  def render(assigns) do
    ~H"""
    <.sigra_auth_page>
      <div class="sigra-auth-flow sigra-auth-stack sigra-auth-stack--6">
        <.header>
          Register
          <:subtitle>
            Already registered?
            <.link navigate={~p"/users/log_in"}>
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
        class="sigra-auth-stack sigra-auth-stack--4"
      >
        <p :if={@check_errors} class="sigra-auth-notice sigra-auth-notice--danger">
          We couldn't create your account. Check the highlighted fields and try again.
        </p>

        <%% # Add custom fields here (e.g., :name, :company) %>
        <.input field={f[:email]} type="email" label="Email" autocomplete="username" required />
        <.input field={f[:password]} type="password" label="Password" autocomplete="new-password" required />

<%= if passkeys? do %>
        <label
          :if={@passkey_primary_enabled}
          class="sigra-auth-section sigra-auth-check-row"
        >
          <input
            type="checkbox"
            name="user[enroll_passkey]"
            value="true"
            checked={@enroll_passkey_after_signup}
            class="sigra-auth-check"
          />
          <span>
            <strong>Add a passkey after creating your account</strong>
            <span class="sigra-auth-copy sigra-auth-copy--muted">
              After confirming your email, you will continue to passkey setup.
            </span>
          </span>
        </label>
<% end %>

        <%% # Password strength indicator %>
        <div :if={@password_strength} class="sigra-auth-stack sigra-auth-stack--2">
          <div class="sigra-auth-cluster">
            <div class="sigra-auth-meter sigra-auth-grow">
              <div
                class={[
                  "sigra-auth-meter__value",
                  password_strength_color(@password_strength)
                ]}
                style={"width: #{password_strength_width(@password_strength)}%"}
              />
            </div>
            <span class={"sigra-auth-status #{password_strength_text_color(@password_strength)}"}>
              {password_strength_label(@password_strength)}
            </span>
          </div>
          <ul :if={@password_suggestions != []} class="sigra-auth-list">
            <li :for={suggestion <- @password_suggestions}>{suggestion}</li>
          </ul>
        </div>

        <.sigra_auth_button phx-disable-with="Creating account..." class="sigra-auth-action sigra-auth-action--primary sigra-auth-action--block">
          Create an account <span aria-hidden="true">&rarr;</span>
        </.sigra_auth_button>
        </.form>
      </div>
    </.sigra_auth_page>
    """
  end

  def mount(_params, _session, socket) do
    changeset = <%= context_module %>.change_user_registration(%<%= schema_alias %>{})

    socket =
      socket
      |> assign(trigger_submit: false, check_errors: false)
<%= if passkeys? do %>
      |> assign(passkey_primary_enabled: <%= context_module %>.passkey_primary_enabled?())
      |> assign(enroll_passkey_after_signup: false)
<% end %>
      |> assign(password_strength: nil, password_suggestions: [])
      |> assign_form(changeset)

    {:ok, socket, temporary_assigns: [form: nil]}
  end

  def handle_event("save", %{"user" => user_params}, socket) do
<%= if passkeys? do %>
    enroll_passkey = Map.get(user_params, "enroll_passkey") in ["true", true, "on", "1"]
<% end %>

    case <%= context_module %>.register_user(user_params) do
      {:ok, user} ->
        # D-05: deliver confirmation email (B5 repair; helper exists at <%= context_module %>.deliver_user_confirmation_instructions/2)
        confirmation_url_fun = fn token ->
<%= if passkeys? do %>
          if enroll_passkey do
            url(socket, ~p"/users/confirm/#{token}?enroll_passkey=1")
          else
            url(socket, ~p"/users/confirm/#{token}")
          end
<% else %>
          url(socket, ~p"/users/confirm/#{token}")
<% end %>
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
<%= if passkeys? do %>
    enroll_passkey = Map.get(user_params, "enroll_passkey") in ["true", true, "on", "1"]
<% end %>

    # Real-time password strength feedback
    {strength, suggestions} =
      case Map.get(user_params, "password", "") do
        "" -> {nil, []}
        password -> Sigra.PasswordPolicy.check_strength(password)
      end

    {:noreply,
     socket
     |> assign(password_strength: strength, password_suggestions: suggestions)
<%= if passkeys? do %>
     |> assign(enroll_passkey_after_signup: enroll_passkey)
<% end %>
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

  defp password_strength_color(:weak), do: "sigra-auth-meter__value--weak"
  defp password_strength_color(:fair), do: "sigra-auth-meter__value--fair"
  defp password_strength_color(:strong), do: "sigra-auth-meter__value--strong"
  defp password_strength_color(_), do: ""

  defp password_strength_width(:weak), do: 33
  defp password_strength_width(:fair), do: 66
  defp password_strength_width(:strong), do: 100
  defp password_strength_width(_), do: 0

  defp password_strength_label(:weak), do: "Weak"
  defp password_strength_label(:fair), do: "Fair"
  defp password_strength_label(:strong), do: "Strong"
  defp password_strength_label(_), do: ""

  defp password_strength_text_color(:weak), do: "sigra-auth-status--danger"
  defp password_strength_text_color(:fair), do: "sigra-auth-status--warning"
  defp password_strength_text_color(:strong), do: "sigra-auth-status--success"
  defp password_strength_text_color(_), do: ""
end
