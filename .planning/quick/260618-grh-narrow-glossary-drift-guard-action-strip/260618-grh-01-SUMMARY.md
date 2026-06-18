---
phase: 260618-grh
plan: "01"
subsystem: test
tags: [test-robustness, glossary-drift-guard, false-negative-fix]
status: complete

dependency_graph:
  requires: []
  provides: [regression guard for action="..." human-copy scanning]
  affects: [test/sigra/admin/glossary_test.exs]

tech_stack:
  added: []
  patterns:
    - Narrowed regex strip pattern (action=\{ vs bare action=) to preserve human-copy attrs for scanning

key_files:
  created: []
  modified:
    - test/sigra/admin/glossary_test.exs

decisions:
  - "Use action=\\{ (curly brace) as the discriminator between Elixir-expression actions (URL-bearing, strip) and string-literal actions (copy-bearing, keep) — confirmed clean separator across all 8 scanned source files"
  - "Split combined href/action/phx pattern into two explicit patterns for readability; functionally equivalent"

metrics:
  duration: "< 5 minutes"
  completed: "2026-06-18"
  tasks_completed: 1
  files_modified: 1
---

# Phase 260618-grh Plan 01: Narrow Glossary Drift Guard Action Strip Summary

Narrowed `@strip_patterns` action= entry from bare `action=` to `action=\{` so component copy attrs (`action="Review users"`, `action="Open members"`) survive stripping and remain visible to the banned-terms scan; added regression test confirming a banned term inside `action="..."` is caught.

## What Was Done

**Task 1: Narrow @strip_patterns line 173 and add regression describe block**

Changed the URL/event strip pattern in `@strip_patterns` from the combined group:

```elixir
~r/(href|action|phx-\w+|name=|input\s+.*name)=/,
```

to two explicit patterns:

```elixir
~r/(href=|action=\{|phx-\w+=)/,
~r/(name=|input\s+.*name)=/,
```

The key change: `action=\{` matches only Elixir-expression form actions (e.g. `action={index_path(@admin_scope)}`). The 5 `action="..."` string-literal component attrs in the scanned files (human copy like "Review users", "Open members", "Send invitations") now survive `strip_non_copy_lines/1` and are subject to banned-term scanning.

Added a new `describe` block with one test:
- Constructs a synthetic `indexed_lines` list in memory (no file I/O)
- Feeds `{"          action=\"Review logins\"", 99}` through `strip_non_copy_lines/1`
- Asserts the line is NOT stripped
- Runs the banned-terms scan over surviving lines and asserts a violation for "logins" is returned

## Verification Gate

```
mix test test/sigra/admin/glossary_test.exs
2 tests, 0 failures
```

Both tests pass:
1. `no banned synonyms in admin chrome source files` — 8 real files, no false positives introduced
2. `action="..." lines with human copy survive stripping and are scanned` — regression guard confirmed

## Deviations from Plan

None — plan executed exactly as written.

## Self-Check

- [x] `test/sigra/admin/glossary_test.exs` modified
- [x] Commit `75133cdc` exists
- [x] 2 tests, 0 failures confirmed
- [x] `action=\{` present in `@strip_patterns`; old bare `action=` pattern gone
- [x] No scanned LiveView source files modified

## Self-Check: PASSED
