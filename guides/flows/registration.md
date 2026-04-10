# User Registration

Sigra ships a complete, enumeration-safe registration flow: a LiveView form, a context function, Argon2id password hashing, and a confirmation email. This guide covers the happy path, common customizations, the confirmation lifecycle, and how to test it.

## What Sigra gives you

- **`MyAppWeb.UserRegistrationLive`** — generated LiveView that renders the form and submits to `Accounts.register_user/2`. You own it; edit the template freely.
- **`MyApp.Accounts.register_user/2`** — the context function that calls `Sigra.Auth.register/3` with the generated changeset. This is where you add custom side effects (welcome email, analytics, billing signup).
- **`MyApp.Accounts.User.registration_changeset/2`** — the Ecto changeset. Validates email format, password length, password complexity, and email uniqueness. Hashes the password via `Sigra.Crypto.hash_password/1` on `prepare_changes`.
- **`MyApp.Accounts.deliver_user_confirmation_instructions/2`** — sends a signed, 24-hour TTL confirmation token to the user's email via the configured mailer.
- **`Sigra.Auth.register/3`** — the library-level primitive. Handles audit logging, telemetry spans, and the enumeration-safe `{:error, :email_taken}` return shape.

## Happy path

The generator produces this in `lib/my_app/accounts.ex`:

    def register_user(attrs, opts \\ []) do
      Sigra.Auth.register(Repo, attrs,
        changeset_fn: &User.registration_changeset(%User{}, &1),
        audit_schema: AuditEvent
      )
    end

And this in `lib/my_app_web/live/user_registration_live.ex`:

    def handle_event("save", %{"user" => user_params}, socket) do
      case Accounts.register_user(user_params) do
        {:ok, user} ->
          {:ok, _} =
            Accounts.deliver_user_confirmation_instructions(
              user,
              &url(~p"/users/confirm/#{&1}")
            )

          {:noreply,
           socket
           |> put_flash(:info, "Check your email to confirm your account.")
           |> push_navigate(to: ~p"/users/log-in")}

        {:error, %Ecto.Changeset{} = changeset} ->
          {:noreply, assign(socket, form: to_form(changeset))}
      end
    end

That's the whole flow. Hashing, validation, enumeration prevention, and audit logging are all handled for you.

## Enumeration-safe error handling

`Sigra.Auth.register/3` returns:

- `{:ok, user}` — success
- `{:error, %Ecto.Changeset{}}` — validation error (format, length, confirmation mismatch)
- `{:error, :email_taken}` — the email is already registered

**Important:** render the same message for `:email_taken` as for "email was sent" if an attacker can see the response. A common pattern is to show "If an account exists, we sent a confirmation email" on both branches. Or, accept the tradeoff and show "Email is already taken" — enumeration is mitigated by rate limiting.

## Requiring confirmation before login

By default, users can log in before confirming their email. To enforce confirmation, set `require_confirmation: true` in your Sigra config:

    # config/config.exs
    config :my_app, MyApp.Auth.Config,
      repo: MyApp.Repo,
      user_schema: MyApp.Accounts.User,
      require_confirmation: true

Now `UserAuth.log_in_user/3` rejects unconfirmed users with `{:error, :unconfirmed}` and the login form shows "Please confirm your email before logging in."

## Customizing the changeset

Add custom validations by extending `User.registration_changeset/2`:

    def registration_changeset(user, attrs) do
      user
      |> cast(attrs, [:email, :password, :display_name])
      |> validate_required([:display_name])
      |> validate_length(:display_name, min: 2, max: 50)
      |> Sigra.User.registration_changeset(attrs)  # email + password validation
    end

The `Sigra.User.registration_changeset/2` helper applies the standard email format, password complexity, and uniqueness validation. Your custom validations run before or after it — your choice.

## Adding welcome-email side effects

Hook into `register_user/2` in your `Accounts` context:

    def register_user(attrs, opts \\ []) do
      case Sigra.Auth.register(Repo, attrs, changeset_fn: &User.registration_changeset(%User{}, &1)) do
        {:ok, user} = result ->
          # Welcome email is separate from confirmation email
          Task.Supervisor.start_child(MyApp.TaskSupervisor, fn ->
            MyApp.Mailer.deliver_welcome_email(user)
          end)

          result

        error ->
          error
      end
    end

For guaranteed delivery, use Oban instead of `Task.Supervisor`:

    MyApp.Workers.SendWelcomeEmail.new(%{user_id: user.id}) |> Oban.insert()

## Testing

    test "registers a user with a hashed password" do
      attrs = %{"email" => "alice@example.com", "password" => "supersecret12"}

      assert {:ok, user} = Accounts.register_user(attrs)
      assert user.email == "alice@example.com"
      Sigra.Testing.assert_password_hashed(user)
    end

    test "sends a confirmation email" do
      {:ok, user} = Accounts.register_user(%{"email" => "bob@example.com", "password" => "supersecret12"})

      Accounts.deliver_user_confirmation_instructions(user, &"/confirm/#{&1}")

      Sigra.Testing.assert_email_sent(to: "bob@example.com", subject: "Confirm")
    end

See [Testing Auth Flows](testing.html) for fixtures, scenario setup, and the full `Sigra.Testing` helper list.

## Related

- [Getting Started](getting-started.html) — full walkthrough from install to working auth.
- [Login and Logout](login-and-logout.html) — what happens after registration.
- [Account Lifecycle](account-lifecycle.html) — email change, password change, deletion.
- `Sigra.Auth` — library-level primitives.
- `Sigra.Crypto` — password hashing and verification.
