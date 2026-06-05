---
created: 2026-06-03T00:00:00.000Z
status: completed
folded_into: phase-156
folded_at: 2026-06-04
folded_resolution: shared-selector merge (.sg-list-row[data-tone], .sg-notice[data-tone]) per 156-CONTEXT D-08
completed_at: 2026-06-05
completion_evidence: Phase 156 folded the duplicate tone rules into shared selectors.
title: sg-notice / sg-list-row tone-rule duplication has no drift guard
area: test/example/priv/static/assets/css
files:
  - test/example/priv/static/assets/css/app.css
source: 154-REVIEW.md (WR-02)
---

## Finding (Phase 154 code review, WR-02)

`.sg-notice[data-tone]` was introduced in Phase 154 as a verbatim selector-rename
of the existing `.sg-list-row[data-tone]` tone rules — identical tokens, identical
`color-mix(in oklab, …)` formula, identical ok=18% / warn,risk,info=20% ring-opacity
asymmetry. The duplication is intentional and behavior-preserving for the Phase
154→156 admin-UI-coherence migration window.

## Risk

There is no shared declaration and no test holding the two tone blocks in sync. If
a future change edits one tone scale (e.g. retunes `warn` ring opacity) and not the
other, the two components silently drift apart with no failing check to catch it.

## How to apply

Pick ONE during the 154→156 window (or when the migration concludes):
- Extract the shared tone declarations into a common selector list
  (`.sg-list-row[data-tone="X"], .sg-notice[data-tone="X"]`) so there is a single
  source of truth, OR
- Add a Playwright/visual or CSS-snapshot assertion that fails if the two tone
  blocks' computed tokens diverge.

Acceptable to leave as-is through the migration window; this todo exists so the
duplication is not forgotten once the rename settles. Not blocking Phase 154.
