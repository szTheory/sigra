# Phase 185: Audit Infrastructure — Pattern Map

**Mapped:** 2026-06-14
**Files analyzed:** 11 (6 new, 5 modified)
**Analogs found:** 11 / 11

---

## File Classification

| New / Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---------------------|------|-----------|----------------|---------------|
| `test/example/lib/example_web/live/admin/design_gallery_live.ex` (NEW) | LiveView / component | request-response, static | `test/example/lib/example_web/live/demo/credentials_live.ex` | role-match (same dev-gate shape, different data source) |
| `test/example/lib/example_web/router.ex` (EDIT) | route config | request-response | same file lines 172-182 (`if dev_routes` block) + lines 249-263 (`live_session :admin_global`) | exact — extend existing block |
| `test/example/priv/playwright/tests/admin-design.spec.ts` (NEW) | Playwright spec | event-driven, snapshot | `test/example/priv/playwright/tests/admin-checkpoints.spec.ts` | exact — clone helper functions, board-scoped variant |
| `test/example/priv/playwright/playwright.config.ts` (EDIT) | config | — | same file lines 107-138 (`admin-checkpoints-{chromium,mobile,dark}` project defs) | exact — clone project trio |
| `test/example/priv/playwright/snapshot-allowlist-design` (NEW) | data / manifest | — | `test/example/priv/playwright/snapshot-allowlist` | exact — same format, second empty file |
| `scripts/ci/quality-ledger-monotonic.sh` (NEW) | CI guard / bash | batch | `scripts/ci/snapshot-canary-guard.sh` | role-match (same guard conventions, different domain) |
| `scripts/ci/snapshot-canary-guard.sh` (EDIT) | CI guard / bash | batch | same file lines 53-55 (`slug_of()`) | exact — one sed alternation added |
| `scripts/ci/snapshot-recapture-gate.sh` (EDIT) | CI gate / bash | batch | same file lines 30-48 (two-step pattern: playwright + canary guard) | exact — add parallel design-lane block |
| `.github/workflows/ci.yml` (EDIT) | CI pipeline | batch | same file lines 1095-1166 (`snapshot_drift_guard` job + `ci-gate`) | exact — clone job, extend `needs:` + loop |
| `guides/reference/admin-quality-ledger.md` (NEW) | reference doc | — | `guides/reference/admin-design-contract.md` (sibling) | partial — same directory, new machine-parseable format |
| `guides/reference/admin-fractal-scorecard.md` (NEW) | reference doc | — | `guides/reference/admin-design-contract.md` (sibling) | partial — same directory, human-readable rubric |
| `test/sigra/installer/design_gallery_isolation_test.exs` (NEW) | ExUnit test | batch | `test/sigra/install/template_syntax_test.exs` | role-match — same `Path.wildcard` + `assert` guard pattern |

---

## Pattern Assignments

---

### `test/example/lib/example_web/live/admin/design_gallery_live.ex` (NEW)

**Analog:** `test/example/lib/example_web/live/demo/credentials_live.ex`

**Module shape / use macro + import** (lines 1-14 of analog, adapted):
```elixir
defmodule ExampleWeb.Admin.DesignGalleryLive do
  @moduledoc """
  Example-only design gallery for /admin/_design.

  Renders all 13 Sigra.Admin.Components + meta-component groups (MG-1..MG-5)
  in every state, inside the real admin shell. Available in development only —
  the route is compile_env(:example, :dev_routes) gated.

  Data is all static literal assigns — no DB queries, no Query module imports.
  """
  use ExampleWeb, :live_view
  import Sigra.Admin.Components
```

**mount/3 pattern** (analog lines 16-25, static-assign variant):
```elixir
  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Design Gallery")}
  end
```

Key differences from analog:
- Analog calls `Personas.all()` in mount — gallery assigns MUST be static literals only (no DB calls, no alias/import of any `Sigra.Admin.*` module except `Sigra.Admin.Components`)
- Analog uses `Layouts.app` in render — gallery must NOT use this; the admin shell is wired at the router `live_session` level (`layout: {ExampleWeb.Layouts, :admin}`), so `render/1` is a bare `~H"""` section without a top-level `<Layouts.*>` wrapper

