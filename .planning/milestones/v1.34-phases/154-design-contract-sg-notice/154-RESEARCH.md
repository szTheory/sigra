# Phase 154: Design Contract + sg-notice — Research

**Researched:** 2026-06-03
**Domain:** Admin UI CSS layer + ExDoc documentation artifact
**Confidence:** HIGH (all findings verified from authoritative source files in the repo)

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01:** Doc lives at `guides/reference/admin-design-contract.md` — peer of `guides/reference/generator-options.md`. NOT under `.planning/`.
- **D-02:** Doc registered in `mix.exs` ExDoc `extras:` list (lines ~186–230). Satisfies Phase 160 SC#4.
- **D-03:** Doc covers all 10 canonical components: job, winning CSS/markup, ARIA role(s), motion spec (including explicit "not animated" entries), when-NOT-to-use. Plus 3 archetypes (Overview / List / Detail) as explicit component compositions.
- **D-04:** `sg-notice` CSS in exactly ONE place: `test/example/priv/static/assets/css/app.css` inside `@layer sg-components`, adjacent to `.sg-list-row[data-tone]` (after line 967).
- **D-05:** No mirrored CSS copy. `admin-generated` lane probes routes/markup, never diffs `app.css`.
- **D-06:** `sg-notice` reuses existing `[data-tone]` token set: `--sg-color-{ok,warn,risk,info}-soft`, `--sg-color-{ok,warn,risk,info}`, `--sg-radius-sm`, `--sg-space-4`, `--sg-color-panel`, `--sg-transition-tone`, `--sg-elev-inset`. No new token or motion primitive.
- **D-07:** Documents current reality and already-locked winners — no new contested design calls. Header winner already locked by COHR-02: open `sg-page-header` beats boxed `sg-card` header.
- **D-08:** "stat" and chip variants are markup-consolidation targets. No `.sg-stat` CSS class invented here. Executable component form is Phase 155 (COMP-01); migration is Phase 156 (COHR-01).

**Hard constraints (locked):** No LiveView files modified. No Playwright baselines changed. `admin-generated` installer-parity lane stays green. All new styles inside `@layer sg-components` — no unlayered rules, no new `!important`, no new tokens/motion primitives. No new Hex deps, no Tailwind, no Alpine.

### Claude's Discretion
- Exact section ordering, table layout, and prose of `admin-design-contract.md` (within D-03 coverage requirement).
- Exact ExDoc group/placement of the new extra in `mix.exs` (alongside existing reference guides).
- Exact CSS property values for `sg-notice` within D-06's token set (~15 lines, behavior-preserving vs. current `sg-list-row data-tone` rendering).

### Deferred Ideas (OUT OF SCOPE)
- Building the executable `Sigra.Admin.Components` module and the 10 component functions → Phase 155 (COMP-01/COMP-02).
- Migrating LiveView call sites to the shared components and re-recording intended baseline deltas → Phase 156 (COHR-01..06).
- Any net-new admin surfaces, nav restructure, or new token/motion primitives → out of milestone scope per PROJECT.md / STATE.md.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| COMP-03 | A committed "Job → Component" mapping plus 3 page archetypes (Overview / List / Detail) document the same-job→same-component conventions, including when-NOT-to-use, ARIA, and motion specs. | Current markup from all 6 LiveViews inventoried; canonical sources verified; ExDoc wiring pattern confirmed. |
| COMP-04 | The one new `sg-notice` component style is added inside the existing `@layer sg-components` using existing tokens only (no new tokens or motion primitives). | Exact `.sg-list-row[data-tone]` template confirmed at lines 945–967; all 6 tokens verified in `:root`. |
</phase_requirements>

---

## Summary

Phase 154 is a pure artifacts phase: one Markdown governance document and ~15 lines of CSS. No behavior changes. The research confirms all decisions are verifiable against the repo source files; nothing requires external library investigation. The planning task is entirely a matter of specifying exact file locations, content structure, and verification strategy.

The `.sg-list-row[data-tone]` tone rules at `app.css:945–967` are the exact template for `sg-notice`. The CSS is 100% verified — token names, selector pattern, property values. The ExDoc wiring is confirmed: `guides/reference/generator-options.md` is the single existing precedent; the new file slots into the same `"Reference"` regex group. All 6 admin LiveViews were read and their component usage inventoried below.

**Primary recommendation:** The planner can write extremely specific task actions — the executor needs no design judgment. Every token name, line number, selector, and markup pattern is documented below.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| `sg-notice` CSS definition | Static asset (app.css) | — | Style lives in the single hand-authored CSS file; no server or browser JS involved |
| Design contract doc | Repository artifact (guides/) | ExDoc build | Markdown file rendered by ExDoc at build time; no runtime tier |
| ExDoc `extras:` registration | Build config (mix.exs) | — | Compile-time only; no runtime impact |
| Playwright / parity lane safety | CI verification | — | Confirmed CSS-agnostic; no tier conflict |

---

## Standard Stack

This phase introduces no new packages. No installation step.

### No New Dependencies

| Reason | Detail |
|--------|--------|
| CSS-only addition | ~15 lines inside existing `@layer sg-components` in `app.css` |
| Documentation only | Plain Markdown + ExDoc config edit |
| Hard constraint | D-06, STATE.md line 41: "No new Hex deps, no Tailwind, no Alpine.js" |

---

## Package Legitimacy Audit

> No packages are installed in this phase. Section intentionally empty.

