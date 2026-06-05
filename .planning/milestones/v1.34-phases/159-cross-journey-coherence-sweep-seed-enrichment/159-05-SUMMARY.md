---
phase: 159-cross-journey-coherence-sweep-seed-enrichment
plan: 05
subsystem: ui
tags: [admin, playwright, liveview, coherence, scope_ribbon, NaiveDateTime, seeds]

requires:
  - phase: 159-cross-journey-coherence-sweep-seed-enrichment
    provides: Phase 159 coherence sweep spec and admin live views

provides:
  - sg-scope-ribbon stable hook class on scope_ribbon/1 component
  - OrganizationLive scope ribbon call with scope_copy/1 helper
  - Discriminating GATE-03 motion check (static CSS source read)
  - NaiveDateTime guard in shape_invitation_row/2
  - Transaction result propagation in insert_audit_batch/3

affects:
  - Phase 160 pixel baselines
  - Admin UI coherence milestone verification

tech-stack:
  added: []
  patterns:
    - "sg-scope-ribbon stable hook class on all scope_ribbon renders (D-07)"
    - "Static CSS source read in Playwright specs for discriminating CSS guard assertions"
    - "normalize_to_datetime/1 pattern for mixed DateTime/NaiveDateTime fields"

key-files:
  created: []
  modified:
    - lib/sigra/admin/components.ex
    - lib/sigra/admin/live/organization_live.ex
    - lib/sigra/admin/organizations/detail.ex
    - test/example/lib/example/demo/seeds.ex
    - test/example/priv/playwright/tests/admin-coherence-sweep.spec.ts
    - test/sigra/admin/components_test.exs

key-decisions:
  - "GATE-03 discriminating check uses static CSS source read (fs.readFileSync) not runtime computed-style; static is environment-independent and fails if @media guard is removed"
  - "Chromium headless exposes pointer:fine — the @media guard IS active in headless; runtime assertion updated to assert transition is non-empty (guard wired) not absent"
  - "users_path/1 and audit_path/1 nil-slug catch-all deferred — misconfigured-routing edge case only; tracked for future phase"
  - "format_date/1 catch-all deferred — behavioral break risk; INFO severity; tracked for CLAUDE.md convention pass"

patterns-established:
  - "scope_copy/1 private helper on org-scoped LiveViews: 3 clauses covering name, slug fallback, catch-all"

requirements-completed: [GATE-03]

duration: 7min
completed: 2026-06-05
---

# Phase 159 Plan 05: Gap Closure (GATE-03 coherence spec + WR-01/02/04) Summary

**GATE-03 closed: sg-scope-ribbon class added to scope_ribbon/1, OrganizationLive wired, discriminating static CSS assertion replaces tautological check, NaiveDateTime crash and silent transaction discard fixed; coherence filmstrip passes 1/1**

## Performance

- **Duration:** 7 min
- **Started:** 2026-06-05T00:55:55Z
- **Completed:** 2026-06-05T01:03:09Z
- **Tasks:** 4
- **Files modified:** 6 (+ 1 golden snapshot test)

## Accomplishments

- `scope_ribbon/1` now emits `sg-scope-ribbon sg-muted sg-text-sm` — all 5 `.toBeVisible()` assertions that target `.sg-scope-ribbon` can now locate the element
- `OrganizationLive` (Screen 2) now renders `<.scope_ribbon copy={scope_copy(@admin_scope)} />` immediately after `</header>`, with a 3-clause `scope_copy/1` helper
- GATE-03 replaced with two-phase discriminating check: static CSS source read asserts transition lives inside `@media (hover: hover) and (pointer: fine)` guard only; removing the guard causes Phase 1a to catch `transition` in the unconditional block and fail
- `shape_invitation_row/2` in detail.ex no longer raises `ArgumentError` when `expires_at` is a `NaiveDateTime` — `normalize_to_datetime/1` helper handles both types
- `insert_audit_batch/3` in seeds.ex now propagates `Repo.transaction` failure via `raise` on `{:error, reason}` instead of silently discarding the result
- Playwright coherence filmstrip: **1 passed, 0 failed** (exit code 0)

