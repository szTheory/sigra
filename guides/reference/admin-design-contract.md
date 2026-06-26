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

| Property                 | Value                                                                                                                                                                                                                                                                                                                 |
| ------------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Job**                  | Numeric KPI with a navigation destination. Used when a count itself is an entry point into a filtered view. Always a real `<a>` element.                                                                                                                                                                              |
| **Winning markup / CSS** | `<a href={@href} class="sg-metric-link"><span class="sg-metric-link__label">{@label}</span><span class="sg-metric-link__value">{@value}</span></a>` — CSS classes: `sg-metric-link`, `sg-metric-link__label`, `sg-metric-link__value`. Kept for future count-as-link use; not part of the current Overview archetype. |
| **ARIA role(s)**         | Native `<a>` — inherits link semantics. No additional ARIA needed. Screen readers announce the link text (label + value).                                                                                                                                                                                             |
| **Motion spec**          | Hover: `box-shadow` lift transition at 140ms `var(--sg-ease)`. Not animated on keyboard focus (focus-visible uses `box-shadow` ring only). Not animated on page load.                                                                                                                                                 |
| **When NOT to use**      | Do NOT use `stat_link` for a numeric KPI that has no navigation destination — use `stat` (read-only, Phase 155 COMP-01). Do NOT use for non-numeric content.                                                                                                                                                          |

---

### Canonical Component: stat

| Property                 | Value                                                                                                                                                                                                         |
| ------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Job**                  | Numeric KPI without navigation. Read-only posture metric. No `<a>` element. Used when a count communicates state but does not link anywhere.                                                                  |
| **Winning markup / CSS** | Markup-consolidation target — no dedicated implementation yet. Closest analog is `sg-metric-link` markup without the `<a>` wrapper. Implemented in Phase 155 (COMP-01). Do NOT invent a `.sg-stat` CSS class. |
| **ARIA role(s)**         | Static text — no interactive role. Semantics depend on container context (e.g. `<dl>` with `<dt>`/`<dd>` for labelled counts).                                                                                |
| **Motion spec**          | Not animated. Static read-only display element.                                                                                                                                                               |
| **When NOT to use**      | Do NOT use `stat` when the KPI navigates to a filtered view — use `stat_link`. Do NOT invent `.sg-stat` CSS class (only the component abstraction is canonical).                                              |

---

### Canonical Component: task_card

| Property                 | Value                                                                                                                                                                                                                                                                                                                                                          |
| ------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Job**                  | Verb-first action prompt for a primary admin task. Forms the main action grid in the Overview archetype. Its CTA links to the action view.                                                                                                                                                                                                                     |
| **Winning markup / CSS** | `<article class="sg-card sg-card-hover sg-stack sg-stack--3"><div class="sg-stack sg-stack--2"><h2 class="sg-section-heading">{@title}</h2><p class="sg-section-copy">{@body}</p></div><div class="sg-cluster"><a href={@href} class="sg-btn sg-btn--primary">{@action}</a></div></article>`. Source: `index_live.ex:132–144`, `organization_live.ex:183–195`. |
| **ARIA role(s)**         | `<article>` (implicit sectioning element) + `<h2>` heading. The `<a>` is the interactive element with descriptive text. No additional ARIA needed.                                                                                                                                                                                                             |
| **Motion spec**          | Hover lift: `translateY(-1px)` + `box-shadow` transition at 140ms, pointer-device only via `@media (hover: hover) and (pointer: fine)`. Not animated on keyboard focus (focus-visible ring only — `box-shadow`). Not animated on page load.                                                                                                                    |
| **When NOT to use**      | Do NOT use `task_card` for informational-only content with no CTA (non-actionable cards). Do NOT use for list items or detail cards — those use `sg-card` directly without `sg-card-hover`.                                                                                                                                                                    |

---

### Canonical Component: summary_chip