**Packages removed due to slopcheck [SLOP] verdict:** none
**Packages flagged as suspicious [SUS]:** none

---

## Architecture Patterns

### System Architecture Diagram

```
Repository source files
        |
        v
app.css (@layer sg-components)          mix.exs (extras:)
  └─ .sg-list-row[data-tone] [lines 945–967]    └─ Reference group regex
  └─ [INSERT] .sg-notice [after line 967]        └─ [INSERT] admin-design-contract.md
                                                            |
                                         guides/reference/admin-design-contract.md
                                                            |
                                                     ExDoc HTML build
                                                     (hexdocs + local `mix docs`)
```

No browser JS. No LiveView event. No server logic. Both deliverables are consumed at build time (ExDoc) and static serving (app.css).

### Recommended Project Structure

No new directories. Both files slot into existing locations:

```
guides/reference/
├── generator-options.md        # existing precedent
└── admin-design-contract.md    # NEW (deliverable 1)

test/example/priv/static/assets/css/
└── app.css                     # edit in place (deliverable 2, ~15 lines after line 967)

mix.exs                         # edit: add one entry to extras:
```

---

## Verified Current State: app.css `@layer sg-components`

**Source:** `test/example/priv/static/assets/css/app.css` [VERIFIED: direct file read]

### Layer declaration (line 15)

```css
@layer sg-base, sg-components, sg-overrides;
```

### Token block (`:root`, lines 20–188)

All tokens confirmed present for `sg-notice` use:

| Token | Value | Verified |
|-------|-------|---------|
| `--sg-space-4` | `1rem` (16px) | line 25 |
| `--sg-radius-sm` | `0.5rem` (8px) | line 84 |
| `--sg-color-panel` | `#ffffff` (light) | line 61 |
| `--sg-color-panel-alt` | `#fbfaf7` (light) | line 62 |
| `--sg-color-ok-soft` | `#ecfdf3` | line 78 |
| `--sg-color-warn-soft` | `#fff7e6` | line 76 |
| `--sg-color-risk-soft` | `#fff1f0` | line 74 |
| `--sg-color-info-soft` | `#eef2ff` | line 80 |
| `--sg-color-ok` | `#176b43` (light) / `#5dd1a0` (dark) | lines 77, 173 |
| `--sg-color-warn` | `#a15c00` (light) / `#f5c451` (dark) | lines 75, 174 |
| `--sg-color-risk` | `#b42318` (light) / `#f8a39c` (dark) | lines 73, 172 |
| `--sg-color-info` | `#1d4ed8` (light) / `#9db8f5` (dark) | lines 79, 175 |
| `--sg-elev-inset` | `inset 0 0 0 1px var(--sg-color-line)` | line 99 |
| `--sg-transition-tone` | `color/background-color/box-shadow var(--sg-motion-fast) var(--sg-ease)` | lines 127–130 |
| `--sg-motion-fast` | `140ms` | line 119 |
| `--sg-ease` | `cubic-bezier(0.2, 0, 0, 1)` | line 122 |

Dark-mode `@media (prefers-color-scheme: dark)` at lines 160–185 overrides tone colors automatically — `sg-notice` inherits these with no additional dark-mode rules needed.

### Exact `.sg-list-row[data-tone]` template (lines 945–967)

This is the direct template for `sg-notice`. Reproduced verbatim:

```css
/* lines 945–967 in app.css — VERIFIED by direct file read */
.sg-list-row {
  border-radius: var(--sg-radius-sm);
  background: var(--sg-color-panel-alt);
  box-shadow: var(--sg-elev-inset);
  padding: var(--sg-space-4);
  transition: var(--sg-transition-tone);
}
.sg-list-row[data-tone="ok"] {
  background: color-mix(in oklab, var(--sg-color-ok-soft) 62%, var(--sg-color-panel));
  box-shadow: inset 3px 0 0 0 var(--sg-color-ok), inset 0 0 0 1px color-mix(in oklab, var(--sg-color-ok) 18%, transparent);
}
.sg-list-row[data-tone="warn"] {
  background: color-mix(in oklab, var(--sg-color-warn-soft) 62%, var(--sg-color-panel));
  box-shadow: inset 3px 0 0 0 var(--sg-color-warn), inset 0 0 0 1px color-mix(in oklab, var(--sg-color-warn) 20%, transparent);
}
.sg-list-row[data-tone="risk"] {
  background: color-mix(in oklab, var(--sg-color-risk-soft) 62%, var(--sg-color-panel));
  box-shadow: inset 3px 0 0 0 var(--sg-color-risk), inset 0 0 0 1px color-mix(in oklab, var(--sg-color-risk) 20%, transparent);
}
.sg-list-row[data-tone="info"] {
  background: color-mix(in oklab, var(--sg-color-info-soft) 62%, var(--sg-color-panel));
  box-shadow: inset 3px 0 0 0 var(--sg-color-info), inset 0 0 0 1px color-mix(in oklab, var(--sg-color-info) 20%, transparent);
}
```

**Note on `ok` vs other tones:** `ok` uses `18%` opacity for the ring, `warn`/`risk`/`info` use `20%`. This asymmetry exists in the source and must be preserved in `sg-notice` to maintain visual parity with `sg-list-row`.

### Insertion point for `sg-notice`

Insert immediately after line 967 (after the closing `}` of `.sg-list-row[data-tone="info"]`), before `.sg-kv` at line 969. This keeps all tone-related row/notice rules grouped together.

