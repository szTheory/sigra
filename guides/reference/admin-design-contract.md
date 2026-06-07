# Sigra Admin Design Contract

This document is the durable, citable authority for the Sigra admin UI component system. It satisfies requirement **COMP-03** and constrains Phases 155–160. The governing principle is **same job → same component**: when two places in the admin UI do the same job, they must use the same component. This document defines what those jobs are, which component wins, and when NOT to use each component.

All entries document **current reality** and **already-locked winners** only. No new design calls are made here.

## v1.36 Brand And Theme Addendum

The v1.36 admin brand pass promotes the ratified Rail Accent system from `brandbook/` into admin chrome while preserving the v1.34 component contract.

- The `sg-*` token layer remains the admin UI source of truth. Token values should stay aligned with `brandbook/tokens.*`; class names should not churn unless there is a deliberate migration.
- The admin shell owns Sigra identity. Use Rail Accent mark/lockup assets, never a placeholder tile or black wordmark on dark surfaces.
- Admin supports Light, Dark, and System. Explicit Light/Dark choices set `data-sg-admin-theme` on the document root and `data-theme` on `.sg-admin-shell`; System removes the override and follows `prefers-color-scheme`.
- Theme controls are shell-level utilities, not page content. They must be reachable by keyboard, expose selected state, and persist without server state.
- New visual polish must be routed through reusable `sg-*` primitives or `Sigra.Admin.Components`; one-off padding, radius, hover, and color fixes are contract drift.
- Browser coverage must include theme behavior, no broken brand assets, and axe checks on curated admin checkpoints.

See also: [Admin UI Principles](admin-ui-principles.md).

---

## Job -> Component Mapping

### Canonical Component: stat_link

| Property | Value |
|----------|-------|
| **Job** | Numeric KPI with a navigation destination. Used in posture strips to deep-link from a count to a filtered view. Always a real `<a>` element. |
| **Winning markup / CSS** | `<a href={@href} class="sg-metric-link"><span class="sg-metric-link__label">{@label}</span><span class="sg-metric-link__value">{@value}</span></a>` — CSS classes: `sg-metric-link`, `sg-metric-link__label`, `sg-metric-link__value`. Source: `index_live.ex:118–125`, `organization_live.ex:169–176`. |
| **ARIA role(s)** | Native `<a>` — inherits link semantics. No additional ARIA needed. Screen readers announce the link text (label + value). |
| **Motion spec** | Hover: `box-shadow` lift transition at 140ms `var(--sg-ease)`. Not animated on keyboard focus (focus-visible uses `box-shadow` ring only). Not animated on page load. |
| **When NOT to use** | Do NOT use `stat_link` for a numeric KPI that has no navigation destination — use `stat` (read-only, Phase 155 COMP-01). Do NOT use for non-numeric content. |

---

### Canonical Component: stat

| Property | Value |
|----------|-------|
| **Job** | Numeric KPI without navigation. Read-only posture metric. No `<a>` element. Used when a count communicates state but does not link anywhere. |
| **Winning markup / CSS** | Markup-consolidation target — no dedicated implementation yet. Closest analog is `sg-metric-link` markup without the `<a>` wrapper. Implemented in Phase 155 (COMP-01). Do NOT invent a `.sg-stat` CSS class. |
| **ARIA role(s)** | Static text — no interactive role. Semantics depend on container context (e.g. `<dl>` with `<dt>`/`<dd>` for labelled counts). |
| **Motion spec** | Not animated. Static read-only display element. |
| **When NOT to use** | Do NOT use `stat` when the KPI navigates to a filtered view — use `stat_link`. Do NOT invent `.sg-stat` CSS class (only the component abstraction is canonical). |

---

### Canonical Component: task_card

