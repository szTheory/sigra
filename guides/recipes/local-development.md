> **Reading map:** [Demo showcase](../introduction/demo-showcase.html) · [Testing auth flows](testing.html) · [Deployment](deployment.html) · [Troubleshooting install](../introduction/troubleshooting-install.html)

# Local Development with Docker

This recipe is for working **on** Sigra (or evaluating it deeply) on your own machine: running the test suite, booting the seeded demo app, and reaching it at a stable URL — all backed by Docker so it never fights your system Postgres or another project's ports. If you are running many Elixir apps at once (each with its own admin UI), this is the workflow that keeps them out of each other's way. **Budget: under 15 minutes.**

If you just want to *install Sigra into your own app*, you want [Installation](../introduction/installation.html) instead — this page is about the Sigra repo's own dev/demo environment.

## Gameplan (TL;DR)

1. **Tests:** `scripts/db/up.sh` → `direnv allow` (once) → `mix test`. A throwaway Postgres on a random port; nothing to configure.
2. **Demo app:** `scripts/uat/up.sh` (host-run, live reload) — or `scripts/uat/up.sh --proxy` for a stable `http://…localhost` URL through the shared proxy.
3. **Read the printout.** Both scripts print the exact URLs, routes, and commands to copy-paste.
4. **Iterate.** Host-run reloads on save. The Docker demo path rebuilds from a layer cache — style edits never re-download deps.
5. **Tear down:** `scripts/db/down.sh` and `scripts/uat/down.sh`.

## What this gives you / what it doesn't

- ✅ Postgres in Docker on a **dynamic** port — never reserves `5432`, never collides with Homebrew Postgres or a sibling project.
- ✅ A stable, collision-free URL per checkout/branch, with `http://sigra.localhost` as a friendly alias for your primary checkout.
- ✅ A Docker image whose layers cache correctly — editing a template doesn't re-fetch or recompile dependencies.
- ❌ Not a production setup. For the prod release image and deploy config see [Deployment](deployment.html).

## Prerequisites

