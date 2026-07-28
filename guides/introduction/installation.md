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
        {:sigra, "~> 1.4.0"}
      ]
    end

The selected 1.0 package line is governed by the [Sigra 1.0 contract](contract.html). If you are reading `main` before Hex shows `1.0.0`, use the latest published Sigra package or a source checkout until the release PR lands.

Fetch it:

    mix deps.get

## Run the generator

    mix sigra.install

For the **complete** switch matrix (defaults, “see also” links, and prose clusters), read **[Generator and install options](../reference/generator-options.html)**—it stays aligned with `Mix.Tasks.Sigra.Install` and defers to `mix help sigra.install` when in doubt.

### mix sigra.install flags (reference)

| Flag | Effect |
|------|--------|
| `--live` / `--no-live` | Generate LiveView pages (default: `--live`). |
| `--binary-id` / `--no-binary-id` | UUID vs bigint primary keys (default: binary IDs on). |
| `--table` | Override the generated table name. |
| `--auth-prefix` | Postgres schema for Sigra-owned tables (default: `auth`; use `public` for old placement). |
| `--api` | Generate API token controller (implied by `--jwt`). |
| `--jwt` | Generate JWT token controller. |
| `--admin` / `--no-admin` | Admin scaffolding (default: on). |
| `--passkeys` / `--no-passkeys` | Passkey scaffolding (default: on). |
| `--organizations` / `--no-organizations` | Organizations scaffolding (default: on). |
| `--yes` | Non-interactive mode (CI / scripts). |

**Subset:** the rows above are a quick cheat sheet only—the canonical table with “See also” links lives at **[Generator and install options](../reference/generator-options.html)**.

