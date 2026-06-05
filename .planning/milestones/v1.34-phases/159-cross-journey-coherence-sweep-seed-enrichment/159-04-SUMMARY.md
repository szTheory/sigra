---
phase: 159-cross-journey-coherence-sweep-seed-enrichment
plan: "04"
subsystem: admin-ui / playwright
tags:
  - css-motion
  - playwright
  - gate-03
  - coherence-sweep
  - accessibility
dependency_graph:
  requires:
    - 159-03  # seed enrichment (FIXT-01/02/03 seeded demo DB)
  provides:
    - GATE-03 keyboard motion check implementation
    - admin-coherence-sweep.spec.ts filmstrip spec
  affects:
    - test/example/priv/static/assets/css/app.css
    - test/example/priv/playwright/tests/admin-coherence-sweep.spec.ts
tech_stack:
  added: []
  patterns:
    - "@media (hover: hover) and (pointer: fine) scoping for CSS transitions"
    - "Behavior-only Playwright spec (no toHaveScreenshot) for DOM contract assertions"
key_files:
  created:
    - test/example/priv/playwright/tests/admin-coherence-sweep.spec.ts
  modified:
    - test/example/priv/static/assets/css/app.css
decisions:
  - "GATE-03 keyboard motion fix is a 3-line CSS change: remove unconditional transition from .sg-filter-chip, add it inside existing @media (hover: hover) and (pointer: fine) guard"
  - "Spec uses openUserDetail helper (copied from admin-checkpoints.spec.ts) to navigate to user audit via registered admin email — avoids hard-coded user IDs"
  - "No playwright.config.ts changes needed: admin-coherence-sweep.spec.ts filename does not match ADMIN_CHECKPOINTS_SPEC regex"
metrics:
  duration: "~8 minutes"
  completed: "2026-06-04"
  tasks_completed: 2
  tasks_total: 2
---

# Phase 159 Plan 04: CSS Motion Fix + Coherence Sweep Spec Summary

CSS motion scoped to pointer:fine devices (D-06/GATE-03) and new behavior-only Playwright filmstrip spec asserting the coherence contract across all 6 admin screens (D-07).

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Scope sg-filter-chip transition to pointer:fine | 1364d173 | test/example/priv/static/assets/css/app.css |
| 2 | Create admin-coherence-sweep.spec.ts | 82234969 | test/example/priv/playwright/tests/admin-coherence-sweep.spec.ts |

## What Was Built

### Task 1: CSS Motion Fix (D-06 GATE-03)

Scoped the `.sg-filter-chip` CSS transition to `@media (hover: hover) and (pointer: fine)` devices. This is a 3-line net change (remove 1, add 3):

- Removed `transition: var(--sg-transition-tone), var(--sg-transition-press);` from the unconditional `.sg-filter-chip {}` block
- Added a new `.sg-filter-chip { transition: ... }` rule nested inside the existing `@media (hover: hover) and (pointer: fine)` guard, before the existing `:hover` rule
- Mouse users (pointer:fine) retain press/tone transitions
- Keyboard and touch users see no chip animation — satisfies GATE-03's keyboard-frequent contract

No other `.sg-filter-chip` rules were changed (color, padding, min-height, border-radius, `:checked`, dark mode overrides all unchanged).

### Task 2: admin-coherence-sweep.spec.ts (D-07)

New Playwright spec at `test/example/priv/playwright/tests/admin-coherence-sweep.spec.ts` asserting the Phase 159 coherence contract:

**6 screens covered:**
1. Global overview (`/admin`) — `.sg-notice` visible
2. Org overview (`/admin/organizations/acme-corp`) — `.sg-scope-ribbon` + Expired pill (FIXT-01) + Deletion scheduled pill (FIXT-02)
3. Users index (`/admin/users` + `?q=pat%40demo.sigra.dev`) — `.sg-scope-ribbon` + Passkeys pill (FIXT-03)
4. User audit (`/admin/users/:id/audit`) — `.sg-scope-ribbon` + page_back link
5. Audit explorer (`/admin/audit`) — `.sg-scope-ribbon`
6. Org roster (`/admin/organizations/acme-corp/users`) — `.sg-scope-ribbon`

**GATE-03 keyboard motion check:**
After the D-06 CSS fix, the filter chip's computed transition is read via `getComputedStyle(el).transition`. In Playwright's Chromium headless environment (non-pointer:fine), the `@media (hover: hover) and (pointer: fine)` guard suppresses the transition. The assertion `expect(transition).not.toContain('transform')` confirms no transform animation fires for keyboard users.

**Constraints satisfied:**
- Zero `toHaveScreenshot()` calls
- `test.describe('Phase 159 coherence sweep', ...)` for traceability
- Seeded-DB dependency documented in comments near each pill assertion
- No `playwright.config.ts` changes required

## Deviations from Plan

None — plan executed exactly as written.

## Threat Flags

None. Both changes are purely presentational/test scope — no new auth surface, no network endpoints, no schema changes.

## Self-Check: PASSED

Files created/modified:
- FOUND: test/example/priv/static/assets/css/app.css (modified)
- FOUND: test/example/priv/playwright/tests/admin-coherence-sweep.spec.ts (created)

Commits:
- FOUND: 1364d173 (fix: scope sg-filter-chip transition)
- FOUND: 82234969 (feat: add admin-coherence-sweep.spec.ts)
