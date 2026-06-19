# Phase 188: Meta-Components / Groups (L2) - Pattern Map

**Mapped:** 2026-06-15
**Files analyzed:** 16
**Analogs found:** 16 / 16

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `test/example/lib/example_web/live/admin/design_gallery_live.ex` | component | request-response | same file current MG-1..MG-5 boards | exact |
| `test/example/priv/playwright/tests/admin-design.spec.ts` | test | request-response | same file component board screenshots/responsive checks | exact |
| `priv/templates/sigra.install/admin/sigra_admin.css` | config | transform | `test/example/priv/static/assets/css/app.css` group rules | role-match |
| `test/example/priv/static/assets/sigra_admin.css` | config | transform | `priv/templates/sigra.install/admin/sigra_admin.css` | exact mirror |
| `test/fixtures/install_golden/tree/priv/static/assets/sigra_admin.css` | config | transform | `priv/templates/sigra.install/admin/sigra_admin.css` | exact mirror |
| `test/example/priv/static/assets/css/app.css` | config | transform | its existing L2 group CSS block | exact source-to-migrate |
| `lib/sigra/admin/live/user_show_live.ex` | component | event-driven | `lib/sigra/admin/live/branding_live.ex` confirmation overlay | role-match |
| `lib/sigra/admin/live/users_index_live.ex` | component | request-response | same file MG-2/MG-5 table-card pattern | exact |
| `lib/sigra/admin/live/audit_index_live.ex` | component | request-response | same file MG-2/MG-6 table-card pattern | exact |
| `lib/sigra/admin/live/audit_user_live.ex` | component | request-response | `lib/sigra/admin/live/audit_index_live.ex` | exact |
| `lib/sigra/admin/live/organization_live.ex` | component | request-response | same file MG-7/MG-8 list/skeleton pattern | exact |
| `lib/sigra/admin/components.ex` | component | transform | existing L1 functions | exact |
| `guides/reference/admin-fractal-scorecard.md` | config | transform | same file L2 add-on section | exact |
| `guides/reference/admin-quality-ledger.md` | config | transform | same file L2 ledger rows | exact |
| `guides/reference/admin-token-reference.md` | config | transform | same file token tables | exact |
| `test/sigra/install/features/admin_test.exs` | test | file-I/O | same file CSS parity/extractor tests | exact |
| `test/example/priv/playwright/tests/admin-theme.spec.ts` | test | request-response | same file confirmation and notice contrast helpers | exact |

## Pattern Assignments

### `test/example/lib/example_web/live/admin/design_gallery_live.ex` (component, request-response)

**Analog:** `test/example/lib/example_web/live/admin/design_gallery_live.ex`

**Imports/static-data pattern** (lines 1-16):
```elixir
defmodule ExampleWeb.Admin.DesignGalleryLive do
  @moduledoc """
  Example-only design gallery for /admin/_design.
  ...
  Data is all static literal assigns — no DB queries, no Query module imports.
  """
  use ExampleWeb, :live_view
  import Sigra.Admin.Components

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Design Gallery")}
  end
```

**Current group-board pattern to expand** (lines 444-550):
```elixir
<section class="sg-stack sg-stack--4">
  <h2 class="sg-section-heading">Component Groups</h2>
  <div class="sg-stack sg-stack--6">
    <%!-- board-mg-1: Metric / Summary Strip --%>
    <div id="board-mg-1" class="sg-card sg-stack sg-stack--4">
      <p class="sg-muted sg-text-sm">MG-1 Metric / Summary Strip</p>
      <dl class="sg-metric-grid">
        <.summary_chip label="Total Users" value={3_842} />
        <.summary_chip label="Active Sessions" value={127} />
        <.summary_chip label="Failed Logins" value={7} tone="risk" />
        <.summary_chip label="MFA Enabled" value={94} tone="ok" />
      </dl>
    </div>
    ...
    <.notice tone={:risk}>
      High login failure rate detected — <.notice_link href="/admin/audit">View audit log</.notice_link>
    </.notice>
```

**Planner notes:** Preserve static literal data. Update the module doc and board labels from MG-1..MG-5 to MG-1..MG-11. For groups containing `.sg-card` children, do not wrap the scored group in another `.sg-card`; use an unframed `sg-stack` shell or an explicitly audit-only wrapper.

