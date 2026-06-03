# Vaultr — Sigra Demo App

Vaultr is the runnable local companion for Sigra's canonical evaluator walkthrough:
[Demo Showcase](https://hexdocs.pm/sigra/demo-showcase.html).

## Try it locally

### Prerequisites

- Elixir 1.18+
- Erlang/OTP 27+
- Docker Desktop, or PostgreSQL reachable through `PG*` environment variables

Recommended Docker path from the repo root:

```bash
scripts/uat/up.sh
```

The script starts a project-scoped Postgres container on an available local
port, creates and migrates the demo database, seeds the evaluator personas,
and prints the exact `PG*` and `PORT` values to use for the Phoenix server.

### Manual setup

```bash
cd test/example
PGHOST=127.0.0.1 PGPORT=<printed-postgres-port> PORT=<printed-app-port> mix phx.server
```

Then visit the printed `/demo/credentials` URL first.

## Demo Personas

All personas use the `@demo.sigra.dev` email domain. Passwords are public-by-design demo credentials — never use them in production.

| Email | Password | Feature demonstrated |
|-------|----------|---------------------|
| admin@demo.sigra.dev | DemoAdmin1!SecurePass | Admin/operator coverage — TOTP MFA, passkey display row, multi-org ownership, and audit inspection |
| alice@demo.sigra.dev | AliceDemoPass1! | Happy path confirmed user baseline |
| bob@demo.sigra.dev | BobDemoPass1!Beta | TOTP MFA enrolled plus org-owner coverage |
| carol@demo.sigra.dev | CarolDemoPass1!Github | Seeded GitHub OAuth-linked identity row for inspection |
| dave@demo.sigra.dev | DaveDemoPass1!Locked | Locked and unconfirmed rough edge |
| frank@demo.sigra.dev | FrankDemoPass1!Deleted | Scheduled deletion lifecycle (still active) |

## Rough Edges

**Dave — locked and unconfirmed:** Dave's account is locked AND unconfirmed. Try logging in — with the correct password or a wrong one — to see Sigra's enumeration-resistant response. The error does not reveal whether the account exists, is locked, or is unconfirmed. Unlock via /admin/users as the admin persona.

**Frank — scheduled deletion:** Frank's `scheduled_deletion_at` is set — the account is still active and accessible. Inspect via /admin/users as the admin persona.

**Carol — seeded OAuth identity vs live provider flow:** Carol has a seeded GitHub identity row for inspection in admin detail views, but live GitHub OAuth still requires evaluator-supplied provider credentials.

## Dev Tools

- `/dev/mailbox` on the printed app URL — Swoosh local email inbox (confirmation emails, password reset links, magic links)
- `/demo/credentials` on the printed app URL — In-app credentials cheat-sheet (all personas listed while the server is running)

## Learn More About Sigra

- [Demo Showcase guide](https://hexdocs.pm/sigra/demo-showcase.html) — canonical evaluator path with screenshot grid and proof boundaries
- [Getting Started](https://hexdocs.pm/sigra/getting-started.html) guide
- [Full documentation](https://hexdocs.pm/sigra) on Hexdocs
