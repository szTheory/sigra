# Demo Showcase — Vaultr Example App

Vaultr is Sigra's seeded showcase Phoenix application, bundled at `test/example/`, that demonstrates every major authentication feature using six pre-seeded personas. This guide walks through each feature area so you can evaluate Sigra's capabilities without writing any setup code yourself.

## Running the Demo

```bash
cd test/example
mix setup && mix phx.server
```

Then visit [http://localhost:4000](http://localhost:4000). See `test/example/README.md` for prerequisites (Elixir, PostgreSQL versions and Docker one-liner).

## Credentials Cheat-Sheet

![Credentials cheat-sheet showing all six demo persona emails and passwords](assets/demo-credentials-demo-showcase-chromium.png)

While the server is running, visit `/demo/credentials` for a live cheat-sheet listing all six persona emails and passwords. The page is only available in development mode — it is not generated in production builds.

## Admin: Platform-Admin View

![Admin user detail showing TOTP MFA enrollment and passkey display row](assets/admin-user-detail-demo-showcase-chromium.png)

![Admin user list showing all six demo personas](assets/admin-user-list-demo-showcase-chromium.png)

Log in as `admin@demo.sigra.dev` (password on the credentials page) to access the `/admin` area. The admin persona demonstrates the full platform-admin surface:

- **TOTP MFA** — TOTP is enrolled; the admin user detail page shows the MFA status row and enrollment date.
- **Passkey display row** — a passkey credential row is visible in the admin user detail, illustrating how WebAuthn credentials are stored and surfaced in the admin UI.
- **Multi-org membership** — admin is a member of multiple demo organizations, demonstrating Sigra's multi-tenancy seams.
- **Rich audit trail** — every login, MFA challenge, and admin action is recorded; review the audit log at `/admin/audit`.

**Alice** (`alice@demo.sigra.dev`) is a standard confirmed user — the happy-path baseline. She is a member of Acme Corp and logs in without MFA, which makes her the simplest reference for testing the plain email/password flow.

**Bob** (`bob@demo.sigra.dev`) is also TOTP-enrolled and acts as org owner of Beta Labs. He complements admin for testing that TOTP enforcement applies consistently across different roles.

## Audit Log

![Audit log explorer showing six or more distinct event types](assets/audit-explorer-demo-showcase-chromium.png)

The `/admin/audit` route in the admin area shows the seeded audit log. The demo seed data covers distinct event types — logins, MFA challenges, account lifecycle events, and admin actions — so the log reads as a live system rather than an empty scaffold. Use the filter controls to narrow by actor, resource, or action string.

## Rough Edges: Locked and Scheduled-Deletion Accounts

These two personas exercise Sigra's failure and lifecycle paths. No screenshot is needed — the interesting behavior is in the response, not the UI.

**Dave** (`dave@demo.sigra.dev`) has a locked and unconfirmed account. Try logging in with the wrong password to see Sigra's enumeration-resistant response — the error message does not reveal whether the account exists or why the login failed. To unlock Dave's account, log in as admin and visit `/admin/users`, find Dave's row, and use the unlock action.

**Frank** (`frank@demo.sigra.dev`) has `scheduled_deletion_at` set — his account is still active and can log in, but it is marked for deletion. Inspect the scheduled deletion date via `/admin/users` as admin. This demonstrates Sigra's graceful account deletion lifecycle: the deletion is scheduled rather than immediate, giving the user a window to cancel before the job runs.

## OAuth Identity

**Carol** (`carol@demo.sigra.dev`) has a seeded GitHub OAuth identity row, visible in her admin user detail page at `/admin/users`. The identity row shows the provider (`github`), the external UID, and the insertion timestamp — exactly what Sigra stores when a user completes the OAuth flow.

> **Important:** the live OAuth flow requires real GitHub OAuth application credentials configured in `config/dev.exs`. The demo does not include working GitHub credentials out of the box, so clicking "Sign in with GitHub" will fail unless you add your own. The seeded identity row is present for inspection regardless — you do not need to run the live flow to evaluate how Sigra stores OAuth identities.

## What's Next

- **[Installation](installation.html)** — add Sigra to your Phoenix app
- **[Getting started](getting-started.html)** — generate auth scaffolding and run your first authenticated request
- **[MFA guide](../flows/mfa.html)** — TOTP enrollment, backup codes, and enforcement policies
- **[Full Sigra documentation](https://hexdocs.pm/sigra)** — complete API reference on Hexdocs
