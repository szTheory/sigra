# Sigra

[![Hex version](https://img.shields.io/hexpm/v/sigra.svg)](https://hex.pm/packages/sigra)
[![Docs](https://img.shields.io/badge/hexdocs-api%20%26%20guides-5865F2)](https://hexdocs.pm/sigra)
[![CI](https://github.com/szTheory/sigra/actions/workflows/ci.yml/badge.svg)](https://github.com/szTheory/sigra/actions/workflows/ci.yml)

**Production-minded authentication for Phoenix 1.8+** — sessions, passwords, email flows, OAuth, MFA, passkeys, optional organizations and admin tooling — without treating security-sensitive code as throwaway scaffolding.

**TL;DR**

- **Problem:** Pow does not support Phoenix 1.8+. Rolling your own auth across crypto, sessions, MFA, and OAuth is slow and risky.
- **What Sigra is:** A **library** of hardened primitives plus **generators** that emit normal Phoenix modules into *your* repo — you patch UX and policy; you `mix deps.update` the sensitive core.
- **When to leave:** You want a hosted identity product (Auth0-as-app) or a framework that hides all auth code from the repo entirely — different tradeoffs.

---

## Pick your lane

| You are… | Do this first |
|----------|----------------|
| **Evaluating** | Skim **Where code lives** (diagram), **What ships**, then open [HexDocs](https://hexdocs.pm/sigra) for API depth. |
| **Integrating** | Run **First integration** (diagram + commands), read **Prerequisites**, then follow [Installation](guides/introduction/installation.md) and [Getting started](guides/introduction/getting-started.md). |
| **Contributing** | Match [toolchain pins in `.tool-versions`](https://github.com/sztheory/sigra/blob/main/.tool-versions), run Postgres-backed tests per [`CLAUDE.md` in the repo](https://github.com/sztheory/sigra/blob/main/CLAUDE.md), read [`CONTRIBUTING.md`](CONTRIBUTING.md); use the [reference example app](https://github.com/sztheory/sigra/tree/main/test/example) as the integration host. |
| **Maintaining / releasing** | See [`MAINTAINING.md`](MAINTAINING.md) for version bumps, Hex and GitHub releases, and planning hygiene for maintainers. |

## Use this in production

Sigra v1.20.0 marks the project's **General Availability**. The authentication primitives have been proven through extensive automated testing and documented security attestations.

1. Add `{:sigra, "~> 1.20"}` to your `mix.exs`.
2. Follow **[Getting started](guides/introduction/getting-started.md)** to generate your host application's auth surface.
3. Review the **[Production checklist](guides/recipes/deployment.md#production-checklist-read-first)** for scheme, cookies, LiveView origins, and mail delivery posture.

Optional deps stay optional until you enable the related capability. If you explicitly turn on async email, JWT, or TOTP QR rendering and something is missing from the host's `mix.exs`, run `mix sigra.doctor` for the blocking row and remediation.

For production confidence and audit evidence:
- **[v1.20 GA evidence](https://github.com/szTheory/sigra/blob/main/.planning/v1.20-GA-UAT-RESULTS.md)**: Comprehensive User Acceptance Testing results and deployment artifacts.
- **[Phase 9 C-1 PASS attestation](https://github.com/szTheory/sigra/blob/main/.planning/phases/09-audit-logging/09-VERIFICATION.md)**: Proof of audit atomicity for all major auth actions.

**Milestone planning (maintainers):** Product north star and scope boundaries for GSD live in `.planning/PROJECT.md` under **North Star (milestones)** (with **Core Value** and **Out of Scope**).

---

## Where code lives

```mermaid
flowchart LR
  subgraph SigraPkg [Sigra_hex_package]
    directionTB
    LibCore[Crypto_tokens_MFA_OAuth_plugs]
    LibBehaviours[Behaviours_and_options]
  end
  subgraph HostRepo [Your_application]
    directionTB
    GenCtx[Generated_contexts_schemas]
    GenWeb[Generated_routes_LiveViews]
  end
  SigraPkg -->|"call_into_Sigra"| GenCtx
  SigraPkg -->|"call_into_Sigra"| GenWeb
  GenWeb -->|"you_edit_copy_and_policy"| GenWeb
```

- **Left:** ships on Hex; security fixes ride **`mix deps.update`**.
- **Right:** plain Elixir under `lib/my_app/` and `lib/my_app_web/` — code review and product iteration happen there.

---

## First integration

```mermaid
flowchart TD
  A[mix_deps_get]
  B["mix_sigra_install_Context_Schema_table"]
  C[mix_ecto_migrate]
  D[mix_phx_server]
  A --> B --> C --> D
```

1. **Dependency** (`mix.exs`):

   ```elixir
   {:sigra, "~> 1.20"}
   ```

2. **Scaffold** (from app root; names must match your domain):

   ```bash
   mix deps.get
   mix sigra.install Accounts User users
   ```

3. **Database + run**:

   ```bash
   mix ecto.migrate
   mix phx.server
   ```

Branching installer flags (`--no-live`, `--admin`, `--api`, …) are summarized below; **every switch and default** is documented in source (`lib/mix/tasks/`) and, when published, on [HexDocs](https://hexdocs.pm/sigra) alongside the API reference.

---

## Prerequisites

| Requirement | Notes |
|-------------|--------|
| **Elixir** | `~> 1.18` (see [`mix.exs`](mix.exs)); align local toolchains with [`.tool-versions` on GitHub](https://github.com/sztheory/sigra/blob/main/.tool-versions). |
| **Phoenix** | 1.8.x baseline the library targets. |
| **Database** | PostgreSQL only. Sigra's generators and maintained install path target a Postgres-backed Ecto repo. |
| **Mailer** | Email flows expect Swoosh (or compatible) wiring — see [Installation](guides/introduction/installation.md). |

Optional dependency rule: Oban, bcrypt migration support, and EQRCode are only blocking when the host actually enables async/background delivery, bcrypt-hash verification, or QR rendering. Use `mix sigra.doctor` to confirm what is active in the current host.

---

## Installer at a glance

| Intent | Example flags | Read more |
|--------|----------------|-----------|
| **Controllers only** (no LiveView UI) | `--no-live` | [`mix sigra.install` source](lib/mix/tasks/sigra.install.ex), [HexDocs](https://hexdocs.pm/sigra) |
| **API / JWT surface** | `--api`, or `--jwt` (implies API pieces) | [API authentication](guides/flows/api-authentication.md), [`sigra.install` source](lib/mix/tasks/sigra.install.ex) |
| **Admin LiveView suite** | default on; **`--no-admin`** to omit | [`sigra.install` source](lib/mix/tasks/sigra.install.ex) |
| **Passkeys** | default on; **`--no-passkeys`** to omit | [Passkeys recipe](guides/recipes/passkeys.md) |
| **Organizations** | default on; **`--no-organizations`** to omit | [Multi-tenant recipe](guides/recipes/multi-tenant.md) |
| **UUID primary keys** | default on; **`--no-binary-id`** for bigint IDs | [`sigra.install` source](lib/mix/tasks/sigra.install.ex) |
| **OAuth slice only** (existing install) | `mix sigra.gen.oauth …` | [OAuth flow](guides/flows/oauth.md), [`sigra.gen.oauth` source](lib/mix/tasks/sigra.gen.oauth.ex) |

---

## What ships in the box

One clause each — depth lives in HexDocs and the guides linked in the next section.

| Area | You get |
|------|---------|
| **Identity** | Argon2id passwords, optional bcrypt → Argon2id upgrade on login, remember-me, sudo / step-up hooks. |
| **Sessions** | Database-backed sessions, device/IP metadata hooks, revocation patterns the generators wire up. |
| **Email** | Registration, confirmation (link + code), magic link, reset, lifecycle mailers — Swoosh-shaped templates in the host. |
| **MFA** | TOTP (NimbleTOTP), backup codes, lockout-aware verification; trust-this-device patterns in the example app. |
| **OAuth** | Assent-backed strategies, encrypted token fields when Cloak is in play; optional `mix sigra.gen.oauth` for incremental adoption. |
| **Passkeys** | WebAuthn via `wax_` when enabled — registration + authentication ceremonies with host-owned credential rows. |
| **Organizations** | Logical multi-tenancy (memberships, invitations, scoped plugs) when enabled — not “separate DB per tenant”. |
| **Admin** | Optional installer-generated admin LiveView (global + org lenses), impersonation guardrails, audit surfaces when enabled. |
| **Audit** | Structured audit logging hooks feeding explorer/export flows where the installer emitted them. |

---

## Topic map → guides

| Topic | Guide |
|-------|--------|
| Installation & env | [introduction/installation.md](guides/introduction/installation.md) |
| First happy path | [introduction/getting-started.md](guides/introduction/getting-started.md) |
| Upgrade notes | [v1.0 → v1.1](guides/introduction/upgrading-to-v1.1.md) · [toward v1.7](guides/introduction/upgrading-to-v1.7.md) · [toward v1.8](guides/introduction/upgrading-to-v1.8.md) |
| Registration | [flows/registration.md](guides/flows/registration.md) |
| Login / logout | [flows/login-and-logout.md](guides/flows/login-and-logout.md) |
| Password reset | [flows/password-reset.md](guides/flows/password-reset.md) |
| Account lifecycle | [flows/account-lifecycle.md](guides/flows/account-lifecycle.md) |
| OAuth | [flows/oauth.md](guides/flows/oauth.md) |
| MFA | [flows/mfa.md](guides/flows/mfa.md) |
| API / JWT | [flows/api-authentication.md](guides/flows/api-authentication.md) |
| Audit logging | [flows/audit-logging.md](guides/flows/audit-logging.md), [audit semantics](docs/audit-semantics.md) |
| Deployment | [recipes/deployment.md](guides/recipes/deployment.md) |
| Testing | [recipes/testing.md](guides/recipes/testing.md) |
| Passkeys | [recipes/passkeys.md](guides/recipes/passkeys.md) |
| Multi-tenant patterns | [recipes/multi-tenant.md](guides/recipes/multi-tenant.md) |
| Custom user fields | [recipes/custom-user-fields.md](guides/recipes/custom-user-fields.md) |
| Subdomain auth | [recipes/subdomain-auth.md](guides/recipes/subdomain-auth.md) |

---

## Security posture (headlines)

| Topic | Default stance |
|-------|----------------|
| **Passwords** | Argon2id via configured hasher; bcrypt verify-and-upgrade path when enabled. |
| **Tokens** | HMAC-protected, time-bounded patterns for magic links, reset, confirmation — stored references, not “guessable IDs only”. |
| **Enumeration** | Safer defaults on account discovery flows (details in HexDocs per flow). |
| **Step-up** | Sudo / MFA challenge patterns integrate with Phoenix plugs and LiveView mounts as generated. |

For threat-model detail and per-flow guarantees, use **HexDocs** and the guides above — the README stays a map, not a spec.

## Release evidence (maintainers and auditors)

Sigra keeps an **evidence hub** (what we ran versus waived for GA cuts, how CI maps to human UAT rows, and pointers to planning artifacts on GitHub). That material is **not** a compliance certificate for your application — integration and deployment risk stay with the **host**.

- **[GA evidence and audit posture](docs/ga-evidence.md)** — router page; same content ships on [HexDocs](https://hexdocs.pm/sigra/ga-evidence.html).
- **[UAT versus CI coverage](docs/uat-ci-coverage.md)** — machine versus human boundaries.

Coordinated disclosure: [SECURITY.md](SECURITY.md).

---

## Reference host: `test/example`

The [`test/example`](https://github.com/sztheory/sigra/tree/main/test/example) tree is a **real Phoenix app** living inside this repo: it tracks what `mix sigra.install` (and friends) emit, compiles under `--warnings-as-errors` in CI, and backs **Playwright** browser smoke (golden path, org flows, admin checkpoints, GA shift-left specs). It is not a second product — it is the executable contract that installer drift tests and reviewer artifacts refer to. When in doubt about “what does the generator actually produce?”, read that tree or the HexDocs task reference.

---

## Contributing & issues

- **Workflow & CI** — [`CONTRIBUTING.md`](CONTRIBUTING.md) (Playwright artifacts, installer audit jobs, Pages mirror).
- **Local parity** — [`CLAUDE.md` on GitHub](https://github.com/sztheory/sigra/blob/main/CLAUDE.md) (Postgres one-liner, `mix test` expectations).
- **Bugs & ideas** — [GitHub Issues](https://github.com/szTheory/sigra/issues).

---

## License

MIT — see [`LICENSE`](LICENSE).
