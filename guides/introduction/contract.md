# Sigra 1.32 Contract

This page is the public contract for the selected Sigra `1.32.0` release line. It explains what the Hex package promises, what generated host applications own, and which parts are shared seams.

## Version Axes

Sigra has two version axes:

- **Hex package SemVer** is the installable package line. The current published package truth before the release PR is `1.20.0`; the selected release path moves to real Hex `1.32.0`.
- **GSD planning milestones** such as `v1.32` are planning tranche labels. For this release, the package target intentionally aligns to `1.32.0`; future planning labels still should not be treated as a second installable package version unless the release docs say so.

When public docs, HexDocs, tags, and release notes refer to the package, treat Hex SemVer as the source of truth.

## Supported Stack

Sigra's `1.32.0` contract follows the package and generator posture in `mix.exs`:

| Surface | Contract |
|---------|----------|
| Elixir | `~> 1.18` |
| OTP | Follows Elixir 1.18 compatibility rather than a separate hand-written OTP policy. |
| Phoenix | Phoenix 1.8.x is the target baseline. |
| Ecto | `~> 3.12` via `ecto` and `ecto_sql`. |
| Database | Tested and supported for typical Postgres-backed Phoenix hosts. Sigra does not inherit every historical database range that transitive libraries may support. |
| Optional dependencies | Optional features are guarded by `Sigra.OptionalDeps`, reported by `Sigra.Doctor`, and inspectable with `mix sigra.doctor`. Missing optional deps should degrade or fail according to the documented feature wiring, not silently change security posture. |

## Ownership Boundaries

| Boundary | Owned surface |
|----------|---------------|
| Library-owned | Versioned Hex package code: crypto helpers, token verification and HMAC handling, MFA/passkey helpers, plugs, config and behaviours, optional-dependency predicates, `Sigra.Doctor`, `mix sigra.doctor`, and fixes delivered by `mix deps.update`. |
| Generated-host-owned | Schemas, migrations, contexts, routes, LiveViews, templates, mailer modules, generated UI customization, deployment controls, product policy, authorization rules, and host business logic emitted into your application. |
| Shared seams | Mail delivery, Oban/background work, OAuth providers, audit forwarding, optional companion libraries, webhook side effects, and host policy hooks. Sigra provides structured seams; the host decides how to wire and operate them. |

## SemVer And Deprecation Policy

For `1.x`, documented public library APIs and documented generated contracts are stable under SemVer. Security-sensitive fixes and compatible additions should arrive through normal dependency updates.

Private, internal, undocumented, and experimental surfaces are outside that guarantee. Host-owned edits to generated code are also outside the library SemVer promise: once code is emitted into your application, your team owns local modifications, product policy, and migration choices.

Deprecations should identify the replacement path, preserve a migration lane when practical, and avoid surprise removal inside the same minor line unless a security issue requires a narrower path.

## Security Invariants

Sigra's security contract is bounded by the library/generator split:

For the top-level security table, vulnerability reporting policy, and non-goal boundaries, see [`SECURITY.md`](../../SECURITY.md).

- **Sessions** use database-backed session patterns and revocation seams that generated hosts can inspect and adapt.
- **Tokens** use time-bounded, HMAC-protected or hashed-reference patterns for flows such as confirmation, reset, magic links, API tokens, and JWT refresh, according to the installed slice.
- **MFA and passkeys** provide TOTP, backup code, trusted-browser, WebAuthn/passkey, lockout, and recovery patterns where the corresponding features are enabled.
- **Audit durability** is owned by Sigra where the library writes audit rows and telemetry; forwarding, retention, external sinks, and reporting UX remain host-operated seams.
- **Optional mail, Oban, and OAuth responsibilities** depend on host configuration and optional dependencies. Use `mix sigra.doctor` to inspect wiring before relying on those paths.
- **Generated-host ownership** means generated schemas, migrations, controllers, LiveViews, templates, and routes are normal application code after install.
- **Host-owned authorization and business policy** stay in the host. Sigra identifies users and provides seams; the host decides what each user may do.

## Non-Goals

Sigra `1.32.0` does not promise:

- A hosted control plane or managed identity service.
- Compliance certification or a host deployment warranty.
- An opinionated authorization engine, RBAC system, or Zanzibar-style policy layer.
- SCIM support in 1.32.
- A broad generated-host UI redesign.
- A Mailglass adapter resurrection inside the Sigra package.
- A public RC train by default.
- New auth primitives in this release beyond the existing contract surface.
