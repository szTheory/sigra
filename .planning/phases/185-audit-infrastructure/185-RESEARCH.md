# Phase 185: Audit Infrastructure — Research

**Researched:** 2026-06-14
**Domain:** Example-only gallery LiveView, Playwright board-snapshot lane, shell-script CI guards, Markdown quality ledger
**Confidence:** HIGH — all findings verified against real source files with line numbers

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

D-01 through D-18 are locked. See `185-CONTEXT.md` `<decisions>` block for
the full canonical text. Summary for planner orientation:

| ID | Summary |
|----|---------|
| D-01 | Gallery at `test/example/lib/example_web/live/admin/design_gallery_live.ex`; dev-route gated; `{ExampleWeb.Layouts, :admin}` shell |
| D-02 | `import Sigra.Admin.Components`; all 13 functions; data-driven assigns; no bespoke markup |
| D-03 | Each component/group in a board wrapper with stable `id` (`board-{component}`, `board-mg-{n}`) |
| D-04 | Contract guard: no `_design`/`design_gallery` artifact in `priv/templates/sigra.install/` |
| D-05 | Three Playwright projects: `admin-design-{chromium,mobile,dark}` cloning checkpoint shape |
| D-06 | One element-scoped composite board PNG per component/group (not per state) |
| D-07 | Axe gate: `@axe-core/playwright`, `wcag2a+wcag2aa`, 0 violations, reuse `assertNoAxeViolations` |
| D-08 | Second empty `snapshot-allowlist-design` (steady-state comments-only) |
| D-09 | Extend `snapshot-canary-guard.sh` to recognize `-admin-design-*` slug suffix |
| D-10 | Designate `board-notice` as design-lane canary |
| D-11 | Ledger as committed Markdown table; columns: item id, fractal level, achieved tier, evidence link |
| D-12 | Tier vocabulary 0/1/2; tier cell is a machine-parseable fixed-column integer |
| D-13 | Ledger at `guides/reference/admin-quality-ledger.md` (net-new, siblings to existing reference files) |
| D-14 | `quality-ledger-monotonic.sh` mirrors `snapshot-canary-guard.sh` conventions |
| D-15 | Per-cell tier comparison: `git show "$BASE:..."` vs working tree; fail on any decrease |
| D-16 | New `quality_ledger_monotonic` CI job in `ci-gate` `needs:` + lane loop; base-ref resolution reused |
| D-17 | Scorecard rubric at `guides/reference/admin-fractal-scorecard.md` (standalone, not embedded in ledger) |
| D-18 | Content: D1–D11 shared + per-level add-ons (Component/Group/Page/Flow) |

### Claude's Discretion

