---
phase: 232
slug: playwright-economics-authenticate-once-then-shard
status: approved
shadcn_initialized: false
preset: none
created: 2026-07-31
---

# Phase 232 — UI Design Contract

> Visual and interaction contract for Phase 232. This is CI and Playwright-test infrastructure work: it introduces **no user-facing UI surface**. The contract is preservation-focused and is binding on test changes that exercise existing admin surfaces.

---

## Phase UI Boundary

- Add no LiveView, route, component, CSS rule, design token, brand asset, control, user-facing copy, loading treatment, error treatment, or destructive flow.
- Do not alter the rendered `/admin/_design` gallery, its component-board fixtures, or existing application behavior in order to support test sharding or authentication reuse.
- Preserve the existing `sg-*` cascade-layer/BEM system, Rail Accent assets, and Light, Dark, and System support. Phase 232 changes test setup and CI topology only.
- The required GitHub check display name remains exactly `Example Playwright smoke (full lifecycle)`; it is a CI surface, not an end-user UI surface, but remains a compatibility contract for branch protection.

## Design System

| Property | Value |
|----------|-------|
| Tool | none — no React/Next/Vite surface; shadcn gate not applicable |
| Preset | not applicable |
| Component library | Phoenix LiveView + existing `Sigra.Admin.Components` |
| Icon library | unchanged; no icon work |
| Font | existing admin Space Grotesk/webfont contract and `--sg-*` typography tokens; no change |

## Spacing Scale

No phase-level spacing is introduced or changed. Existing admin spacing remains authoritative.

| Token | Value | Usage |
|-------|-------|-------|
| xs | 4px | Existing `--sg-space-1`; unchanged |
| sm | 8px | Existing `--sg-space-2`; unchanged |
| md | 16px | Existing `--sg-space-4`; unchanged |
| lg | 24px | Existing `--sg-space-6`; unchanged |
| xl | 32px | Existing `--sg-space-8`; unchanged |
| 2xl | 48px | Existing `--sg-space-12`; unchanged |
| 3xl | 64px | Existing `--sg-space-16`; unchanged |

Exceptions: none. No CSS or markup may be added by this phase.

## Typography

No phase-level typography is introduced or changed. Existing admin tokens and current rendered baselines are the source of truth; this phase must not add a type scale or change font loading.

| Role | Size | Weight | Line Height |
|------|------|--------|-------------|
| Body | existing token | unchanged | unchanged |
| Label | existing token | unchanged | unchanged |
| Heading | existing token | unchanged | unchanged |
| Display | existing token | unchanged | unchanged |

The design-gallery test must continue to wait for `document.fonts.ready` and assert `document.fonts.check('16px "Space Grotesk"')` before any screenshot or visual assertion.

## Color

No phase-level color is introduced or changed. Preserve existing Rail Accent token mappings and all three theme modes.

| Role | Value | Usage |
|------|-------|-------|
| Dominant (60%) | existing `--sg-color-subtle` / `--sg-color-panel` by active theme | Existing page backgrounds and surfaces only; unchanged |
| Secondary (30%) | existing `--sg-color-panel-alt` by active theme | Existing cards, navigation, and secondary surfaces only; unchanged |
| Accent (10%) | existing Ember brand tokens (`#c2410c` / context-appropriate dark mapping) | Existing identity, primary actions, selected states, and ownership-boundary emphasis only; unchanged |
| Destructive | existing `--sg-color-risk` by active theme | Existing destructive/risk states only; unchanged |

Accent reserved for: existing Sigra identity, primary actions, selected states, and ownership-boundary emphasis. Phase 232 adds none.

## Copywriting Contract

No application copy is introduced or modified. The following entries expressly prevent CI infrastructure from becoming a user-facing UI feature.

| Element | Copy |
|---------|------|
| Primary CTA | None — no new CTA |
| Empty state heading | None — existing gallery/application empty states unchanged |
| Empty state body | None — existing gallery/application empty states unchanged |
| Error state | None — setup or shard failures are CI diagnostics, not application UI; existing in-app error copy remains unchanged |
| Destructive confirmation | None — no destructive UI action |

## Interaction and Test Preservation Contract

