# Phase 187: Individual Components (L1) - Pattern Map

**Mapped:** 2026-06-14
**Files analyzed:** 12
**Analogs found:** 12 / 12

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `lib/sigra/admin/components.ex` | component | transform | `lib/sigra/admin/components.ex` | exact |
| `priv/templates/sigra.install/admin/sigra_admin.css` | config | transform | `test/example/priv/static/assets/css/app.css` + existing `sigra_admin.css` layer shell | exact |
| `test/example/priv/static/assets/sigra_admin.css` | config | transform | `priv/templates/sigra.install/admin/sigra_admin.css` | exact |
| `test/fixtures/install_golden/tree/priv/static/assets/sigra_admin.css` | config | transform | `priv/templates/sigra.install/admin/sigra_admin.css` | exact |
| `test/example/priv/static/assets/css/app.css` | config | transform | `test/example/priv/static/assets/css/app.css` component rule blocks | exact |
| `test/example/lib/example_web/live/admin/design_gallery_live.ex` | component | request-response | `test/example/lib/example_web/live/admin/design_gallery_live.ex` | exact |
| `test/example/priv/playwright/tests/admin-design.spec.ts` | test | request-response | `test/example/priv/playwright/tests/admin-design.spec.ts` | exact |
| `guides/reference/admin-quality-ledger.md` | config | batch | `guides/reference/admin-quality-ledger.md` | exact |
| `guides/reference/admin-token-reference.md` | config | transform | `guides/reference/admin-token-reference.md` | exact |
| `test/sigra/admin/components_test.exs` | test | transform | `test/sigra/admin/components_test.exs` | exact |
| `test/sigra/install/features/admin_test.exs` | test | file-I/O | `test/sigra/install/features/admin_test.exs` | exact |
| `test/sigra/install/golden_diff_test.exs` | test | file-I/O | `test/sigra/install/golden_diff_test.exs` | exact |

## Pattern Assignments

### `lib/sigra/admin/components.ex` (component, transform)

**Analog:** `lib/sigra/admin/components.ex`

**Imports/module pattern** (lines 1-12):
```elixir
defmodule Sigra.Admin.Components do
  @moduledoc """
  Lib-owned canonical admin component set for Sigra's admin LiveViews.

  Provides 13 flat, stateless `Phoenix.Component` function components that consolidate
  the duplicated admin chrome across LiveViews.
  """
  use Phoenix.Component
```

**Attr/rest pattern** (lines 44-56):
```elixir
attr :href, :string, required: true, doc: "the URL the stat link navigates to"
attr :label, :string, required: true, doc: "the human-readable KPI label"
attr :value, :integer, required: true, doc: "the numeric KPI value"
attr :class, :any, default: nil, doc: "additional CSS classes merged onto the root element"
attr :rest, :global, doc: "arbitrary HTML attributes added to the root element"

def stat_link(assigns) do
  ~H"""
  <a href={@href} class={["sg-metric-link", @class]} {@rest}>
```

**Interactive ARIA/state pattern** (lines 567-610):
```elixir
<span class={["sg-field-help", @class]} data-sg-field-help-root="true" {@rest}>
  <button
    type="button"
    class="sg-field-help__trigger"
    aria-label={"Help: #{@label}"}
    aria-controls={@id}
    aria-describedby={@id}
    aria-expanded="false"
    data-sg-field-help-trigger="true"
  >
  ...
  <span id={@id} class="sg-field-help__panel" role="tooltip" hidden>
```

**Tone derivation/error handling pattern** (lines 683-723):
```elixir
def audit_row(assigns) do
  ~H"""
  <article class={["sg-list-row sg-stack sg-stack--2", @class]} data-tone={audit_tone(@row)} {@rest}>
    <span class="sg-status-pill" data-tone={audit_tone(@row)}>{@row.action_label}</span>
    <code :if={@show_codes} class="sg-code">{@row.id}</code>
  </article>
  """
end

defp audit_tone(%{outcome: outcome}) when outcome not in ["success", nil, ""], do: "risk"
defp audit_tone(%{action_badge: badge}) when not is_nil(badge), do: "info"
defp audit_tone(_row), do: nil

defp format_date(value) do
  raise ArgumentError,
        "format_date/1 expected %DateTime{}, %NaiveDateTime{}, or nil, got: #{inspect(value)}"
end
```

