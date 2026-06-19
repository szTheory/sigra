---
phase: 191-microcopy-ia-sweep
reviewed: 2026-06-17T23:55:00Z
depth: standard
files_reviewed: 8
files_reviewed_list:
  - lib/sigra/admin/live/branding_live.ex
  - lib/sigra/admin/live/index_live.ex
  - lib/sigra/admin/live/organization_live.ex
  - lib/sigra/admin/live/user_show_live.ex
  - lib/sigra/admin/live/users_index_live.ex
  - test/sigra/admin/glossary_test.exs
  - test/sigra/admin/components_test.exs
  - guides/reference/admin-glossary.md
findings:
  critical: 0
  warning: 2
  info: 1
  total: 3
status: issues_found
remediation:
  fixed:
    - "WR-02 — inspect(exception) rescue leak in branding_live.ex:728 → generic operator message"
    - "IN-01 — added clarifying comment to @notice_link_golden in components_test.exs"
  deferred:
    - "WR-01 — narrow glossary guard action= strip pattern → .planning/todos/pending/2026-06-17-phase-191-review-deferred.md (brittle regex, no current defect)"
---

# Phase 191: Code Review Report

**Reviewed:** 2026-06-17T23:55:00Z
**Depth:** standard
**Files Reviewed:** 8
**Status:** issues_found (2 warnings, 1 info — no blockers)

## Summary

Phase 191 made 21 exact string substitutions across 5 admin LiveViews, added a new `chip_label("deleted", nil)` clause, fixed the WR-04 `inspect(reason)` leak in `branding_live.ex`, and introduced `test/sigra/admin/glossary_test.exs` as a source-parsing drift guard.

The copy edits are mechanically correct: no interpolation breakage, no HEEx syntax disruption, no logic changes beyond the `chip_label` clause insertion. The carve-out state machine in `glossary_test.exs` was traced in full: the marker line is correctly identified on line 585 (the `class=` line), `count_div_depth` returns `max(1, 0)` = 1 to account for the preceding `<div` on line 584, and the nesting depth arithmetic closes at line 610. The `Log in` at line 601 inside the carve-out is not reported. The test runs GREEN (confirmed by `mix test test/sigra/admin/glossary_test.exs` — 1 test, 0 failures, 0.4s).

Two warnings are raised: the `action=` strip pattern silently suppresses component attribute lines that carry visible copy (false-negative risk for future guard regressions), and a pre-existing `inspect(exception)` rescue path in `branding_live.ex` that phase 191 did not address. One info item: the `notice_link` component test in `components_test.exs` still uses "Review accounts" as its hardcoded inner_block string — this is consistent with the test's purpose (structural rendering, not copy hygiene) and sits outside the drift guard's scope, but it is a stale string that could mislead a future reader.

---

## Warnings

### WR-01: `action=` attribute lines are stripped from glossary scan — banned terms in `action=` position are invisible to the guard

**File:** `test/sigra/admin/glossary_test.exs:173`

**Issue:** The `@strip_patterns` list includes `~r/(href|action|phx-\w+|name=|input\s+.*name)=/`, which strips any line containing `action=`. This was intended to suppress HTML `<form action=...>` and Phoenix event attribute lines. However, it also strips component attribute lines such as:

```
          action="Review users"
```

These lines in `index_live.ex` and `organization_live.ex` carry visible operator-facing copy. If a banned term were introduced into an `action=` attribute (e.g. `action="Review logins"`), the drift guard would report zero violations — a silent false negative.

The current `action=` values are all clean, so no regression exists today. The gap becomes a correctness risk if `task_card` action labels are edited in the future without anyone realizing the guard cannot catch them.

**Fix:** Narrow the `action=` pattern to only match HTML form action attributes (which carry URLs, not human copy), or replace it with a pattern that strips only lines where `action=` contains a URL-shaped value:

```elixir
# Instead of:
~r/(href|action|phx-\w+|name=|input\s+.*name)=/,

# Use two separate patterns — one for URL-bearing attrs, one for event handlers:
~r/(href=|action="\/|phx-\w+=)/,
~r/(name=|input\s+.*name)=/,
```

Alternatively, add `action=` lines to a separate second scan pass that validates them against the banned terms list without the full line stripping.

---

### WR-02: Pre-existing `inspect(exception)` rescue path survives in `branding_live.ex:728`

**File:** `lib/sigra/admin/live/branding_live.ex:725-729`

**Issue:** The phase 191 WR-04 fix correctly replaced the catch-all `error_message(_reason)` with a generic message. However, the second clause of `error_message` still contains a rescue branch that leaks internal representation:

```elixir
defp error_message(%{__struct__: _module} = exception) do
  Exception.message(exception)
rescue
  _ -> inspect(exception)      # <-- still leaks raw Elixir terms on rescue
end
```

If `Exception.message/1` raises (e.g., because a struct with `__struct__` is passed that is not a proper exception), the rescue returns `inspect(exception)` — which produces output like `%SomeModule{field: value}` in the operator UI. The glossary's voice rubric explicitly forbids this: "No `inspect/1` output, no `%Ecto.Changeset{}` struct shapes, no module names."

This path was pre-existing before phase 191 and is not a new regression, but it is adjacent to the WR-04 fix and the phase's stated goal was to eliminate all `inspect(reason)` leaks from the error path.

**Fix:**

```elixir
defp error_message(%{__struct__: _module} = exception) do
  Exception.message(exception)
rescue
  _ -> "Could not save auth branding. Check the values and try again."
end
```

---

## Info

### IN-01: `@notice_link_golden` in `components_test.exs` uses stale "Review accounts" string

**File:** `test/sigra/admin/components_test.exs:72,437`

**Issue:** The `@notice_link_golden` module attribute and the corresponding `render_component` call at line 437 both use the string `"Review accounts"` — a banned synonym (account-as-person-noun) per the glossary. The phase 191 plan updated `@notice_golden` (the notice component golden) and the related `inner_block` render string, but `@notice_link_golden` was not changed.

This is intentional by design: the `notice_link` test is a structural rendering test (verifying the anchor HTML, not policing copy). The `inner_block` is deliberately set to an arbitrary string to verify the component renders it faithfully. Test files are also explicitly excluded from `@in_scope_files` in the drift guard. No current test failure results.

However, a future reader auditing the test file will see "Review accounts" and may not know it was intentionally left to test component structure. A clarifying comment would prevent confusion.

**Fix:** Add a one-line comment explaining the intentional use:

```elixir
# Structural rendering test — inner_block text is arbitrary; copy hygiene is out of scope here.
@notice_link_golden "<a href=\"/admin/users?needs_review=true\" class=\"sg-notice__action \">\n  Review accounts\n</a>"
```

---

_Reviewed: 2026-06-17T23:55:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