| Property                 | Value                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     |
| ------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Job**                  | Aggregate count or boolean-state posture badge in a list-screen header or compact dashboard snapshot. Non-interactive — communicates state, not action.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   |
| **Winning markup / CSS** | `<dl class="sg-metric-grid"><div class="sg-metric" data-sg-metric-enhanced><dt class="sg-metric__label">…</dt><dd class="sg-metric__value"><span class="sg-metric__number">…<span class="sg-metric__unit">%</span></span></dd><dd class="sg-metric__caption">…</dd><dd class="sg-metric__subvalue">…</dd></div></dl>`. Enhanced metrics use a consistent three-line text stack: number, one-line label, optional one-line detail. Enhanced cards may add `sg-metric__icon`, SVG or text icon content (`sg-metric__icon-svg` / `sg-metric__icon-text`), `sg-metric__unit`, and `sg-metric__help`; `sg-metric__subvalue` is optional, but the enhanced CSS still reserves the same three-row internal rhythm so value/caption/detail baselines align across neighboring cards. The basic `<dt>/<dd>` form remains valid for simple metrics. |
| **ARIA role(s)**         | `<dl>` with `<dt>`/`<dd>` pairs — definition list semantics. Optional help is card-level: the metric root carries `tabindex="0"`, `aria-describedby`, and `data-sg-metric-help-root`; the help panel is `role="tooltip"` and remains supplemental, not required to understand the metric. No visible `?` trigger is rendered.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             |
| **Motion spec**          | Read-only metric containers do not navigate. Optional help opens on hover/focus/touch by toggling visibility only; focus uses the standard ring and pointer hover may use a subtle shadow change. Tone does not add left side bands; risk/warn semantics are conveyed by copy plus icon tone. No counter animation.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       |
| **When NOT to use**      | Do NOT use `summary_chip` for interactive filter state — use `applied_chip`. Do NOT use for a metric that links somewhere — use `stat_link`. Do NOT add a visible question-mark help icon; supplemental help is discoverable from the metric card itself via hover/focus/touch.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           |

---

### Canonical Component: applied_chip

| Property                 | Value                                                                                                                                                                                                                                                                                                                                                                                       |
| ------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Job**                  | Active filter indicator with a clear affordance. Shows which filters are currently active above the results table. Clicking the remove link deactivates the filter.                                                                                                                                                                                                                         |
| **Winning markup / CSS** | `<span class="sg-applied-chip"><span>{chip.label}</span><a class="sg-applied-chip__remove" href={remove_chip_path(...)} aria-label={"Remove filter " <> chip.label}><span aria-hidden="true">&times;</span><span class="sr-only">remove</span></a></span>`. CSS classes: `sg-applied-chip`, `sg-applied-chip__remove`. Source: `users_index_live.ex:167–180`, `audit_user_live.ex` applied-chip cluster (post-form, contiguous with filter panel — see Audit Explorer Archetype for elevated composition). |
| **ARIA role(s)**         | Remove link has explicit `aria-label={"Remove filter " <> chip.label}`. The `&times;` glyph is `aria-hidden="true"`. `<span class="sr-only">remove</span>` provides screen-reader text fallback.                                                                                                                                                                                            |
| **Motion spec**          | `sg-applied-chip__remove` has `transition: var(--sg-transition-tone)` for hover color change (140ms). Not animated on filter-apply (keyboard-frequent interaction — per GATE-03). Not animated on page load or keyboard navigation.                                                                                                                                                         |
| **When NOT to use**      | Do NOT use `applied_chip` for non-removable state badges — use `summary_chip`. Do NOT use for navigation links.                                                                                                                                                                                                                                                                             |

---

### Canonical Component: empty_state

| Property                 | Value                                                                                                                                                                                                                                                                                    |
| ------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Job**                  | Dashed-border centred placeholder when a list or section has zero rows. Communicates the absence of content and optionally prompts a next step.                                                                                                                                          |
| **Winning markup / CSS** | `<div class="sg-empty-state sg-stack sg-stack--3"><p class="sg-empty-state__title">...</p><p class="sg-muted sg-text-sm">...</p></div>`. CSS: `sg-empty-state` (dashed border, centred, `sg-color-line-strong`). Source: `users_index_live.ex:285`, `user_show_live.ex:188,222,252,282`. |
| **ARIA role(s)**         | No additional ARIA. The `<p class="sg-empty-state__title">` provides a semantic heading for the empty region. Screen readers announce the content inline.                                                                                                                                |
| **Motion spec**          | Not animated. Static display.                                                                                                                                                                                                                                                            |
| **When NOT to use**      | Do NOT use `empty_state` for loading states — use `skeleton`. Do NOT use in non-list contexts (e.g., inside a form or notice). Do NOT use when there is an error — use `notice` with the appropriate tone.                                                                               |

