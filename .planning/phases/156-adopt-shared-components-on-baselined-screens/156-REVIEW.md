---
phase: 156-adopt-shared-components-on-baselined-screens
reviewed: 2026-06-04T00:00:00Z
depth: standard
files_reviewed: 6
files_reviewed_list:
  - lib/sigra/admin/live/audit_index_live.ex
  - lib/sigra/admin/live/index_live.ex
  - lib/sigra/admin/live/organization_live.ex
  - lib/sigra/admin/live/user_show_live.ex
  - lib/sigra/admin/live/users_index_live.ex
  - test/example/priv/static/assets/css/app.css
findings:
  critical: 0
  warning: 3
  info: 4
  total: 7
status: issues_found
---

# Phase 156: Code Review Report

**Reviewed:** 2026-06-04T00:00:00Z
**Depth:** standard
**Files Reviewed:** 6
**Status:** issues_found

## Summary

Phase 156 migrates five admin LiveViews onto the shared `Sigra.Admin.Components`
set: importing the module, deleting the per-LiveView private `metric_link`,
`task_card`, and `summary_chip` defs, and swapping inline markup for
`<.stat_link>`, `<.task_card>`, `<.summary_chip>`, `<.applied_chip>`,
`<.empty_state>`, `<.notice>`, `<.scope_ribbon>`, and `<.page_back>`. The
`summary_alert/1` tone changed from string (`"risk"`/`"warn"`) to atom
(`:risk`/`:warn`) to match the `notice/1` attr contract, and the CSS merged the
duplicate `.sg-notice[data-tone]` block into the shared `.sg-list-row[data-tone]`
selectors.

The mechanical swaps are largely faithful. The atom-vs-string tone change is
correct: `notice/1` declares `attr :tone, :atom, values: [:ok, :warn, :risk,
:info, nil]`, and `data-tone={@tone}` renders the atom to its string form, which
the CSS `[data-tone="risk"]` selectors match — the existing golden test
(`components_test.exs:150`) confirms `:risk` → `data-tone="risk"`. The CSS
consolidation is byte-equivalent (the merged shared-selector rules carry the
same declarations the deleted `.sg-notice` rules did), so it is behavior-
preserving.

The key concern is the `<.notice>` migration: the `notice/1` component wraps its
slot in a `<p class="sg-text-sm">`, but both new call sites pass block-level
`<p>` elements as children, producing invalid nested-`<p>` HTML. This is a real
DOM-correctness regression that the component's own golden test does not catch
(it only exercises a plain-string body). Details below.

## Warnings

### WR-01: `<.notice>` wraps a `<p>` body, creating invalid nested `<p>` in two call sites

**File:** `lib/sigra/admin/live/user_show_live.ex:131-133`, `lib/sigra/admin/live/organization_live.ex:73-78`
**Issue:**
The `notice/1` component renders its slot inside a paragraph:

```elixir
# components.ex:301-307
def notice(assigns) do
  ~H"""
  <div class={["sg-notice", @class]} data-tone={@tone} {@rest}>
    <p class="sg-text-sm">{render_slot(@inner_block)}</p>
  </div>
  """
end
```

Both new call sites pass `<p>` elements *as the slot body*:

`user_show_live.ex:131-133`
```heex
<.notice :if={summary_alert(@detail)} tone={elem(summary_alert(@detail), 0)}>
  <p class="sg-text-sm">{elem(summary_alert(@detail), 1)}</p>
</.notice>
```
renders to `<p class="sg-text-sm"><p class="sg-text-sm">…</p></p>`.

`organization_live.ex:73-78`
```heex
<.notice tone={if(Map.get(@summary_counts, :locked, 0) > 0, do: :risk, else: nil)}>
  <p class="sg-meta-label">Risk queue</p>
  <p class="sg-meta-value">{locked_summary(...)} in this organization</p>
</.notice>
```
renders to `<p class="sg-text-sm"><p class="sg-meta-label">…</p><p class="sg-meta-value">…</p></p>`.

A `<p>` may only contain phrasing content; an inner `<p>` is not permitted. Per
the HTML parser's auto-close rule, the browser closes the outer `<p
class="sg-text-sm">` *before* the inner `<p>`, then leaves a stray `</p>`. The
resulting live DOM differs from the server-rendered string, which is exactly the
kind of mismatch that can desync LiveView DOM patching, and it drops the
`sg-text-sm` wrapper styling the migration appears to intend. The pre-migration
markup at both sites placed these `<p>`s directly inside a `<div
class="sg-list-row …">` (block container) — valid — so this is a behavior
regression introduced by the swap, not a pre-existing issue.

This is not covered by `components_test.exs:150`, which only renders `notice`
with a bare string body (`fn _, _ -> "Locked …" end`), so the golden passes while
the real call sites emit invalid HTML.

**Fix:** Either pass phrasing-only content (plain text / `<span>`) to `<.notice>`
so the component's own `<p>` is the only paragraph, or change the call sites to
not nest a `<p>`. For user_show, drop the inner `<p>` and let `notice` supply it:

```heex
<.notice :if={summary_alert(@detail)} tone={elem(summary_alert(@detail), 0)}>
  {elem(summary_alert(@detail), 1)}
</.notice>
```

For organization_live, the two-line label/value shape does not fit a single
`<p>` cleanly; keep it as the prior `<div class="sg-list-row" data-tone={…}>`
(string tone) form, or revise `notice/1` to render its slot in a `<div>`
(coordinated with the component owner and its golden), so the `sg-meta-label` /
`sg-meta-value` `<p>`s remain valid block children.

### WR-02: `summary_alert/1` is called three times per render (re-evaluated on every `elem/2`)

**File:** `lib/sigra/admin/live/user_show_live.ex:131-132`
**Issue:**
```heex
<.notice :if={summary_alert(@detail)} tone={elem(summary_alert(@detail), 0)}>
  <p class="sg-text-sm">{elem(summary_alert(@detail), 1)}</p>
