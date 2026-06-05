# Phase 158: Audit Mobile + Per-User Audit (High Effort) - Pattern Map

**Mapped:** 2026-06-04
**Files analyzed:** 6 (1 new component + 3 LiveView modifications + 1 golden test + 1 Playwright spec)
**Analogs found:** 6 / 6 (all in-tree — this is a coherence pass on a mature codebase)

> **Navigate by SYMBOL, not line number.** RESEARCH flags pre-157 line drift. Every excerpt
> below is anchored to a `def`/`defp`/attr/golden name. Line numbers are current-as-of-read
> hints only.

---

## File Classification

| File | Role | Data Flow | Closest Analog | Match Quality |
|------|------|-----------|----------------|---------------|
| `lib/sigra/admin/components.ex` — new `audit_row/1` (11th component) | component (function) | transform (row map → card HEEx) | the 10 existing components in the same file (esp. `applied_chip/1`, `empty_state/1`) + the `user_show_live.ex` recent-audit `<article>` | exact (same file, same house style) |
| `lib/sigra/admin/live/audit_index_live.ex` — dual-layout + chips + tone consolidation | LiveView (lib-owned) | request-response (CRUD-read) | `users_index_live.ex` dual-layout (`render/1` desktop/mobile blocks) + `quick_filter/1` | exact (sibling LiveView, same idiom) |
| `lib/sigra/admin/live/audit_user_live.ex` — dual-layout + shared chrome + tone consolidation | LiveView (lib-owned) | request-response (CRUD-read) | `audit_index_live.ex` (sibling explorer) + `users_index_live.ex` dual-layout | exact |
| `lib/sigra/admin/live/user_show_live.ex` — recent-audit block → `<.audit_row>` | LiveView (lib-owned) | request-response (read-only embed) | its own current `<article>` block (characterization source) | exact (self) |
| `test/sigra/admin/components_test.exs` — `audit_row` golden(s) | test (byte-golden) | transform-assert | the 8 existing `@*_golden` literal-`==` assertions | exact |
| `test/example/priv/playwright/tests/admin-checkpoints.spec.ts` — `user-audit` slug | test (visual + a11y) | event-driven (browser journey) | the `audit-explorer` slug block (`captureAndVerify` + `assertCheckpointScreenshot`) | exact |

---

## Pattern Assignments

### `lib/sigra/admin/components.ex` — new `audit_row/1` (component, transform)

**Analog A — house-style attr/slot + class/rest merge convention.** Every one of the 10
components follows: required content attrs, then `attr :class, :any, default: nil`, then
`attr :rest, :global`, with `class={[..., @class]} {@rest}` on the root. `applied_chip/1` is
the closest shape (also a flat span/article with no slot logic):

```elixir
# Source: components.ex — applied_chip/1 (~:161-180)
attr :label, :string, required: true, doc: "the filter label shown inside the chip"
attr :remove_href, :string, required: true, doc: "..."
attr :class, :any, default: nil, doc: "additional CSS classes merged onto the root element"
attr :rest, :global, doc: "arbitrary HTML attributes added to the root element"

def applied_chip(assigns) do
  ~H"""
  <span class={["sg-applied-chip", @class]} {@rest}>
    <span>{@label}</span>
    ...
  </span>
  """
end
```

`empty_state/1` shows the `attr ... required: true` + optional-class + slot pattern when a
component needs a variable body — relevant if `audit_row` ever takes a slot (it does NOT per
UI-SPEC; it is attr-only). The moduledoc `## Components` bullet list (`components.ex:15-27`)
MUST gain an 11th `audit_row/1` line, and the moduledoc "10 flat, stateless" / "Provides 10"
counts (`components.ex:5`) must be updated to 11.

**Analog B — the compact card to reproduce byte-for-byte (characterization source).** The
`audit_row` compact variant (`show_detail=false`, `show_codes=false`) must emit the EXACT bytes
this block produces today, including the no-seconds timestamp format:

```heex
<!-- Source: user_show_live.ex — render/1 "Recent Audit" (~:264-272) -->
<article :for={row <- @detail.recent_audit} class="sg-list-row sg-stack sg-stack--2" data-tone={audit_tone(row)}>
  <div class="sg-cluster sg-cluster--2">
    <span class="sg-status-pill" data-tone={audit_tone(row)}>{row.action_label}</span>
    <span :if={row.action_badge} class="sg-status-pill" data-tone="info">{row.action_badge}</span>
  </div>
  <span class="sg-muted sg-text-sm">{row.actor_summary}</span>
  <span class="sg-muted sg-text-xs">{Calendar.strftime(row.inserted_at, "%Y-%m-%d %H:%M")}</span>
</article>
```

NOTE the inline `Calendar.strftime(..., "%Y-%m-%d %H:%M")` (no seconds, no helper). See
**Shared Pattern: date formatting (D-09)** below — `audit_row` must own a single date helper.

**Analog C — the full-detail lines the explorers add (gated by `show_detail`/`show_codes`).**
The explorer `<tr>` carries the extra lines the compact card omits:

```heex
<!-- Source: audit_index_live.ex — render/1 table <tr> (~:139-156) -->
<span class="sg-text-sm">{format_timestamp(row.inserted_at)}</span>   <!-- %H:%M:%S in table -->
<code class="sg-code">{row.id}</code>                                <!-- gated by show_codes -->
<code class="sg-code">{row.action}</code>                            <!-- gated by show_codes -->
<span :if={row.action_badge} class="sg-muted">Actor: {row.actor_label}</span>            <!-- show_detail -->
<span :if={row.action_badge} class="sg-muted">Effective user: {row.effective_user_label}</span>  <!-- show_detail -->
```

**Target markup (from UI-SPEC, the contract to implement):**
```heex
<article class="sg-list-row sg-stack sg-stack--2" data-tone={audit_tone(@row)}>
  <div class="sg-cluster sg-cluster--2">
    <span class="sg-status-pill" data-tone={audit_tone(@row)}>{@row.action_label}</span>
    <span :if={@row.action_badge} class="sg-status-pill" data-tone="info">{@row.action_badge}</span>
  </div>
  <span class="sg-muted sg-text-sm">{@row.actor_summary}</span>
  <span :if={@show_detail} class="sg-muted sg-text-sm">Actor: {@row.actor_label}</span>
  <span :if={@show_detail and @row.action_badge} class="sg-muted sg-text-sm">Effective user: {@row.effective_user_label}</span>
  <span class="sg-muted sg-text-xs">{format_date(@row.inserted_at)}</span>
  <code :if={@show_codes} class="sg-code">{@row.id}</code>
  <code :if={@show_codes} class="sg-code">{@row.action}</code>
</article>
```
Attrs: `attr :row, :map, required: true`; `attr :show_detail, :boolean, default: false`;
`attr :show_codes, :boolean, default: false`. Per RESEARCH, decide whether to also add
`:class`/`:rest` to match house style (the golden freezes whatever is chosen).

**HARD-FAIL boundary (D-01):** NO `variant={:table|:card}` polymorphism. Card shape only. The
desktop `<tr>` stays inline in both explorers (a `<tr>` is not an `<article>` — same reason
`users_index_live.ex` keeps its `<tr>` inline and shares nothing with its mobile `<article>`).

**The Presenter row struct `audit_row/1` consumes** (single source — all three sites use it):
```elixir
# Source: lib/sigra/admin/audit/presenter.ex — present_event/2 (~:20-35)
%{
  id: event.id,
  inserted_at: event.inserted_at,                  # DateTime.t() from Ecto
  action: event.action,                            # "admin.impersonation.start"
  action_label: action_label(event.action),        # "Impersonation started"
  action_badge: if(impersonation?, do: "Impersonation", else: nil),
  actor_label: user_label(actor, event.actor_id),
  effective_user_label: user_label(effective_user, event.effective_user_id),
  actor_summary: if(impersonation?, do: "<a> acting as <b>", else: user_label(...)),
  outcome: event.outcome || "success"               # NB: defaults "success", never nil from explorer
}
```
`Detail.recent_audit_preview/3` calls the SAME `Presenter.present/2`, so the UserShow compact
block is field-compatible by construction.

