---
phase: 202-audit-surfaces-elevation
reviewed: 2026-06-26T00:00:00Z
depth: standard
files_reviewed: 5
files_reviewed_list:
  - lib/sigra/admin/components.ex
  - lib/sigra/admin/live/audit_index_live.ex
  - lib/sigra/admin/live/audit_user_live.ex
  - test/example/priv/playwright/tests/admin-design.spec.ts
  - test/example/test/example_web/live/admin_audit_index_live_test.exs
findings:
  critical: 0
  warning: 2
  info: 4
  total: 6
status: issues_found
---

# Phase 202: Code Review Report

**Reviewed:** 2026-06-26
**Depth:** standard
**Files Reviewed:** 5
**Status:** issues_found

## Summary

Phase 202 extracted three shared audit function components (`audit_table_row/1`,
`audit_pagination_nav/1`, `audit_empty_state/1`) into `Sigra.Admin.Components` and
collapsed both audit LiveViews to consume them, deleting the duplicated `audit_tone/1`,
`multi_page?/1`, `format_timestamp/1`, and the old inline desktop-table markup. The
index page also gained a `<details>` "More filters" disclosure (the per-user page
already had one). Test seams were added: a Playwright equivalence guard asserting
exactly two `code.sg-code` nodes in the first desktop row, and an ExUnit pagination
boundary test (`>=26` renders nav, single-page suppresses it).

The refactor is mechanically faithful. I traced the old inline markup (`HEAD~13`) against
the extracted components and confirmed: column order is preserved, tone derivation is
byte-identical to the deleted per-LiveView copies, the nil-meta pagination path is safe
(`page_path(_, _, nil) -> "#"` plus the `@meta && multi_page?(@meta)` nav guard), and the
hidden `page_size`/`order_by`/`order_direction` inputs remain inside `<form>` but outside
`<details>` so they always submit. The pagination test's `?action=` exact-match filter is
a valid `QueryParams` key, so the single-page ABSENT case is correctly scoped.

Two behavior changes are worth attention (one DOM/forensic, one test-coverage), plus
some informational notes. No correctness or security blockers found.

## Narrative Findings (AI reviewer)

## Warnings

### WR-01: Desktop audit table now hides the event-id and action code behind a click-to-open `<details>` — silent forensic-affordance regression