---

### Canonical Component: page_back

| Property                 | Value                                                                                                                                                                                                                                                |
| ------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Job**                  | Single-step navigation back to a prior screen when the current leaf cannot express its path as a breadcrumb. Not used on user detail or per-user audit, where breadcrumbs carry `Overview / Users / User / Audit` hierarchy and list return context. |
| **Winning markup / CSS** | `<a class="sg-btn sg-btn--ghost sg-btn--sm" href={@return_to}><span aria-hidden="true">&larr;</span> Back to users</a>`. CSS classes: `sg-btn sg-btn--ghost sg-btn--sm`. No dedicated `page_back` CSS class.                                         |
| **ARIA role(s)**         | Native `<a>` — inherits link semantics. Arrow (`&larr;`) is `aria-hidden="true"`. Link text is descriptive ("Back to users", "Back to user").                                                                                                        |
| **Motion spec**          | Standard button hover/active transitions. Not animated on keyboard navigation. Not animated on page load.                                                                                                                                            |
| **When NOT to use**      | Do NOT use `page_back` for multi-level hierarchy — use breadcrumbs for user detail and per-user audit. Do NOT use on non-leaf screens (Overview, List).                                                                                              |

---

### Canonical Component: scope_ribbon

| Property                 | Value                                                                                                                                                                                                                                                                                                                                            |
| ------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| **Job**                  | Persistent in-body scope indicator showing whether the admin is viewing Global context or a specific organisation. Present on every list and leaf screen.                                                                                                                                                                                        |
| **Winning markup / CSS** | Currently rendered as `<span class="sg-scope-ribbon sg-muted sg-text-sm">{scope_copy(@admin_scope)}</span>`. On user leaf screens it appears as body context below the breadcrumb, not beside a back button. Note: `sg-scope-pill` in the topbar (`sg-admin-topbar`) is a different element — it appears in the layout shell, not the page body. |
| **ARIA role(s)**         | Decorative scope copy — no additional ARIA. Screen readers read the span text inline.                                                                                                                                                                                                                                                            |
| **Motion spec**          | Not animated. Static display.                                                                                                                                                                                                                                                                                                                    |
| **When NOT to use**      | Do NOT use `scope_ribbon` for primary navigation. Do NOT replace the topbar `sg-scope-pill` with `scope_ribbon` — they serve different contexts.                                                                                                                                                                                                 |

---

### Canonical Component: field_help

| Property                 | Value                                                                                                                                                                                                                                                                                                                                                                                              |
| ------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Job**                  | Label-adjacent explanatory help for admin form fields whose effect is not obvious from the label alone. Answers the operator's likely "what does this affect?" question without adding permanent explanatory copy below every input.                                                                                                                                                               |
| **Winning markup / CSS** | `<span class="sg-field-label-row"><label class="sg-field-label" for="...">...</label><span class="sg-field-help" data-sg-field-help-root><button type="button" class="sg-field-help__trigger" aria-label="Help: ..." aria-controls="..." aria-expanded="false" data-sg-field-help-trigger>...</button><span id="..." class="sg-field-help__panel" role="tooltip" hidden>...</span></span></span>`. |
| **ARIA role(s)**         | The trigger is a native button with an explicit accessible name, `aria-controls`, `aria-describedby`, and `aria-expanded`. The panel is non-interactive text with `role="tooltip"` and is toggled by delegated JS on hover, focus, click/tap, Escape, and outside click. Do not place the button inside a wrapping `<label>`; use explicit `for`/`id` labels.                                      |
| **Motion spec**          | Trigger color and press scale only: exact-property transitions, `scale(0.96)` on active, standard focus ring on keyboard focus. Panel visibility toggles without layout shift. No looping animation, no page-load animation, and no `transition: all`.                                                                                                                                             |
| **When NOT to use**      | Do NOT use for obvious fields where the label is enough. Do NOT put links, buttons, or other controls inside the tooltip. Do NOT use native `title` attributes for admin form help.                                                                                                                                                                                                                |

---

### Canonical Component: admin_loading_bar