- MG-N catalog → page-region mapping (planner's call; research surfaces candidates below)
- Guard refactor vs. second invocation for design-lane recognition
- Exact spec/board naming, board count per component, which board is canary (answered: `board-notice` per D-10/UI-SPEC)
- Exact ExUnit/CI mechanism for D-04 contract guard

### Deferred Ideas (OUT OF SCOPE)

- Actual fractal audits/quality improvements (phases 186-191)
- Changing any token values (Phase 186 only)
- New admin features, screens, or nav restructuring
- `phx_storybook` dependency
- Auth UI surfaces
- Retroactively byte-guarding example `sigra_auth.css` copy
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| INFRA-01 | Example-only `/admin/_design` gallery LiveView rendering all 13 components + meta-component groups in every state, inside the real admin shell, dev-route gated, contract-guarded | D-01..D-04; gallery shape from `CredentialsLive` + router `if` block; component assigns from `components.ex`; admin shell from router `live_session :admin_global` |
| INFRA-02 | `admin-design-{chromium,mobile,dark}` Playwright board-snapshot lane; element-scoped composite board PNGs; axe wcag2a+wcag2aa, 0 violations | D-05..D-07; clone pattern from `admin-checkpoints.spec.ts` lines 114-148 and `playwright.config.ts` lines 107-138 |
| INFRA-03 | Second empty `snapshot-allowlist-design`; gallery canary board; `snapshot-canary-guard.sh` recognizes `-admin-design-*` slugs | D-08..D-10; `slug_of()` at `snapshot-canary-guard.sh` lines 53-55; `snapshot-recapture-gate.sh` update |
| INFRA-04 | `guides/reference/admin-quality-ledger.md` with per-cell tier integers 0/1/2 | D-11..D-13; machine-parseable table format specified below |
| INFRA-05 | Merge-blocking `scripts/ci/quality-ledger-monotonic.sh`; fails if any tier decreased vs base ref | D-14..D-16; mirror `snapshot-canary-guard.sh` convention; per-cell extraction strategy |
| INFRA-06 | Ratified fractal scorecard rubric at `guides/reference/admin-fractal-scorecard.md` | D-17..D-18; D1-D11 + per-level add-ons defined; cross-reference `admin-design-contract.md` |
</phase_requirements>

---

## Summary

Phase 185 builds six audit instruments for the DS-COHERENCE milestone's fractal sweep. Every
instrument either clones a verified existing pattern (Playwright projects, guard scripts, allowlist)
or authors a new file that must be machine-parseable by a guard script or by CI. No live Postgres
query is needed and no new npm/hex packages are required — `@axe-core/playwright` is already wired
in `admin-checkpoints.spec.ts`.

The gallery LiveView is the most novel piece. It must mount inside the real admin shell without the
`Sigra.LiveView.AdminScope` on_mount (which requires a real admin policy + Postgres). The dev-route
scope gates it cleanly so it never compiles into test/prod builds where `Application.compile_env`
would be false. The gallery cannot call any Query modules — all assigns are static literal data.

**Primary recommendation:** Clone ruthlessly. The `admin-checkpoints-*` trio, `assertNoAxeViolations`,
`snapshot-canary-guard.sh`, and `snapshot-allowlist` are direct templates for every new artifact.
The only net-new logic is (a) the gallery LiveView with static assign data, (b) the `slug_of()`
extension for the design suffix, and (c) the per-cell monotonic guard.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Gallery route + LiveView | Example-only (`test/example/`) | — | D-04 prohibits installer template leakage |
| Gallery markup (components) | Lib (`Sigra.Admin.Components`) | Gallery is just a caller | D-02: gallery imports, never duplicates |
| Admin shell chrome / theme | Lib (`Sigra.Admin.Live` shell) | `{ExampleWeb.Layouts, :admin}` | Gallery wraps in the real shell, not a stripped test harness |
| Playwright project defs | Example (`playwright.config.ts`) | — | Config lives beside the test files it governs |
| Snapshot allowlist-design | Example (`priv/playwright/`) | — | Paired with the snapshot dirs it guards |
| Guard scripts (canary, monotonic) | `scripts/ci/` | `.github/workflows/ci.yml` | CI infra layer, not app code |
| Quality ledger + rubric | `guides/reference/` | CI guard reads it | Reference docs with machine-parseable cells |

---

## Standard Stack

No new packages required. All tooling is already in place.

### Core (already available)

| Tool | Version | Purpose | Evidence |
|------|---------|---------|---------|
| `@axe-core/playwright` | Already installed | WCAG axe gate | `admin-checkpoints.spec.ts` line 2 `import AxeBuilder` |
| `@playwright/test` | Already installed | Browser snapshot + axe runner | `playwright.config.ts` line 1 |
| Phoenix LiveView | Already in mix.exs | Gallery LiveView module | All lib-owned admin pages use it |
| `Sigra.Admin.Components` | lib-owned | 13 component functions the gallery renders | `lib/sigra/admin/components.ex` |

### No New Installation Required

The `admin-design.spec.ts` spec imports the same helpers used by `admin-checkpoints.spec.ts`.
The gallery LiveView is pure Elixir with no new mix deps. The guard scripts are bash.
The monotonic guard needs only `git`, `grep`, `awk`, `sed` — all present on GitHub-hosted runners.

---

## Package Legitimacy Audit

No new packages installed in this phase.

---

## Architecture Patterns

### System Architecture Diagram

```
Developer browser (dev only)
        |
        | GET /admin/_design
        v
ExampleWeb.Router (if compile_env :dev_routes)
        |
        | pipe_through [:browser, :require_authenticated, :admin_global]
        | live_session with layout: {ExampleWeb.Layouts, :admin}
        v
ExampleWeb.Admin.DesignGalleryLive          [test/example/lib/example_web/live/admin/]
        |
        | import Sigra.Admin.Components
        | static literal assigns (no DB queries)
        v
All 13 component functions + MG-1..MG-N meta-component groups
        |
        | wrapped in board wrappers (id="board-{name}")
        v
{ExampleWeb.Layouts, :admin}    [real admin shell: topbar, theme toggle, breadcrumbs]


CI lane: admin-design-{chromium,mobile,dark}
        |
        | npx playwright test tests/admin-design.spec.ts --project=admin-design-{chromium,mobile,dark}
        v
admin-design.spec.ts
  - navigate to /admin/_design (pre-seeded admin session)
  - per board: assertNoAxeViolations(page, "axe:board-{name}")
  - per board: expect(page.locator("#board-{name}")).toHaveScreenshot("{board}-...png")
        |
        v
admin-design.spec.ts-snapshots/{board}-admin-design-{project}.png


CI gate: snapshot_drift_guard (extended)
        |
        | snapshot-canary-guard.sh (design invocation)
        |   --base $ref --allowlist snapshot-allowlist-design --canary notice
        |   SNAP_DIR=tests/admin-design.spec.ts-snapshots
        v
Fail if any design board PNG changed outside allowlist-design; canary "notice" is immutable


CI gate: quality_ledger_monotonic (new job)
        |
        | quality-ledger-monotonic.sh --base $BASE_REF
        |   git show $BASE:guides/reference/admin-quality-ledger.md vs working tree
        |   per-cell comparison of tier integers
        v
Fail if any row's tier integer decreased
```

### Recommended Project Structure (new files only)

```
test/example/lib/example_web/live/admin/
└── design_gallery_live.ex          # INFRA-01: example-only gallery LiveView

test/example/priv/playwright/
├── snapshot-allowlist-design       # INFRA-03: second empty allowlist (comments-only)
└── tests/
    ├── admin-design.spec.ts        # INFRA-02: board-snapshot + axe spec
    └── admin-design.spec.ts-snapshots/   # auto-created by Playwright on first run
        └── {board}-admin-design-{project}.png

guides/reference/
├── admin-quality-ledger.md         # INFRA-04: machine-parseable tier ledger
└── admin-fractal-scorecard.md      # INFRA-06: ratified rubric (D1-D11 + add-ons)

scripts/ci/
└── quality-ledger-monotonic.sh     # INFRA-05: merge-blocking tier monotonic guard

# Files modified (not created):
test/example/lib/example_web/router.ex          # add /admin/_design route (INFRA-01)
test/example/priv/playwright/playwright.config.ts  # add 3 admin-design-* projects (INFRA-02)
scripts/ci/snapshot-canary-guard.sh             # extend slug_of() for -admin-design-* (INFRA-03)
scripts/ci/snapshot-recapture-gate.sh           # learn design lane (INFRA-03)
.github/workflows/ci.yml                        # add quality_ledger_monotonic job (INFRA-05)
```

---

## Pattern 1: Dev-Route Gated Example-Only LiveView

**Source:** `test/example/lib/example_web/router.ex` lines 172-182 (verified)

The router uses an `if Application.compile_env(:example, :dev_routes)` block to gate example-only
routes. The block is evaluated at compile time, so these routes do not exist in `MIX_ENV=test` or
`MIX_ENV=prod` builds.

```elixir
# EXISTING pattern (router.ex lines 172-182):
if Application.compile_env(:example, :dev_routes) do
  scope "/dev" do
    pipe_through :browser
    forward "/mailbox", Plug.Swoosh.MailboxPreview
  end

  scope "/demo", ExampleWeb do
    pipe_through :browser
    live "/credentials", Demo.CredentialsLive
  end
end
```

**Gallery route to add** — inside the same `if` block, adding a new scope:

```elixir
# ADD inside the existing `if Application.compile_env(:example, :dev_routes)` block:
scope "/admin", ExampleWeb.Admin do
  pipe_through [:browser, :require_authenticated, :admin_global]

  live_session :admin_design_gallery,
    layout: {ExampleWeb.Layouts, :admin},
    on_mount: [
      {ExampleWeb.UserAuth, :ensure_authenticated},
      {Sigra.LiveView.AdminScope,
       [mode: :global, policy: Example.SigraAdminPolicy, login_path: "/users/log_in"]}
    ] do
    live "/_design", DesignGalleryLive, :index
  end
end
```

**CRITICAL:** The gallery is dev-gated, but it still passes through `admin_global` and
`Sigra.LiveView.AdminScope`. This means:
- It requires an authenticated admin session (same as the real admin)
- It gets `@admin_scope` assigned, which the gallery can use for breadcrumb copy if desired
- The `{ExampleWeb.Layouts, :admin}` shell renders correctly with real chrome

**Alternative simpler form:** The gallery does NOT call any Query module. If `admin_global` pipeline
overhead is undesirable for a pure audit tool, the gallery can instead use a simpler pipeline
(just `:browser, :require_authenticated`) and manually assign a fake `admin_scope` in `mount/3`.
However, the admin shell layout (`admin` layout component) may expect `@admin_scope` for topbar
rendering. **Recommended:** Keep `admin_global` + `AdminScope` on_mount to guarantee the shell
renders identically to production.

---

## Pattern 2: Example-Only LiveView Module Shape

**Source:** `test/example/lib/example_web/live/demo/credentials_live.ex` (verified)

```elixir
defmodule ExampleWeb.Demo.CredentialsLive do
  use ExampleWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Demo Credentials", credentials: [...])}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} wide>
      ...
      <span class="vt-status-pill" data-testid="demo-dev-only-badge">DEV ONLY</span>
      ...
    </Layouts.app>
    """
  end
end
```

**Gallery equivalent shape:**

```elixir
defmodule ExampleWeb.Admin.DesignGalleryLive do
  @moduledoc """
  Example-only design gallery for /admin/_design.

  Renders all 13 Sigra.Admin.Components + meta-component groups in every
  state, inside the real admin shell. Available in development only —
  the route is compile_env(:example, :dev_routes) gated.

  Data is all static literal assigns — no DB queries.
  """
  use ExampleWeb, :live_view
  import Sigra.Admin.Components

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Design Gallery")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <section class="sg-stack sg-stack--6">
      <header class="sg-page-header">
        <p class="sg-page-kicker">Design System</p>
        <h1 class="sg-page-title">Design Gallery</h1>
        <p class="sg-page-copy">
          Component and group state matrix for audit and regression checking.
          Available in development only.
        </p>
        <span data-testid="design-gallery-dev-only-badge">DEV ONLY</span>
      </header>

      <section class="sg-stack sg-stack--4">
        <h2 class="sg-section-heading">Components</h2>
        <div class="sg-stack sg-stack--6">
          <div id="board-notice" class="sg-card sg-stack sg-stack--4">
            <p class="sg-muted sg-text-sm">notice</p>
            ...all four notice tones...
          </div>
          ...12 more board wrappers...
        </div>
      </section>

      <section class="sg-stack sg-stack--4">
        <h2 class="sg-section-heading">Component Groups</h2>
        <div class="sg-stack sg-stack--6">
          <div id="board-mg-1" class="sg-card sg-stack sg-stack--4">
            ...
          </div>
          ...
        </div>
      </section>
    </section>
    """
  end
end
```

Note: the gallery module is `ExampleWeb.Admin.DesignGalleryLive` (not in `Sigra.Admin.Live.*`),
placing it squarely in the example namespace and making the "not in installer template" contract
easier to enforce.

---

## Pattern 3: Component Assigns Inventory

Full assign signatures from `lib/sigra/admin/components.ex` (verified, all lines cited):

| Component | Required attrs | Optional attrs | Slots | States to show in board |
|-----------|---------------|----------------|-------|------------------------|
| `stat_link` (line 44-57) | `href`, `label`, `value` (integer) | `class`, `rest` | — | one instance |
| `stat` (line 73-85) | `label`, `value` (integer) | `class`, `rest` | — | one instance |
| `task_card` (line 103-121) | `title`, `body`, `href`, `action` | `class`, `rest` | — | one instance |
| `summary_chip` (line 149-224) | `label`, `value` (integer) | `id`, `icon`, `value_unit`, `value_suffix`, `subvalue`, `help`, `tone`, `class`, `rest` | — | basic form (label+value only) + enhanced form (icon, value_unit, subvalue, help, tone variants: risk/warn/ok/info) |
| `applied_chip` (line 353-377) | `label`, `remove_href` | `class`, `rest` | — | one instance |
| `empty_state` (line 395-408) | `title` | `class`, `rest` | `inner_block` | one instance with body |
| `page_back` (line 424-435) | `return_to`, `label` | `class`, `rest` | — | one instance |
| `scope_ribbon` (line 452-460) | `copy` | `class`, `rest` | — | two instances: global + org scope copy |
| `notice` (line 487-506) | `inner_block` (required slot) | `tone` (nil/ok/warn/risk/info atom), `class`, `rest` | `inner_block` | tone: nil + ok + warn + risk + info (5 instances) |
| `notice_link` (line 519-538) | `href`, `inner_block` (required slot) | `class`, `rest` | `inner_block` | one combined board with notice (a notice containing a notice_link) |
| `field_help` (line 555-613) | `id`, `label`, `inner_block` (required slot) | `class`, `rest` | `inner_block` | one instance (panel hidden, JS-toggle not captured) |
| `skeleton` (line 627-639) | — | `class`, `rest` | — | one instance at representative width |
| `audit_row` (line 668-698) | `row` (map with: id, inserted_at, action, action_label, action_badge, actor_label, effective_user_label, actor_summary, outcome) | `show_detail` (bool, default false), `show_codes` (bool, default false), `class`, `rest` | — | show_detail: false + show_detail: true + show_codes: true + tone risk (outcome != "success") + tone info (action_badge present) |

**Key insight for `audit_row`:** The `row` map shape is exactly what `components_test.exs` uses for
`@compact_row`, `@impersonation_row`, and `@failure_row` (lines 97-131). The gallery should reuse
the same map shapes to stay honest.

**Key insight for `summary_chip`:** The branching between basic and enhanced form is controlled
by `summary_chip_enhanced?/1` (line 226), which checks for the presence of any optional field.
The gallery must show both branches explicitly.

**Key insight for `notice_link`:** Per the UI-SPEC, it can share the `board-notice` board (a
notice containing an embedded notice_link), or get its own `board-notice_link`. The combined
approach keeps the board count lower. Confirmed: `board-notice` is the designated canary (D-10,
UI-SPEC line 165).

---

## Pattern 4: MG-N Meta-Component Catalog (Candidate Mapping)

Derived from reading all 6 lib-owned admin pages. This is a candidate set for the planner to
ratify as the definitive MG-N catalog.

| Group | Name | Components Composed | Page Sources | Region Description |
|-------|------|--------------------|--------------|--------------------|
| MG-1 | Metric / Summary Strip | `summary_chip` × N in `dl.sg-metric-grid` | `IndexLive` (lines 87-124), `UsersIndexLive` (lines 92-149) | `<dl class="sg-metric-grid">` with 3-6 summary chips in a responsive grid |
| MG-2 | Filter Panel + Applied-chip Row | `applied_chip` × N + Clear-all `<a>` inside `sg-cluster--start` | `UsersIndexLive` (lines 236-243), `AuditIndexLive` (lines 139-146) | `sg-filter-panel sg-stack` form + chip row below; "Clear all" link at end |
| MG-3 | Task-card Grid | `task_card` × 2-3 in `div.sg-grid--2` or `.sg-grid--3` | `IndexLive` (lines 56-75), `OrganizationLive` (lines 74-90) | `<div class="sg-grid sg-grid--{2,3}">` with 2-3 task cards |
| MG-4 | Alarm Notice Band | `notice` (risk or ok tone) + optional `notice_link` | `IndexLive` (lines 47-55), `OrganizationLive` (lines 62-72) | A single `notice` that appears at the top of overview pages; tone is data-driven |
| MG-5 | Audit Feed + Pagination | `audit_row` × N in `.sg-show-mobile` + desktop `sg-table` + pagination `<nav>` | `AuditIndexLive` (lines 148-236), `AuditUserLive` | The desktop-table / mobile-card swap pattern with a cursor-based pagination nav |
| MG-6 | Org Member Roster | `skeleton` (loading) + `sg-list-row` member cards with `sg-status-pill` tone badges | `OrganizationLive` (lines 91-112) | `sg-card sg-stack sg-stack--3` with member list and role/status pill cluster |

**Notes for the planner:**
- MG-1 through MG-5 are the highest-value groups (most reused across pages).
- MG-6 is org-specific and appears only on `OrganizationLive`.
- The task description says "MG-1..MG-N" — the exact upper bound is the planner's call. Starting
  with MG-1..MG-6 is defensible; more groups can be added in phases 186-191 as the gallery evolves.
- Each MG group board in the gallery should mirror the real page markup structure (same wrapper
  classes), using static literal data for assigns.

---

## Pattern 5: Playwright Project Clone (admin-design-*)

**Source:** `playwright.config.ts` lines 107-138 (verified)

Exact diff to add to `playwright.config.ts`:

```typescript
// Add a new const before the projects array:
const ADMIN_DESIGN_SPEC = /admin-design\.spec\.ts/;

// Inside projects array — add testIgnore to existing chromium and mobile projects:
// chromium (line 84): add ADMIN_DESIGN_SPEC to testIgnore
// mobile (line 93): add ADMIN_DESIGN_SPEC to testIgnore

// Add three new projects at end of projects array:
{
  name: 'admin-design-chromium',
  testMatch: ADMIN_DESIGN_SPEC,
  use: {
    ...devices['Desktop Chrome'],
    video: checkpointVideo,
  },
},
{
  name: 'admin-design-mobile',
  testMatch: ADMIN_DESIGN_SPEC,
  use: {
    ...devices['iPhone 13'],
    video: checkpointVideo,
  },
},
{
  name: 'admin-design-dark',
  testMatch: ADMIN_DESIGN_SPEC,
  use: {
    ...devices['Desktop Chrome'],
    colorScheme: 'dark',
    video: checkpointVideo,
  },
},
```

**Snapshot path resolution:** The existing `pathTemplate` at playwright.config.ts lines 60-61 is:

```typescript
pathTemplate: '{testDir}/{testFilePath}-snapshots/{arg}{-projectName}{ext}'
```

With `testFilePath = "tests/admin-design.spec.ts"`, the boards land at:

```
tests/admin-design.spec.ts-snapshots/board-notice-admin-design-chromium.png
tests/admin-design.spec.ts-snapshots/board-notice-admin-design-mobile.png
tests/admin-design.spec.ts-snapshots/board-notice-admin-design-dark.png
```

The `{arg}` is the first positional arg to `toHaveScreenshot(...)`, e.g. `"board-notice.png"` →
the template inserts `{-projectName}` before `{ext}`, yielding `board-notice-admin-design-chromium.png`.

---

## Pattern 6: Board-Snapshot + Axe Spec Shape

**Source:** `admin-checkpoints.spec.ts` lines 114-148 (verified)

```typescript
// Source: test/example/priv/playwright/tests/admin-checkpoints.spec.ts
// Lines 114-126: assertNoAxeViolations helper (copy verbatim):
async function assertNoAxeViolations(page: Page, label: string) {
  const { violations } = await new AxeBuilder({ page })
    .withTags(['wcag2a', 'wcag2aa'])
    .analyze();
  const detail =
    violations.length === 0 ? '' : JSON.stringify(violations).slice(0, 2000);
  expect(violations, `${label}: axe violations\n${detail}`).toHaveLength(0);
}

// Lines 137-148: assertCheckpointScreenshot helper — adapt for gallery:
async function assertBoardScreenshot(page: Page, testInfo: TestInfo, boardId: string) {
  await assertNoAxeViolations(page, `axe:${boardId}`);
  const dark = testInfo.project.name.includes('dark');
  const mobile = testInfo.project.name.includes('mobile');
  const ci = process.env.CI === 'true';
  const locator = page.locator(`#${boardId}`);
  await expect(locator).toHaveScreenshot(`${boardId}.png`, {
    // fullPage not applicable to element-scoped capture (element bounds)
    maxDiffPixels: ci ? 200_000 : dark ? 75_000 : mobile ? 45_000 : 30_000,
    maxDiffPixelRatio: ci ? 0.22 : dark ? 0.1 : mobile ? 0.08 : 0.06,
  });
}
```

**Key difference from checkpoints:** The checkpoints spec calls `expect(page).toHaveScreenshot()`
(full-page scoped). The design spec calls `expect(page.locator("#board-{name}")).toHaveScreenshot()`
(element-scoped). This is what produces the board-level composite PNG rather than a full-page capture.

**Gallery spec structure:**

```typescript
// tests/admin-design.spec.ts
import AxeBuilder from '@axe-core/playwright';
import { test, expect, type Page, type TestInfo } from '@playwright/test';

