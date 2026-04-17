# Sigra

[![Hex version](https://img.shields.io/hexpm/v/sigra.svg)](https://hex.pm/packages/sigra)
[![Docs](https://img.shields.io/badge/hexdocs-api%20%26%20guides-5865F2)](https://hexdocs.pm/sigra)

**Production-minded authentication for Phoenix 1.8+** — sessions, passwords, email flows, OAuth, MFA, passkeys, optional organizations and admin tooling — without betting your security story on copy-pasted app code that never gets patched.

Pow does not support Phoenix 1.8+. Sigra does, deliberately: **critical crypto and auth logic stay in the library** (you `mix deps.update`), while **schemas, routes, and LiveViews live in your repo** so you own the seam to your product.

---

## Start here (90 seconds)

1. **Add the dependency** in `mix.exs`:

   ```elixir
   {:sigra, "~> 0.1.0"}
   ```

2. **Fetch and install** into a Phoenix app that already has Ecto + Postgres wired the usual way:

   ```bash
   mix deps.get
   mix sigra.install Accounts User users
   ```

   Adjust module names to match your app (`Accounts` / `User` / `users` table are the common defaults from the docs).

3. **Migrate and run**:

   ```bash
   mix ecto.migrate
   mix phx.server
   ```

You now have register / log in / confirmation / reset-password style flows (exact surface depends on the flags you passed to `mix sigra.install`). **Full API and options** live on [HexDocs](https://hexdocs.pm/sigra).

---

## Why Sigra feels different

| You get | Why it matters |
|--------|----------------|
| **Library-owned security** | Token signing, MFA verification, OAuth callback handling, rate-limit hooks — the boring places bugs become CVEs. |
| **Generator-owned UI seams** | LiveViews and controllers are *your* files: customize copy, layout, and policy without forking a black-box dep. |
| **Phoenix 1.8 as the baseline** | Built for `live_session`, modern endpoints, and the post-Pow ecosystem — not a layer fighting the framework. |

---

## What ships in the box

Rough mental map (see HexDocs for the full matrix and flags):

- **Identity** — Argon2id passwords, optional bcrypt transparent upgrade on login, remember-me, sudo / step-up.
- **Email** — Registration, confirmation (link + code), magic link, password reset, lifecycle mailers (Swoosh-shaped).
- **Sessions** — Database-backed sessions with scope-friendly metadata (IPs, devices, optional geo hooks).
- **MFA** — TOTP (NimbleTOTP), backup codes, trust-this-device patterns the example app demonstrates.
- **OAuth** — Assent-backed strategies; `mix sigra.gen.oauth` for a focused OAuth slice when you do not want a full re-install.
- **Passkeys & orgs** — Optional installer flags for WebAuthn (`wax_`) and multi-tenant-style organizations when you need them.
- **Admin (optional)** — Installer-gated LiveView admin, impersonation guardrails, audit exploration — off the happy path until you opt in.

If you only remember one thing: **Sigra is the security core + generators; your `lib/my_app_web/` is the product chrome.**

---

## Read next

- **[Installation & first-time setup](guides/introduction/installation.md)** — deps, env, mailer, and the “does it compile?” checklist.
- **[Getting started walkthrough](guides/introduction/getting-started.md)** — register → confirm → log in → protect a route in small, ordered steps.
- **[HexDocs](https://hexdocs.pm/sigra)** — module reference, behaviours, installer options, upgrade notes.

---

## For contributors & maintainers

- **Elixir / OTP** versions live in [`.tool-versions`](.tool-versions); match them in CI and locally.
- **Tests** expect Postgres; `CLAUDE.md` has a copy-paste Docker one-liner. The **`test/example`** tree is the canonical “generated host” we compile and drive in Playwright / installer drift tests.
- **Hacking workflow** — see [`CONTRIBUTING.md`](CONTRIBUTING.md) for CI lanes, Playwright artifacts, and review expectations.

---

## License

MIT — see [`LICENSE`](LICENSE).
