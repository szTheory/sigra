---
created: 2026-06-17T00:00:00.000Z
status: pending
title: narrow glossary drift-guard action= strip pattern (phase 191 deferred review finding WR-01)
area: test
files:
  - test/sigra/admin/glossary_test.exs
source: 191-REVIEW.md (WR-01)
---

## Why deferred

Phase 191's code review came back clean at the blocker level (0 critical). Two
of the three findings were fixed inline at phase close (commit follows this
todo):
- WR-02 — `inspect(exception)` rescue leak in `branding_live.ex:728` replaced
  with the generic operator message (on-theme with the phase's WR-04 goal).
- IN-01 — added a clarifying comment to `@notice_link_golden` in
  `components_test.exs` explaining the intentional "Review accounts" string.

WR-01 below was deferred because it hardens the drift guard's strip regex, and
narrowing that pattern carries false-positive regression risk across all 8
scanned source files. There is **no current defect** — every `action=` value in
the scanned LiveViews is clean today. Deferring to a focused pass is lower risk
than editing a load-bearing strip regex at phase close.

## Finding to address

### WR-01 — `action=` attribute lines are stripped from the glossary scan (glossary_test.exs:173)

`@strip_patterns` includes `~r/(href|action|phx-\w+|name=|input\s+.*name)=/`,
which strips any line containing `action=`. That was intended to suppress HTML
`<form action=...>` and Phoenix event-attribute lines, but it also strips
component attribute lines that carry visible operator copy, e.g.
`action="Review users"` in `index_live.ex` / `organization_live.ex`. If a banned
term were introduced into an `action=` value (e.g. `action="Review logins"`),
the guard would silently report zero violations — a false negative.

**Fix direction:** narrow the `action=` rule so it strips only URL-bearing form
actions and event handlers, not human-copy component attrs. Either split into two
patterns:

```elixir
~r/(href=|action="\/|phx-\w+=)/,   # URL-bearing + event handlers
~r/(name=|input\s+.*name)=/,
```

or add a second scan pass that validates `action="..."` literal values against
the banned-terms list without stripping the whole line. Add a regression test
that introduces a banned term in an `action=` value and asserts the guard catches
it, so the gap cannot silently reopen.