### `lib/sigra/admin/components.ex` (component, transform)

**Analog:** `Sigra.Admin.Components`

**Component import/ownership pattern** (lines 1-31):
```elixir
defmodule Sigra.Admin.Components do
  @moduledoc """
  Lib-owned canonical admin component set for Sigra's admin LiveViews.
  ...
  Each component emits only `sg-*` CSS classes defined by the design contract.
  """
  use Phoenix.Component
```

**L1 components Phase 188 must reuse** (lines 110-120, 166-185, 369-381, 407-413, 506-511, 538-543, 652-655, 699-712):
```elixir
def task_card(assigns) do
  ~H"""
  <article class={["sg-card sg-card-hover sg-stack sg-stack--3", @class]} {@rest}>
    ...
  </article>
  """
end

def applied_chip(assigns) do
  ~H"""
  <span class={["sg-applied-chip", @class]} {@rest}>
    <span>{@label}</span>
    <a class="sg-applied-chip__remove" href={@remove_href} aria-label={"Remove filter " <> @label}>
```

```elixir
def notice(assigns) do
  ~H"""
  <div class={["sg-notice", @class]} data-tone={@tone} {@rest}>
    <div class="sg-text-sm">{render_slot(@inner_block)}</div>
  </div>
  """
end

def audit_row(assigns) do
  ~H"""
  <article class={["sg-list-row sg-stack sg-stack--2", @class]} data-tone={audit_tone(@row)} {@rest}>
    <div class="sg-cluster sg-cluster--2">
      <span class="sg-status-pill" data-tone={audit_tone(@row)}>{@row.action_label}</span>
```

**Planner notes:** Gallery and production groups should compose these functions instead of duplicating their markup: `summary_chip`, `applied_chip`, `task_card`, `notice`, `notice_link`, `empty_state`, `skeleton`, and `audit_row`.

### `test/example/priv/playwright/tests/admin-design.spec.ts` (test, request-response)

**Analog:** same file

**Imports/readiness/auth pattern** (lines 1-19, 21-31, 47-58):
```typescript
import AxeBuilder from '@axe-core/playwright';
import { test, expect, type Page, type TestInfo } from '@playwright/test';
import { TEST_PASSWORD } from '../helpers/fixtures';

async function waitForLiveViewReady(page: Page) {
  await page.waitForSelector('[data-phx-session].phx-connected', {
    state: 'attached',
  });
}

async function assertNoAxeViolations(page: Page, label: string) {
  const { violations } = await new AxeBuilder({ page })
    .withTags(['wcag2a', 'wcag2aa'])
    .analyze();
```

**Board inventory/snapshot pattern** (lines 66-86, 95-105):
```typescript
async function assertBoardScreenshot(page: Page, testInfo: TestInfo, boardId: string) {
  await assertNoAxeViolations(page, `axe:${boardId}`);
  const dark = testInfo.project.name.includes('dark');
  const mobile = testInfo.project.name.includes('mobile');
  const ci = process.env.CI === 'true';
  const locator = page.locator(`#${boardId}`);
  await expect(locator).toHaveScreenshot(`${boardId}.png`, {
    maxDiffPixels: ci ? 200_000 : dark ? 75_000 : mobile ? 45_000 : 30_000,
    maxDiffPixelRatio: ci ? 0.22 : dark ? 0.1 : mobile ? 0.08 : 0.06,
  });
}

