---
phase: 261-tokens-type-logo-favicon-and-contrast
plan: 09
subsystem: ui
tags: [playwright, accessibility, favicon, css, contrast]

requires:
  - phase: 261-08
    provides: Booted example app at port 4011 and admin theme test setup
provides:
  - Real-DOM logo clearance and favicon contract checks in the existing admin theme spec
  - Tasklane host table header contrast correction using its existing muted token
affects: [261-10, 261-11, admin-ui, brand]

actuals:
  tokens: 4606
  tasks: 3
  commits: 3
commits: 3
plan_head_before: 6b092d2d2af53e1a2da4435131b16b4f2b2ef371
plan_head_after: 6c0205094cabff892be82c91292c66967cae53cd

tech-stack:
  added: []
  patterns:
    - Render favicon response bytes in an in-memory browser canvas for pixel assertions
    - Scope host table overrides beneath the Tasklane application root

key-files:
  created: []
  modified:
    - test/example/priv/playwright/tests/admin-theme.spec.ts
    - test/example/priv/static/assets/css/app.css

key-decisions:
  - "Use the existing Tasklane muted token for generic table headings after axe measured 4.47:1."
  - "Render the unchanged root favicon as PNG because its .ico URL serves PNG bytes."

requirements-completed: [BTOK-04, BTOK-05]
coverage:
  - id: D1
    description: Lockup width, clear space, transform, and topbar geometry are checked in Light and Dark.
    requirement: BTOK-04
    verification:
      - kind: automated_ui
        ref: "admin-theme.spec.ts#lockup keeps 2T clear space at 96px minimum in Light and Dark"
        status: pass
      - kind: automated_ui
        ref: "Plan 09 full PR-path browser sweep, admin-behavior Chromium group"
        status: pass
    human_judgment: false
  - id: D2
    description: Favicon link ownership, byte identity, 16/32 pixel grids, and retired-mark distinction are checked in the browser.
    requirement: BTOK-05
    verification:
      - kind: automated_ui
        ref: "admin-theme.spec.ts#favicon links render on Sigra-owned pages only"
        status: pass
      - kind: automated_ui
        ref: "admin-theme.spec.ts#favicon assets are the book bytes and root favicon stays unchanged"
        status: pass
      - kind: automated_ui
        ref: "admin-theme.spec.ts#favicon renders pixel-exact at 16px and 32px and is distinct from the retired mark"
        status: pass
    human_judgment: false
  - id: D3
    description: Tasklane generic table headings pass the contrast gate on the real page.
    verification:
      - kind: automated_ui
        ref: "Plan 09 full PR-path browser sweep, admin-checkpoints three-project group"
        status: pass
    human_judgment: false

duration: 49min
completed: 2026-11-16
status: complete
---

# Phase 261 Plan 09: Tokens, Type, Logo, Favicon and Contrast Summary

**Real-browser geometry and favicon proofs, plus a scoped Tasklane table-header contrast fix.**

## Performance

- **Duration:** 49 min
- **Started:** 2026-11-16T15:11:10Z
- **Completed:** 2026-11-16T16:00:14Z
- **Tasks:** 3
- **Files modified:** 2

## Accomplishments

- Added the real-DOM lockup geometry test for Light and Dark, plus three favicon scope, identity, and pixel-render tests to the existing `admin-theme.spec.ts`.
- Measured the 96px lockup at `T = 6.2465px`; in both themes, the Admin label gap was 16px, top gap 12.5318px, bottom gap 13.5318px, left gap 32px, transform `none`, and topbar height 65px.
- Verified exact 16px and 32px ICO and fixed-light-SVG grids (48 and 200 ink pixels respectively); the responsive favicon SVG was exact at 32px and retained its required 16px bounds and nonblank rendering.
- Corrected the generic Tasklane table-header cascade with a narrow `.vt-app-main` override using `--vt-color-muted`; the live foreground/background ratio became 5.2544:1.
- Passed the complete PR-path browser sweep after the CSS correction, with `SIGRA_PNG_COMPARE_SKIP=1`; no snapshot was updated or recaptured.

## Task Commits

1. **Task 1: Tracer, lockup geometry in Light and Dark from the real DOM** - `28dc80519` (test)
2. **Task 2: Favicon link scope, asset identity and the 16/32 pixel render check** - `c3320d33c` (test)
3. **Task 3: Run geometry and favicon checks, then the full PR-path browser sweep** - `6c0205094` (fix)

## Files Created/Modified

- `test/example/priv/playwright/tests/admin-theme.spec.ts` - Four browser tests for logo geometry and favicon ownership, bytes, and rendered pixels. The root `/favicon.ico` response remains unchanged and is decoded as its actual PNG payload.
- `test/example/priv/static/assets/css/app.css` - Scoped generic host-table heading color to the existing Tasklane muted token.

## Decisions Made

- Kept Sigra's admin tokens and canary unchanged; the contrast correction applies only to generic `.table` headers under the Tasklane host app.
- Used the exact bytes returned by the legacy root favicon route for distinctness checks; the `.ico` path currently contains a PNG payload.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Corrected the generic Tasklane table-header contrast cascade**
- **Found during:** Task 3 (full PR-path browser sweep)
- **Issue:** DaisyUI's generic `.table :where(thead, tfoot)` rule applied a 60%-opacity base-content color to `OrganizationMembersLive`. On the Paper background, the impersonation-banner axe canary reported a 4.47:1 contrast ratio, just below 4.5:1.
- **Fix:** Added `.vt-app-main .table :where(thead, tfoot) { color: var(--vt-color-muted); }` to the example app stylesheet. A live browser probe measured 5.2544:1 after the fix.
- **Files modified:** `test/example/priv/static/assets/css/app.css`
- **Verification:** Re-ran the full sweep from the beginning; all groups passed. The impersonation canary and axe rules were unchanged.
- **Committed in:** `6c0205094`

**Total deviations:** 1 auto-fixed bug. The contrast fix was necessary to pass the existing accessibility gate and stayed within Task 3's allowed example CSS scope.

## Verification

- Focused geometry and favicon browser run: **4 passed**.
- Full sweep from its first group after the fix: admin-behavior Chromium **50 passed**; admin-checkpoints **3 passed**; untagged admin-design **45 passed**; demo-showcase **4 passed**; admin-eval **192 passed**.
- Final Playwright listing: **404 tests in 22 files**.
- Template/example admin stylesheet parity check passed; no snapshot artifacts or `.github` / spec ownership files changed.
- The app ran at port 4011 for browser verification and was stopped after the full sweep passed.

## Issues Encountered

- The existing `/favicon.ico` route returns PNG bytes despite its extension. The test now verifies the unchanged response and renders those bytes as PNG; no favicon asset was changed.
- The first full sweep exposed the 4.47:1 host-table issue. After the scoped correction, the full sweep passed from the beginning.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Plan 09's automated geometry, favicon, and contrast checks are complete. The planned end-of-phase contact sheet remains for its later Phase 261 step.

---
*Phase: 261-tokens-type-logo-favicon-and-contrast*
*Completed: 2026-11-16*

## Self-Check: PASSED

- Summary file exists.
- Task commits `28dc80519`, `c3320d33c`, and `6c0205094` are ancestors of HEAD.
- The committed Plan 09 diff passes `git diff --check`; the summary contains no home paths, personal emails, or stub markers.
