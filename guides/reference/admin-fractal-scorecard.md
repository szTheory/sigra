# Admin Fractal Scorecard Rubric

This file is the fixed grading anchor for phases 186-192. Re-runs use this rubric to fill
the quality ledger identically — ensuring that successive audits evaluate the same axes and
that tier assignments remain comparable over time.

---

## Tier Vocabulary

| Tier | Name | Definition |
|------|------|-----------|
| 0 | Drift | Fails one or more scorecard axes; visible regressions vs the v1.34 admin design contract |
| 1 | Ratified | Meets the v1.34 contract bar; passes all required axes; no obvious gaps or missing states |
| 2 | Award-grade | emilkowal.ski-level micro-interaction quality; coherent on-brand copy; pixel-considered spacing; delightful in detail |

---

## Shared Dimensions (D1-D11)

These 11 dimensions apply to every surface at every level (L1 component through L4 flow).
Audit phases 186-192 fill in the **score** and **evidence** columns for each surface evaluated.

| dimension | description | pass criteria | score | evidence |
|-----------|-------------|---------------|-------|----------|
| D1 Brand color | Admin surfaces use the Rail Accent palette (`--sg-color-ember-*`, `--sg-color-neutral-*`) as defined in `brandbook/tokens.css` and propagated through `sigra_admin.css` | No raw hex values outside `sg-*` token vars; ember rail-block mark renders at correct hue in both light and dark | | |
| D2 Brand type | Typography uses Space Grotesk via `--sg-font-sans`; weight scale (400/500/700) applied consistently per admin-design-contract.md | No system font fallback visible in screenshots; correct weight on headings and kickers | | |
| D3 Spacing/radius/shadow | All spatial decisions use `sg-stack--N`, `sg-cluster`, `sg-grid`, `--sg-radius-*`, `--sg-shadow-*` tokens — no raw pixel values in inline styles or bespoke classes | Zero bespoke `style=` attributes with spacing values; board layouts reflow without gap collapse | | |
| D4 Light/Dark/System | Surface renders correctly under all three `data-sg-admin-theme` values: `light`, `dark`, and system (inherits `prefers-color-scheme`) | Playwright `admin-design-dark` project screenshots pass; no color that reads incorrectly in dark mode | | |
| D5 Contrast WCAG AA | All text/background pairs meet WCAG 2.1 AA contrast ratio (4.5:1 normal text, 3:1 large text and UI components) | axe-core `wcag2aa` scan exits 0 violations on the surface | | |
| D6 Motion quality | Transitions and animations respect `prefers-reduced-motion: reduce`; no gratuitous motion; durations ≤ 200ms for micro-interactions | `@media (prefers-reduced-motion: reduce)` strips all transitions; no janky repaints on interaction | | |
| D7 Interaction states | Interactive elements (buttons, links, chips, cards) have visible focus, hover, and active state styling via `sg-*` classes | Focus ring visible at 3:1 contrast; no state shows raw browser default outline only | | |
| D8 Mobile-first responsive | Layout reflows gracefully at 320px (minimum) through 1440px+ without horizontal overflow or collapsed content | iPhone 13 (390×844) Playwright project screenshots pass; no `overflow: hidden` hiding content | | |
| D9 IA/least-surprise | Navigation and labeling follow least-surprise conventions; general → specific hierarchy; actions use verb-first copy | Users can locate primary actions without scanning the full page; no mystery-meat labels | | |
| D10 Microcopy | All visible text uses on-brand, terse, operator-calibrated copy per the v1.37 microcopy contract | No placeholder text ("Lorem ipsum", "TODO"); copy matches admin-design-contract.md per-component copy spec | | |
| D11 A11y semantics | Landmark regions, heading order, ARIA roles, labels, and live regions are correct per WCAG 2.1 AA | axe-core `wcag2a` + `wcag2aa` scan exits 0 violations; correct `<h1>/<h2>/<h3>` nesting | | |

Cross-reference: See `admin-design-contract.md` for per-component ARIA and motion specs (D11, D6).

---

## Per-Level Add-ons

These add-ons extend the shared D1-D11 dimensions with level-specific criteria. An evaluator
scores a surface at the tightest level that applies to its structure.

### L1 Individual Component Add-ons

Applied to each of the 13 `Sigra.Admin.Components` function components.

