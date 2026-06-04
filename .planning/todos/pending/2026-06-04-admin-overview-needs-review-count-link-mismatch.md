---
created: 2026-06-04T00:00:00.000Z
status: pending
title: needs-review alarm count includes deleted accounts but deep-links to locked-only filter
area: lib/sigra/admin/live
files:
  - lib/sigra/admin/live/index_live.ex
  - lib/sigra/admin/live/organization_live.ex
source: 157-REVIEW.md (WR-01, IN-03)
---

## Finding (Phase 157 code review, WR-01 + IN-03)

`needs_review/1` sums two distinct states:
`Map.get(counts, :locked, 0) + Map.get(counts, :deleted, 0)`. The alarm copy
("N accounts need review") deep-links to `?locked=true` only. `locked` and
`deleted` are independent boolean filters in `Sigra.Admin.Users.Query`
(`apply_filter/3` AND-composes them). A deletion-scheduled-but-not-locked
account inflates the count yet is invisible at `?locked=true` — the count and
the link destination disagree.

This logic is **pre-existing** (present at base commit d0371b7e, line 129/55) —
Phase 157 only promoted the alarm to the front-door position (LAND-01). It was
therefore out of scope for the 157 remediation pass, but it now sits in the
headline alarm of both Overviews, so it matters more than before.

IN-03: `needs_review/1` is byte-identical in both LiveViews — fix one place and
the other silently diverges.

## Risk

The headline alarm's whole job is to be a trustworthy entry point into a filtered
list. Today a reviewer can click "Review now" and the count will not reconcile
with the rows shown.

## How to apply

Pick the semantics deliberately (do not guess-fix — the query AND-composes
filters, so `?locked=true&deleted=true` would show only locked-AND-deleted, which
is also wrong):
- Narrow `needs_review/1` to `:locked` only so count and link agree, OR
- Split the alarm into two reconciling segments (locked + deletion-scheduled)
  each linking to its own filter, OR
- Add OR-filter support to `Users.Query` and link to a true combined view.

Then extract `needs_review/1` into a shared admin module (per "same job → same
component") so the two Overviews cannot drift.