**render/1 scaffold** (derived from UI-SPEC page structure):
```heex
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
          <%!-- 13 board wrappers, each id="board-{component}" --%>
          <div id="board-notice" class="sg-card sg-stack sg-stack--4">
            ...
          </div>
          ...
        </div>
      </section>

      <section class="sg-stack sg-stack--4">
        <h2 class="sg-section-heading">Component Groups</h2>
        <div class="sg-stack sg-stack--6">
          <%!-- MG-1..MG-5 boards, each id="board-mg-{n}" --%>
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

**DEV ONLY badge** (analog line 44):
```heex
<span class="vt-status-pill" data-testid="demo-dev-only-badge">DEV ONLY</span>
```
Gallery version:
```heex
<span data-testid="design-gallery-dev-only-badge">DEV ONLY</span>
```

**Board wrapper contract** (from UI-SPEC / D-03 — no bespoke CSS, `sg-card` only):
```heex
<div id="board-{component}" class="sg-card sg-stack sg-stack--4">
  <p class="sg-muted sg-text-sm">{component_name}</p>
  <div class="sg-stack sg-stack--3">
    <span class="sg-muted sg-text-xs">{state label e.g. "tone: ok"}</span>
    <.{component} ... />
    ...
  </div>
</div>
```

**Canary board `board-notice`** (D-10, UI-SPEC line 165 — must contain all 5 tones including an embedded `notice_link`):
```heex
<div id="board-notice" class="sg-card sg-stack sg-stack--4">
  <p class="sg-muted sg-text-sm">notice</p>
  <div class="sg-stack sg-stack--3">
    <span class="sg-muted sg-text-xs">tone: nil (neutral)</span>
    <.notice>System maintenance scheduled for Sunday 02:00 UTC.</.notice>

    <span class="sg-muted sg-text-xs">tone: ok</span>
    <.notice tone={:ok}>All clear — no accounts need review.</.notice>

    <span class="sg-muted sg-text-xs">tone: warn</span>
    <.notice tone={:warn}>Password reset email delivery delayed.</.notice>

    <span class="sg-muted sg-text-xs">tone: risk</span>
    <.notice tone={:risk}>
      3 accounts need review —
      <.notice_link href="/admin/users?needs_review=true">Review accounts</.notice_link>
    </.notice>

    <span class="sg-muted sg-text-xs">tone: info</span>
    <.notice tone={:info}>Impersonation session active. End it before navigating away.</.notice>
  </div>
</div>
```

**`audit_row` board** — row maps mirror `@compact_row`/`@impersonation_row`/`@failure_row` from `test/sigra/admin/components_test.exs` lines 97-131:
```heex
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

    <span class="sg-muted sg-text-xs">show_detail: true, show_codes: true</span>
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

---

### `test/example/lib/example_web/router.ex` (EDIT — dev route addition)

**Analog:** Same file, lines 172-182 (`if Application.compile_env(:example, :dev_routes)` block) + lines 249-263 (`live_session :admin_global`).

**Existing dev-gate block to extend** (router.ex lines 172-182):
```elixir
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

**Existing `live_session :admin_global` to clone** (router.ex lines 249-263):
```elixir
live_session :admin_global,
  layout: {ExampleWeb.Layouts, :admin},
  on_mount: [
    {ExampleWeb.UserAuth, :ensure_authenticated},
    {Sigra.LiveView.AdminScope,
     [mode: :global, policy: Example.SigraAdminPolicy, login_path: "/users/log_in"]}
  ] do
  live "/admin", Elixir.Sigra.Admin.Live.IndexLive, :index
  ...
end
```

**Addition inside the `if` block** — a new scope after the `/demo` scope that mirrors the admin pipeline and `live_session` shape exactly:
```elixir
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

**What differs:** The scope alias is `ExampleWeb.Admin` (so `DesignGalleryLive` resolves to `ExampleWeb.Admin.DesignGalleryLive`). The `live_session` name is `:admin_design_gallery` (distinct from `:admin_global` to avoid mixing gallery + real admin pages in one session group). Sits inside the compile-env gate so it compiles out in prod/test.

---

### `test/example/priv/playwright/tests/admin-design.spec.ts` (NEW)

**Analog:** `test/example/priv/playwright/tests/admin-checkpoints.spec.ts`

**Imports block** (analog lines 1-6 — copy exactly, drop `captureAdminCheckpoint`/`adminUsersEmailLocator`):
```typescript
import AxeBuilder from '@axe-core/playwright';
import { test, expect, type Page, type TestInfo } from '@playwright/test';
import { TEST_PASSWORD } from '../helpers/fixtures';
```

