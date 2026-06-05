# Architecture Research — v1.34 ADMIN-UI-COHERENCE

**Domain:** Shared Admin Component Layer — lib+generator hybrid integration
**Researched:** 2026-06-03
**Confidence:** HIGH (derived from direct codebase inspection, no external speculation)

## System Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                     LIBRARY (lib/)                                   │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │  lib/sigra/admin/components.ex  ← NEW (Phase 1)              │   │
│  │  Sigra.Admin.Components                                       │   │
│  │  Public `def` functions: task_card/1, metric_link/1,         │   │
│  │  summary_chip/1, notice/1, scope_ribbon/1, page_back/1,      │   │
│  │  empty_state/1, skeleton/1                                    │   │
│  └───────────────────────┬──────────────────────────────────────┘   │
│                           │  `import Sigra.Admin.Components`         │
│  ┌────────────────────────▼──────────────────────────────────────┐  │
│  │  lib/sigra/admin/live/                                        │  │
│  │   index_live.ex         (Overview archetype — Global)         │  │
│  │   organization_live.ex  (Overview archetype — Org)            │  │
│  │   users_index_live.ex   (List archetype)                      │  │
│  │   user_show_live.ex     (Detail archetype)                    │  │
│  │   audit_index_live.ex   (List archetype)                      │  │
│  │   audit_user_live.ex    (Detail archetype)                    │  │
│  └───────────────────────────────────────────────────────────────┘  │
└────────────────────────────────────┬────────────────────────────────┘
                                     │  updated via mix deps.update
┌────────────────────────────────────▼────────────────────────────────┐
│                 GENERATED HOST APP (test/example/)                   │
│  test/example/lib/example_web/components/admin_shell.ex             │
│  (host-owned: imports lib LiveViews, owns shell chrome)             │
│                                                                      │
│  test/example/priv/static/assets/css/app.css                        │
│  (ONLY CSS file; sg-* BEM token layer; ~89 custom properties)       │
│                                                                      │
│  test/example/priv/playwright/tests/admin-checkpoints.spec.ts       │
│  (visual + a11y + parity contract)                                   │
└─────────────────────────────────────────────────────────────────────┘
                              ↑ mirrored from
