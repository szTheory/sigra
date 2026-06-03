---
phase: quick-260602-hhr
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - lib/sigra/admin/live/users_index_live.ex
  - test/example/priv/static/assets/css/app.css
autonomous: true
requirements: [STAGE3-PAGINATION, STAGE3-CHIPS, STAGE3-EMPTY-STATES, STAGE3-TRUNCATE, STAGE3-MOBILE-CARD]

must_haves:
  truths:
    - "Pagination nav shows an accurate 'Showing X–Y of Z users' readout computed from Flop.Meta (X = current_offset + 1, Y = current_offset + length(rows), Z = total_count), with the zero case guarded."
    - "Prev/next icon buttons keep their disabled + aria-disabled states; the bare 'Page {n}' text is replaced by the readout (optionally retaining 'Page X of N')."
    - "When any filter is active, a removable applied-filter chip renders for each active filter key with a human label and an ✕ remove link that drops only that key (other filters preserved, page reset to 1), plus a 'Clear all' link to index_path(@admin_scope)."
    - "No chip row renders when no filters are active; non-filter keys (page/page_size/order_by/order_direction) are never shown as chips."
    - "Empty state keeps the title 'No users match this view'; when filtered it offers a one-click Clear-all-filters action; when genuinely zero (no filters) it shows an orienting teaching body instead of an error-implying one."
    - "Long emails and organization summaries truncate visually with ellipsis while carrying the full value in a title= attribute (full text stays in the DOM for screen readers)."
    - "Mobile card separates status, activity, and registered into scannable groups instead of one muted wall, keeping data-testid='admin-users-mobile-results' and 'Open user'."
    - "All pinned test strings/ids intact; mix compile --warnings-as-errors is clean with no unused private functions."
  artifacts:
    - path: "lib/sigra/admin/live/users_index_live.ex"
      provides: "Showing X–Y of Z readout, applied-filter chips, teaching empty states, truncate-with-tooltip, richer mobile card"
      contains: "Showing"
    - path: "test/example/priv/static/assets/css/app.css"
      provides: "sg-applied-chip and sg-truncate token-driven utilities"
      contains: "sg-applied-chip"
  key_links:
    - from: "lib/sigra/admin/live/users_index_live.ex"
      to: "@meta (Flop.Meta)"
      via: "showing-range computed from current_offset/total_count/length(@rows)"
      pattern: "current_offset"
    - from: "lib/sigra/admin/live/users_index_live.ex"
      to: "index_path |> append_query"
      via: "per-chip removal links and Clear all"
      pattern: "append_query"
---

<objective>
Apply Stage 3 "users index craft" polish to the library-owned admin users index: a
"Showing X–Y of Z users" pagination readout, removable applied-filter chips + Clear all,
teaching empty states that distinguish filtered-empty from genuine zero, truncate-with-tooltip
on long emails/orgs, and a richer mobile card. Markup + minimal additive CSS only.

Purpose: Make "what's applied" and "where am I in the result set" obvious at a glance, and make
the empty state teach recovery — the at-a-glance surfaces this screen was missing.

Output: Updated `users_index_live.ex` and two new token-driven CSS utilities in `app.css`.
No data-layer, no JS, no test changes. Every pinned test string/id preserved.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/STATE.md
@./CLAUDE.md

# The screen being edited (library-owned LiveView — read fully; restart server to view)
@lib/sigra/admin/live/users_index_live.ex

# Test contracts that MUST keep passing unchanged
@test/example/test/example_web/live/admin_user_index_live_test.exs
@test/example/test/example_web/live/admin_user_filters_live_test.exs

# CSS design system (sg-* token layer) — add minimal additive utilities only
@test/example/priv/static/assets/css/app.css

<interfaces>
<!-- Contracts the executor needs. No codebase exploration required. -->

