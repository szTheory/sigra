---
phase: 159-cross-journey-coherence-sweep-seed-enrichment
reviewed: 2026-06-04T00:00:00Z
depth: standard
files_reviewed: 9
files_reviewed_list:
  - lib/sigra/admin/components.ex
  - lib/sigra/admin/live/organization_live.ex
  - lib/sigra/admin/organizations/detail.ex
  - test/example/lib/example/demo/personas.ex
  - test/example/lib/example/demo/seeds.ex
  - test/example/priv/playwright/tests/admin-coherence-sweep.spec.ts
  - test/example/priv/static/assets/css/app.css
  - test/example/test/example/demo/personas_test.exs
  - test/example/test/example/demo/seeds_test.exs
findings:
  critical: 2
  warning: 6
  info: 3
  total: 11
status: issues_found
---

# Phase 159: Code Review Report

**Reviewed:** 2026-06-04
**Depth:** standard
**Files Reviewed:** 9
**Status:** issues_found

## Summary

Phase 159 introduces a canonical admin component set (`Sigra.Admin.Components`), an
org-scoped overview LiveView + data layer, a nine-persona demo seed pipeline, and a
behavior-only Playwright "coherence sweep" spec. The Elixir data/seed layer is largely
sound: idempotency guards, fail-closed authorization, and deterministic fixtures are
handled carefully and are well-covered by the two ExUnit suites.

The serious problems are in the new Playwright spec, which asserts a CSS class
(`.sg-scope-ribbon`) that **no component or markup in the codebase ever emits**, and on
the org-overview screen asserts a scope ribbon that the LiveView does not render at all.
As written, the spec's primary coherence assertion fails on five of six screens — it
cannot pass against the real DOM. A second, weaker problem is that the GATE-03 motion
assertion is tautological and passes regardless of whether the CSS guard is correct.

There are also several robustness gaps in the lib layer (NaiveDateTime handling in the
invitation row shaper, divergent `format_date/1` semantics, unguarded path helpers) and
a swallowed transaction result in the seed orchestrator.

## Critical Issues

### CR-01: Playwright spec asserts `.sg-scope-ribbon`, a class that is never rendered

**File:** `test/example/priv/playwright/tests/admin-coherence-sweep.spec.ts:89,104,120,127,132`
**Issue:**
The spec asserts `page.locator('.sg-scope-ribbon')` is visible on screens 2, 3, 4, 5, and
6. No source file in the repository ever emits the class `sg-scope-ribbon`. The
`scope_ribbon/1` component (the only producer of the scope indicator) renders:

```elixir
# lib/sigra/admin/components.ex:259-263
def scope_ribbon(assigns) do
  ~H"""
  <span class={["sg-muted sg-text-sm", @class]} {@rest}>{@copy}</span>
  """
end
```

A repo-wide grep confirms `sg-scope-ribbon` appears **only** inside this spec file — never
in `lib/`, never in the CSS. Every `.sg-scope-ribbon` `toBeVisible()` assertion will time
out and fail. This is not a flaky test; it is a guaranteed failure that defeats the entire
purpose of the coherence sweep (verifying the scope indicator is present across screens).

Compounding this on screen 2 (`/admin/organizations/acme-corp`): `OrganizationLive.render/1`
does **not** call `<.scope_ribbon>` anywhere, so even a corrected selector
(`.sg-muted.sg-text-sm`) would not find a scope ribbon on the org overview — that screen
ships no scope indicator at all.

**Fix:** Either (a) give the `scope_ribbon/1` component a stable, dedicated hook class and
update call sites:

```elixir
def scope_ribbon(assigns) do
  ~H"""
  <span class={["sg-scope-ribbon sg-muted sg-text-sm", @class]} {@rest}>{@copy}</span>
  """
end
```

or (b) change the spec to assert the class the component actually emits, scoped to the
ribbon copy (e.g. `getByText(...)` or a `data-*` hook). Whichever path is chosen, add a
`<.scope_ribbon>` to `OrganizationLive.render/1` (or drop the screen-2 assertion at line
89) so the org-overview screen actually satisfies the contract it is being tested against.

### CR-02: Org overview path helpers crash on a non-org (global) scope while the header silently degrades

**File:** `lib/sigra/admin/live/organization_live.ex:200-204`
**Issue:**
`users_path/1` and `audit_path/1` only match a `%Scope{organization_slug: slug}` where
`slug` is a binary; they have no catch-all clause:

```elixir
defp users_path(%Scope{organization_slug: slug}) when is_binary(slug),
  do: "/admin/organizations/#{slug}/users"
defp audit_path(%Scope{organization_slug: slug}) when is_binary(slug),
  do: "/admin/organizations/#{slug}/audit"
```