- **Complete/visually-distinct interaction states** — every interactive state (default, hover,
  focus, active, disabled) renders a visually distinguishable treatment; not just color, also
  shape/size/shadow where relevant.
- **Reduced-motion strips movement** — component-level transitions are wrapped in
  `@media (prefers-reduced-motion: reduce)` and set `transition: none` or equivalent.
- **Per-component axe clean** — axe-core scan on the component's board in the gallery exits
  0 violations for `wcag2a` and `wcag2aa` tag sets.
- **Reflows at 320-1440 without overflow** — no text clipping, no horizontal scroll,
  no collapsed grid cells at iPhone 13 minimum viewport.

### L2 Meta-Component Group Add-ons

Applied to each of the 11 meta-component group boards (MG-1 through MG-11).

- **Intra-group rhythm consistent** — spacing between components within the group uses a
  single `sg-stack--N` tier; no mixed stacking contexts within one group.
- **No card-in-card nesting** — `sg-card` elements are not nested inside other `sg-card`
  elements within the same group; use flat list rows or direct children.
- **Right-component-for-job** — each component within the group is the canonical choice
  per `admin-design-contract.md` (e.g. stats use `summary_chip`, not raw `<dl>`).
- **Zero/loading/error states defined** — the group renders meaningfully in all three
  application states; loading uses `skeleton` components; zero-data uses `empty_state`;
  error uses `notice tone={:risk}`.
- **Desktop-table to mobile-card swap is content-equivalent** — the same data elements
  are present in both the desktop tabular layout and the mobile card layout; no content
  hidden between viewports without accessible equivalence.
- **Reused groups render byte-coherently** — if the same group pattern appears on multiple
  pages, both instances produce the same structure (same CSS classes, same data attributes)
  for equivalent data.

### L3 Page Composition Add-ons

Applied to each of the 6 page LiveViews (IndexLive, OrganizationLive, UsersIndexLive,
UserShowLive, AuditIndexLive, AuditUserLive).

- **Archetype conformance** — page conforms to the correct archetype: Overview (primary
  posture KPIs + task cards + recent feed), List (filter + table/card + pagination), or
  Detail (back link + scope ribbon + sections + audit sub-feed).
- **GOV.UK IA** — content hierarchy follows the GOV.UK principle: general → specific;
  tasks-first, posture-second, capabilities-last on Overview pages.
- **Principle-of-least-surprise** — primary action is the largest/first interactive element;
  destructive actions are secondary and require confirmation; navigation context is always
  visible via breadcrumbs or `page_back`.
- **Page vertical rhythm** — no flush adjacent sections (missing spacer); no double-gap
  (two `sg-stack` wrappers adding up to excessive whitespace); consistent `sg-stack--6`
  between major sections, `sg-stack--4` inside cards.
- **Landmark/heading order correct** — `<main>` landmark wraps page content; `<h1>` is
  the page title; subsequent headings use `<h2>` for sections; no skipped heading levels.
- **Focus management on navigate/patch** — LiveView patch updates restore focus to
  the first meaningful element in the updated region; full navigations reset scroll and
  focus to `<h1>` or page title.

### L4 Flow Add-ons

Applied to operator flows that span multiple pages (e.g. global admin login → overview →
user detail → impersonation → audit review → sign-out).

- **Persona JTBD happy + main-error + boundary** — the flow is tested with a seed-driven
  persona covering the happy path, the primary error case (e.g. wrong credentials,
  permission denied), and a boundary case (e.g. no data, max limits).
- **Scope/return-context preserved** — after navigating deep into a flow, returning to the
  list or overview restores the prior filter/pagination state; no context loss on back navigation.
- **Full keyboard operability** — the entire flow can be completed using keyboard only
  (Tab, Enter, Space, Esc); no mouse-only interactions.
- **Calm reduced-motion** — with `prefers-reduced-motion: reduce` set in the browser,
  page transitions and component animations are stripped; no jarring repaints.
- **Light/Dark/System persists across flow** — theme selection from the admin shell persists
  across LiveView navigations and patch events; no flash-of-wrong-theme on page load.
- **Deterministic fixture reproduces flow** — the demo seed data (`mix run priv/repo/seeds.exs`)
  provides enough personas and state that a Playwright test can reproduce the entire flow
  without any out-of-band setup.

---

Cross-reference: `admin-design-contract.md`, `admin-ui-principles.md`
