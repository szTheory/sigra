# Upgrading notes — toward v1.8

This page tracks **maintainer-facing** and **adopter-facing** expectations for the **planning milestone v1.8** (*adopter polish — diminishing returns*). SemVer for the **library** on Hex follows **`mix.exs`** and **`CHANGELOG.md`**; planning milestones (**v1.7**, **v1.8**, …) are coordination labels in **`.planning/`** — not a second installable version axis (see **`CHANGELOG.md`** → *Planning milestones vs Hex releases*).

## After v1.7 (planning milestone)

If you have not read **v1.7** maintainer context yet (Nyquist **41–44**, OAuth↔audit CI contracts, GA / human-vs-machine docs hub), start with **[Upgrading notes — toward v1.7](upgrading-to-v1.7.html)** — **v1.8** builds on that narrative without replacing it.

**v1.8** itself is intentionally small: **clearer doc navigation**, **upgrade entry points**, and **companion OAuth recipe** wording — not a broad audit refactor or new optional packages.

## Library / host upgrade checklist

1. Bump `{:sigra, ...}` in the **host** `mix.exs` using **`CHANGELOG.md`** and Hex release notes as the source of truth.
2. Run **`mix deps.get`**, then **`mix compile`** and **`mix test`** (or your CI equivalent).
3. If you use **optional** integrations (Oban, Hammer, OAuth templates), confirm optional deps still match what generated code expects (**`README.md`** and installer output).

Unless **`CHANGELOG.md`** documents a **breaking** change for your **`0.2.x`** line, **no new `mix sigra.upgrade` steps** are implied by the **v1.8** planning milestone alone.

## See also

- [First hour with Sigra](first-hour.html)
- [Troubleshooting install](troubleshooting-install.html)
- [Upgrading notes — toward v1.7](upgrading-to-v1.7.html)
- Archived planning: **`.planning/milestones/v1.7-ROADMAP.md`**