| Property                 | Value                                                                                                                                                                                                                                                                                                         |
| ------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Job**                  | Lightweight route-level feedback for admin LiveView navigation (`initial`, `patch`, `redirect`) when a view change takes long enough to be perceptible.                                                                                                                                                       |
| **Winning markup / CSS** | `<span class="sg-admin-loading-bar" data-sg-admin-loading-bar aria-hidden="true"></span>` rendered inside `.sg-admin-topbar`. JS toggles `html[data-sg-admin-page-loading="true"]`; CSS draws a 2px rail on the top edge of the sticky topbar with no layout shift.                                           |
| **ARIA role(s)**         | The rail is decorative and `aria-hidden="true"`. While route loading is active, JS sets `aria-busy="true"` on `.sg-admin-shell`; no live-region copy is announced because navigation already changes page title, breadcrumb, and heading.                                                                     |
| **Motion spec**          | Visual show is delayed 180ms to avoid flicker, then remains visible for at least 220ms. The rail fills once from `0→100%`, never loops, and uses opacity/transform only. `error`, page-cache restore, and max-active failsafe paths reset the rail. `prefers-reduced-motion: reduce` keeps a static 2px rail. |
| **When NOT to use**      | Do NOT use for local form submits, table filters, field validation, preview updates, or element-level LiveView loading events. Use button pending state, skeletons, or field-level feedback for those narrower interactions.                                                                                  |

---

### Canonical Component: notice

| Property                 | Value                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          |
| ------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| **Job**                  | Block-level contextual alert with semantic tone (`ok` / `warn` / `risk` / `info`). Used for summary alerts inside identity cards and scoped-attention rows.                                                                                                                                                                                                                                                                                                                                                                                                                    |
| **Winning markup / CSS** | `<div class="sg-notice" data-tone={tone}><p class="sg-text-sm">…</p></div>`. Inline next-step links inside notices use `<.notice_link>` / `.sg-notice__action`: a native underlined link, not a button row. The `sg-notice` CSS class was added in Phase 154 (COMP-04) as a byte-clone of `.sg-list-row`. Call-site migration to `<.notice>` is Phase 156 (COHR-05). Source: `user_show_live.ex:131`, `organization_live.ex:71`.                                                                                                                                               |
| **ARIA role(s)**         | Load-present notices carry **no** live-region role; tone is conveyed visually via `data-tone` and textually via copy. A live-region role is added per-call-site (via `:rest`) only for genuinely post-load dynamic notices (future Phase 157 / LAND-01). Rationale: `role="alert"` is inert on load-present content (WAI-ARIA APG); `role="status"` is for post-load updates (MDN) and risks duplicate announcements on LiveView re-render; Phoenix `flash/1` uses `role="alert"` only because it is dynamically injected with focus-management JS — not Sigra's render model. |
| **Motion spec**          | `transition: var(--sg-transition-tone)` on the notice base rule (color/background-color/box-shadow, 140ms). Inline notice actions transition text color, underline color, and focus ring only; pointer hover shifts the link color and underline color without applying a fill/background. Keyboard focus uses the focus ring, not hover animation. Not animated on initial render. Not animated on filter-apply (keyboard-frequent interaction per GATE-03). `prefers-reduced-motion` handled automatically by the universal rule at `app.css:1463–1473`.                     |
| **When NOT to use**      | Do NOT use `notice` for inline form field validation — use `sg-error` / Phoenix form error helpers. Do NOT use `notice` for persistent navigation context — use `scope_ribbon`. Do NOT use `notice` where a `sg-list-row[data-tone]` row is part of tabular/list data rather than a standalone alert.                                                                                                                                                                                                                                                                          |

---

### Canonical Component: skeleton

| Property                 | Value                                                                                                                                                                                                                                                                                    |
| ------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Job**                  | Loading placeholder that matches the shape of the content it will replace during async data fetch. Communicates that content is loading, not absent.                                                                                                                                     |
| **Winning markup / CSS** | `<div class="sg-skeleton">` — CSS defined in `app.css`. Deferred org overview roster sections render skeleton rows while disconnected/deferred data is loading.                                                                                                                          |
| **ARIA role(s)**         | No additional ARIA on the skeleton itself. The containing section carries `aria-busy="true"` while content is loading; screen readers announce the replacement content when loaded.                                                                                                      |
| **Motion spec**          | Shimmer animation via `sg-skeleton-shimmer` `@keyframes` using `translateX` only (composite-safe, GPU-accelerated). `prefers-reduced-motion: reduce` strips the animation via the universal `animation-duration: 0.01ms !important` rule at `app.css:1463–1473`, leaving a static block. |
| **When NOT to use**      | Do NOT use `skeleton` for error states — use `notice` with `risk` tone. Do NOT use `skeleton` for empty states — use `empty_state`. Do NOT use `skeleton` for content that is available synchronously.                                                                                   |

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

  ── Org only — demoted scoped-detail tail (below shared archetype) ──
  <section class="sg-card sg-stack sg-stack--3">          [Org] Members roster
  <section class="sg-card sg-stack sg-stack--3">          [Org] Pending invitations