**`waitForLiveViewReady` helper** (analog lines 43-47 — copy verbatim):
```typescript
async function waitForLiveViewReady(page: Page) {
  await page.waitForSelector('[data-phx-session].phx-connected', {
    state: 'attached',
  });
}
```

**`registerUser` helper** (analog lines 49-58 — copy verbatim; used for admin session seeding):
```typescript
async function registerUser(page: Page, email: string, password: string) {
  await page.goto('/users/register');
  await waitForLiveViewReady(page);
  await page.fill('input[name="user[email]"]', email);
  await page.fill('input[name="user[password]"]', password);
  await page.locator('form:has(input[name="user[password]"])').first().evaluate((form) => {
    (form as HTMLFormElement).requestSubmit();
  });
  await expect(page).not.toHaveURL(/\/users\/register/);
}
```

**`assertNoAxeViolations` helper** (analog lines 114-126 — copy verbatim):
```typescript
async function assertNoAxeViolations(page: Page, label: string) {
  const { violations } = await new AxeBuilder({ page })
    .withTags(['wcag2a', 'wcag2aa'])
    .analyze();
  const detail =
    violations.length === 0 ? '' : JSON.stringify(violations).slice(0, 2000);
  expect(violations, `${label}: axe violations\n${detail}`).toHaveLength(0);
}
```

**`assertBoardScreenshot` helper** (adapted from `assertCheckpointScreenshot` at analog lines 132-148; key change: `page.locator(#boardId)` instead of `page` for element-scoped capture):
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
```

Pixel thresholds are copied verbatim from the checkpoints analog (analog lines 144-146).

**Board ID constants and test loop:**
```typescript
const COMPONENT_BOARDS = [
  'board-stat', 'board-stat_link', 'board-task_card', 'board-summary_chip',
  'board-applied_chip', 'board-empty_state', 'board-page_back', 'board-scope_ribbon',
  'board-notice',       // designated canary (D-10)
  'board-field_help', 'board-skeleton', 'board-audit_row',
];
const GROUP_BOARDS = ['board-mg-1', 'board-mg-2', 'board-mg-3', 'board-mg-4', 'board-mg-5'];

test.describe('Design gallery board snapshots', () => {
  test.beforeAll(async ({ browser }) => {
    // Seed an admin session — mirror checkpoints spec approach (platform-admin+ prefix)
    const suffix = Date.now();
    const adminEmail = `platform-admin+design-${suffix}@example.test`;
    const page = await browser.newPage();
    await registerUser(page, adminEmail, TEST_PASSWORD);
    await page.context().storageState({ path: 'fixtures/admin-design-session.json' });
    await page.close();
  });

  test.beforeEach(async ({ page }) => {
    await page.goto('/admin/_design');
    await waitForLiveViewReady(page);
  });

  for (const boardId of [...COMPONENT_BOARDS, ...GROUP_BOARDS]) {
    test(`board: ${boardId}`, async ({ page }, testInfo) => {
      await assertBoardScreenshot(page, testInfo, boardId);
    });
  }
});
```

**What differs from checkpoints spec:**
- `toHaveScreenshot` is called on `page.locator(`#${boardId}`)` (element-scoped), not on `page` (full-page). This is the defining structural difference.
- No `captureAndVerify` wrapper — gallery boards use `toHaveScreenshot` directly (no separate reviewer artifact attachments needed, visual regression is the artifact).
- Loops over board IDs rather than a single monolithic test journey.
- `notice_link` is absorbed into `board-notice` (not a separate board ID) to keep the combined canary board intact and avoid a fragile standalone link board.

---

### `test/example/priv/playwright/playwright.config.ts` (EDIT — 3 new projects)

**Analog:** Same file, lines 83-138 (existing `chromium`, `mobile`, and `admin-checkpoints-*` project defs).

**Existing `ADMIN_CHECKPOINTS_SPEC` const pattern** (lines 26-27) — clone for design:
```typescript
const ADMIN_CHECKPOINTS_SPEC = /admin-checkpoints\.spec\.ts/;
// Add alongside it:
const ADMIN_DESIGN_SPEC = /admin-design\.spec\.ts/;
```

**Existing `chromium` project testIgnore** (line 84) — add `ADMIN_DESIGN_SPEC`:
```typescript
{
  name: 'chromium',
  testIgnore: [ADMIN_CHECKPOINTS_SPEC, ADMIN_GENERATED_SPEC, DEMO_SHOWCASE_SPEC, ADMIN_DESIGN_SPEC],
  use: { ...devices['Desktop Chrome'] },
},
```

**Existing `mobile` project testIgnore** (lines 93-100) — add `ADMIN_DESIGN_SPEC`:
```typescript
{
  name: 'mobile',
  testIgnore: [
    ADMIN_BEHAVIOR_SPECS,
    ADMIN_CHECKPOINTS_SPEC,
    ADMIN_GENERATED_SPEC,
    WEBAUTHN_CDP_SPECS,
    DEMO_SHOWCASE_SPEC,
    ADMIN_DESIGN_SPEC,
  ],
  use: { ...devices['iPhone 13'] },
},
```

**Three new projects** — clone from `admin-checkpoints-{chromium,mobile,dark}` (lines 107-138):
```typescript
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

