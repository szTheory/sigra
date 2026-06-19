---
phase: 184-distribution-parity
plan: "01"
subsystem: installer-templates
tags: [css, admin, design-system, distribution, extraction]
dependency_graph:
  requires: []
  provides:
    - priv/templates/sigra.install/admin/sigra_admin.css
  affects:
    - Plans 184-02 and 184-03 (depend on this file existing)
tech_stack:
  added: []
  patterns:
    - selective CSS property extraction (skip interleaved --vt-* tokens)
    - cascade-layer declaration carried into extracted file
key_files:
  created:
    - priv/templates/sigra.install/admin/sigra_admin.css
  modified: []
decisions:
  - D-03 audit confirmed clean: zero var(--vt-*), zero .vt-*, zero VAULTR references
  - Extraction used selective property copy (not line-range cut) to handle interleaved --vt-* tokens in :root block
  - Trailing --sg-* sizing tokens (--sg-pill-h etc.) after the --vt-* interleaved block were correctly included
  - @layer sg-components carries only the layout primitive selectors (lines 262-349); VAULTR subsection (351+) excluded
metrics:
  duration: ~5 minutes
  completed: "2026-06-14T04:47:02Z"
  tasks_completed: 1
  tasks_total: 1
  files_created: 1
  files_modified: 0
---

# Phase 184 Plan 01: Extract Admin sg-* CSS into Canonical Installer Template — Summary

**One-liner:** Selective extraction of all `sg-*` material from `app.css` into `priv/templates/sigra.install/admin/sigra_admin.css` — 368 lines, 11,012 bytes, zero `vt-*` contamination.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Extract sg-* CSS into canonical installer template | 7a47d175 | priv/templates/sigra.install/admin/sigra_admin.css |

## What Was Built

Created `priv/templates/sigra.install/admin/sigra_admin.css` as the canonical installer template for the Sigra admin design system. This file is extracted from `test/example/priv/static/assets/css/app.css` (3,848 lines / 107,242 bytes) using selective property and rule extraction — not a contiguous line-range cut — to handle the interleaved `--vt-*` tokens in the `:root` block.

### Extraction Boundaries

The following material was extracted (included):

| Section | Source Lines | Content |
|---------|-------------|---------|
| Header comment | 1–13 | Layer-order rationale and architecture note |
| Layer declaration | 15 | `@layer sg-base, sg-components, sg-overrides;` |
| `:root` sg-* tokens | 20–154 | Spacing, type, color, radii, elevation, motion, focus, z-index, layout |
| `:root` sizing tokens | 179–185 | `--sg-pill-h`, `--sg-pill-gap`, `--sg-pill-pad-*`, `--sg-bottom-nav-gap`, `--sg-code-pad-y` |
| `color-scheme: light` | 187 | Inside `:root` |
| Dark-mode sg-* overrides | 190–224 | `@media (prefers-color-scheme: dark) { :root { --sg-* } }` |
| `@layer sg-base` | 249–260 | `html` and `:where(a)` rules |
| `@layer sg-components` | 262–349 | Layout primitives only (`.sg-container`, `.sg-stack`, `.sg-grid`, `.sg-cluster`, `.sg-show-desktop/mobile`, responsive media query) |
| `@layer sg-overrides` | 3791–3824 | Small-screen tweaks for sg-* selectors |
| Reduced-motion block | 3831–3848 | `@media (prefers-reduced-motion: reduce)` |

The following material was intentionally excluded (stays in `app.css`):

| Section | Source Lines | Content |
|---------|-------------|---------|
| `--vt-*` light-mode tokens | 156–177 | Vaultr brand tokens (interleaved in `:root`) |
| `--vt-*` dark-mode tokens | 225–242 | Vaultr dark overrides (interleaved in dark `@media :root`) |
| VAULTR HOST APP subsection | 351–3789 | All `.vt-*` selectors within `@layer sg-components` |

### Key Landmines Navigated

1. **Interleaved vt-* in :root**: The `--vt-*` token block (lines 156–177) sits inside the single `:root {}` block, not in a separate block. Selective property-by-property extraction was used; the trailing `--sg-*` sizing tokens (lines 179–185) that come after the `--vt-*` block were correctly included.

2. **Dark-mode interleaving**: Same interleaving pattern in the `@media (prefers-color-scheme: dark)` block — `--vt-*` dark overrides (lines 225–242) were skipped while all `--sg-*` dark overrides (lines 190–224) were carried over.

3. **VAULTR subsection boundary**: The comment `/* VAULTR HOST APP */` at line 351 marks the start of the excluded section inside `@layer sg-components`. Only lines 262–349 (the layout primitives) were extracted, and the `@layer sg-components {}` block was properly closed before VAULTR content.

4. **prefers-reduced-motion**: The block at lines 3831–3848 is outside all `@layer` blocks at the very end of `app.css`. It was included because it uses `--sg-motion-fast` and targets `.sg-admin-loading-bar`.

## Verification Results

All acceptance criteria verified:

| Check | Command | Result |
|-------|---------|--------|
| Zero var(--vt-*) refs | `grep -c 'var(--vt-'` | 0 PASS |
| Zero .vt-* selectors | `grep -c '\.vt-'` | 0 PASS |
| Zero VAULTR refs | `grep -c 'VAULTR'` | 0 PASS |
| Layer declaration present | `grep -c '@layer sg-base, sg-components, sg-overrides;'` | 1 PASS |
| @layer sg-base present | `grep -c '@layer sg-base'` | 2 PASS |
| @layer sg-components present | `grep -c '@layer sg-components'` | 1 PASS |
| @layer sg-overrides present | `grep -c '@layer sg-overrides'` | 1 PASS |
| prefers-reduced-motion present | `grep -c 'prefers-reduced-motion'` | 2 PASS |
| prefers-color-scheme: dark present | `grep -c 'prefers-color-scheme: dark'` | 1 PASS |
| --sg-pill-h present | `grep -c '\-\-sg-pill-h'` | 1 PASS |
| File exists | `[ -f ...]` | FOUND PASS |

## Deviations from Plan

None — plan executed exactly as written. The task description accurately described the landmines, and all four were navigated correctly in the first attempt.

## Known Stubs

None. The extracted CSS file is a complete, production-ready design system with no placeholder or stub content.

## Threat Flags

None. The extracted file is a static CSS design system with no user input, no secrets, no authentication logic, and no embedded configuration. D-03 audit confirmed zero cross-contamination with vt-* Vaultr brand material.

## Self-Check: PASSED

- [x] `priv/templates/sigra.install/admin/sigra_admin.css` exists (368 lines, 11,012 bytes)
- [x] Commit `7a47d175` exists: `feat(184-01): extract canonical admin sg-* CSS into installer template`
- [x] All 11 acceptance criteria verified with grep/file checks
- [x] No unexpected file deletions in commit
