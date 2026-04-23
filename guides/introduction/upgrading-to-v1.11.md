# Upgrading notes — toward v1.11

This page tracks **maintainer-facing** and **adopter-facing** expectations for the **planning milestone v1.11** (*adoption stabilization*). SemVer for the **library** on Hex follows **`mix.exs`** and **`CHANGELOG.md`**; planning milestones are coordination labels in **`.planning/`** — not a second installable version axis on Hex (see **`CHANGELOG.md`** → *Planning milestones vs Hex releases*).

**v1.11** is intentionally small: triage log, upgrade continuity from **v1.10**, intro cross-links, and maintainer guidance on **when to pause full GSD milestone cycles** versus **Hex-only** patch releases. It does **not** ship full **SEED-002**, **SEED-001**, or **Lockspire** glue — those remain on their existing deferral triggers (**ADR 001**, seed docs).

For the assumed “first production” feature bundle through **v1.10**, see **[v1.10 adopter scope](../../.planning/v1.10-ADOPTER-SCOPE.md)** and **[Adoption stabilization triage](../../.planning/v1.11-TRIAGE.md)**.

## After v1.10 (planning milestone)

If you have not followed **v1.10** adopter-confidence docs yet, read **[Upgrading notes — toward v1.10](upgrading-to-v1.10.html)** first — **v1.11** layers maintainer cadence expectations and doc continuity on that baseline.

## Library / host upgrade checklist

1. Bump `{:sigra, ...}` in the **host** **`mix.exs`** using **`CHANGELOG.md`** and Hex release notes as the source of truth.
2. Run **`mix deps.get`**, then **`mix compile`** and **`mix test`** (or your CI equivalent).
3. Skim **[Maintaining Sigra](../../MAINTAINING.html)** → **Milestone cadence and pause** if you maintain Sigra itself or fork policy-heavy branches.

Unless **`CHANGELOG.md`** documents a **breaking** change for your line, **no new `mix sigra.upgrade` steps** are implied by the **v1.11** planning milestone alone.

## See also

- [Upgrading notes — toward v1.10](upgrading-to-v1.10.html)
- [Upgrading notes — toward v1.8](upgrading-to-v1.8.html)
- [First hour with Sigra](first-hour.html)
- [Troubleshooting install](troubleshooting-install.html)