**Snapshot path template** (line 60-61 — unchanged, no edit required):
```typescript
pathTemplate: '{testDir}/{testFilePath}-snapshots/{arg}{-projectName}{ext}'
```
This template causes `toHaveScreenshot('board-notice.png')` in project `admin-design-chromium` to land at `tests/admin-design.spec.ts-snapshots/board-notice-admin-design-chromium.png`.

---

### `test/example/priv/playwright/snapshot-allowlist-design` (NEW)

**Analog:** `test/example/priv/playwright/snapshot-allowlist` (exact format copy)

**Content** (copy the comment header, change the canary name reference):
```
# Intended-delta snapshot slugs for the admin-design Playwright baselines.
#
# One slug per line. A slug covers all three projects at once
# (chromium / mobile / dark) — e.g. `board-notice` allows
# board-notice-admin-design-{chromium,mobile,dark}.png to change.
#
# STEADY STATE: this file is empty (comments only). scripts/ci/snapshot-canary-guard.sh
# fails CI if any baseline PNG changes whose slug is not listed here, so a PR that
# deliberately re-records baselines MUST add the slug(s) in the same diff.
# Reset to empty once the re-recording PR merges.
#
# The `board-notice` canary must NEVER appear here.
#
```

---

### `scripts/ci/snapshot-canary-guard.sh` (EDIT — slug_of extension)

**Analog:** Same file, lines 53-55 (current `slug_of()`)

**Current `slug_of()`** (lines 53-55):
```bash
slug_of() {
  basename "$1" | sed -E 's/-admin-checkpoints-(chromium|mobile|dark)\.png$//'
}
```

**Option A (recommended): second invocation in CI** — leave `slug_of()` unchanged; the design-lane guard runs as a separate script invocation with overridden env vars. No change to this file under Option A.

**Option B: generalize `slug_of()`** (one-line sed change):
```bash
slug_of() {
  basename "$1" | sed -E \
    's/-admin-checkpoints-(chromium|mobile|dark)\.png$//;
     s/-admin-design-(chromium|mobile|dark)\.png$//'
}
```

RESEARCH.md recommends Option A to avoid sed-alternation ordering risk. The planner picks; pattern for both is shown above.

**Default env values already accepted by the guard** (lines 17-20):
```bash
SNAP_DIR="${SNAP_DIR:-test/example/priv/playwright/tests/admin-checkpoints.spec.ts-snapshots}"
ALLOWLIST="${ROOT}/test/example/priv/playwright/snapshot-allowlist"
BASE="HEAD"
CANARY="impersonation-banner"
```
Design-lane overrides for the second invocation:
```bash
SNAP_DIR="test/example/priv/playwright/tests/admin-design.spec.ts-snapshots" \
bash scripts/ci/snapshot-canary-guard.sh \
  --base "$BASE_REF" \
  --allowlist test/example/priv/playwright/snapshot-allowlist-design \
  --canary board-notice
```

---

### `scripts/ci/snapshot-recapture-gate.sh` (EDIT — design lane block)

**Analog:** Same file, lines 30-38 (existing two-step checkpoints + guard pattern)