| Property | Value |
|----------|-------|
| **Job** | Verb-first action prompt for a primary admin task. Sits above the posture strip in the Overview archetype. Its CTA links to the action view. |
| **Winning markup / CSS** | `<article class="sg-card sg-card-hover sg-stack sg-stack--3"><div class="sg-stack sg-stack--2"><h2 class="sg-section-heading">{@title}</h2><p class="sg-section-copy">{@body}</p></div><div class="sg-cluster"><a href={@href} class="sg-btn sg-btn--primary">{@action}</a></div></article>`. Source: `index_live.ex:132–144`, `organization_live.ex:183–195`. |
| **ARIA role(s)** | `<article>` (implicit sectioning element) + `<h2>` heading. The `<a>` is the interactive element with descriptive text. No additional ARIA needed. |
| **Motion spec** | Hover lift: `translateY(-1px)` + `box-shadow` transition at 140ms, pointer-device only via `@media (hover: hover) and (pointer: fine)`. Not animated on keyboard focus (focus-visible ring only — `box-shadow`). Not animated on page load. |
| **When NOT to use** | Do NOT use `task_card` for informational-only content with no CTA (non-actionable cards). Do NOT use for list items or detail cards — those use `sg-card` directly without `sg-card-hover`. |

---

### Canonical Component: summary_chip

| Property | Value |
|----------|-------|
| **Job** | Aggregate count or boolean-state posture badge in a list-screen header. Non-interactive — communicates state, not action. |
| **Winning markup / CSS** | `<dl class="sg-metric-grid"><div class="sg-metric"><dt>{@label}</dt><dd>{@value}</dd></div></dl>`. CSS classes: `sg-metric-grid`, `sg-metric`. Source: `users_index_live.ex:78–84` (render), `users_index_live.ex:336–343` (private component). |
| **ARIA role(s)** | `<dl>` with `<dt>`/`<dd>` pairs — definition list semantics. Screen readers announce label/value pairs naturally. No additional ARIA needed. |
| **Motion spec** | Not animated. Static read-only display. No hover or focus state on the container. |
| **When NOT to use** | Do NOT use `summary_chip` for interactive filter state — use `applied_chip`. Do NOT use for a metric that links somewhere — use `stat_link`. |

---

### Canonical Component: applied_chip

| Property | Value |
|----------|-------|
| **Job** | Active filter indicator with a clear affordance. Shows which filters are currently active above the results table. Clicking the remove link deactivates the filter. |
| **Winning markup / CSS** | `<span class="sg-applied-chip"><span>{chip.label}</span><a class="sg-applied-chip__remove" href={remove_chip_path(...)} aria-label={"Remove filter " <> chip.label}><span aria-hidden="true">&times;</span><span class="sr-only">remove</span></a></span>`. CSS classes: `sg-applied-chip`, `sg-applied-chip__remove`. Source: `users_index_live.ex:167–180`, `audit_user_live.ex:137–152`. |
| **ARIA role(s)** | Remove link has explicit `aria-label={"Remove filter " <> chip.label}`. The `&times;` glyph is `aria-hidden="true"`. `<span class="sr-only">remove</span>` provides screen-reader text fallback. |
| **Motion spec** | `sg-applied-chip__remove` has `transition: var(--sg-transition-tone)` for hover color change (140ms). Not animated on filter-apply (keyboard-frequent interaction — per GATE-03). Not animated on page load or keyboard navigation. |
| **When NOT to use** | Do NOT use `applied_chip` for non-removable state badges — use `summary_chip`. Do NOT use for navigation links. |

---

### Canonical Component: empty_state

| Property | Value |
|----------|-------|
| **Job** | Dashed-border centred placeholder when a list or section has zero rows. Communicates the absence of content and optionally prompts a next step. |
| **Winning markup / CSS** | `<div class="sg-empty-state sg-stack sg-stack--3"><p class="sg-empty-state__title">...</p><p class="sg-muted sg-text-sm">...</p></div>`. CSS: `sg-empty-state` (dashed border, centred, `sg-color-line-strong`). Source: `users_index_live.ex:285`, `user_show_live.ex:188,222,252,282`. |
| **ARIA role(s)** | No additional ARIA. The `<p class="sg-empty-state__title">` provides a semantic heading for the empty region. Screen readers announce the content inline. |
| **Motion spec** | Not animated. Static display. |
| **When NOT to use** | Do NOT use `empty_state` for loading states — use `skeleton`. Do NOT use in non-list contexts (e.g., inside a form or notice). Do NOT use when there is an error — use `notice` with the appropriate tone. |

