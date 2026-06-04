# Phase 157: Overview Landings (Highest Effort) — Research

**Researched:** 2026-06-04
**Domain:** Phoenix LiveView visual redesign + Playwright checkpoint authoring
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **D-01:** LAND-04 via `connected?(socket)`-gate deferred load in `mount/3`. No `assign_async/3`, no `Task`/`handle_info`. Two states only: skeleton (disconnected) → data (connected). Queries run inline on connected mount.
- **D-02:** `aria-busy="true"` on the skeleton's containing `<section>`. Alarm `role="status"` via `:rest` is valid (post-load dynamic) — do NOT add always-on live-region to load-present markup.
- **D-03:** Alarm built from `<.notice>` with no new CSS class. Position (top of stack) + existing `sg-notice[data-tone="risk"]` treatment IS the prominence. If judged insufficient: escalate lock exception, do not invent `sg-alarm`.
- **D-04:** Identical front-door archetype for both screens: (1) `sg-page-header` → (2) alarm `<.notice>` → (3) `task_card` grid → (4) demoted `stat_link` posture strip → (5) capability matrix (Global only). `sg-status-pill` inside `sg-posture-strip__risk` anchor REMOVED from both strips.
- **D-05 (user-confirmed 2026-06-04):** Org keeps Members roster + Pending invitations as demoted "scoped detail" tail BELOW the shared front-door archetype.
- **D-06:** Two new Playwright slugs `global-overview` + `org-overview` added to the single authenticated journey in `admin-checkpoints.spec.ts`. Screenshot wait MUST go beyond `.phx-connected` and wait for real loaded data (not skeleton). 6 new committed PNGs total.
- **D-07:** Fold `2026-06-04-org-notice-nested-p.md` by keeping all `<.notice>` slot content inline. No block `<p>` children. Fixed structurally by removing the old Org "Scoped attention" card.

### Claude's Discretion

- Exact skeleton shapes/count per region.
- Alarm headline microcopy and count phrasing (within tone + deep-link requirements).
- Exact placement/markup of Org's demoted scoped-detail tail.
- Per-screen commit ordering; whether two redesigns land in one or two commits.
- Exact Playwright wait selector that proves "loaded, not skeleton."

### Deferred Ideas (OUT OF SCOPE)

- Loud, color/role-coded distinct treatment for the Global super-admin scope (token-layer work) — future milestone.
- Audit mobile + per-user audit reconciliation — Phase 158.
- Cross-journey coherence sweep + seed enrichment — Phase 159.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| LAND-01 | Needs-review alarm is the most prominent element above the task grid — loud when count > 0 (deep-linked), "all clear" when 0 | Verified: `<.notice tone={:risk\|:ok}>` as first child of `sg-stack--6` after the header; existing `sg-notice[data-tone="risk"]` CSS at `app.css:960-967,972-978` provides inset bar + risk-soft fill. Position drives prominence. |
| LAND-02 | Both Overviews lead with verb-first task cards; posture metrics demoted to secondary strip; capability matrix to lowest priority | Verified: D-04 archetype reorder. Current `index_live.ex` has task cards at `:39-58`, posture strip at `:60-95`, capability at `:97-111`. New order moves `<.notice>` alarm between header and task cards, moves task cards up, posture strip second. |
| LAND-03 | Global and Org share a consistent visual rhythm and archetype (differing task counts are acceptable) | Verified: byte-coherent items 1–4 across both screens (D-04/D-05). Org's scoped-detail tail is the only structural divergence — not a front-door archetype violation. |
| LAND-04 | Async overview data renders a loading skeleton instead of an empty flash or layout jump | Verified: `connected?(socket)` gate in `mount/3` per D-01. Skeleton shapes must match loaded content footprint for no layout jump. `aria-busy="true"` on containing section during load. |
</phase_requirements>

---

## Summary

Phase 157 is a visual redesign of two lib-owned LiveViews (`lib/sigra/admin/live/index_live.ex` and `lib/sigra/admin/live/organization_live.ex`) plus their first committed Playwright baselines. All decisions are locked in CONTEXT.md (D-01..D-07) and the design contract is locked in UI-SPEC.md. This research focuses entirely on the planning gaps those documents leave open: the validation architecture, the precise edit sequence and risk ordering, and the execution landmines.

The phase has **no new packages, no new CSS classes, no new components**. Every output is an edit to existing files. The risk surface is concentrated in four areas: (1) the `connected?`-gate two-mount semantics and how tests must account for the disconnected→connected transition, (2) the Playwright wait condition that proves "loaded, not skeleton" without being a perpetual flake, (3) the `aria-busy` / live-region interaction risk, and (4) the no-new-CSS-class boundary for the alarm.