### `prefers-reduced-motion` block (lines 1437–1447)

```css
@media (prefers-reduced-motion: reduce) {
  *,
  *::before,
  *::after {
    animation-duration: 0.01ms !important;
    animation-iteration-count: 1 !important;
    scroll-behavior: auto !important;
    transition-property: color, background-color, border-color, box-shadow, opacity, fill, stroke !important;
    transition-duration: var(--sg-motion-fast) !important;
  }
}
```

This is the ONLY `!important` in the file. `sg-notice` inherits this automatically — no additional `prefers-reduced-motion` rules needed. `color`, `background-color`, and `box-shadow` are all in the override `transition-property` list, so they remain at `var(--sg-motion-fast)` even under reduced-motion.

### `@layer sg-components` closing brace (line 1418)

The `@layer sg-components { ... }` block closes at line 1418 (after `.sg-skeleton`). `sg-notice` is inserted well inside this block (after line 967) — no risk of accidentally exiting the layer.

---

## Verified Current State: 10 Canonical Components in LiveViews

**Sources:** All 6 admin LiveView files read directly. [VERIFIED: direct file read]

### Component 1: `summary_chip` — Compact boolean property badge

**Current location:** `users_index_live.ex` only (private `summary_chip/1` component, line 336)

**Current markup:**
```html
<!-- users_index_live.ex lines 78–84 (render) and 336–343 (defp) -->
<dl class="sg-metric-grid">
  <div class="sg-metric">
    <dt>{@label}</dt>
    <dd>{@value}</dd>
  </div>
</dl>
```

**CSS classes:** `sg-metric-grid` (lines 1092–1096), `sg-metric` (lines 1097–1101). Non-interactive. No tone. No link.

**Job:** Shows aggregate counts (Total, Confirmed, MFA, Passkeys, Locked, Deleted) as read-only posture tiles in the list-screen header.

**ARIA:** `<dl>` with `<dt>`/`<dd>` pairs — definition list semantics, no additional ARIA needed.

**Motion:** Not animated. No hover/focus state on the container. Static read-only display.

---

### Component 2: `stat_link` — Numeric KPI with navigation

**Current location:** `index_live.ex` and `organization_live.ex` (both use private `metric_link/1`, lines 118–125 and 169–176 respectively)

**Current markup:**
```html
<!-- index_live.ex lines 118–125 -->
<a href={@href} class="sg-metric-link">
  <span class="sg-metric-link__label">{@label}</span>
  <span class="sg-metric-link__value">{@value}</span>
</a>
```

**CSS classes:** `sg-metric-link` (lines 1176–1184), `sg-metric-link__label` (lines 1186–1191), `sg-metric-link__value` (lines 1193–1198). Is a real `<a>` tag. Has hover lift via `box-shadow`.

**Job:** Deep-link entry point from posture strip to filtered user list.

**ARIA:** Native `<a>` — inherits link semantics. No additional ARIA.

**Motion:** Hover: `box-shadow` transition `140ms var(--sg-ease)`. No transform on enter.

---

### Component 3: `stat` — Numeric KPI without navigation (read-only)

**Current location:** Does NOT exist as a dedicated component anywhere yet. The "stat without link" posture is currently handled inline. In `organization_live.ex` (line 71), the risk queue entry is a `sg-list-row` with a tone, not a standalone stat widget.

**Current markup:** No dedicated markup. The demoted stats concept is expressed via `sg-metric-link` items that happen to have no separate non-link variant — or via ad-hoc `sg-meta-label`/`sg-meta-value` pairs.

**Doc note (D-08):** Document as markup-consolidation target. The canonical form (a `<span>` + `<span>` non-link block analogous to `sg-metric-link` but not an `<a>`) is deferred to Phase 155 (COMP-01).

---

### Component 4: `task_card` — Verb-first action prompt

**Current location:** `index_live.ex` (private `task_card/1`, line 132) and `organization_live.ex` (private `task_card/1`, line 183). Identical markup in both.

**Current markup:**
```html
<!-- index_live.ex lines 132–144 -->
<article class="sg-card sg-card-hover sg-stack sg-stack--3">
  <div class="sg-stack sg-stack--2">
    <h2 class="sg-section-heading">{@title}</h2>
    <p class="sg-section-copy">{@body}</p>
  </div>
  <div class="sg-cluster">
    <a href={@href} class="sg-btn sg-btn--primary">{@action}</a>
  </div>
</article>
```

**CSS classes:** `sg-card` + `sg-card-hover` (hover lift: box-shadow + translateY(-1px) at 140ms).

**Job:** Verb-first entry point to a primary admin task. Sits above the stat strip in Overview archetype.

**ARIA:** `<article>` with `<h2>` heading. The `<a>` is the interactive element. No additional ARIA needed.

**Motion:** Hover lift (`translateY(-1px)` + `box-shadow` transition) — pointer-device only via `@media (hover: hover) and (pointer: fine)`. Not animated on keyboard focus (focus-visible uses `box-shadow` ring only).

---

### Component 5: `applied_chip` — Active filter indicator

**Current location:** `users_index_live.ex` (inline, lines 167–180) and `audit_user_live.ex` (inline, lines 137–152). Both use identical markup.

