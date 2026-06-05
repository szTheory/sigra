---
phase: 157-overview-landings-highest-effort
reviewed: 2026-06-04T00:00:00Z
depth: standard
files_reviewed: 5
files_reviewed_list:
  - lib/sigra/admin/live/index_live.ex
  - lib/sigra/admin/live/organization_live.ex
  - test/example/test/example_web/admin_shell_test.exs
  - test/example/priv/playwright/tests/admin-checkpoints.spec.ts
  - guides/reference/admin-design-contract.md
findings:
  critical: 0
  warning: 5
  info: 4
  total: 9
status: issues_found
---

# Phase 157: Code Review Report

**Reviewed:** 2026-06-04
**Depth:** standard
**Files Reviewed:** 5
**Status:** issues_found

## Summary

Reviewed the Phase 157 redesign of the two admin Overview LiveViews into a
deferred-load "front-door" archetype. The core mechanic under scrutiny — the
`connected?(socket)` mount gate — is correct: the disconnected path assigns
loading state plus empty/zeroed structs and performs no DB queries, while the
connected path runs the queries inline. The redesigned `render/1` is nil/empty
safe during the loading frame (`needs_review/1` tolerates `%{}`, the alarm
`<.notice>` is gated by `:if={not @loading}`, and lists default to `[]`). The
Playwright wait-guard correctly waits for `.sg-metric-link__value` rather than
just `.phx-connected`, which closes the documented skeleton-frame race.
`@admin_scope` is verified to be a `%Sigra.Admin.Scope{}` struct, so the
`users_path/1` and `audit_path/1` pattern matches in `organization_live.ex`
resolve.

No BLOCKER-class defects were proven. The findings below are correctness/quality
issues: a misleading count-to-link mapping in the alarm notice (both views), a
skeleton shape mismatch in the org view that defeats the stated purpose of the
loading placeholder, a latent date-type fragility, and several vacuous test
assertions that provide false coverage confidence.

## Warnings

### WR-01: Alarm count includes deleted accounts but deep-links to locked-only filter

**File:** `lib/sigra/admin/live/index_live.ex:54-56,157-159`, `lib/sigra/admin/live/organization_live.ex:64-66,203-205`
**Issue:** `needs_review/1` sums two distinct states:
`Map.get(counts, :locked, 0) + Map.get(counts, :deleted, 0)`. The alarm copy
("N accounts need review") is then deep-linked to `?locked=true` only
(`/admin/users?locked=true` global; `users_path(@admin_scope) <> "?locked=true"`
org). `locked` and `deleted` are separate, independent boolean filters in
`Sigra.Admin.Users.Query` (`apply_filter/3` for `:deleted` at query.ex:306-309;
`:locked` is a separate clause). A user that is deletion-scheduled but **not**
locked contributes to the alarm count yet is invisible at `?locked=true` — the
reviewer clicks "Review now" and the count does not reconcile with the list.
This is a count/destination mismatch, not a styling nit: the alarm's whole job
is to be a trustworthy entry point into a filtered list.
**Fix:** Make the deep-link match the count composition. Either link to a
combined view (`?locked=true&deleted=true` if the query supports OR semantics —
it currently AND-composes filters, so this would show only locked-AND-deleted,
which is also wrong), or split the alarm into two reconciling segments, or
narrow `needs_review/1` to `:locked` only so the count and link agree:
```elixir
defp needs_review(counts), do: Map.get(counts, :locked, 0)
```
Pick the semantics deliberately; today the count and the link disagree.

### WR-02: Org posture-strip skeletons do not match the shape they replace

**File:** `lib/sigra/admin/live/organization_live.ex:91`
**Issue:** The org posture strip renders bare `<.skeleton />` placeholders during
load, while `index_live.ex:89-94` correctly renders
`<.skeleton class="sg-metric-link" />` so the loading shape matches the
`stat_link` (`sg-metric-link`) it will be replaced by. Per the design contract
(skeleton "Job": *"Loading placeholder that matches the shape of the content it
will replace"*), the unclassed org skeletons collapse to default `sg-skeleton`
sizing and produce visible layout shift when the connected frame swaps in the
sized `stat_link`s. The two Overviews are supposed to be "byte-coherent across
Global and Org" for items 1–4 of the archetype (contract line 167); this
diverges.
**Fix:** Mirror the global view:
```elixir
<.skeleton class="sg-metric-link" /><.skeleton class="sg-metric-link" />
<.skeleton class="sg-metric-link" /><.skeleton class="sg-metric-link" />
<.skeleton class="sg-metric-link" />
```
The Members (line 125-126) and Pending invitations (line 147-148) skeletons are
likewise unshaped; size them to the `sg-list-row` they replace.

### WR-03: `format_date/1` silently swallows non-`DateTime` timestamps

**File:** `lib/sigra/admin/live/organization_live.ex:190-191`
**Issue:** `format_date(%DateTime{})` is the only formatting head;
`format_date(_) -> "—"`. `invitation.expires_at` comes from host-app data via
`Detail.shape_invitation_row/2` (`Map.get(invitation, :expires_at)`), which is
typed only as `DateTime.t() | nil`. The example app uses `:utc_datetime` (loads
as `%DateTime{}`), so tests pass — but Ecto's `:naive_datetime` (an equally
valid, common timestamp type for host schemas) loads as `%NaiveDateTime{}` and
would render every non-expired invitation's expiry as "—" with no error and no
test signal. This is lib-owned code reading host-controlled data; the silent
fallback masks a real misconfiguration.
**Fix:** Handle `NaiveDateTime` (and optionally `Date`) explicitly so a
mis-typed host column degrades visibly or correctly:
```elixir
defp format_date(%DateTime{} = dt), do: Calendar.strftime(dt, "%Y-%m-%d")
defp format_date(%NaiveDateTime{} = dt), do: Calendar.strftime(dt, "%Y-%m-%d")
defp format_date(nil), do: "—"
defp format_date(other), do: raise ArgumentError, "unexpected expires_at: #{inspect(other)}"
```
At minimum support `NaiveDateTime`; the catch-all "—" should not absorb a
populated-but-wrong-typed value.