**Primary planning guidance:** Split implementation into three ordered waves: (1) ExUnit-verifiable LiveView changes (both screens, loading states, archetype reorder, nested-`<p>` fold), (2) design-contract doc update (one-line Org-variant note per D-05), (3) Playwright baselines (record after ExUnit is green, not before). The Playwright wave cannot begin until the LiveView wave is complete — the skeleton makes the wait condition load-bearing, and premature baseline recording freezes a skeleton frame.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Deferred data load (LAND-04) | Frontend Server (LiveView) | — | `connected?` gate lives in `mount/3`; the two-state render is LiveView's own lifecycle, not a client-side concern |
| Alarm prominence (LAND-01) | Frontend Server (LiveView) | CSS layer | Position in the HEEx tree + existing `sg-notice[data-tone]` CSS treatment — no JS or client behavior |
| Archetype reorder (LAND-02/03) | Frontend Server (LiveView) | — | Pure HEEx restructuring within `render/1` |
| Skeleton shapes | Frontend Server (LiveView) | CSS layer | `<.skeleton>` shapes in HEEx; shimmer animation owned by `app.css:1421-1443` |
| `aria-busy` accessibility signal | Frontend Server (LiveView) | — | Set/remove as an HTML attribute on the `<section>` in the LiveView template |
| Playwright checkpoints | Test layer (Playwright) | — | New slugs added to `admin-checkpoints.spec.ts` journey |
| Design contract update | Documentation | — | One-line note in `guides/reference/admin-design-contract.md` |

---

## Validation Architecture

> `workflow.nyquist_validation` is `true` in `.planning/config.json` — this section is REQUIRED.

### Test Framework

| Property | Value |
|----------|-------|
| Framework | ExUnit (built-in) + Phoenix.LiveViewTest |
| Config file | `mix.exs` test configuration |
| Quick run command | `mix test test/sigra/admin/components_test.exs test/example/test/example_web/admin_shell_test.exs test/example/test/example_web/integration/phase_27_integration_test.exs` |
| Full suite command | `mix test` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| LAND-01 | Alarm `<.notice tone={:risk}>` is the first child after `sg-page-header`; `tone={:ok}` when `needs_review == 0` | LiveView render assertion (HTML offset order) | `mix test test/example/test/example_web/admin_shell_test.exs` | Existing test needs NEW assertions |
| LAND-01 | Alarm is NOT inside `sg-posture-strip__risk` (old location deleted) | LiveView render assertion (refute) | Same | Existing test needs NEW assertion |
| LAND-01 | Alarm deep-link `href` contains `?locked=true` | LiveView render assertion | Same | NEW assertions needed |
| LAND-02 | Task card grid appears BEFORE posture strip in rendered HTML | LiveView render assertion (HTML offset order) | Same | NEW assertions needed |
| LAND-02 | `sg-status-pill` inside `sg-posture-strip__risk` is ABSENT | LiveView render assertion (refute) | Same | NEW assertions needed |
| LAND-03 | Both screens emit identical class sequence for items 1–4 of the archetype | render_component golden OR structural assertion | `mix test test/sigra/admin/components_test.exs` | NEW test in components_test.exs OR admin_shell_test.exs |
| LAND-04 | `sg-skeleton` appears on disconnected (HTTP GET) render | ConnCase GET + `html_response` assertion | `mix test test/example/test/example_web/admin_shell_test.exs` | NEW test needed |
| LAND-04 | `sg-skeleton` is ABSENT on connected render (`live/2`) | LiveView `live/2` assertion | Same | NEW test needed |
| LAND-04 | `aria-busy="true"` present on skeleton, absent on loaded render | Both states | Same | NEW tests needed |
| LAND-04 | No layout jump: skeleton shapes match loaded footprint (posture strip stat count, Org: 3 data regions) | Visual (Playwright screenshot diff) | Playwright `admin-checkpoints` run | NEW — no ExUnit substitute |
| D-07 (nested-`<p>`) | No `<p>` inside `<.notice>` inner_block in either LiveView | axe gate in Playwright `assertNoAxeViolations` | Playwright `admin-checkpoints` run | NEW — first time these slugs run axe |
| Alarm live-region | `role="status"` on the alarm notice (via `:rest`) | LiveView render assertion | Same | NEW assertion needed |
| Parity lane | `admin-generated` lane stays green | Playwright `admin-generated.spec.ts` | `npx playwright test tests/admin-generated.spec.ts --project admin-generated` | Existing — must stay green |
| Checkpoint baselines | `global-overview.png` + `org-overview.png` × 3 projects exist and are non-empty | `captureAndVerify` in Playwright | Playwright `admin-checkpoints` run | NEW — 6 PNGs to be committed |

### How to Prove LAND-04 Distinctly (the hardest requirement)

**The core problem:** `connected?` in Phoenix.LiveViewTest's `live/2` is always `true` after mount. A test using `live/2` sees only the connected state. The only way to observe the disconnected (skeleton) state in ExUnit is via an HTTP GET through `ConnCase`.

**Two-mount semantics in tests:**

| Test method | `connected?(socket)` | What renders |
|-------------|---------------------|--------------|
| `conn |> get("/admin")` → `html_response/2` | `false` (HTTP mount) | skeleton state (`loading: true`) |
| `conn |> live("/admin")` → `{:ok, _view, html}` | `true` (WS mount) | data state (`loading: false`) |

This is NOT a bug — it is the correct test split. Use ConnCase GET to assert the skeleton state, LiveViewTest `live/2` to assert the data state. Both must exist for LAND-04 to be provable.