Before production, work through the **[Production checklist (read first)](../recipes/deployment.html#production-checklist-read-first)** on the same deployment recipe. Mail and background delivery tradeoffs are in **[Mail delivery: inline vs Oban (TL;DR)](../recipes/deployment.html#mail-delivery-inline-vs-oban-tl-dr)**. For a CI-backed host that mirrors recommended wiring, browse **`test/example/`** in the Sigra repo.

Sigra generates `uuid` (binary_id) primary keys by default — no flag required. If your app is already on bigint integer IDs and you want to stay on them, pass `--no-binary-id`:

    mix sigra.install Accounts User users --no-binary-id

On Postgres, Sigra also puts its generated auth-owned tables in an `auth` schema by default. This is deliberate namespace hygiene: your application tables can stay in `public`, while Sigra's users, tokens, sessions, MFA, passkeys, OAuth identities, organizations, enterprise SSO, API tokens, and audit events share an explicit auth boundary. The generated migration creates the schema and uses Ecto prefixes; it does not depend on `search_path`.

If you want the old public-schema placement for a new Postgres install, choose it explicitly:

    mix sigra.install Accounts User users --auth-prefix public

MySQL and SQLite keep their current default-schema behavior.

This generates the **application-owned** scaffolding into your project:

- `lib/my_app/accounts.ex` — the `Accounts` context with `register_user/2`, `get_user_by_email_and_password/2`, `deliver_user_reset_password_instructions/2`, and friends.
- `lib/my_app/accounts/user.ex` — the `User` Ecto schema with password changesets and validation.
- `lib/my_app/accounts/user_token.ex` — session, confirmation, reset, and magic-link token schema.
- `lib/my_app_web/user_auth.ex` — the `UserAuth` plug module: `log_in_user/3`, `log_out_user/1`, `fetch_current_scope/2`, `require_authenticated_user/2`.
- `lib/my_app_web/live/user_registration_live.ex` and friends — the registration, login, password-reset, and settings LiveViews.
- `lib/my_app_web/components/sigra_auth_components.ex` and `priv/static/assets/sigra_auth.css` — the generated auth shell and scoped Light/Dark/System styling.
- `lib/my_app/sigra_admin_access.ex`, `lib/my_app/accounts/platform_admin_grant.ex`, and `mix sigra.admin.*` tasks — the explicit, persisted first-admin seam when admin scaffolding is enabled.
- `priv/repo/migrations/*_create_users_auth_tables.exs` — the users + tokens migrations, under `auth` by default on Postgres.
- `priv/repo/migrations/*_create_sigra_brand_profiles.exs` — optional global auth/email brand tokens managed from the generated admin UI.
- `test/support/auth_fixtures.ex` — scenario fixtures (`user_fixture`, `authenticated_fixture`, etc.).

**You own this code.** Security-critical primitives (hashing, TOTP verification, token HMACs) live in the library and update via `mix deps.update sigra`. Everything in your app — schemas, routes, templates, LiveViews — is yours to customize without fighting the library.

Auth forms and transactional emails also get brandable defaults. Use `branding:` in `sigra_config/0`, the generated `/admin/auth-branding` page, or edit the generated host templates directly. See [Auth Branding](../recipes/auth-branding.html) for the lanes and tradeoffs.

The generator also patches your router with the auth pipelines and scopes. Re-running `mix sigra.install` is safe: it detects existing files and skips them (pass `--force` to overwrite).

## Migrate

    mix ecto.migrate

On Postgres this creates the `auth` schema and Sigra-owned tables such as `auth.users`, `auth.user_tokens`, and `auth.user_sessions` (plus optional tables such as `auth.audit_events`). On MySQL and SQLite, tables are created in the adapter's default placement.

## Grant the first admin

Admin-enabled installs start closed: registering first, using a particular email domain, or being the first database row never grants admin access. Register and confirm the operator account, then grant it explicitly:

    mix sigra.admin.grant --email operator@example.com

The task asks for confirmation, writes the host-owned grant and its audit event in one transaction, and is safe to repeat. For deployment automation, add `--yes`. Useful companion commands are:

    mix sigra.admin.check --email operator@example.com
    mix sigra.admin.list
    mix sigra.admin.revoke --email operator@example.com

Run these tasks in the same release environment and database as the Phoenix app. They never accept or set a password. `--no-admin` installs emit none of these grant artifacts.

## Smoke test

Start the server:

    mix phx.server

Visit <http://localhost:4000/users/register>. You should see the generated registration LiveView. Fill in an email and password — the user should be created and you should be logged in.

If that worked, you're ready. Continue with [Getting Started](getting-started.html) for the full walkthrough including login, logout, and password reset.

## Troubleshooting

- **`** (UndefinedFunctionError) Sigra.Config.new!/1`** — run `mix deps.get && mix deps.compile sigra` to pick up the library.
- **`** (Ecto.MigrationError) relation "users" already exists`** — you already have a `users` table in the target schema from a prior library. Either drop it, choose `--auth-prefix public` only when that is intentional, or rename the Sigra table via the generated migration.
- **`mix sigra.install` skips files you want to regenerate** — pass `--force` and re-run. Be warned: this overwrites any local edits.
- **`mix sigra.admin.grant` says the account is unconfirmed** — finish the normal confirmation flow first; the task deliberately refuses unconfirmed or soft-deleted accounts.
- **Compilation warnings about `:cookie_domain`** — see [Subdomain Authentication](subdomain-auth.html) if you want subdomain-scoped cookies, or set `cookie_domain: nil` explicitly to silence the prod boot warning.

## Migrating from bigint to uuid

Sigra defaults to `uuid` (binary_id) primary keys. If you installed Sigra before this default flipped and your `users` table uses bigint integer IDs, you have two options:

1. **Stay on bigint (recommended for existing installs):** re-run the generator with `--no-binary-id` when regenerating any file, and leave your existing migrations untouched. The `binary_id is the default` flip only affects *fresh* generator runs — your already-installed migrations on disk are frozen.
2. **Migrate to uuid manually:** write a one-off migration that adds a new `uuid` column, backfills it, swaps the primary key, and re-points FKs. Sigra does not ship an automated primary-key converter; a `--primary-key` flag may be added in a future release.

## What's next

- [Getting Started](getting-started.html) — register, log in, log out, reset password in under 30 minutes.
- [User Registration flow](registration.html) — customizing the registration form and confirmation flow.
- [Login and Logout flow](login-and-logout.html) — remember-me, session renewal, logout hooks.