**Apply:** Keep markup stateless and `sg-*` only. Default to CSS-only changes. If a component needs state markup, add attrs/rest in the existing style and update strict goldens in `test/sigra/admin/components_test.exs` in the same slice.

---

### `priv/templates/sigra.install/admin/sigra_admin.css` (config, transform)

**Analog:** `priv/templates/sigra.install/admin/sigra_admin.css` for layer/token placement; `test/example/priv/static/assets/css/app.css` for component rules to migrate.

**Cascade-layer/token pattern** (`sigra_admin.css` lines 15, 117-137, 222):
```css
@layer sg-base, sg-components, sg-overrides;

:root {
  --sg-motion-press: 120ms;
  --sg-motion-pop: 180ms;
  --sg-motion-fast: 140ms;
  --sg-motion-medium: 220ms;
  --sg-motion-slow: 300ms;
  --sg-transition-press: transform var(--sg-motion-fast) var(--sg-ease);
  --sg-transition-tone:
    color var(--sg-motion-fast) var(--sg-ease),
    background-color var(--sg-motion-fast) var(--sg-ease),
    box-shadow var(--sg-motion-fast) var(--sg-ease);
  --sg-transition-enter:
    opacity var(--sg-motion-medium) var(--sg-ease-out),
    transform var(--sg-motion-medium) var(--sg-ease-out);
}

@layer sg-components {
```

**Reduced-motion pattern** (`sigra_admin.css` lines 346-368):
```css
@media (prefers-reduced-motion: reduce) {
  *,
  *::before,
  *::after {
    animation-duration: 0.01ms !important;
    animation-iteration-count: 1 !important;
    scroll-behavior: auto !important;
    transition-property:
      color, background-color, border-color, box-shadow, opacity, fill, stroke !important;
    transition-duration: var(--sg-motion-fast) !important;
  }
}
```

**Component CSS source blocks to copy from `app.css`:**

| Component family | Source lines in `test/example/priv/static/assets/css/app.css` | Notes |
|------------------|---------------------------------------------------------------|-------|
| status pills / audit row tone glyphs | 1774-1896 | `sg-status-pill`, tone backgrounds, non-color glyph cues |
| buttons / page_back / task CTA | 1979-2088 | `sg-btn`, variants, focus, active, disabled, pointer-gated hover |
| card hover / empty-state shell | 2324-2346, 2874-2884 | `sg-card-hover`, `sg-empty-state`, title |
| field help | 2441-2502 | trigger, expanded state, panel |
| applied chip | 2679-2707 | pill + remove affordance |
| list row / notice / notice_link / code | 2742-2851, 2886-2893, 3505-3511 | toned rows, inline link, code affordance |
| metrics / summary_chip / stat / stat_link | 3003-3293 | metric grid, enhanced metric, help panel, metric link |
| skeleton | 3514-3543 | transform-only shimmer and keyframes |

**Pointer-gated hover pattern** (`app.css` lines 2341-2346):
```css
@media (hover: hover) and (pointer: fine) {
  .sg-card-hover:hover {
    box-shadow: var(--sg-elev-2);
    transform: translateY(-1px);
  }
}
```

**Disabled/inert pattern** (`app.css` lines 2009-2014):
```css
.sg-btn[disabled],
.sg-btn[aria-disabled="true"],
.sg-btn.is-disabled {
  opacity: 0.5;
  pointer-events: none;
}
```

**Apply:** Place migrated and improved component rules inside `@layer sg-components`. Use only `var(--sg-*)`, `color-mix`, and existing layer conventions. Add net-new motion tokens near lines 117-137 only; do not re-tune existing token values.

---

### `test/example/priv/static/assets/sigra_admin.css` (config, transform)

**Analog:** `priv/templates/sigra.install/admin/sigra_admin.css`

**Parity pattern** (`test/sigra/install/features/admin_test.exs` lines 317-327):
```elixir
template = File.read!("priv/templates/sigra.install/admin/sigra_admin.css")
example = File.read!("test/example/priv/static/assets/sigra_admin.css")

assert byte_size(template) == byte_size(example),
       "size mismatch — resync with: cp priv/templates/sigra.install/admin/sigra_admin.css test/example/priv/static/assets/sigra_admin.css"

assert template == example,
       "content mismatch — example copy has diverged from the installer template; resync with: cp priv/templates/sigra.install/admin/sigra_admin.css test/example/priv/static/assets/sigra_admin.css"
```