**Specific assertions to distinguish "done" from "looks done":**

```
# Skeleton state (disconnected — HTTP GET)
html = conn |> log_in_user(admin) |> get("/admin") |> html_response(200)
assert html =~ "sg-skeleton"
assert html =~ ~s(aria-busy="true")
refute html =~ "sg-metric-link__value"  # stat_link values not yet present

# Data state (connected — LiveView live/2)
{:ok, _view, html} = conn |> log_in_user(admin) |> live("/admin")
refute html =~ "sg-skeleton"
refute html =~ ~s(aria-busy="true")
assert html =~ "sg-metric-link__value"  # stat_link values present
assert html =~ "sg-notice"              # alarm present
```

The `sg-metric-link__value` presence/absence toggle is the clearest binary proof that the deferred load fired. If the test only asserts `sg-skeleton` on GET and not the absence on `live/2`, the implementation could synchronously load everything and still pass the first assertion.

### How the Playwright Wait Proves "Loaded, Not Skeleton"

The load-bearing wait for D-06 is:
```typescript
// After waitForLiveViewReady (proves .phx-connected):
await expect(page.locator('.sg-metric-link__value').first()).toBeVisible();
// THEN capture + screenshot
await captureAndVerify(page, testInfo, 'global-overview');
await assertCheckpointScreenshot(page, testInfo, 'global-overview');
```

`waitForLiveViewReady` alone only proves the WebSocket connected — the skeleton state IS displayed with a connected socket during the skeleton render frame. The `sg-metric-link__value` visibility wait proves the connected mount completed and replaced the skeleton with data. Any `stat_link` value element is guaranteed absent in the skeleton state (skeletons replace the entire stat strip content) and present in the data state.

For `org-overview`, the same pattern applies using any `.sg-metric-link__value` within the posture strip.

**Why not wait for `aria-busy` to disappear?** `aria-busy="false"` is not set — the attribute is REMOVED when loading ends. `page.waitForSelector('[aria-busy]', {state: 'detached'})` would work but is fragile to selector scope. The `sg-metric-link__value` visibility wait is cleaner and tests the actual content.

### Sampling Rate

- **Per task commit:** `mix test test/sigra/admin/components_test.exs test/example/test/example_web/admin_shell_test.exs test/example/test/example_web/integration/phase_27_integration_test.exs`
- **Per wave merge:** `mix test`
- **Phase gate:** Full `mix test` green + Playwright `admin-checkpoints` (×3 projects) green before `/gsd:verify-work`

### Wave 0 Gaps

The following test additions are needed before the implementation is complete (they do NOT exist today):

- [ ] `test/example/test/example_web/admin_shell_test.exs` — add `describe "Phase 157 Overview redesign"` block with:
  - ConnCase GET `/admin` → skeleton assertions (LAND-04 disconnected)
  - ConnCase GET `/admin/organizations/:slug` → skeleton assertions (LAND-04 Org disconnected)
  - `live/2` `/admin` → data state assertions (LAND-04 connected)
  - `live/2` `/admin/organizations/:slug` → data state assertions
  - Archetype order assertions (task cards before posture strip) for both screens (LAND-02)
  - Alarm position assertion (notice before task grid) for both screens (LAND-01)
  - `refute html =~ "sg-posture-strip__risk"` — confirms old alarm anchor removed (LAND-01 cleanup)
  - `refute html =~ "sg-skeleton"` on connected render (LAND-04 no-skeleton-in-data)
  - `assert html =~ ~s(role="status")` on alarm notice in connected render (D-02 live-region)

No gaps in `components_test.exs` — that file tests the shared components only, and none of those components change in this phase.

No new test file is needed — all new assertions live in the existing `admin_shell_test.exs` which already tests both Overview screens via ConnCase.

---

## Edit Sequence and Risk Ordering

The edit dependency graph has one hard constraint: **Playwright baselines cannot be recorded until LiveView changes are complete and ExUnit is green**. Within that, the two LiveView edits are independent of each other but share the same structural pattern.

### Wave 1 — LiveView Changes (ExUnit-verifiable; no Playwright yet)

**Order within Wave 1 is risk-ordered (highest-risk edit first):**

**1a. `lib/sigra/admin/live/index_live.ex` — Global Overview redesign**

Edits (all within one file, `mount/3` + `render/1`):

1. Split `mount/3` into disconnected/connected branches using `connected?(socket)` gate.
   - Disconnected path: assign `loading: true`, `summary_counts: %{}`. Do NOT call `Query.summary_counts/2`.
   - Connected path: call `Query.summary_counts/2`, assign `loading: false` with data.
   - Risk: `runtime_config!()` is called before the gate — must remain outside it (needed for both paths). The `admin_scope` assign is always available from `on_mount` hooks.

