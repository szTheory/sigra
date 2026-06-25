---
created: 2026-06-18T00:00:00.000Z
status: pending
title: optional CI guard for admin-token-reference completeness (186 IN-03, deferred)
area: test
files:
  - guides/reference/admin-token-reference.md
  - test/example/priv/playwright/tests/admin-theme.spec.ts
source: 186-REVIEW.md (IN-03); split out of 2026-06-14-phase-186-review-deferred.md when that todo was closed by quick task 260618-gly
resolves_phase: 199
---

## What

`admin-token-reference.md` claims it documents "every `--sg-*` custom property in the
`:root` layer" (currently true: 96/96), but nothing stops it rotting when a token is
added without a doc row.

## Fix direction (optional, low priority)

- Lightweight CI check diffing LHS `--sg-*` defs in `sigra_admin.css :root` against the
  documented backtick tokens, failing on divergence.
- Optionally add a unit-style guard for `oklabChannels()` (e.g.
  `contrastRatio("oklab(1 0 0)", "oklab(0 0 0)") ≈ 21:1`) so the CR-01 matrix fix cannot
  silently regress.

## Why deferred

Explicitly marked optional in 186-REVIEW.md. The substantive 186 review findings
(WR-01/02/03, IN-02) are all resolved (quick task 260618-gly); this guard is a
nice-to-have rot-prevention measure, not a fix for any current defect.