```

**Org variant:** Items 1–3 are byte-coherent across Global and Org Overviews. Org appends a demoted scoped-detail tail (Members roster + Pending invitations) below the shared front-door archetype. This tail is Org-only; it is NOT part of the shared archetype. No `page_back` on Overview screens (leaf-only constraint).

**Notes:**

- Admin shell breadcrumbs are present on every admin page. Overview pages render a single current-page crumb (`Overview`); workspace pages render `Overview / Current page`; user leaf pages render structured paths such as `Overview / Users / email` and `Overview / Users / email / Audit`. Scope remains visible in the topbar and page body, not duplicated in breadcrumb labels.
- The alarm is now `<.notice tone={:risk|:ok}>` as the first child after the header, with `role="status"` opt-in for the org post-load dynamic count (Phase 157, LAND-01).
- All `<.notice>` slot content is inline — no block children. The `notice/1` component wraps the slot in the notice text wrapper, so callers should keep copy sentence-shaped. Use `<.notice_link>` for inline notice actions such as "Review accounts"; reserve buttons or split action rows for heavier future alert layouts.
- Deferred data load via `connected?(socket)` gate: disconnected mount assigns `loading: true` + empty structs; connected mount runs queries inline and assigns `loading: false`. Containing `<section>` carries `aria-busy="true"` during load.
- No `page_back` on Overview screens (leaf-only constraint).
- **role="status" adjudication (v1.34 close):** The alarm notice uses `role="status"` as an opt-in live-region attribute for the post-load dynamic count. This is intentional — `role="status"` is the correct ARIA live-region for polite post-load count updates on Overview screens (as opposed to `role="alert"` which is reserved for interrupting content). Resolved: no code change needed. Ratified at v1.34 close.
- **Dark WCAG-AA resolution (v1.34 close):** The `--sg-color-brand-strong` token was lightened in the dark `:root` block in Phase 160 (D-06) to `#fdba74`, clearing WCAG-AA on dark brand-soft backgrounds. All dark baselines were re-recorded; axe confirms 0 violations.

---

### List Archetype

**Source:** `users_index_live.ex`

**Search-first composition (Phase 201 — v1.41 ADMIN-UX-ELEVATION):**

```
<section class="sg-stack sg-stack--6">
  <header class="sg-page-header">               [1] identity / orientation bar
    <p class="sg-page-kicker">User operations</p>
    <h1 class="sg-page-title">                  [Users or org-scoped heading]

  <.scope_ribbon>                               [2] scope indicator

  <section class="sg-stack sg-stack--4"         [3] FIND USERS — dominant first affordance
    aria-labelledby="find-users-heading">
    <h2 class="sg-section-heading">Find users</h2>
    <form method="get" class="sg-filter-panel sg-stack">
      <div class="sg-search-row">               Search input + Submit + Clear
      <div class="sg-cluster sg-cluster--start"> [applied_chip row — contiguous with panel]
        <.applied_chip> x N + "Clear all" link  [present only when filters active]
      <div class="sg-cluster">                  Quick filter checkboxes (quick_filter x N)
      <div class="sg-stack sg-stack--3">        "More filters" disclosure + advanced grid

  <section class="sg-stack sg-stack--3">        [4] USER HEALTH — demoted slim metric strip
    <h2 class="sg-section-heading">User health</h2>
    <dl class="sg-metric-grid">
      <.summary_chip> Total users (neutral)     [3 chips only: Total + Locked + Deletion]
      <.summary_chip> Locked (risk when > 0)
      <.summary_chip> Deletion scheduled (warn when > 0)

  <div data-testid="admin-users-desktop-results" [5] desktop table
       class="sg-table-panel sg-show-desktop">
    <table class="sg-table">
      <thead><tr>
        <th>User</th>                           [column order FROZEN per D-06]
        <th>Status</th>
        <th>Organizations</th>
        <th>Activity</th>
        <th class="sg-cell-right">Action</th>
      </thead>
      <tbody><tr :for={row <- @rows}>
        <td> <.user_name_stack> — name/email/id identity stack
        <td> <.user_status_cluster> — reduced status pills + extra_badges seam
        <td>                      — org summary
        <td>                      — activity/registered + extra_columns seam
        <td>                      — "Open user" action link

  <div data-testid="admin-users-mobile-results"  [6] mobile card stack
       class="sg-stack sg-stack--3 sg-show-mobile">
    <article :for={row <- @rows} class="sg-card sg-stack sg-stack--3">
      <.user_name_stack>                        — same field slice as desktop td 1
      <.user_status_cluster>                    — same field slice as desktop td 2
      <dl class="sg-kv">                        — org / activity / registered / extra_columns

  <.empty_state>                                [7] zero-row state

  <nav>                                         [8] pagination (only when multi_page?)
```

