---
phase: quick-260602-hvx
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - lib/sigra/admin/live/audit_index_live.ex
  - lib/sigra/admin/live/audit_user_live.ex
autonomous: true
requirements: [STAGE-5-AUDIT-INVESTIGATOR]
must_haves:
  truths:
    - "Riley can pick Outcome from a Success/Failure dropdown instead of typing it"
    - "Riley can bound the audit timeline with from/to date inputs (both views)"
    - "Active filters render as removable chips with a Clear all on both views"
    - "Failure rows pop as a risk-toned pill carrying color + text + glyph; success stays calm"
    - "Filtered-empty states teach recovery and offer one-click Clear all; both pinned titles preserved"
    - "action_prefix stays a free-text input echoing dotted values like admin.impersonation"
    - "Per-user view preserves return_to through chips, clear, export, and pagination"
  artifacts:
    - path: "lib/sigra/admin/live/audit_index_live.ex"
      provides: "Investigator-shaped global/org audit explorer markup + chip/severity helpers"
      contains: "applied_chips"
    - path: "lib/sigra/admin/live/audit_user_live.ex"
      provides: "Per-user audit explorer mirroring the index treatment with return_to plumbing"
      contains: "applied_chips"
  key_links:
    - from: "audit_index_live.ex outcome select"
      to: "Sigra.Admin.Audit.QueryParams @allowed_params"
      via: "name=\"outcome\" with values \"\"/success/failure"
      pattern: "name=\"outcome\""
    - from: "audit_*_live.ex date inputs"
      to: "QueryParams from/to"
      via: "name=\"from\" + name=\"to\""
      pattern: "name=\"(from|to)\""
    - from: "audit_user_live.ex chips/clear/export"
      to: "return_to param"
      via: "preserve return_to in every generated path"
      pattern: "return_to"
---

