---
phase: 201
plan: "03"
subsystem: admin-ui
tags:
  - playwright
  - design-contract
  - quality-ledger
  - users-index
  - form-submit
  - tier-2
dependency_graph:
  requires:
    - "201-01 (users_index_live.ex recomposed search-first with GET form + DRY components)"
    - "201-02 (example host-seam non-empty extra_list_badges + extra_list_columns)"
  provides:
    - "form-submit Playwright test for GET-form contract (D-02)"
    - "users-index-live ledger cell ratcheted to bare Tier 2 with proxy evidence (D-09)"
    - "rewritten List Archetype block in admin-design-contract.md (D-12)"
  affects:
    - "admin-design.spec.ts (new test guards GET-form reflow)"
    - "admin-quality-ledger.md (users-index-live now Tier 2)"
    - "admin-design-contract.md (List Archetype documented at elevated composition)"
tech_stack:
  added: []
  patterns:
    - "form-submit Playwright test pattern (fill + waitForURL + click, not ?q= goto)"
    - "Tier-2 ledger Evidence format: inline prose pipe-row, N/A for inapplicable modal proxies"
    - "List Archetype contract: search-first composition with Notes section matching Detail Archetype style"
key_files:
  created: []
  modified:
    - test/example/priv/playwright/tests/admin-design.spec.ts
    - guides/reference/admin-quality-ledger.md
    - guides/reference/admin-design-contract.md
key-decisions:
  - "D-02 guarded by real form submission (fill + waitForURL + click), not ?q= goto — a detached input would fail the waitForURL"
  - "td:nth-child(3)/(4) equivalence selectors confirmed correct after Plan 01 recompose — column order preserved, no selector change needed"
  - "Ledger Evidence expanded inline in the pipe row (mirroring user-show-live exemplar), not as a separate block"
  - "overlay-axe and 7 APG focus-trap/restore gates marked N/A (not fabricated) — Users Index owns no modal dialog"
  - "List Archetype block rewritten to match Phase 200 Detail Archetype style: code block + Notes section, no stale claims"
requirements-completed:
  - INDEX-03
  - INDEX-04
coverage:
  - id: D1
    description: "Playwright test submits the filter form via real GET submission (typed query + Search button click) and asserts filtered result in both desktop and mobile result containers"
    requirement: INDEX-03
    verification:
      - kind: automated_ui
        ref: "test/example/priv/playwright/tests/admin-design.spec.ts#filter form submits via real GET submission and returns filtered results"
        status: pass
    human_judgment: false
  - id: D2
    description: "td:nth-child(3)/(4) frozen equivalence selectors confirmed to target Organizations/Activity after Plan 01 recompose"
    requirement: INDEX-03
    verification:
      - kind: other
        ref: "grep -cF 'td:nth-child(3) span' admin-design.spec.ts returns >=1; grep -cF 'td:nth-child(4) span' returns >=1; users_index_live.ex thead confirms 5-column order User/Status/Organizations/Activity/Action"
        status: pass
    human_judgment: false
  - id: D3
    description: "users-index-live ledger cell ratcheted to bare Tier 2 with applicable proxy evidence; monotonic guard exits 0"
    requirement: INDEX-04
    verification:
      - kind: other
        ref: "awk -F'|' '/users-index-live/ {gsub(/ /,\"\",$4); print $4}' guides/reference/admin-quality-ledger.md returns '2'; bash scripts/ci/quality-ledger-monotonic.sh --base origin/main exits 0"
        status: pass
    human_judgment: false
  - id: D4
    description: "List Archetype block in admin-design-contract.md rewritten to search-first elevated composition with DRY note and stale claims removed"
    requirement: INDEX-04
    verification:
      - kind: other
        ref: "grep -c 'user_row_fields' guides/reference/admin-design-contract.md returns >=1; no sg-page-copy/sg-metric-grid inside sg-page-header in List Archetype block"
        status: pass
    human_judgment: false

duration: 185s
completed: "2026-06-26"
status: complete
---

# Phase 201 Plan 03: Test and Documentation Guards Summary

**GET-form contract proven by real form-submit Playwright test, users-index-live ratcheted to bare Tier 2 with proxy evidence, and List Archetype block rewritten to the elevated search-first composition.**

## Performance