---

### `lib/sigra/admin/live/audit_index_live.ex` (LiveView, request-response)

**Analog — `UsersIndexLive` dual-layout block (the idiom to MIRROR exactly):**
```heex
<!-- Source: users_index_live.ex — render/1 (~:179-280) -->
<div id="admin-users-desktop-results" data-testid="admin-users-desktop-results"
     class="sg-table-panel sg-show-desktop">
  <table class="sg-table"> ... inline <tr> rows ... </table>
</div>
<div id="admin-users-mobile-results" data-testid="admin-users-mobile-results"
     class="sg-stack sg-stack--3 sg-show-mobile">
  <article :for={row <- @rows} class="sg-card sg-stack sg-stack--3"> ... </article>
</div>
```
Keep BOTH `id=` and `data-testid=`. For audit, wrap the EXISTING desktop table (currently
`<div :if={@rows != []} class="sg-table-panel">` at `audit_index_live.ex:125`) by adding
`sg-show-desktop` and `data-testid="admin-audit-desktop-results"`. Add the sibling mobile
block `data-testid="admin-audit-mobile-results"` iterating
`<.audit_row :for={row <- @rows} row={row} show_detail show_codes />` (card uses `sg-list-row`
via the component, NOT `sg-card`).

**HARD-FAIL (D-02):** No horizontal-scroll responsive table. `sg-table-panel` has no
self-hide — without the `sg-show-desktop` wrapper the table overflows the iPhone-13 profile.