**Current markup:**
```html
<!-- users_index_live.ex lines 167–180 -->
<div class="sg-cluster sg-cluster--start">
  <span class="sg-applied-chip">
    <span>{chip.label}</span>
    <a class="sg-applied-chip__remove"
       href={remove_chip_path(...)}
       aria-label={"Remove filter " <> chip.label}>
      <span aria-hidden="true">&times;</span>
      <span class="sr-only">remove</span>
    </a>
  </span>
  <a href={...} class="sg-btn sg-btn--ghost sg-btn--sm">Clear all</a>
</div>
```

**CSS classes:** `sg-applied-chip` (lines 885–895), `sg-applied-chip__remove` (lines 896–905). Brand-colored pill with interactive remove link.

**Job:** Shows active filters above results; clicking remove deactivates the filter.

**ARIA:** Remove link has explicit `aria-label={"Remove filter " <> chip.label}`. `<span aria-hidden="true">&times;</span>` hides the × from screen readers. `<span class="sr-only">remove</span>` provides text fallback.

**Motion:** `sg-applied-chip__remove` has `transition: var(--sg-transition-tone)` for hover color change. Not animated on filter-apply (keyboard-frequent — GATE-03).

---

### Component 6: `empty_state` — Zero-row slot content

**Current location:** `users_index_live.ex` (inline, line 285), `user_show_live.ex` (multiple: sessions line 188, identities line 222, organizations line 252, recent audit line 282).

**Current markup:**
```html
<!-- users_index_live.ex line 285 -->
<div class="sg-empty-state sg-stack sg-stack--3">
  <p class="sg-empty-state__title">No users match this view</p>
  <p class="sg-muted sg-text-sm">...</p>
</div>
```

**CSS classes:** `sg-empty-state` (lines 990–1000): `border: 1px dashed var(--sg-color-line-strong)`, `background: var(--sg-color-panel)`, `color: var(--sg-color-muted)`, `padding: var(--sg-space-6)`, `text-align: center`. `sg-empty-state__title`: `color: var(--sg-color-ink)`, `font-weight: var(--sg-weight-semibold)`.

**Note:** Some instances use `div.sg-empty-state` directly without the `__title` subclass (sessions/identities empty states use `<p class="sg-empty-state__title">` directly). Spacing is consistent via `sg-stack` wrapper.

**Job:** Dashed-border, centred placeholder when a list has zero rows.

**ARIA:** No additional ARIA. The heading role is `<p class="sg-empty-state__title">` — Phase 155 should use `<p>` or `<h3>` depending on context; document both are valid here.

**Motion:** Not animated. Static.

---

### Component 7: `page_back` — Single navigation step back

**Current location:** `user_show_live.ex` (inline, lines 90–95) and `audit_user_live.ex` (inline, lines 62–67). Both use a plain `<a>` with back-arrow, no dedicated CSS class.

**Current markup (`user_show_live.ex`):**
```html
<div class="sg-cluster sg-cluster--between">
  <a class="sg-btn sg-btn--ghost sg-btn--sm" href={@return_to}>
    <span aria-hidden="true">&larr;</span> Back to users
  </a>
  <span class="sg-muted sg-text-sm">{scope_copy(@admin_scope)}</span>
</div>
```

**Current markup (`audit_user_live.ex`):**
```html
<div class="sg-cluster sg-cluster--between">
  <a class="sg-btn sg-btn--ghost sg-btn--sm" href={@return_to}>
    <span aria-hidden="true">&larr;</span> Back to user
  </a>
  <span class="sg-muted sg-text-sm">{scope_copy(@admin_scope)}</span>
</div>
```

**CSS classes:** `sg-btn sg-btn--ghost sg-btn--sm` only. No dedicated `page_back` CSS class exists.

**Job:** Returns to the list screen (consumes `return_to` param). Appears only on leaf screens (Detail / per-user Audit).

**ARIA:** Native `<a>`. Arrow is `aria-hidden="true"`. Link text is descriptive ("Back to users").

**Motion:** Standard button hover/active transitions. Not animated on keyboard navigation.

---

### Component 8: `scope_ribbon` — Persistent in-body scope indicator

**Current location:** No dedicated `scope_ribbon` component or CSS class exists. Scope is currently shown as a `<span class="sg-muted sg-text-sm">{scope_copy(@admin_scope)}</span>` alongside the back-nav in `user_show_live.ex` (line 94) and `audit_user_live.ex` (line 66).

The topbar scope pill (`sg-scope-pill` in `sg-admin-topbar`) is a different element — it appears in the layout shell, not the page body.

**Doc note (D-07):** Document the canonical form as the in-body scoping indicator alongside `page_back`. The scope pill pattern is the CSS hook (`sg-scope-pill`). Phase 155 will define the exact component API.

---

### Component 9: `notice` — Contextual alert with semantic tone

**Current location — two ad-hoc instances:**

1. **`user_show_live.ex` line 131** (summary alert inside the Identity card):
```html
<div :if={summary_alert(@detail)} class="sg-list-row" data-tone={elem(summary_alert(@detail), 0)}>
  <p class="sg-text-sm">{elem(summary_alert(@detail), 1)}</p>
</div>
```

2. **`organization_live.ex` line 71** (risk queue row inside "Scoped attention" card):
```html
<div class="sg-list-row" data-tone={if(Map.get(@summary_counts, :locked, 0) > 0, do: "risk", else: nil)}>
  <p class="sg-meta-label">Risk queue</p>
  <p class="sg-meta-value">...</p>
</div>
```

**Current CSS:** Uses `.sg-list-row[data-tone]` rules — the block-level notice treatment is borrowed from the list-row class.