### WR-04: Vacuous `refute` assertions give false coverage confidence

**File:** `test/example/test/example_web/admin_shell_test.exs:171,187,219,247-248`
**Issue:** Several negative assertions can never fail because the asserted strings
are never produced by either LiveView in any state:
- `refute html =~ "sg-posture-strip__risk"` (lines 171, 187, 218, 247) — this
  class was removed from both strips per the design contract (contract line
  170). It is not rendered on load **or** connected, so the refute is dead.
- `refute html =~ "Scoped attention"` (lines 219, 248) — this literal does not
  appear anywhere in `organization_live.ex`.

Dead refutes look like regression guards but assert nothing; if a future change
reintroduced a risk pill, only the `__risk` variant would be (accidentally)
caught, and "Scoped attention" is uncatchable. The skeleton/data-frame guards
in the same tests (`assert html =~ "sg-skeleton"` /
`refute html =~ "sg-metric-link__value"`) are the assertions doing real work.
**Fix:** Replace the dead refutes with assertions that exercise the actual
loading-vs-loaded contract, e.g. assert the alarm `<.notice>` is absent on the
disconnected frame (`refute html =~ ~s(role="status")` on the GET path) and
present on the connected frame — that directly verifies the `:if={not @loading}`
gate rather than asserting never-rendered strings.

### WR-05: `role="status"` on a load-present notice contradicts the documented ARIA contract

**File:** `lib/sigra/admin/live/index_live.ex:49-53`, `lib/sigra/admin/live/organization_live.ex:59-63`
**Issue:** The alarm carries `role="status"`. The design contract's own `notice`
entry (contract line 113) states a live-region role is for *"genuinely post-load
dynamic notices"* and warns `role="status"` *"is for post-load updates (MDN) and
risks duplicate announcements on LiveView re-render."* But with the
`connected?` gate, the notice is **not** an async update injected after first
paint — on the connected mount it is present in the very first connected render
(the `:if={not @loading}` branch evaluates true from frame one of the connected
DOM). A `status` live region that is present at the time the region is created
is announced once on insertion and then again on any LiveView re-render of that
subtree, which is exactly the duplicate-announcement failure mode the contract
calls out. The role is being used to satisfy a test (`assert html =~ role="status"`)
rather than to mark a true post-load update.
**Fix:** Either (a) drop `role="status"` and rely on the visual/textual tone as
the contract prescribes for load-present notices, or (b) if a live announcement
is genuinely wanted, render the notice with an empty live region on the loading
frame and populate it on the connected frame so the region pre-exists and only
its content changes (the only pattern that announces once). Update the test in
lockstep. Do not keep a `status` region that is born populated.

## Info

### IN-01: Hardcoded deep-link paths in the global Overview

**File:** `lib/sigra/admin/live/index_live.ex:56,96-120`
**Issue:** Global Overview hardcodes `/admin/users`, `/admin/audit`,
`/admin/users?locked=true`, etc. as string literals, while the org view derives
them via `users_path/1`/`audit_path/1`. Hardcoded admin-mount paths break if the
host mounts the admin router at a non-default prefix.
**Fix:** Centralize the admin base path (verified router helper or a single
private path builder) so a remounted admin scope does not produce dead links.
Low priority for v1 if the admin mount path is fixed by convention.

### IN-02: `runtime_config!/0` duplicated verbatim across both LiveViews

**File:** `lib/sigra/admin/live/index_live.ex:161-174`, `lib/sigra/admin/live/organization_live.ex:207-221`
**Issue:** The two `runtime_config!/0` implementations are identical except for
the error-message prefix string. Duplicated config-resolution logic drifts.
**Fix:** Extract to a shared helper (e.g. `Sigra.Admin.runtime_config!/1` taking
a label) used by both Overviews and any future admin LiveView.

### IN-03: `needs_review/1` duplicated across both LiveViews

**File:** `lib/sigra/admin/live/index_live.ex:157-159`, `lib/sigra/admin/live/organization_live.ex:203-205`
**Issue:** Byte-identical private function in both modules. If WR-01 is fixed in
one place, the other will silently diverge.
**Fix:** Move `needs_review/1` into a shared module so the alarm semantics stay
coherent across Global and Org per the "same job → same component" principle.

### IN-04: `role_tone/1` maps `:owner` and `:admin` to the same tone

**File:** `lib/sigra/admin/live/organization_live.ex:173-178`
**Issue:** Both `"owner"` and `"admin"` return `"info"`, so the status pill
renders identically for the two roles; only the text label distinguishes them.
Likely intentional, but flagged because the parallel `role_label/1` does
distinguish them and a reviewer cannot tell the tone collapse is deliberate.
**Fix:** If owner vs admin should read differently at a glance, give owner a
distinct tone; otherwise add a one-line comment that the shared tone is
intentional.

---

_Reviewed: 2026-06-04_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