**Apply:** Treat this file as a byte mirror of the canonical template. Planner actions should sync it after every canonical CSS edit and run the parity test.

---

### `test/fixtures/install_golden/tree/priv/static/assets/sigra_admin.css` (config, transform)

**Analog:** `test/sigra/install/golden_diff_test.exs`

**Golden fixture read/compare pattern** (lines 53-63, 134-144, 172-184):
```elixir
test "generated tree matches committed fixture byte-for-byte (migration filenames normalized)" do
  {:ok, %{app_dir: app_dir, baseline_paths: baseline}} = run_installer()
  actual = InstallFixture.normalize_tree(app_dir, baseline)
  expected = read_fixture_tree()
  assert_tree_equal(actual, expected)
end

defp read_fixture_tree do
  @fixture_tree_dir
  |> Path.join("**")
  |> Path.wildcard(match_dot: true)
  |> Enum.filter(&File.regular?/1)
  |> Enum.map(fn abs_path ->
    rel = Path.relative_to(abs_path, @fixture_tree_dir)
    raw = File.read!(abs_path)
    {InstallFixture.normalize_path_for_golden(rel), InstallFixture.normalize_content_for_golden(rel, raw)}
  end)
end
```

**Apply:** Update this fixture copy whenever `sigra_admin.css` changes intentionally. Do not touch unrelated fixture files.

---

### `test/example/priv/static/assets/css/app.css` (config, transform)

**Analog:** `test/example/priv/static/assets/css/app.css`

**Existing host-link pattern** (`root.html.heex` lines 10-12):
```heex
<link phx-track-static rel="stylesheet" href={~p"/assets/default.css"} />
<link phx-track-static rel="stylesheet" href={~p"/assets/sigra_admin.css"} />
<link phx-track-static rel="stylesheet" href={~p"/assets/css/app.css"} />
```

**Migration source examples:**
```css
/* lines 2680-2707 */
.sg-applied-chip {
  display: inline-flex;
  align-items: center;
  gap: var(--sg-space-2);
  background: var(--sg-color-brand-soft);
  color: var(--sg-color-brand-strong);
}

@media (hover: hover) and (pointer: fine) {
  .sg-applied-chip__remove:hover {
    color: var(--sg-color-ink);
    text-decoration: underline;
  }
}
```

```css
/* lines 3519-3543 */
.sg-skeleton {
  position: relative;
  overflow: hidden;
  min-height: var(--sg-space-4);
  border-radius: var(--sg-radius-sm);
  background: color-mix(in oklab, var(--sg-color-line) 60%, transparent);
}
.sg-skeleton::after {
  transform: translateX(-100%);
  animation: sg-skeleton-shimmer var(--sg-motion-slow) var(--sg-ease) infinite;
}
@keyframes sg-skeleton-shimmer {
  to { transform: translateX(100%); }
}
```

**Apply:** Remove migrated `sg-*` component rules after they land in shipped CSS. Keep `vt-*`/example-only glue and explicit dark-token parity blocks. Do not leave duplicate `sg-*` component definitions in both files.

---

### `test/example/lib/example_web/live/admin/design_gallery_live.ex` (component, request-response)

**Analog:** `test/example/lib/example_web/live/admin/design_gallery_live.ex`

**Imports/static LiveView pattern** (lines 1-16):
```elixir
defmodule ExampleWeb.Admin.DesignGalleryLive do
  use ExampleWeb, :live_view
  import Sigra.Admin.Components

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Design Gallery")}
  end
```

**Board id/stable matrix pattern** (lines 36-52, 68-108, 151-173):
```heex
<%!-- board-stat --%>
<div id="board-stat" class="sg-card sg-stack sg-stack--4">
  <p class="sg-muted sg-text-sm">stat</p>
  <div class="sg-stack sg-stack--3">
    <span class="sg-muted sg-text-xs">read-only KPI</span>
    <.stat label="Active Users" value={1_247} />
  </div>
</div>

<%!-- board-summary_chip --%>
<div id="board-summary_chip" class="sg-card sg-stack sg-stack--4">
  <span class="sg-muted sg-text-xs">tone: warn</span>
  <dl class="sg-metric-grid">
    <.summary_chip label="Pending Reviews" value={4} tone="warn" />
  </dl>
</div>

<%!-- board-notice (CANARY, D-10) — all 5 tones including embedded notice_link --%>
<div id="board-notice" class="sg-card sg-stack sg-stack--4">
  <.notice tone={:risk}>
    3 accounts need review —
    <.notice_link href="/admin/users?needs_review=true">Review accounts</.notice_link>
  </.notice>
</div>
```