**Existing two-step pattern** (lines 30-38):
```bash
echo "snapshot-recapture-gate: (a) compare-mode admin checkpoints across 3 projects"
( cd "$PW" && CI=true SIGRA_EXAMPLE_URL="$SIGRA_EXAMPLE_URL" \
    npx playwright test tests/admin-checkpoints.spec.ts \
      --project=admin-checkpoints-chromium \
      --project=admin-checkpoints-mobile \
      --project=admin-checkpoints-dark )

echo "snapshot-recapture-gate: (b) drift/canary guard (only intended slugs changed, and all did)"
bash "${ROOT}/scripts/ci/snapshot-canary-guard.sh" --base HEAD --require-all "${ALLOW_ARGS[@]}"
```

**Design-lane block to add** (after step (b), before step (c)):
```bash
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

---

### `scripts/ci/quality-ledger-monotonic.sh` (NEW)

**Analog:** `scripts/ci/snapshot-canary-guard.sh` (full file — conventions to mirror)

**Conventions to copy from analog** (lines 1-38):
```bash
#!/usr/bin/env bash
# [phase comment header]
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
```

**Flag parsing pattern** (analog lines 24-33):
```bash
while [[ $# -gt 0 ]]; do
  case "$1" in
    --base) BASE="$2"; shift 2;;
    *) echo "quality-ledger-monotonic: FAIL: unknown arg: $1" >&2; exit 2;;
  esac
done
```

**`fail()` helper** (analog lines 35-38):
```bash
fail() {
  echo "quality-ledger-monotonic: FAIL: $*" >&2
  exit 1
}
```

**exit 1 on violation / exit 2 on usage error** (analog lines 111-115 + 31-32):
```bash
# exit 2 for bad args (in flag parsing case above)
# exit 1 for violations:
if [[ "$violations" -ne 0 ]]; then
  exit 1
fi
echo "quality-ledger-monotonic: PASS (${#HEAD_TIERS[@]} cells checked vs ${BASE})"
```

**Tier extraction function** (net-new logic; `gawk` `gensub()` available on ubuntu-latest):
```bash
extract_tiers() {
  grep -E '^\| [a-z]' | awk -F'|' '{
    item=gensub(/^ +| +$/, "", "g", $2)
    tier=gensub(/^ +| +$/, "", "g", $4)
    if (tier ~ /^[012]$/) print item ":" tier
  }'
}
```

**Initial-commit edge case** (no base ledger exists → skip, exit 0):
```bash
while IFS=: read -r item tier; do
  BASE_TIERS["$item"]="$tier"
done < <(git -C "$ROOT" show "${BASE}:${LEDGER}" 2>/dev/null | extract_tiers)

