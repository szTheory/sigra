# Upgrading notes — toward v1.12

This page tracks **maintainer-facing** and **adopter-facing** expectations for the **planning milestone v1.12** (*trust, evidence, and adoption polish*). SemVer for the **library** on Hex follows **`mix.exs`** and **`CHANGELOG.md`**; planning milestones are coordination labels in **`.planning/`** — not a second installable version axis on Hex (see **`CHANGELOG.md`** → *Planning milestones vs Hex releases*).

**v1.12** tightens the **trust bundle** across phases **73–75**: a bounded **SEED-002** audit batch (planning truth in **09-03**), a **single UAT outcome index** for the eight GA·UAT SEED rows, and alignment with the **machine vs human** coverage catalog in **`docs/uat-ci-coverage.md`**. The **eight-row SEED outcome table** exists **only** in **`.planning/v1.12-UAT-EVIDENCE.md`** — do **not** copy or paraphrase that matrix here.

- **Bounded batch / planning truth:** [`09-03-SUMMARY.md`](https://github.com/sztheory/sigra/blob/main/.planning/phases/09-audit-logging/09-03-SUMMARY.md)
- **UAT outcome index (eight rows):** [`v1.12-UAT-EVIDENCE.md`](https://github.com/sztheory/sigra/blob/main/.planning/v1.12-UAT-EVIDENCE.md)
- **Machine vs residual catalog:** [`uat-ci-coverage.md`](../../docs/uat-ci-coverage.md) — read the **v1.12 launch evidence** subsection

For **v1.11** adoption stabilization context, see **[Upgrading notes — toward v1.11](upgrading-to-v1.11.html)**.

## After v1.11 (planning milestone)

If you have not read **v1.11** upgrade notes yet, read **[Upgrading notes — toward v1.11](upgrading-to-v1.11.html)** first — **v1.12** builds on that baseline.

## Library / host upgrade checklist

1. Bump `{:sigra, ...}` in the **host** **`mix.exs`** using **`CHANGELOG.md`** and Hex release notes as the source of truth.
2. Run **`mix deps.get`**, then **`mix compile`** and **`mix test`** (or your CI equivalent).
3. Skim **`CHANGELOG.md`** and **[Maintaining Sigra](../../MAINTAINING.md)** for **breaking** or **host-app** steps for your line; use **MAINTAINING** for maintainer **release ritual** pointers around evidence URLs when cutting minors/majors.

Unless **`CHANGELOG.md`** documents a **breaking** change for your line, **no new `mix sigra.upgrade` steps** are implied by the **v1.12** planning milestone alone.

## See also

- [Upgrading notes — toward v1.11](upgrading-to-v1.11.html)
- [Upgrading notes — toward v1.10](upgrading-to-v1.10.html)
- [Upgrading notes — toward v1.8](upgrading-to-v1.8.html)
- [First hour with Sigra](first-hour.html)
- [Troubleshooting install](troubleshooting-install.html)