**Phase 154 goal:** Add `.sg-notice` CSS that is visually identical to `.sg-list-row[data-tone]` so Phase 156 can do a call-site swap to `<.notice>` without a Playwright baseline re-record.

**Job:** Block-level contextual alert with semantic tone (`ok`/`warn`/`risk`/`info`). ARIA live region.

---

### Component 10: `skeleton` — Loading placeholder

**Current location:** CSS defined at `app.css` lines 1395–1417. No LiveView currently renders a skeleton — the component is defined for future use (Phase 157 async overview data: LAND-04).

**Current CSS:**
```css
/* app.css lines 1395–1417 */
.sg-skeleton {
  position: relative;
  overflow: hidden;
  min-height: var(--sg-space-4);
  border-radius: var(--sg-radius-sm);
  background: color-mix(in oklab, var(--sg-color-line) 60%, transparent);
}
.sg-skeleton::after {
  content: "";
  position: absolute;
  inset: 0;
  background: linear-gradient(
    90deg,
    transparent,
    color-mix(in oklab, var(--sg-color-panel) 70%, transparent),
    transparent
  );
  transform: translateX(-100%);
  animation: sg-skeleton-shimmer var(--sg-motion-slow) var(--sg-ease) infinite;
}
@keyframes sg-skeleton-shimmer {
  to { transform: translateX(100%); }
}
```

**Motion:** Shimmer uses `transform: translateX` only (composite-safe). `prefers-reduced-motion` strips the `animation` via the universal `animation-duration: 0.01ms !important` rule, leaving a static block.

**Job:** Replaces async content during load. Matches the shape of the content it will replace.

---

## Verified Current State: 3 Page Archetypes

**Sources:** Verified from LiveView renders. [VERIFIED: direct file read]

### Overview Archetype — `index_live.ex` (global) + `organization_live.ex` (org)

**Canonical structure from `index_live.ex`:**
```
<section class="sg-stack sg-stack--6">
  <header class="sg-page-header">          ← open header (no sg-card wrapper)
    <p class="sg-page-kicker">
    <h1 class="sg-page-title">
    <p class="sg-page-copy">
  </header>

  <div class="sg-grid sg-grid--3">         ← task_card grid (3 cards global, 2 org)
    task_card × N

  <section class="sg-card sg-posture-strip sg-stack sg-stack--3">  ← demoted metrics
    <a class="sg-posture-strip__risk">     ← needs-review status pill (links to filtered)
      <span class="sg-status-pill" data-tone={...}>
    </a>
    <div class="sg-cluster sg-cluster--3">
      metric_link × N                      ← stat_link strip
    </div>

  <section class="sg-stack sg-stack--3">  ← capability matrix (lowest priority)
    capability × N
```

**Key observations:**
- Global Overview has 3 task cards; Org Overview has 2.
- The needs-review pill is INSIDE `sg-posture-strip` (a card surface), NOT a standalone `sg-notice`. This is the "loud when count > 0" alarm — Phase 157 will promote it. For Phase 154 documentation, record the current state.
- No `sg-notice` component is used in Overview pages yet (the alarm is a status pill, not a block notice).
- `organization_live.ex` line 71 uses `sg-list-row data-tone` as a contextual alert inside the "Scoped attention" card — this is one of the two `notice` consolidation targets.

### List Archetype — `users_index_live.ex`

**Canonical structure:**
```
<section class="sg-stack sg-stack--6">
  <header class="sg-page-header">          ← open header (D-07 winner, COHR-02 locked)
    <p class="sg-page-kicker">
    <h1 class="sg-page-title">
    <p class="sg-page-copy">
    <dl class="sg-metric-grid">            ← summary_chip strip
      summary_chip × N

  <form class="sg-filter-panel sg-stack">  ← filter panel
    <div class="sg-search-row">
    <div class="sg-cluster">               ← quick_filter chips (checkbox-based)
      quick_filter × N
    <div class="sg-stack sg-stack--3">     ← "More filters" expandable (sg-collapse)
      more filter fields

  <div class="sg-cluster sg-cluster--start">  ← applied_chip row (if any filter active)
    applied_chip × N
    <a "Clear all">

  <div class="sg-table-panel sg-show-desktop">  ← desktop table
    <table class="sg-table">

  <div class="sg-stack sg-show-mobile">   ← mobile card stack
    <article class="sg-card sg-stack"> × N

  <div class="sg-empty-state sg-stack">  ← zero-rows state

  <nav class="sg-cluster sg-cluster--between">  ← pagination
```

### Detail Archetype — `user_show_live.ex`

**Canonical structure:**
```
<section class="sg-stack sg-stack--6">
  <div class="sg-cluster sg-cluster--between">  ← page_back + scope copy
    <a class="sg-btn sg-btn--ghost sg-btn--sm" href={@return_to}>

  <section class="sg-card sg-stack sg-stack--3">  ← Identity card (BOXED — outlier, D-07)
    <h1 class="sg-page-title">
    <dl class="sg-summary-facts">               ← stat strip
    <div class="sg-list-row" data-tone={...}>   ← notice (consolidation target, line 131)

  <section class="sg-card sg-stack sg-stack--3">  ← Sessions card
    <div class="sg-table-panel">                ← session table
    <div class="sg-empty-state">                ← zero sessions

  <div class="sg-detail-grid">                  ← 2-column detail grid
    <section class="sg-detail-panel">           ← Security panel
    <section class="sg-detail-panel">           ← Identities panel

  <section class="sg-card sg-stack sg-stack--3">  ← Organizations card
    <div class="sg-list">
      <article class="sg-list-row sg-stack">   ← org membership rows

  <section class="sg-card sg-stack sg-stack--3">  ← Recent Audit card
    <div class="sg-list">
      <article class="sg-list-row" data-tone={...}> ← audit tone rows

  <section class="sg-danger-panel sg-stack">   ← Danger Zone

  <dialog class="modal">                        ← confirm dialog
```

