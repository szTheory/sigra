# Stack Research — v1.34 ADMIN-UI-COHERENCE

**Domain:** Lib-owned HEEx component consolidation + Playwright checkpoint expansion for Sigra's admin UI coherence pass
**Researched:** 2026-06-03
**Confidence:** HIGH — all findings grounded in actual project files; no new deps required

---

## The answer in one sentence

No new runtime dependencies, no Tailwind, no JS framework, and no new CSS are warranted.
Everything needed already exists: `Phoenix.Component` (bundled in `phoenix_live_view ~> 1.1`),
the complete `sg-*` CSS token layer in `test/example/priv/static/assets/css/app.css`, plain-JS
hooks already wired in the admin shell, and the existing Playwright `admin-checkpoints-{chromium,
mobile,dark}` project partition.

---

## Recommended Stack

### Core Technologies (no changes from today)

| Technology | Version (locked) | Purpose | Why / Notes |
|------------|-----------------|---------|-------------|
| Phoenix LiveView | 1.1.31 | LiveView rendering; `Phoenix.Component` for function components | `Phoenix.Component` is the correct host for a lib-owned HEEx component module. `use Phoenix.LiveView` already imports it in each admin LiveView. The new `lib/sigra/admin/components.ex` module will `use Phoenix.Component` directly (not `Phoenix.LiveView`) — it renders markup but does not own a socket. |
| Phoenix | 1.8.7 | Web framework | Already the project target. No changes. |
| Ecto / Ecto SQL | 3.x (locked) | Database layer | No role in component consolidation. |
| `@playwright/test` | ^1.48.0 (package.json) | Browser smoke + screenshot checkpoints | Already installed. New checkpoints (`global-overview`, `org-overview`, `user-audit`) are added to the **existing** `admin-checkpoints.spec.ts` spec — no new npm packages, no new config projects. |
| `@axe-core/playwright` | ^4.10.0 (package.json) | WCAG A/AA gating on each checkpoint | Already installed; `assertNoAxeViolations` is called per checkpoint. New checkpoints reuse the same helper. |

### The `Sigra.Admin.Components` Module

**Location:** `lib/sigra/admin/components.ex`

This is the only new source file in this milestone's stack. It is a pure function-component
module — no socket, no LiveView lifecycle, no new deps.

```elixir
defmodule Sigra.Admin.Components do
  @moduledoc """
  Shared HEEx function components for the lib-owned admin surfaces.
  Each component renders the canonical sg-* markup for one job — same job, same component.
  """
  use Phoenix.Component
  # No import of Phoenix.LiveView is needed; Phoenix.Component is the correct base.
  # attr / slot declarations are the public contract; callers get compile-time warnings
  # for missing required attrs and unknown attrs (when :global is absent).

  attr :label,  :string, required: true
  attr :value,  :integer, required: true
  attr :href,   :string, required: true

  def stat_link(assigns) do
    ~H"""
    <a href={@href} class="sg-metric-link">
      <span class="sg-metric-link__label">{@label}</span>
      <span class="sg-metric-link__value">{@value}</span>
    </a>
    """
  end

  # ... (stat, notice, filter_chip, applied_chip, page_back, scope_ribbon, empty_state, skeleton)
end
```

**How it is consumed inside lib LiveViews:**

Each LiveView module already `use Phoenix.LiveView`. That macro imports `Phoenix.Component`,
which means `import Sigra.Admin.Components` works directly in each `render/1`:

```elixir
defmodule Sigra.Admin.Live.IndexLive do
  use Phoenix.LiveView
  import Sigra.Admin.Components   # exposes def stat_link/1, def task_card/1, etc.
  ...
end
```

The generated `AdminShell` (host-side, `use MyAppWeb, :html`) can likewise `import Sigra.Admin.Components`
after `use Phoenix.Component` is already pulled in by the host's web module.

---

## `attr` / `slot` Idioms for the Shared Module

**Rule: every public component must declare its full contract with `attr` and `slot`.**
This is not optional style — Phoenix.Component emits compile-time warnings for callers that
pass unknown or missing attrs, which is the only static contract Sigra has with the generated
host's `AdminShell`.

### `attr` patterns in use / to follow