2. Update `render/1` to branch on `@loading`:
   - Add `<.notice>` alarm as first child after the `sg-page-header`, with `role="status"` via `:rest` for D-02.
   - Add skeleton shapes for the posture strip stat region when `loading: true`: replace the `<.stat_link>` cluster with `<.skeleton>` shapes matching the 6 stat_link footprints.
   - Remove the `sg-posture-strip__risk` anchor block (lines `:61-65`).
   - When `loading: true`: add `aria-busy="true"` to the posture strip `<section>`.
   - Promote `task_card` grid to appear BEFORE the posture strip section (move the `<div class="sg-grid sg-grid--3">` block up, above the `<.notice>` alarm but below it in the archetype order).

   Wait — the correct archetype order from D-04/UI-SPEC is:
   1. `sg-page-header` (unchanged)
   2. `<.notice>` alarm (NEW — before task cards)
   3. `task_card` grid (MOVED up from current position; currently second)
   4. posture strip (MOVED down; currently before capability)
   5. capability matrix (unchanged position relative to strip)

   Current `index_live.ex` order: header → task cards → posture strip → capability. The task cards are ALREADY second in the current file (lines `:39-58`). The only reorder needed is inserting the alarm BEFORE the task cards, and the posture strip is already below. The archetype is almost right — the task cards just need the alarm above them.

3. Update `needs_review/1` helper — no change needed; it already computes `locked + deleted`.

**1b. `lib/sigra/admin/live/organization_live.ex` — Org Overview redesign**

Edits (all within one file, `mount/3` + `render/1`):

1. Split `mount/3` into disconnected/connected branches:
   - Disconnected: assign `loading: true`, `summary_counts: %{}`, `members: []`, `pending_invitations: []`. Assign `organization_name` (safe synchronous call). Do NOT call `Query.summary_counts/2`, `Detail.member_roster/2`, or `Detail.pending_invitations/2`.
   - Connected: all three queries inline, assign `loading: false`.
   - Risk: `organization_name/1` must work without a DB call — it reads from `admin_scope.organization.name` or slug, which is already assigned by the `on_mount` hooks. Confirmed safe: `organization_name/1` at lines `:187-189` only reads struct fields, no DB.

2. Update `render/1`:
   - Remove the old "Scoped attention" card entirely (`organization_live.ex:59-84`). This is the D-07 fix — the nested-`<p>` `<.notice>` at lines `:73-78` disappears with it.
   - Add `<.notice>` alarm as first child after `sg-page-header`, same pattern as Global, with `role="status"` via `:rest`.
   - Skeleton shapes for loading state: need to cover posture strip stat region + members roster section + pending invitations section (3 deferred-data regions). Add `aria-busy="true"` to the section wrapping these three regions, or to each section individually.
   - The task card grid is already first (lines `:44-57`) — it moves up to AFTER the alarm (same as Global).
   - Remove the `sg-posture-strip__risk` anchor block (lines `:86-94`).
   - Keep Members roster (`:125-141`) and Pending invitations (`:143-162`) as the demoted tail, with visual hierarchy cues that read as clearly secondary.

**1c. Design-contract doc update**

Edit `guides/reference/admin-design-contract.md` — Overview Archetype section (around line 135-167):
- Update the "Current component composition" block to reflect the new archetype order.
- Add one-line Org-variant note per D-05: "Org appends a demoted scoped-detail tail: members + pending invitations — below the shared front-door archetype."
- This is low-risk, text-only, and does not affect ExUnit or Playwright.

### Wave 2 — ExUnit Test Additions

Add the Wave 0 test assertions to `test/example/test/example_web/admin_shell_test.exs`. Run `mix test` to green-gate before proceeding to Playwright.

### Wave 3 — Playwright Baselines

Only after Wave 1 + Wave 2 are ExUnit-green:

1. Verify the `org-overview` route renders `OrganizationLive` (not the comment-referenced "org landing stub" at `admin-checkpoints.spec.ts:202`). The route `/admin/organizations/:slug` maps to `OrganizationLive` per `router.ex:287` — confirmed correct. The comment at line 202 in the spec refers to a different checkpoint (`org-scoped-admin`) that navigated to `/admin/organizations/:slug/users` instead of `/` to avoid the stub. After this phase, the redesigned `/admin/organizations/:slug` IS the correct target.

2. Add to `admin-checkpoints.spec.ts`, BEFORE the org-scoped-admin checkpoint (to keep journey order logical):

```typescript
// --- Checkpoint N: Global overview (/admin) -----------------------------------
await page.goto('/admin');
await waitForLiveViewReady(page);
// Wait for loaded data, not skeleton frame (D-06 hard requirement)
await expect(page.locator('.sg-metric-link__value').first()).toBeVisible();
await expect(page.locator('.sg-notice').first()).toBeVisible();
await captureAndVerify(page, testInfo, 'global-overview');
await assertCheckpointScreenshot(page, testInfo, 'global-overview');

// --- Checkpoint N+1: Org overview (/admin/organizations/:slug) ---------------
await page.goto(`/admin/organizations/${orgSlug}`);
await waitForLiveViewReady(page);
await expect(page.locator('.sg-metric-link__value').first()).toBeVisible();
await expect(page.locator('.sg-notice').first()).toBeVisible();
await captureAndVerify(page, testInfo, 'org-overview');
await assertCheckpointScreenshot(page, testInfo, 'org-overview');
```