**File:** `lib/sigra/admin/components.ex:766-772` (consumed at `lib/sigra/admin/live/audit_index_live.ex:167` and `lib/sigra/admin/live/audit_user_live.ex:190`)
**Issue:** In the pre-refactor desktop table (`HEAD~13`), the raw `code.sg-code` event id
rendered in the Occurred cell and the action code rendered in the Event cell — both
**visible by default**. The extracted `audit_table_row/1` relocates *both* codes into a
collapsed `<details><summary>Event codes</summary>...</details>` inside the Event cell.
On an audit/forensic surface, the raw event id and action code are precisely the
copy-pasteable evidence an operator reaches for, and they now require a per-row click to
reveal. This is a real UX/behavior change introduced by the refactor, not just a markup
move. The Playwright guard (`code.sg-code` `.count() === 2`) passes because `<details>`
keeps children attached to the DOM, so the regression in *default visibility* is invisible
to the test seam — the guard only proves presence, never default visibility.
**Fix:** Confirm the collapse is intended product behavior (the phase framing says "native
`<details>` disclosure", suggesting yes). If intended, this is acceptable — but the desktop
table previously surfaced the action code without interaction, so consider keeping the
action code visible and only collapsing the (long, noisy) event-id UUID:
```elixir
<div class="sg-cluster sg-cluster--2">
  <span class="sg-status-pill" data-tone={audit_tone(@row)}>{@row.action_label}</span>
  <span :if={@row.action_badge} class="sg-status-pill" data-tone="info">{@row.action_badge}</span>
</div>
<code class="sg-code">{@row.action}</code>
<details>
  <summary class="sg-text-sm sg-muted">Event id</summary>
  <code class="sg-code">{@row.id}</code>
</details>
```
At minimum, add a test asserting the codes are inside `<details>` *and* that `<summary>`
is keyboard-operable, so the affordance is a locked contract rather than an accident.

### WR-02: Pagination boundary test only exercises the global index — the per-user audit nav path is untested

**File:** `test/example/test/example_web/live/admin_audit_index_live_test.exs:130-178`
**Issue:** The new `multi_page?/1`-driven nav now lives in the shared
`audit_pagination_nav/1` and is consumed by **both** `AuditIndexLive` (href via
`page_path/3`) and `AuditUserLive` (href via `page_path/4` with `user_id`/`return_to`).
The ExUnit boundary test only covers the global index route (`/admin/audit?...`). The
per-user path (`/admin/users/:id/audit`) builds `prev_href`/`next_href` through a *different*
4-arity `page_path/4` that threads `return_to`, and that arity has zero ExUnit coverage for
the present/absent nav boundary. A bug in `AuditUserLive.page_path/4` (e.g., dropping the
cursor, or mangling `return_to` so the Next link 404s) would not be caught here. The
Playwright spec navigates the per-user audit but wraps the equivalence + nav assertions in
`if ((await userAuditDesktop.count()) > 0)` (admin-design.spec.ts:404), so on a seed where
the chosen user has <26 events the per-user nav assertions silently no-op.
**Fix:** Add a sibling ExUnit case that seeds >=26 events for a user and asserts the per-user
route renders `aria-label="Next page"` with an href that preserves both `cursor=` and
`return_to=`, e.g.:
```elixir
html = conn |> log_in_user(admin) |> get("/admin/users/#{subject.id}/audit?return_to=/admin/users") |> html_response(200)
assert html =~ ~s(aria-label="Next page")
assert html =~ "cursor="
assert html =~ "return_to="
```

## Info

### IN-01: `assertAuditResultEquivalence` asserts only desktop ⊆ mobile, never mobile ⊇ desktop for detail lines

**File:** `test/example/priv/playwright/tests/admin-design.spec.ts:166-198`
**Issue:** The mobile `audit_row/1` renders the `Actor:` detail line gated on `show_detail`
alone (components.ex:707), whereas the desktop `audit_table_row/1` gates *all* detail lines
on `@row.action_badge` (components.ex:778-779). For a non-impersonation row the desktop
Actor cell has one span and mobile has two — a genuine content divergence. The equivalence
guard only checks that desktop tokens appear in mobile (`expectTokensInBothContainers`
iterates desktop-derived tokens), so this asymmetry passes by construction and the guard
cannot detect a future case where mobile *drops* a line desktop still shows. This is a
pre-existing component asymmetry, not introduced by Phase 202, but the new equivalence
seam advertises "content-equivalent" while only proving one direction.
**Fix:** If true bidirectional equivalence is the contract, also assert the mobile-only
tokens (e.g. `Actor:`/`Effective user:` lines) appear in desktop, or document explicitly
that the guard is intentionally one-directional (desktop is the authoritative superset).

### IN-02: Duplicate `name="action_prefix"` / `name="outcome"` inputs in the same GET form rely on last-wins param coalescing

**File:** `lib/sigra/admin/live/audit_index_live.ex:75,99` and `lib/sigra/admin/live/audit_user_live.ex:98,110` (also `outcome` at 65/108 and 88/121)
**Issue:** The "Impersonation" quick-filter checkbox and the "Action prefix" text input both
emit `name="action_prefix"`; the "Failures" checkbox and the Outcome `<select>` both emit
`name="outcome"`. With both populated, GET submission yields two `action_prefix=` pairs and
Phoenix/Plug keeps the last occurrence (the text input, since it is later in source order).
This is pre-existing (both inputs existed before the `<details>` move), and the collapse
does not change submission semantics — collapsed `<details>` fields still submit. But it is
a latent footgun: reordering the markup silently flips which value wins, and a user who
checks "Impersonation" *and* types a different prefix gets only the typed prefix with no
indication the checkbox was ignored.
**Fix:** Out of scope for this phase. Track separately: either give the inputs distinct names
and merge in `QueryParams`, or sync the checkbox `checked` state to disable/clear the text
input.

### IN-03: `audit_pagination_nav/1` re-evaluates `multi_page?/1` and reads `@meta.previous_page`/`@meta.next_page` after the `:if` guard — fine, but the disabled-link branch is now unreachable

**File:** `lib/sigra/admin/components.ex:826-845`
**Issue:** The nav renders only when `multi_page?(@meta)` is true, i.e. at least one of
`previous_page`/`next_page` is non-nil. The inner `is-disabled` class / `aria-disabled="true"`
branches handle the case where one cursor is nil (legitimate: first/last page). That is
correct and reachable. No bug — flagging only to confirm the guard interaction was checked:
the `@meta && ...` short-circuit in both call sites prevents a `nil.previous_page` KeyError
when results fail to load. Verified safe.
**Fix:** None required.

### IN-04: `format_date/1` raise-on-unknown vs `format_timestamp/1` silent-empty-string are inconsistent siblings

**File:** `lib/sigra/admin/components.ex:911-926`
**Issue:** `format_date/1` raises `ArgumentError` on an unexpected type (deliberate, per the
T-158-01 mitigation comment), but the adjacent `format_timestamp/1` falls through to `""`
for any non-`%DateTime{}` value (line 912). The desktop table's Occurred column therefore
*silently renders blank* if `inserted_at` is ever a `%NaiveDateTime{}` or nil, while the
mobile card would raise loudly on the same row. Given the stated D-09 rationale ("must NOT
silently render a populated-but-wrong-typed value"), the two helpers should fail the same way.
**Fix:** Either make `format_timestamp/1` raise on unknown types for parity, or have it accept
`%NaiveDateTime{}` and `nil` the way `format_date/1` does. Low risk in practice (presenter
always supplies `%DateTime{}`), hence info-level.

---

_Reviewed: 2026-06-26_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