## Task Commits

Each task was committed atomically:

1. **Task 1: Fix scope_ribbon class + add OrganizationLive ribbon call** - `8ed3ddce` (feat)
2. **Task 2: Make GATE-03 motion check discriminating (WR-02)** - `81694789` (feat)
3. **Task 3: Fix WR-01 (NaiveDateTime guard) and WR-04 (transaction result discard)** - `65f7ce15` (fix)
4. **Task 4: Run coherence sweep Playwright spec autonomously** - `31e05f89` (feat)

## Files Created/Modified

- `lib/sigra/admin/components.ex` — `sg-scope-ribbon` prepended to scope_ribbon/1 class list; doc updated
- `lib/sigra/admin/live/organization_live.ex` — `<.scope_ribbon copy={scope_copy(@admin_scope)} />` after `</header>`; 3-clause `scope_copy/1` added below `organization_name/1`
- `lib/sigra/admin/organizations/detail.ex` — `normalize_to_datetime/1` helper + call in `shape_invitation_row/2`
- `test/example/lib/example/demo/seeds.ex` — `insert_audit_batch/3` now matches `{:ok,_}/{:error,reason}` and raises on failure
- `test/example/priv/playwright/tests/admin-coherence-sweep.spec.ts` — GATE-03 two-phase check; `readFileSync`/`path` imports; locator fixes (`.first()` on Passkeys pill, "View full audit" link navigation)
- `test/sigra/admin/components_test.exs` — `@scope_ribbon_golden` updated to include `sg-scope-ribbon` class

## Decisions Made

- **GATE-03 discriminating mechanism:** Static CSS source read (`fs.readFileSync`) is the discriminating check. If the `@media (hover: hover) and (pointer: fine)` guard is removed from `app.css` and the transition moved to the unconditional `.sg-filter-chip` block, Phase 1a assertion `expect(unconditionalBlock).not.toMatch(/transition/)` will fail. This is environment-independent and does not depend on browser media feature emulation.
- **Chromium headless pointer:fine behavior:** Chromium headless DOES expose `pointer:fine` — the `@media` guard IS active in headless. The original plan assumed headless would NOT match `pointer:fine`. The runtime Phase 2 assertion was updated to assert `transition.length > 0` (transition is populated/wired) rather than asserting it is absent. The static assertions remain the discriminating check.
- **Deferrals documented below** (users_path/1 nil-slug catch-all, format_date/1 catch-all).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Updated scope_ribbon_golden test snapshot**
- **Found during:** Task 3 (compile/test verification)
- **Issue:** `components_test.exs` had a golden snapshot asserting the old HTML `<span class="sg-muted sg-text-sm ">` — failed after Task 1 added `sg-scope-ribbon` to the class list
- **Fix:** Updated `@scope_ribbon_golden` to `<span class="sg-scope-ribbon sg-muted sg-text-sm ">`
- **Files modified:** `test/sigra/admin/components_test.exs`
- **Verification:** 74 admin tests pass
- **Committed in:** `65f7ce15` (Task 3 commit)

**2. [Rule 1 - Bug] Fixed strict-mode Passkeys pill locator**
- **Found during:** Task 4 (Playwright run)
- **Issue:** `page.locator('.sg-status-pill[data-tone="ok"]').filter({ hasText: 'Passkeys' })` resolved to 2 elements (desktop + mobile result rows) — Playwright strict mode throws on multi-match with `toBeVisible()`
- **Fix:** Added `.first()` to make the locator non-strict
- **Files modified:** `test/example/priv/playwright/tests/admin-coherence-sweep.spec.ts`
- **Verification:** No strict mode violation on Passkeys pill assertion
- **Committed in:** `31e05f89` (Task 4 commit)

