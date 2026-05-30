# Vaultr — Sigra Demo App

Vaultr is a showcase Phoenix app demonstrating [Sigra](https://hexdocs.pm/sigra) — a comprehensive authentication library for Phoenix 1.8+. It covers registration, email confirmation, password reset, TOTP MFA, OAuth/social login, and account lifecycle out of the box. You can run it locally in one command and explore every auth feature with pre-seeded personas.

## Try it locally

### Prerequisites

- Elixir 1.18+
- Erlang/OTP 27+
- PostgreSQL running (or Docker)

Start a disposable Postgres container:

```bash
docker run -d --name vaultr-postgres -e POSTGRES_PASSWORD=postgres -p 5432:5432 postgres:16-alpine
```

The container password is `postgres` — matching the app's dev config default.

### One-command setup

```bash
cd test/example
mix setup && mix phx.server
```

Then visit http://localhost:4000

## Demo Personas

All personas use the `@demo.sigra.dev` email domain. Passwords are public-by-design demo credentials — never use them in production.

| Email | Password | Feature demonstrated |
|-------|----------|---------------------|
| admin@demo.sigra.dev | DemoAdmin1!SecurePass | Admin — TOTP MFA, passkey display row, multi-org owner, rich audit trail |
| alice@demo.sigra.dev | AliceDemoPass1! | Standard confirmed user — happy path login, Acme Corp member |
| bob@demo.sigra.dev | BobDemoPass1!Beta | TOTP MFA enrolled — org owner (Beta Labs) |
| carol@demo.sigra.dev | CarolDemoPass1!Github | OAuth identity — GitHub-linked login (carol@demo.sigra.dev) |
| dave@demo.sigra.dev | DaveDemoPass1!Locked | Locked account — failed login attempts exhausted, unconfirmed |
| frank@demo.sigra.dev | FrankDemoPass1!Deleted | Scheduled deletion — account marked for deletion |

## Rough Edges

**Dave — locked and unconfirmed:** Dave's account is locked AND unconfirmed. Try logging in — with the correct password or a wrong one — to see Sigra's enumeration-resistant response. The error does not reveal whether the account exists, is locked, or is unconfirmed. Unlock via /admin/users as the admin persona.

**Frank — scheduled deletion:** Frank's `scheduled_deletion_at` is set — the account is still active and accessible. Inspect via /admin/users as the admin persona.

## Dev Tools

- http://localhost:4000/dev/mailbox — Swoosh local email inbox (confirmation emails, password reset links, magic links)
- http://localhost:4000/demo/credentials — In-app credentials cheat-sheet (all personas listed while the server is running)

## Learn More About Sigra

- [Getting Started](https://hexdocs.pm/sigra/getting-started.html) guide
- [Full documentation](https://hexdocs.pm/sigra) on Hexdocs
- [Demo Showcase guide](https://hexdocs.pm/sigra/demo-showcase.html) — walkthrough with screenshots