3. Run `--update-snapshots` for only the two NEW slugs to commit the initial PNGs. **Do NOT pass `--update-snapshots` globally** — that would re-record the existing 5 slugs. Use the slug-specific approach or record with `--grep "global-overview|org-overview"`.

4. Commit the 6 new PNGs (`global-overview-admin-checkpoints-{chromium,mobile,dark}.png` × 2 slugs) to `test/example/priv/playwright/tests/admin-checkpoints.spec.ts-snapshots/`.

---

## Landmines

### Landmine 1: Nested-`<p>` Survival Path

**What goes wrong:** The old Org "Scoped attention" card at `organization_live.ex:59-84` contains `<.notice tone={...}>` at lines `:73-78` with two block `<p>` children, producing invalid `<p><p>…</p></p>`. D-07 resolves this by removing the entire card. The landmine: if the executor removes the card but inadvertently carries forward any block `<p>` child in the NEW top-of-page alarm notice, the axe violation reappears.

**How to avoid:** The new alarm's inner content must be inline only: text node + optional inline `<a>` or `<span>`. Never `<p>` as a direct child of `<.notice>`. The `notice/1` component at `components.ex:302-306` wraps the slot in `<p class="sg-text-sm">` — any block element child makes it `<p><p>…</p></p>`.

**Warning sign:** `axe:org-overview` violation `nested-interactive` or `duplicate-id` — but more likely axe's `wcag_412` for invalid HTML. The violation will show in `assertNoAxeViolations` output.

**Hard-fail signal:** If `axe:org-overview` shows any violation at all, check the notice content first.

---

### Landmine 2: Perpetual-Flake Baseline from Skeleton Screenshot

**What goes wrong:** If the Playwright wait condition is `waitForLiveViewReady` only (`.phx-connected` selector), the screenshot may freeze the skeleton frame. The WebSocket connection establishes BEFORE the connected `mount/3` has finished running its queries — there's a brief window where `.phx-connected` is set but the DOM still shows the skeleton. On longpoll transport (the example app's MIX_ENV=dev fallback), this window is larger.

**How to avoid:** The wait MUST include a content-visible assertion after `waitForLiveViewReady`. The plan above uses `.sg-metric-link__value` visibility. The 15,000ms `expect.timeout` configured in `playwright.config.ts:55` is sufficient for the query + render cycle.

**Warning sign:** Two consecutive runs of the checkpoint spec produce diff PNGs where one shows skeleton shapes and one does not — a `maxDiffPixels` violation on an otherwise-identical page.

---

### Landmine 3: Inert Live-Region Duplicate Announcement

**What goes wrong:** Adding `role="status"` to the alarm `<.notice>` on the connected mount is valid per D-02 because the count is dynamically loaded. But if the same `role="status"` is accidentally applied to the disconnected (skeleton) mount — i.e., if the `role` is on the notice unconditionally and the notice renders an empty or loading message in the skeleton state — screen readers may announce the empty message and then the real message, causing a confusing double-read.

**How to avoid:** In the skeleton state, do NOT render the alarm `<.notice>` at all, or render it WITHOUT `role="status"`. The role should only be added via `:rest` in the connected state where the alarm has real content. Simplest pattern:

```heex
<.notice
  :if={not @loading}
  tone={if @needs_review > 0, do: :risk, else: :ok}
  role="status"
>
  ...inline alarm content...
</.notice>
```

OR render the notice in both states but pass `role="status"` only when `not @loading`:

```heex
<.notice
  tone={...}
  {if not @loading, do: [role: "status"], else: []}
>
```

**Warning sign:** axe `aria` violation on the `org-overview` or `global-overview` slug, or AT (VoiceOver/NVDA) testing shows double announcement.

---

### Landmine 4: The `sg-posture-strip__risk` Anchor Removal

**What goes wrong:** The current posture strip in both screens has `<a href="...?locked=true" class="sg-cluster sg-cluster--start sg-posture-strip__risk">` wrapping an `sg-status-pill`. This is the OLD alarm location. If the executor adds the new `<.notice>` alarm but forgets to remove this `sg-posture-strip__risk` anchor, both alarm elements coexist — visually confusing and semantically doubled.

**Exact lines to delete:**
- `index_live.ex:61-65`: the `<a class="sg-posture-strip__risk">` block
- `organization_live.ex:86-94`: the `<a class="sg-posture-strip__risk">` block

**Warning sign:** In the rendered HTML, `sg-posture-strip__risk` still appears. The test assertion `refute html =~ "sg-posture-strip__risk"` in Wave 0 will catch this.

---

### Landmine 5: Connected?-Gate Applied Incorrectly in `mount/3`

**What goes wrong:** The `connected?(socket)` check must be in `mount/3` — NOT in `handle_params/3` or any other callback. The precedent at `confirmation_live.ex:103` places the check in `handle_params/3` because that LV uses `live_action` routing. The Overview LVs use `mount/3` as the sole load site (confirmed by both LV files).

A second common error: calling `runtime_config!()` inside the `if connected?(socket)` branch. The config is needed to pass to the query functions, but the config call itself has a raise path (missing Application config) that should fire the same on both mounts, not only on connected.

**Correct structure:**