These are invoked unconditionally during `render/1` (lines 65, 76, 82, 93-112). If this
LiveView is ever reached with `organization_slug: nil` (global scope, or a partially
populated scope), every render path raises `FunctionClauseError` and crashes the LiveView
mid-render. This is inconsistent with `organization_name/1` (line 196-198), which *does*
fail soft to `"Organization"` — signaling the author anticipated a nil-slug scope. The
result is a header that renders "Organization" followed by an immediate crash when the
first path helper is hit, rather than a clean degradation or an explicit guard at mount.

**Fix:** Fail fast and explicitly at `mount/1` if the scope is not org-scoped, or give the
path helpers a defined nil-slug behavior. Preferred — guard at mount:

```elixir
def mount(_params, _session, socket) do
  admin_scope = socket.assigns.admin_scope

  if is_nil(admin_scope.organization_slug) do
    raise ArgumentError,
          "OrganizationLive requires an organization-scoped admin_scope; got #{inspect(admin_scope)}"
  end
  # ... existing body
end
```

This converts a confusing mid-render `FunctionClauseError` into a clear contract violation
at the boundary, and keeps the header/path-helper assumptions consistent.

## Warnings

### WR-01: `shape_invitation_row/2` raises on `%NaiveDateTime{}` expiry values from host schemas

**File:** `lib/sigra/admin/organizations/detail.ex:117-128`
**Issue:**
`expired?` is computed with `DateTime.compare(expires_at, now)`. `DateTime.compare/2`
raises `ArgumentError` if either argument is a `%NaiveDateTime{}`. `Detail` is a
**library** module resolving **host** schemas by namespace inference; a host whose
`OrganizationInvitation.expires_at` is `:naive_datetime` (a common Ecto default) will crash
the org overview. That NaiveDateTime is a live possibility here is corroborated by
`OrganizationLive.format_date/1` (line 192) explicitly handling `%NaiveDateTime{}`. The
`@type invitation_row` annotation only admits `DateTime.t() | nil`, masking the gap.

**Fix:** Normalize or branch on the value type before comparing:

```elixir
expired? =
  case expires_at do
    %DateTime{} = dt -> DateTime.compare(dt, now) == :lt
    %NaiveDateTime{} = ndt -> NaiveDateTime.compare(ndt, DateTime.to_naive(now)) == :lt
    nil -> false
  end
```

### WR-02: GATE-03 motion assertion is tautological — passes even if the CSS guard regresses

**File:** `test/example/priv/playwright/tests/admin-coherence-sweep.spec.ts:140-145`
**Issue:**
The test focuses `label.sg-filter-chip`, reads `getComputedStyle(el).transition`, and
asserts it does not contain `'transform'`. In a non-`pointer:fine` environment the base
`.sg-filter-chip` rule (`app.css:858`) declares **no** `transition` property at all, so the
computed value is the UA default (`all 0s ease 0s`), which can never contain the substring
`transform`. The assertion therefore passes whether the `@media (hover: hover) and (pointer:
fine)` guard at `app.css:870` is present, absent, broken, or the transition is removed
entirely. It does not actually verify the GATE-03 contract (that the transform transition is
suppressed for keyboard/touch users) — it would pass for code that violates that contract.

**Fix:** Make the assertion discriminating — verify the transition IS present under
`pointer: fine` and absent otherwise, e.g. by emulating media via
`page.emulateMedia()` is not sufficient for `pointer`/`hover`; instead assert the positive
case (focus does not apply a transform) by reading the computed `transform` after focus, or
add a Playwright project that emulates a fine pointer and assert the transition contains
`transform` there while the default project asserts it does not. At minimum, assert the
chip has the expected `transition` *value* under each condition rather than a substring of
the UA default.

### WR-03: `OrganizationLive.format_date/1` silently swallows wrong-typed values that the canonical component is designed to reject

**File:** `lib/sigra/admin/live/organization_live.ex:191-194`
**Issue:**
This LiveView defines a private `format_date/1` with a silent catch-all:

```elixir
defp format_date(_), do: "—"
```

The canonical `Sigra.Admin.Components.format_date/1` (`components.ex:411-414`) was
deliberately changed (per its own moduledoc, "T-158-01 mitigation", "the catch-all must NOT
silently render a populated-but-wrong-typed value") to `raise ArgumentError` on unknown
types. This LiveView re-introduces exactly the silent fallback the component set was created
to eliminate, so a populated-but-mistyped `expires_at` renders as an em dash instead of
surfacing the bug — the divergence the phase set out to retire.

**Fix:** Drop the local helper and reuse the canonical component behavior. If a date helper
is still needed inline, mirror the component's strict semantics (handle `%DateTime{}`,
`%NaiveDateTime{}`, `nil`; raise otherwise) rather than a silent `_ -> "—"`.

### WR-04: Seed transaction result is discarded — a rolled-back audit batch reports success