**Important:** The Identity card uses `sg-card` (BOXED header) — this is the D-07 documented outlier. COHR-02 locks "open `sg-page-header`" as the winner; reconciliation is in Phase 156. Phase 154 documents current reality: the Detail archetype CURRENTLY has a boxed identity card.

---

## Verified Current State: ExDoc `extras:` Registration Pattern

**Source:** `mix.exs` lines 186–248 [VERIFIED: direct file read]

### How to register the new guide

The new file goes in the `extras:` list (plain string, no options map needed):

```elixir
# mix.exs extras: list — add after "guides/reference/generator-options.md"
"guides/reference/admin-design-contract.md",
```

### `groups_for_extras:` — "Reference" group (line 243)

```elixir
groups_for_extras: [
  Introduction: ~r{guides/introduction/.?},
  Reference: ~r{guides/reference/.?},        # ← this regex matches the new file automatically
  Flows: ~r{guides/flows/.?},
  ...
]
```

The `Reference: ~r{guides/reference/.?}` regex already covers any file under `guides/reference/` — **no change to `groups_for_extras:` is needed**. Only an entry in `extras:` is required.

### Current `extras:` count and position

`guides/reference/generator-options.md` is at line 199 (the only `guides/reference/` file currently in `extras:`). The new entry should be added immediately after it for logical grouping.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Dark-mode tone color | Custom dark-mode `sg-notice` overrides | Token overrides in `:root @media (prefers-color-scheme: dark)` at lines 160–185 | Tone tokens (`--sg-color-ok`, etc.) already have dark-mode values; `sg-notice` inherits them |
| Reduced-motion | Extra `@media (prefers-reduced-motion)` rule on `sg-notice` | Existing universal rule at lines 1437–1447 | The universal rule strips `animation`, shortens `transition`; `box-shadow` and `background-color` are already listed |
| ARIA live region | CSS | HEEx markup in Phase 155 | CSS cannot set ARIA roles; ARIA is a Phase 155 concern |
| `sg-notice` for form errors | Custom form error block | `sg-error` / Phoenix form helpers | `sg-notice` is block-level contextual; form errors are field-level |

**Key insight:** The existing `sg-*` token layer and universal motion/reduced-motion rules handle all edge cases automatically. The only CSS needed is the ~15-line selector + tone-variant block.

---

## Common Pitfalls

### Pitfall 1: Writing CSS outside `@layer sg-components`

**What goes wrong:** An unlayered rule (not inside `@layer sg-components { }`) would have lower specificity than layered rules in some cascade configurations, OR it would fight with the layer ordering.

**Why it happens:** The `@layer` block opens at line 203 and closes at line 1418. If you insert after line 1418 but before line 1423 (`@layer sg-overrides`), you would be outside the block.

**How to avoid:** Insert at line 968 (after `.sg-list-row[data-tone="info"]` closes). The layer block does not close until line 1418. Verify with a line count sanity check.

**Warning signs:** `git diff` shows the insertion is after the `}` at line 1418.

---

### Pitfall 2: Modifying LiveView files

**What goes wrong:** Any edit to `lib/sigra/admin/live/*.ex` violates the phase hard constraint and risks Playwright baseline churn.

**Why it happens:** The executor might think "let me also update the markup to use `sg-notice` while I'm here."

**How to avoid:** Phase 154 adds the CSS CLASS DEFINITION only. No LiveView renders `.sg-notice` in Phase 154 — that is Phase 156's job (COHR-05).

**Warning signs:** `git diff` shows changes to any file under `lib/sigra/admin/live/`.

---

### Pitfall 3: Introducing `--sg-color-panel-alt` instead of the `color-mix` formula

**What goes wrong:** Using `background: var(--sg-color-panel-alt)` for all tone variants instead of the `color-mix(in oklab, var(--sg-color-{tone}-soft) 62%, var(--sg-color-panel))` formula.

**Why it happens:** `--sg-color-panel-alt` is the base background for `.sg-list-row` (neutral, no tone). The toned variants use `color-mix` — this is what produces the softened tone fill.

**How to avoid:** The `sg-list-row` template is exact: base rule uses `var(--sg-color-panel-alt)`; toned variants use `color-mix`. Copy the pattern verbatim.

---

### Pitfall 4: Adding a new `!important`

**What goes wrong:** Breaks the documented invariant ("only `!important` in this file is the `prefers-reduced-motion` block").

**Why it happens:** Temptation to override a specificity conflict.

**How to avoid:** `sg-notice` has no specificity conflict — it is a new class with no existing competing rules. No `!important` is ever needed.

---

### Pitfall 5: Omitting `transition: var(--sg-transition-tone)` on the base rule