---

### Canonical Component: page_back

| Property | Value |
|----------|-------|
| **Job** | Single-step navigation back to the list screen. Consumes the `return_to` param. Appears only on leaf screens (Detail / per-user Audit). Not a breadcrumb. |
| **Winning markup / CSS** | `<a class="sg-btn sg-btn--ghost sg-btn--sm" href={@return_to}><span aria-hidden="true">&larr;</span> Back to users</a>` wrapped in `<div class="sg-cluster sg-cluster--between">` alongside the scope copy span. CSS classes: `sg-btn sg-btn--ghost sg-btn--sm`. No dedicated `page_back` CSS class. Source: `user_show_live.ex:90–95`, `audit_user_live.ex:62–67`. |
| **ARIA role(s)** | Native `<a>` — inherits link semantics. Arrow (`&larr;`) is `aria-hidden="true"`. Link text is descriptive ("Back to users", "Back to user"). |
| **Motion spec** | Standard button hover/active transitions. Not animated on keyboard navigation. Not animated on page load. |
| **When NOT to use** | Do NOT use `page_back` for multi-level hierarchy — use a breadcrumb for more than one step back. Do NOT use on non-leaf screens (Overview, List). |

---

### Canonical Component: scope_ribbon

| Property | Value |
|----------|-------|
| **Job** | Persistent in-body scope indicator showing whether the admin is viewing Global context or a specific organisation. Present on every list and leaf screen. |
| **Winning markup / CSS** | Currently rendered as `<span class="sg-muted sg-text-sm">{scope_copy(@admin_scope)}</span>` alongside `page_back` inside `<div class="sg-cluster sg-cluster--between">`. No dedicated `scope_ribbon` CSS class yet. Source: `user_show_live.ex:94`, `audit_user_live.ex:66`. Implemented in Phase 155 (COMP-01); present on every list and leaf screen as of Phase 156. Note: `sg-scope-pill` in the topbar (`sg-admin-topbar`) is a different element — it appears in the layout shell, not the page body. |
| **ARIA role(s)** | Decorative scope copy — no additional ARIA. Screen readers read the span text inline. |
| **Motion spec** | Not animated. Static display. |
| **When NOT to use** | Do NOT use `scope_ribbon` for primary navigation. Do NOT replace the topbar `sg-scope-pill` with `scope_ribbon` — they serve different contexts. |

---

### Canonical Component: notice

| Property | Value |
|----------|-------|
| **Job** | Block-level contextual alert with semantic tone (`ok` / `warn` / `risk` / `info`). Used for summary alerts inside identity cards and scoped-attention rows. |
| **Winning markup / CSS** | `<div class="sg-notice" data-tone={tone}><p class="sg-text-sm">…</p></div>`. The `sg-notice` CSS class was added in Phase 154 (COMP-04) as a byte-clone of `.sg-list-row`. Call-site migration to `<.notice>` is Phase 156 (COHR-05). Source: `user_show_live.ex:131`, `organization_live.ex:71`. |
| **ARIA role(s)** | Load-present notices carry **no** live-region role; tone is conveyed visually via `data-tone` and textually via copy. A live-region role is added per-call-site (via `:rest`) only for genuinely post-load dynamic notices (future Phase 157 / LAND-01). Rationale: `role="alert"` is inert on load-present content (WAI-ARIA APG); `role="status"` is for post-load updates (MDN) and risks duplicate announcements on LiveView re-render; Phoenix `flash/1` uses `role="alert"` only because it is dynamically injected with focus-management JS — not Sigra's render model. |
| **Motion spec** | `transition: var(--sg-transition-tone)` on base rule (color/background-color/box-shadow, 140ms). Not animated on initial render. Not animated on keyboard navigation. Not animated on filter-apply (keyboard-frequent interaction per GATE-03). `prefers-reduced-motion` handled automatically by the universal rule at `app.css:1463–1473`. |
| **When NOT to use** | Do NOT use `notice` for inline form field validation — use `sg-error` / Phoenix form error helpers. Do NOT use `notice` for persistent navigation context — use `scope_ribbon`. Do NOT use `notice` where a `sg-list-row[data-tone]` row is part of tabular/list data rather than a standalone alert. |