**File:** `test/example/lib/example/demo/seeds.ex:625-678`
**Issue:**
`insert_audit_batch/3` wraps the batch in `Repo.transaction/1` but discards the
`{:ok, _} | {:error, _}` return. `seed_audit_events/2` and `run/0` always return `:ok`. The
in-code comment explicitly notes that idempotency depends on the batch being all-or-nothing
("A mid-batch crash would otherwise leave <15 rows … the next run/0 re-fires and accumulates
duplicates indefinitely"). If the transaction fails and rolls back, `run/0` still returns
`:ok`, so the operator believes seeding succeeded while the audit trail is empty — and the
next run re-fires. The failure mode the transaction guards against is silently reported as
success.

**Fix:** Match on the transaction result and fail loudly:

```elixir
case Repo.transaction(fn -> ... end) do
  {:ok, _} -> :ok
  {:error, reason} -> raise "demo audit seed batch failed: #{inspect(reason)}"
end
```

### WR-05: "needs review" count includes deleted accounts but the CTA only filters locked

**File:** `lib/sigra/admin/live/organization_live.ex:65,206-208`
**Issue:**
`needs_review/1` returns `locked + deleted`:

```elixir
defp needs_review(counts) do
  Map.get(counts, :locked, 0) + Map.get(counts, :deleted, 0)
end
```

but the alarm CTA links only to `users_path(@admin_scope) <> "?locked=true"` (line 65). When
`deleted > 0` and `locked == 0`, the banner reads "N accounts need review — Review now", yet
"Review now" lands on a filtered list that excludes every account that drove the count. The
count and the destination disagree, which can read as a broken alarm to an operator.

**Fix:** Either scope the count to what the CTA actually surfaces (count locked only), or
point the CTA at a filter that covers both populations (e.g. a combined "needs review"
filter, or split into two signals). If the intent is genuinely "locked OR deletion-
scheduled", the link must reflect that set.

### WR-06: `upsert_organization/3` `Repo.insert/2` clause is non-exhaustive under a real conflict

**File:** `test/example/lib/example/demo/seeds.ex:203-206`
**Issue:**
```elixir
case Repo.insert(changeset, on_conflict: :nothing) do
  {:ok, %Organization{id: nil}} -> Repo.get_by!(Organization, slug: slug)
  {:ok, org} -> org
end
```

This case has no `{:error, changeset}` clause. `on_conflict: :nothing` suppresses the
partial-unique conflict, but any *other* changeset/DB validation failure (or a constraint
not covered by the partial index) returns `{:error, _}` and raises `CaseClauseError` with a
message that obscures the real cause. The check-then-insert above narrows the window but a
concurrent insert between the `get_by` and `insert` is exactly when the conflict path fires,
and a failed insert for any other reason is unhandled.

**Fix:** Add an explicit error clause:

```elixir
{:error, cs} -> raise "failed to seed organization #{slug}: #{inspect(cs.errors)}"
```

## Info

### IN-01: `summary_chip/1` and `stat/1` use `<dt>`/`<dd>` outside a `<dl>` wrapper

**File:** `lib/sigra/admin/components.ex:139-146`
**Issue:**
`summary_chip/1` wraps `<dt>`/`<dd>` in a plain `<div class="sg-metric">`, not a `<dl>`.
`<dt>`/`<dd>` are only valid as children of `<dl>` (or a `<div>` that is itself a child of a
`<dl>`). As written, this is invalid HTML and breaks the definition-list semantics the
docstring claims ("definition-list semantics"). `stat/1` (line 79) correctly uses `<dl>`,
so the two KPI components are inconsistent.

**Fix:** Wrap in `<dl class={["sg-metric", @class]}>` to match `stat/1`, or use
non-list elements (`<span>`/`<span>`) if the list semantics are not actually wanted.

### IN-02: `print_credentials/0` recomputes `feature_map/0` once per persona

**File:** `test/example/lib/example/demo/seeds.ex:63-72`
**Issue:**
`Personas.feature_map()` is rebuilt inside the `Enum.each` lambda for every persona. It is a
pure constant map; building it nine times is wasteful and slightly obscures intent.
(Correctness only — not a perf-scope finding.)

**Fix:** Hoist it: `features = Personas.feature_map()` before the loop and index into it.

### IN-03: Duplicate `background` declaration on `.sg-empty-state`

**File:** `test/example/priv/static/assets/css/app.css:750,1015`
**Issue:**
`.sg-empty-state` receives `background: var(--sg-color-panel)` from the shared group at line
750 and then `background: var(--sg-color-panel)` again at line 1015. The two rules are not in
conflict (same value), but the redundant declaration is dead/duplicated style that can drift
if one site is later edited.

**Fix:** Remove the redundant `background` from the `.sg-empty-state` block at line 1015, or
remove `.sg-empty-state` from the shared selector group at line 750 if the dashed-panel
treatment should own its own background.

---

_Reviewed: 2026-06-04_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
