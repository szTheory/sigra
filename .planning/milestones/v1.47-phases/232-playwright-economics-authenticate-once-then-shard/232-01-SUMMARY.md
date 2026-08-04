---
phase: 232-playwright-economics-authenticate-once-then-shard
plan: 01
subsystem: testing
tags: [playwright, storageState, authentication, liveview, ci-economics]
requires:
  - phase: 230-tier-1-critical-path-reclamation
    provides: design-gallery inventory and CI evidence grammar
provides:
  - One UI-authenticated storageState setup per design-gallery project
  - Structural contracts preventing cross-wired state or per-test registration
  - PW-01 pre-change receipt for the ordered observed-run phases
affects: [232-02, 232-03, playwright-design-gallery]
tech-stack:
  added: []
  patterns: [Playwright setup-project authentication with project-specific ephemeral storage state]
key-files:
  created:
    - test/example/priv/playwright/tests/admin-design.setup.ts
    - test/sigra/planning/phase_232_playwright_economics_test.exs
    - .planning/phases/232-playwright-economics-authenticate-once-then-shard/232-EVIDENCE.md
  modified:
    - test/example/priv/playwright/playwright.config.ts
    - test/example/priv/playwright/tests/admin-design.spec.ts
key-decisions:
  - "Each design project owns a matching UI setup project and test-results/.auth storageState file."
  - "Design beforeEach retains only navigation and deterministic LiveView/font readiness."
patterns-established:
  - "Playwright setup projects persist state only after role-based registration success is observed."
requirements-completed: [PW-01]
coverage:
  - id: D1
    description: "Three design-gallery projects authenticate through distinct ephemeral setup states."
    requirement: PW-01
    verification:
      - kind: unit
        ref: "test/sigra/planning/phase_232_playwright_economics_test.exs"
        status: pass
      - kind: integration
        ref: "npx playwright test --list --project=admin-design-chromium --project=admin-design-mobile --project=admin-design-dark --retries=0"
        status: pass
    human_judgment: false
  - id: D2
    description: "Design-gallery test readiness and board coverage remain structurally intact."
    requirement: PW-01
    verification:
      - kind: unit
        ref: "test/sigra/planning/phase_232_playwright_economics_test.exs#design spec uses readiness-only beforeEach"
        status: pass
    human_judgment: false
duration: 8min
completed: 2026-07-31
status: complete
---

# Phase 232 Plan 01: Authenticate Once, Then Shard Summary

**Each design-gallery render context now reuses one UI-authenticated, policy-valid Playwright session while preserving deterministic LiveView and Space Grotesk readiness.**

## Performance

- **Duration:** 8min
- **Tasks:** 2
- **Files modified:** 6

## Accomplishments

- Added isolated Chromium, iPhone 13, and dark-desktop setup projects, identities, and ephemeral state files below Playwright output.
- Removed per-test registration from the gallery spec without changing its route navigation, LiveView readiness, font gate, boards, axe scan, or snapshots.
- Added Phase 232 contracts and captured the pre-change PW-01 CI receipt from run `30390832059`.

## Task Commits

1. **Task 1: Prove one chromium design session end-to-end** — `1cccfea1`, `abfbbd95`
2. **Task 2: Expand distinct authentication to mobile and dark** — `87216e6c`, `6241d42a`

## Files Created/Modified

- `test/example/priv/playwright/playwright.config.ts` — setup dependencies and state mappings.
- `test/example/priv/playwright/tests/admin-design.setup.ts` — UI registration and private storage-state persistence.
- `test/example/priv/playwright/tests/admin-design.spec.ts` — readiness-only gallery setup.
- `test/sigra/planning/phase_232_playwright_economics_test.exs` — non-vacuous Phase 232 structural contracts.
- `232-EVIDENCE.md` — BEFORE-PW-01 receipt and verbatim metrics output.

## Decisions Made

- State files are project-specific under `test-results/.auth` and are produced only after registration succeeds.
- Existing project device, color-scheme, video, retry, worker, and test-selection settings remain unchanged.

## Verification

- `mix test test/sigra/planning/phase_232_playwright_economics_test.exs` — 4 passing tests.
- `npx playwright test --list --project=admin-design-chromium --project=admin-design-mobile --project=admin-design-dark --retries=0` — 126 listed tests, including 3 setup dependencies and the unchanged 123 design-spec tests.

## Deviations from Plan

None - plan executed exactly as written.

## Known Stubs

None.

## Next Phase Readiness

PW-01’s structural implementation and pre-change evidence are ready for the retry-zero observed-run checkpoint in Plan 232-02.

## Self-Check: PASSED

- Verified all created source, contract, evidence, and summary files exist.
- Verified task commits `1cccfea1`, `abfbbd95`, `87216e6c`, and `6241d42a` exist in git history.