| Pattern | When | Example from codebase |
|---------|------|----------------------|
| `attr :name, :string, required: true` | Mandatory string attr | All existing `metric_link`, `task_card` — already correct |
| `attr :value, :integer, required: true` | Mandatory integer attr | `metric_link` value, `summary_chip` value |
| `attr :tone, :string, default: nil` | Optional state enum (ok/warn/risk/info/nil) | `notice` component; mirrors `sg-status-pill[data-tone]` vocab |
| `attr :href, :string, default: nil` | Optional navigation attr — nil = non-link variant | `stat` component needs both link and non-link renderings |
| `attr :class, :string, default: nil` | Escape hatch for one-off layout overrides | Use sparingly; document acceptable values |
| `attr :rest, :global` | Forward arbitrary HTML attrs (aria-*, data-*, id) | Add to `page_back`, `empty_state`, `scope_ribbon` where the caller may need to bind phx-* or id for LiveView targeting |

**`:global` usage rule:** add `attr :rest, :global` only to components whose root element
could reasonably receive HTML event attributes from a caller (e.g., `page_back` where the
caller may want `phx-click`). Do NOT add `:global` to inner-markup helpers (`stat_link`,
`task_card`) because they should be opaque wrappers over the token layer. The existing
`metric_link` / `summary_chip` / `task_card` in the live files are all private (`defp`) and
have no `:global` — this is correct.

**`slot` pattern** — use for the `empty_state` body text and the `notice` body:

```elixir
attr :tone,  :string, default: nil   # nil = neutral, "ok"/"warn"/"risk"/"info"
attr :title, :string, required: true
slot :inner_block, required: true    # the body paragraph(s)

def notice(assigns) do
  ~H"""
  <div class="sg-notice" data-tone={@tone}>
    <p class="sg-notice__title">{@title}</p>
    <div class="sg-notice__body">{render_slot(@inner_block)}</div>
  </div>
  """
end
```

The `slot :inner_block, required: true` pattern is idiomatic Phoenix.Component for layout
components. For simple data-display components (`stat_link`, `filter_chip`) use attrs only —
slots add HEEx nesting overhead the caller doesn't need.

---

## Skeleton / Loading States: Pure CSS, Not LiveView Async

**Decision: use the `.sg-skeleton` CSS class directly in HEEx markup. Do NOT introduce
LiveView async assigns (`assign_async/3`) or `phx-update="ignore"` patterns for this
milestone.**

Rationale grounded in the actual code:

1. **The CSS is already complete.** `app.css:1395` defines `.sg-skeleton` with a shimmer
   animation that already honors `prefers-reduced-motion`. The class exists and is spec'd — it
   is literally marked "used by later stages" in the CSS comment.

2. **Current mounts are synchronous.** Both `IndexLive.mount/3` and `UsersIndexLive.mount/3`
   call `Query.summary_counts/2` synchronously in `mount`. There is no existing async assign
   pattern anywhere in the 6 admin LiveViews. Introducing `assign_async/3` now is an
   architectural change that goes beyond the coherence scope and could break the existing
   Playwright checkpoint flow (checkpoints rely on `waitForLiveViewReady` + `phx-connected` —
   adding async assigns requires additional await logic).

3. **Skeleton as render-phase conditional, not async.** The correct pattern for this milestone
   is a simple conditional skeleton rendered while the page-level assign is `nil`, which is
   already the case during the brief mount/handle_params gap:

   ```heex
   <%= if @summary_counts == %{} do %>
     <div class="sg-skeleton" style="height: 2rem; width: 12rem;"></div>
   <% else %>
     <.stat_link label="Total" value={@summary_counts.total} href="/admin/users" />
   <% end %>
   ```

   This renders a skeleton on the initial mount before `handle_params` populates the assign,
   then switches to real content — no async assigns needed.

4. **If async is ever warranted (Phase 3+):** LiveView 1.1 has `assign_async/3` via
   `Phoenix.LiveView.Async`. Pattern: `assign_async(socket, :summary_counts, fn -> ... end)`.
   The assign value becomes `%AsyncResult{}` with `.loading?`, `.result`, `.failed` fields.
   Check with `@summary_counts.loading?` in the template. But this is NOT warranted for
   v1.34 — defer unless a Phase 3/4 profiling run shows measurable mount latency.

**What NOT to do:** Do not add `phx-update="append"` or `phx-update="stream"` — these are
for incrementally-updated lists, not for skeleton states. Do not add a JS hook to toggle
skeleton classes — pure CSS conditional rendering is sufficient and testable without JS.

---

## Playwright: Adding New Checkpoints to the Existing Spec

**The pattern is: add new blocks inside the existing single test in `admin-checkpoints.spec.ts`.
Do NOT add new projects to `playwright.config.ts`, do NOT add new spec files.**

### Why: the existing partition model is correct

`playwright.config.ts` already partitions by spec file, not by test. The three
`admin-checkpoints-{chromium,mobile,dark}` projects all use `testMatch: ADMIN_CHECKPOINTS_SPEC`.
Adding a new spec file for new checkpoints would require adding new `testMatch` entries or
widening the regex — both create reviewer confusion and CI drift. The existing single-test
design is intentional (comment: "a single test per project so fixtures are seeded once").

