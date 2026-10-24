---
phase: 253-fix-flaky-ci-and-preserve-required-checks
plan: "36"
subsystem: testing
tags: [ci-reliability, load-recovery, playwright, parse5, node20]
requires:
  - phase: 253
    provides: load-failure diagnostic (CR-DARK-FIRST) that identified the CJS/ESM parse5 seam
provides:
  - Node20-compatible async renderSha256 (cached native import('parse5'))
  - offline pinned-transform collection and hash contract (scripts/ci/ci-playwright-load.test.mjs)
affects: [253 native recovery plans]
actuals:
  tokens: 9000
  tasks: 2
  commits: 2
  # plan_head_before ca5f1e2f20417e37bbcc5cf66304b6dff94b670a
plan_head_before: ca5f1e2f20417e37bbcc5cf66304b6dff94b670a
plan_head_after: 06840d827
tech-stack:
  added: []
  patterns: ["load real spec through installed Playwright loadConfigFromFile/loadTestFile in fresh Node subprocesses with child_process/network denied"]
key-files:
  created: [scripts/ci/ci-playwright-load.test.mjs]
  modified:
    - test/example/priv/playwright/lib/eval/canonicalize.ts
    - test/example/priv/playwright/lib/eval/bundle.ts
    - test/example/priv/playwright/lib/eval/canonicalize.test.ts
    - test/example/priv/playwright/tests/admin-eval.spec.ts
key-decisions:
  - "Cache the parse5 import promise but clear it on rejection; original import error propagates, no fabricated hash."
  - "bundle.ts uses import.meta.url so it only loads as ESM; the contract copies it into a type:module temp tree rather than changing module mode."
requirements-completed: ["CIREL-01"]
coverage:
  - id: D1
    description: "Old static parse5 import fails under the real pinned Playwright 1.59.1 CJS transform with the observed ERR_REQUIRE_ESM; repaired canonicalizer transforms to native import() and yields a stable 64-hex hash"
    requirement: CIREL-01
    verification:
      - kind: unit
        ref: "scripts/ci/ci-playwright-load.test.mjs#preserved static-import canonicalizer fails ... (RED) / repaired renderSha256 resolves ..."
        status: pass
    human_judgment: false
  - id: D2
    description: "Actual admin-eval spec collects first (5), second (2) and original board titles in fresh processes with no load errors; 17 canonicalize cases pass; bundle manifest has concrete render_sha256"
    requirement: CIREL-01
    verification:
      - kind: unit
        ref: "scripts/ci/ci-playwright-load.test.mjs (10 tests)"
        status: pass
    human_judgment: false
duration: 25min
completed: 2026-10-13
status: complete
---

# Phase 253 Plan 36: Node20 canonicalizer import repair Summary

**parse5 (ESM-only) is now loaded by a cached native dynamic import inside an async renderSha256, so the Playwright-transformed admin-eval spec collects under Node 20.18.1; proven offline with no CLI, browser, app or network.**

## Accomplishments
- Reproduced the observed `require() of ES Module ... parse5` error from the preserved old git blob (52112f07) through the installed Playwright 1.59.1 `requireOrImport` transform (RED), with no CLI/browser.
- `renderSha256` returns `Promise<string>`; `writeBundle` and spec-local `writeBundleLocal` are async and await it; `captureSurface` awaits `writeBundleLocal`. Walk/allowlist/hash rules unchanged (same hash for volatile-only changes, different hash for semantic change).
- Transformed output verified to contain `import("parse5")` and no `require("parse5")`.
- `canonicalize.test.ts` converted to awaited async cases (17 preserved, failure count kept); runs under the pinned transform (17 passed, 0 failed).
- Real spec collected via installed `loadConfigFromFile` + `loadTestFile` + `suite.allTests()` per stage in fresh subprocesses: first stage has exactly the 5 first titles, second exactly the 2 second titles, unstaged has none; `render bundle: board-mg-9/populated` registered in all; zero load errors, nonempty inventory.
- Written bundle manifest (via bundle.ts, ESM temp copy) has a 64-hex `render_sha256` and unchanged manifest fields.

## Task Commits
1. **Task 1: canonicalizer import seam** - `28323da85` (fix)
2. **Task 2: canonicalize self-test + collection** - `06840d827` (test); collection contract itself landed in the Task 1 commit with the new test file

## Deviations from Plan

None in scope. Notes: the `canonicalize.test.ts` needed an async `main()` wrapper (no top-level await under the CJS transform) - part of the planned conversion. STATE.md/ROADMAP/state.json/REQUIREMENTS/config were intentionally not touched (root owns them per execution contract); pre-existing uncommitted `.planning/STATE.md`, `config.json`, `state.json` edits were left unstaged.

## Issues Encountered
None. Verification: `ASDF_NODEJS_VERSION=20.18.1 asdf exec node --test scripts/ci/ci-playwright-load.test.mjs` -> 10 pass, 0 fail.

## execution_performed
Offline only. Zero Playwright CLI processes, browsers, apps, network or GitHub calls. No native allocation spent; immutable budget facts (six reservations, five prior CLI processes, 276453ms, 112489ms, retry 1/0) untouched.

## Remaining gaps
Successful offline loading does not prove the historical CR-DARK-FIRST registration cause; that failure and zero-selected result stay failed. Full Phase 253 verification remains not_started; freeze source blob maps must include `helpers/registrationControls.mjs` (diagnostic finding). No package, lock, module-mode or Node pin changed.

## Known Stubs
None.

## Threat Flags
None.

## Self-Check: PASSED