</.notice>
```
`summary_alert/1` runs once for the `:if` guard and again for each `elem/2`
call — three evaluations of the same `cond` per render. Functionally it returns
a stable tuple so the output is correct, but if `summary_alert` ever returns
`nil` between the guard and an `elem/2` call (it cannot here, but the pattern is
fragile), `elem(nil, 0)` would raise. The pre-migration markup had the identical
triple-call shape, so this is a carried-over smell rather than newly introduced —
flagging because the migration was the moment to assign it once.

**Fix:** Compute once into an assign in `handle_params` (or via `assign` in
`render`) and branch on it:

```elixir
assigns = assign(assigns, :summary_alert, summary_alert(assigns.detail))
```
```heex
<.notice :if={@summary_alert} tone={elem(@summary_alert, 0)}>
  {elem(@summary_alert, 1)}
</.notice>
```

### WR-03: `empty_state` slot bodies are collapsed onto one line, harming readability/diffability

**File:** `lib/sigra/admin/live/user_show_live.ex:188`, `:219`, `:246`, `:273`
**Issue:**
The four `<.empty_state>` swaps put the title attr and the entire slot body on a
single physical line, e.g.:
```heex
<.empty_state :if={@detail.sessions == []} title="No active sessions."><p class="sg-muted sg-text-sm">This user does not have a currently visible session in this scope.</p></.empty_state>
```
This is valid HEEx and renders correctly, but the single-line form is
inconsistent with the multi-line `<.empty_state>` blocks used in
`audit_index_live.ex:168` and `users_index_live.ex:282`, and makes future diffs
noisy and review-hostile. The Playwright assertion `getByText('No active
sessions.')` (admin-user-operations.spec.ts:128) still matches, so behavior is
intact.

**Fix:** Reflow to the multi-line block form used by the index LiveViews for
consistency:
```heex
<.empty_state :if={@detail.sessions == []} title="No active sessions.">
  <p class="sg-muted sg-text-sm">This user does not have a currently visible session in this scope.</p>
</.empty_state>
```

## Info

### IN-01: `summary_chip/1` emits `<dt>`/`<dd>` inside a `<div>`, not a `<dl>`

**File:** `lib/sigra/admin/components.ex:138-145` (consumed at `users_index_live.ex:79-84`)
**Issue:** The shared `summary_chip/1` renders `<div class="sg-metric"><dt>…</dt><dd>…</dd></div>`. `<dt>` and `<dd>` are only valid as children of a `<dl>` (or a `<div>` *inside* a `<dl>`). The call site does wrap the chips in `<dl class="sg-metric-grid">` (`users_index_live.ex:78`), so `dl > div > dt/dd` is the valid grouping form and this is fine in context — but the component in isolation (and any future caller not nesting it in a `<dl>`) emits orphan `<dt>`/`<dd>`. This is pre-existing component behavior, not introduced by phase 156; noting because the migration newly routes through it. No action required unless the component gains non-`<dl>` callers.

### IN-02: `scope_copy/1` is now duplicated across LiveViews with diverging shapes

**File:** `lib/sigra/admin/live/audit_index_live.ex:229-232`, `lib/sigra/admin/live/user_show_live.ex:401-404`, `lib/sigra/admin/live/users_index_live.ex:384-389`, `lib/sigra/admin/live/organization_live.ex` (none)
**Issue:** Each LiveView keeps its own `scope_copy/1` private fn feeding the shared `<.scope_ribbon>`. The clauses differ subtly (e.g. users_index matches `%Scope{mode: :global}` and `%Scope{organization: …}`; audit matches `%Scope{mode: :organization, organization: …}` then a catch-all). The copy text also differs per surface, so this is intentional per-surface phrasing, not a true duplicate — but four near-identical resolvers feeding one shared component is a consolidation the phase left on the table. No correctness impact.

### IN-03: `audit_index_live.ex` still uses raw string `data-tone` on `<tr>`/pills — inconsistent with the atom-tone notice path

**File:** `lib/sigra/admin/live/audit_index_live.ex:136`, `:146`, `:160-161`, `:206-208`
**Issue:** `row_tone/1` returns string tones (`"risk"`, `"info"`, `nil`) and they are applied directly as `data-tone={row_tone(row)}` on `<tr>` and `<span class="sg-status-pill">`. This is correct for raw `data-tone` attributes (no component contract to satisfy) and matches the CSS selectors. It is *intentionally* string-based, unlike the `notice/1` atom path. Noting only that two tone conventions now coexist in the codebase (atom for `notice`, string for raw `data-tone`); both are valid, but a reader may expect uniformity. No change required.

### IN-04: `user_show_live.ex` references `@current_scope` while the rest of the module uses `@admin_scope`

**File:** `lib/sigra/admin/live/user_show_live.ex:288`, `:307` (via `show_impersonation_start?(@current_scope)`)
**Issue:** The impersonation guard reads `@current_scope`, whereas every other branch in this LiveView reads `@admin_scope`. This is pre-existing (untouched by phase 156) and presumably `@current_scope` is provided by an on_mount hook, but the migration is a reasonable moment to flag the inconsistent assign name — if `@current_scope` is ever absent, the `:if` would raise `KeyError` at render. Verify the assign is guaranteed by the live session hook. No phase-156 regression.

---

_Reviewed: 2026-06-04T00:00:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