```elixir
def mount(_params, _session, socket) do
  config = runtime_config!()          # always — raises fast if misconfigured
  admin_scope = socket.assigns.admin_scope  # always
  organization_name = organization_name(admin_scope)  # always (no DB)

  socket =
    socket
    |> assign(:sigra_config, config)
    |> assign(:organization_name, organization_name)
    |> assign(:page_title, "#{organization_name} overview")

  if connected?(socket) do
    {:ok,
     socket
     |> assign(:loading, false)
     |> assign(:summary_counts, Query.summary_counts(config, admin_scope))
     |> assign(:members, Detail.member_roster(config, admin_scope))
     |> assign(:pending_invitations, Detail.pending_invitations(config, admin_scope))}
  else
    {:ok,
     socket
     |> assign(:loading, true)
     |> assign(:summary_counts, %{})
     |> assign(:members, [])
     |> assign(:pending_invitations, [])}
  end
end
```

**Warning sign:** A `KeyError` on `@summary_counts` in the skeleton render, or queries firing on the disconnected mount (visible by DB query count in test logs).

---

### Landmine 6: The `admin-generated` Parity Lane and Route Content Checks

**What goes wrong:** `admin-generated.spec.ts:83-87` has:
```typescript
await page.goto(`/admin/organizations/${allowedOrgSlug}`);
await expect(adminShellHeader(page)).toContainText(allowedOrgName);
await expect(page.locator("main")).toContainText(allowedOrgName);
```

After the redesign, the `main` contains the org name in both the page title (`<h1>`) and the scoped-detail tail — no change needed. But if the executor removes the `{@organization_name}` from the `<h1>` (the page title), this assertion fails.

Similarly, `admin_shell_test.exs:55-60` asserts:
- `html =~ "Organization overview"` (kicker — unchanged)
- `html =~ "Work inside this organization scope"` (page copy — unchanged)

These strings are in the `sg-page-header` which the archetype reorder preserves. But the assertion at line 60 `html =~ "Work inside this organization scope"` is in the `sg-page-copy` paragraph that is unchanged by the phase.

The assertion at `phase_27_integration_test.exs:38` is `html =~ organization.name` — safe, organization name persists in the redesign.

**Warning sign:** `admin-generated` parity lane fails with "could not find text" on the org overview page.

---

### Landmine 7: Dark-Mode Axe Parity

**What goes wrong:** The dark-mode project in `playwright.config.ts:131-138` uses `colorScheme: 'dark'` which triggers the CSS `prefers-color-scheme: dark` override block. The `sg-notice[data-tone="risk"]` colors in dark mode use `--sg-color-risk` #f8a39c and `--sg-color-risk-soft` rgba values (UI-SPEC Color section). If any hard-coded light hex was accidentally introduced (e.g., a `style=` attribute or an unlayered color rule), dark mode shows white-on-white or invisible text.

**How to avoid:** Never set `color:` or `background-color:` inline. Use only `data-tone={...}` on `<.notice>` and let the CSS layer resolve dark vs. light. The `sg-skeleton` shimmer is already `prefers-reduced-motion`-safe per `app.css:1463-1473` — no additional handling needed.

**Warning sign:** `axe:org-overview` in the `admin-checkpoints-dark` project reports a contrast ratio violation.

---

### Landmine 8: Skeleton Shapes Must Match Loaded Content Footprint (LAND-04 Intent)

**What goes wrong:** Using generic `<.skeleton class="h-8 w-full" />` blocks that don't match the stat_link count or the member roster row count produces a layout jump when data loads — which is the exact failure LAND-04 prohibits.

**Specific shape requirements:**

For Global Overview posture strip (6 stat_links):
- 6 skeleton shapes in the `sg-cluster sg-cluster--3` container, each matching the approximate dimensions of a `sg-metric-link` (a label + value stacked column).

For Org Overview:
- Posture strip: 5 stat_links (Total/Confirmed/MFA/Passkeys/Locked) → 5 skeleton shapes.
- Members section: 3 skeleton shapes as placeholder rows (fixed count is discretion — CONTEXT.md says "match loaded footprint" which means pick a representative count, e.g., 3).
- Pending invitations section: 2 skeleton shapes as placeholder rows.

The section headings ("Members", "Pending invitations") can remain visible during skeleton — only the list content needs skeletal placeholders.

**Warning sign:** Playwright screenshot diff between skeleton state and loaded state shows height change — the skeleton section is noticeably shorter or taller than the loaded section.

---

## Code Examples

### Verified Pattern: connected?-gate in mount/3

`[VERIFIED: test/example/lib/example_web/live/confirmation_live.ex:103]`

The actual precedent in this repo uses `connected?(socket)` in `handle_params/3`, not `mount/3`. For the Overview screens, the check goes in `mount/3` because there is no `handle_params` logic and the data load is not param-dependent. The pattern from `confirmation_live.ex:103-130` is:

```elixir
if connected?(socket) do
  # real work
else
  {:noreply, socket}  # or {:ok, socket} in mount
end
```

For `mount/3`, the return is `{:ok, socket}` in both branches (not `{:noreply, ...}`).