---

### Canonical Component: skeleton

| Property | Value |
|----------|-------|
| **Job** | Loading placeholder that matches the shape of the content it will replace during async data fetch. Communicates that content is loading, not absent. |
| **Winning markup / CSS** | `<div class="sg-skeleton">` — CSS defined in `app.css`. Overview posture strips render skeletons while disconnected/deferred data is loading. |
| **ARIA role(s)** | No additional ARIA on the skeleton itself. The containing section carries `aria-busy="true"` while content is loading; screen readers announce the replacement content when loaded. |
| **Motion spec** | Shimmer animation via `sg-skeleton-shimmer` `@keyframes` using `translateX` only (composite-safe, GPU-accelerated). `prefers-reduced-motion: reduce` strips the animation via the universal `animation-duration: 0.01ms !important` rule at `app.css:1463–1473`, leaving a static block. |
| **When NOT to use** | Do NOT use `skeleton` for error states — use `notice` with `risk` tone. Do NOT use `skeleton` for empty states — use `empty_state`. Do NOT use `skeleton` for content that is available synchronously. |

---

## Page Archetypes

The three archetypes define how components compose into full pages. All compositions are documented from current verified LiveView implementations — current reality, not target state.

### Overview Archetype

**Source:** `index_live.ex` (Global Overview), `organization_live.ex` (Org Overview)

**Phase 157 component composition (canonical after LAND-01/02/03/04):**

```
<section class="sg-stack sg-stack--6">
  <header class="sg-page-header">                          [1] open header — locked winner per COHR-02
    <p class="sg-page-kicker">
    <h1 class="sg-page-title">
    <p class="sg-page-copy">

  <.notice tone={:risk|:ok} role="status">                [2] LOUD ALARM — first after header
    ...inline alarm content (count + deep-link or "All clear")...
  </.notice>  (:if={not @loading})

  <div class="sg-grid sg-grid--{3|2}">                    [3] PRIMARY content — task_card grid
    task_card x N

  <section class="sg-card sg-posture-strip sg-stack sg-stack--3" aria-busy={...}>  [4] demoted stat_link strip
    <div class="sg-cluster sg-cluster--3">
      stat_link x N  (or skeleton x N when loading)

  <section class="sg-stack sg-stack--3">                  [5] Global only — capability matrix
    capability x N

  ── Org only — demoted scoped-detail tail (below shared archetype) ──
  <section class="sg-card sg-stack sg-stack--3">          [Org] Members roster
  <section class="sg-card sg-stack sg-stack--3">          [Org] Pending invitations
```

**Org variant:** Items 1–4 are byte-coherent across Global and Org Overviews. Org appends a demoted scoped-detail tail (Members roster + Pending invitations) below the shared front-door archetype. This tail is Org-only; it is NOT part of the shared archetype. No `page_back` on Overview screens (leaf-only constraint).