**Apply:** Add exhaustive state matrices by extending existing boards or adding missing stable board IDs. `notice_link` currently has no separate `board-notice_link`; either add one or explicitly retain embedded coverage in planner actions. Keep data static and literal.

---

### `test/example/priv/playwright/tests/admin-design.spec.ts` (test, request-response)

**Analog:** `test/example/priv/playwright/tests/admin-design.spec.ts`

**LiveView readiness/auth pattern** (lines 15-30, 78-87):
```typescript
async function waitForLiveViewReady(page: Page) {
  await page.waitForSelector('[data-phx-session].phx-connected', {
    state: 'attached',
  });
}

test.beforeEach(async ({ page }, testInfo) => {
  const suffix = `${Date.now()}-${testInfo.project.name}-${testInfo.title}`.replace(
    /[^a-z0-9]+/gi,
    '-',
  );
  const adminEmail = `platform-admin+design-${suffix}@example.test`;
  await registerUser(page, adminEmail, TEST_PASSWORD);
  await page.goto('/admin/_design');
  await waitForLiveViewReady(page);
});
```

**Axe + board screenshot pattern** (lines 32-60):
```typescript
async function assertNoAxeViolations(page: Page, label: string) {
  const { violations } = await new AxeBuilder({ page })
    .withTags(['wcag2a', 'wcag2aa'])
    .analyze();
  expect(violations, `${label}: axe violations\n${detail}`).toHaveLength(0);
}

async function assertBoardScreenshot(page: Page, testInfo: TestInfo, boardId: string) {
  await assertNoAxeViolations(page, `axe:${boardId}`);
  const locator = page.locator(`#${boardId}`);
  await expect(locator).toHaveScreenshot(`${boardId}.png`, {
    maxDiffPixels: ci ? 200_000 : dark ? 75_000 : mobile ? 45_000 : 30_000,
    maxDiffPixelRatio: ci ? 0.22 : dark ? 0.1 : mobile ? 0.08 : 0.06,
  });
}
```

**Board registry pattern** (lines 63-69):
```typescript
const COMPONENT_BOARDS = [
  'board-stat', 'board-stat_link', 'board-task_card', 'board-summary_chip',
  'board-applied_chip', 'board-empty_state', 'board-page_back', 'board-scope_ribbon',
  'board-notice',       // designated canary (D-10)
  'board-field_help', 'board-skeleton', 'board-audit_row',
];
```

**Apply:** Keep role/stable ID selectors and LiveView readiness. If adding `board-notice_link` or responsive state checks, register IDs here and avoid sleeps.

---

### `guides/reference/admin-quality-ledger.md` (config, batch)

**Analog:** `guides/reference/admin-quality-ledger.md`

**Machine-parseable tier pattern** (lines 14-30, 34-49):
```markdown
The **tier** column (column 4, 1-indexed in `|`-delimited rows) contains a single integer
(`0`, `1`, or `2`) with no decorators.

| Item | Level | Tier | Evidence |
|------|-------|------|----------|
| stat | L1 | 1 | [components_test.exs](../../test/sigra/admin/components_test.exs) |
| stat_link | L1 | 1 | [components_test.exs](../../test/sigra/admin/components_test.exs) |
...
| audit_row | L1 | 1 | [components_test.exs](../../test/sigra/admin/components_test.exs) |
```

**Guard pattern** (`scripts/ci/quality-ledger-monotonic.sh` lines 22-56):
```bash
extract_tiers() {
  grep -E '^\| [a-z]' | awk -F'|' '{
    item=$2; gsub(/^ +| +$/, "", item)
    tier=$4; gsub(/^ +| +$/, "", tier)
    if (tier ~ /^[012]$/) print item ":" tier
  }'
}

if [[ -n "$base_tier" && "$head_tier" -lt "$base_tier" ]]; then
  echo "quality-ledger-monotonic: FAIL: tier decreased for '${item}': ${base_tier} → ${head_tier}" >&2