**Notes:**

- **Search-first (Phase 201):** The Find Users filter panel is the dominant first affordance below the page header. The metric strip (User health) is demoted below the panel as a secondary summary — operators scan for exceptions, not aggregates, as the primary action.
- **Applied chips contiguous with filter panel (D-01):** The applied-chip row sits directly inside `<form>` below the search row — it is NOT a detached sibling `<div>` after `</form>`. Chips are navigation-only `<a>` tags (no named inputs) so the GET form submission is unaffected (D-02).
- **Slim metric strip (D-03):** The User health section emits exactly 3 summary chips: Total (neutral), Locked (risk), Deletion scheduled (warn). Coverage KPIs (Confirmed, MFA, Passkeys) are omitted from the list view — they would add noise without decision value in a scan context.
- **Reduced pill vocabulary (D-04):** `status_pills/1` emits only decision-bearing signals: Unconfirmed (warn), No MFA (warn), Locked (risk), Deletion scheduled (warn). The always-present "Confirmed" branch is dropped — absence of Unconfirmed implies confirmed.
- **`<.user_row_fields>` DRY note (D-05):** Two private field-slice function components — `user_name_stack/1` (name/email/id identity stack) and `user_status_cluster/1` (status pills + extra_badges) — are each authored once and called from both the desktop `<td>` and the mobile `<article>`. The desktop `<td>` boundaries and mobile card shell are layout-specific; all inner field content is shared.
- **Five-column order FROZEN (D-06):** Desktop table columns are: User / Status / Organizations / Activity / Action. This order is frozen and must not change without updating the `td:nth-child(3)/(4)` positional selectors in `admin-design.spec.ts:assertUserResultEquivalence` in the same change.
- **Host seams preserved (D-07):** `extra_badges` is rendered inside `user_status_cluster/1` (called from both layouts). `extra_columns` is rendered in the layout-specific shells (desktop activity `<td>` and mobile `dl`). Both seams are preserved in both layouts.
- **Page header emits only kicker + title:** The `<header class="sg-page-header">` emits a kicker `<p>` and title `<h1>`. No `<p class="sg-page-copy">` or `<dl class="sg-metric-grid">` lives inside the page header — those were in the pre-Phase-201 structure and are now stale. The metric grid is a separate demoted `<section>` at position [4].

---

### Detail Archetype

**Source:** `user_show_live.ex`

**JTBD-first component composition (Phase 200 — v1.41 ADMIN-UX-ELEVATION):**

```
<section class="sg-stack sg-stack--6">
  scope_ribbon

  <header class="sg-page-header">               [1] calm identity bar — JTBD scan target
    <p class="sg-page-kicker">User</p>
    <h1 class="sg-page-title">                  [display_name || email]
    <p class="sg-page-copy">                    [secondary: muted email + sg-code UUID]
    <dl class="sg-summary-facts">               [compact metrics: Sessions + MFA + Last seen]
    notice                                      [single priority alert: locked>unconfirmed>no-MFA]
    [status pills cluster]                      [status_pills/1 at bottom of header]

  <section class="sg-card sg-stack sg-stack--3"> [2] Sessions bounded preview (display-only)
    <div class="sg-cluster sg-cluster--between"> [header cluster: heading + count + Manage sessions link]
    <div class="sg-table-panel">               [max 3 rows, no revoke buttons]
    empty_state                                [zero sessions]

  <div class="sg-detail-grid">                 [3] 2-column detail grid
    <section class="sg-detail-panel">          [Security panel]
    <section class="sg-detail-panel">          [Identities panel]

  <section class="sg-card sg-stack sg-stack--3"> [4] Organizations bounded preview (max 3 rows)
  <section class="sg-card sg-stack sg-stack--3"> [5] Recent Audit card + "View full audit" link-out

  [extra_detail_sections/1 host seam]           [6] Host-injected sections — rendered here, BEFORE Danger Zone

  <section class="sg-danger-panel sg-stack">   [7] Danger Zone — impersonation start form
```

