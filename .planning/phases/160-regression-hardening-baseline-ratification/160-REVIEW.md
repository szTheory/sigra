---
phase: 160-regression-hardening-baseline-ratification
reviewed: 2026-06-05T14:06:36Z
depth: standard
files_reviewed: 6
files_reviewed_list:
  - lib/sigra/admin.ex
  - lib/sigra/admin/live/index_live.ex
  - lib/sigra/admin/live/organization_live.ex
  - lib/sigra/admin/live/users_index_live.ex
  - lib/sigra/admin/users/query.ex
  - test/example/priv/static/assets/css/app.css
findings:
  critical: 1
  warning: 4
  info: 2
  total: 7
status: issues_found
---

# Phase 160: Code Review Report

**Reviewed:** 2026-06-05T14:06:36Z
**Depth:** standard
**Files Reviewed:** 6
**Status:** issues_found

## Summary

This change set introduces a shared `Sigra.Admin.needs_review/1` helper (dedup of two
inline copies), rewires the "Review now" / "Locked" / "Review risky accounts" CTAs from
`?locked=true` to `?needs_review=true`, adds a `:needs_review` `or_where` clause to the
admin user query, adds `needs_review` to `@quick_filter_keys` plus a `chip_label`, and
adds a dark-mode `--sg-color-brand-strong` token override with a WCAG-AA intent.

The dedup helper is correct and the dark CSS token is well-formed. However, the
`needs_review` feature is **broken end-to-end**: the query key is never registered as an
allowed param or a Flop filter field, so the new `apply_filter` clauses are unreachable
dead code and `?needs_review=true` is silently ignored — every primary "review risky
accounts" CTA now navigates to the *full, unfiltered* user list. Separately, the
`or_where` implementation, if it were wired through, would break tenant scoping by ORing
past the base authorization `where`. There is no test coverage for the new filter path,
and a stale empty CSS rule was left behind.

## Critical Issues

### CR-01: `needs_review` filter is dead code — every "review risky accounts" CTA returns the full unfiltered user list

**File:** `lib/sigra/admin/users/query.ex:313-317`, `lib/sigra/admin/live/index_live.ex:56,78,115`, `lib/sigra/admin/live/organization_live.ex:67,114`

**Issue:** The change moved the primary risk CTAs from `?locked=true` to
`?needs_review=true` and added `apply_filter/3` clauses for `:needs_review`. But
`needs_review` is **not** in `@allowed_params` (`query.ex:12-27`), **not** in
`@filter_fields` (`query.ex:29-40`), and **not** in the Flop schema's `filterable` list
(`query.ex:49-60`).

Trace through `normalize_params/1`:
1. `Map.take(@allowed_params)` (line 106) drops `needs_review` because it is not listed.
2. `to_flop_params/1` calls `Flop.nest_filters(@filter_fields, ...)` (line 623) — only
   keys in `@filter_fields` are nested into Flop filters, so no
   `%Flop.Filter{field: :needs_review}` is ever constructed.
3. Consequently the new `apply_filter(query, %Flop.Filter{field: :needs_review, ...})`
   clauses at lines 313 and 317 are **never reached** (dead code).

Net effect: visiting `/admin/users?needs_review=true` applies **no filter at all** and
returns the entire authorized user set. The overview "{N} accounts need review → Review
now" notice, the "Review risky accounts" task card, and the global "Locked" stat tile all
now link to a view that shows *every* user (healthy accounts included) as if they need
review. This is a correctness/data-integrity regression in the exact CTA the phase set out
to wire — and it is also a security-signal failure: operators are told all users need
review.

No test exercises this path: `test/sigra/admin/users_query_test.exs:323-330` covers
`locked` and `deleted` individually but has zero coverage for `needs_review`.

**Fix:** Register the key on every layer that gates a filter through to `apply_filter`,
AND fix the `or_where` scoping defect (see WR-01) before doing so. Minimum wiring:

```elixir
# query.ex — @allowed_params
@allowed_params ~w(
  q organization page page_size order_by order_direction
  confirmed mfa passkeys locked deleted needs_review
  provider registered_from registered_to
)

# query.ex — @filter_fields
@filter_fields [
  :q, :organization, :confirmed, :mfa, :passkeys,
  :locked, :deleted, :needs_review, :provider,
  :registered_from, :registered_to
]

# Params @derive Flop.Schema filterable: [ ... :needs_review ... ]
# embedded_schema: field :needs_review, :boolean
```

Then add a query test that asserts `%{"needs_review" => "true"}` returns exactly
`locked ∪ deleted` ids (and that it stays inside org scope for an org-scoped admin).
Until the filter actually works, the alternative is to revert the CTAs back to
`?locked=true` rather than ship a no-op filter behind the primary risk CTA.

## Warnings

### WR-01: `or_where` for `needs_review` breaks tenant scoping and broadens the authorized set

**File:** `lib/sigra/admin/users/query.ex:313-315`

**Issue:** Per Ecto semantics (`deps/ecto/lib/ecto/query.ex:1865-1889`), `or_where`
combines with **all** previous `where` expressions using `OR` — the new condition is ORed
against the conjunction of every prior where clause, including the base scoping clauses.

`base_query/3` enforces authorization with `where` clauses:
- Organization scope: `from user ..., where: user.id in subquery(membership_user_ids_query(...))` (`query.ex:214-215`)
- Global scope: `Authorizer.scope_query(user_schema, admin_scope)` (`query.ex:204`)

`apply_filters/3` reduces filters with `where`/`or_where` over that base
(`query.ex:224-225`). If the `needs_review` filter is ever reached (after CR-01 is fixed),
the resulting SQL becomes:

```sql
WHERE (<base scope> AND <other active filters>) OR (locked_at IS NOT NULL OR deleted_at IS NOT NULL)
```

The trailing `OR (locked OR deleted)` escapes the base scope `where`, so an
organization-scoped admin would see locked/deleted users from **other organizations**, and
any concurrently-applied filter (e.g. `confirmed=true`) is also short-circuited. This is a
tenant-isolation / authorization-broadening defect — exactly the "must not broaden beyond
locked ∪ deleted within scope" invariant called out for this phase. It is latent only
because CR-01 prevents the clause from executing; fixing CR-01 without fixing this makes
it live.

**Fix:** Use `where` with an internal disjunction so the condition is ANDed against the
scope, not ORed past it:

```elixir
defp apply_filter(query, %Flop.Filter{field: :needs_review, value: true}, _helpers) do
  where(query, [user: user], not is_nil(user.locked_at) or not is_nil(user.deleted_at))
end
```

### WR-02: "Locked" stat tile mislabels its destination

**File:** `lib/sigra/admin/live/index_live.ex:112-116`

**Issue:** The global overview "Locked" stat tile shows `@summary_counts.locked` (locked
count only) but links to `?needs_review=true`, whose intended result is locked ∪ deleted.
Meanwhile the adjacent "Deleted" tile (line 117-121) links to `?deleted=true`. So clicking
a tile labeled "Locked" with a locked-only count would (once the filter works) land on a
list that also includes deletion-scheduled accounts — count and label no longer match the
landing view, and the two tiles are inconsistent. The org overview has the same issue at
`organization_live.ex:111-115`.

**Fix:** Either link the "Locked" tile to `?locked=true` (label-accurate) and keep
`?needs_review=true` reserved for the explicit "Review risky accounts" CTA, or relabel the
tile. Prefer `?locked=true` for the stat tile:

```elixir
<.stat_link label="Locked" value={Map.get(@summary_counts, :locked, 0)} href="/admin/users?locked=true" />
```

### WR-03: No test coverage for the new `needs_review` filter or its CTA wiring

**File:** `test/sigra/admin/users_query_test.exs` (absent coverage), `lib/sigra/admin/users/query.ex:313-317`

**Issue:** The new filter clause, the `@quick_filter_keys` addition, and the rewired CTAs
have zero test coverage. The existing filter contract test
(`users_query_test.exs:323-330`) asserts `locked` and `deleted` separately but never
`needs_review`. This is precisely why CR-01 (a no-op filter) and WR-01 (scope escape)
shipped undetected. For a security surface, the absence of a test asserting "needs_review
returns exactly locked ∪ deleted, scoped" is a defect.

**Fix:** Add an assertion to the filter test, e.g.:

```elixir
assert_ids(ctx, %{"needs_review" => "true"}, Enum.sort([ctx.bob.id, ctx.carol.id]))
# and an org-scoped variant proving no cross-tenant leakage
```

### WR-04: Stale empty CSS rule left inside dark-mode media query

**File:** `test/example/priv/static/assets/css/app.css:893-896`

**Issue:** The dark-mode `--sg-color-brand-strong` override (lines 170-173) correctly
supersedes the old scoped chip fix, and the comment at 889-892 says "Scoped override
removed — no duplication." But the removal left an empty rule:

```css
@media (prefers-color-scheme: dark) {
  .sg-filter-chip:has(input:checked) {
  }
}
```

An empty selector + empty media block is dead code that some CSS linters/minifiers flag
and that misleads future readers into thinking a dark override still exists here.

**Fix:** Delete lines 893-896 entirely (the comment at 889-892 can stay or be trimmed to a
one-liner). The global token override already covers this surface, so no unlayered
component rule is needed — that part of the design-system intent is satisfied.

## Info

### IN-01: `needs_review/1` helper hardcodes `:locked`/`:deleted` keys with no guard against drift

**File:** `lib/sigra/admin.ex:10-12`

**Issue:** The dedup is correct and the two call sites
(`index_live.ex:36`, `organization_live.ex:45`) now share one implementation — good. But
the helper silently `Map.get(..., 0)`s two specific keys produced by
`Query.summary_counts/2` (`query.ex:159-167`). If a future count key is renamed, this
returns a quietly-wrong total rather than failing. Low risk given current call sites;
noting for maintainability.

**Fix:** Optional — add a brief `@spec needs_review(map()) :: non_neg_integer()` and a doctest
pinning the `{locked, deleted}` contract so the coupling is explicit.

### IN-02: Dark `--sg-color-brand-strong` (`#fdba74`) WCAG-AA intent is plausible but unverified against all brand-soft surfaces

**File:** `test/example/priv/static/assets/css/app.css:170-173`

**Issue:** The override token is applied globally and the comment claims it clears AA on
the dark `--sg-color-brand-soft` chip tint (`rgba(243,90,16,0.16)` over panel `#1f1d1a`).
`#fdba74` on that effective background is a reasonable AA pass, but the same token is also
used as foreground on `--sg-color-brand-soft` in `.sg-applied-chip` (line 906),
`.sg-badge--brand` (line 454), and several link/hover states (e.g. 365, 414, 522, 603,
713). The dark override is uniform, so the change is consistent (no unlayered rules
introduced), but contrast on every reuse was not independently confirmed here.

**Fix:** Optional — spot-check `#fdba74` against the dark `--sg-color-brand-soft` and dark
`--sg-color-panel` for the `.sg-applied-chip` and `.sg-badge--brand` foregrounds to
confirm AA holds on each surface, not just the filter chip.

---

_Reviewed: 2026-06-05T14:06:36Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
