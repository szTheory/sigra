---
phase: 260618-gly
plan: "01"
subsystem: test-infrastructure
tags: [test-robustness, css-extraction, d-11-parity]
requires: []
provides: [hardened-d11-parity-extractors]
affects: [test/sigra/install/features/admin_test.exs]
tech_stack:
  added: []
  patterns: [structural-css-block-extraction, selector-scoped-token-lookup]
key_files:
  modified:
    - test/sigra/install/features/admin_test.exs
decisions:
  - "WR-02: extract_css_block/2 anchored on .sigra-auth[data-theme=\"dark\"] replaces fixed 30-line Enum.take window"
  - "WR-03: extract_token_value/3 with optional context_selector (default :root); auth call sites pass .sigra-auth"
  - "Auth light tokens confirmed in .sigra-auth block (not :root) in sigra_auth.css — .sigra-auth context selector is correct"
metrics:
  duration: "~5 minutes"
  completed: "2026-06-18"
  tasks_completed: 2
  tasks_total: 2
  files_changed: 1
status: complete
---

# Phase 260618-gly Plan 01: Harden Phase 186 D-11 Parity Test Extractors Summary

Two latent brittleness issues in admin_test.exs (phase 186 review findings WR-02 and WR-03) are fixed.
Structural CSS block extraction and root-scoped token lookup replace positional heuristics with no
assertions weakened.

## Tasks Completed

| # | Task | Commit | Files |
|---|------|--------|-------|
| 1 | Fix WR-02 — replace fixed 30-line auth dark window with structural block extraction | 9cff3605 | test/sigra/install/features/admin_test.exs |
| 2 | Fix WR-03 — scope extract_token_value/2 to correct CSS block | a0a34438 | test/sigra/install/features/admin_test.exs |

## What Was Built

### WR-02 (Task 1)
Replaced the brittle `Enum.take(30)` sliding window for auth dark block extraction with a call to
the existing `extract_css_block/2` helper anchored on `.sigra-auth[data-theme="dark"]`. The helper
uses `:binary.match/2` to find the selector and `take_balanced_block/1` to read to the matching `}`,
so the extraction is structural rather than positional. The binding was renamed from `auth_dark_lines`
to `auth_dark_block` to reflect that it is now a CSS block string rather than a line list. The two
downstream `String.contains?` assertions were updated to reference the new binding name — the
assertions themselves are unchanged.

### WR-03 (Task 2)
Added an optional `context_selector` parameter (default `":root"`) to `extract_token_value`. The
function now calls `extract_css_blocks(css, context_selector)` to build a search domain confined to
the relevant CSS block, rather than scanning the entire CSS file. This eliminates the risk of a dark
override value silently satisfying a light parity check if declaration order changes.

Pre-change CSS structure verification confirmed:
- `sigra_admin.css`: light `--sg-color-risk`, `--sg-color-warn`, `--sg-color-ok` live inside `:root { ... }` — default selector works, no call site change needed.
- `sigra_auth.css`: light `--sigra-auth-risk`, `--sigra-auth-warn`, `--sigra-auth-ok` live inside `.sigra-auth, .sigra-auth-email-preview { ... }` — NOT in `:root`. The auth call site in the light ember parity loop was updated to pass `".sigra-auth"` explicitly.

## Deviations from Plan

None — plan executed exactly as written.

## Verification Gate

```
mix test test/sigra/install/features/admin_test.exs --no-deps-check
27 tests, 0 failures
```

```
grep -n "Enum.take(30)" test/sigra/install/features/admin_test.exs
(no output — pattern is gone)
```

## Self-Check: PASSED

- `test/sigra/install/features/admin_test.exs` — exists and modified
- Commit `9cff3605` — WR-02 fix present in git log
- Commit `a0a34438` — WR-03 fix present in git log
- `Enum.take(30)` grep returns nothing
- 27 tests, 0 failures
