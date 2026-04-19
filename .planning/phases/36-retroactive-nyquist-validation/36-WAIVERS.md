# Phase 36 — Waived / retroactive Nyquist debt (VAL-02)

**Owner:** Sigra maintainers  
**Date:** 2026-04-17  

Each row documents a phase whose `*-VALIDATION.md` remained `status: draft` (or used a legacy pre-template layout) while the underlying work shipped and was verified elsewhere. This satisfies **VAL-02 (b)** — explicit waiver with superseding pointer — without rewriting every historical Nyquist table in one milestone.

| phase_dir | classification_before_36 | waiver_rationale | superseding_evidence | owner | date |
|-----------|-------------------------|------------------|----------------------|-------|------|
| 12-scope-session-foundation | COMPLIANT_DRAFT_STATUS | Shipped in v1.1; validation artifact never flipped to `approved` | `.planning/milestones/v1.1-ROADMAP.md` | Sigra maintainers | 2026-04-17 |
| 13-organizations-schemas-context | COMPLIANT_DRAFT_STATUS | Shipped in v1.1 | `.planning/milestones/v1.1-ROADMAP.md` | Sigra maintainers | 2026-04-17 |
| 14-org-plugs-scope-hydration | COMPLIANT_DRAFT_STATUS | Shipped in v1.1 | `.planning/milestones/v1.1-ROADMAP.md` | Sigra maintainers | 2026-04-17 |
| 15-audit-integration | COMPLIANT_DRAFT_STATUS | Shipped in v1.1 | `.planning/milestones/v1.1-ROADMAP.md` | Sigra maintainers | 2026-04-17 |
| 16-org-liveviews-switcher | COMPLIANT_DRAFT_STATUS | Shipped in v1.1 | `.planning/milestones/v1.1-ROADMAP.md` | Sigra maintainers | 2026-04-17 |
| 17-invitation-flow-email | COMPLIANT_DRAFT_STATUS | Shipped in v1.1 | `.planning/milestones/v1.1-ROADMAP.md` | Sigra maintainers | 2026-04-17 |
| 18-backfill-organizations-generator-wiring | LEGACY_FORMAT | Pre-standard `*-VALIDATION.md` schema; work verified under v1.1 | `.planning/milestones/v1.1-ROADMAP.md` | Sigra maintainers | 2026-04-17 |
| 19-passkey-schema-contexts | COMPLIANT_DRAFT_STATUS | Shipped in v1.1 | `.planning/milestones/v1.1-ROADMAP.md` | Sigra maintainers | 2026-04-17 |
| 20-passkey-challenge-plug-runtime-config-js-hooks-infra | COMPLIANT_DRAFT_STATUS | Shipped in v1.1 | `.planning/milestones/v1.1-ROADMAP.md` | Sigra maintainers | 2026-04-17 |
| 21-passkey-liveviews-post-auth-controller | COMPLIANT_DRAFT_STATUS | Shipped in v1.1 | `.planning/milestones/v1.1-ROADMAP.md` | Sigra maintainers | 2026-04-17 |
| 22-passkeys-generator-wiring | COMPLIANT_DRAFT_STATUS | Shipped in v1.1 | `.planning/milestones/v1.1-ROADMAP.md` | Sigra maintainers | 2026-04-17 |
| 23-docs-ci-smoke-upgrade-guide | COMPLIANT_DRAFT_STATUS | Shipped in v1.1 | `.planning/milestones/v1.1-ROADMAP.md` | Sigra maintainers | 2026-04-17 |
| 24-repair-phase-16-17-organizations-generator-templates | COMPLIANT_DRAFT_STATUS | Closeout shipped pre-v1.2 | `.planning/milestones/v1.1-ROADMAP.md` | Sigra maintainers | 2026-04-17 |
| 25-fix-sigra-upgrade-duplicate-migration-version-bug-and-restor | COMPLIANT_DRAFT_STATUS | Closeout shipped pre-v1.2 | `.planning/milestones/v1.1-ROADMAP.md` | Sigra maintainers | 2026-04-17 |
| 26-retroactive-v1-1-verification-closeout | COMPLIANT_DRAFT_STATUS | Explicit v1.1 verification closeout milestone | `.planning/milestones/v1.1-ROADMAP.md` | Sigra maintainers | 2026-04-17 |
| 27-admin-access-foundation | COMPLIANT_DRAFT_STATUS | Shipped v1.2; milestone audit is canonical | `.planning/milestones/v1.2-MILESTONE-AUDIT.md` | Sigra maintainers | 2026-04-17 |
| 28-user-operations-surface | COMPLIANT_DRAFT_STATUS | Shipped v1.2 | `.planning/milestones/v1.2-MILESTONE-AUDIT.md` | Sigra maintainers | 2026-04-17 |
| 29-secure-impersonation | COMPLIANT_DRAFT_STATUS | Shipped v1.2 | `.planning/milestones/v1.2-MILESTONE-AUDIT.md` | Sigra maintainers | 2026-04-17 |
| 30-audit-exploration-and-export | COMPLIANT_DRAFT_STATUS | Shipped v1.2 | `.planning/milestones/v1.2-MILESTONE-AUDIT.md` | Sigra maintainers | 2026-04-17 |
| 31-automation-first-verification | COMPLIANT_DRAFT_STATUS | Shipped v1.2 | `.planning/milestones/v1.2-MILESTONE-AUDIT.md` | Sigra maintainers | 2026-04-17 |
| 32-generated-installer-admin-surface-parity | COMPLIANT_DRAFT_STATUS | Shipped v1.2 | `.planning/milestones/v1.2-MILESTONE-AUDIT.md` | Sigra maintainers | 2026-04-17 |
| 34-generated-host-e2e-coverage-and-phase-28-retroactive-verification | COMPLIANT_DRAFT_STATUS | Shipped v1.2 | `.planning/milestones/v1.2-MILESTONE-AUDIT.md` | Sigra maintainers | 2026-04-17 |
| 35-shift-left-verification-automation | COMPLIANT_DRAFT_STATUS | Shipped v1.2 | `.planning/milestones/v1.2-MILESTONE-AUDIT.md` | Sigra maintainers | 2026-04-17 |
| 36-retroactive-nyquist-validation | COMPLIANT_DRAFT_STATUS | Active hardening phase; waiver covers draft-status frontmatter until Phase 36 execution finishes | `.planning/phases/36-retroactive-nyquist-validation/36-INVENTORY.md` + `.planning/milestones/v1.2-MILESTONE-AUDIT.md` | Sigra maintainers | 2026-04-17 |

**Structural cleanup:** Empty duplicate directory `.planning/phases/34-generated-host-e2e-and-phase-28-retroactive-verification` was removed (`rmdir` on 2026-04-17); canonical Phase 34 artifacts live under `34-generated-host-e2e-coverage-and-phase-28-retroactive-verification/`.