### Verified Pattern: aria-busy attribute in HEEx

`[ASSUMED — standard HTML/ARIA, no project precedent]`

The `aria-busy` attribute accepts strings `"true"` / `"false"` in HTML. In HEEx, pass as a boolean or string:

```heex
<section aria-busy={if @loading, do: "true"}>
```

When `@loading` is `false`, this produces `aria-busy="false"`. Per the accessibility contract, the attribute should be REMOVED (not set to `"false"`) when loading ends — use `:if` on the attribute or set it only when true:

```heex
<section {if @loading, do: ["aria-busy": "true"], else: []}>
```

Or more idiomatically in Phoenix >= 1.8 with `:rest`-style spread:

```heex
<section aria-busy={if @loading, do: "true"}>
```

Both patterns are acceptable — the `"false"` value is valid ARIA. The important thing is it changes.

### Verified Pattern: notice/1 inline content (no nested `<p>`)

`[VERIFIED: lib/sigra/admin/components.ex:302-306]`

`notice/1` wraps slot in `<p class="sg-text-sm">`. Pass inline content only:

```heex
<.notice tone={if @needs_review > 0, do: :risk, else: :ok} role="status">
  {@needs_review} accounts need review —
  <a href="/admin/users?locked=true">Review now</a>
</.notice>
```

NOT:

```heex
<.notice tone={:risk}>
  <p>Some content</p>  <%!-- WRONG: produces <p><p>…</p></p> --%>
</.notice>
```

### Verified Pattern: stat_link (for wait selector)

`[VERIFIED: lib/sigra/admin/components.ex:48-55]`

`stat_link/1` renders `<a class="sg-metric-link ..."><span class="sg-metric-link__label">...</span><span class="sg-metric-link__value">...</span></a>`. The Playwright wait selector `.sg-metric-link__value` uniquely identifies a loaded stat value.

---

## Existing Test Coverage Inventory

The following files contain assertions that will be affected by or must survive the Phase 157 changes. The planner must include explicit verification steps for each:

| File | Current assertions on Overview screens | Status after Phase 157 |
|------|----------------------------------------|------------------------|
| `test/example/test/example_web/admin_shell_test.exs:19-30` | `html =~ "What do you need to do?"`, `html =~ "Admin"`, `html =~ "Global"` | Unchanged — strings still present |
| `test/example/test/example_web/admin_shell_test.exs:49-63` | `html =~ "Organization overview"`, `html =~ "Work inside this organization scope"` | Unchanged |
| `test/example/test/example_web/integration/phase_27_integration_test.exs:22` | `html =~ "What do you need to do?"` | Unchanged |
| `test/example/test/example_web/integration/phase_27_integration_test.exs:38-40` | `html =~ "Admin"`, `html =~ organization.name`, `html =~ "Organization"` | Unchanged |
| `test/example/priv/playwright/tests/admin-generated.spec.ts:83-86` | `adminShellHeader` contains org name; `main` contains org name | Unchanged — org name in `<h1>` and tail |

**Strings that WILL change** (executor must verify these are gone or updated):

| String | Current location | Why it changes |
|--------|-----------------|----------------|
| `"Scoped attention"` | `organization_live.ex:62` | Old card removed in D-04 |
| `"Risk queue"` | `organization_live.ex:74` | Removed with old card |
| `"Evidence boundary"` | `organization_live.ex:80` | Removed with old card |
| `"sg-posture-strip__risk"` | Both files | Old alarm anchor removed |

If any existing test asserts these strings, they fail after the redesign and must be updated. **Current audit shows NO existing test asserts these specific strings** — `admin_shell_test.exs` asserts only the kicker/title/copy text which are in the `sg-page-header` (unchanged).

---

## Open Questions

1. **Skeleton shape for Org tail during loading**
   - What we know: the tail has Members + Pending invitations sections, each with unknown row counts at load time (the data is what the skeleton replaces).
   - What's unclear: what fixed placeholder row count to use for skeleton rows (discretion per CONTEXT.md, but must not cause layout jump).
   - Recommendation: Use 3 placeholder rows for Members and 2 for Pending invitations as representative defaults. These are "typical" small-org counts; the skeleton visually signals "content is coming" without implying an exact count.

2. **`aria-busy` scope in Org overview**
   - What we know: Global has one deferred region (posture strip). Org has three (posture strip + members + invitations).
   - What's unclear: should one top-level `aria-busy` cover all three deferred regions, or should each section have its own?
   - Recommendation: Single `aria-busy="true"` on the outermost container that wraps all three deferred sections (or on the outermost `<section class="sg-stack sg-stack--6">` element) is simpler and less verbose. The WAI-ARIA spec says `aria-busy` "indicates an element is being modified and that assistive technologies may want to wait until changes are complete before exposing them to the user" — one top-level annotation is correct.