**Notes:**

- Detail headers use the open `sg-page-header` pattern. The former boxed identity-card outlier was reconciled in v1.34.
- **JTBD-first order (Phase 200):** the Sessions card is positioned first after the identity bar — it is the primary admin JTBD for this page (understand session state → manage sessions). Security/Identities grid and Organizations follow as secondary context.
- **Bounded previews (Phase 200):** Sessions and Organizations show max 3 rows, display-only. Session revoke controls were moved to `UserSessionsLive` (the dedicated `/admin/users/:id/sessions` surface). The "Manage sessions" link-out and "View all organizations" link-out connect the preview to the full surface.
- **APG confirm dialog location:** the `sg-confirm-overlay` / `sg-confirm-dialog` confirm dialog now lives on `UserSessionsLive`, not on the detail page. Do not re-add a confirm overlay to `user_show_live.ex`; the detail page is intentionally calm (no destructive actions).
- **`extra_detail_sections/1` host seam (preserved — semver contract):** host apps inject custom sections via the `extra_detail_sections/1` callback. These sections render at position [6] — AFTER all lib-owned sections (identity bar, previews, grid, audit) and BEFORE the Danger Zone. The render uses dual atom/string `:title`/`:body` key reads (`Map.get(section, :title) || Map.get(section, "title")`) to maintain backward compatibility with both map formats. This seam position and key contract are frozen from this point forward.
- Summary alerts use the shared `<.notice>` component.
- Admin confirmation dialogs use the Sigra-owned `sg-confirm-overlay` / `sg-confirm-dialog` pattern. Do not use generic `.modal[open]` in the admin shell; the bundled default modal rules globally lock root scroll and can leak unstyled modal chrome into admin surfaces.

---

### Audit Explorer Archetype

**Source:** `audit_index_live.ex` (global audit, `/admin/audit`) + `audit_user_live.ex` (per-user audit, `/admin/users/:id/audit`)

**Elevated composition (Phase 202 — v1.41 ADMIN-UX-ELEVATION):**

```
<section class="sg-stack sg-stack--6">
  [per-user only] breadcrumbs + scope_ribbon + identity header

  [index only] <header class="sg-page-header">      [1] orientation bar
    <p class="sg-page-kicker">
    <h1 class="sg-page-title">

  <section class="sg-stack sg-stack--4"             [2] FIND EVENTS — single filter panel
    aria-labelledby="...">
    <form method="get" class="sg-filter-panel sg-stack">
      <div class="sg-cluster">                      Quick toggles (Failures / Impersonation)
        checkboxes — GET, always visible, folded into the panel (D-01)

      <details>                                     <details> advanced-disclosure — CSS-only (D-02)
        <summary>More filters</summary>
        <div class="sg-form-grid">                  Text / date / actor fields

      <div class="sg-cluster">                      Action row
        <button type="submit">Apply filters</button>
        <a ...>Clear</a>
        <a ...>Export CSV</a>                       Export surfaced in the action row (D-04)

      [per-user only] <input type="hidden" name="return_to">
      <input type="hidden" name="page_size" value="25">
      <input type="hidden" name="order_by">
      <input type="hidden" name="order_direction">

  <div :if={any_filter_active?} class="sg-cluster sg-cluster--start">  [3] applied chips
    <.applied_chip> x N + "Clear all" link         Navigation-only <a> tags, post-form

  <div data-testid="admin-audit-desktop-results"    [4] desktop table (sg-show-desktop)
       class="sg-table-panel sg-show-desktop">
    <table class="sg-table">
      <thead>                                       [column order FROZEN per D-06]
        <th>Occurred</th>
        <th>Event</th>                              action_label + action_badge (human-readable)
        <th>Actor</th>
        <th>Outcome</th>
      <tbody><tr :for={row <- @rows}>               shared <.audit_table_row row={row} />
        <td> timestamp
        <td> action_label + action_badge
             <details>                              in-row code disclosure (D-05)
               <summary>…</summary>
               <code class="sg-code">row.id</code>       both code.sg-code nodes stay in
               <code class="sg-code">row.action</code>   desktop results container (D-06)
        <td> actor identity
        <td> outcome badge + <.audit_empty_state>

  <div class="sg-stack sg-stack--3 sg-show-mobile"> [5] mobile card stack
    <.audit_row show_detail show_codes>             EXISTING shared component (D-07)

  <.audit_empty_state>                              [6] zero-row state — shared component (D-08)

  <.audit_pagination_nav meta={@meta} ...>          [7] pagination (only when multi_page?/1 true)
```

