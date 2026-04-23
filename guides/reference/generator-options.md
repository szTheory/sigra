# Generator and install options

This page is the **canonical human index** for `mix sigra.install` switches. Exhaustive machine truth lives in **`mix help sigra.install`** and in the HexDocs module page for **`Mix.Tasks.Sigra.Install`**.

| Flag | Default | One-line effect | See also |
|------|---------|-----------------|----------|
| `--live` / `--no-live` | true | Generate LiveView-based auth pages vs a slimmer controller-only surface. | [Getting started](../introduction/getting-started.html) |
| `--binary-id` / `--no-binary-id` | true | Use UUID primary keys (`binary_id`) vs bigint integer IDs. | [Installation](../introduction/installation.html) |
| `--table` | — | Override the generated Ecto table name instead of using the third positional argument. | [Installation](../introduction/installation.html) |
| `--api` | false | Emit the API token controller and routes for programmatic clients. | [API authentication](../flows/api-authentication.html) |
| `--jwt` | false | Emit JWT access/refresh handling (implies the API token path). | [API authentication](../flows/api-authentication.html) |
| `--organizations` / `--no-organizations` | true | Generate organizations, memberships, and tenant-aware routing. | [Multi-tenant apps](../recipes/multi-tenant.html) |
| `--passkeys` / `--no-passkeys` | true | Generate WebAuthn / passkey enrollment and login scaffolding. | [Passkeys](../recipes/passkeys.html) |
| `--admin` / `--no-admin` | true | Generate admin dashboard scaffolding. | [Deployment](../recipes/deployment.html#production-checklist-read-first) |
| `--yes` | false | Non-interactive install for CI and scripts (skips prompts). | [Testing auth flows](../recipes/testing.html) |

## LiveView

The default install keeps **LiveView** on so registration, login, settings, and MFA settings match the modern Phoenix tutorial shape most teams expect. Turning LiveView off (`--no-live`) is a deliberate slimming choice—pair it with the rest of your routing plan so you are not surprised by missing LiveView modules. The [Getting started](../introduction/getting-started.html) walkthrough assumes LiveView routes exist.

## Binary IDs

Sigra defaults **`binary_id`** to **on**, which matches the generator migrations you see in new apps (`uuid` columns). If you are grafting Sigra onto an existing `bigint` users table, `--no-binary-id` keeps the installer aligned with your current primary-key story—read [Installation](../introduction/installation.html) before flipping this on a brownfield app.

## API and JWT

`--api` exposes bearer-token-friendly controllers; `--jwt` layers JWT issuance on top of that path. Both are optional product choices—start with browser sessions, then add API/JWT when you have a real non-browser client. See [API authentication](../flows/api-authentication.html) for token rotation, audit hooks, and security notes.

## Organizations

Logical multi-tenancy (memberships, org switcher, `for_org/2` helpers) ships **on** by default. Use `--no-organizations` only when you are certain you will never need org-scoped queries in this codebase—removing it later is more work than carrying the default tables. [Multi-tenant apps](../recipes/multi-tenant.html) explains how tenant scoping is enforced in application code.

## Passkeys

Passkeys are **on** by default so passwordless enrollment is available from settings. `--no-passkeys` removes WebAuthn controllers and templates—reasonable for constrained environments, but you should document why for future operators. [Passkeys](../recipes/passkeys.html) covers RP ID, origins, and recovery paths.

## Admin

Admin scaffolding defaults **on** so support teams get a generated dashboard surface. `--no-admin` removes that bundle when you already have an admin product or strict separation of duties. Production hardening still belongs in [Deployment](../recipes/deployment.html#production-checklist-read-first)—the installer does not infer your threat model.

## Non-interactive CI

Pass **`--yes`** in pipelines so `mix sigra.install` never blocks on prompts. Combine it with explicit flags (`--no-live`, `--no-passkeys`, etc.) when your fixture app must mirror a reduced feature set. Pair with [Testing auth flows](../recipes/testing.html) for fixtures and `Sigra.Testing` helpers.

If anything on this page disagrees with **`mix help sigra.install`**, treat **`mix help sigra.install`** as authoritative and open an issue or PR so the guide can be corrected.