Flop.Meta fields available on @meta (ground-truth #2):
  total_count, total_pages, current_page, page_size,
  current_offset (0-based offset of first row on page),
  next_page, previous_page, has_next_page?, has_previous_page?

@rows = current page's rows. @current_params = normalized string-keyed map
(keys: "q", "confirmed", "mfa", "passkeys", "locked", "deleted",
"provider", "registered_from", "registered_to", "organization",
plus hidden "page_size"/"order_by"/"order_direction"/"page").

Existing private helpers already in the module (reuse, do not duplicate):
  param_value(params, key, default \\ "")  # Map.get with default
  param_true?(params, key)                 # value == "true"
  present_param?(params, key)              # value not in [nil, ""]
  index_path(admin_scope)                  # "/admin/users" or org path
  append_query(path, params)               # rejects nil/""/false, encodes query
  @quick_filter_keys ~w(confirmed mfa passkeys locked deleted)
  @more_filter_keys  ~w(provider registered_from registered_to organization)

Tokens available in app.css (use these, never raw values):
  spacing --sg-space-1..12; radius --sg-radius-xs/sm/full;
  --sg-text-sm/-xs/-2xs; --sg-color-{ink,muted,panel,brand,brand-soft,brand-strong,line,line-strong};
  --sg-weight-medium(600)/semibold(700); --sg-tracking-wide;
  --sg-control-md (2.75rem); --sg-transition-tone; --sg-transition-press;
  --sg-elev-inset; --sg-ease-out.

PINNED CONTRACTS — preserve exactly (ground-truth #5):
  ids/testids: id+data-testid "admin-users-desktop-results" and "admin-users-mobile-results";
  literal button text "Search"; toggle text "More filters";
  input name=s: q, confirmed, mfa, passkeys, locked, deleted, provider,
    registered_from, registered_to, organization, page_size, order_by, order_direction;
  empty-state TITLE string "No users match this view";
  "Open user" primary row action + its ?return_to= URL behavior.
  No test pins pagination text or any chip markup.
</interfaces>
</context>

<tasks>

<task type="auto">
  <name>Task 1: Showing X–Y of Z readout, applied-filter chips, and teaching empty states</name>
  <files>lib/sigra/admin/live/users_index_live.ex</files>
  <action>
Three changes inside the existing `render/1` template plus small private helpers.

(1) PAGINATION READOUT (replace the bare `<span class="sg-muted sg-text-sm">Page {@meta.current_page || 1}</span>` at the center of the existing `<nav :if={@meta}>`). Add a private helper `showing_range(meta, rows)` returning `{x, y, z}` where `z = meta.total_count`, and when `z > 0`: `x = meta.current_offset + 1`, `y = meta.current_offset + length(rows)`; when `z == 0` the nav is moot (empty state shows instead) — still render the nav safely (e.g. return `{0, 0, 0}` and render "Showing 0 of 0 users"). Render the readout as `Showing {x}–{y} of {z} users` wrapped so it is screen-reader friendly: use a single `<span class="sg-muted sg-text-sm sg-tabular">` with an `aria-live="polite"` or plain text (the GET nav re-renders the whole page, so plain text in a labeled span is sufficient — do NOT add aria-live if it would announce on every paint; a plain labeled span reading "Showing 5–8 of 42 users" is screen-reader friendly already). Use an en-dash (–) between X and Y. Keep the prev/next `<a>` icon buttons and their `aria-disabled`/`is-disabled`/`aria-label` exactly as-is. Optionally append "· Page {meta.current_page || 1} of {meta.total_pages || 1}" after the readout in a muted span. Add a tiny class `sg-tabular` (defined in Task 3) so the digits align.

(2) APPLIED-FILTER CHIPS — render a new region BETWEEN the closing `</form>` (line ~165) and the desktop results `<div id="admin-users-desktop-results">`. Guard the whole region with `:if={any_filter_active?(@current_params)}` where `any_filter_active?/1` returns true if `present_param?(params, "q")` OR any key in `@quick_filter_keys` is `param_true?` OR any key in `@more_filter_keys` is `present_param?`. Build the chip list via a private helper `applied_chips(params)` returning an ordered list of `%{key, label, remove_to}`:
  - For "q": include only when present; label `Search: <value>` (use the raw value); remove_to drops "q".
  - For each quick key that is `param_true?`: label = humanized key (capitalize the word, e.g. "Confirmed", "MFA", "Passkeys", "Locked", "Deleted" — you may keep a small label map so "mfa"→"MFA" reads right; for others use String.capitalize on the single word). remove_to drops that key.
  - For each more key that is present: label = `<Human key>: <value>` (e.g. "Provider: github", "Registered from: 2026-05-01", "Organization: acme"). remove_to drops that key.
  remove_to is built by `index_path(@admin_scope) |> append_query(params |> Map.delete(key) |> Map.put("page", "1"))` so other filters survive and pagination resets. Ignore non-filter keys entirely (never iterate page/page_size/order_by/order_direction). Render the region as a `sg-cluster` (wrap) of `sg-applied-chip` elements: each chip is a small inline element showing the label text plus an `<a>` ✕ remove link with `aria-label={"Remove filter " <> label}` pointing at remove_to; then a trailing "Clear all" `<a href={index_path(@admin_scope)} class="sg-btn sg-btn--ghost sg-btn--sm">Clear all</a>`. The chip markup is NOT test-pinned — shape it as: a span.sg-applied-chip containing a `<span>{label}</span>` and an `<a class="sg-applied-chip__remove" ...>✕</a>` (use ✕ glyph or "×"; provide `sr-only` text "remove" if the glyph alone is ambiguous).

(3) TEACHING EMPTY STATES — the existing `<div :if={@rows == []} class="sg-empty-state">` keeps the title `No users match this view` (PINNED — do not change the title text). Branch the BODY (and add an action) on `any_filter_active?(@current_params)`:
  - Filtered-empty (any_filter_active? true): keep a recovery-oriented body (e.g. "No users match the active filters. Clear them to widen the result set.") AND add a one-click action — an `<a href={index_path(@admin_scope)} class="sg-btn sg-btn--secondary sg-btn--sm">Clear all filters</a>` inside the empty-state.
  - Genuine zero (any_filter_active? false): show an orienting teaching body that does NOT imply an error, e.g. "Users appear here as people register and sign in. Once accounts exist, you can search, filter, and open any user." No clear-action needed (there are no filters to clear).
  Keep everything inside the existing `sg-empty-state` structure.

Add the new private helpers near the other param helpers: `any_filter_active?/1`, `applied_chips/1`, `chip_label/2` (or inline label map), `showing_range/2`. Reuse `present_param?`, `param_true?`, `index_path`, `append_query`, `@quick_filter_keys`, `@more_filter_keys` — do not duplicate their logic. Do not remove any existing helper that is still referenced. If you introduce a label map for humanizing keys, keep it as a module attribute or a small function clause set (no fenced code in this action — express as prose: a function with clauses mapping "mfa"→"MFA", "registered_from"→"Registered from", "registered_to"→"Registered to", "organization"→"Organization", "provider"→"Provider", and a fallback that capitalizes the word).
  </action>
  <verify>
    <automated>cd /Users/jon/projects/sigra && mix compile --warnings-as-errors 2>&1 | grep -v '^Compiling\|^Generated' | grep -ci warning | grep -qx 0 && echo "compile clean"</automated>
  </verify>
  <done>
Template renders a "Showing X–Y of Z users" readout in place of "Page {n}"; an applied-filter
chip region appears only when filters are active with per-chip ✕ removal + Clear all; the empty
state keeps its pinned title and branches body+action between filtered and genuine-zero. Compiles
warnings-as-errors clean. The two index/filters test files still pass (run in Task 3 verify).
  </done>
</task>

<task type="auto">
  <name>Task 2: Truncate-with-tooltip + richer mobile card</name>
  <files>lib/sigra/admin/live/users_index_live.ex</files>
  <action>
Two markup refinements (CSS classes land in Task 3).

(A) TRUNCATE-WITH-TOOLTIP (desktop table). In the desktop `<tbody>`:
  - Email cell (`<span class="sg-muted sg-text-sm">{row.user.email}</span>`): add `sg-truncate` to the class and a `title={row.user.email}` attribute so the full email is on hover/SR while the cell ellipsizes. Keep the text content unchanged (full value stays in DOM).
  - Organization summary (`<span>{row.organization_summary}</span>` in the Organizations cell): add `sg-truncate` plus `title={row.organization_summary}`.
  Do not alter the User-name `sg-strong` line (names are short; leave as-is) or the code/id. The `title` attribute must carry the FULL value (truncate visually only).

(B) RICHER MOBILE CARD. The current mobile card (`data-testid="admin-users-mobile-results"`) collapses org/activity/registered into one `sg-stack sg-stack--1 sg-text-sm sg-muted` wall. Restructure that single muted stack into a more scannable hierarchy WITHOUT duplicating the desktop wholesale and WITHOUT removing any data:
  - Keep the identity block (name/email/id) and the status-pill cluster prominent and first (status stays scannable — do not bury it).
  - Split the meta wall into labeled groups: an "Organizations" line (org summary + count) visually distinct from an "Activity" group (activity_label) and a "Registered" line (registered_label). Use the existing `sg-kv`/`sg-meta-label`/`sg-meta-value` primitives OR small labeled spans (e.g. a muted 2xs uppercase label above each value) to give hierarchy. Keep it compact — mobile-first, no wall-of-muted-text. Apply `sg-truncate` + `title=` to the email and org summary here too if they can overflow the card.
  - Preserve `data-testid="admin-users-mobile-results"`, the `id="admin-users-mobile-results"`, and the "Open user" action with its `open_user_path` href + `?return_to=` behavior exactly.
  - Keep `row.extra_badges` and `row.extra_columns` rendered (do not drop hook-provided badges/columns).
Keep desktop column order untouched (User, Status, Organizations, Activity, Action) — do not reorder.
  </action>
  <verify>
    <automated>cd /Users/jon/projects/sigra && mix compile --warnings-as-errors 2>&1 | grep -v '^Compiling\|^Generated' | grep -ci warning | grep -qx 0 && echo "compile clean"</automated>
  </verify>
  <done>
Desktop email + org summary cells ellipsize with a full-value title= tooltip; the mobile card
presents status + labeled Organizations/Activity/Registered groups instead of one muted stack,
keeps its testid/id + "Open user", and retains extra badges/columns. Compiles clean.
  </done>
</task>

<task type="auto">
  <name>Task 3: Additive CSS (sg-applied-chip, sg-truncate, sg-tabular) + test/compile verification</name>
  <files>test/example/priv/static/assets/css/app.css</files>
  <action>
Add minimal, token-driven, additive utilities inside the existing `@layer sg-components` block
(place near `.sg-filter-chip`, around line ~882, so related primitives sit together). No new
`!important`. Mobile-first. Every value references an existing token.

(1) `.sg-applied-chip` — an inline-flex pill marking an active filter:
  - display: inline-flex; align-items: center; gap: var(--sg-space-2);
  - padding: var(--sg-space-1) var(--sg-space-2) (compact — smaller than sg-filter-chip);
  - border-radius: var(--sg-radius-full); background: var(--sg-color-brand-soft);
  - color: var(--sg-color-brand-strong); font-size: var(--sg-text-sm);
  - box-shadow: inset 0 0 0 1px color-mix(in oklab, var(--sg-color-brand) 22%, transparent);
  And `.sg-applied-chip__remove` — the ✕ link: small inline-flex, color inherits brand-strong,
  text-decoration none, line-height 1, padding minimal (var(--sg-space-1)); on hover (guard with
  `@media (hover: hover) and (pointer: fine)`) bump to a stronger tint or underline; include a
  visible focus treatment relying on the global focus ring (do not override focus). Use
  var(--sg-transition-tone) for the hover color transition. Keep the glyph optically centered.

(2) `.sg-truncate` — optical truncation utility:
  - display: block (or inline-block); max-width: a token-driven cap — use `min(100%, 22rem)` is NOT
    a token; instead set `max-width: 100%` with `overflow: hidden; text-overflow: ellipsis;
    white-space: nowrap;` so it ellipsizes to the cell/card width (the table cell already constrains
    width). This keeps it token-free of magic numbers while still clipping. (If a hard cap reads
    better in the table, you MAY add a width via an existing spacing token, but prefer cell-driven.)

(3) `.sg-tabular` — `font-variant-numeric: tabular-nums;` so the Showing X–Y of Z digits align
  (per ground-truth #6, summary chips already get tabular-nums; this is only for the new readout).

Keep additions inside the cascade layer; do not touch tokens or existing rules. After editing,
run the full verification below.
  </action>
  <verify>
    <automated>cd /Users/jon/projects/sigra && grep -c '!important' test/example/priv/static/assets/css/app.css >/tmp/imp_before 2>/dev/null; grep -Eq 'sg-applied-chip|sg-truncate|sg-tabular' test/example/priv/static/assets/css/app.css && echo "css utilities present"</automated>
  </verify>
  <done>
app.css contains token-driven `.sg-applied-chip` (+ `__remove`), `.sg-truncate`, and `.sg-tabular`
inside `@layer sg-components`, no new `!important`. Final gate (Task verification below) green.
  </done>
</task>

</tasks>

<verification>
Run after all three tasks (from repo root, live Postgres on 5432 per CLAUDE.md):

1. Compile clean (no warnings):
   `cd /Users/jon/projects/sigra && mix compile --warnings-as-errors`

2. The two pinned test contracts pass UNCHANGED (run from test/example):
   `cd /Users/jon/projects/sigra/test/example && mix test test/example_web/live/admin_user_index_live_test.exs test/example_web/live/admin_user_filters_live_test.exs`
   Both must be fully green — they pin: container ids/testids (desktop+mobile), "Search",
   "More filters", filter name=s, empty-state title "No users match this view", "Open user",
   and the ?return_to= URL.

3. No new `!important` introduced:
   `diff <(cat /tmp/imp_before) <(grep -c '!important' test/example/priv/static/assets/css/app.css)` → identical count.

4. Manual spot (orchestrator handles server restart — library path-dep not hot-reloaded):
   restart `mix phx.server` (PORT 4011), log in admin@demo.sigra.dev, visit /admin/users:
   filtered view shows chips + Clear all + "Showing X–Y of Z users"; clearing a chip drops only
   that filter; an over-long email ellipsizes with a hover tooltip; mobile card is scannable.
</verification>

<success_criteria>
- "Showing X–Y of Z users" readout present and accurate from Flop.Meta (zero case guarded); prev/next
  + aria/disabled states intact.
- Applied-filter chips render only when filters active, each removable (drops one key, preserves the
  rest, resets page), plus Clear all → index_path; non-filter keys never shown.
- Empty state keeps pinned title; filtered-empty offers Clear-all action; genuine-zero shows an
  orienting (non-error) teaching body.
- Long email + org summary truncate visually with full-value title= tooltip (DOM keeps full text).
- Mobile card is scannable (status + labeled Organizations/Activity/Registered groups), keeps testid +
  "Open user" + extra badges/columns.
- All pinned test strings/ids intact; both contract test files green; `mix compile
  --warnings-as-errors` clean; no new `!important`; column order unchanged.
</success_criteria>

<output>
Create `.planning/quick/260602-hhr-stage-3-admin-ui-pass-2-users-index-craf/260602-hhr-SUMMARY.md` when done.
</output>
</content>
</invoke>