┌─────────────────────────────────────────────────────────────────────┐
│              INSTALLER TEMPLATE (priv/templates/sigra.install/)     │
│  admin/components/admin_shell.ex  ← template (EEx with web_module) │
└─────────────────────────────────────────────────────────────────────┘
```

## Component Boundaries

| Component | Responsibility | Lib-owned or Generated | Updated How |
|-----------|---------------|------------------------|-------------|
| `Sigra.Admin.Components` (new) | Canonical shared HEEx components — task_card, metric_link, summary_chip, notice, scope_ribbon, page_back, empty_state, skeleton | **Lib-owned** | `mix deps.update sigra` |
| `lib/sigra/admin/live/*.ex` (6 LiveViews) | Screen logic, data loading, event handling, render using shared components | **Lib-owned** | `mix deps.update sigra` |
| `AdminShell` (generated, host-owned) | Shell chrome: topbar, sidebar nav, breadcrumb, impersonation banner, bottom nav, scope switcher | **Generated** (template + example) | Installer re-run or manual migration |
| `app.css` (host-owned) | All `sg-*` BEM token CSS; no build step | **Generated** (example only; referenced by `priv/templates`) | Not touched by this milestone |
| `admin-checkpoints.spec.ts` | Visual baseline + axe + parity contract | **Generated** (example only) | Extended with new checkpoint slugs |

## Question 1: Where Does `Sigra.Admin.Components` Live and How Is It Imported?

**Decision: Lib-owned at `lib/sigra/admin/components.ex`, module `Sigra.Admin.Components`.**

The 6 LiveViews (`index_live.ex`, `organization_live.ex`, `users_index_live.ex`, `user_show_live.ex`, `audit_index_live.ex`, `audit_user_live.ex`) all already live in `lib/sigra/admin/live/`. They are lib-owned and updated via `mix deps.update`. The shared components must follow the same ownership boundary — otherwise components lag behind the LiveViews that use them, which defeats the coherence goal.

**Import mechanism:**

Each LiveView that uses the shared components adds `import Sigra.Admin.Components` at the module level, immediately after `use Phoenix.LiveView`. This replaces the current `defp metric_link/1`, `defp task_card/1`, and `defp summary_chip/1` private defs that are duplicated across `index_live.ex`, `organization_live.ex`, and `users_index_live.ex`.

```elixir
# lib/sigra/admin/components.ex
defmodule Sigra.Admin.Components do
  use Phoenix.Component

  attr :label, :string, required: true
  attr :value, :integer, required: true
  attr :href, :string, required: true
  def metric_link(assigns) do
    ~H"""
    <a href={@href} class="sg-metric-link">
      <span class="sg-metric-link__label">{@label}</span>
      <span class="sg-metric-link__value">{@value}</span>
    </a>
    """
  end

  # ... task_card, summary_chip, notice, scope_ribbon, page_back, empty_state, skeleton
end
```

```elixir
# lib/sigra/admin/live/index_live.ex
defmodule Sigra.Admin.Live.IndexLive do
  use Phoenix.LiveView
  import Sigra.Admin.Components   # ← import replaces private defp duplicates
  ...
end
```

**The generated host app does not need to know about `Sigra.Admin.Components` directly.** The host app generates `AdminShell` (the chrome), which wraps the lib-owned LiveViews via the router. The LiveViews reference components via their own `import` — this is entirely internal to the library. The host app is never asked to import or call `Sigra.Admin.Components` itself.

**No generated mirroring is needed for the component module.** It is a pure lib artifact, the same as `Sigra.Admin.Live.IndexLive`. Adopters get it automatically when they run `mix deps.update sigra`.

## Question 2: CSS Class References — Lib LiveViews Emitting `sg-*` Classes

**The boundary works because lib emits class names; CSS ships with the host.**

The lib-owned LiveViews and `Sigra.Admin.Components` already emit `sg-*` BEM class strings in their HEEx markup. This has worked since v1.2 Admin Dashboard and is the established pattern. There is no drift risk on the CSS side from this milestone because:

1. The milestone explicitly does not add new CSS tokens (the `sg-*` layer is declared mature in the kickoff brief). All new components (`notice`, `scope_ribbon`, `page_back`, `skeleton`) must use only existing `sg-*` classes already defined in `app.css`.

2. The single CSS file lives at `test/example/priv/static/assets/css/app.css` and is also the template's CSS reference. When a new host app runs `mix sigra.install`, it gets a copy of this file. After that, the host owns their CSS.

3. The `sg-skeleton` class is already defined in `app.css` (line 1395, per the kickoff brief) but unused. The skeleton component in `Sigra.Admin.Components` will reference `sg-skeleton` — this is zero-risk because the class already exists in both the example and the installer template.

**Drift risk:** The only drift risk is if a component uses a class that exists in `test/example/priv/static/assets/css/app.css` but was not propagated to `priv/templates/sigra.install/` CSS at install time. Mitigate by auditing any new class name against both files before Phase 1 ships. Given no new tokens are added, this is low risk.

## Question 3: Mapping Page Archetypes to Module Structure

The 3 archetypes map cleanly onto the existing module structure. No new modules, no structural changes.

### Overview Archetype

Used by: `IndexLive` (Global) and `OrganizationLive` (Org)

Structure:
- `<.task_card>` grid (verbs-first, 3-col Global / 2-col Org)
- `<.notice>` or `<.scope_ribbon>` for needs-review alarm
- Posture strip with `<.metric_link>` row
- Secondary capability/members section

Both LiveViews use `render/1` with no sub-layouts. After Phase 1 the private `defp metric_link` and `defp task_card` are removed and replaced with the imported public versions.

### List Archetype

Used by: `UsersIndexLive` and `AuditIndexLive`

Structure:
- `sg-page-header` with `<.summary_chip>` strip in the header
- Filter chip row (quick filters visible, more filters disclosed)
- Table / card list with `sg-table-panel` or `sg-list`
- Pagination row

`UsersIndexLive` already has `summary_chip` as a private `defp`. `AuditIndexLive` has a different filter idiom (bare `sg-field` inputs). After Phase 2 both use `<.summary_chip>` from the shared module and the same filter chip pattern.

### Detail Archetype

Used by: `UserShowLive` and `AuditUserLive`

Structure:
- `<.page_back>` consuming `@return_to` (replaces bespoke `sg-btn--ghost` back link)
- `sg-page-header` (open, not boxed) — `UserShowLive` currently uses `sg-card` wrapper; Phase 2 removes it
- `<.scope_ribbon>` below the page header (scoped attention signal)
- Sub-resource cards (`sg-card`) for sessions, security, audit, etc.

### Shared Layout Helpers vs Per-LiveView Render

All layout composition stays in per-LiveView `render/1` — there is no shared "archetype layout" function. Each LiveView assembles its own render using shared components as building blocks. This preserves the clarity of "what is on each screen is visible in that LiveView" and avoids magical composition through helper-layouts, which would obscure the structure from future maintainers.

## Question 4: Playwright Checkpoint Specs and Admin-Generated Parity Lane

**The current spec has 5 checkpoints × 3 projects = 15 baselines.** The spec is the `admin-checkpoints` partition only; the `admin-generated` lane is a separate ExUnit installer-parity test.

### What the spec currently covers (from direct inspection)

| Checkpoint slug | URL | What it asserts |
|---|---|---|
| `global-user-index` | `/admin/users?q=...` | admin shell chrome, Global scope, dense list |
| `user-detail` | `/admin/users/:id` | detail layout, impersonation/revoke buttons |
| `org-scoped-admin` | `/admin/organizations/:slug/users` | org-scoped shell chrome |
| `impersonation-banner` | `/organizations/:slug/members` | impersonation banner on non-admin page |
| `audit-explorer` | `/admin/audit?action_prefix=...` | filter, export, impersonation attribution |

**Coverage gaps this milestone must close (by adding checkpoints, not widening behavior matrix):**

| New checkpoint slug | URL target | Phase |
|---|---|---|
| `global-overview` | `/admin` | Phase 3 |
| `org-overview` | `/admin/organizations/:slug` | Phase 3 |
| `user-audit` | `/admin/users/:id/audit` | Phase 4 |

**Markup constraints from the existing baselines:**

- The existing 5 checkpoint baselines (`global-user-index`, `user-detail`, `org-scoped-admin`, `impersonation-banner`, `audit-explorer`) use `assertCheckpointScreenshot` with committed PNGs. Any markup change to pages covered by these checkpoints will show as a diff in the playwright HTML report and requires deliberate re-record.
- Phase 1 (behavior-preserving extraction) must not trigger baseline diffs. If it does, something went wrong.
- Phase 2 (adopt on baselined screens) will trigger intentional diffs. Baselines re-recorded after visual review in the playwright HTML report.
- The `admin-generated` parity lane checks that installer-generated output renders equivalently to the example. Because `Sigra.Admin.Components` is lib-owned (not generated), the parity lane is not directly affected by the component module itself. **The parity lane is only affected if `AdminShell` changes** — and `AdminShell` is not touched by this milestone.

**Axe (WCAG A/AA) runs on every checkpoint.** New components must be accessible from the start. Specifically:
- `<.notice>` must use appropriate ARIA roles (`role="alert"` for live notices, `role="status"` for info)
- `<.page_back>` must have visible text (not icon-only)
- `<.skeleton>` must use `aria-hidden="true"` and `aria-busy="true"` on the loading container

## Question 5: Build Order

The correct build order respects the "behavior-preserving extraction first" principle and ensures each phase's success criteria is independently verifiable.

### Phase 0 — Design contract (no code)
Output: committed artifact documenting canonical component set, attribute signatures, Job→Component mapping table, 3 page archetype compositions, anti-churn list. No `.ex` files changed.

**Why first:** The component signatures and archetype layouts are architectural decisions. Getting them wrong in Phase 1 means re-extracting in Phase 2. Writing them down as a reviewed artifact before any code prevents scope creep in Phase 1.

### Phase 1 — Build `Sigra.Admin.Components` (new file, lib-owned)
**New file:** `lib/sigra/admin/components.ex`

Components to extract (sourced from existing best instances):
- `metric_link/1` — from `index_live.ex:118` and `organization_live.ex:169` (identical markup, identical attrs; one canonical source)
- `task_card/1` — from `index_live.ex:132` and `organization_live.ex:183` (identical; one canonical source)
- `summary_chip/1` — from `users_index_live.ex` private defp

New components added (markup composed from existing `sg-*` primitives):
- `notice/1` — attrs: `tone` (risk/warn/info/ok), `inner_block`; wraps `sg-list-row[data-tone]` pattern already in `user_show_live.ex:131`
- `scope_ribbon/1` — attrs: `admin_scope`; lightweight `sg-muted sg-text-sm` scope label strip
- `page_back/1` — attrs: `href`, `label`; wraps `sg-btn sg-btn--ghost sg-btn--sm` with `&larr;` already in `user_show_live.ex:91`
- `empty_state/1` — attrs: `title`, `body` (optional); wraps `sg-empty-state` already used in `user_show_live.ex:188`
- `skeleton/1` — attrs: `class` (optional extra class); wraps `sg-skeleton` (defined in css, unused)

**Success criterion:** All existing Playwright baselines green with no re-record. This proves the extraction is behavior-preserving — the rendered markup is byte-identical to the private defps being replaced.

**No changes to any existing LiveView files in this phase.**

### Phase 2 — Adopt shared components on baselined screens (modify existing LiveViews)
Screens touched: `IndexLive`, `OrganizationLive`, `UsersIndexLive`, `UserShowLive`, `AuditIndexLive`

**What changes in each file:**

| LiveView | Removals | Additions/Changes |
|---|---|---|
| `index_live.ex` | `defp metric_link`, `defp task_card`, `defp capability` (keep capability as private — not shared) | `import Sigra.Admin.Components`; call `<.metric_link>` and `<.task_card>` from module |
| `organization_live.ex` | `defp metric_link`, `defp task_card` | `import Sigra.Admin.Components`; call shared versions |
| `users_index_live.ex` | `defp summary_chip` | `import Sigra.Admin.Components`; call `<.summary_chip>` |
| `user_show_live.ex` | bespoke back-nav cluster (line 91–95), `sg-card` wrapper around the header section (line 97), ad-hoc `sg-list-row` alert (line 131) | `<.page_back>`, open `sg-page-header` (remove `sg-card` wrapper), `<.notice>`, `<.scope_ribbon>` |
| `audit_index_live.ex` | bare `sg-field` filter inputs | `<.summary_chip>` strip; filter chip pattern matching users index |

**Success criterion:** Playwright baselines for the 5 existing checkpoints show only the intended deltas (documented before re-record). Axe passes. `admin-generated` parity lane stays green.

### Phase 3 — Under-iterated: Two Overview landings
Screens touched: `IndexLive`, `OrganizationLive`

Architecture impact: None. Uses only components from Phase 1. The render restructuring (verbs-first, demoted posture strip, scope ribbon, single alarm) is markup rearrangement within the existing `render/1` function.

**New checkpoints added:** `global-overview`, `org-overview` — each in `admin-checkpoints.spec.ts` using `captureAndVerify` + `assertCheckpointScreenshot` + `assertNoAxeViolations`.

### Phase 4 — Under-iterated: Audit mobile + per-user audit
Screens touched: `AuditIndexLive`, `AuditUserLive`

Architecture impact: `AuditUserLive` adopts the shared `<.page_back>`, `<.scope_ribbon>`, `<.notice>`, and `<.empty_state>` components. Mobile card fallback in `AuditIndexLive` uses existing `sg-*` CSS responsive utilities.

**New checkpoint added:** `user-audit`.

### Phase 5 — Cross-journey coherence sweep + seed enrichment
No new components or module-level changes. Markup adjustments across all 6 LiveViews. Seed enrichment in `test/example/lib/example/demo/`.

### Phase 6 — Regression hardening + baseline ratification
All committed PNGs re-recorded and ratified. Final clean run across all playwright projects + `admin-generated` parity lane.

## Integration Points

### Internal Boundaries

| Boundary | Communication | Notes |
|----------|---------------|-------|
| `Sigra.Admin.Components` → 6 LiveViews | `import` at module level | Phase 1: new file, no changes to LiveViews yet |
| `Sigra.Admin.Components` → `AdminShell` | None — `AdminShell` is host-generated; it does not call component module directly | Preserved boundary |
| LiveViews → CSS | String class names in HEEx markup | Lib emits names; CSS ships with host — this is unchanged |
| `admin-checkpoints.spec.ts` → LiveViews | HTTP + LiveView WebSocket | New checkpoint slugs added in Phases 3–4; existing assertions unchanged |
| `admin-generated` parity lane → installer template | ExUnit fixture; compares generated output | Not affected unless `AdminShell` template changes — and it does not |

### Template/Example Drift Obligation

**`AdminShell` is the one file with a template-vs-example seam.** Direct diff of `priv/templates/sigra.install/admin/components/admin_shell.ex` vs `test/example/lib/example_web/components/admin_shell.ex` confirms they are currently byte-identical modulo the EEx `<%= web_module %>` substitution for `ExampleWeb`.

**This milestone does not change `AdminShell`.** The template-vs-example seam is therefore not disturbed by v1.34 work. The drift obligation is: if `AdminShell` were to change (it should not for this milestone), both files must be updated simultaneously and the `admin-generated` parity lane re-run.

The new `Sigra.Admin.Components` module does not have a template counterpart — it is a lib file, not a generated file. No template mirroring is required for it.

## Recommended Project Structure (after Phase 1)

```
lib/sigra/admin/
├── components.ex          ← NEW: shared HEEx component module (Phase 1)
├── live/
│   ├── index_live.ex      ← MODIFIED: import Components, remove private defp duplicates
│   ├── organization_live.ex  ← MODIFIED: same
│   ├── users_index_live.ex   ← MODIFIED: same
│   ├── user_show_live.ex     ← MODIFIED: adopt page_back, notice, scope_ribbon
│   ├── audit_index_live.ex   ← MODIFIED: adopt summary_chip, filter chips
│   └── audit_user_live.ex    ← MODIFIED: adopt page_back, scope_ribbon, notice (Phase 4)
└── ...                    (no other structural changes)

test/example/priv/playwright/tests/
└── admin-checkpoints.spec.ts  ← EXTENDED: add global-overview, org-overview, user-audit

test/example/lib/example/demo/
├── personas.ex            ← EXTENDED: Phase 5 seed enrichment
└── seeds.ex               ← EXTENDED: Phase 5 seed enrichment
```

## Anti-Patterns to Avoid

### Anti-Pattern 1: Putting the component module in `generated/` or treating it as host-owned

**What goes wrong:** If `Sigra.Admin.Components` were generated into the host app, adopters would pin to a snapshot at install time. Security and coherence patches to shared components would not propagate via `mix deps.update` — exactly the failure mode Sigra's hybrid architecture is designed to prevent for security-critical code.

**Do this instead:** `lib/sigra/admin/components.ex` — lib-owned, same as all 6 LiveViews.

### Anti-Pattern 2: Extracting components without a behavior-preserving Phase 1

**What goes wrong:** If Phase 1 and Phase 2 (adopt + refactor) are merged, the Playwright baselines cannot serve as a regression gate for the extraction step. Any baseline failure is ambiguous: was it the extraction or the refactor that caused it?

**Do this instead:** Phase 1 adds the new file only. No LiveView file is touched. All baselines pass unchanged. Phase 2 modifies LiveViews and expects deliberate baseline diffs only for the screens it touches.

### Anti-Pattern 3: Adding new `sg-*` CSS tokens in this milestone

**What goes wrong:** The kickoff brief explicitly says the token layer is mature. Adding tokens requires updating `app.css` in `test/example/`, the installer template CSS, and all existing host apps' CSS — none of which is coordinated. It also risks divergence between the example CSS and what installer-generated apps have.

**Do this instead:** Compose all new components exclusively from existing `sg-*` classes. Audit against `app.css` before landing any component. The `sg-skeleton` class already exists; use it.

### Anti-Pattern 4: Touching `AdminShell` to accommodate shared components

**What goes wrong:** `AdminShell` is the template-vs-example seam. Any change requires synchronized updates to `priv/templates/sigra.install/admin/components/admin_shell.ex` AND `test/example/lib/example_web/components/admin_shell.ex`, re-running the `admin-generated` parity lane, and communicating a template upgrade to existing adopters.

**Do this instead:** `Sigra.Admin.Components` is imported by the lib LiveViews, not by `AdminShell`. The shell remains untouched.

## Sources

- Direct inspection of `lib/sigra/admin/live/index_live.ex` and `organization_live.ex` confirming identical `defp metric_link` and `defp task_card` definitions (byte-for-byte duplication)
- Direct inspection of `user_show_live.ex` confirming boxed `sg-card` header wrapping (line 97), bespoke back-nav cluster (line 91–95), and ad-hoc `sg-list-row` notice pattern (line 131)
- Direct inspection of `admin-checkpoints.spec.ts` confirming 5 existing checkpoint slugs and the `captureAndVerify` + `assertCheckpointScreenshot` + `assertNoAxeViolations` contract
- Direct diff of template `priv/templates/sigra.install/admin/components/admin_shell.ex` vs `test/example/lib/example_web/components/admin_shell.ex` — byte-identical modulo EEx substitution
- `~/.claude/plans/recap-sigra-v1-0-0-ga-cached-puppy.md` — approved kickoff brief (2026-06-03): phase order, scope lock, anti-churn list, new checkpoint slugs
- `.planning/research/IA-JOURNEY-SYNTHESIS.md` — IA + animation principles informing archetype layouts
- `PROJECT.md` v1.34 scope statement

---
*Architecture research for: v1.34 ADMIN-UI-COHERENCE shared component layer integration*
*Researched: 2026-06-03*