**What goes wrong:** Tone changes (e.g., if a notice's `data-tone` is set dynamically via LiveView) would snap instead of transitioning.

**Why it happens:** Forgetting the transition on the base rule while correctly adding it to the toned variants.

**How to avoid:** The `sg-list-row` base rule has `transition: var(--sg-transition-tone)` — copy it. The transition lives on the base selector, not the variants.

---

### Pitfall 6: Missing `ok` tone's 18% (vs 20%) ring opacity

**What goes wrong:** Visual inconsistency between `sg-notice[data-tone="ok"]` and `sg-list-row[data-tone="ok"]`.

**Why it happens:** The existing `sg-list-row` rules use `18%` for `ok` and `20%` for `warn`/`risk`/`info`. This asymmetry is intentional — `ok` is the most common state and a slightly lighter ring prevents visual noise.

**How to avoid:** Copy the exact `color-mix` percentages from the `sg-list-row` rules (18% for ok, 20% for the rest).

---

## Code Examples

### Exact `sg-notice` CSS to insert (verified against token set)

Insert after `app.css` line 967, inside `@layer sg-components`:

```css
/* NOTICE — behavior-preserving consolidation of sg-list-row[data-tone] alert pattern.
 * Phase 156 (COHR-05) migrates call sites to <.notice>. Source: Phase 154 COMP-04. */
.sg-notice {
  border-radius: var(--sg-radius-sm);
  background: var(--sg-color-panel-alt);
  box-shadow: var(--sg-elev-inset);
  padding: var(--sg-space-4);
  transition: var(--sg-transition-tone);
}
.sg-notice[data-tone="ok"] {
  background: color-mix(in oklab, var(--sg-color-ok-soft) 62%, var(--sg-color-panel));
  box-shadow: inset 3px 0 0 0 var(--sg-color-ok), inset 0 0 0 1px color-mix(in oklab, var(--sg-color-ok) 18%, transparent);
}
.sg-notice[data-tone="warn"] {
  background: color-mix(in oklab, var(--sg-color-warn-soft) 62%, var(--sg-color-panel));
  box-shadow: inset 3px 0 0 0 var(--sg-color-warn), inset 0 0 0 1px color-mix(in oklab, var(--sg-color-warn) 20%, transparent);
}
.sg-notice[data-tone="risk"] {
  background: color-mix(in oklab, var(--sg-color-risk-soft) 62%, var(--sg-color-panel));
  box-shadow: inset 3px 0 0 0 var(--sg-color-risk), inset 0 0 0 1px color-mix(in oklab, var(--sg-color-risk) 20%, transparent);
}
.sg-notice[data-tone="info"] {
  background: color-mix(in oklab, var(--sg-color-info-soft) 62%, var(--sg-color-panel));
  box-shadow: inset 3px 0 0 0 var(--sg-color-info), inset 0 0 0 1px color-mix(in oklab, var(--sg-color-info) 20%, transparent);
}
```

Line count: 16 lines (base + 4 variants + comment header = ~15 executable lines, 16 total with comment). Within the "~15 lines" budget from the requirements.

### ExDoc registration — exact edit to `mix.exs`

```elixir
# Before (mix.exs line ~199):
"guides/reference/generator-options.md",

# After:
"guides/reference/generator-options.md",
"guides/reference/admin-design-contract.md",
```

No other changes to `mix.exs`. The `groups_for_extras: [Reference: ~r{guides/reference/.?}]` regex already matches.

---

## State of the Art

| Old Approach | Current Approach | Status |
|---|---|---|
| `sg-list-row[data-tone]` for block-level alerts | `sg-notice[data-tone]` (Phase 154 adds CSS; Phase 156 migrates call sites) | Pending Phase 156 |
| Private `task_card/1` in each overview LiveView | Shared `Sigra.Admin.Components.task_card/1` | Pending Phase 155 |
| Private `metric_link/1` in each overview LiveView | Shared `Sigra.Admin.Components.stat_link/1` | Pending Phase 155 |
| Ad-hoc back-nav `<a>` + scope `<span>` | `<.page_back>` + `<.scope_ribbon>` | Pending Phase 155/156 |

---

## Assumptions Log

> All claims in this research were verified directly from repo source files. No assumed claims.

**If this table is empty:** All claims in this research were verified or cited — no user confirmation needed.

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| — | — | — | — |

---

## Open Questions (RESOLVED)

1. **`sg-notice__body` sub-element** — RESOLVED
   - What we know: The UI-SPEC mentions `.sg-notice__body` as an optional sub-element.
   - What's unclear: Should the CSS include `.sg-notice__body { }` as a stub? There is no existing usage to match.
   - Recommendation: Do NOT include `.sg-notice__body` in Phase 154 CSS (it adds complexity with no behavior-preserving target). Phase 155 defines the sub-element when building the HEEx component. Keep Phase 154 CSS to the minimal 5-rule block.

2. **`stat` component markup (read-only KPI)** — RESOLVED
   - What we know: No dedicated "stat without link" markup exists in any LiveView.
   - What's unclear: Should the contract doc describe a hypothetical markup, or just acknowledge the gap and defer?
   - Recommendation: Per D-08, document as "markup-consolidation target, form deferred to Phase 155 (COMP-01)." Do not invent markup — document the `sg-metric-link` pattern as the closest analog.

---

## Environment Availability

> Phase 154 is purely a code/config/docs artifact phase. No external tool dependencies beyond `git` and a text editor.

Step 2.6: SKIPPED (no external dependencies identified beyond the existing repo toolchain).

Verification commands (already available in the project's standard toolchain):

| Verification | Command | Available |
|---|---|---|
| CSS layer boundary check | `grep -n "@layer" test/example/priv/static/assets/css/app.css` | Standard grep |
| No `!important` added | `git diff test/example/priv/static/assets/css/app.css \| grep "!important"` | Standard git |
| No LiveView modified | `git diff lib/sigra/admin/live/` | Standard git |
| ExDoc builds | `mix docs` | Standard mix task |
| No Playwright baselines changed | `git diff test/example/priv/playwright/tests/\*-snapshots/` | Standard git |

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | N/A — artifacts-only phase; no functional behavior to test |
| Quick run command | `git diff --name-only` (verify only expected files changed) |
| Full suite command | `mix test` (no new test files needed; existing suite must stay green) |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| COMP-03 | Governance doc committed at correct path | File existence | `ls guides/reference/admin-design-contract.md` | ❌ Wave 0 |
| COMP-03 | Doc registered in ExDoc extras | Config check | `grep "admin-design-contract" mix.exs` | ❌ Wave 0 |
| COMP-04 | `sg-notice` CSS inside `@layer sg-components` | CSS grep | `grep -c "sg-notice" test/example/priv/static/assets/css/app.css` | ❌ Wave 0 |
| COMP-04 | No `!important` added | Diff check | `git diff app.css \| grep "!important"` — expect empty | ❌ Wave 0 |
| SC#4 | No LiveView modified | Diff check | `git diff lib/sigra/admin/live/` — expect empty | ❌ Wave 0 |
| SC#4 | No Playwright baselines changed | Diff check | `git diff test/example/priv/playwright/tests/*-snapshots/` — expect empty | ❌ Wave 0 |

### Sampling Rate

- **Per task commit:** `git diff --stat` — verify only expected files in diff
- **Per wave merge:** `mix test` — confirm existing suite green
- **Phase gate:** All 6 checklist items above green; `mix docs` succeeds; UI-SPEC checklist confirmed

### Wave 0 Gaps

- No test files needed — all validations are file-existence checks and `git diff` inspections
- `mix docs` must succeed (verifies ExDoc registration is valid YAML/config)

---

## Security Domain

> This is a CSS + documentation artifact phase. No authentication logic, no user data, no HTTP handlers, no secrets, no cryptography. ASVS categories are not applicable.

Security enforcement: not applicable to this phase.

---

## Sources

### Primary (HIGH confidence)

All sources are direct file reads from the working repository.

- `test/example/priv/static/assets/css/app.css` — `:root` tokens (lines 20–188); `@layer` declaration (line 15); `.sg-list-row[data-tone]` rules (lines 945–967); `.sg-empty-state` (lines 990–1000); `.sg-page-header` (lines 653–656); `.sg-card` (lines 756–759); `.sg-skeleton` (lines 1395–1417); `prefers-reduced-motion` (lines 1437–1447); `sg-status-pill` (lines 394–481); `sg-applied-chip` (lines 885–911); `sg-metric-grid` / `sg-metric` (lines 1092–1120); `sg-metric-link` (lines 1176–1199).
- `lib/sigra/admin/live/users_index_live.ex` — List archetype canonical, `summary_chip`, `quick_filter`, `applied_chip`, `empty_state` markup.
- `lib/sigra/admin/live/user_show_live.ex` — Detail archetype canonical, `page_back`, `notice` (sg-list-row usage line 131), `empty_state`, `summary_alert`.
- `lib/sigra/admin/live/index_live.ex` — Global Overview archetype, `task_card`, `metric_link` / `stat_link`.
- `lib/sigra/admin/live/organization_live.ex` — Org Overview archetype, `task_card`, `metric_link`, `notice` (sg-list-row usage line 71).
- `lib/sigra/admin/live/audit_index_live.ex` — Audit List archetype (confirmed: open `sg-page-header`, filter form, no `notice` component).
- `lib/sigra/admin/live/audit_user_live.ex` — Per-user Audit archetype, `page_back`, `applied_chip`.
- `mix.exs` lines 186–256 — ExDoc `extras:` list, `groups_for_extras:` confirming "Reference" regex.
- `guides/reference/generator-options.md` — Format precedent for new governance doc.
- `.planning/phases/154-design-contract-sg-notice/154-CONTEXT.md` — Locked decisions D-01..D-08.
- `.planning/phases/154-design-contract-sg-notice/154-UI-SPEC.md` — Visual and interaction contract.
- `.planning/REQUIREMENTS.md` — COMP-03, COMP-04 definitions.
- `.planning/STATE.md` — CSS boundary lock (line 41).
- `test/example/priv/playwright/tests/admin-generated.spec.ts` — Confirmed: probes routes/markup, no CSS diff.
- `scripts/ci/admin-acceptance-smoke.sh` — Confirmed: scaffolds host app and runs Playwright; no CSS comparison.

---

## Metadata

**Confidence breakdown:**

- `sg-notice` CSS (token names, values, formula): HIGH — every token and formula verified from `app.css` source
- `app.css` insertion point (line 967 + 1): HIGH — exact line numbers verified
- ExDoc registration (extras list + groups_for_extras regex): HIGH — verified from `mix.exs`
- 10-component markup inventory: HIGH — all 6 LiveViews read directly
- 3 archetype compositions: HIGH — verified from LiveView render functions
- Playwright lane CSS-agnosticism: HIGH — confirmed by reading spec and smoke script

**Research date:** 2026-06-03
**Valid until:** This research documents a static snapshot of the repo. Re-verify line numbers if any CSS or mix.exs changes land before planning is complete.
