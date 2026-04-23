# Upgrading notes — toward v1.10

This page tracks **maintainer-facing** and **adopter-facing** expectations for the **planning milestone v1.10** (*adopter confidence for solo production*). SemVer for the **library** on Hex follows **`mix.exs`** and **`CHANGELOG.md`**; planning milestones are coordination labels in **`.planning/`** — not a second installable version axis (see **`CHANGELOG.md`** → *Planning milestones vs Hex releases*).

For what “first production” is assumed to include in v1.10, see **[v1.10 adopter scope](../../.planning/v1.10-ADOPTER-SCOPE.md)**.

## After v1.9 (planning milestone)

If you have not followed **v1.9** audit-atomicity work yet, read the archived roadmap **[v1.9 ROADMAP](../../.planning/milestones/v1.9-ROADMAP.md)** — **v1.10** builds on that shipped baseline without replacing **v1.8** / **v1.7** doc narratives.

**v1.10** is intentionally docs-first: deployment and mail confidence, an intermediate production path, upgrade entry points, and explicit **non-goals** (Lockspire glue, full-library SEED-002) — not new auth primitives.

## Library / host upgrade checklist

1. Bump `{:sigra, ...}` in the **host** **`mix.exs`** using **`CHANGELOG.md`** and Hex release notes as the source of truth.
2. Run **`mix deps.get`**, then **`mix compile`** and **`mix test`** (or your CI equivalent).
3. Re-read **`guides/introduction/intermediate-production-path.md`** if you run OAuth, MFA, or default generator options beyond the installer golden path.

Unless **`CHANGELOG.md`** documents a **breaking** change for your line, **no new `mix sigra.upgrade` steps** are implied by the **v1.10** planning milestone alone.

## See also

- [Upgrading notes — toward v1.11](upgrading-to-v1.11.html)
- [Upgrading notes — toward v1.8](upgrading-to-v1.8.html)
- [Upgrading notes — toward v1.7](upgrading-to-v1.7.html)
- [First hour with Sigra](first-hour.html)
- [Troubleshooting install](troubleshooting-install.html)
