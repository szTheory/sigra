# Security Policy

## Reporting a Vulnerability

Please report security vulnerabilities via GitHub's private vulnerability reporting for this repository, not the public issue tracker.

Use the repository security advisories area at https://github.com/sztheory/sigra/security/advisories to start a private report. Maintainers will acknowledge receipt within a reasonable window and coordinate next steps with you.

For routine bugs and feature requests that are not security-sensitive, use the public issue tracker linked from [CONTRIBUTING.md](CONTRIBUTING.md).

## Security Invariants

| Area | Sigra stance | Host responsibility |
|------|--------------|---------------------|
| Sessions | Generated session flows use database-backed session patterns, revocation seams, and device/IP metadata hooks where installed. | Configure HTTPS, cookies, proxy headers, session lifetime policy, and production deployment controls. |
| Tokens | Confirmation, reset, magic-link, API token, and JWT refresh paths use time-bounded, HMAC-protected or hashed-reference patterns according to the installed slice. | Protect secrets, rotate credentials, choose exposure windows, and operate any external token consumers. |
| MFA and passkeys | TOTP, backup codes, trusted-browser flows, passkeys, lockout, and recovery paths are provided when enabled. | Decide enrollment policy, support recovery operations, and test browser/device support in the host environment. |
| Audit durability | Sigra owns library audit row writes, structured telemetry, and audit semantics for auth actions it performs. | Own retention, external sinks, reporting UX, audit forwarding, and operational monitoring. |
| Optional mail, Oban, and OAuth | Optional features are guarded by `Sigra.OptionalDeps`, diagnosable with `Sigra.Doctor`, and inspectable with `mix sigra.doctor`. | Add and configure mail, Oban, OAuth providers, credentials, queue supervision, and failure handling. |
| Generated-host ownership | Generated schemas, migrations, controllers, LiveViews, templates, and routes are normal host application code after install. | Review, customize, patch, migrate, and operate generated-host code. |
| Host-owned authorization | Sigra establishes identity and provides seams for policy checks. | Own authorization, business policy, entitlements, compliance controls, and product-specific access decisions. |

## Security Non-Goals

| Non-goal | Boundary |
|----------|----------|
| Hosted control plane | Sigra is a library and generator, not a managed identity service. |
| Compliance certification | Sigra does not certify the host application, deployment, organization, or controls. |
| Opinionated authorization engine | Host-owned authorization and business policy remain outside Sigra's core. |
| SCIM in 1.0 | SCIM is not part of the 1.0 contract surface. |
| Broad generated-host UI redesign | Generated UI remains functional host-owned Phoenix code, not a complete design system. |
| Mailglass adapter resurrection | Sigra ships recipe-level host-owned Mailglass wiring, not a library-resident adapter. |
| Public RC train by default | The selected path is a direct Hex `1.0.0` release unless a concrete blocker changes the plan. |
| New auth primitives | This release locks the existing contract surface rather than adding new auth primitives. |
