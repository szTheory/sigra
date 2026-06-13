# Vaultr — Sigra Demo App

Vaultr is the runnable local companion for Sigra's canonical evaluator walkthrough:
[Demo Showcase](https://hexdocs.pm/sigra/demo-showcase.html).

## Try it locally

### Prerequisites

- Elixir 1.19+
- Erlang/OTP 27+
- Docker Desktop, or PostgreSQL reachable through `PG*` environment variables

Recommended Docker path from the repo root:

```bash
scripts/uat/up.sh
```

The script starts a project-scoped Postgres container on an available local
port, creates and migrates the demo database, seeds the evaluator personas,
and prints the exact server command and URLs. It also writes the current
runtime values to `tmp/uat.env`, which is ignored by git.

In a second terminal, run the server command printed by `scripts/uat/up.sh`.
It includes the discovered `PG*`, `PORT`, and `SIGRA_EXAMPLE_URL` values:

```bash
cd test/example && PGHOST=127.0.0.1 PGPORT=<printed-postgres-port> PORT=<printed-app-port> SIGRA_EXAMPLE_URL=<printed-app-url> iex -S mix phx.server
```

Then visit the printed `/demo/credentials` URL first.

For a stable `.localhost` URL, use the shared local Traefik proxy:

```bash
scripts/dev-proxy/up.sh
scripts/uat/up.sh --proxy
```

That route starts Vaultr as a Docker `web` service on the external Docker
network named `proxy` and lets the shared `dev_proxy-traefik-1` route
`http://sigra.localhost`. Sigra does not start its own port-80 Traefik in this
path. The proxy helper is a generic local-dev convenience shipped by Sigra;
any compatible Traefik attached to `proxy` works. If you need an isolated fallback proxy, use
`scripts/uat/up.sh --private-traefik`, which binds
`http://sigra.localhost:18080` by default.
Proxy mode recompiles the local Sigra path dependency on startup and refuses to
start if another running UAT web container already claims the same
`SIGRA_UAT_PROXY_HOST`. If the Dockerized app is already running and you change
Sigra library code, refresh the compiled dependency with:

```bash
scripts/uat/up.sh --refresh-code
```

### Everyday commands

```bash
scripts/uat/status.sh       # reprint URLs, ports, and the server command
scripts/uat/up.sh --refresh-code
scripts/uat/up.sh --print-env
scripts/uat/down.sh         # stop containers, keep the database volume
scripts/uat/down.sh --purge # stop containers and delete this stack's database volume
```

`scripts/uat/up.sh` chooses a Compose project name from your user, branch, and
checkout path. That lets multiple Sigra checkouts, or sibling Elixir libraries
with their own demo UIs, run side by side. Postgres and Phoenix use available
localhost ports by default, so the stack does not reserve `5432` or `4000`.

When you need fixed ports for external callbacks or a debugger, opt in:

```bash
SIGRA_UAT_PG_PORT=5432 SIGRA_EXAMPLE_PORT=4000 scripts/uat/up.sh
```

If a fixed port is already occupied, Docker or Phoenix will fail loudly. Drop
the override and rerun `scripts/uat/up.sh` to return to conflict-free dynamic
ports.

### Manual setup without Docker

If you already have PostgreSQL running locally, you can skip the UAT helper:

```bash
cd test/example
mix setup && mix phx.server
```

## Demo Personas

All personas use the `@demo.vaultr.test` email domain. Passwords are public-by-design demo credentials — never use them in production.

| Email                  | Password               | Feature demonstrated                                                                               |
| ---------------------- | ---------------------- | -------------------------------------------------------------------------------------------------- |
| admin@demo.vaultr.test | DemoAdmin1!SecurePass  | Admin/operator coverage — TOTP MFA, passkey display row, multi-org ownership, and audit inspection |
| alice@demo.vaultr.test | AliceDemoPass1!        | Happy path confirmed user baseline                                                                 |
| bob@demo.vaultr.test   | BobDemoPass1!Beta      | TOTP MFA enrolled plus org-owner coverage                                                          |
| carol@demo.vaultr.test | CarolDemoPass1!Github  | Seeded GitHub OAuth-linked identity row for inspection                                             |
| dave@demo.vaultr.test  | DaveDemoPass1!Locked   | Locked and unconfirmed rough edge                                                                  |
| frank@demo.vaultr.test | FrankDemoPass1!Deleted | Scheduled deletion lifecycle (still active)                                                        |

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
