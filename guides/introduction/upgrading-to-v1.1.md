# Upgrading to v1.1

Sigra v1.1 adds the shipped organizations and passkeys surface to an existing v1.0-style install. This guide is operational by design: use it in a branch, keep a backup, run the exact commands, and verify the result with the same upgrade test path the repo exercises.

## Before you start

1. Create a branch for the upgrade.
2. Make sure you can restore production data from backup.
3. Run the upgrade on a clean tree in your app repo. The real task refuses dirty trees unless you pass `--allow-dirty`.
4. Make sure your app already compiles and migrates cleanly on the current Sigra version.

## 1. Update the dependency

In your app's `mix.exs`, bump Sigra to the v1.1 release you are targeting, then fetch deps:

    mix deps.get

## 2. Choose your organizations backfill mode

You have two valid upgrade paths:

- **No backfill:** existing users keep the zero-org posture until they create or accept an organization.
- **Backfill personal orgs:** existing users each get a personal organization.

The repo exercises both paths. Choose one intentionally.

## 3. Run the schema upgrade

For the zero-org path:

    mix sigra.upgrade --yes

For the personal-org backfill path:

    mix sigra.upgrade --backfill-personal-orgs --yes

The test fixture appends `--allow-dirty` because `mix phx.new` leaves a fresh tmp app uncommitted. In a real application, prefer a clean working tree instead of relying on that escape hatch.

## 4. Run migrations and compile

After the upgrade task writes migrations and generated code updates:

    mix ecto.migrate
    mix compile --warnings-as-errors

If you used `--backfill-personal-orgs`, run any generated data migrations your app expects as part of deployment. The repo's upgrade harness explicitly runs the data-migration path after `mix ecto.migrate`.

## 5. Configure the new passkey surface

v1.1 adds generated passkey routes and runtime config. The default injected config looks like:

    config :my_app, :sigra_config,
      passkeys: [
        rp_id: "localhost",
        rp_name: "My App",
        origin: "http://localhost:4000",
        timeout_ms: 60_000,
        attestation: :none,
        user_verification: :preferred,
        ceremony_rate_limit: [limit: 5, window_ms: 60_000],
        passkey_primary_enabled: true
      ]

Set `rp_id` and `origin` to your real hostnames before rolling this out beyond localhost.

## 6. Know what changes in the generated app

After a successful upgrade, expect:

- organizations-aware generated surface in the default install posture
- passkey routes under `/users/log_in/passkey`, `/users/mfa/passkey`, and `/users/settings/mfa/passkeys`
- login pages that can present passkey-primary alongside password and magic-link fallback

The guide deliberately does not promise more than the repo proves. In particular, use the two upgrade modes above rather than assuming every existing user will get a personal org automatically.

## 7. Verify with the same tested path

Run the focused upgrade regression:

    mix test test/upgrade_test.exs

That test exercises the same two command paths this guide documents:

- `mix sigra.upgrade --yes`
- `mix sigra.upgrade --backfill-personal-orgs --yes`

It also checks the post-upgrade app still compiles, migrates, and stays bootable on the org-enabled and zero-org paths.

## 8. Smoke-check the upgraded app

Start the app and validate the generated surface manually:

    mix phx.server

Then confirm:

1. existing users can still log in
2. zero-org users land on `/organizations` instead of a 500
3. passkey controls render on `/users/log_in`
4. MFA settings include the passkey enrollment surface

## Related

- [Getting Started](getting-started.html) — the default install happy path, including organizations and passkeys.
- [Passkeys](passkeys.html) — runtime configuration, RP ID/origin operations, and recovery posture.
- [Multi-Tenant Apps](multi-tenant.html) — how Sigra's shipped logical-org model scopes tenant-owned data.
