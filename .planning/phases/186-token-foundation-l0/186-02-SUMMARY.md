---
phase: 186-token-foundation-l0
plan: "02"
subsystem: testing
tags: [css-parity, dark-mode, token-guard, exunit, ember-family]
dependency_graph:
  requires: []
  provides: [D-11 dark-block parity assertion, auth ember-family cross-check]
  affects: [test/sigra/install/features/admin_test.exs]
tech_stack:
  added: []
  patterns: [ExUnit file-I/O parity assertion (DIST-05 pattern), sorted CSS property extraction]
key_files:
  created: []
  modified:
    - test/sigra/install/features/admin_test.exs
decisions:
  - D-11 parity assertion uses line-range extraction (not brace-counting) for robustness against CSS structural changes
  - Ember-family cross-check covers risk/warn/ok only (not info — no --sigra-auth-info token exists in sigra_auth.css)
  - Dark block ranges hardcoded with a "verified 2026-06-14" comment per plan specification
metrics:
  duration: "~10 minutes"
  completed: "2026-06-14"
  tasks_completed: 1
  tasks_total: 1
  files_modified: 1
---

# Phase 186 Plan 02: D-11 Dark-Block Parity Assertion Summary

Added the D-11 System↔explicit-toggle dark-block parity assertion to admin_test.exs: ExUnit tests extracting and comparing sorted --sg-* declaration sets from the sigra_admin.css @media dark block and app.css explicit-toggle dark block, plus auth ember-family (risk/warn/ok) light+dark cross-check and a direct #fdba74 brand-strong assertion.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Add D-11 dark-block parity describe block to admin_test.exs | 773a9753 | test/sigra/install/features/admin_test.exs |

## What Was Built

A new `describe "D-11 System↔explicit-toggle dark-block parity"` block appended to `test/sigra/install/features/admin_test.exs` after the DIST-05 block. Contains:

- **Test 1 (dark token value parity):** Extracts sorted `--sg-*` declaration lists from both dark blocks (sigra_admin.css lines 167-204 via `extract_dark_media_props/1`, app.css lines 1512-1543 via `extract_explicit_dark_props/1`), asserts equality with an actionable failure message. Also directly asserts `--sg-color-brand-strong: #fdba74;` is present (WCAG AA v1.34 lightened value).

- **Test 2 (auth ember-family parity):** Asserts that `--sg-color-risk`, `--sg-color-warn`, `--sg-color-ok` in the admin light :root match the corresponding `--sigra-auth-risk`, `--sigra-auth-warn`, `--sigra-auth-ok` values in sigra_auth.css light block. Also asserts all three dark equivalents (#f8a39c, #f5c451, #5dd1a0) appear in both admin dark block and sigra_auth.css dark block. Notes the known near-match exclusion (--sg-color-panel #1f1d1a vs --sigra-auth-surface #211f1c).

- **Private helpers added:** `extract_dark_media_props/1`, `extract_explicit_dark_props/1`, `extract_token_value/2` — all module-level alongside existing `source_fragment/3` and `source_offset/2`.

## Verification

```
mix test test/sigra/install/features/admin_test.exs
# 24 tests, 0 failures
```

Plan verification criteria met:
- `grep -c "D-11 System" test/sigra/install/features/admin_test.exs` → 1
- `grep -c "fdba74" test/sigra/install/features/admin_test.exs` → 3
- DIST-05 test undisturbed (still passes)
- No new files created

## Deviations from Plan

### Auto-detected adjustments

**1. [Rule 2 - Missing critical functionality] Auth info token absent from sigra_auth.css**
- **Found during:** Task 1 implementation
- **Issue:** The plan specified asserting all four ember tone values (risk/warn/ok/info) against auth surface. `--sigra-auth-info` does not exist in `sigra_auth.css` — only risk, warn, ok are present.
- **Fix:** Scoped the ember cross-check to the three tokens that exist (risk, warn, ok). This matches the RESEARCH.md ember parity table which only documents these three against auth.
- **Files modified:** test/sigra/install/features/admin_test.exs
- **Commit:** 773a9753

No other deviations. Plan executed as specified.

## Decisions Made

- Line-range slicing approach (not brace-counting) used for block extraction — stable because verified line ranges are noted with a dated comment.
- Ember cross-check covers dark values by checking the extracted dark lines for substring presence (the `--sg-*` value strings), using the auth dark block located by the `data-theme="dark"` anchor.
- `--sigra-auth-info` is absent from sigra_auth.css; info ember parity is skipped with no assertion. Future work can add `--sigra-auth-info` if the auth CSS is extended.

## Known Stubs

None. All assertions reference actual file content; no mock data or placeholder values.

## Threat Flags

None. This plan modifies one ExUnit test file. No auth flows, no user data, no network, no cryptographic operations.

## Self-Check: PASSED

- [x] `test/sigra/install/features/admin_test.exs` exists and is modified
- [x] Commit 773a9753 verified in git log
- [x] 24 tests, 0 failures
- [x] D-11 describe block present (1 match on "D-11 System")
- [x] fdba74 assertion present (3 matches)
- [x] No files deleted in commit
