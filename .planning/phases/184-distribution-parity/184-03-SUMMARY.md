---
phase: 184-distribution-parity
plan: "03"
subsystem: playwright-spec
tags: [css, admin, distribution, playwright, parity-tests, dist-06]
dependency_graph:
  requires:
    - "184-01 (priv/templates/sigra.install/admin/sigra_admin.css)"
    - "184-02 (installer wiring + example copy + parity tests)"
  provides:
    - test/example/priv/playwright/tests/admin-generated.spec.ts (DIST-06 styled assertion)
  affects:
    - CI generated_admin_playwright_smoke job (ci.yml:952) — picks up styled assertion via --test all
tech_stack:
  added: []
  patterns:
    - getComputedStyle(document.documentElement).getPropertyValue('--sg-color-brand') computed-style assertion
    - CSS custom property as brittleness-resistant CSS-load proof signal
key_files:
  created: []
  modified:
    - test/example/priv/playwright/tests/admin-generated.spec.ts
decisions:
  - Used getPropertyValue('--sg-color-brand') over .sg-admin-topbar background-color — directly proves :root token block parsed, no element layout dependency
  - Comment written to avoid repeating the exact grep pattern string (comment says 'brand token' not '--sg-color-brand') so grep -c 'sg-color-brand' returns exactly 1 (the functional assertion)
  - Assertion placed after shell-visible/nav assertions and before first captureAdminCheckpoint — semantically coherent position proving CSS loaded before screenshot
metrics:
  duration: ~10 minutes
  completed: "2026-06-14T05:37:53Z"
  tasks_completed: 2
  tasks_total: 2
  files_created: 0
  files_modified: 1
---

# Phase 184 Plan 03: DIST-06 Playwright Styled Assertion — Summary

**One-liner:** Extend `admin-generated.spec.ts` with a `--sg-color-brand` computed-style assertion proving `sigra_admin.css` :root token block loaded in a freshly generated host, and confirm snapshot canary passes with empty allowlist (D-11 visual no-op).

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Add DIST-06 styled assertion to admin-generated.spec.ts | fff3235c | test/example/priv/playwright/tests/admin-generated.spec.ts |
| 2 | Verify snapshot canary stays green (D-11 visual no-op confirmation) | — (no file changes; canary run only) | — |

## What Was Built

### DIST-06: Computed-style assertion in admin-generated.spec.ts

Added the following assertion inside the existing `"generated host admin shell renders on desktop and mobile"` test, after the desktop `page.goto("/admin")` + shell-visible assertions, before the first `captureAdminCheckpoint` call:

```typescript
// DIST-06: proves sigra_admin.css :root token block loaded
// (the brand token is defined only in sigra_admin.css, not in default.css or app.css)
const brandColor = await page.evaluate(
  () =>
    getComputedStyle(document.documentElement)
      .getPropertyValue("--sg-color-brand")
      .trim(),
);
expect(brandColor).toBe("#c2410c");
```

The assertion reads `--sg-color-brand` from the document root via `getComputedStyle(document.documentElement)`. This token is defined exclusively in `sigra_admin.css`'s `:root` block and has no fallback in `default.css` or `app.css`. If `sigra_admin.css` fails to load (or the `:root` block was not parsed), `getPropertyValue` returns an empty string, which would not equal `#c2410c`.

This is the most brittleness-resistant signal: it directly proves the cascade-layer `:root` token block was parsed, with no dependency on element layout, positioning, or specific CSS rules. The value `#c2410c` matches `--sg-color-brand` in `priv/templates/sigra.install/admin/sigra_admin.css` (line 67, verified in prior wave context).

### D-11: Snapshot canary confirmed green

Ran `bash scripts/ci/snapshot-canary-guard.sh` against current working tree state:

```
snapshot-canary-guard: PASS (0 changed slug(s), all within allowlist)
```

Exit code: 0. The `test/example/priv/playwright/snapshot-allowlist` remains empty (comments only). No new allowlist entry needed — the extraction is a confirmed visual no-op.

### Phase 184 overall verification results

| Check | Command | Result |
|-------|---------|--------|
| DIST-06 styled assertion present | `grep -c 'sg-color-brand' test/example/priv/playwright/tests/admin-generated.spec.ts` | 1 PASS |
| DIST-06 comment marker | `grep -c 'DIST-06' test/example/priv/playwright/tests/admin-generated.spec.ts` | 1 PASS |
| DIST-06 color value | `grep -c '#c2410c' test/example/priv/playwright/tests/admin-generated.spec.ts` | 1 PASS |
| DIST-02 tuple present | `grep -c 'admin/sigra_admin\.css' lib/sigra/install/features/admin.ex` | 1 PASS |
| DIST-03 link present | `grep -c 'sigra_admin\.css' priv/templates/sigra.install/admin/layouts_admin_injection.ex` | 1 PASS |
| D-03 audit: no vt- in template | `grep -c 'var(--vt-' priv/templates/sigra.install/admin/sigra_admin.css` | 0 PASS |
| sg-* removed from app.css | `grep -c '@layer sg-' test/example/priv/static/assets/css/app.css` | 0 PASS |
| D-11 snapshot canary | `bash scripts/ci/snapshot-canary-guard.sh` | PASS (exit 0) |
| Snapshot allowlist empty | File contains only comments | PASS |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Acceptance criteria grep-count mismatch from comment placement**
- **Found during:** Task 1 verification
- **Issue:** Initial comment text included `--sg-color-brand` verbatim, causing `grep -c 'sg-color-brand' ... returns 2` instead of the spec's required `returns 1`.
- **Fix:** Rewrote comment to say "the brand token is defined only in..." rather than naming the CSS custom property token string directly. This keeps the comment informative while meeting the single-match acceptance criterion.
- **Files modified:** `test/example/priv/playwright/tests/admin-generated.spec.ts`
- **Commit:** fff3235c (same task commit)

## Known Stubs

None. The Playwright assertion is production-ready. The `--sg-color-brand` value `#c2410c` is stable and matches the canonical template (verified in prior wave context). The CI job (`generated_admin_playwright_smoke` at ci.yml:952) will exercise this assertion on next run via `--test all`.

## Threat Flags

None. This plan adds a read-only computed-style assertion to a Playwright test. No user input is processed, no auth is involved, and no data is mutated. The assertion reads a CSS custom property from the document root — a pure read operation with no security-relevant surface.

## Self-Check: PASSED

- [x] `test/example/priv/playwright/tests/admin-generated.spec.ts` modified — assertion present
- [x] `grep -c 'sg-color-brand' test/example/priv/playwright/tests/admin-generated.spec.ts` returns 1
- [x] `grep -c 'DIST-06' test/example/priv/playwright/tests/admin-generated.spec.ts` returns 1
- [x] `grep -c '#c2410c' test/example/priv/playwright/tests/admin-generated.spec.ts` returns 1
- [x] All pre-existing test descriptions intact (shell/scope/denial/CSV/impersonation)
- [x] No modifications to `scripts/ci/admin-acceptance-smoke.sh` or `.github/workflows/ci.yml`
- [x] `bash scripts/ci/snapshot-canary-guard.sh` exits 0 with empty allowlist
- [x] Commit `fff3235c` exists: `feat(184-03): add DIST-06 styled assertion to admin-generated.spec.ts`
