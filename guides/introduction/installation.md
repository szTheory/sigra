# Installation

Sigra installs into an existing Phoenix 1.8+ application in four commands. This guide covers the dependency, the generator, the migration, and a quick smoke test. When you're done, head to [Getting Started](getting-started.html) for the end-to-end walkthrough.

## Prerequisites

- Elixir ~> 1.18 and Erlang/OTP ~> 27
- A Phoenix 1.8+ application (`mix phx.new my_app`) with an Ecto repo
- PostgreSQL (primary supported adapter; MySQL and SQLite work with conditional migrations)

If you don't have a Phoenix app yet:

    mix archive.install hex phx_new
    mix phx.new my_app
    cd my_app
    mix ecto.create

## Add the dependency

Add `:sigra` to `deps/0` in `mix.exs`:

    defp deps do
      [
        {:phoenix, "~> 1.8"},
        {:ecto_sql, "~> 3.12"},
        # ...
        {:sigra, "~> 0.2"}
      ]
    end

Fetch it:

    mix deps.get

## Run the generator

    mix sigra.install

Sigra generates `uuid` (binary_id) primary keys by default — no flag required. If your app is already on bigint integer IDs and you want to stay on them, pass `--no-binary-id`:

    mix sigra.install Accounts User users --no-binary-id

This generates the **application-owned** scaffolding into your project:

- `lib/my_app/accounts.ex` — the `Accounts` context with `register_user/2`, `get_user_by_email_and_password/2`, `deliver_user_reset_password_instructions/2`, and friends.
- `lib/my_app/accounts/user.ex` — the `User` Ecto schema with password changesets and validation.
- `lib/my_app/accounts/user_token.ex` — session, confirmation, reset, and magic-link token schema.
- `lib/my_app_web/user_auth.ex` — the `UserAuth` plug module: `log_in_user/3`, `log_out_user/1`, `fetch_current_scope/2`, `require_authenticated_user/2`.
- `lib/my_app_web/live/user_registration_live.ex` and friends — the registration, login, password-reset, and settings LiveViews.
- `priv/repo/migrations/*_create_users_auth_tables.exs` — the users + tokens migrations.
- `test/support/auth_fixtures.ex` — scenario fixtures (`user_fixture`, `authenticated_fixture`, etc.).

**You own this code.** Security-critical primitives (hashing, TOTP verification, token HMACs) live in the library and update via `mix deps.update sigra`. Everything in your app — schemas, routes, templates, LiveViews — is yours to customize without fighting the library.

The generator also patches your router with the auth pipelines and scopes. Re-running `mix sigra.install` is safe: it detects existing files and skips them (pass `--force` to overwrite).

## Migrate

    mix ecto.migrate

This creates the `users` and `users_tokens` tables (plus any optional tables such as `audit_events` if you enabled **audit logging** in the installer).

## Smoke test

Start the server:

    mix phx.server

Visit <http://localhost:4000/users/register>. You should see the generated registration LiveView. Fill in an email and password — the user should be created and you should be logged in.

If that worked, you're ready. Continue with [Getting Started](getting-started.html) for the full walkthrough including login, logout, and password reset.

## Troubleshooting

- **`** (UndefinedFunctionError) Sigra.Config.new!/1`** — run `mix deps.get && mix deps.compile sigra` to pick up the library.
- **`** (Ecto.MigrationError) relation "users" already exists`** — you already have a `users` table from a prior library. Either drop it or rename the Sigra table via the generated migration.
- **`mix sigra.install` skips files you want to regenerate** — pass `--force` and re-run. Be warned: this overwrites any local edits.
- **Compilation warnings about `:cookie_domain`** — see [Subdomain Authentication](subdomain-auth.html) if you want subdomain-scoped cookies, or set `cookie_domain: nil` explicitly to silence the prod boot warning.

## Migrating from bigint to uuid

Sigra defaults to `uuid` (binary_id) primary keys. If you installed Sigra before this default flipped and your `users` table uses bigint integer IDs, you have two options:

1. **Stay on bigint (recommended for existing installs):** re-run the generator with `--no-binary-id` when regenerating any file, and leave your existing migrations untouched. The `binary_id is the default` flip only affects *fresh* generator runs — your already-installed migrations on disk are frozen.
2. **Migrate to uuid manually:** write a one-off migration that adds a new `uuid` column, backfills it, swaps the primary key, and re-points FKs. Sigra does not ship an automated primary-key converter; a `--primary-key` flag may be added in a future release.

## What's next

- [Getting Started](getting-started.html) — register, log in, log out, reset password in under 30 minutes.
- [User Registration flow](registration.html) — customizing the registration form and confirmation flow.
- [Login and Logout flow](login-and-logout.html) — remember-me, session renewal, logout hooks.