const RESPONSIVE_WIDTHS = [320, 375, 768, 1024, 1440] as const;
const GROUP_BOARDS = ['board-mg-1', 'board-mg-2', 'board-mg-3', 'board-mg-4', 'board-mg-5'];
```

**Responsive assertion pattern to copy for group boards** (lines 114-149):
```typescript
for (const width of RESPONSIVE_WIDTHS) {
  await page.setViewportSize({ width, height: 900 });

  for (const boardId of COMPONENT_BOARDS) {
    const board = page.locator(`#${boardId}`);
    await expect(board, `${boardId} should exist at ${width}px`).toBeVisible();

    const fit = await board.evaluate((element) => {
      const boardRect = element.getBoundingClientRect();
      const children = Array.from(element.querySelectorAll('*'));
      const overflowingChild = children.find((child) => {
        const rect = child.getBoundingClientRect();
        return rect.left < -1 || rect.right > window.innerWidth + 1;
      });
```

**L1 structure assertion pattern** (lines 337-350):
```typescript
const auditBoard = page.locator('#board-audit_row');
await expect(auditBoard.locator('article.sg-list-row')).toHaveCount(3);
await expect(auditBoard.locator('article.sg-list-row[data-tone="info"]')).toHaveCount(1);
await expect(auditBoard.locator('article.sg-list-row[data-tone="risk"]')).toHaveCount(1);
await expect(auditBoard.locator('code.sg-code')).toHaveCount(2);
```

**Planner notes:** Extend `GROUP_BOARDS` to all eleven ids. Add group-board responsive checks by reusing the `RESPONSIVE_WIDTHS` loop. Add MG-5/MG-6 equivalence tests using stable `data-testid` hooks from production LiveViews.

### `lib/sigra/admin/live/users_index_live.ex` (component, request-response)

**Analog:** same file, MG-2 and MG-5

**Filter panel + applied chips** (lines 156-243):
```elixir
<form method="get" action={index_path(@admin_scope)} class="sg-filter-panel sg-stack">
  <div class="sg-search-row">
    <label class="sg-field">
      <span class="sg-field-label">Search</span>
      <input type="text" name="q" ... class="sg-input" />
    </label>
    <button type="submit" class="sg-btn sg-btn--primary">Search</button>
    <a href={index_path(@admin_scope)} class="sg-btn sg-btn--ghost">Clear</a>
  </div>
  ...
</form>

<div :if={any_filter_active?(@current_params)} class="sg-cluster sg-cluster--start">
  <.applied_chip :for={chip <- applied_chips(@current_params)} ... />
```

**MG-5 desktop/mobile equivalence anchors** (lines 245-345, 348-386):
```elixir
<div id="admin-users-desktop-results" data-testid="admin-users-desktop-results" class="sg-table-panel sg-show-desktop">
  <table class="sg-table">
    ...
    <span class="sg-strong">{primary_name(row)}</span>
    <span class="sg-muted sg-text-sm sg-truncate" title={row.user.email}>{row.user.email}</span>
    <code class="sg-code">{row.user.id}</code>
    ...
    <a class="sg-btn sg-btn--secondary sg-btn--sm" href={open_user_path(...)}>Open user</a>
```

```elixir
<div id="admin-users-mobile-results" data-testid="admin-users-mobile-results" class="sg-stack sg-stack--3 sg-show-mobile">
  <article :for={row <- @rows} class="sg-card sg-stack sg-stack--3">
    <span class="sg-strong">{primary_name(row)}</span>
    <span class="sg-muted sg-text-sm sg-truncate" title={row.user.email}>{row.user.email}</span>
    <code class="sg-code">{row.user.id}</code>
    ...
    <a class="sg-btn sg-btn--secondary sg-btn--block" href={open_user_path(...)}>Open user</a>
```

**Planner notes:** MG-5 tests should assert primary identity, status pills, org/activity facts, `Open user`, and user id appear in both `admin-users-desktop-results` and `admin-users-mobile-results`.

### `lib/sigra/admin/live/audit_index_live.ex` and `lib/sigra/admin/live/audit_user_live.ex` (component, request-response)

**Analog:** `audit_index_live.ex`, exact for MG-6; `audit_user_live.ex` repeats the pattern.

**Audit filter panel + applied chips** (audit index lines 58-146):
```elixir
<form method="get" action={index_path(@admin_scope)} class="sg-filter-panel sg-stack">
  <div class="sg-cluster">
    <label class="sg-filter-chip">
      <input type="checkbox" name="outcome" value="failure" ... />
      <span>Failures</span>
    </label>
  </div>
  <div class="sg-form-grid sg-form-grid--cols">
    <label class="sg-field">
      <span class="sg-field-label">Actor</span>
      <input type="text" name="actor" ... class="sg-input" />
```

**MG-6 desktop/mobile equivalence anchors** (audit index lines 148-203; user audit lines 177-232):
```elixir
<div id="admin-audit-desktop-results" data-testid="admin-audit-desktop-results" class="sg-table-panel sg-show-desktop">
  <table class="sg-table">
    <tr :for={row <- @rows} data-tone={audit_tone(row)}>
      <span class="sg-text-sm">{format_timestamp(row.inserted_at)}</span>
      <code class="sg-code">{row.id}</code>
      <span class="sg-status-pill" data-tone={audit_tone(row)}>{row.action_label}</span>
      <code class="sg-code">{row.action}</code>
```

```elixir
<div id="admin-audit-mobile-results" data-testid="admin-audit-mobile-results" class="sg-stack sg-stack--3 sg-show-mobile">
  <.audit_row :for={row <- @rows} row={row} show_detail show_codes />
</div>
```

**Planner notes:** MG-6 tests should cover both `admin-audit-*` and `admin-audit-user-*` hooks if user-audit remains part of the reused-group evidence. Assert action label/code, outcome/tone, actor/effective-user, event id, and pagination/export affordances.

### `lib/sigra/admin/live/organization_live.ex` (component, request-response)

**Analog:** same file, MG-7/MG-8

**Notice/task/list/skeleton composition** (lines 60-137):
```elixir
<.notice :if={not @loading} tone={if @needs_review > 0, do: :risk, else: :ok} role="status">
  <%= if @needs_review > 0 do %>
    {@needs_review} accounts need review — <.notice_link href={users_path(@admin_scope) <> "?needs_review=true"}>Review accounts</.notice_link>
  <% else %>
    All clear
  <% end %>
</.notice>

<div class="sg-grid sg-grid--2">
  <.task_card title="Support members" ... />
  <.task_card title="Investigate org events" ... />
</div>

<section class="sg-card sg-stack sg-stack--3">
  <h2 class="sg-section-heading">Members</h2>
  <%= if @loading do %>
    <.skeleton class="sg-list-row" /><.skeleton class="sg-list-row" /><.skeleton class="sg-list-row" />
  <% else %>
    <div :if={@members != []} class="sg-list">
      <div :for={member <- @members} class="sg-list-row">
```

**Planner notes:** Reuse this pattern for MG-7/MG-8 gallery state matrices. If changing production zero states, prefer `<.empty_state>` to plain `sg-section-copy` when the group is a zero-data section.

### `lib/sigra/admin/live/user_show_live.ex` (component, event-driven)

**Analog:** same file for MG-9/MG-10, `branding_live.ex` for MG-11 confirmation.

**MG-9 identity + summary facts** (lines 93-132):
```elixir
<header class="sg-page-header">
  <div class="sg-cluster sg-cluster--between sg-cluster--start sg-cluster--3">
    <div class="sg-stack sg-stack--1">
      <p class="sg-page-kicker">Identity &amp; Status</p>
      <h1 class="sg-page-title">{@detail.display_name || @detail.user.email}</h1>
      <span class="sg-muted sg-text-sm">{@detail.user.email}</span>
      <code class="sg-code">{@detail.user.id}</code>
    </div>
    <div class="sg-cluster sg-cluster--2">
      <span :for={{label, tone} <- status_pills(@detail)} class="sg-status-pill" data-tone={tone}>{label}</span>
    </div>
  </div>
  <dl class="sg-summary-facts">
```

**MG-10 detail/list panels** (lines 190-266):
```elixir
<div class="sg-detail-grid">
  <section class="sg-detail-panel sg-stack sg-stack--3">
    <h2 class="sg-section-heading">Security</h2>
    <dl class="sg-kv">
      <dt class="sg-kv__term">MFA</dt>
      <dd class="sg-kv__value">{mfa_value(@detail.security.mfa_status)}</dd>
...
<section class="sg-card sg-stack sg-stack--3">
  <div class="sg-list">
    <.audit_row :for={row <- @detail.recent_audit} row={row} />
    <.empty_state :if={@detail.recent_audit == []} title="No recent audit activity">
```

**Current MG-11 drift to replace** (lines 269-318):
```elixir
<section class="sg-danger-panel sg-stack sg-stack--3">
  ...
  <button phx-click="open_revoke_all_sessions" class="sg-btn sg-btn--danger sg-btn--sm">
    Revoke all sessions
  </button>
</section>

<dialog :if={@confirm_action} open class="modal">
  <div class="modal-box">
    <p class="sg-section-heading">Confirm action</p>
```

**Planner notes:** Keep the existing LiveView events (`open_revoke_session`, `open_revoke_all_sessions`, `cancel_confirm`, `confirm_action`) but replace DaisyUI dialog chrome with the `BrandingLive` Sigra-owned overlay pattern.

### `lib/sigra/admin/live/branding_live.ex` (component, event-driven)

**Analog for MG-11:** `sg-confirm-overlay` / `sg-confirm-dialog`

**Confirmation markup pattern** (lines 349-372):
```elixir
<div :if={@restore_defaults_open?} class="sg-confirm-overlay" role="presentation">
  <section
    class="sg-confirm-dialog"
    role="dialog"
    aria-modal="true"
    aria-labelledby="restore-defaults-title"
  >
    <p id="restore-defaults-title" class="sg-section-heading">Restore defaults?</p>
    <p class="sg-text-sm" style="margin-top: var(--sg-space-3);">
      This removes the saved admin branding changes and uses the app's configured defaults...
    </p>
    <div class="sg-confirm-dialog__actions">
      <button type="button" phx-click="cancel_restore_defaults" class="sg-btn sg-btn--ghost sg-btn--sm">
```

**Event-state pattern** (lines 450-456):
```elixir
def handle_event("open_restore_defaults", _params, socket) do
  {:noreply,
   assign(socket, :restore_defaults_open?, admin_profile?(socket.assigns.profile_source))}
end

def handle_event("cancel_restore_defaults", _params, socket) do
  {:noreply, assign(socket, :restore_defaults_open?, false)}
end
```

### `priv/templates/sigra.install/admin/sigra_admin.css` and mirrors (config, transform)

**Analog:** canonical CSS header and component layer in `sigra_admin.css`; missing L2 rules sourced from `app.css`.

**Canonical cascade-layer/token pattern** (lines 1-15):
```css
/* Vaultr/Sigra demo design layer.
 *
 * ...
 * Architecture: a token-driven, BEM-flavored component layer. Cascade layers
 * (declared below) make `sg-*` authoritatively win over daisyUI's `default.css`
 * without `!important`
 */

@layer sg-base, sg-components, sg-overrides;
```

**Canonical component surface style location** (lines 541-550, 648-694, 695-748):
```css
.sg-nav-card,
.sg-card,
.sg-filter-panel,
.sg-table-panel,
.sg-detail-panel,
.sg-empty-state {
  border-radius: var(--sg-radius-md);
  background: var(--sg-color-panel);
  box-shadow: var(--sg-elev-1);
}

.sg-applied-chip {
  display: inline-flex;
  align-items: center;
  gap: var(--sg-space-2);
  ...
}

.sg-list-row[data-tone="ok"],
.sg-notice[data-tone="ok"] {
  background: color-mix(in oklab, var(--sg-color-ok-soft) 62%, var(--sg-color-panel));
```

**Example-only L2 rules to migrate into canonical `@layer sg-components`** (`app.css` lines 2093-2630):
```css
.sg-detail-grid {
  display: grid;
  gap: var(--sg-space-4);
  grid-template-columns: repeat(auto-fit, minmax(15rem, 1fr));
}

.sg-form-grid { display: grid; gap: var(--sg-space-3); }
.sg-action-row { display: flex; flex-wrap: wrap; align-items: center; gap: var(--sg-space-2); }

.sg-confirm-overlay {
  position: fixed;
  inset: 0;
  z-index: var(--sg-z-modal);
  display: flex;
  align-items: center;
  justify-content: center;
  padding: var(--sg-space-4);
  background: color-mix(in oklab, var(--sg-color-ink) 46%, transparent);
}

.sg-search-row { display: grid; gap: var(--sg-space-3); }
.sg-filter-chip { display: inline-flex; align-items: center; gap: var(--sg-space-2); }
.sg-list { display: grid; gap: var(--sg-space-3); }
.sg-table-panel { overflow: hidden; }
.sg-summary-facts { display: flex; flex-wrap: wrap; gap: var(--sg-space-5); }
.sg-danger-panel { border-radius: var(--sg-radius-md); ... }
```

**Mirror rule:** After canonical edits, copy exact bytes to `test/example/priv/static/assets/sigra_admin.css` and `test/fixtures/install_golden/tree/priv/static/assets/sigra_admin.css`. Current grep shows these mirrors only have the canonical subset (`sg-table-panel` reference at line 544) and do not have the example-only L2 rules yet.

### `test/sigra/install/features/admin_test.exs` (test, file-I/O)

**Analog:** same file

**Byte parity tests** (lines 317-327):
```elixir
describe "DIST-05 example≡template byte-parity (sigra_admin.css)" do
  test "example copy is byte-identical to the installer template" do
    template = File.read!("priv/templates/sigra.install/admin/sigra_admin.css")
    example = File.read!("test/example/priv/static/assets/sigra_admin.css")

    assert byte_size(template) == byte_size(example),
           "size mismatch — resync with: cp priv/templates/sigra.install/admin/sigra_admin.css test/example/priv/static/assets/sigra_admin.css"

    assert template == example,
```

**Current brittle extractor pattern to harden** (lines 335-423):
```elixir
test "admin dark @media block and app.css explicit-toggle dark block declare identical --sg-* values" do
  admin_css = File.read!("priv/templates/sigra.install/admin/sigra_admin.css")
  app_css = File.read!("test/example/priv/static/assets/css/app.css")

  admin_dark_props = extract_dark_media_props(admin_css)
  app_dark_props = extract_explicit_dark_props(app_css)
  assert admin_dark_props == app_dark_props
end

defp extract_dark_media_props(css) do
  css
  |> String.split("\n")
  |> Enum.slice(176..209)
  |> Enum.filter(&String.contains?(&1, "--sg-"))
```

**Planner notes:** Replace fixed line slices with structural block extraction. Keep the same file-I/O style and assertions; do not change token values.

### `test/example/priv/playwright/tests/admin-theme.spec.ts` (test, request-response)

**Analog:** same file

**Confirmation guard pattern** (lines 1226-1249):
```typescript
await restoreButton.click();
const confirmDialog = page.getByRole("dialog", {
  name: "Restore defaults?",
});
await expect(confirmDialog).toBeVisible();
await expect(page.locator(".sg-confirm-overlay")).toBeVisible();
await expect(page.locator(".modal[open]")).toHaveCount(0);
await expect(page.locator("dialog.modal")).toHaveCount(0);
await expect(
  page.getByText("This removes the saved admin branding changes"),
).toBeVisible();
...
await page.getByRole("button", { name: "Cancel" }).click();
await expect(confirmDialog).toBeHidden();
await expect(page.locator(".sg-confirm-overlay")).toHaveCount(0);
```

**Duplicated helper to hoist** (lines 1387-1402 and 1417-1431):
```typescript
const readNoticeStyles = async () =>
  notice.evaluate((el) => {
    const inner = el.querySelector(".sg-text-sm") as HTMLElement | null;
    if (!inner) throw new Error("Expected .sg-text-sm inside .sg-notice");
    return {
      color: getComputedStyle(inner).color,
      background: getComputedStyle(el).backgroundColor,
    };
  });

await expect
  .poll(async () => {
    const styles = await readNoticeStyles();
    return contrastRatio(styles.color, styles.background);
  })
  .toBeGreaterThanOrEqual(4.5);
```

**Planner notes:** Hoist `readNoticeStyles` to a shared helper accepting a `Locator`. Keep role selectors and LiveView readiness gates; no sleeps.

### Docs: scorecard, ledger, token reference (config, transform)

**Scorecard analog:** `guides/reference/admin-fractal-scorecard.md` lines 61-79:
```markdown
### L2 Meta-Component Group Add-ons

Applied to each of the 5 meta-component group boards (MG-1 through MG-5).

- **Intra-group rhythm consistent** ...
- **No card-in-card nesting** ...
- **Right-component-for-job** ...
- **Zero/loading/error states defined** ...
- **Desktop-table to mobile-card swap is content-equivalent** ...
- **Reused groups render byte-coherently** ...
```

**Ledger analog:** `guides/reference/admin-quality-ledger.md` lines 34-54:
```markdown
| Item | Level | Tier | Evidence |
|------|-------|------|----------|
...
| mg-1-metric-strip | L2 | 1 | [admin-design.spec.ts board-mg-1](#) |
| mg-2-filter-panel | L2 | 1 | [admin-design.spec.ts board-mg-2](#) |
| mg-3-task-grid | L2 | 1 | [admin-design.spec.ts board-mg-3](#) |
| mg-4-alarm-notice | L2 | 1 | [admin-design.spec.ts board-mg-4](#) |
| mg-5-audit-feed | L2 | 1 | [admin-design.spec.ts board-mg-5](#) |
```

**Token reference analog:** `guides/reference/admin-token-reference.md` lines 11-19 and 27-39:
```markdown
| Token | Value | Rationale | Brand Ref |
|-------|-------|-----------|-----------|
| `--sg-color-ink` | `#151515` (light) / `#f4f1eb` (dark) | Primary text... |
...
| `--sg-color-brand` | `#c2410c` | Primary ember accent... |
```

**Planner notes:** Update stale "5 boards" and MG-1..MG-5 ledger rows to the approved MG-1..MG-11 catalog. Keep ledger tier cells plain integers for the monotonic guard.

## Shared Patterns

### Admin LiveView Component Reuse
**Source:** `lib/sigra/admin/components.ex`
**Apply to:** all group boards and production LiveViews

Use function components for L1 jobs and raw `sg-*` classes only for group layout. The authoritative reuse list is documented in the module lines 16-28 and implemented by the excerpts above.

### Deterministic Playwright
**Source:** `test/example/priv/playwright/tests/admin-design.spec.ts`
**Apply to:** all admin design tests

Use `waitForLiveViewReady(page)` from lines 15-19, role selectors for controls, stable ids/test ids for result containers and boards, and no sleeps. Pair board snapshots with axe WCAG A/AA from lines 47-58.

### MG-5/MG-6 Equivalence
**Source:** `users_index_live.ex`, `audit_index_live.ex`, `audit_user_live.ex`
**Apply to:** table/card tests and board state evidence

Assert both desktop and mobile containers include primary identity/event, status/outcome, secondary facts, action/navigation affordance, and identifiers. Stable hooks:
`admin-users-desktop-results`, `admin-users-mobile-results`, `admin-audit-desktop-results`, `admin-audit-mobile-results`, `admin-audit-user-desktop-results`, `admin-audit-user-mobile-results`.

### Confirmation Coherence
**Source:** `lib/sigra/admin/live/branding_live.ex`
**Apply to:** `user_show_live.ex` MG-11 and gallery board-mg-11

Use `sg-confirm-overlay` + `sg-confirm-dialog`, `role="dialog"`, `aria-modal="true"`, and `aria-labelledby`. Keep tests asserting `.modal[open]` and `dialog.modal` count zero.

### CSS Distribution Parity
**Source:** `test/sigra/install/features/admin_test.exs`
**Apply to:** canonical CSS and mirrors

Canonical edits start in `priv/templates/sigra.install/admin/sigra_admin.css`. Sync bytes to both mirrors and preserve `@layer sg-components`, token-only values, Light/Dark/System behavior, and the D-11 token boundary.

## No Analog Found

None. Every planned file has a same-file, same-role, or stronger production precedent. The only caution is that `sigra_admin.css` does not yet contain most L2 group selectors; use `app.css` as the source analog and migrate into the canonical stylesheet.

## Metadata

**Analog search scope:** `lib/sigra/admin/live`, `lib/sigra/admin/components.ex`, `test/example/lib/example_web/live/admin`, `test/example/priv/playwright/tests`, `priv/templates/sigra.install/admin`, `test/example/priv/static/assets`, `test/sigra/install/features`, `guides/reference`.
**Files scanned:** 16 primary files plus phase context/research/UI spec and project reference guides.
**Pattern extraction date:** 2026-06-15
