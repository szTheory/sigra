# Upgrading notes — toward v1.7

This page tracks **maintainer-facing** and **adopter-facing** expectations after **v1.6** (Nyquist closure + OAuth audit depth). SemVer for the **library** follows `mix.exs`; planning milestones (**v1.6**, **v1.7**) are coordination labels in `.planning/`.

## After v1.6 (planning milestone)

- **Nyquist 41–44:** Disposition lives in **`.planning/nyquist-phases-41-44-matrix.md`** and is indexed from **`MAINTAINING.md`**. If you maintain a fork, read the matrix before changing verification artifacts under `.planning/phases/41–44*/`.
- **OAuth ↔ audit (OA-01):** Merge-blocking tests include **`Sigra.OAuthCeremonyAuditTest`** and CI structure is guarded by **`Sigra.Planning.Phase58OauthOa01CiContractTest`**. Do not add `exclude:` patterns that skip OAuth audit work without updating that contract.
- **Docs hub:** Machine vs human coverage for GA-style rows is centralized in **`docs/uat-ci-coverage.md`**.

## Library version

Always take **`CHANGELOG.md`** and Hex release notes as the source of truth for **package** upgrades. This guide will accumulate **host-app** migration steps as v1.7 phases ship.

## See also

- [First hour with Sigra](first-hour.html)
- [Troubleshooting install](troubleshooting-install.html)
- [Upgrading notes — toward v1.8](upgrading-to-v1.8.html) — post–v1.7 doc polish + Hex bump checklist
- Archived planning: `.planning/milestones/v1.6-ROADMAP.md`