fi
```

**Apply:** Raise only L1 rows for the audited components. Tier cell must remain bare `1` or `2`; put evidence links in the Evidence column.

---

### `guides/reference/admin-token-reference.md` (config, transform)

**Analog:** `guides/reference/admin-token-reference.md`

**Motion token documentation pattern** (lines 149-180):
```markdown
## Motion

Five duration tokens and four easing curves validated against emilkowal.ski's research on micro-interaction timing.

| Token | Value | Rationale | Brand Ref |
|-------|-------|-----------|-----------|
| `--sg-motion-press` | `120ms` | Button press and tap feedback ... | `admin-layer decision` |
| `--sg-motion-pop` | `180ms` | Tooltip and dropdown entrance ... | `motion.medium` |
| `--sg-motion-fast` | `140ms` | Tone-swap and hover color transitions ... | `motion.fast` |

| `--sg-transition-enter` | `opacity + transform at medium + ease-out` | Element entrance ... | `admin-layer decision` |
```

**Apply:** If Phase 187 adds exit-asymmetry or dropdown/tooltip-class tokens, document them in the same Duration Tokens / Composed Transition Shorthands tables. Do not alter documented existing values.

---

### `test/sigra/admin/components_test.exs` (test, transform)

**Analog:** `test/sigra/admin/components_test.exs`

**Strict literal golden pattern** (lines 7-31, 137-170):
```elixir
# D-13: NO mneme / auto_assert / snapshot library. Literal == strings only.
# Each assertion carries a component-naming, contract-citing,
# do-not-re-record drift message.

test "stat_link renders original metric_link bytes faithfully" do
  html =
    render_component(&Components.stat_link/1,
      label: "Total users",
      value: 1234,
      href: "/admin/users"
    )

  assert html == @stat_link_golden,
         "stat_link drifted — see admin-design-contract.md; do not re-record Playwright baselines"
end
```

**Structural/assertion pattern** (lines 325-355, 361-383, 412-430):
```elixir
test "field_help renders accessible label-adjacent tooltip control" do
  html = render_component(&Components.field_help/1, id: "branding-logo-url-help", label: "Logo URL", inner_block: [...])

  assert html =~ ~s(aria-controls="branding-logo-url-help")
  assert html =~ ~s(aria-expanded="false")
  assert html =~ ~s(role="tooltip")
  refute html =~ ~s(title=)
  refute html =~ "<a"
end

test "audit_row tone-mapping: failure outcome yields data-tone=risk" do
  html = render_component(&Components.audit_row/1, row: @failure_row)
  assert html =~ ~s(data-tone="risk")
end
```

**Apply:** For CSS-only work, leave this file untouched. For intended markup/state changes, update the literal golden and add focused structural assertions that cite the design contract.

---

### `test/sigra/install/features/admin_test.exs` (test, file-I/O)

**Analog:** `test/sigra/install/features/admin_test.exs`

**Installer CSS ownership pattern** (lines 46-50, 317-327):
```elixir
test "emits sigra_admin.css installer template to host priv/static/assets/ (DIST-02)" do
  files = Admin.files(otp_app: :my_app, web_module: "MyAppWeb")

  assert {:eex, "admin/sigra_admin.css", "priv/static/assets/sigra_admin.css"} in files
end

test "example copy is byte-identical to the installer template" do
  template = File.read!("priv/templates/sigra.install/admin/sigra_admin.css")
  example = File.read!("test/example/priv/static/assets/sigra_admin.css")

  assert template == example
end
```

**Dark-token parity pattern** (lines 335-352, 403-423):
```elixir
admin_dark_props = extract_dark_media_props(admin_css)
app_dark_props = extract_explicit_dark_props(app_css)

assert admin_dark_props == app_dark_props,
       "Dark --sg-* token values diverged between System path ... and explicit-toggle path ..."

defp extract_dark_media_props(css) do
  css
  |> String.split("\n")
  |> Enum.slice(166..203)
  |> Enum.filter(&String.contains?(&1, "--sg-"))
  |> Enum.map(&String.trim/1)
  |> Enum.sort()