**Analog — quick-filter chip (`quick_filter/1`) — and the active-state MISMATCH.** The
users-index chip is a **checkbox** (`:has(input:checked)` active state):
```heex
<!-- Source: users_index_live.ex — defp quick_filter/1 (~:325-338) -->
<label class="sg-filter-chip">
  <input type="checkbox" name={@key} value="true" checked={param_true?(@params, @key)}
         class="checkbox checkbox-sm" />
  <span>{String.replace(@key, "_", " ")}</span>
</label>
```
The CSS active rule keys on a CHECKED INPUT:
```css
/* Source: app.css — .sg-filter-chip:has(input:checked) (~:878-882) */
.sg-filter-chip:has(input:checked) {
  background: var(--sg-color-brand-soft);
  color: var(--sg-color-brand-strong);
  box-shadow: inset 0 0 0 1px color-mix(in oklab, var(--sg-color-brand) 32%, transparent);
}
```
**MISMATCH (RESEARCH Pitfall #1, D-04):** audit chips are VALUE-SETTERS, not booleans —
"Failures" → `outcome=failure`, "Impersonation" → `action_prefix=admin.impersonation`. A plain
`<a href="?outcome=failure">` has no `<input>`, so this CSS never lights up. **Recommended
reconciliation (RESEARCH Option a):** keep a `<label class="sg-filter-chip"><input>` shell whose
checked state reflects whether the real string value is active (and whose submission sets the
real `outcome`/`action_prefix` string), preserving the `:has(input:checked)` active state with
ZERO new CSS. Do NOT ship a chip whose active state never renders. Do NOT add
`impersonation=true`/`failure=true` params — they are silently dropped by `QueryParams`.

**The real param contract (no query-layer change needed):**
```elixir
# Source: lib/sigra/admin/audit/query_params.ex — @allowed_params (~:9-21) + reduce clauses (~:56-60)
@allowed_params ~w(actor effective_user organization action action_prefix outcome from to cursor page_size subject_user)
# {"action_prefix", v} -> Map.put(acc, :action_prefix, String.trim(v))
# {"outcome", v}       -> Map.put(acc, :outcome, String.trim(v))
```

**Tone consolidation (D-10) — retire the divergent `row_tone/1`.** This file's `row_tone/1`
is the canonical body to lift into the unified `audit_tone/1`:
```elixir
# Source: audit_index_live.ex — defp row_tone/1 (~:206-208) — IDENTICAL to audit_user_live.ex:246-248
defp row_tone(%{outcome: outcome}) when outcome not in ["success", nil, ""], do: "risk"
defp row_tone(%{action_badge: badge}) when not is_nil(badge), do: "info"
defp row_tone(_row), do: nil
```
The desktop `<tr>` still needs tone for `data-tone={...}` — so the unified `audit_tone/1` must be
callable from the LiveView too (Open Question #1: co-locate in `components.ex` as a
shared/public helper, OR keep an identical `defp` the planner dedups). Either way ONE body wins.

---

### `lib/sigra/admin/live/audit_user_live.ex` (LiveView, request-response)

**Analog — sibling `audit_index_live.ex` for the dual-layout + chips** (mirror the same
changes). Use `data-testid="admin-audit-user-desktop-results"` /
`admin-audit-user-mobile-results` (D-03).

**AUDX-03 reconciliation — replace hand-rolled chrome with shared components.** Three
hand-rolled blocks currently diverge from the shared set:

```heex
<!-- Source: audit_user_live.ex — render/1 back-nav + scope ribbon (~:62-67) -->
<a class="sg-btn sg-btn--ghost sg-btn--sm" href={@return_to}>
  <span aria-hidden="true">&larr;</span> Back to user
</a>
<span class="sg-muted sg-text-sm">{scope_copy(@admin_scope)}</span>
<!-- → replace with <.page_back return_to={@return_to} label="Back to user" />
        and <.scope_ribbon copy={scope_copy(@admin_scope)} /> -->
```
```heex
<!-- Source: audit_user_live.ex — render/1 inline applied-chip (~:138-148) -->
<span :for={chip <- applied_chips(@current_params)} class="sg-applied-chip">
  <span>{chip.label}</span>
  <a class="sg-applied-chip__remove" href={remove_chip_path(...)} aria-label={"Remove filter " <> chip.label}>
    <span aria-hidden="true">&times;</span><span class="sr-only">remove</span>
  </a>
</span>
<!-- → replace with <.applied_chip label={chip.label} remove_href={remove_chip_path(...)} /> -->
```
```heex
<!-- Source: audit_user_live.ex — render/1 inline empty-state (~:197-217) -->
<div :if={@rows == []} class="sg-empty-state sg-stack sg-stack--3">
  <p class="sg-empty-state__title">No audit events match this user view</p>
  ...
</div>
<!-- → replace with <.empty_state title="..."> ... </.empty_state> -->
```
The inline applied-chip markup is byte-identical to the `@applied_chip_golden`
(`components_test.exs:40`), so swapping to `<.applied_chip>` is behavior-preserving for the
desktop/dark baselines. The `<.page_back>`/`<.scope_ribbon>`/`<.empty_state>`/`<.notice>`
components already exist — see **Shared Patterns** below. AuditIndex already uses
`<.applied_chip>` (`audit_index_live.ex:117-122`) — copy that wiring.

This file's `row_tone/1` (`~:246-248`, identical body) is retired by the D-10 consolidation.

---

### `lib/sigra/admin/live/user_show_live.ex` (LiveView, read-only embed)

**Self-analog — replace the inline recent-audit `<article>` (Analog B above, ~:264-272) with
`<.audit_row :for={row <- @detail.recent_audit} row={row} />`** (compact: `show_detail`/
`show_codes` default `false`). The `<.empty_state>` already wraps the zero-rows case here
(`user_show_live.ex:273`) — keep it.

**Tone behavior change (RESEARCH Pitfall #3):** this file's `audit_tone/1` LACKS the
impersonation branch:
```elixir
# Source: user_show_live.ex — defp audit_tone/1 (~:437-440) — DIVERGENT, no action_badge branch
defp audit_tone(%{outcome: "success"}), do: nil
defp audit_tone(%{outcome: nil}), do: nil
defp audit_tone(%{outcome: _}), do: "risk"
defp audit_tone(_), do: nil
```
Adopting the unified helper means impersonation rows in the "Recent Audit" block gain
`data-tone="info"` where they have none today. If `targetEmail`'s recent-audit preview contains
impersonation rows, the `user-detail` baseline shifts — flag a POSSIBLE additional intended
re-record (CONTEXT only names `audit-explorer` ×3 + `user-audit` ×3). Verify against seed/journey.

---

### `test/sigra/admin/components_test.exs` — `audit_row` golden(s) (test, byte-golden)

**Analog — the literal-`==` golden discipline (NO snapshot lib, D-13):**
```elixir
# Source: components_test.exs — @applied_chip_golden + its test (~:40, ~:67-77 pattern)
@applied_chip_golden "<span class=\"sg-applied-chip \">\n  <span>Active</span>\n  <a class=\"sg-applied-chip__remove\" href=\"/admin/users?status=\" aria-label=\"Remove filter Active\">\n    <span aria-hidden=\"true\">&times;</span>\n    <span class=\"sr-only\">remove</span>\n  </a>\n</span>"

test "applied_chip renders ... bytes faithfully" do
  html = render_component(&Components.applied_chip/1, label: "Active", remove_href: "/admin/users?status=")
  assert html == @applied_chip_golden,
         "applied_chip drifted — see admin-design-contract.md; do not re-record Playwright baselines"
end
```
Header comment block (`components_test.exs:7-24`) tracks the golden inventory and must be updated.
Plan AT LEAST two new goldens: compact variant (`show_detail=false, show_codes=false` — must
reproduce the `user_show_live.ex:264-272` bytes exactly, including `%Y-%m-%d %H:%M`) and full
variant (`show_detail=true, show_codes=true`). Optional D-10 tone-mapping golden
(risk/info/nil → `data-tone`). `@endpoint nil` — no Postgres needed; run first/cheapest.
Each assertion carries the "drifted — ...; do not re-record Playwright baselines" message.

---

### `test/example/priv/playwright/tests/admin-checkpoints.spec.ts` — `user-audit` slug (test, visual+a11y)

**Analog — the `audit-explorer` slug block (the two-call pattern to mirror):**
```ts
// Source: admin-checkpoints.spec.ts — Checkpoint 5 audit-explorer (~:267-276)
await page.goto('/admin/audit?action_prefix=admin.impersonation');
await waitForLiveViewReady(page);
await expect(page.getByRole('heading', { name: 'Audit' })).toBeVisible();
await expect(page.getByText('Impersonation').first()).toBeVisible();   // <-- loaded-row wait, not just .phx-connected
await expect(page.getByRole('link', { name: 'Export CSV' })).toBeVisible();
await captureAndVerify(page, testInfo, 'audit-explorer');
await assertCheckpointScreenshot(page, testInfo, 'audit-explorer');
```
`captureAndVerify` attaches the artifact + asserts a non-empty PNG (`~:94-109`).
`assertCheckpointScreenshot` runs the axe WCAG 2a/2aa gate FIRST, then `toHaveScreenshot` with
`fullPage:false` + per-project `maxDiffPixels` tolerances (`~:129-145`).

**New `user-audit` slug — insert AFTER impersonation STOP (`~:263-265`), navigating to
`/admin/users/:id/audit` for `targetEmail`** (already has `admin.impersonation` rows — zero new
seed). Place after the existing `audit-explorer` block at `~:276` (or between stop `~:265` and
`audit-explorer` `~:267`). **HARD-FAIL (D-06):** the screenshot wait MUST assert a visible
LOADED row, e.g. `[data-testid="admin-audit-user-mobile-results"] article` /
`[data-testid="admin-audit-user-desktop-results"] tbody tr` / a stable "Impersonation" pill —
NOT just `.phx-connected` (157 D-06 flake lesson). Produces 3 committed PNGs
(chromium/mobile/dark). The stale header comment ("five required pages") may be updated.

**Baseline re-records (D-07):** deliberately re-record all 3 `audit-explorer` PNGs — the
all-viewport chip row sits above the fold under `fullPage:false`, shifting desktop+dark too.
Each is an intended delta after HTML-report review; non-delta slugs stay byte-green.

---

## Shared Patterns

### Date formatting (D-09 fold) — THREE divergent variants to reconcile

**Sources (all current, RESEARCH CRITICAL DRIFT #1 — there is NO `format_date/1` in any audit view):**
```elixir
# audit_index_live.ex — defp format_timestamp/1 (~:265-268)  [seconds; catch-all -> ""]
defp format_timestamp(%DateTime{} = ts), do: Calendar.strftime(ts, "%Y-%m-%d %H:%M:%S")
defp format_timestamp(_timestamp), do: ""

# audit_user_live.ex — defp format_timestamp/1 (~:384-387)   [IDENTICAL to above]
defp format_timestamp(%DateTime{} = ts), do: Calendar.strftime(ts, "%Y-%m-%d %H:%M:%S")
defp format_timestamp(_timestamp), do: ""

# user_show_live.ex — INLINE, no helper (~:271)              [no seconds]
{Calendar.strftime(row.inserted_at, "%Y-%m-%d %H:%M")}

# organization_live.ex — defp format_date/1 (~:190-191)      [DIFFERENT surface/format — OUT of scope]
defp format_date(%DateTime{} = dt), do: Calendar.strftime(dt, "%Y-%m-%d")
defp format_date(_), do: "—"
```
**Apply to:** the single date helper `audit_row/1` calls (give the component its own private
`format_date/1`). **D-09 head set:** `%DateTime{}` + `%NaiveDateTime{}` → format; `nil` → `"—"`;
anything else → raise `ArgumentError` (the catch-all must NOT silently absorb a populated-but-
wrong-typed value). **Pick ONE format string** — recommend `%Y-%m-%d %H:%M` to match the compact
card and minimize that golden's diff; the explorer-table seconds change shifts the
`audit-explorer` baseline (acceptable under D-07, reason it explicitly). Add a unit test
(`%DateTime`/`%NaiveDateTime` format, `nil → "—"`, wrong-type → raise). Leave
`organization_live.ex`'s `format_date/1` alone (Phase 157 territory).

### Tone derivation (D-10) — single source of truth `audit_tone/1`

**Source:** `audit_index_live.ex:206-208` / `audit_user_live.ex:246-248` (identical body):
```elixir
defp audit_tone(%{outcome: outcome}) when outcome not in ["success", nil, ""], do: "risk"
defp audit_tone(%{action_badge: badge}) when not is_nil(badge), do: "info"
defp audit_tone(_row), do: nil
```
**Apply to:** `audit_row/1` (card `data-tone`) AND both explorers' inline `<tr>` `data-tone`.
Retires `row_tone/1` (×2) and the OLD `user_show_live.ex` `audit_tone/1`. `sg-list-row[data-tone]`
already carries all four tones (`app.css:952-967`, merged with `sg-notice`) — ZERO new CSS.

### Existing shared components to wire into AuditUserLive (already golden-tested)

**Source:** `components.ex` — `page_back/1` (~:232), `scope_ribbon/1` (~:258), `notice/1`
(~:301), `empty_state/1` (~:204), `applied_chip/1` (~:166). All flat/stateless, `sg-*`-only,
`:class`/`:rest` convention. `notice/1` wraps its slot in `<p class="sg-text-sm">` (relevant if
asserting notice text). Error state copy → `<.notice tone={:risk}>` per UI-SPEC copywriting.

---

## No Analog Found

None. Every file in scope has a direct in-tree analog — this is a consolidation + wiring phase,
not invention. (RESEARCH "Don't Hand-Roll": every build already has a canonical home.)

---

## Metadata

**Analog search scope:** `lib/sigra/admin/components.ex`, `lib/sigra/admin/live/`,
`lib/sigra/admin/audit/`, `test/sigra/admin/`, `test/example/priv/playwright/tests/`,
`test/example/priv/static/assets/css/app.css`.
**Files scanned:** 11 (components.ex, users_index_live, audit_index_live, audit_user_live,
user_show_live, organization_live, presenter, query_params, components_test, admin-checkpoints.spec, app.css).
**Pattern extraction date:** 2026-06-04
