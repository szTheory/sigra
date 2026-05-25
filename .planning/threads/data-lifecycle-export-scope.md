---
slug: data-lifecycle-export-scope
title: Data lifecycle and export scope follow-on investigation
status: open
created: 2026-05-25
updated: 2026-05-25
---

# Thread: Data lifecycle and export scope follow-on investigation

## Goal

Preserve the current assessment of `DATA-LIFECYCLE` so it can be picked up cleanly after `ENT-SSO` without re-deriving why it matters or how narrow it should stay.

## Context

*Created 2026-05-25.*

- `DATA-LIFECYCLE` remains a meaningful future milestone, but the repo-grounded assessment ranked it behind `ENT-SSO`.
- The current substrate is real but thin:
  - `Sigra.DataExport` exists, but today it only exports a minimal auth map (`user`, `sessions`, `identities`) and has a very light test surface.
  - `guides/flows/audit-logging.md` already documents `Sigra.Audit.stream/2` for SIEM export and retention posture.
  - `guides/flows/account-lifecycle.md` already documents deletion/anonymize semantics and immediate session/token revocation.
  - Admin/audit CSV export is already proven on the operator surface, but it is not yet a coherent end-user/compliance-facing auth-data contract.
- The strongest future milestone shape still looks narrow and evidence-driven:
  - extend `Sigra.DataExport` into a clearer auth-data export contract
  - connect audit export posture to that contract truthfully
  - clarify anonymize/delete/recovery semantics and operator recipes
  - avoid pretending Sigra owns host-app compliance or generic BI/reporting export
- This milestone should stay out of "compliance theater":
  - no certifications
  - no broad reporting platform behavior
  - no generic app-domain export guarantees beyond auth/account-owned surfaces

## References

- `.planning/MILESTONE-ARC.md`
- `.planning/PROJECT.md`
- `lib/sigra/data_export.ex`
- `test/sigra/data_export_test.exs`
- `guides/flows/audit-logging.md`
- `guides/flows/account-lifecycle.md`

## Next Steps

- Inventory the exact auth/account data Sigra can truthfully export today versus what still lives only in host-owned schemas.
- Decide whether audit export belongs as a first-class `DataExport` concern or remains a parallel operator/export surface with linked docs.
- Tighten the semantics for `:soft_delete`, `:hard_delete`, and `:anonymize` into a clearer operator-facing truth table.
- Keep the milestone scoped to auth/account data only unless a concrete adopter need proves a wider seam.
