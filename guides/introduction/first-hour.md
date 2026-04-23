# First hour with Sigra

**Goal:** Land a **green** local loop: deps → install → migrate → server → register → confirm → log in — in about **one hour** including reading.

## Reading map (shortest path)

1. [Installation](installation.html) — add the dependency and run the installer.
2. [Getting started](getting-started.html) — happy-path walkthrough this guide assumes you will run.
3. [Production checklist (deployment recipe)](../recipes/deployment.html#production-checklist-read-first) — HTTPS, sessions, and proxy checks before a public host.
4. If something breaks: [Troubleshooting install](troubleshooting-install.html).
5. Upgrading an existing Sigra host: [Upgrading toward v1.7](upgrading-to-v1.7.html) (Nyquist / OAuth audit / CI context) · [Upgrading toward v1.8](upgrading-to-v1.8.html) (post–v1.7 doc polish + Hex bump checklist).

## Checklist

- [ ] PostgreSQL reachable (`localhost:5432` or your URL); credentials match `config/dev.exs`.
- [ ] `{:sigra, "~> 0.2"}` (or current published range) in `mix.exs`; `mix deps.get`.
- [ ] `mix sigra.install` (use `--yes` in CI or scripts); then `mix ecto.migrate`.
- [ ] `mix test` in the **host** app passes (or at least compiles) before layering optional features.
- [ ] `mix phx.server` — open `/users/register`, complete getting-started flow.

## Optional features (later same day)

Only after the checklist is green:

- OAuth login: [OAuth flow](../flows/oauth.html) and `mix sigra.gen.oauth`.
- MFA: [MFA flow](../flows/mfa.html).

## Maintainer / CI truth

If you are **contributing to Sigra** itself, local `mix test` expects Postgres — see repository **`CLAUDE.md`** / **`CONTRIBUTING.md`** for the exact env vars and Docker one-liner.