- **Duration:** 185s
- **Started:** 2026-06-26T09:28:53Z
- **Completed:** 2026-06-26T09:31:58Z
- **Tasks:** 3
- **Files modified:** 3

## Accomplishments

- Added a real form-submit Playwright test that types a query into the search input and clicks the "Search" button (NOT a `?q=` pre-built goto), confirming the GET-form contract is enforced end-to-end (D-02). If the filter input is ever placed outside the `<form>`, this test fails.
- Confirmed the frozen `td:nth-child(3)/(4)` equivalence selectors in `assertUserResultEquivalence` still target Organizations/Activity after Plan 01's recompose — column order preserved, no selector change needed (D-06).
- Ratcheted `users-index-live` ledger column-4 from `1` to bare integer `2`; expanded Evidence citing all applicable Tier-2 proxies (content-equivalence, glossary-clean, motion-tokens, density rhythm, target-size) and explicitly marking overlay-axe + 7 APG gates as N/A (D-09). Monotonic guard passes: 36 cells, 0 regressions.
- Rewrote the stale List Archetype block in `admin-design-contract.md` to document the Phase 201 elevated composition: search-first filter panel, demoted slim metric strip, contiguous applied-chip row, `<.user_row_fields>` DRY note, frozen 5-column order, host seam positions (D-12). Removed stale claims: `sg-page-copy` + `sg-metric-grid` inside `sg-page-header`, metric-strip-first ordering, detached applied-chip sibling.

## Task Commits

1. **Task 1: Add real form-submit Playwright test and confirm frozen equivalence selectors** - `9cae5401` (test)
2. **Task 2: Ratchet users-index-live ledger cell to bare Tier 2** - `ea6b82f8` (docs)
3. **Task 3: Rewrite stale List Archetype block in design contract** - `388b4713` (docs)

## Files Created/Modified

- `test/example/priv/playwright/tests/admin-design.spec.ts` — New test: `filter form submits via real GET submission and returns filtered results` (48 lines added after line 393)
- `guides/reference/admin-quality-ledger.md` — `users-index-live` row column-4 flipped `1` → `2`; Evidence expanded with Tier-2 proxy evidence and N/A modal markers
- `guides/reference/admin-design-contract.md` — List Archetype block (formerly 38 lines) rewritten to 60-line elevated composition block with Notes section

## Decisions Made

- D-02: Real form submission via `getByPlaceholder + fill + waitForURL + getByRole('button', 'Search').click()` — the `waitForURL` guard fires when the URL gains `?q=admin@demo.tasklane.test`; a detached input would submit an empty form and fail the URL match.
- D-06: No selector change made to `td:nth-child(3)/(4)` in `assertUserResultEquivalence` — confirmed Organizations at col-3, Activity at col-4 by reading `users_index_live.ex` thead. Plan 01 froze the five-column order and that freeze was honored.
- Ledger row written as a single extended pipe row (mirroring the `user-show-live` Tier-2 exemplar at line 88), not as a separate prose block — keeps awk positional parse working.
- `overlay-axe` / APG focus-trap/restore gates written as literal `N/A` in the Evidence column, not omitted — the plan required explicit N/A markers to distinguish "not applicable" from "not checked".
- Notes section in the rewritten List Archetype matches the style of Phase 200's Detail Archetype block (bullet-format with decision references), ensuring structural consistency across the contract.

## Deviations from Plan

None — plan executed exactly as written.

## Known Stubs

None — all three artifacts are documentation/test additions with no runtime data wiring stubs.

## Threat Flags

None — no new network endpoints, auth paths, file access patterns, or schema changes introduced. The Playwright test is read-only (GET form submission, no state mutation). The ledger and contract edits are static markdown.

## Self-Check

### Files Exist
- test/example/priv/playwright/tests/admin-design.spec.ts: EXISTS (verified via grep)
- guides/reference/admin-quality-ledger.md: EXISTS (awk parse confirmed)
- guides/reference/admin-design-contract.md: EXISTS (grep confirmed user_row_fields)

### Commits Exist
- 9cae5401: test(201-03): add real form-submit Playwright test for GET-form contract (D-02) ✓
- ea6b82f8: docs(201-03): ratchet users-index-live ledger cell to bare Tier 2 (D-09) ✓
- 388b4713: docs(201-03): rewrite stale List Archetype block to elevated search-first composition (D-12) ✓

## Self-Check: PASSED