### Exact addition pattern

```typescript
// Inside the existing test body, after checkpoint 5 (audit-explorer):

// --- Checkpoint 6: Global overview (IndexLive) ---------------------------------
await page.goto('/admin');
await waitForLiveViewReady(page);
await expect(page.locator('h1')).toContainText('What do you need to do?');
await captureAndVerify(page, testInfo, 'global-overview');
await assertCheckpointScreenshot(page, testInfo, 'global-overview');

// --- Checkpoint 7: Org overview (OrganizationLive) ----------------------------
await page.goto(`/admin/organizations/${orgSlug}`);
await waitForLiveViewReady(page);
await expect(page.locator('header').first()).toContainText(orgName);
await captureAndVerify(page, testInfo, 'org-overview');
await assertCheckpointScreenshot(page, testInfo, 'org-overview');

// --- Checkpoint 8: Per-user audit (AuditUserLive) -----------------------------
const targetUserId = /* extract from URL after openUserDetail */ '...';
await page.goto(`/admin/users/${targetUserId}/audit`);
await waitForLiveViewReady(page);
await expect(page.getByRole('heading', { name: /Audit/ })).toBeVisible();
await captureAndVerify(page, testInfo, 'user-audit');
await assertCheckpointScreenshot(page, testInfo, 'user-audit');
```

The `captureAndVerify` + `assertCheckpointScreenshot` helpers are already defined in the spec
and call the correct `captureAdminCheckpoint` artifact helper. The `assertCheckpointScreenshot`
helper already handles the per-project thresholds (`ci`, `dark`, `mobile`). No changes to
`adminArtifacts.ts` or `playwright.config.ts` are needed.

### Snapshot baselines

The `toHaveScreenshot` call in `assertCheckpointScreenshot` uses the path template:
```
{testDir}/{testFilePath}-snapshots/{arg}{-projectName}{ext}
```
So new baselines land at:
```
tests/admin-checkpoints.spec.ts-snapshots/global-overview-admin-checkpoints-chromium.png
tests/admin-checkpoints.spec.ts-snapshots/global-overview-admin-checkpoints-dark.png
tests/admin-checkpoints.spec.ts-snapshots/global-overview-admin-checkpoints-mobile.png
```
These are committed to the repo on first-record via `--update-snapshots`. The per-project
pixel thresholds in `assertCheckpointScreenshot` already handle the CI/dark/mobile variance
without changes.

### `testInfo` / user-ID extraction pattern

The `targetEmail` user is already created earlier in the test. To get the user ID for
`/admin/users/:id/audit`, navigate to the user detail and parse `page.url()`:

```typescript
await openUserDetail(page, targetEmail);
const detailUrl = new URL(page.url());
const userId = detailUrl.pathname.split('/').at(-1)!;
```

This pattern is already used in the spec for the impersonation checkpoint (see `detailPath`
derivation at line 212).

---

## What NOT to Add

| Avoid | Why |
|-------|-----|
| New runtime Hex dependencies | Zero new deps warranted. `Phoenix.Component` is already in `phoenix_live_view`. The `sg-*` CSS layer is complete. No new token work is in scope. |
| Tailwind CSS | The admin surface is explicitly `--no-tailwind`. The `sg-*` token + BEM layer is the design system. Mixing Tailwind utility classes would break the existing responsive system and dark-mode block. |
| Alpine.js, Stimulus, LiveSvelte, or any JS framework | The admin already uses three hand-written plain JS hooks (CmdK, copy-to-clipboard, theme). All interactive patterns in scope (skeleton reveal, filter chips, notice dismissal) are either pure CSS conditionals or existing LiveView `phx-click` events. No additional JS abstractions needed. |
| `assign_async/3` or `Phoenix.LiveView.Async` | Current mounts are synchronous and fast. Adding async introduces Playwright await complexity and is out of scope for a coherence pass. |
| New Playwright config projects | The existing `admin-checkpoints-{chromium,mobile,dark}` projects already cover all three viewports/themes. Add checkpoints inside the existing spec, not new projects. |
| `@axe-core/playwright` upgrade | The ^4.10.0 constraint is compatible with current WCAG rules. No upgrade needed for this milestone. |
| `phoenix_live_view` async streams for admin tables | `phx-update="stream"` is for incrementally-updated push lists (e.g., real-time feeds). Admin tables are paginated query results loaded on navigation. Standard `assign` + render is correct. |
| A dedicated Storybook or component catalog | The milestone scope is consolidation of 6 existing screens, not building a component development environment. The repo's Playwright checkpoint reports serve as the visual catalog. |
| `Phoenix.HTML.Form` / `to_form` | Filter forms in the admin use `method="get"` HTML forms (not LiveView changesets) by design, so they work without JS. Do not migrate to `to_form` / `<.form>` component. |
| New CSS variables or `sg-*` tokens | The token layer is complete and Emil-Kowalski-compliant. This milestone audits usage — adds no new tokens, no new CSS layers, no new keyframes. The one exception: `sg-notice` styles will need to be added to `app.css` if the `notice` component is introduced, because the CSS class does not yet exist. This is a minor addition of ~15 lines inside the existing `sg-components` layer, not a new token or primitive. |