if [[ ${#BASE_TIERS[@]} -eq 0 ]]; then
  echo "quality-ledger-monotonic: INFO: no base tiers at ${BASE}:${LEDGER} — skipping (initial commit)"
  exit 0
fi
```

**Per-cell monotonic check** (net-new; `"$head_tier" -lt "$base_tier"` is the core predicate):
```bash
for item in "${!HEAD_TIERS[@]}"; do
  head_tier="${HEAD_TIERS[$item]}"
  base_tier="${BASE_TIERS[$item]:-}"
  if [[ -n "$base_tier" && "$head_tier" -lt "$base_tier" ]]; then
    echo "quality-ledger-monotonic: FAIL: tier decreased for '${item}': ${base_tier} → ${head_tier}" >&2
    violations=1
  fi
done
```

---

### `.github/workflows/ci.yml` (EDIT — new job + ci-gate extension)

**Analog:** Same file, lines 1095-1166 (`snapshot_drift_guard` job and `ci-gate` aggregator)

**`snapshot_drift_guard` job** (lines 1095-1114) — new `quality_ledger_monotonic` job clones this shape exactly:
```yaml
snapshot_drift_guard:
  name: Snapshot drift guard (canary allowlist)
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
    - name: Run snapshot canary / drift allowlist guard
      run: bash scripts/ci/snapshot-canary-guard.sh --base "${{ steps.base.outputs.ref }}"
```

**New `quality_ledger_monotonic` job** (clone the above; swap final step):
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

**Design-lane Playwright run step** (add to `example_playwright_smoke` job; mirrors the checkpoints run step pattern at ci.yml ~lines 800-822):
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

**Design-lane canary guard step** (add to `snapshot_drift_guard` job after the existing checkpoints guard step at line 1114):
```yaml
- name: Run snapshot canary / drift guard — design lane
  run: |
    SNAP_DIR="test/example/priv/playwright/tests/admin-design.spec.ts-snapshots" \
    bash scripts/ci/snapshot-canary-guard.sh \
      --base "${{ steps.base.outputs.ref }}" \
      --allowlist test/example/priv/playwright/snapshot-allowlist-design \
      --canary board-notice
```

**`ci-gate` `needs:` extension** (lines 1119-1128 — add one entry):
```yaml
needs:
  - install_golden_contract
  - library_tests
  - library_tests_dep_off
  - install_smoke
  - upgrade_smoke
  - example_http_smoke
  - example_playwright_smoke
  - generated_admin_playwright_smoke
  - snapshot_drift_guard
  - quality_ledger_monotonic    # ADD
```

**`ci-gate` `env:` block** (lines 1132-1141 — add one line):
```yaml
QUALITY_LEDGER_MONOTONIC: ${{ needs.quality_ledger_monotonic.result }}
```

**`ci-gate` loop** (lines 1145-1154 — add one entry):
```
QUALITY_LEDGER_MONOTONIC \
```

---

### `guides/reference/admin-quality-ledger.md` (NEW)

**Analog:** `guides/reference/admin-design-contract.md` (sibling — same directory, same Markdown authoring conventions)

**Machine-parseable table format** (from RESEARCH.md Pattern 9). Tier column (column 4, 1-indexed in `|`-delimited table) must contain only `0`, `1`, or `2` with no surrounding whitespace variations:
```markdown
| item | level | tier | evidence |
|------|-------|------|----------|
| stat | L1 | 1 | [components_test.exs](../../test/sigra/admin/components_test.exs) |
| stat_link | L1 | 1 | [components_test.exs](../../test/sigra/admin/components_test.exs) |
...
| mg-1-metric-strip | L2 | 1 | [admin-design.spec.ts board-mg-1](#) |
...
| index-live | L3 | 1 | [admin-checkpoints: global-overview](#) |
...
```

All 13 L1 component rows + MG-1..MG-5 L2 rows + 6 L3 page rows start at tier `1` (Ratified baseline per D-12).

**Tier extraction one-liner** (how the monotonic guard reads it):
```bash
grep -E '^\| [a-z]' guides/reference/admin-quality-ledger.md \
  | awk -F'|' '{
      item=gensub(/^ +| +$/, "", "g", $2)
      tier=gensub(/^ +| +$/, "", "g", $4)
      if (tier ~ /^[012]$/) print item ":" tier
    }'
```

---

### `guides/reference/admin-fractal-scorecard.md` (NEW)

**Analog:** `guides/reference/admin-design-contract.md` (sibling — Markdown reference doc, heading → table format)

**Structure** (D-17/D-18 content; standalone file, not embedded in ledger):
- Preamble: one paragraph explaining the rubric is the grading anchor for phases 186-192
- "Shared Dimensions (D1–D11)" section — one subsection per dimension, `Pass / Fail / N-A` with one-line evidence requirement
- "Per-Level Add-ons" section — one subsection each for Component (L1), Group (L2), Page (L3), Flow (L4)
- "Tier Vocabulary" section — `0 Drift / 1 Ratified / 2 Award-grade` definitions
- Cross-reference: `See admin-design-contract.md for per-component ARIA and motion specs`

---

### `test/sigra/installer/design_gallery_isolation_test.exs` (NEW)

**Analog:** `test/sigra/install/template_syntax_test.exs` (same `Path.wildcard` over installer template tree + ExUnit assert pattern)

**`template_syntax_test.exs` pattern** (lines 1-67 — module structure and wildcard approach):
```elixir
defmodule Sigra.Install.TemplateSyntaxTest do
  use ExUnit.Case, async: true

  @moduletag :install

  @template_root "priv/templates/sigra.install"

  describe "HEEx-inside-EEx guard" do
    for path <- Path.wildcard(Path.join([@template_root, "**", "*.ex"])) do
      @path path
      test "no raw EEx tags inside ~H heredocs: #{@path}" do
        content = File.read!(@path)
        ...
        refute Regex.match?(@raw_eex_re, body), "#{@path} ..."
      end
    end
  end
end
```

**Gallery isolation test** — mirrors the wildcard + assert shape but uses a single `Path.wildcard` over all template files:
```elixir
defmodule Sigra.Installer.DesignGalleryIsolationTest do
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

**Key differences from analog:**
- No `@moduletag :install` (this test needs no Postgres and should run in the default `mix test` suite without tag filtering)
- Single test (not a macro-generated `for` loop) because the check is holistic (any path containing "design")
- `assert offenders == []` rather than `refute` — more readable failure message format

---

## Shared Patterns

### Dev-only compile gate
**Source:** `test/example/lib/example_web/router.ex` lines 172-182
**Apply to:** Gallery route (inside `if Application.compile_env(:example, :dev_routes)` block)
```elixir
if Application.compile_env(:example, :dev_routes) do
  # ... existing dev scopes ...

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
end
```

### Admin shell wiring (layout at router level, not in render/1)
**Source:** `test/example/lib/example_web/router.ex` lines 249-263
**Apply to:** Gallery `live_session` definition
The `layout: {ExampleWeb.Layouts, :admin}` is set in the `live_session` block. The gallery `render/1` must NOT wrap its content in `<Layouts.app ...>` — the shell is already applied. This is the opposite of `CredentialsLive` (which uses `<Layouts.app ...>` explicitly because it has no live_session shell).

### Guard script conventions
**Source:** `scripts/ci/snapshot-canary-guard.sh` lines 1-38
**Apply to:** `scripts/ci/quality-ledger-monotonic.sh`
```bash
#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# ... variables ...
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
```

### ci-gate base-ref resolution
**Source:** `.github/workflows/ci.yml` lines 1102-1112
**Apply to:** New `quality_ledger_monotonic` job
```yaml
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
```

### Axe a11y helper (copy verbatim)
**Source:** `test/example/priv/playwright/tests/admin-checkpoints.spec.ts` lines 114-126
**Apply to:** `admin-design.spec.ts`
Do not modify this function. Copy it as-is into the new spec.

### Snapshot diff thresholds (copy verbatim)
**Source:** `test/example/priv/playwright/tests/admin-checkpoints.spec.ts` lines 142-146
**Apply to:** `assertBoardScreenshot` in `admin-design.spec.ts`
```typescript
const ci = process.env.CI === 'true';
// maxDiffPixels:     ci ? 200_000 : dark ? 75_000 : mobile ? 45_000 : 30_000
// maxDiffPixelRatio: ci ? 0.22    : dark ? 0.1    : mobile ? 0.08   : 0.06
```

---

## No Analog Found

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| `guides/reference/admin-quality-ledger.md` | reference doc (machine-parseable) | — | No existing machine-parseable tier table in the codebase; the sibling docs (`admin-design-contract.md`, `admin-ui-principles.md`) are human-readable Markdown without integer-cell constraints |
| `guides/reference/admin-fractal-scorecard.md` | reference doc (rubric) | — | No existing dimension rubric file; content is specified by CONTEXT.md D-17/D-18 and the upstream milestone plan |

---

## Verification Warnings

1. **`test/example/lib/example_web/live/admin/` does not exist yet.** The executor must `mkdir -p` that directory before writing `design_gallery_live.ex`.

2. **`test/sigra/installer/` does not exist yet** (the existing installer tests are under `test/sigra/install/`). The D-04 guard is named `test/sigra/installer/design_gallery_isolation_test.exs` per CONTEXT.md. Executor should either create the directory or place the test under `test/sigra/install/` (closer to analog). The planner should decide; both directories compile into `mix test`.

3. **`snapshot-allowlist-design` canary line:** The comment header must say "The `board-notice` canary must NEVER appear here" (not `impersonation-banner`) to match the design lane.

4. **Playwright session fixtures path:** The `beforeAll` session storage path (`fixtures/admin-design-session.json`) should mirror whatever path the checkpoints spec uses. Verify the exact fixtures dir path from `admin-checkpoints.spec.ts` line 160+ before writing the design spec.

5. **`ci-gate` checkout action pin:** The `actions/checkout` SHA used in `snapshot_drift_guard` (line 1086) is `df4cb1c069e1874edd31b4311f1884172cec0e10`. Use the same SHA in the `quality_ledger_monotonic` job for consistency.

---

## Metadata

**Analog search scope:** `test/example/`, `test/sigra/`, `scripts/ci/`, `.github/workflows/`, `guides/reference/`
**Files read:** 11 source files verified (all analog paths confirmed to exist before citation)
**Pattern extraction date:** 2026-06-14
