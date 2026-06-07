# Custom User Fields

The `User` schema is generated into your app, so adding custom fields is a normal Ecto workflow: edit the schema, add a migration, extend the changeset, propagate to fixtures. Nothing in the library cares about the extra columns. This recipe shows the full loop.

## The generated schema

After `mix sigra.install`, you have `lib/my_app/accounts/user.ex`:

    defmodule MyApp.Accounts.User do
      use Ecto.Schema
      import Ecto.Changeset

      @schema_prefix "auth"
      schema "users" do
        field :email, :string
        field :password, :string, virtual: true, redact: true
        field :hashed_password, :string, redact: true
        field :confirmed_at, :utc_datetime
        field :failed_login_attempts, :integer, default: 0
        field :locked_at, :utc_datetime

        timestamps(type: :utc_datetime)
      end

      def registration_changeset(user, attrs) do
        user
        |> cast(attrs, [:email, :password])
        |> Sigra.User.registration_changeset(attrs)
      end

      # ... password_changeset, confirm_changeset, etc.
    end

You own this file. Add fields, validations, helpers — whatever your app needs.

## Step 1: Add fields to the schema

Suppose you want `display_name`, `timezone`, and `role`:

    @schema_prefix "auth"
    schema "users" do
      field :email, :string
      field :password, :string, virtual: true, redact: true
      field :hashed_password, :string, redact: true
      field :confirmed_at, :utc_datetime
      field :failed_login_attempts, :integer, default: 0
      field :locked_at, :utc_datetime

      # Custom fields
      field :display_name, :string
      field :timezone, :string, default: "UTC"
      field :role, Ecto.Enum, values: [:user, :admin], default: :user

      timestamps(type: :utc_datetime)
    end

## Step 2: Write a migration

    mix ecto.gen.migration add_user_profile_fields

Then in `priv/repo/migrations/*_add_user_profile_fields.exs`:

    defmodule MyApp.Repo.Migrations.AddUserProfileFields do
      use Ecto.Migration

      def change do
        alter table(:users, prefix: "auth") do
          add :display_name, :string
          add :timezone, :string, null: false, default: "UTC"
          add :role, :string, null: false, default: "user"
        end

        create index(:users, [:role], prefix: "auth")
      end
    end

Run `mix ecto.migrate`.

## Step 3: Extend the registration changeset

Add the new fields to the cast list and any validations you need:

    def registration_changeset(user, attrs) do
      user
      |> cast(attrs, [:email, :password, :display_name, :timezone])
      |> validate_required([:display_name])
      |> validate_length(:display_name, min: 2, max: 50)
      |> validate_inclusion(:timezone, Tzdata.zone_list())
      |> Sigra.User.registration_changeset(attrs)  # email + password validation + hashing
    end

`Sigra.User.registration_changeset/2` is the shared helper that enforces the email format, password complexity, and Argon2id hashing. Call it **after** your custom validations so it can see the full changeset.

## Step 4: Update the registration LiveView

Add form fields to `lib/my_app_web/live/user_registration_live.ex`:

    <.input field={@form[:display_name]} type="text" label="Display name" required />
    <.input field={@form[:timezone]} type="select" label="Timezone" options={Tzdata.zone_list()} />
    <.input field={@form[:email]} type="email" label="Email" required />
    <.input field={@form[:password]} type="password" label="Password" required />

The LiveView already calls `Accounts.register_user/1`, which calls `Sigra.Auth.register/3` — no code changes needed there.

## Step 5: Extend the fixture

In `test/support/auth_fixtures.ex`, the generated `user_fixture/1` is the composition root for every scenario. Add your defaults:

    def user_fixture(attrs \\ %{}) do
      attrs =
        Enum.into(attrs, %{
          email: unique_user_email(),
          password: valid_user_password(),
          display_name: "Test User",
          timezone: "UTC",
          role: :user
        })

      {:ok, user} = MyApp.Accounts.register_user(attrs)
      user
    end

Every scenario fixture (`authenticated_fixture`, `mfa_complete_fixture`, etc.) composes from `user_fixture/1`, so your custom fields propagate automatically.

## Step 6: Use the new fields

Anywhere you have a `%User{}`:

    <%= @current_scope.user.display_name %>
    <%= format_time(@event.occurred_at, @current_scope.user.timezone) %>

    <%= if @current_scope.user.role == :admin do %>
      <.link navigate={~p"/admin"}>Admin Dashboard</.link>
    <% end %>

## Role-based authorization

For simple role gating, add a plug:

    defp require_admin(conn, _opts) do
      if conn.assigns.current_scope.user.role == :admin do
        conn
      else
        conn
        |> put_flash(:error, "Admins only")
        |> redirect(to: ~p"/")
        |> halt()
      end
    end

    scope "/admin", MyAppWeb do
      pipe_through [:browser, :require_authenticated_user, :require_admin]

      live "/users", AdminUsersLive
    end

For more complex authorization (per-resource policies), consider [Bodyguard](https://hexdocs.pm/bodyguard) or [LetMe](https://hexdocs.pm/let_me). Sigra focuses on **authentication** and leaves authorization policy to the app.

## Upgrade safety

Because the `User` schema lives in your app, not the library, upgrading Sigra never touches your custom fields. A new library release might ship new functions in `Sigra.User` (the shared changeset helpers), but your schema — and your columns — are untouched.

If a future Sigra release adds a new built-in field (say, `locked_reason`), `mix sigra.install --force` will show a diff and let you merge it by hand. You're never surprised.

## Testing

    test "registration accepts custom fields" do
      attrs = %{
        "email" => "alice@example.com",
        "password" => "supersecret12",
        "display_name" => "Alice",
        "timezone" => "America/Los_Angeles"
      }

      assert {:ok, user} = Accounts.register_user(attrs)
      assert user.display_name == "Alice"
      assert user.timezone == "America/Los_Angeles"
      Sigra.Testing.assert_password_hashed(user)
    end

    test "registration rejects blank display_name" do
      attrs = %{"email" => "bob@example.com", "password" => "supersecret12", "display_name" => ""}
      assert {:error, changeset} = Accounts.register_user(attrs)
      assert "can't be blank" in errors_on(changeset).display_name
    end

## Related

- [User Registration flow](registration.html) — the default changeset behavior.
- [Multi-Tenant Apps](multi-tenant.html) — scoping users by tenant_id.
- [Testing Auth Flows](testing.html) — how fixtures compose.