// ... assertNoAxeViolations (copy from checkpoints spec) ...
// ... assertBoardScreenshot helper using element-scoped locator ...

// Board IDs — one per component, one per MG group
const COMPONENT_BOARDS = [
  'board-stat', 'board-stat_link', 'board-task_card', 'board-summary_chip',
  'board-applied_chip', 'board-empty_state', 'board-page_back', 'board-scope_ribbon',
  'board-notice',      // <-- designated canary (D-10)
  'board-notice_link', // can be combined with board-notice board or separate
  'board-field_help', 'board-skeleton', 'board-audit_row',
];
const GROUP_BOARDS = ['board-mg-1', 'board-mg-2', 'board-mg-3', 'board-mg-4', 'board-mg-5'];

test.describe('Design gallery board snapshots', () => {
  test.beforeEach(async ({ page }) => {
    // Navigate to /admin/_design — requires an admin session
    // Seed approach: either use a fixed-credentials admin persona from the
    // demo seeds (e.g., platform-admin+... prefix) or do a quick register+login.
    // The gallery is static (no DB queries), so the session just needs to pass
    // the admin_global pipeline check.
    await page.goto('/admin/_design');
    await page.waitForSelector('[data-phx-session].phx-connected', { state: 'attached' });
  });

  for (const boardId of [...COMPONENT_BOARDS, ...GROUP_BOARDS]) {
    test(`board: ${boardId}`, async ({ page }, testInfo) => {
      await assertBoardScreenshot(page, testInfo, boardId);
    });
  }
});
```

**Authentication in the gallery spec:** The gallery still sits behind `admin_global`, so the spec
needs an admin session. The cleanest approach mirrors the checkpoints spec (which registers a
`platform-admin+...` email on the fly). The gallery spec should do the same: register a fresh
admin user in `test.beforeAll` (or `beforeEach`), so it is fully self-contained and repeatable.

---

## Pattern 7: Snapshot Canary Guard Extension

**Source:** `scripts/ci/snapshot-canary-guard.sh` lines 53-55 (verified)

```bash
# CURRENT slug_of() (line 53-55):
slug_of() {
  basename "$1" | sed -E 's/-admin-checkpoints-(chromium|mobile|dark)\.png$//'
}
```

**Design-lane extension — two approaches:**

**Option A: Second invocation (simpler, no refactor risk)**

Keep `slug_of()` for the checkpoints lane. In CI, invoke the guard a second time with overridden
env vars for the design lane:

```bash
# In ci.yml snapshot_drift_guard step:
bash scripts/ci/snapshot-canary-guard.sh --base "${{ steps.base.outputs.ref }}"
SNAP_DIR="test/example/priv/playwright/tests/admin-design.spec.ts-snapshots" \
bash scripts/ci/snapshot-canary-guard.sh \
  --base "${{ steps.base.outputs.ref }}" \
  --allowlist test/example/priv/playwright/snapshot-allowlist-design \
  --canary board-notice
