> **Reading map:** [Demo showcase](../introduction/demo-showcase.html) · [Testing auth flows](testing.html) · [Deployment](deployment.html) · [Troubleshooting install](../introduction/troubleshooting-install.html)

# Local Development with Docker

This recipe is for working **on** Sigra (or evaluating it deeply) on your own machine: running the test suite, booting the seeded demo app, and reaching it at a stable URL — all backed by Docker so it never fights your system Postgres or another project's ports. If you are running many Elixir apps at once (each with its own admin UI), this is the workflow that keeps them out of each other's way. **Budget: under 15 minutes.**

If you just want to *install Sigra into your own app*, you want [Installation](../introduction/installation.html) instead — this page is about the Sigra repo's own dev/demo environment.

## Gameplan (TL;DR)

1. **Tests:** `scripts/db/up.sh` → `direnv allow` (once) → `mix test`. A throwaway Postgres on a random port; nothing to configure.
2. **Demo app:** `scripts/uat/up.sh` — **one command.** It builds + boots the demo behind the shared Traefik proxy with live reload, waits until the app actually responds, auto-opens `/demo/credentials`, and prints grouped auth/admin/ops routes. No second terminal.
3. **Read the printout.** Both scripts print the exact URLs, routes, and commands to copy-paste.
4. **Iterate.** Save a template or `lib/` source and it hot-reloads in the running container (bind-mount + inotify) — no image rebuild, and style edits never re-download deps. Prefer the raw host-run path? Use `--dev`.
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

One command does everything:

```bash
scripts/uat/up.sh
```

That single command:

1. starts a project-scoped Postgres and creates/migrates/seeds the `example_dev` database,
2. builds + boots the demo **as a container behind the shared Traefik proxy** (bringing the proxy up automatically if it isn't running), with the repo **bind-mounted for live reload**,
3. **waits until the app actually responds** (a readiness probe — the URL is never printed as live while it's still `STARTING`),
4. **auto-opens** `http://…localhost/demo/credentials`, and
5. prints grouped **auth / admin / ops** routes to copy-paste (sign in as `admin@demo.vaultr.test` for the admin routes).

Save a `test/example` template or a `lib/` source file and it hot-reloads in the running container — no image rebuild. There's **no second terminal**: the server is already up by the time the script returns.

### Flags

| Flag | What it does |
|---|---|
| (none) / `--proxy` | The default: Dockerized demo behind shared Traefik, live reload, health-gated, auto-open. `--proxy` is just an explicit alias of the default. |
| `--dev` / `--host` | Host-run Phoenix instead of the container — fastest live reload, no Docker app build. Starts + health-gates the server for you, in the background. |
| `--attach` / `--iex` | Host-run in the **foreground**, bound to an IEx shell (Ctrl-C twice to stop). Implies the host-run path. |
| `--no-watch` | Proxy mode without the bind-mount live-reload override (apply source changes with `--refresh-code`). |
| `--no-open` | Don't auto-open the browser when the app is ready. |
| `--reset` | Drop and recreate the demo database first. |
| `--no-seed` | Skip seeding the demo personas. |
| `--private-traefik` | Host-run fallback behind a project-private Traefik on `:18080` (no shared `:80`). |

### Running several Sigra-family libs at once

The shared proxy is what keeps multiple Elixir apps (each with its own admin UI) out of each other's way:

- **One global Traefik** (`scripts/dev-proxy/up.sh`, auto-started) owns `127.0.0.1:80` and routes every project's `.localhost` hostname over the shared `proxy` Docker network — so Sigra and sibling libraries coexist without anyone reserving port 80 or 4000.
- **Each checkout/branch gets a unique host** (`sigra-<branch>-<hash>.localhost`), derived so two branches or worktrees never collide. (Two Traefik routers with the *same* host would silently round-robin between them — the unique-by-construction host avoids that.)
- **`http://sigra.localhost` is claim-based.** The first stack to claim it — on **any** branch, not just the default — gets the friendly alias; everyone else keeps their unique per-checkout host. So you still get the clean URL on a feature branch.
- **Per-host cookie jars.** A session on `sigra.localhost` is *not* shared with `sigra-feature-x.localhost`. That's a feature for auth testing, not a bug.
- **Firefox / Safari / `curl`** don't resolve `*.localhost`. Use the printed **RAW FALLBACK** `http://127.0.0.1:<port>` for those.

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

- **Day-to-day (default):** `scripts/uat/up.sh`. Save a `test/example` template or `lib/` source → it hot-reloads in the container (bind-mount + inotify). No image rebuild in the loop, and no second terminal.
- **Fastest reload:** `scripts/uat/up.sh --dev` runs Phoenix on the host directly — no container layer at all. Tail `tmp/uat-phoenix.log` for output, or `--attach` to drop into IEx.
- **No bind-mount:** `--no-watch` runs the container without the live-reload mount; pick up source changes with `scripts/uat/up.sh --refresh-code` (cache-aware rebuild + restart).

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
- **Demo URL says `STARTING — not yet responding`** — the readiness probe hasn't seen a 200 yet. Give it a few seconds; if it persists, check the logs. Host-run (`--dev`) logs are in `tmp/uat-phoenix.log`; container logs are `docker compose … logs -f web` (the exact command is printed under COMMANDS).
- **Hot reload feels slow on macOS** — Docker bind-mount file-watching has noticeable latency on macOS. For the tightest save→reload loop, use `scripts/uat/up.sh --dev` (host-run, no bind mount).
- **Browser looks stale after a source change with `--no-watch`** — you opted out of the live-reload mount; run `scripts/uat/up.sh --refresh-code`.
- **`different value ... for ExampleWeb.Endpoint`** — the image was built with different bind/port than runtime; rebuild with `--refresh-code`.

## Where to go next

[Demo showcase](../introduction/demo-showcase.html) for the guided evaluator walkthrough · [Testing auth flows](testing.html) for writing tests · [Deployment](deployment.html) for the production release image.