end
```

**Apply:** Run this test after CSS parity edits. If new motion tokens are added to `:root`, review whether dark-token helper ranges need updating only if dark blocks move and tests fail for legitimate range drift.

---

### `test/sigra/install/golden_diff_test.exs` (test, file-I/O)

**Analog:** `test/sigra/install/golden_diff_test.exs`

**Byte diff failure pattern** (lines 148-184, 216-228):
```elixir
defp assert_tree_equal(actual, expected) do
  actual_paths = actual |> Enum.map(&elem(&1, 0)) |> Enum.sort()
  expected_paths = expected |> Enum.map(&elem(&1, 0)) |> Enum.sort()

  if missing != [] or extra != [] do
    flunk("""
    File set differs from golden fixture.
    """)
  end

  for {path, actual_content} <- actual do
    expected_content = Map.fetch!(expected_map, path)
    if actual_content != expected_content do
      flunk("""
      Content differs at #{path}:
      #{render_diff(expected_content, actual_content)}
      """)
    end
  end
end
```

**Apply:** Use this as the hard guard that the installer fixture copy changed only as intended.

## Shared Patterns

### Component CSS Migration

**Source:** `test/example/priv/static/assets/css/app.css` component blocks; target `priv/templates/sigra.install/admin/sigra_admin.css @layer sg-components`.

**Apply to:** All 13 components and all three parity CSS surfaces.

Rules to preserve:
- Exact-property transitions only; never `transition: all`.
- Pointer hover wrapped in `@media (hover: hover) and (pointer: fine)`.
- Focus uses `box-shadow: var(--sg-focus-ring)` with `outline: none`.
- Disabled/inert controls use `[disabled]`, `[aria-disabled="true"]`, or `.is-disabled` plus `pointer-events: none`.
- Status tones pair color with shape/glyph/border/text.
- Existing `--sg-*` token values are locked; add only net-new tokens for Phase 187 motion gaps.

### Delegated Help Behavior

**Source:** `priv/templates/sigra.install/admin/admin_hooks.js` lines 419-525 and 528-651.

```javascript
function installFieldHelp() {
  if (window.__sigraFieldHelpInstalled) return;
  window.__sigraFieldHelpInstalled = true;

  function open(root) {
    var trigger = triggerFor(root);
    var help = helpFor(root);
    if (!root || !trigger || !help) return;
    help.hidden = false;
    trigger.setAttribute("aria-expanded", "true");
    root.dataset.helpOpen = "true";
  }

  document.addEventListener("click", function (event) { ... });
  document.addEventListener("focusin", function (event) { ... });
  document.addEventListener("mouseover", function (event) {
    if (!finePointer()) return;
    ...
  });
  document.addEventListener("keydown", function (event) {
    if (event.key !== "Escape") return;
    closeAll(null);
  });
}
```

### Snapshot Allowlist / Canary Discipline

**Source:** `scripts/ci/snapshot-canary-guard.sh` lines 40-57 and 90-117.

```bash
slug_of() {
  basename "$1" | sed -E \
    's/-admin-checkpoints-(chromium|mobile|dark)\.png$//;
     s/-admin-design-(chromium|mobile|dark)\.png$//'
}

if [[ "$sl" == "$CANARY" ]]; then
  fail "canary snapshot changed: '${CANARY}' must stay byte-green (kind=${kind})"
fi
if [[ -z "${ALLOWED[$sl]:-}" ]]; then
  echo "snapshot-canary-guard: FAIL: unintended snapshot change: ${sl} (${kind}) — not in ${ALLOWLIST}" >&2
fi
```

**Apply to:** Any intended design-board visual delta. Declare changed board slugs in both `snapshot-allowlist` and `snapshot-allowlist-design`; keep `board-notice` canary stable unless planner deliberately changes the canary contract.

## No Analog Found

None. Every target file has an exact local analog or is itself the established pattern source.

## Metadata

**Analog search scope:** `lib/sigra/admin`, `priv/templates/sigra.install/admin`, `test/example/lib/example_web/live/admin`, `test/example/priv/static/assets`, `test/example/priv/playwright/tests`, `test/sigra/admin`, `test/sigra/install`, `guides/reference`, `scripts/ci`.

**Files scanned:** 32 listed admin/code/test/reference files plus targeted CSS/JS/test grep.

**Pattern extraction date:** 2026-06-14

**Limitations:** No repo-local `.codex/skills/` or `.agents/skills/` directories exist. All requested files were inspected. Large `app.css` was inspected by targeted non-overlapping ranges around the relevant `sg-*` component rules rather than loading the whole file.