```

**Option B: Generalize slug_of() (one-sed update)**

Replace the single sed pattern with two alternating patterns:

```bash
slug_of() {
  basename "$1" | sed -E \
    's/-admin-checkpoints-(chromium|mobile|dark)\.png$//;
     s/-admin-design-(chromium|mobile|dark)\.png$//'
}
```

This makes `slug_of()` handle both lane suffixes. Then the design invocation can use the same
function with `SNAP_DIR`/`--allowlist`/`--canary` overrides.

**Recommendation:** Option A (second invocation). It is safer because it does not risk breaking
the checkpoints guard if the sed alternation has an order-of-operations issue. The context shows
the guard already accepts all needed flag overrides.

**Design-lane default values for second invocation:**

```bash
SNAP_DIR=test/example/priv/playwright/tests/admin-design.spec.ts-snapshots
ALLOWLIST=test/example/priv/playwright/snapshot-allowlist-design
CANARY=board-notice     # designated canary (D-10, UI-SPEC line 165)
```

---

## Pattern 8: Snapshot Recapture Gate Extension

**Source:** `scripts/ci/snapshot-recapture-gate.sh` (verified, full file read)

The recapture gate currently knows only the checkpoints lane (lines 31-35). It must also run the
design lane. The simplest extension adds a second Playwright run + canary guard invocation:

```bash
# After step (a) and step (b) for checkpoints, add:
echo "snapshot-recapture-gate: (a2) compare-mode admin design gallery across 3 projects"
( cd "$PW" && CI=true SIGRA_EXAMPLE_URL="$SIGRA_EXAMPLE_URL" \
    npx playwright test tests/admin-design.spec.ts \
      --project=admin-design-chromium \
      --project=admin-design-mobile \
      --project=admin-design-dark )

echo "snapshot-recapture-gate: (b2) drift/canary guard — design lane"
SNAP_DIR="${PW}/tests/admin-design.spec.ts-snapshots" \
bash "${ROOT}/scripts/ci/snapshot-canary-guard.sh" \
  --base HEAD \
  --allowlist "${PW}/snapshot-allowlist-design" \
  --canary board-notice \
  --require-all "${ALLOW_ARGS[@]}"
