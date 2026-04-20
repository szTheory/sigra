# Phase 36 — Nyquist / VALIDATION inventory (VAL-01)

**Generated:** 2026-04-17 (bootstrap; re-run regen script before closing VAL-01).

**Regenerate:**

```bash
bash .planning/phases/36-retroactive-nyquist-validation/scripts/regen-inventory.sh
```

## Summary counts

| Category | Count |
|----------|-------|
| MISSING `*-VALIDATION.md` | 0 |
| Present — `nyquist_compliant: true` but `status` not `approved` (treat as draft-adjacent) | 22 |
| Present — `nyquist_compliant: true` + `status: approved` | 1 |
| Present — legacy / alternate schema (no standard frontmatter) | 1 |
| REMOVED duplicate phase dir (no artifact) | 1 |

## Per-phase directory

| phase_dir | validation_file | classification | notes |
|-----------|-----------------|----------------|-------|
| 10.1.1-example-app-repair-ci-install-usage-smoke-harness | 10.1.1-VALIDATION.md | COMPLIANT_APPROVED | retro file added Phase 36 |
| 11-generator-feature-system | 11-VALIDATION.md | COMPLIANT_APPROVED | |
| 12-scope-session-foundation | 12-VALIDATION.md | COMPLIANT_DRAFT_STATUS | `status: draft` typical |
| 13-organizations-schemas-context | 13-VALIDATION.md | COMPLIANT_DRAFT_STATUS | |
| 14-org-plugs-scope-hydration | 14-VALIDATION.md | COMPLIANT_DRAFT_STATUS | |
| 15-audit-integration | 15-VALIDATION.md | COMPLIANT_DRAFT_STATUS | |
| 16-org-liveviews-switcher | 16-VALIDATION.md | COMPLIANT_DRAFT_STATUS | |
| 17-invitation-flow-email | 17-VALIDATION.md | COMPLIANT_DRAFT_STATUS | |
| 18-backfill-organizations-generator-wiring | 18-VALIDATION.md | LEGACY_FORMAT | pre-template YAML; content under “Validation Architecture” |
| 19-passkey-schema-contexts | 19-VALIDATION.md | COMPLIANT_DRAFT_STATUS | |
| 20-passkey-challenge-plug-runtime-config-js-hooks-infra | 20-VALIDATION.md | COMPLIANT_DRAFT_STATUS | |
| 21-passkey-liveviews-post-auth-controller | 21-VALIDATION.md | COMPLIANT_DRAFT_STATUS | |
| 22-passkeys-generator-wiring | 22-VALIDATION.md | COMPLIANT_DRAFT_STATUS | |
| 23-docs-ci-smoke-upgrade-guide | 23-VALIDATION.md | COMPLIANT_DRAFT_STATUS | |
| 24-repair-phase-16-17-organizations-generator-templates | 24-VALIDATION.md | COMPLIANT_DRAFT_STATUS | |
| 25-fix-sigra-upgrade-duplicate-migration-version-bug-and-restor | 25-VALIDATION.md | COMPLIANT_DRAFT_STATUS | |
| 26-retroactive-v1-1-verification-closeout | 26-VALIDATION.md | COMPLIANT_DRAFT_STATUS | |
| 27-admin-access-foundation | 27-VALIDATION.md | COMPLIANT_DRAFT_STATUS | |
| 28-user-operations-surface | 28-VALIDATION.md | COMPLIANT_DRAFT_STATUS | |
| 29-secure-impersonation | 29-VALIDATION.md | COMPLIANT_DRAFT_STATUS | |
| 30-audit-exploration-and-export | 30-VALIDATION.md | COMPLIANT_DRAFT_STATUS | |
| 31-automation-first-verification | 31-VALIDATION.md | COMPLIANT_DRAFT_STATUS | |
| 32-generated-installer-admin-surface-parity | 32-VALIDATION.md | COMPLIANT_DRAFT_STATUS | |
| 33-admin-shell-navigation-and-audit-preview-polish | 33-VALIDATION.md | COMPLIANT_APPROVED | retro file added Phase 36 |
| 34-generated-host-e2e-and-phase-28-retroactive-verification | — | REMOVED | empty duplicate dir removed 2026-04-17 (`rmdir`); canonical Phase 34 is `34-generated-host-e2e-coverage-…` |
| 34-generated-host-e2e-coverage-and-phase-28-retroactive-verification | 34-VALIDATION.md | COMPLIANT_DRAFT_STATUS | canonical Phase 34 artifacts |
| 35-shift-left-verification-automation | 35-VALIDATION.md | COMPLIANT_DRAFT_STATUS | |
| 36-retroactive-nyquist-validation | 36-VALIDATION.md | COMPLIANT_DRAFT_STATUS | this phase |
| 999.1-nyquist-retroactive-validation-pass | 999.1-VALIDATION.md | COMPLIANT_APPROVED | pointer-only supersession file |
| 999.2-dependabot-major-version-bumps | 999.2-VALIDATION.md | COMPLIANT_APPROVED | pointer-only supersession file |

<!-- regen_lines: 31 -->