---

## Module Location Decision

`lib/sigra/admin/components.ex` is the correct location. Rationale:

- Mirrors the existing module namespace: `Sigra.Admin.Live.*` lives in `lib/sigra/admin/live/`.
  A sibling `Sigra.Admin.Components` at `lib/sigra/admin/components.ex` is idiomatic.
- It is lib-owned (ships with `mix deps.update sigra`), matching the hybrid architecture.
  Security-critical markup that operators rely on for correct action labels, aria attributes,
  and tone states should propagate via dep updates, not require host app regeneration.
- The generated `AdminShell` (host-side) remains in `priv/templates/` and imports
  `Sigra.Admin.Components` — this keeps the generated file thin and makes the component
  contract visible to the generator.
- Do NOT put the module in `lib/sigra_web/` — Sigra has no `sigra_web` top-level; the
  admin LiveViews are already in `lib/sigra/admin/live/` following the library convention.

---

## Version Compatibility

| Package | Version | Notes |
|---------|---------|-------|
| `phoenix_live_view` | 1.1.31 | `Phoenix.Component`, `attr/3`, `slot/3`, `render_slot/2` all available. `assign_async/3` available but not needed. |
| `phoenix` | 1.8.7 | HEEx sigil, `~H"""` fully supported. No API changes relevant to this scope. |
| `@playwright/test` | ^1.48.0 | `toHaveScreenshot` with `pathTemplate` and `maxDiffPixels`/`maxDiffPixelRatio` both available. |
| `@axe-core/playwright` | ^4.10.0 | `AxeBuilder.withTags(['wcag2a','wcag2aa'])` API unchanged. |

---

## Sources

- `lib/sigra/admin/live/index_live.ex` — confirmed `attr` declaration patterns; `metric_link`/`task_card` private components are the canonical source forms
- `lib/sigra/admin/live/users_index_live.ex` — confirmed `summary_chip` / `quick_filter` / `applied_chip` pattern; filter chip HTML structure
- `lib/sigra/admin/live/organization_live.ex` — confirmed duplicate `metric_link`/`task_card` definitions (lines 165–193)
- `test/example/priv/static/assets/css/app.css` — confirmed `.sg-skeleton` CSS at line 1395 (complete, shimmer animation, prefers-reduced-motion block); confirmed `.sg-metric-link`, `.sg-metric`, `.sg-filter-chip`, `.sg-applied-chip`, `.sg-posture-strip` all present; `sg-notice` NOT present (needs ~15 lines in `sg-components` layer if added)
- `test/example/priv/playwright/playwright.config.ts` — confirmed project partition model; `ADMIN_CHECKPOINTS_SPEC` regex; three checkpoint projects
- `test/example/priv/playwright/tests/admin-checkpoints.spec.ts` — confirmed single-test pattern; `captureAndVerify` + `assertCheckpointScreenshot`; `waitForLiveViewReady`; user-ID-from-URL extraction pattern
- `test/example/priv/playwright/helpers/adminArtifacts.ts` — confirmed `captureAdminCheckpoint` helper contract
- `test/example/priv/playwright/package.json` — confirmed `@playwright/test: ^1.48.0`, `@axe-core/playwright: ^4.10.0`
- `mix.lock` — confirmed `phoenix_live_view: 1.1.31`, `phoenix: 1.8.7`
- `priv/templates/sigra.install/admin/components/admin_shell.ex` — confirmed `use MyAppWeb, :html` + `attr`/`slot` usage in generated shell; `import Sigra.Admin.Components` wiring point
- Phoenix LiveView 1.1 docs: `Phoenix.Component`, `attr/3`, `slot/3` — HIGH confidence (current locked version)

---

*Stack research for: v1.34 ADMIN-UI-COHERENCE — shared Sigra.Admin.Components + Playwright checkpoint expansion*
*Researched: 2026-06-03*
