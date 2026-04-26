# Phase 86 Verification Record

**Phase:** 86 — GAUAT email visual regression harness (Phase 04 + Phase 08 templates)
**Date:** 2026-04-26
**Status:** PASS

## Phase-Close SHA

```
6ce3cd3
```

This is the wave-3 merge-base commit used as the `{short-sha}` suffix for all hero PNGs in both the Phase 04 and Phase 08 evidence bundles. Both plan 86-03 (Phase 04 evidence + CI wiring) and plan 86-04 (Phase 08 evidence) were executed against this base.

## Snapshot Metrics

<!-- snapshot count = 36, contrast min ratio = 4.5, byte budget max = 100000 -->

| Metric | Value |
|--------|-------|
| Snapshot count (total) | 36 |
| Templates | 9 (2 Phase 04 + 7 Phase 08) |
| Engines | 2 (chromium, webkit) |
| Themes | 2 (light, dark) |
| Viewport | 640×1200 |

## Quality Gates

| Gate | Threshold | Outcome |
|------|-----------|---------|
| Contrast min ratio | ≥ 4.5:1 (WCAG AA) | PASS — CTA color `#1d4ed8` = 6.70:1 on white (D-86-07) |
| Byte budget max | ≤ 100,000 bytes per rendered HTML | PASS — all 9 templates under threshold (G2 rubric) |
| Playwright baselines | 36 cells green | PASS — 36 passed in email_visual_regression CI lane |
| caniemail CSS lint | No deny-list violations | PASS — Sigra.Email.CssLint gate green for all templates |

## Evidence Locations

### Phase 04 — GAUAT-01 (security templates)

| File | Description |
|------|-------------|
| `.planning/uat-evidence/v1.20/email-phase-04/README.md` | Human-readable evidence pointer with YAML frontmatter |
| `.planning/uat-evidence/v1.20/email-phase-04/manifest.json` | Machine-readable per-cell evidence rows |
| `.planning/uat-evidence/v1.20/email-phase-04/reports/contrast-summary.json` | Contrast gate summary per template |
| `.planning/uat-evidence/v1.20/email-phase-04/reports/byte-budget.csv` | Byte-budget per cell |
| `.planning/uat-evidence/v1.20/email-phase-04/snapshots/lockout-notification__chromium__light__sha-6ce3cd3.png` | Hero PNG |
| `.planning/uat-evidence/v1.20/email-phase-04/snapshots/lockout-notification__chromium__dark__sha-6ce3cd3.png` | Hero PNG |
| `.planning/uat-evidence/v1.20/email-phase-04/snapshots/lockout-notification__webkit__light__sha-6ce3cd3.png` | Hero PNG |
| `.planning/uat-evidence/v1.20/email-phase-04/snapshots/lockout-notification__webkit__dark__sha-6ce3cd3.png` | Hero PNG |
| `.planning/uat-evidence/v1.20/email-phase-04/snapshots/suspicious-login__chromium__light__sha-6ce3cd3.png` | Hero PNG |
| `.planning/uat-evidence/v1.20/email-phase-04/snapshots/suspicious-login__chromium__dark__sha-6ce3cd3.png` | Hero PNG |
| `.planning/uat-evidence/v1.20/email-phase-04/snapshots/suspicious-login__webkit__light__sha-6ce3cd3.png` | Hero PNG |
| `.planning/uat-evidence/v1.20/email-phase-04/snapshots/suspicious-login__webkit__dark__sha-6ce3cd3.png` | Hero PNG |

### Phase 08 — GAUAT-02 (lifecycle templates)

| File | Description |
|------|-------------|
| `.planning/uat-evidence/v1.20/email-phase-08/README.md` | Human-readable evidence pointer with YAML frontmatter |
| `.planning/uat-evidence/v1.20/email-phase-08/manifest.json` | Machine-readable per-cell evidence rows (28 cells) |
| `.planning/uat-evidence/v1.20/email-phase-08/reports/contrast-summary.json` | Contrast gate summary per template |
| `.planning/uat-evidence/v1.20/email-phase-08/reports/byte-budget.csv` | Byte-budget per cell |
| `.planning/uat-evidence/v1.20/email-phase-08/snapshots/` | 28 hero PNGs (7 templates × 2 engines × 2 themes, `__sha-6ce3cd3.png` suffix) |

## CI Lane

**Job:** `email_visual_regression`
**Workflow:** `.github/workflows/ci.yml`
**Run URL:** `https://github.com/szTheory/sigra/actions` (populated by `SIGRA_CI_RUN_URL` env var per run)
**Release asset:** `sigra-email-visual-regression-v1.20.0.tar.gz` (promoted on `refs/tags/v1.20.0` via `gh release upload`)

## GAUAT-01 Attestation

**Requirement:** GAUAT-01 — Phase 04 lockout + suspicious-login automated visual regression and evidence.

**Status: PASS**

Evidence:
- 8 hero PNGs committed at `.planning/uat-evidence/v1.20/email-phase-04/snapshots/` with `__sha-6ce3cd3.png` naming per D-86-06
- `manifest.json` with per-cell SHA-256, byte size, git SHA, contrast min ratio, byte budget max
- `README.md` with YAML frontmatter including `phase`, `gauat_requirement: GAUAT-01`, `hex_version`, `git_sha`, `git_tag`, `ci_run_url`, `ci_workflow`, `generated_by`, `generated_at`, `disposition: pass`
- `reports/contrast-summary.json` and `reports/byte-budget.csv` generated from same source data
- Playwright baseline grid: 2 templates × 2 engines × 2 themes = 8 cells green

## GAUAT-02 Attestation

**Requirement:** GAUAT-02 — Phase 08 lifecycle-template automated visual regression and evidence.

**Status: PASS**

Evidence:
- 28 hero PNGs committed at `.planning/uat-evidence/v1.20/email-phase-08/snapshots/` with `__sha-6ce3cd3.png` naming per D-86-06
- `manifest.json` with per-cell SHA-256, byte size, git SHA, contrast min ratio, byte budget max
- `README.md` with YAML frontmatter including `phase`, `gauat_requirement: GAUAT-02`, `hex_version`, `git_sha`, `git_tag`, `ci_run_url`, `ci_workflow`, `generated_by`, `generated_at`, `disposition: pass`
- `reports/contrast-summary.json` and `reports/byte-budget.csv` generated from same source data
- Playwright baseline grid: 7 templates × 2 engines × 2 themes = 28 cells green

## Residual Statement

The following items are explicitly outside the scope of CI-automated evidence and documented as residual-only per D-86-09:

1. **Legacy Outlook desktop Word engine** — Microsoft announced EOL October 2026. Outlook desktop switches to the Edge WebView2 rendering engine after EOL. The caniemail deny-list (`Sigra.Email.CssLint`) catches the CSS patterns that fail in the Word engine today, but pixel-level rendering in the legacy engine is not CI-testable without a Windows VM + licensed Outlook binary.

2. **Subjective copy tone** — Whether email copy reads as "appropriately professional" or "appropriately urgent" is a human judgment call not reducible to a CI assertion. Grammar and structure are covered by the ExUnit G3/G4/G5 rubric (URL parity, recipient correctness, XSS escaping).

3. **Spam-folder placement / deliverability** — Email deliverability is infrastructure- and domain-reputation-dependent. It is not a rendering concern and cannot be simulated in CI without a live sending infrastructure and inbox monitoring service.

These residuals are documented in `docs/uat-ci-coverage.md` SEED-1/2 and do not constitute waivers of the CI-automated evidence claims above.