1. Each of `admin-design-chromium`, `admin-design-mobile`, and `admin-design-dark` receives a distinct, ephemeral policy-valid `platform-admin+...` authenticated `storageState`. A state produced for one project must not be used by another project or emitted as an artifact.
2. Removing per-test `registerUser()` must preserve deterministic navigation to `/admin/_design`, the explicit `[data-phx-session].phx-connected` readiness gate, and font-readiness assertion before every test page is used. Do not substitute sleeps, polling delays, broad text selectors, retries, or `continue-on-error`.
3. Preserve existing role selectors, stable `data-testid`/`sg-*` hooks, board IDs, behavior assertions, full-page WCAG 2.1/2.2 AA axe coverage, and curated element-scoped screenshot baselines. Snapshot count and passing assertion count are identical for the PW-01 before/after receipt.
4. Preserve the three existing design-gallery render contexts: desktop Chromium/light, iPhone 13/mobile, and desktop Chromium/dark. The project-specific authenticated state must not mask or overwrite the viewport or `colorScheme` configuration. System-mode behavior remains covered by the existing application suite; no interactive theme toggle is added.
5. Shard isolation is invisible to users: every concurrent shard owns its runner-local PostgreSQL service/database, example-app process, and listening port. A failure in any shard must fail the terminal required result; retries are `0` in the observed sharded proof.

## UI Considerations

Applicable state considerations resolved: 5 covered, 0 backstop, 0 unresolved. Six additional probe rows were explicitly dismissed as inapplicable. These are existing rendered states whose coverage must survive the test-infrastructure change; the phase creates no new UI state.

| Category | Element(s) | Status | Resolution / Reason |
|----------|------------|--------|---------------------|
| loading | `/admin/_design` gallery | ✅ covered | The existing gallery loading behavior remains unchanged, and every test waits for attached `.phx-connected`, `document.fonts.ready`, and a successful Space Grotesk check before assertions or screenshots. |
| populated | `/admin/_design` gallery | ✅ covered | The populated gallery preserves all 13 component boards, 11 group boards, and 4 configuration boards, with unchanged IDs, fixtures, behavior assertions, axe scans, and screenshot baselines. |
| overflow | `/admin/_design` gallery | ✅ covered | Existing desktop and iPhone 13 gallery baselines and overflow assertions remain byte-for-byte in force; authentication reuse and sharding may not alter wrapping, clipping, scrolling, or viewport configuration. |
| loading | Authenticated admin navigation | ✅ covered | Navigation to `/admin/_design` preserves the existing admin loading treatment and completes only after explicit LiveView attachment and font-readiness signals; sleeps and retry-based readiness are forbidden. |
| overflow | Responsive admin navigation | ✅ covered | Existing responsive admin navigation behavior remains unchanged across desktop light, iPhone 13 mobile, and desktop dark projects, including current overflow coverage and stable hooks. |

Dismissed as inapplicable:

- Gallery `empty`: the gallery uses a fixed, curated board inventory; an empty dataset is not a supported Phase 232 UI state.
- Gallery `error`: Phase 232 adds no application error state; gallery setup or load failures remain test diagnostics and fail the run.
- Gallery `partial`: a partially rendered or missing board is a failing test condition, not a supported UI state.
- Gallery `zero-one-many`: the gallery is a curated, non-variable fixture inventory rather than a runtime collection.
- Navigation `error`: Phase 232 introduces no navigation failure UI or copy; an authentication or navigation failure fails the Playwright shard.
- Navigation `long-text`: Phase 232 changes no navigation labels or application copy, so it introduces no new long-text condition.

## Registry Safety

| Registry | Blocks Used | Safety Gate |
|----------|-------------|-------------|
| shadcn official | none | not applicable — shadcn is not initialized and this is not a React UI phase |
| third-party | none | not applicable |

## Checker Sign-Off

- [x] Dimension 1 Copywriting: PASS — no copy delta confirmed
- [x] Dimension 2 Visuals: PASS — no visual delta confirmed
- [x] Dimension 3 Color: PASS — existing theme tokens preserved
- [x] Dimension 4 Typography: PASS — existing font readiness/baselines preserved
- [x] Dimension 5 Spacing: PASS — no layout or CSS delta confirmed
- [x] Dimension 6 Registry Safety: PASS — no registry use

**Approval:** approved — 2026-07-31
