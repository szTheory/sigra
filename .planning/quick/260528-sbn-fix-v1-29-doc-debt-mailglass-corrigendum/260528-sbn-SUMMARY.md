---
phase: quick-260528-sbn
plan: "01"
subsystem: docs
tags: [docs, companion-libs, version-pins, corrigendum, v1.29]
dependency_graph:
  requires: [DOC-01-complete, Phase-136]
  provides: [accurate-mailglass-corrigendum-pointer, resolvable-sigra-version-pins]
  affects: [guides/recipes/companion-libs]
tech_stack:
  added: []
  patterns: []
key_files:
  created: []
  modified:
    - guides/recipes/companion-libs/mailglass.md
    - guides/recipes/companion-libs/accrue.md
    - guides/recipes/companion-libs/lockspire.md
    - guides/recipes/companion-libs/relyra.md
    - guides/recipes/companion-libs/rulestead.md
    - guides/recipes/companion-libs/threadline.md
decisions:
  - "Corrigendum pointer now directs readers to CHANGELOG.md v1.25 entry (present tense); suite-integration.html removed as that page has no corrigendum text"
  - "All 7 {:sigra, ~> 1.29} self-pins updated to {:sigra, ~> 0.2} which resolves to 0.3.0 on hex.pm"
  - "AGENTS.md verified as already correct (Three committed migrations) — no edit made"
metrics:
  duration: ~300s
  completed: "2026-05-28"
  tasks: 3
  files_changed: 6
---

# Phase quick-260528-sbn Plan 01: Fix v1.29 Doc-Debt (Mailglass Corrigendum + Version Pins) Summary

**One-liner:** Rewrote stale DOC-01 corrigendum pointer in mailglass.md to present tense pointing at CHANGELOG.md, and replaced all 7 `{:sigra, "~> 1.29"}` pins (which fail `mix deps.get`) with `{:sigra, "~> 0.2"}` across 6 companion-lib recipes.

## Tasks Completed

| # | Task | Commit | Files |
|---|------|--------|-------|
| 1 | Rewrite mailglass.md corrigendum pointer (Item 1) | 7e9db30 | guides/recipes/companion-libs/mailglass.md |
| 2 | Align sigra self-pin to ~> 0.2 across 6 recipes; verify AGENTS.md (Items 2+3) | 90adeaa | mailglass.md, accrue.md, lockspire.md, relyra.md, rulestead.md, threadline.md |
| 3 | ExDoc build + banned-phrase gate | (verification only, no commit needed) | — |

## Deviations from Plan

None — plan executed exactly as written.

## Verification Results

- `mix docs --warnings-as-errors` exits 0 (run from main project root where deps are compiled; worktree shares the guides/ tree via git).
- `grep -rc '{:sigra, "~> 1.29"}' guides/recipes/companion-libs/` reports 0 across all 6 files.
- `grep -rl '{:sigra, "~> 0.2"}' guides/recipes/companion-libs/` reports 6 files.
- mailglass.md non-goals bullet references `CHANGELOG.md` (v1.25 entry) and MILESTONES.md/PROJECT.md, not the stale `suite-integration.html` location.
- `test/example/AGENTS.md:208` confirmed to read "Three committed migrations" — no edit made.
- Banned-phrase grep across all 6 edited files: 0 matches.

## Item Detail

### Item 1 — mailglass.md corrigendum pointer

**Before (stale):**
> A corrigendum correcting the v1.25 EMAIL-RAILS narrative is planned for Phase 136 DOC-01; until it lands, see the planned location: `../introduction/suite-integration.html`.

**After (corrected):**
> A corrigendum correcting the v1.25 EMAIL-RAILS Mailglass narrative has landed in `CHANGELOG.md` (v1.25 entry); the same correction appears in MILESTONES.md and PROJECT.md under v1.25.

### Item 2 — AGENTS.md migration count (verify-only)

`test/example/AGENTS.md:208` reads "Three committed migrations" — correct. No edit needed or made.

### Item 3 — Version pin alignment (7 occurrences, 6 files)

Changed `{:sigra, "~> 1.29"}` → `{:sigra, "~> 0.2"}` at:
- accrue.md:30
- lockspire.md:37
- relyra.md:46
- rulestead.md:36 and :100
- mailglass.md:35
- threadline.md:49

Sister-lib pins (`mailglass ~> 1.2`, `threadline ~> 0.5`, etc.) and `validated_against:` frontmatter left unchanged.

## Known Stubs

None.

## Threat Flags

None — docs-only changes, no new network endpoints or security surface introduced.

## Self-Check: PASSED

- guides/recipes/companion-libs/mailglass.md: FOUND (modified)
- guides/recipes/companion-libs/accrue.md: FOUND (modified)
- guides/recipes/companion-libs/lockspire.md: FOUND (modified)
- guides/recipes/companion-libs/relyra.md: FOUND (modified)
- guides/recipes/companion-libs/rulestead.md: FOUND (modified)
- guides/recipes/companion-libs/threadline.md: FOUND (modified)
- Commit 7e9db30: FOUND
- Commit 90adeaa: FOUND