**Notes:**

- **Single filter panel (D-01):** Both pages are ONE `<form method="get" class="sg-filter-panel sg-stack">`. The per-user page previously had three separate forms (two standalone quick-toggle forms + main filter form). Wave 2 (Phase 202) collapsed them into a single panel, making the per-user page coherent with the index.
- **Native `<details>` advanced-disclosure (D-02):** Text and date filter fields live inside a CSS-only `<details><summary>More filters</summary>…</details>`. No `phx-hook`, no LiveView round-trip — browser owns the open/close state. Quick toggles (Failures / Impersonation) stay outside the disclosure as always-visible summary controls.
- **GET-form contract preserved (D-03):** `handle_params/3` is the only state path. Every toggle, chip remove, and page/sort link is a URL built via `append_query/2`. The `?action_prefix=admin.impersonation` checkpoint entry path, applied-chip `:checked` state, and per-user `return_to` round-trip are all preserved. No `phx-click` on filters.
- **Export in action row (D-04):** The Export CSV link is in the consolidated filter action row on both pages, not buried near pagination.
- **Inline code disclosure, codes stay DOM-accessible (D-05/D-06):** Raw event `id` and `action` codes moved out of the primary desktop column flow into an in-row native `<details>` inside the Event cell. Both `<code class="sg-code">` nodes remain inside the `[data-testid="admin-audit-desktop-results"]` container — `assertAuditResultEquivalence` still extracts exactly 2 codes. The CSV `event_id` column is independent of LiveView render (`csv_export.ex` reads the presenter map directly).
- **Four-column order FROZEN (D-06):** Desktop table columns are: Occurred / Event / Actor / Outcome. This order is frozen and must not change without updating the `td:nth-child(3)` positional selector in `admin-design.spec.ts:assertAuditResultEquivalence` in the same change.
- **Byte-coherent shared components (D-08):** Desktop table row (`<.audit_table_row>`), pagination nav (`<.audit_pagination_nav>`), and empty state (`<.audit_empty_state>`) are public function components in `lib/sigra/admin/components.ex`, emitting byte-identical markup from both LiveViews. Private helper duplication (`audit_tone/1`, `multi_page?/1`, `format_timestamp/1`) eliminated — both now call the shared helpers.
- **Legitimate per-page divergence (D-09):** Index `@chip_keys` is 6-key (incl. `actor`/`effective_user`); per-user is 5-key (excl. `effective_user`). Per-user has breadcrumbs, `display_name` identity header, `return_to` plumbing, and `clear_path`/`export_params` with `user_id`. Index has scope ribbon and Effective-user filter field. These differences stay per-page.
- **Honest cursor pagination (D-10):** `multi_page?/1` gates the `<nav>` on non-nil `next_page` or `prev_page` cursor (no `total_pages` math). Default `page_size=25`. Proven by deterministic ExUnit test: ≥26 events → `<nav aria-label="Next page">` present; ≤25 → absent.
- **Microcopy glossary-clean:** New copy is auto-guarded by `glossary_test.exs:28` (audit_index_live) and `:29` (audit_user_live).
- **No modal dialogs:** Neither page owns a modal overlay. Overlay-axe and APG focus-trap/restore proxies are N/A for both surfaces.

---

**Ratified:** v1.34 ADMIN-UI-COHERENCE (2026-06-05). This contract reflects the final Phases 154–160 implementation reality. All "same job → same component" principles are enforced by the committed Playwright baselines and the ExUnit component byte-golden suite.