- **Docker Desktop** running.
- **Elixir 1.19+** / OTP 27+ (host-run mode and `mix test` run on the host).
- A modern browser. Chrome/Edge resolve `*.localhost` automatically; for Firefox/Safari/`curl` use the printed raw `127.0.0.1:<port>` URL.
- Optional but recommended: **[direnv](https://direnv.net)** for zero-step test-DB discovery (a `source` fallback is always printed).
- For the install golden tests only: the pinned `phx_new` archive — `mix archive.install --force hex phx_new 1.8.7`.

## Postgres for `mix test`

`mix test` needs a Postgres with `postgres`/`postgres` and a `sigra_test` database. Boot a disposable one in Docker:

```bash
scripts/db/up.sh          # ephemeral Postgres on a dynamic port; writes tmp/db.env
direnv allow              # one-time; auto-loads tmp/db.env on every cd into the repo
mix test
```

No direnv? Use the printed fallback instead:

```bash
source tmp/db.env && mix test
```

How it works: the container publishes Postgres on a **random** host port (so it can't clash with anything), `scripts/db/up.sh` discovers that port and writes it to `tmp/db.env` in both naming conventions — `SIGRA_TEST_PG_*` (read by the library suite) and `PG*` (read by the demo app and the install fixtures). When `tmp/db.env` isn't loaded (CI, or a plain Postgres on `5432`), everything falls back to `localhost:5432`, so nothing breaks. The container is ephemeral (no data volume) and raised to `max_connections=200` for the install suite's many generated apps. Tear it down with `scripts/db/down.sh`.

> This test database is separate from the demo database below. Keep them apart: the demo DB persists seeded personas; the test DB is disposable.

## Running the demo app

```bash
scripts/uat/up.sh
```

This starts a project-scoped Postgres, creates/migrates/seeds the `example_dev` database, and prints the Phoenix server command plus every key URL. Phoenix runs **on the host** here, so saving a file live-reloads — this is the day-to-day development path. Run the printed `iex -S mix phx.server` command, then open the printed `/demo/credentials` URL.

## Stable URLs: the shared-proxy workflow

When you want a real hostname instead of `127.0.0.1:<random-port>` — and you're running several apps at once — use the shared proxy:

```bash
scripts/uat/up.sh --proxy
```

This builds the demo app as a container, attaches it to the shared `proxy` Docker network, and prints a URL like `http://sigra-main-1a2b3c.localhost`. One global Traefik (`scripts/dev-proxy/up.sh`, brought up automatically if absent) owns `127.0.0.1:80` and routes every project's `.localhost` hostname — so Sigra, and sibling libraries, coexist without anyone reserving port 80 or 4000.

A few things worth knowing:

- **Each checkout/branch gets a unique host** (`sigra-<branch>-<hash>.localhost`), derived so two branches or worktrees never collide. (Two Traefik routers with the *same* host would silently round-robin between them — the unique-by-construction host avoids that entirely.)
- **Your primary checkout also answers on `http://sigra.localhost`** — a friendly alias attached only when you're on the default branch and no other stack already holds it. A second branch doesn't fail; it just keeps its own unique host.
- **Per-host cookie jars.** A session on `sigra.localhost` is *not* shared with `sigra-feature-x.localhost`. That's a feature for auth testing, not a bug.
- **Firefox / Safari / `curl`** don't resolve `*.localhost`. Use the printed **RAW FALLBACK** `http://127.0.0.1:<port>` for those.
- A project-private fallback proxy (no shared :80) is available via `scripts/uat/up.sh --private-traefik`.

## How the Docker build caches your changes

The `--proxy` image (`scripts/uat/Dockerfile.example`) is layered so a change only rebuilds what it must — you will never re-download or recompile dependencies for a template tweak:

| You changed… | What rebuilds |
|---|---|
| An example template / `.heex` / controller | Only the final example-compile layer (fast incremental). Deps + sigra stay **cached**. |
| Sigra library source (`lib/`, `priv/`) | The dependency layer recompiles (sigra + its deps); the example recompiles. |
| `mix.exs` / `mix.lock` | Dependencies re-resolve and recompile. |

After editing Sigra source while a `--proxy` stack is running, apply it with:

```bash
scripts/uat/up.sh --refresh-code
```

That does a cache-aware `docker compose build` + restart — not a from-scratch rebuild.

## Iterating on code

- **Day-to-day:** use host-run (`scripts/uat/up.sh` with no flag). Save a file → Phoenix live-reloads. No Docker rebuild in the loop.
- **Demo / parity / sharing a URL:** use `--proxy`, and `--refresh-code` to pick up source changes.

## Teardown

```bash
scripts/db/down.sh        # stop the test Postgres (--purge to also drop volumes)
scripts/uat/down.sh       # stop the demo stack (--purge to drop the seeded demo DB)
```

## Troubleshooting

- **`FATAL: sorry, too many clients already`** — a shared/system Postgres is saturated. The Dockerized test DB (`scripts/db/up.sh`) is isolated and raised to 200 connections; make sure `tmp/db.env` is loaded so tests use it, not a system `5432`.
- **`mix test` connects to the wrong DB** — confirm `tmp/db.env` is loaded (`direnv allow`, or `source tmp/db.env`). Unloaded, it defaults to `localhost:5432` by design.
- **`http://sigra.localhost` doesn't resolve** — you're likely in Firefox/Safari/`curl`; use the printed RAW FALLBACK `127.0.0.1:<port>`.
- **Port 80 already owned** — a sibling project's proxy already holds it; that's fine, Sigra routes through it. To run your own, set `SIGRA_DEV_PROXY_HTTP_PORT`.
- **Browser looks stale after a Sigra source change (`--proxy`)** — run `scripts/uat/up.sh --refresh-code`.
- **`different value ... for ExampleWeb.Endpoint`** — the image was built with different bind/port than runtime; rebuild with `--refresh-code`.

## Where to go next

[Demo showcase](../introduction/demo-showcase.html) for the guided evaluator walkthrough · [Testing auth flows](testing.html) for writing tests · [Deployment](deployment.html) for the production release image.