**3. [Rule 1 - Bug] Fixed audit navigation to per-user audit page**
- **Found during:** Task 4 (Playwright run)
- **Issue:** `getByRole('link', { name: /audit/i }).first()` clicked the global nav "Audit" link (navigating to `/admin/audit`) instead of the per-user "View full audit" link (navigating to `/admin/users/:id/audit`)
- **Fix:** Changed to `getByRole('link', { name: /view full audit/i })` which uniquely matches the per-user audit link on the detail page
- **Files modified:** `test/example/priv/playwright/tests/admin-coherence-sweep.spec.ts`
- **Verification:** URL assertion `toHaveURL(/\/admin\/users\/[^?]+\/audit/)` passes
- **Committed in:** `31e05f89` (Task 4 commit)

**4. [Rule 1 - Bug] Fixed incorrect GATE-03 runtime assertion premise**
- **Found during:** Task 4 (Playwright run)
- **Issue:** Plan assumed Chromium headless does NOT match `pointer:fine` so transition would be suppressed; actual behavior is Chromium headless DOES expose `pointer:fine` — the `@media` guard IS active, so `getComputedStyle(chip).transition` contains `transform`. The assertion `not.toContain('transform')` always fails in Chromium headless.
- **Fix:** Updated runtime assertion to `expect(transition.length).toBeGreaterThan(0)` — asserts the transition is wired up (guard is active, CSS variables resolve correctly). Discriminating guarantee comes from the static Phase 1 assertions, not the runtime check.
- **Files modified:** `test/example/priv/playwright/tests/admin-coherence-sweep.spec.ts`
- **Verification:** Playwright exits code 0, 1 passed
- **Committed in:** `31e05f89` (Task 4 commit)

---

**Total deviations:** 4 auto-fixed (all Rule 1 bugs)
**Impact on plan:** All auto-fixes necessary for spec correctness. No scope creep. Static GATE-03 assertions are fully discriminating as planned.

## Deferred Items

1. **`users_path/1` and `audit_path/1` nil-slug catch-all** (`organization_live.ex` lines ~200-204) — only crashes on misconfigured nil-slug routing (host app misconfiguration); deferred to a targeted fix in a future phase to keep this plan focused on GATE-03 closure.
2. **`format_date/1` silent catch-all** (`organization_live.ex` line ~194) — current 4-clause pattern has `defp format_date(_), do: "—"`; changing to raise would be a behavioral break for host apps passing unexpected types; marked INFO severity by verifier; deferred to CLAUDE.md convention enforcement pass.

## Playwright Run Result

- **Command:** `SIGRA_EXAMPLE_URL=http://localhost:4011 npx playwright test tests/admin-coherence-sweep.spec.ts --project=chromium`
- **Result:** 1 passed, 0 failed
- **Exit code:** 0
- **Screens verified:** All 6 (global overview notice, org overview ribbon + pills, users index ribbon + passkeys pill, user audit ribbon + back link, audit explorer ribbon, org roster ribbon)

## GATE-03 Discriminating Check Confirmation

The GATE-03 check is now discriminating:

**Phase 1a (discriminating):** Reads `test/example/priv/static/assets/css/app.css` as text, extracts the first `.sg-filter-chip { ... }` unconditional block, asserts it does NOT match `/transition/`. If someone removes the `@media (hover: hover) and (pointer: fine)` guard and moves the `transition` rule into the unconditional block, this assertion fails.

**Phase 1b (presence):** Finds the `@media (hover: hover) and (pointer: fine)` block, asserts it contains `.sg-filter-chip` and `transition`. Confirms the guard is present and the rule is wired.

**Phase 2 (wiring):** Runtime `getComputedStyle(chip).transition` in Chromium headless (which matches `pointer:fine`) asserts the transition string is non-empty — confirms CSS variables resolve and the rule is active.

## Issues Encountered

- `mix phx.compile` task does not exist in this project — used `mix compile` instead (equivalent for pre-compilation)
- Server started via background process; polled port 4011 until listening (ready in ~3s)

## Next Phase Readiness

- GATE-03 is now discriminating; Phase 159 re-verification should score 6/6
- Phase 160 pixel baselines can proceed against a server with `sg-scope-ribbon` class present on all screens

---
*Phase: 159-cross-journey-coherence-sweep-seed-enrichment*
*Completed: 2026-06-05*