```

This keeps the gate's "all-green == approval" model intact for both lanes.

---

## Pattern 9: Quality Ledger Machine-Parseable Format

The ledger must be a Markdown table where the tier column contains only `0`, `1`, or `2` as plain
integers with no surrounding whitespace or extra characters. This allows a shell one-liner to
extract per-cell tiers reliably without full Markdown parsing.

**Recommended table format:**

```markdown
| item | level | tier | evidence |
|------|-------|------|----------|
| stat | L1 | 1 | [components_test.exs](test/sigra/admin/components_test.exs) |
| stat_link | L1 | 1 | [components_test.exs](test/sigra/admin/components_test.exs) |
| task_card | L1 | 1 | [components_test.exs](test/sigra/admin/components_test.exs) |
| summary_chip | L1 | 1 | [components_test.exs](test/sigra/admin/components_test.exs) |
| applied_chip | L1 | 1 | [components_test.exs](test/sigra/admin/components_test.exs) |
| empty_state | L1 | 1 | [components_test.exs](test/sigra/admin/components_test.exs) |
| page_back | L1 | 1 | [components_test.exs](test/sigra/admin/components_test.exs) |
| scope_ribbon | L1 | 1 | [components_test.exs](test/sigra/admin/components_test.exs) |
| notice | L1 | 1 | [components_test.exs](test/sigra/admin/components_test.exs) |
| notice_link | L1 | 1 | [components_test.exs](test/sigra/admin/components_test.exs) |
| field_help | L1 | 1 | [components_test.exs](test/sigra/admin/components_test.exs) |
| skeleton | L1 | 1 | [components_test.exs](test/sigra/admin/components_test.exs) |
| audit_row | L1 | 1 | [components_test.exs](test/sigra/admin/components_test.exs) |
| mg-1-metric-strip | L2 | 1 | [admin-design.spec.ts board-mg-1](#) |
| mg-2-filter-panel | L2 | 1 | [admin-design.spec.ts board-mg-2](#) |
| mg-3-task-grid | L2 | 1 | [admin-design.spec.ts board-mg-3](#) |
| mg-4-alarm-notice | L2 | 1 | [admin-design.spec.ts board-mg-4](#) |
| mg-5-audit-feed | L2 | 1 | [admin-design.spec.ts board-mg-5](#) |
| index-live | L3 | 1 | [admin-checkpoints: global-overview](#) |
| organization-live | L3 | 1 | [admin-checkpoints: org-overview](#) |
| users-index-live | L3 | 1 | [admin-checkpoints: global-user-index](#) |
| user-show-live | L3 | 1 | [admin-checkpoints: user-detail](#) |
| audit-index-live | L3 | 1 | [admin-checkpoints: audit-explorer](#) |
| audit-user-live | L3 | 1 | [admin-checkpoints: user-audit](#) |
```

**Initial tier values:** All items start at tier `1` (Ratified) because they passed the v1.34
contract. This is defensible: the gallery + monotonic guard start from a floor of 1; phases 186-192
move cells to 2; no cell should ever go to 0 on a green main branch.

**Machine-parseable extraction:** The tier column is column 3 (1-indexed). Given the fixed-width
table format, a per-row grep + awk or sed can extract item → tier pairs:

```bash
# Extract item:tier pairs from ledger (skip header/separator lines):
grep -E '^\| [a-z]' "$LEDGER_FILE" | awk -F'|' '{
  item=gensub(/^ +| +$/, "", "g", $2)
  tier=gensub(/^ +| +$/, "", "g", $4)
  print item ":" tier
}'
```

---

## Pattern 10: Monotonic Guard Script

**Source convention:** `scripts/ci/snapshot-canary-guard.sh` lines 1-116 (verified)

```bash
#!/usr/bin/env bash
# Phase 185 (AUDIT-INFRA): merge-blocking quality ledger monotonic guard.
# Fails CI if any tier cell in guides/reference/admin-quality-ledger.md
# decreased compared to the base ref.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LEDGER="guides/reference/admin-quality-ledger.md"
BASE="HEAD"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --base) BASE="$2"; shift 2;;
    *) echo "quality-ledger-monotonic: FAIL: unknown arg: $1" >&2; exit 2;;
  esac
done

fail() {
  echo "quality-ledger-monotonic: FAIL: $*" >&2
  exit 1
}

# Extract item:tier pairs from a ledger file (stdin or process substitution)
extract_tiers() {
  grep -E '^\| [a-z]' | awk -F'|' '{
    item=gensub(/^ +| +$/, "", "g", $2)
    tier=gensub(/^ +| +$/, "", "g", $4)
    if (tier ~ /^[012]$/) print item ":" tier
  }'
}

# Read base tiers
declare -A BASE_TIERS=()
while IFS=: read -r item tier; do
  BASE_TIERS["$item"]="$tier"
done < <(git -C "$ROOT" show "${BASE}:${LEDGER}" 2>/dev/null | extract_tiers)

if [[ ${#BASE_TIERS[@]} -eq 0 ]]; then
  echo "quality-ledger-monotonic: INFO: no base tiers found at ${BASE}:${LEDGER} — skipping comparison (initial commit)"
  exit 0
fi

# Read working-tree tiers
declare -A HEAD_TIERS=()
while IFS=: read -r item tier; do
  HEAD_TIERS["$item"]="$tier"
done < <(extract_tiers < "${ROOT}/${LEDGER}")

violations=0
for item in "${!HEAD_TIERS[@]}"; do
  head_tier="${HEAD_TIERS[$item]}"
  base_tier="${BASE_TIERS[$item]:-}"
  if [[ -n "$base_tier" && "$head_tier" -lt "$base_tier" ]]; then
    echo "quality-ledger-monotonic: FAIL: tier decreased for '${item}': ${base_tier} → ${head_tier}" >&2
    violations=1
  fi
done

if [[ "$violations" -ne 0 ]]; then
  exit 1
fi

echo "quality-ledger-monotonic: PASS (${#HEAD_TIERS[@]} cells checked vs ${BASE})"
```

**Edge cases handled:**
- Initial commit (no base ledger): skip comparison, exit 0
- New items in HEAD not in BASE: allowed (forward-only addition)
- Items removed from HEAD that were in BASE: not checked (removal is a separate concern)
- The `gensub` requires GNU awk (gawk), which is standard on GitHub-hosted Ubuntu runners

---

## Pattern 11: CI Wiring — quality_ledger_monotonic Job

**Source:** `.github/workflows/ci.yml` lines 1095-1166 (verified)

**New job to add** (modeled on `snapshot_drift_guard` at lines 1095-1114):

```yaml
quality_ledger_monotonic:
  name: Quality ledger monotonic guard
  runs-on: ubuntu-latest
  steps:
    - uses: actions/checkout@df4cb1c069e1874edd31b4311f1884172cec0e10  # v6.0.3
      with:
        fetch-depth: 0
    - name: Resolve base ref
      id: base
      shell: bash
      run: |
        set -euo pipefail
        if [ "${{ github.event_name }}" = "pull_request" ]; then
          git fetch origin "${{ github.base_ref }}" --depth=1
          echo "ref=origin/${{ github.base_ref }}" >> "$GITHUB_OUTPUT"
        else
          echo "ref=HEAD~1" >> "$GITHUB_OUTPUT"
        fi
    - name: Run quality ledger monotonic guard
      run: bash scripts/ci/quality-ledger-monotonic.sh --base "${{ steps.base.outputs.ref }}"
```

**ci-gate update** (lines 1116-1166): Add `quality_ledger_monotonic` to the `needs:` list and the
loop's lane iteration. Exact diff:

```yaml
# ci-gate needs: (add one line):
- quality_ledger_monotonic

# ci-gate env block (add one):
QUALITY_LEDGER_MONOTONIC: ${{ needs.quality_ledger_monotonic.result }}

# ci-gate loop (add one line):
QUALITY_LEDGER_MONOTONIC \
```

**Design board CI run:** The Playwright design-lane boards run in the same
`example_playwright_smoke` job. A new step is added between the checkpoints run and the non-admin
run:

```yaml
- name: Run design gallery boards (chromium, mobile, dark)
  working-directory: test/example/priv/playwright
  env:
    CI: "true"
    SIGRA_EXAMPLE_URL: "http://localhost:4000"
  run: |
    npx playwright test \
      tests/admin-design.spec.ts \
      --project=admin-design-chromium \
      --project=admin-design-mobile \
      --project=admin-design-dark
```

And the `snapshot_drift_guard` job gains a second guard invocation for the design lane:

```yaml
- name: Run snapshot canary / drift guard — design lane
  run: |
    SNAP_DIR="test/example/priv/playwright/tests/admin-design.spec.ts-snapshots" \
    bash scripts/ci/snapshot-canary-guard.sh \
      --base "${{ steps.base.outputs.ref }}" \
      --allowlist test/example/priv/playwright/snapshot-allowlist-design \
      --canary board-notice
```

---

## Pattern 12: D-04 Contract Guard — No Gallery in Installer Template

**Mechanism:** A lightweight ExUnit test in the existing test suite asserts that no path under
`priv/templates/sigra.install/` contains "design" or "_design" in its filename.

```elixir
# test/sigra/install/design_gallery_isolation_test.exs
defmodule Sigra.Install.DesignGalleryIsolationTest do
  use ExUnit.Case, async: true

  @installer_template_root "priv/templates/sigra.install"

  test "no design gallery artifact exists in installer template tree (D-04)" do
    offenders =
      Path.wildcard("#{@installer_template_root}/**/*")
      |> Enum.filter(&String.contains?(&1, "design"))

    assert offenders == [],
           "Design gallery artifacts found in installer template tree (D-04 violation):\n" <>
             Enum.join(offenders, "\n")
  end
end
```

This test runs with `mix test` (no special tags, no Postgres required). It is fast (pure filesystem
glob), so it does not pollute the test suite with slow I/O. If a future developer accidentally
generates a `design_gallery_live.ex` into the installer template tree, this test fails immediately.

**Alternative:** A CI bash check:

```bash
# In a ci.yml step or a new scripts/ci/ script:
if find priv/templates/sigra.install -name "*design*" | grep -q .; then
  echo "FAIL: design gallery artifact found in installer template tree (D-04)" >&2
  exit 1
fi
```

**Recommendation:** ExUnit is preferred because it runs in `mix test` locally and in the
`library_tests` CI lane, making violations visible during development rather than only in CI.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| WCAG accessibility assertions | Custom DOM walker | `@axe-core/playwright` (already wired) | Handles shadow DOM, ARIA tree, all WCAG rules correctly |
| Visual regression per-state | 13×N individual PNGs | Element-scoped board PNG (one per component/group) | Bounds baseline count to ~50; diffs are human-meaningful |
| Tier monotonic comparison | String diff of whole ledger | Per-cell integer extraction | Benign edits (evidence links, whitespace) would trip a string diff; only tier regression matters |
| Slug-stripping in canary guard | New guard script | Extend `slug_of()` in existing guard | The guard already has all needed flag plumbing; one sed alternation is sufficient |

---

## Common Pitfalls

### Pitfall 1: Gallery Calling Query Modules (Data Drift)

**What goes wrong:** Developer adds `Query.summary_stats(...)` call to make the gallery look
"real". This introduces a DB dependency, makes the gallery non-deterministic (data changes break
visual baselines), and couples the gallery to Postgres.

**Why it happens:** The real admin pages all call Query modules; copy-paste temptation is high.

**How to avoid:** All assigns in `mount/3` must be static literal data. Write them as module
attributes or inline maps. The gallery must not import `Sigra.Admin.Users.Query` or any other
context module.

**Warning signs:** Any `import` or `alias` of a `Sigra.Admin.*` module other than
`Sigra.Admin.Components` in the gallery LiveView.

---

### Pitfall 2: Gallery Leaking into Installer Template (D-04 Violation)

**What goes wrong:** Developer places the gallery at `lib/sigra/admin/live/design_gallery_live.ex`
instead of `test/example/lib/example_web/live/admin/design_gallery_live.ex`. The installer
generates it into host apps.

**Why it happens:** The `lib/sigra/admin/live/` directory is where all other admin LiveViews live;
it is a natural instinct.

**How to avoid:** Gallery module namespace is `ExampleWeb.Admin.DesignGalleryLive`, not
`Sigra.Admin.Live.*`. The ExUnit contract guard catches this structurally.

**Warning signs:** Any file named `*design*` in `priv/templates/sigra.install/`.

---

### Pitfall 3: Admin Shell Mismatch in Gallery

**What goes wrong:** Gallery uses `Layouts.app` (the non-admin app shell) instead of the admin
shell. Dark mode, topbar, breadcrumbs, and `sg-*` token layer are all wrong. The dark project
snapshot uses `prefers-color-scheme: dark` which triggers `:root[data-sg-admin-theme="dark"]` — 
this only works when the admin shell sets the `data-sg-admin-theme` attribute.

**Why it happens:** The non-admin `Layouts.app` is what most example LiveViews use
(e.g., `CredentialsLive`). The admin shell is set at the `live_session` level via
`layout: {ExampleWeb.Layouts, :admin}` in the router.

**How to avoid:** The gallery's router entry MUST be inside a scope with
`layout: {ExampleWeb.Layouts, :admin}` and the `Sigra.LiveView.AdminScope` on_mount. Do not
override the layout in the gallery `render/1` itself.

**Warning signs:** Gallery renders with `<Layouts.app ...>` in its `~H"""` template.

---

### Pitfall 4: `notice_link` Used Outside a `notice` Slot

**What goes wrong:** Gallery renders `<.notice_link href="...">text</.notice_link>` as a
standalone element in a board. It renders visually but produces a meaningless audit instrument
because `notice_link` is designed to be used inside `notice` content.

**Why it happens:** It is easier to render `notice_link` alone than to compose it inside a
notice.

**How to avoid:** The `board-notice` board should include a fifth notice variant (e.g., `tone: risk`)
that embeds a `notice_link`. This is the canonical usage. Alternatively a separate
`board-notice_link` board can show a notice wrapping a notice_link.

---

### Pitfall 5: Snapshot Naming Collision Between Lanes

**What goes wrong:** If `admin-design.spec.ts` uses the same snapshot argument string as
`admin-checkpoints.spec.ts` (e.g., `"global-overview.png"`), they produce PNGs in different
directories but the same filename. The canary guard's `slug_of()` strips the project suffix,
so `global-overview` as a slug in the checkpoints allowlist would accidentally also match a design
lane file.

**Why it happens:** Temptation to reuse familiar slug names.

**How to avoid:** Design lane board names use `board-` prefix (e.g., `board-notice.png`,
`board-audit_row.png`). These never collide with checkpoints slugs (which use page names like
`global-overview`, `user-detail`). The `board-` prefix is enforced by the `id="board-{name}"`
stable-id contract.

---

### Pitfall 6: Monotonic Guard Against Wrong Base on First Run

**What goes wrong:** On the initial commit that introduces the ledger (this phase), the
`quality_ledger_monotonic` job runs with `--base HEAD~1`. `HEAD~1` does not have the ledger
file, so `git show HEAD~1:guides/reference/admin-quality-ledger.md` exits non-zero.

**Why it happens:** The guard is designed to compare against base, but the file does not exist there.

**How to avoid:** The guard script handles this with an explicit "no base tiers found → skip"
exit 0 path (shown in Pattern 10). `git show` exits non-zero if the file does not exist; the guard
catches this via `2>/dev/null` + empty array check.

---

## Code Examples

### Gallery LiveView — board-notice (Canary Board, D-10)

```heex
<%!-- board-notice: designated canary board — must be stable and present on every render --%>
<div id="board-notice" class="sg-card sg-stack sg-stack--4">
  <p class="sg-muted sg-text-sm">notice</p>
  <div class="sg-stack sg-stack--3">
    <span class="sg-muted sg-text-xs">tone: nil (neutral)</span>
    <.notice>
      System maintenance scheduled for Sunday 02:00 UTC.
    </.notice>

    <span class="sg-muted sg-text-xs">tone: ok</span>
    <.notice tone={:ok}>
      All clear — no accounts need review.
    </.notice>

    <span class="sg-muted sg-text-xs">tone: warn</span>
    <.notice tone={:warn}>
      Password reset email delivery delayed.
    </.notice>

    <span class="sg-muted sg-text-xs">tone: risk</span>
    <.notice tone={:risk}>
      3 accounts need review —
      <.notice_link href="/admin/users?needs_review=true">Review accounts</.notice_link>
    </.notice>

    <span class="sg-muted sg-text-xs">tone: info</span>
    <.notice tone={:info}>
      Impersonation session active. End it before navigating away.
    </.notice>
  </div>
</div>
```

### Gallery LiveView — board-audit_row

```heex
<%!-- The row maps mirror @compact_row / @failure_row / @impersonation_row from components_test.exs --%>
<div id="board-audit_row" class="sg-card sg-stack sg-stack--4">
  <p class="sg-muted sg-text-sm">audit_row</p>
  <div class="sg-stack sg-stack--3">
    <span class="sg-muted sg-text-xs">show_detail: false (compact)</span>
    <.audit_row row={%{
      id: "uuid-1234", inserted_at: ~N[2026-01-15 10:30:00],
      action: "auth.login.success", action_label: "Login", action_badge: nil,
      actor_label: "alice@example.test", effective_user_label: "alice@example.test",
      actor_summary: "alice@example.test", outcome: "success"
    }} />

    <span class="sg-muted sg-text-xs">show_detail: true, show_codes: true (explorer)</span>
    <.audit_row row={%{
      id: "uuid-5678", inserted_at: ~N[2026-01-15 11:00:00],
      action: "admin.impersonation.start", action_label: "Impersonation started",
      action_badge: "Impersonation",
      actor_label: "admin@example.test", effective_user_label: "alice@example.test",
      actor_summary: "admin@example.test acting as alice@example.test", outcome: "success"
    }} show_detail show_codes />

    <span class="sg-muted sg-text-xs">tone: risk (non-success outcome)</span>
    <.audit_row row={%{
      id: "uuid-9999", inserted_at: ~N[2026-01-15 09:00:00],
      action: "auth.login.failure", action_label: "Login failed", action_badge: nil,
      actor_label: "unknown@example.test", effective_user_label: "unknown@example.test",
      actor_summary: "unknown@example.test", outcome: "failure"
    }} />
  </div>
</div>
```

### Ledger Tier Extraction One-liner (for manual verification)

```bash
# Verify tier extraction from working-tree ledger:
grep -E '^\| [a-z]' guides/reference/admin-quality-ledger.md \
  | awk -F'|' '{gsub(/ /, "", $2); gsub(/ /, "", $4); print $2 ":" $4}'
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Manual "human eyeballs git status" before baseline re-record | `snapshot-canary-guard.sh` empty-allowlist discipline | Phase 158 | Re-record is now machine-verifiable; no human review step |
| Whole-page Playwright screenshots | Element-scoped `toHaveScreenshot(locator, ...)` | Phase 35 (checkpoints) | Board-level diffs are human-meaningful; per-component regression surfaces |
| No quality tracking | Committed tier ledger + monotonic guard | Phase 185 (this phase) | Tier regression is structurally un-mergeable |

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Gallery route should reuse `admin_global` pipeline + `Sigra.LiveView.AdminScope` on_mount (same as real admin pages) | Pattern 1 | If admin shell requires `@admin_scope` assigns and the route does not set them, the shell renders broken; mitigated by using the same pipeline as existing admin live_session |
| A2 | `gawk`/GNU awk `gensub()` is available on GitHub-hosted ubuntu-latest runners | Pattern 10 | If only POSIX awk is available, the `gensub()` call fails; can be replaced with two `gsub()` calls |
| A3 | The `notice_link` board is best served by combining it with the `board-notice` board rather than a separate `board-notice_link` | Pattern 3, UI-SPEC | If Playwright element-scoped capture of `board-notice` becomes too tall for mobile viewport, a separate `board-notice_link` board may be needed |

---

## Open Questions

1. **Gallery admin session seeding**
   - What we know: `admin-checkpoints.spec.ts` seeds a fresh `platform-admin+...` user per test run
   - What's unclear: The gallery spec could do the same, or it could use a pre-existing demo persona seed. The demo seed approach is faster but introduces a fixture dependency.
   - Recommendation: Mirror the checkpoints approach — register a fresh admin in `test.beforeAll`. The gallery has no DB queries, so once the session is established, the page is instant.

2. **`notice_link` board placement**
   - What we know: UI-SPEC says combined or separate board is acceptable
   - What's unclear: Playwright element-scoped capture of a board that contains a `<a>` inside a `<div data-tone="risk">` may need explicit scroll-into-view
   - Recommendation: Keep `notice_link` inside `board-notice` (combined). If the board height causes capture issues on mobile, separate it.

3. **MG-N group count final decision**
   - What we know: Research surfaces MG-1..MG-6 candidates
   - What's unclear: Whether MG-6 (Org Member Roster) warrants its own group or is a one-page-only composition
   - Recommendation: Start with MG-1..MG-5 (clearly reused across pages). Add MG-6 if the planner judges it worth a separate board. The ledger can be extended without breaking the monotonic guard.

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| `@axe-core/playwright` | INFRA-02 axe gate | Already installed | See `package.json` | — |
| `@playwright/test` | INFRA-02 board snapshots | Already installed | See `package.json` | — |
| `git` | INFRA-05 monotonic guard, INFRA-03 canary guard | Available on CI runners | System git | — |
| `gawk` (GNU awk) | INFRA-05 `gensub()` in monotonic guard | Available on ubuntu-latest | Standard | Use POSIX `gsub()` fallback if needed |
| PostgreSQL | Gallery LiveView auth (admin session) | Available per CLAUDE.md | 16.x (docker) | — |

No missing dependencies.

---

## Validation Architecture

> Nyquist requirement: for each INFRA-01..06, what test/command/CI gate proves the instrument
> actually functions — not just that files exist.

### Test Framework

| Property | Value |
|----------|-------|
| Framework | ExUnit (`mix test`) + Playwright (`npx playwright test`) |
| Config file | `test/example/priv/playwright/playwright.config.ts` |
| Quick run command | `mix test test/sigra/install/design_gallery_isolation_test.exs` (D-04 guard) |
| Full suite command | `mix test && (cd test/example/priv/playwright && npx playwright test tests/admin-design.spec.ts)` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| INFRA-01 (gallery route) | Gallery route exists and renders under admin shell with all 13 boards | Playwright smoke | `npx playwright test tests/admin-design.spec.ts --project=admin-design-chromium` | Wave 0 gap |
| INFRA-01 (compile-out) | Gallery compiles out in `MIX_ENV=test` (no route defined) | ExUnit (router test or mix compile check) | `MIX_ENV=test mix compile --no-deps-check` + assert `/admin/_design` is absent | Wave 0 gap |
| INFRA-01 (D-04 contract) | No `*design*` file in `priv/templates/sigra.install/` | ExUnit | `mix test test/sigra/install/design_gallery_isolation_test.exs` | Wave 0 gap |
| INFRA-02 (board PNGs) | 13 component boards + MG-N group boards captured as element-scoped PNGs across 3 projects | Playwright visual regression | `npx playwright test tests/admin-design.spec.ts --project=admin-design-{chromium,mobile,dark}` | Wave 0 gap |
| INFRA-02 (axe) | 0 axe WCAG2A+AA violations on each board | Playwright axe (`assertNoAxeViolations`) | Same command — axe runs inside each `assertBoardScreenshot` call | Wave 0 gap |
| INFRA-03 (allowlist empty) | `snapshot-allowlist-design` exists and has no non-comment content | Bash | `grep -v '^#' test/example/priv/playwright/snapshot-allowlist-design | grep -q . && exit 1 || exit 0` | Wave 0 gap |
| INFRA-03 (canary guard recognizes design slugs) | `snapshot-canary-guard.sh` exits 0 when no design PNG changed; exits 1 when canary `board-notice` changed | Bash unit test (script with fixture PNGs) | `SNAP_DIR=<fixture-dir> bash scripts/ci/snapshot-canary-guard.sh --base HEAD --allowlist /dev/null --canary board-notice` | Wave 0 gap |
| INFRA-03 (canary board stability) | The `board-notice` board PNG does not change between identical runs | Playwright canary guard | `SNAP_DIR=tests/admin-design.spec.ts-snapshots bash scripts/ci/snapshot-canary-guard.sh --base HEAD --allowlist snapshot-allowlist-design --canary board-notice` | Wave 0 gap (after initial baseline capture) |
| INFRA-04 (ledger exists + parseable) | `admin-quality-ledger.md` exists and all tier cells are 0/1/2 integers | Bash | `grep -E '^\| [a-z]' guides/reference/admin-quality-ledger.md | awk -F'|' '{tier=gensub(/ /,"","g",$4); if (tier !~ /^[012]$/) exit 1}'` | Wave 0 gap |
| INFRA-04 (initial tiers = 1) | All tier cells are 1 on first commit (Ratified baseline) | Bash | `grep -E '^\| [a-z]' guides/reference/admin-quality-ledger.md | awk -F'|' '{tier=gensub(/ /,"","g",$4); if (tier != "1") exit 1}'` | Wave 0 gap |
| INFRA-05 (monotonic guard passes on no-op) | Guard exits 0 when tiers are identical to base | Bash (synthetic fixture) | Create a temp git branch with an identical ledger; run `bash scripts/ci/quality-ledger-monotonic.sh --base <branch>` | Wave 0 gap |
| INFRA-05 (monotonic guard fails on tier decrease) | Guard exits 1 when any tier decreased | Bash (synthetic fixture) | Create a temp branch with a tier set to `2`; lower it to `1` in working tree; run guard | Wave 0 gap |
| INFRA-05 (CI job wired) | `quality_ledger_monotonic` appears in `ci-gate` `needs:` | grep | `grep quality_ledger_monotonic .github/workflows/ci.yml` | Wave 0 gap |
| INFRA-06 (rubric exists + structure) | `admin-fractal-scorecard.md` exists and contains D1-D11 + level add-ons | grep | `grep -c 'D[0-9]' guides/reference/admin-fractal-scorecard.md | awk '$1 >= 11 {exit 0} {exit 1}'` | Wave 0 gap |

### Sampling Rate

- **Per task commit:** `mix test test/sigra/install/design_gallery_isolation_test.exs` (instant, no Postgres, guards D-04)
- **Per wave merge:** Full `mix test` + design gallery Playwright run across 3 projects
- **Phase gate:** All of the above + `bash scripts/ci/snapshot-canary-guard.sh` design invocation + `bash scripts/ci/quality-ledger-monotonic.sh` before `/gsd:verify-work`

### Wave 0 Gaps (files that must exist before implementation tasks run)

- [ ] `test/sigra/install/design_gallery_isolation_test.exs` — D-04 ExUnit contract guard
- [ ] `test/example/priv/playwright/tests/admin-design.spec.ts` — board-snapshot + axe spec skeleton (at minimum, the file and test structure; actual boards added as gallery is built)
- [ ] `test/example/priv/playwright/snapshot-allowlist-design` — empty allowlist (comments-only)
- [ ] `scripts/ci/quality-ledger-monotonic.sh` — monotonic guard script
- [ ] `guides/reference/admin-quality-ledger.md` — ledger with initial tier=1 rows
- [ ] `guides/reference/admin-fractal-scorecard.md` — rubric content

---

## Security Domain

> `security_enforcement` is not explicitly set to `false`. The gallery is a dev-only audit surface
> with no data-mutation paths and no new auth logic. Applicable controls are minimal.

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | Yes (gallery behind admin auth) | Reuse existing `admin_global` pipeline; no new auth code |
| V3 Session Management | No — gallery adds no session logic | — |
| V4 Access Control | Yes (dev-only compile gate) | `Application.compile_env(:example, :dev_routes)` |
| V5 Input Validation | No — gallery has no user inputs | — |
| V6 Cryptography | No — no new crypto | — |

### Known Threat Patterns

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Gallery route accessible in production | Elevation of privilege | `compile_env` gate compiles it out; D-04 contract guard fails CI if it leaks to installer |
| Static data in gallery contains actual user PII | Information disclosure | Gallery uses synthetic literal data (not DB queries); no PII risk |

---

## Sources

### Primary (HIGH confidence — verified by direct file read with line numbers)

- `test/example/priv/playwright/tests/admin-checkpoints.spec.ts` — axe wiring lines 114-126, element-scoped capture lines 132-148
- `test/example/priv/playwright/playwright.config.ts` — project definitions lines 107-138, snapshot path template lines 60-61
- `scripts/ci/snapshot-canary-guard.sh` — `slug_of()` lines 53-55, flag parsing lines 24-33, full logic verified
- `scripts/ci/snapshot-recapture-gate.sh` — full file verified; design-lane extension pattern derived
- `lib/sigra/admin/components.ex` — all 13 function signatures lines 44-724, full assigns inventory
- `test/sigra/admin/components_test.exs` — byte-golden contract anchor, `@compact_row`/`@impersonation_row`/`@failure_row` maps lines 97-131
- `test/example/lib/example_web/live/demo/credentials_live.ex` — dev-gated LiveView precedent (D-01 model)
- `test/example/lib/example_web/router.ex` — `if compile_env` block lines 172-182; `live_session :admin_global` lines 249-263
- `lib/sigra/admin/live/index_live.ex` — IndexLive markup lines 37-126 (MG-1, MG-3, MG-4 regions)
- `lib/sigra/admin/live/organization_live.ex` — OrganizationLive markup lines 48-138 (MG-3, MG-4, MG-6 regions)
- `lib/sigra/admin/live/users_index_live.ex` — UsersIndexLive markup lines 76-393 (MG-1, MG-2 region)
- `lib/sigra/admin/live/audit_index_live.ex` — AuditIndexLive markup lines 50-237 (MG-2, MG-5 regions)
- `.github/workflows/ci.yml` — `snapshot_drift_guard` job lines 1095-1114; `ci-gate` aggregator lines 1116-1166; Playwright run step lines 800-822
- `test/example/priv/playwright/snapshot-allowlist` — format reference (verified empty/comments-only)
- `test/example/priv/playwright/tests/admin-checkpoints.spec.ts-snapshots/` — 24 existing PNGs, naming pattern confirmed

### Secondary (MEDIUM confidence — derived from primary sources)

- MG-N catalog (MG-1..MG-6): derived from reading the 6 lib-owned admin page renders; not from a pre-existing catalog document

### Tertiary (LOW confidence)

None — all findings verified against real source files.

---

## Metadata

**Confidence breakdown:**
- Gallery LiveView shape: HIGH — direct precedent in `CredentialsLive` + router pattern
- Component assigns inventory: HIGH — read directly from `components.ex` + cross-referenced with `components_test.exs`
- Playwright project/snapshot clone: HIGH — exact existing code read with line numbers
- Guard extension: HIGH — guard source read, sed pattern confirmed
- Monotonic guard script: HIGH — pattern derived directly from `snapshot-canary-guard.sh` conventions; edge cases identified
- MG-N catalog: MEDIUM — derived from page renders; the exact group-count boundary is the planner's call

**Research date:** 2026-06-14
**Valid until:** 2026-09-14 (stable domain; guard scripts and component module change slowly)
