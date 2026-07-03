---
phase: "214"
plan: "03"
subsystem: example-css
status: complete
tags: [debt, css, ci-guard, browser-parse-verification]
requirements: [DEBT-05]

dependency_graph:
  requires: []
  provides: [DEBT-05-resolved, app-css-corruption-guard]
  affects: [test/example/priv/static/assets/css/app.css, .github/workflows/ci.yml]

tech_stack:
  added:
    - scripts/ci/app-css-corruption-check.sh (awk-based CSS :root corruption guard)
  patterns:
    - awk depth-tracking to scope CSS :root block scanning
    - Context-aware last_was_prop tracking for multi-line CSS value continuations

key_files:
  created:
    - scripts/ci/app-css-corruption-check.sh
  modified:
    - test/example/priv/static/assets/css/app.css
    - .github/workflows/ci.yml
  closed:
    - .planning/todos/pending/2026-06-21-app-css-comment-corruption-cleanup.md

decisions:
  - Guard uses awk context tracking (not a raw regex) to distinguish orphaned value
    fragments from legitimate multi-line --vt-* property value continuations
  - Guard added to fast_checks job in ci.yml (single checkout, no extra runner cost)
  - Browser-parse verification run with Playwright against live example server (not
    manual) — confirmed CSS parser accepted 334 app.css rules with --vt-* resolving

metrics:
  duration: 6m
  completed: "2026-07-03T01:54:07Z"
  tasks_completed: 3
  tasks_total: 3
  files_modified: 3
  files_created: 1
---

# Phase 214 Plan 03: App.css Corruption Cleanup (DEBT-05) Summary

Delete four orphaned-comment-corruption ranges from `test/example/priv/static/assets/css/app.css` and add CI guard to prevent regression — sg-* split left bare CSS value fragments in :root with no property names; CI guard and browser-parse verification close the blind spot.

## Tasks Completed

| # | Task | Commit | Files |
|---|------|--------|-------|
| 1 | Delete orphaned :root value fragments (D-15) | 76c6d116 | test/example/priv/static/assets/css/app.css |
| 2 | Add CI corruption guard and wire into ci.yml (D-17) | bbb0b37a | scripts/ci/app-css-corruption-check.sh, .github/workflows/ci.yml |
| 3 | Browser-parse verification | (no commit — verification only) | — |

## What Was Done

### Task 1: Delete orphaned :root value fragments

Removed all orphaned CSS value fragments from `test/example/priv/static/assets/css/app.css`:

**Light-mode :root block:**
- Deleted `/* Elevation ladder. ... */` comment header + three multi-line bare box-shadow value fragments (`--sg-elev-1/2/3` bodies at original lines 28-33)
- Deleted `/* Motion. ... */` comment header + two multi-line bare transition value fragments (`--sg-transition-tone/press` bodies at original lines 35-43)
- Deleted `/* Focus */` comment + one single-line bare focus-ring value fragment (`--sg-focus-ring` body at original line 45-46)

**Dark-mode :root block:**
- Deleted orphaned comment fragment tails (`* (~1.88:1 → >=4.5:1)...`, `* contrast...`) and bare box-shadow value at original lines 88-91

All `--vt-*` token declarations (light and dark mode) remain untouched. All `var(--sg-*)` references in `.vt-*` selector rules (234 occurrences of `var(--vt-`, 442 occurrences of `var(--sg-`) remain untouched.

### Task 2: CI corruption guard

Created `scripts/ci/app-css-corruption-check.sh` using awk to:
- Track brace depth to scope scanning to `:root {}` blocks only
- Track whether the previous non-blank line was a CSS property declaration (`last_was_prop`)
- Flag lines that are bare numeric values (`^\s+[0-9]`), bare `color var(--sg-` transition fragments, or bare `color-mix(in oklab, var(--sg-` focus-ring fragments ONLY when not a known continuation line
- Exit 0 on clean file; exit 1 with diagnostic output on corrupted file

The guard correctly distinguishes orphaned value fragments from legitimate multi-line `--vt-shadow: ... ;` continuation lines (tested: 348 parseable blocks, guard passes on clean file and fails on injected corruption).

Wired into `.github/workflows/ci.yml` under the `fast_checks` job as a "Check app.css for orphaned corruption" step — no extra runner cold-start required.

### Task 3: Browser-parse verification

Booted the example app on `http://localhost:4099` and ran a Playwright browser-parse verification:

**Result: PASSED (automated)**
- Total CSS rules parsed: 388
- Rules from app.css specifically: 334
- `--vt-color-ink` resolves to `#10242c` (correct light-mode value)
- `--vt-color-muted` resolves to `#526971` (correct light-mode value)
- Browser confirmed CSS parser accepted the cleaned file (rule count well above 20 threshold)

**Verified date:** 2026-07-03

## Deviations from Plan

None — plan executed exactly as written.

The Node.js structural check from the plan's `<verify>` block (`blocks.length > 30`) also passed with 348 parseable blocks. The guard script design used awk context tracking (as suggested in the plan) rather than a simpler regex approach, to correctly handle multi-line `--vt-shadow` continuation lines without false positives.

## Verification Results

```
bash scripts/ci/app-css-corruption-check.sh: OK (exit 0)
Orphaned value fragments in :root: NONE
--vt-* tokens preserved: 234 occurrences of var(--vt-
var(--sg-*) selector references preserved: 442 occurrences of var(--sg-
ci.yml fast_checks contains "Check app.css for orphaned corruption" step: YES
Browser-parse: 334 rules, --vt-color-ink=#10242c, PASSED (automated)
```

## Requirements Closed

- DEBT-05 — demo app.css orphaned-comment corruption cleaned up and guarded
- Todo `.planning/todos/pending/2026-06-21-app-css-comment-corruption-cleanup.md` moved to `resolved/`

## Known Stubs

None — all three deliverables are complete and functional.

## Threat Flags

None — this plan only modifies demo CSS and adds a CI guard script. No new security attack surface introduced.

## Self-Check: PASSED

- app.css: FOUND at test/example/priv/static/assets/css/app.css
- app-css-corruption-check.sh: FOUND at scripts/ci/app-css-corruption-check.sh
- 214-03-SUMMARY.md: FOUND at .planning/phases/214-debt-robustness-clear/214-03-SUMMARY.md
- Commit 76c6d116: FOUND (fix: delete orphaned :root value fragments)
- Commit bbb0b37a: FOUND (feat: add CI corruption guard)
- Guard verification: PASSED (exit 0 on clean file)