3. **Journey position for the two new checkpoint slugs**
   - What we know: The existing journey seeds a target user + org, then logs in as admin. The global overview `/admin` renders for the admin immediately after login.
   - What's unclear: should the new slugs be captured at the start of the journey (right after login) or after checkpoint 1 (global user index)?
   - Recommendation: Capture `global-overview` immediately after the admin login (before navigating to `/admin/users?q=...`), then `org-overview` after the org is created and before `org-scoped-admin`. This is the most logical narrative flow — overview screens are natural entry points, not afterthoughts. The only dependency is the org being seeded (needed for `org-overview`) — capture `global-overview` first, then `org-overview` after `createOrganization`.

---

## Environment Availability

> Skip condition: no new external dependencies — this phase is pure code/config changes within an existing Phoenix project. The Playwright infrastructure is already installed and validated by Phase 155/156.

Step 2.6: SKIPPED — no new external dependencies. All tools (mix, Phoenix.LiveViewTest, Playwright) are already confirmed available from prior phases.

---

## Package Legitimacy Audit

> Not applicable — this phase installs zero new packages. No legitimacy gate required.

---

## Security Domain

> `security_enforcement` is not explicitly set to `false` in config — checking ASVS applicability.

| ASVS Category | Applies | Rationale |
|---------------|---------|-----------|
| V2 Authentication | No | No auth logic changed — Overview screens read-only aggregate data |
| V3 Session Management | No | No session changes |
| V4 Access Control | No | Admin scope is enforced by `on_mount` hooks (unchanged), not by the LiveView render |
| V5 Input Validation | No | No user input on Overview screens |
| V6 Cryptography | No | No crypto |
| V2.5 Credential Recovery | No | Not applicable |

The Overview screens contain no destructive actions, no user input, and no auth-sensitive mutations. The only security-relevant aspect is the alarm deep-link pointing to `/admin/users?locked=true` — this link navigates within the already-authenticated admin scope, which is enforced by existing `on_mount` hooks. No security changes required.

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `organization_name/1` (lines 187-189 in `organization_live.ex`) makes no DB call — safe to call on disconnected mount | Edit Sequence | If it did call DB, disconnected mount skips it and `@organization_name` would be unset, crashing the skeleton render |
| A2 | `.sg-metric-link__value` is guaranteed absent in skeleton state (skeleton replaces entire stat strip content) | Validation Architecture | If skeleton doesn't replace the stat cluster, the Playwright wait selector resolves immediately and freezes skeleton |
| A3 | No existing test asserts the strings "Scoped attention", "Risk queue", or "Evidence boundary" | Existing Test Coverage Inventory | If any test does assert these, it fails after Phase 157 and must be fixed |
| A4 | The `admin-generated` parity lane does not probe the Org Overview content beyond `containText(allowedOrgName)` | Landmine 6 | If it probes deleted strings, the parity lane fails |

A1 is HIGH confidence from direct code inspection (`organization_name/1` at `organization_live.ex:187-189` reads only struct fields). A2-A4 are HIGH confidence from direct test-file inspection.

---

## Sources

### Primary (HIGH confidence)

- `lib/sigra/admin/live/index_live.ex` — direct inspection, all line references verified
- `lib/sigra/admin/live/organization_live.ex` — direct inspection, all line references verified
- `lib/sigra/admin/components.ex` — direct inspection, notice/1 wrapper at lines 302-306 confirmed
- `test/example/priv/playwright/tests/admin-checkpoints.spec.ts` — direct inspection, `waitForLiveViewReady` at :40-44, journey pattern at :171-254
- `test/example/priv/playwright/playwright.config.ts` — direct inspection, 3 checkpoint projects confirmed
- `test/example/test/example_web/admin_shell_test.exs` — direct inspection, existing Overview assertions identified
- `test/example/test/example_web/integration/phase_27_integration_test.exs` — direct inspection
- `test/example/priv/playwright/tests/admin-generated.spec.ts` — direct inspection, org content assertion at :83-86
- `test/example/priv/playwright/tests/admin-checkpoints.spec.ts-snapshots/` — directory listing confirms 15 existing PNGs (5 slugs × 3 projects); no global-overview or org-overview yet
- `.planning/phases/157-overview-landings-highest-effort/157-CONTEXT.md` — locked decisions consumed
- `.planning/phases/157-overview-landings-highest-effort/157-UI-SPEC.md` — design contract consumed
- `guides/reference/admin-design-contract.md` — skeleton ARIA note at line 125 confirmed

### Secondary (MEDIUM confidence)

- WAI-ARIA APG: `role="status"` is valid for post-load dynamic content; `aria-busy` communicates in-progress updates — aligns with D-02 decisions

### Tertiary (LOW confidence)

None — all claims verified against codebase.

---

## Metadata

**Confidence breakdown:**

- Edit sequence: HIGH — based on direct file inspection of both LiveViews, all line numbers verified
- Test coverage gaps: HIGH — exhaustive grep across test tree confirmed no existing Overview LiveView test using `live/2`
- Playwright patterns: HIGH — `captureAndVerify` + `assertCheckpointScreenshot` pattern verified from existing spec
- Skeleton wait condition: HIGH — `sg-metric-link__value` absence in skeleton state derivable from the component code
- Landmines: HIGH — all derive from direct codebase evidence, not assumed patterns

**Research date:** 2026-06-04
**Valid until:** Phase 157 completion (short-lived — codebase-specific)