**Notes:**
- The alarm is now `<.notice tone={:risk|:ok}>` as the first child after the header, with `role="status"` opt-in for the post-load dynamic count (Phase 157, LAND-01). The old `sg-status-pill` inside `sg-posture-strip__risk` anchor has been removed from both strips.
- All `<.notice>` slot content is inline — no block `<p>` children (D-07). The `notice/1` component wraps the slot in `<p class="sg-text-sm">`, so any block child would produce invalid `<p><p>…</p></p>`.
- Deferred data load via `connected?(socket)` gate: disconnected mount assigns `loading: true` + empty structs; connected mount runs queries inline and assigns `loading: false`. Containing `<section>` carries `aria-busy="true"` during load.
- **role="status" adjudication (v1.34 close):** The alarm notice uses `role="status"` as an opt-in live-region attribute for the post-load dynamic count. This is intentional — `role="status"` is the correct ARIA live-region for polite post-load count updates on Overview screens (as opposed to `role="alert"` which is reserved for interrupting content). Resolved: no code change needed. Ratified at v1.34 close.
- **Dark WCAG-AA resolution (v1.34 close):** The `--sg-color-brand-strong` token was lightened in the dark `:root` block in Phase 160 (D-06) to `#fdba74`, clearing WCAG-AA on dark brand-soft backgrounds. All dark baselines were re-recorded; axe confirms 0 violations.

---

### List Archetype

**Source:** `users_index_live.ex`

**Current component composition:**

```
<section class="sg-stack sg-stack--6">
  <header class="sg-page-header">           [open header — locked winner per COHR-02]
    <p class="sg-page-kicker">
    <h1 class="sg-page-title">
    <p class="sg-page-copy">
    <dl class="sg-metric-grid">             [summary_chip strip]
      summary_chip x N

  scope_ribbon                              [body scope indicator]

  <form class="sg-filter-panel sg-stack">  [filter panel]
    <div class="sg-search-row">
    <div class="sg-cluster">               [quick_filter chips — checkbox-based]
      quick_filter x N
    <div class="sg-stack sg-stack--3">     [expandable more-filters section]

  <div class="sg-cluster sg-cluster--start"> [applied_chip row — present when filters active]
    applied_chip x N
    <a "Clear all">

  <div class="sg-table-panel sg-show-desktop">  [desktop table]
    <table class="sg-table">

  <div class="sg-stack sg-show-mobile">    [mobile card stack]
    <article class="sg-card sg-stack"> x N

  <div class="sg-empty-state sg-stack">   [zero-rows state]

  <nav class="sg-cluster sg-cluster--between">  [pagination]
```

---

### Detail Archetype

**Source:** `user_show_live.ex`

**Current component composition:**

```
<section class="sg-stack sg-stack--6">
  <div class="sg-cluster sg-cluster--between">  [page_back + scope_ribbon]
    page_back (sg-btn sg-btn--ghost sg-btn--sm)
    scope_ribbon

  <header class="sg-page-header">               [open identity header]
    <p class="sg-page-kicker">
    <h1 class="sg-page-title">
    <dl class="sg-summary-facts">
    notice

  <section class="sg-card sg-stack sg-stack--3"> [Sessions card]
    <div class="sg-table-panel">               [session table]
    empty_state                                [zero sessions]

  <div class="sg-detail-grid">                 [2-column detail grid]
    <section class="sg-detail-panel">          [Security panel]
    <section class="sg-detail-panel">          [Identities panel]

  <section class="sg-card sg-stack sg-stack--3"> [Organizations card]
  <section class="sg-card sg-stack sg-stack--3"> [Recent Audit card]
  <section class="sg-danger-panel sg-stack">   [Danger Zone]
  <dialog class="modal">                       [confirm dialog]
```

**Notes:**
- Detail headers use the open `sg-page-header` pattern. The former boxed identity-card outlier was reconciled in v1.34.
- Summary alerts use the shared `<.notice>` component.

---

**Ratified:** v1.34 ADMIN-UI-COHERENCE (2026-06-05). This contract reflects the final Phases 154–160 implementation reality. All "same job → same component" principles are enforced by the committed Playwright baselines and the ExUnit component byte-golden suite.