<objective>
Make the two audit LiveViews investigator-shaped (Riley's job: "what happened, who, export evidence"). Convert Outcome to a `<select>`, add a from/to date range, render applied-filter chips + Clear all, foreground failure severity as a risk-toned outcome pill, and turn empty states into teaching states — on both the global/org explorer and the per-user view.

Purpose: Stage 5 of the approved Admin-UI Pass 2 plan. Filters today are 4 raw text boxes with no applied-filter affordance and flat severity. This is the under-iterated investigator surface.

Output: Reshaped markup + small private helpers in both `audit_index_live.ex` and `audit_user_live.ex`, mirroring the Stage-3 `sg-applied-chip` pattern. Backend-safe — no data-layer, query, JS, or test changes. All required CSS (`sg-select`, `sg-applied-chip`, `sg-status-pill[data-tone]`, `sg-day-group`) already exists in `app.css`.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/STATE.md
@./CLAUDE.md

# Library-owned LiveViews being reshaped (read fully before editing)
@lib/sigra/admin/live/audit_index_live.ex
@lib/sigra/admin/live/audit_user_live.ex

# Test contracts that MUST stay green (do not edit)
@test/example/test/example_web/live/admin_audit_index_live_test.exs
@test/example/test/example_web/live/admin_audit_user_live_test.exs

<interfaces>
<!-- Established Stage-3 chip pattern from users_index_live.ex — MIRROR this shape exactly.
     Reuse the same helper names and `sg-applied-chip` markup so the design system stays coherent.
     All four CSS classes below already exist in app.css; no CSS change is expected. -->

Stage-3 chip markup (users_index_live.ex lines 167–180) — replicate per audit view:
- Wrapper: `<div :if={any_filter_active?(@current_params)} class="sg-cluster sg-cluster--start">`
- Per chip: `<span class="sg-applied-chip"><span>{chip.label}</span><a class="sg-applied-chip__remove" href={remove_chip_path(...)} aria-label={"Remove filter " <> chip.label}><span aria-hidden="true">&times;</span><span class="sr-only">remove</span></a></span>`
- Trailing: `<a href={CLEAR_PATH} class="sg-btn sg-btn--ghost sg-btn--sm">Clear all</a>`

Stage-3 chip helpers (users_index_live.ex lines 428–476) — adapt key lists to audit params:
- `applied_chips(params)` returns ordered `[%{key, label}]`
- `chip_label(key, value)` humanizes; e.g. returns "Outcome: Failure", "Action: auth", "From: 2026-05-01"
- `remove_chip_path(admin_scope, params, key)` drops one key, preserves the rest, resets pagination (drop "cursor")
- `present_param?/2`, `param_value/3` already exist locally in both audit views

Backend-supported filter params (Sigra.Admin.Audit.QueryParams @allowed_params) — DO NOT invent others:
  actor, effective_user, organization, action, action_prefix, outcome, from, to, cursor, page_size, subject_user

Data reality (seed): outcome ∈ {success, failure}; action-prefix segments ∈ {account, admin, auth, mfa, security, session}.
@meta has current_page / previous_page / next_page (encoded cursor) — NO total_count.

Existing CSS classes (app.css) — reuse, do not redefine:
  .sg-select (line 790) · .sg-applied-chip + __remove (line 885) · .sg-status-pill[data-tone] glyphs (Stage-0) · .sg-day-group (line 1075)
</interfaces>
</context>

<tasks>

<task type="auto">
  <name>Task 1: Reshape the global/org audit explorer (audit_index_live.ex)</name>
  <files>lib/sigra/admin/live/audit_index_live.ex</files>
  <action>
Reshape the filter form, results, and empty state in `render/1`, and add private helpers. Backend-safe — touch only markup + private functions; do not change mount/handle_params/Explorer calls.

FILTER FORM (the `sg-form-grid--cols` block, lines ~57–77):
- Keep the Actor and Effective user TEXT inputs unchanged (`name="actor"`, `name="effective_user"`).
- Keep Action prefix as a free TEXT input (`name="action_prefix"`). TEST PIN: index test passes the dotted value `action_prefix=admin.impersonation` and asserts `name="action_prefix"` + `value="admin.impersonation"` render. A `<select>` would break this — leave it free text. You MAY clarify the label/placeholder (e.g. placeholder "e.g. auth or admin.impersonation") but keep name + value echo intact.
- Convert Outcome to a `<select name="outcome" class="sg-select">` with three options: `Any` (value ""), `Success` (value "success"), `Failure` (value "failure"). Reflect the current param as `selected` (compute `selected={param_value(@current_params, "outcome") == "success"}` etc.). Outcome is NOT pinned as a text input by either test, so the select is safe.
- Add a date range: two inputs `name="from"` and `name="to"` (labels "Occurred from" / "Occurred to"). Use `type="date"` to match the Stage-3 users-index date inputs (registered_from/to use `type="date"`); value echoes `param_value(@current_params, "from"|"to")`. Backend supports from/to via @allowed_params.

KEEP UNCHANGED: the `Apply filters` / `Clear` / `Export CSV` cluster (lines ~79–83) and the three hidden inputs `page_size` / `order_by` / `order_direction` (lines ~85–87). TEST PIN: index test asserts `name="page_size"` + `value="1"` render — keep the hidden page_size echo exactly.

APPLIED-FILTER CHIPS (new block, insert between the closing `</form>` and the results `sg-table-panel`):
- Mirror the Stage-3 markup (see `<interfaces>`). Render only when `any_filter_active?(@current_params)` is true.
- Active filter keys for chips: `actor`, `effective_user`, `action_prefix`, `outcome`, `from`, `to`. Ignore non-filter keys (`cursor`, `page_size`, `order_by`, `order_direction`, `organization`).
- "Clear all" links to `index_path(@admin_scope)` (existing helper).
- Each chip ✕ links to `remove_chip_path(@admin_scope, @current_params, key)` — drops that one key, preserves the rest, deletes "cursor" (pagination reset).

SEVERITY FOREGROUNDING (the Outcome cell, line ~124 `<td class="sg-show-desktop sg-text-sm">{row.outcome}</td>`):
- When `row_tone(row) == "risk"` (a failure), render the outcome as `<span class="sg-status-pill" data-tone="risk">{row.outcome}</span>` so it carries color + text + the Stage-0 ✕ glyph (WCAG-safe triple cue).
- Otherwise (success/neutral) keep the calm muted plain text `{row.outcome}`.
- Leave the existing `tr[data-tone]` row rail/tint, the action pill, and `row_tone/1` as-is. Do not over-tint — only failures pop.

TEACHING EMPTY STATE (the `sg-empty-state` block, lines ~130–133):
- KEEP the pinned title exactly: `No audit events match this view`. TEST PIN: the org-scope test asserts this string.
- When filters are active, the body guides recovery and adds a one-click `Clear all filters` link to `index_path(@admin_scope)` (mirror Stage-3 users empty-state body, lines 285–301). When no filters are active, an orienting body (events appear here as activity is recorded) — not an error.

HELPERS (add as private fns, adapt from Stage-3 users_index_live.ex 428–476):
- `any_filter_active?(params)` → true if any of [actor, effective_user, action_prefix, outcome, from, to] is present.
- `applied_chips(params)` → ordered `[%{key, label}]` over those keys, using `present_param?/2`.
- `chip_label(key, value)` → humanized: "Outcome: " <> humanize_outcome(value) ("success"→"Success","failure"→"Failure"); "Action: " <> value (for action_prefix); "From: " <> value; "To: " <> value; "Actor: " <> value; "Effective user: " <> value.
- `remove_chip_path(admin_scope, params, key)` → `index_path |> append_query(params |> Map.delete(key) |> Map.delete("cursor"))` (reuse existing `append_query/2`).
- `present_param?(params, key)` → `param_value(params, key) not in [nil, ""]`.
- `param_value/3` already exists — reuse it.

OPTIONAL day-group sub-headers (`sg-day-group`): SKIP for this task. It risks the `:for` row stream + cell-content assertions and the simpler wins are the priority. Note it deferred in the SUMMARY.

Run `mix compile --warnings-as-errors` after editing — remove any now-unused private fn and fix warnings before finishing.
  </action>
  <verify>
    <automated>cd /Users/jon/projects/sigra && mix compile --warnings-as-errors 2>&1 | tail -5 && cd test/example && PGHOST=127.0.0.1 PGPORT=5432 PGUSER=postgres PGPASSWORD=postgres mix test test/example_web/live/admin_audit_index_live_test.exs 2>&1 | tail -15</automated>
  </verify>
  <done>Outcome is a `<select>` (Any/Success/Failure reflecting the param); from/to date inputs render; action_prefix stays free text echoing `admin.impersonation`; applied-filter chips + Clear all render when filters active; failure outcome renders as a risk-toned pill, success stays muted text; empty state keeps the title `No audit events match this view` and teaches recovery; `mix compile --warnings-as-errors` clean; `admin_audit_index_live_test.exs` green (3/3).</done>
</task>

<task type="auto">
  <name>Task 2: Mirror the treatment onto the per-user audit explorer (audit_user_live.ex)</name>
  <files>lib/sigra/admin/live/audit_user_live.ex</files>
  <action>
Apply the SAME investigator treatment as Task 1 to the per-user view, preserving its `return_to` plumbing through every generated path. The per-user view is the same component shape pre-filtered to the subject. Touch only markup + private fns; do not change mount/handle_params/Explorer/Detail calls or the `sanitize_return_to` logic.

FILTER FORM (the `sg-form-grid--cols` block, lines ~82–102):
- Convert Outcome (currently free text, line ~88–91) to `<select name="outcome" class="sg-select">` with Any("")/Success("success")/Failure("failure"), reflecting the current param as `selected`. Outcome is NOT pinned by the per-user test — safe.
- Keep Action prefix free TEXT (`name="action_prefix"`). TEST PIN: per-user test passes `action_prefix=session` and asserts `name="action_prefix"` + `value="session"`. Keep name + value echo.
- Keep the Actor text input.
- The view already has a `from` text input (label "Occurred after", placeholder "2026-05-01"). ADD a symmetric `to` input next to it (`name="to"`, same input style/placeholder convention). For visual symmetry you MAY relabel "Occurred after"→"Occurred from" and add "Occurred to"; keep `name="from"` unchanged. (Match the per-user view's existing text-input + placeholder style; do not switch from to `type="date"` mid-view unless both render cleanly together — prefer consistency with the existing `from` input.)

KEEP UNCHANGED: the `Apply filters` / `Clear` / `Export CSV` cluster (lines ~104–110) including `clear_path(@admin_scope, @detail.user.id, @return_to)` and `export_path(... export_params(@current_params, @return_to))`; the `return_to` hidden input (line ~112); and the three hidden inputs page_size/order_by/order_direction (lines ~113–115). TEST PIN: per-user test asserts `name="page_size"` + `value="1"` and that `return_to=%2F…` persists — keep all of these.

APPLIED-FILTER CHIPS (new block, between `</form>` and the results panel):
- Mirror the Stage-3 markup. Render when `any_filter_active?(@current_params)`.
- Chip keys: `actor`, `action_prefix`, `outcome`, `from`, `to` (per-user has no `effective_user` filter input — omit it; do not chip non-filter keys cursor/page_size/order_*/return_to).
- Each chip ✕ → `remove_chip_path(@admin_scope, @detail.user.id, @current_params, @return_to, key)` — drops one key, PRESERVES return_to and the rest, drops "cursor".
- "Clear all" → `clear_path(@admin_scope, @detail.user.id, @return_to)` (existing helper preserves return_to).

SEVERITY FOREGROUNDING (Outcome cell, line ~152): same as Task 1 — failure → `<span class="sg-status-pill" data-tone="risk">{row.outcome}</span>`; success → muted plain text. Leave row tone, action pill, and `row_tone/1` untouched.

TEACHING EMPTY STATE (lines ~158–161):
- KEEP the pinned title exactly: `No audit events match this user view`. TEST PIN not asserted by the read tests but pinned by ground-truth — preserve it.
- Filters active → teaching body + a one-click clear linking to `clear_path(@admin_scope, @detail.user.id, @return_to)` (preserves return_to). No filters → orienting body.

HELPERS (add private fns, mirroring Task 1 but threading return_to where paths are built):
- `any_filter_active?(params)` over [actor, action_prefix, outcome, from, to].
- `applied_chips(params)` ordered over those keys.
- `chip_label(key, value)` same humanization as Task 1 (no effective_user needed but harmless to include).
- `remove_chip_path(admin_scope, user_id, params, return_to, key)` → `index_path(admin_scope, user_id) |> append_query(params |> Map.delete(key) |> Map.delete("cursor") |> Map.put("return_to", return_to))`. Reuse existing `append_query/2`; the existing cleaner drops nil/"" so a nil return_to is naturally omitted.
- `present_param?/2` and `param_value/3` (param_value already exists — reuse).

OPTIONAL day-group: SKIP (same rationale as Task 1).

Run `mix compile --warnings-as-errors` and remove any unused private fn before finishing.
  </action>
  <verify>
    <automated>cd /Users/jon/projects/sigra && mix compile --warnings-as-errors 2>&1 | tail -5 && cd test/example && PGHOST=127.0.0.1 PGPORT=5432 PGUSER=postgres PGPASSWORD=postgres mix test test/example_web/live/admin_audit_user_live_test.exs 2>&1 | tail -15</automated>
  </verify>
  <done>Per-user Outcome is a `<select>`; a `to` date input is added alongside the existing `from`; action_prefix stays free text echoing `session`; chips + Clear all preserve return_to; failure outcome renders as a risk-toned pill; empty-state title `No audit events match this user view` preserved with a teaching body; return_to persists through chips/clear/export/pagination; `mix compile --warnings-as-errors` clean; `admin_audit_user_live_test.exs` green (2/2).</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| browser → audit LiveView (GET params) | URL filter params (actor, outcome, from, to, action_prefix, return_to) cross into the explorer |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-hvx-01 | Tampering | new filter params (outcome/from/to) | mitigate | Only emit params already in `Sigra.Admin.Audit.QueryParams @allowed_params`; the existing QueryParams layer validates/whitelists server-side — no new unvalidated param introduced |
| T-hvx-02 | Information disclosure | per-user `return_to` open-redirect | accept | Unchanged this stage; existing `sanitize_return_to/3` already constrains to `/admin/users`/`/admin/organizations/` prefixes; chips/clear only re-thread the already-sanitized value |
| T-hvx-03 | Information disclosure | raw audit metadata in markup | mitigate | No raw `row.metadata` rendered; only Presenter-derived labels (action_label/actor_summary/outcome) — preserved from current code; per-test `refute html =~ "metadata"` stays green |
| T-hvx-SC | Tampering | npm/pip/cargo installs | accept | No package installs in this plan (markup-only, deps unchanged) |
</threat_model>

<verification>
Full gate from `test/example` (both audit test files must stay green, honoring every ground-truth pin):

```
cd /Users/jon/projects/sigra && mix compile --warnings-as-errors
cd /Users/jon/projects/sigra/test/example && PGHOST=127.0.0.1 PGPORT=5432 PGUSER=postgres PGPASSWORD=postgres \
  mix test test/example_web/live/admin_audit_index_live_test.exs \
           test/example_web/live/admin_audit_user_live_test.exs
```

Manual spot-check of the rendered HTML pins (covered by the tests, but assert during review): `name="outcome"` is now a `<select>` with a `selected` option; `name="from"` and `name="to"` inputs present (both views); `name="action_prefix"` still free text echoing `admin.impersonation` (index) and `session` (per-user); `name="page_size"` hidden echo intact; empty-state titles unchanged; per-user `return_to=%2F…` persists.
</verification>

<success_criteria>
- Outcome is a `<select>` (Any/Success/Failure, value reflected) on both views.
- from/to date-range inputs present and backend-wired on both views (index gains both; per-user gains `to`).
- action_prefix remains a free-text input echoing dotted/word values.
- Applied-filter chips + "Clear all" render on both views; per-user chips/clear preserve return_to.
- Failure rows render the outcome as a `data-tone="risk"` pill (color + text + glyph); success stays calm muted text.
- Teaching empty states keep both pinned titles and offer one-click clear when filtered.
- No unsupported params, no JS, no data-layer/query, no test edits.
- `mix compile --warnings-as-errors` clean; both audit ExUnit files green.
- (FLAG) Library-owned LiveViews require a server restart to view; visual baselines are refreshed in Stage 8.
</success_criteria>

<output>
Create `.planning/quick/260602-hvx-stage-5-admin-ui-pass-2-audit-explorer-i/260602-hvx-SUMMARY.md` when done.
Note in the SUMMARY whether the optional `sg-day-group` day-group sub-headers were included or deferred (default: deferred).
</output>
