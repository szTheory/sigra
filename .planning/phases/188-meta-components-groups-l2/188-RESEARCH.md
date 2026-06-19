# Phase 188: Meta-Components / Groups (L2) - Research

**Researched:** 2026-06-15  
**Domain:** Phoenix LiveView admin UI meta-component groups, shipped CSS parity, Playwright visual/a11y evidence  
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
Phase 188 uses the approved `188-UI-SPEC.md` MG-1..MG-11 catalog as the source of truth, not the stale current MG-1..MG-5 docs and gallery. Update the gallery, `GROUP_BOARDS`, L2 scorecard copy, quality ledger, and evidence links together.

The final L2 catalog is: MG-1 Metric/Summary Strip, MG-2 Filter Panel + Applied-chip Row, MG-3 Task-card Grid, MG-4 Alarm Notice Band, MG-5 User Results + Pagination, MG-6 Audit Feed + Pagination, MG-7 Organization Member Roster, MG-8 Pending Invitations, MG-9 Identity Header + Summary Facts, MG-10 Detail Facts + Membership Panels, and MG-11 Destructive Action + Confirmation.

Any L2 group/layout CSS required for MG-1..MG-11 must live in the canonical shipped stylesheet `priv/templates/sigra.install/admin/sigra_admin.css`, with `test/example/priv/static/assets/sigra_admin.css` and `test/fixtures/install_golden/tree/priv/static/assets/sigra_admin.css` kept byte-identical. Do not leave required group styling in example-only `test/example/priv/static/assets/css/app.css`.

Migrated group rules belong in the existing `@layer sg-components` structure, must depend only on `var(--sg-*)` tokens or established token-safe CSS primitives, and must not re-tune Phase 186 token values. Preserve the DIST-05 parity surfaces on every edit.

`/admin/_design` must render `board-mg-1` through `board-mg-11` with stable ids. Each board should render populated, zero, loading, and error variants when the state is reachable. If a state is impossible, document that on the board or in verification notes.

Add group-level responsive/overflow assertions at 320, 375, 768, 1024, and 1440px.

Add explicit MG-5 and MG-6 desktop-table to mobile-card equivalence assertions: primary identity/event, status/outcome, secondary facts, action/navigation affordance, and identifiers must be present in both representations at the breakpoint.

Board screenshots remain one composite state-matrix PNG per group per project (`admin-design-chromium`, `admin-design-mobile`, `admin-design-dark`), paired with axe `wcag2a` and `wcag2aa` scans. Use role selectors, stable ids/test ids, LiveView readiness gates, and no sleeps.

Production group markup and scored board content must avoid `.sg-card .sg-card`. If a gallery wrapper is needed around a group that itself contains cards, make the wrapper unframed or explicitly mark it as an audit-only wrapper excluded from the group score.

Groups must use the right L1 component for the job: `summary_chip` for metrics, `applied_chip` for removable filter state, `task_card` for action prompts, `notice` for contextual group alerts, `empty_state` for zero data, `skeleton` for loading, and `audit_row` for mobile/compact audit rows. Do not introduce bespoke one-off markup when a ratified component covers the job.

Reused groups across two or more pages must render byte-coherently for equivalent data. Named density/scope variants are allowed only when the variant is documented in the board label and ledger evidence.

Standardize MG-11 on `sg-confirm-overlay` / `sg-confirm-dialog` for the L2 destructive-confirmation contract. `BrandingLive` already uses this pattern; `UserShowLive` currently uses a DaisyUI `<dialog class="modal">` and should be brought into the Sigra-owned confirmation pattern if Phase 188 touches MG-11.

Fold `2026-06-14-phase-186-review-deferred.md` into Phase 188. Implement the D-11 parity/test-harness hardening as a focused UI-neutral slice: structural dark-block and token extractors in `test/sigra/install/features/admin_test.exs`, hoist/dedupe the duplicated `readNoticeStyles` helper in `admin-theme.spec.ts`, and add a lightweight `admin-token-reference.md` completeness guard if it can be done without expanding product scope.

The folded todo must not change token values or broaden Phase 188 into a new L0 token audit. It is accepted as test-harness robustness because the user explicitly chose to fold it into this phase.

### the agent's Discretion
Exact migration sequencing for group CSS families, as long as canonical/example/golden CSS parity stays green.

Exact board layout for each MG state matrix, provided it uses stable ids and avoids scored card-in-card nesting.

Exact ledger tier achieved for each L2 row after evidence is produced; monotonic guard rules apply.

Whether MG-11 confirmation standardization lands in the same slice as group CSS migration or in a later Phase 188 slice.

### Deferred Ideas (OUT OF SCOPE)
Page-level overlay/focus/scroll behavior, page archetype scoring, sticky/scroll behavior, and pagination honesty beyond L2 group evidence - Phase 189.

Flow/persona happy/error/boundary fixture enrichment - Phase 190.

System-wide microcopy and one-term-per-concept glossary - Phase 191.

Final generated-host parity and baseline lock - Phase 192.

Example auth CSS de-staling remains outside this phase unless a separate maintenance task promotes it.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| GROUP-01 | All MG-1..MG-11 pass the meta scorecard, including intra-group rhythm, no card-in-card nesting, and right-component-for-job composition. | Use `188-UI-SPEC.md` as source of truth; current gallery only has MG-1..MG-5 and `board-mg-3` wraps `task_card` cards inside an `.sg-card` board wrapper. [CITED: .planning/phases/188-meta-components-groups-l2/188-UI-SPEC.md] [VERIFIED: codebase grep] |
| GROUP-02 | Each group defines zero, loading, and error states. | `188-UI-SPEC.md` contains a per-MG state contract; current `design_gallery_live.ex` group boards only show populated examples. [CITED: .planning/phases/188-meta-components-groups-l2/188-UI-SPEC.md] [VERIFIED: codebase grep] |
| GROUP-03 | Desktop-table ↔ mobile-card swaps are content-equivalent at the breakpoint with graceful overflow and no squished columns. | MG-5 users and MG-6 audit already expose desktop/mobile containers with stable `data-testid` hooks in production LiveViews; Playwright currently checks responsive overflow for `COMPONENT_BOARDS` only. [VERIFIED: codebase grep] |
| GROUP-04 | Groups reused across >=2 pages render byte-coherently. | MG-1, MG-2, MG-3, MG-4, MG-6, and MG-11 have repeated production surfaces; byte-coherence should be enforced by shared component usage, stable class structure, and focused DOM assertions. [VERIFIED: codebase grep] |
</phase_requirements>

## Summary

Phase 188 is a codebase-driven L2 audit, not a library selection phase. The approved contract is already present in `188-UI-SPEC.md`; planning should implement that contract across the gallery, Playwright assertions, canonical shipped CSS, production LiveViews, scorecard, and ledger. [CITED: .planning/phases/188-meta-components-groups-l2/188-UI-SPEC.md]

The main implementation risk is the same class of drift Phase 187 closed for L1: several L2 group rules still live only in `test/example/priv/static/assets/css/app.css`, including detail grids, filter chips, search/form grids, table rules, key/value facts, truncation, confirmation overlays, danger panels, and action rows. Generated hosts link `sigra_admin.css`, so any required group styling left in `app.css` makes gallery evidence untruthful for adopters. [VERIFIED: codebase grep]

**Primary recommendation:** Plan Phase 188 as four slices: L2 CSS migration/parity; MG-1..MG-11 gallery/state catalog; Playwright group responsive/equivalence/coherence assertions; production drift fixes plus ledger/scorecard raises. [VERIFIED: codebase grep]

## Project Constraints (from AGENTS.md)

- Preserve the `sg-*` cascade-layer/BEM design system for admin UI work. [CITED: AGENTS.md]
- Use Rail Accent brand assets from `brandbook/`. [CITED: AGENTS.md]
- Support Light, Dark, and System modes. [CITED: AGENTS.md]
- Keep Playwright/admin UI tests deterministic: role selectors, stable hooks, LiveView readiness, no sleeps. [CITED: AGENTS.md]
- In `test/example/`, use `mix precommit` when done with all changes; avoid sleeps in tests; preserve the same admin UI constraints under the nested example app instructions. [CITED: test/example/AGENTS.md]

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|--------------|----------------|-----------|
| MG catalog rendering and state matrices | Frontend Server (LiveView) | Browser / Client | `/admin/_design` is a LiveView that renders deterministic board markup; browser tests verify visual/a11y behavior. [VERIFIED: codebase grep] |
| Group styling and responsive behavior | CDN / Static | Frontend Server (LiveView) | `sigra_admin.css` is the shipped static asset; LiveView markup must use its `sg-*` classes consistently. [VERIFIED: codebase grep] |
| Desktop/mobile content equivalence | Frontend Server (LiveView) | Browser / Client | Production LiveViews emit both table and mobile card/list variants; Playwright should assert equivalent rendered content at breakpoints. [VERIFIED: codebase grep] |
| Byte-coherent reuse | Frontend Server (LiveView) | API / Backend | Reuse coherence is primarily markup/component structure; backend rows supply equivalent data for repeated group patterns. [VERIFIED: codebase grep] |
| Ledger and scorecard ratification | Static docs / CI | Browser / Client | `admin-quality-ledger.md` is parsed by CI; Playwright screenshots/axe provide evidence links. [VERIFIED: codebase grep] |

## Standard Stack

### Core

| Library / Tool | Version | Purpose | Why Standard |
|----------------|---------|---------|--------------|
| Phoenix / Phoenix LiveView | `phoenix ~> 1.8`, `phoenix_live_view ~> 1.1` | Admin LiveView pages and function components. | Existing admin UI is implemented in Phoenix LiveView and `Sigra.Admin.Components`; do not introduce a frontend component library. [VERIFIED: mix.exs] |
| ExUnit | Mix 1.19.5 runtime | CSS parity, install/golden, component and harness tests. | Existing merge-blocking tests are ExUnit files under `test/sigra/`. [VERIFIED: CLI + codebase grep] |
| Playwright | CLI 1.59.1; package range `@playwright/test ^1.48.0` | Design board screenshots, responsive assertions, theme projects. | Existing `admin-design-{chromium,mobile,dark}` projects run `admin-design.spec.ts`. [VERIFIED: CLI + package.json + codebase grep] |
| `@axe-core/playwright` | package range `^4.10.0` | WCAG A/AA scans paired with each board snapshot. | Existing `admin-design.spec.ts` scopes axe to `wcag2a` and `wcag2aa`. [VERIFIED: package.json + codebase grep] |

### Supporting

| Library / Tool | Version | Purpose | When to Use |
|----------------|---------|---------|-------------|
| `scripts/ci/snapshot-recapture-gate.sh` | repo script | Deliberate recapture for admin-design PNG baselines. | Use when board visual changes are intended. [VERIFIED: codebase grep] |
| `scripts/ci/snapshot-canary-guard.sh` | repo script | Enforce empty allowlist/canary discipline. | Use before phase close and after recaptures. [VERIFIED: codebase grep] |
| `scripts/ci/quality-ledger-monotonic.sh` | repo script | Prevent L2 tier decreases. | Run after ledger edits. [VERIFIED: codebase grep] |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Hand-authored `sg-*` + LiveView | shadcn/Radix/React component registry | Rejected by phase UI spec and repo constraints; Phase 188 has no React/Vite/shadcn stack and should add no packages. [CITED: .planning/phases/188-meta-components-groups-l2/188-UI-SPEC.md] |
| Existing Playwright lane | New visual test framework | Existing admin-design lane already covers screenshots, mobile/dark projects, and axe; new tooling would add risk without solving a phase requirement. [VERIFIED: codebase grep] |

**Installation:** No new packages should be installed for this phase. [CITED: .planning/phases/188-meta-components-groups-l2/188-UI-SPEC.md]

## Package Legitimacy Audit

No external package installation is recommended for Phase 188, so the Package Legitimacy Gate is not applicable. Existing packages were identified from local `mix.exs` and `test/example/priv/playwright/package.json`; no new package names are introduced. [VERIFIED: mix.exs] [VERIFIED: package.json]

## Architecture Patterns

### System Architecture Diagram

```text
Phase 188 inputs
  -> 188-UI-SPEC MG-1..MG-11 contract
  -> existing production LiveViews and Sigra.Admin.Components
  -> existing L2 gallery/tests/ledger/scorecard

Implementation flow
  -> migrate required group CSS from example app.css to canonical sigra_admin.css
  -> sync example and install-golden sigra_admin.css byte mirrors
  -> expand /admin/_design board-mg-1..board-mg-11 state matrices
  -> add Playwright group board inventory, axe, responsive, equivalence, and no-nesting assertions
  -> fix production drift where board evidence reveals reuse or component-choice mismatch
  -> update scorecard and ledger evidence

Validation flow
  -> ExUnit CSS/install/golden tests
  -> admin-design chromium/mobile/dark Playwright projects
  -> snapshot canary/recapture gate when intended visual deltas exist
  -> quality-ledger-monotonic guard
```

### Recommended Project Structure

```text
lib/sigra/admin/live/
├── index_live.ex              # MG-1, MG-3, MG-4 production source
├── users_index_live.ex        # MG-1, MG-2, MG-5 production source
├── audit_index_live.ex        # MG-2, MG-6 production source
├── audit_user_live.ex         # MG-2, MG-6, MG-9 production source
├── organization_live.ex       # MG-3, MG-4, MG-7, MG-8 production source
├── user_show_live.ex          # MG-9, MG-10, MG-11 production source
└── branding_live.ex           # MG-11 confirmation precedent

test/example/lib/example_web/live/admin/
└── design_gallery_live.ex     # board-mg-1..board-mg-11 state evidence

priv/templates/sigra.install/admin/
└── sigra_admin.css            # canonical shipped L2 group CSS

test/example/priv/playwright/tests/
└── admin-design.spec.ts       # board screenshots, axe, group responsive/equivalence/coherence tests

guides/reference/
├── admin-fractal-scorecard.md # L2 scorecard wording
└── admin-quality-ledger.md    # L2 tier/evidence rows
```

### Pattern 1: Board Inventory Moves With Evidence

**What:** Every MG board added to `design_gallery_live.ex` must also be added to `GROUP_BOARDS`, snapshot baselines, scorecard copy, and ledger rows. [CITED: .planning/phases/188-meta-components-groups-l2/188-UI-SPEC.md]

**When to use:** Any MG-1..MG-11 catalog edit. [CITED: .planning/phases/188-meta-components-groups-l2/188-UI-SPEC.md]

**Example:**

```typescript
// Source: test/example/priv/playwright/tests/admin-design.spec.ts
const GROUP_BOARDS = [
  'board-mg-1',
  'board-mg-2',
  'board-mg-3',
  'board-mg-4',
  'board-mg-5',
  'board-mg-6',
  'board-mg-7',
  'board-mg-8',
  'board-mg-9',
  'board-mg-10',
  'board-mg-11',
];
```

### Pattern 2: Canonical CSS Migration With Byte Mirrors

**What:** Move reusable L2 group CSS from `app.css` into `priv/templates/sigra.install/admin/sigra_admin.css`, then copy the canonical file to both mirrors. [CITED: .planning/phases/188-meta-components-groups-l2/188-CONTEXT.md]

**When to use:** Any group rule required by generated hosts, especially tables, filters, facts, lists, confirmation, and danger panels. [VERIFIED: codebase grep]

**Example:**

```bash
cp priv/templates/sigra.install/admin/sigra_admin.css test/example/priv/static/assets/sigra_admin.css
cp priv/templates/sigra.install/admin/sigra_admin.css test/fixtures/install_golden/tree/priv/static/assets/sigra_admin.css
mix test test/sigra/install/features/admin_test.exs test/sigra/install/golden_diff_test.exs
```

### Pattern 3: Content-Equivalent Table/Card Assertions

**What:** For MG-5 and MG-6, assert the table and mobile representation expose the same primary, status/outcome, secondary facts, action/navigation, and identifiers. [CITED: .planning/phases/188-meta-components-groups-l2/188-UI-SPEC.md]

**When to use:** Add focused Playwright tests against production page containers and/or gallery state matrices. [VERIFIED: codebase grep]

**Example:**

```typescript
// Source pattern: existing stable hooks in UsersIndexLive
await expect(page.locator('[data-testid="admin-users-desktop-results"]')).toContainText(userEmail);
await expect(page.locator('[data-testid="admin-users-mobile-results"]')).toContainText(userEmail);
await expect(page.locator('[data-testid="admin-users-desktop-results"]')).toContainText('Open user');
await expect(page.locator('[data-testid="admin-users-mobile-results"]')).toContainText('Open user');
```

### Anti-Patterns to Avoid

- **Gallery-only styling:** Required group CSS in `test/example/priv/static/assets/css/app.css` can make `/admin/_design` pass while generated hosts remain unstyled. [VERIFIED: codebase grep]
- **Card-in-card scoring:** `board-mg-3` currently wraps `.task_card` articles in an `.sg-card` board wrapper; use unframed board shells or score exclusions for groups containing cards. [VERIFIED: codebase grep]
- **Modal drift:** `UserShowLive` uses `<dialog class="modal">` while `BrandingLive` uses `sg-confirm-overlay` / `sg-confirm-dialog`; standardize MG-11 on Sigra-owned confirmation markup. [VERIFIED: codebase grep]
- **Silent state omissions:** If a zero/loading/error state is impossible, document why; otherwise render the state. [CITED: .planning/phases/188-meta-components-groups-l2/188-UI-SPEC.md]

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Metrics/posture summaries | Raw metric cards or new `.sg-stat` classes | `summary_chip` | L1 winner already defines metric semantics and visual states. [CITED: guides/reference/admin-design-contract.md] |
| Removable filter state | Bespoke pills/buttons | `applied_chip` | Existing component has removal labels and focus behavior. [CITED: guides/reference/admin-design-contract.md] |
| Action prompt grid | Custom card markup | `task_card` | Existing component owns verb-first CTA structure. [CITED: guides/reference/admin-design-contract.md] |
| Group alerts/errors | Flash-only or raw alert divs | `notice` / `notice_link` | L2 error states need contextual board/page evidence. [CITED: guides/reference/admin-design-contract.md] |
| Zero data | Plain paragraphs | `empty_state` | Empty is not error; component gives consistent zero-row treatment. [CITED: guides/reference/admin-design-contract.md] |
| Loading placeholders | Spinners or arbitrary gray boxes | `skeleton` with `aria-busy` on container | L1 contract defines loading placeholder semantics. [CITED: guides/reference/admin-design-contract.md] |
| Audit mobile/compact rows | Duplicate audit row markup | `audit_row` | Keeps tone derivation and row structure coherent. [CITED: guides/reference/admin-design-contract.md] |
| Confirmation dialogs | DaisyUI `.modal` | `sg-confirm-overlay` / `sg-confirm-dialog` | Admin design contract warns against generic modal chrome in admin shell. [CITED: guides/reference/admin-design-contract.md] |

**Key insight:** Phase 188 quality claims are only truthful if the same shipped CSS and component structures render in production pages, the gallery, and generated hosts. [VERIFIED: codebase grep]

## Common Pitfalls

### Pitfall 1: Stale MG-1..MG-5 Instrumentation

**What goes wrong:** The planner updates only the five existing boards and leaves MG-6..MG-11 unevidenced. [VERIFIED: codebase grep]  
**Why it happens:** `design_gallery_live.ex`, `admin-design.spec.ts`, `admin-fractal-scorecard.md`, and `admin-quality-ledger.md` still reference five group boards. [VERIFIED: codebase grep]  
**How to avoid:** Treat `188-UI-SPEC.md` as the catalog source and update all instruments together. [CITED: .planning/phases/188-meta-components-groups-l2/188-UI-SPEC.md]  
**Warning signs:** `GROUP_BOARDS.length` remains 5 or scorecard text says "MG-1 through MG-5". [VERIFIED: codebase grep]

### Pitfall 2: Example-Trapped Group CSS

**What goes wrong:** Tables, filters, facts, confirmations, and detail panels pass in the example but are incomplete in generated hosts. [VERIFIED: codebase grep]  
**Why it happens:** `app.css` contains many group rules not present in `sigra_admin.css`: `.sg-detail-grid`, `.sg-form-grid`, `.sg-action-row`, `.sg-confirm-*`, `.sg-search-row`, `.sg-filter-chip`, `.sg-truncate`, `.sg-tabular`, `.sg-list`, `.sg-kv`, `.sg-table`, `.sg-summary-facts`, and `.sg-danger-panel`. [VERIFIED: codebase grep]  
**How to avoid:** Migrate required L2 rules into canonical `sigra_admin.css` under `@layer sg-components`, remove duplicate source rules, and sync mirrors. [CITED: .planning/phases/188-meta-components-groups-l2/188-CONTEXT.md]  
**Warning signs:** `rg` finds a required `sg-*` group selector only in `test/example/priv/static/assets/css/app.css`. [VERIFIED: codebase grep]

### Pitfall 3: Desktop/Mobile Swap Loses Data

**What goes wrong:** Mobile cards hide identifiers, outcome/status, secondary facts, or actions that the desktop table exposes. [CITED: .planning/phases/188-meta-components-groups-l2/188-UI-SPEC.md]  
**Why it happens:** Visibility utilities make it easy to ship two separate DOMs without comparing their content. [VERIFIED: codebase grep]  
**How to avoid:** Add explicit MG-5/MG-6 assertions for data element equivalence, not just visual screenshots. [CITED: .planning/phases/188-meta-components-groups-l2/188-UI-SPEC.md]  
**Warning signs:** Tests only snapshot `board-mg-*` and never inspect `admin-users-mobile-results` or `admin-audit-mobile-results`. [VERIFIED: codebase grep]

### Pitfall 4: Byte-Coherence Claims Without Structural Checks

**What goes wrong:** Reused groups drift by page while the ledger claims L2 coherence. [CITED: .planning/REQUIREMENTS.md]  
**Why it happens:** Screenshots catch gross visual drift but not same-data same-structure claims. [ASSUMED]  
**How to avoid:** Add DOM/class/attribute assertions for repeated groups or factor repeated group rendering into helpers only when it reduces real duplication. [VERIFIED: codebase grep]  
**Warning signs:** MG-6 audit rows render through `audit_row` on mobile but table tone derivation is duplicated in multiple LiveViews. [VERIFIED: codebase grep]

### Pitfall 5: Token-Harness Cleanup Becomes Token Audit

**What goes wrong:** The folded D-11 hardening changes token values or expands into L0 redesign. [CITED: .planning/phases/188-meta-components-groups-l2/188-CONTEXT.md]  
**Why it happens:** The target files are token tests and token reference docs. [VERIFIED: codebase grep]  
**How to avoid:** Limit changes to structural extractors, helper dedupe, and optional completeness guard; do not change ratified token values. [CITED: .planning/phases/188-meta-components-groups-l2/188-CONTEXT.md]

## Code Examples

### Existing Deterministic Board Screenshot Pattern

```typescript
// Source: test/example/priv/playwright/tests/admin-design.spec.ts
async function waitForLiveViewReady(page: Page) {
  await page.waitForSelector('[data-phx-session].phx-connected', {
    state: 'attached',
  });
}

async function assertBoardScreenshot(page: Page, testInfo: TestInfo, boardId: string) {
  await assertNoAxeViolations(page, `axe:${boardId}`);
  const locator = page.locator(`#${boardId}`);
  await expect(locator).toHaveScreenshot(`${boardId}.png`, {
    maxDiffPixels: 30_000,
  });
}
```

### Existing MG-5 Stable Hooks

```elixir
# Source: lib/sigra/admin/live/users_index_live.ex
<div
  id="admin-users-desktop-results"
  data-testid="admin-users-desktop-results"
  class="sg-table-panel sg-show-desktop"
>
  ...
</div>

<div
  id="admin-users-mobile-results"
  data-testid="admin-users-mobile-results"
  class="sg-stack sg-stack--3 sg-show-mobile"
>
  ...
</div>
```

### Existing MG-11 Confirmation Precedent

```elixir
# Source: lib/sigra/admin/live/branding_live.ex
<div :if={@restore_defaults_open?} class="sg-confirm-overlay" role="presentation">
  <section
    class="sg-confirm-dialog"
    role="dialog"
    aria-modal="true"
    aria-labelledby="restore-defaults-title"
  >
    ...
  </section>
</div>
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| MG-1..MG-5 starter L2 catalog | MG-1..MG-11 approved L2 catalog | Phase 188 UI spec, 2026-06-15 | Gallery, Playwright, scorecard, and ledger must expand together. [CITED: .planning/phases/188-meta-components-groups-l2/188-UI-SPEC.md] |
| Example-only component styling | Shipped `sigra_admin.css` parity model | Phases 184 and 187 | L2 group CSS must follow the same canonical/template/example/golden parity discipline. [CITED: .planning/phases/188-meta-components-groups-l2/188-CONTEXT.md] |
| Generic DaisyUI modal in admin detail | Sigra-owned confirmation overlay/dialog | Ratified by admin design contract and Phase 188 context | `UserShowLive` is the outlier if MG-11 is touched. [VERIFIED: codebase grep] |

**Deprecated/outdated:**
- `guides/reference/admin-fractal-scorecard.md` L2 copy says MG-1 through MG-5; update to MG-1..MG-11. [VERIFIED: codebase grep]
- `guides/reference/admin-quality-ledger.md` has only five L2 rows and names `mg-5-audit-feed`, while Phase 188 makes MG-5 User Results and MG-6 Audit Feed. [VERIFIED: codebase grep]
- `test/example/lib/example_web/live/admin/design_gallery_live.ex` module docs and board list say MG-1..MG-5. [VERIFIED: codebase grep]

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Screenshots catch gross visual drift but not same-data same-structure claims. | Common Pitfalls | Planner may over-index on DOM assertions; acceptable because added assertions are low risk. |

## Open Questions (RESOLVED)

1. **How high should each L2 ledger row be raised?**
   - What we know: Existing L2 rows are tier 1 and tiers cannot decrease. [VERIFIED: codebase grep]
   - Resolution: Ledger tier is raised only after evidence review. Executors must keep the existing monotonic floor, review the generated screenshots/assertions, and record the achieved tier without claiming tier 2 from intent alone. [CITED: guides/reference/admin-quality-ledger.md]

2. **Should repeated group rendering be factored into new helpers?**
   - What we know: Production group patterns repeat across LiveViews, but the existing system mainly composes L1 function components and `sg-*` classes directly. [VERIFIED: codebase grep]
   - Resolution: Helper extraction is only for byte-coherence failures where it reduces real duplication. Executors should keep direct L1 component composition unless tests expose same-data structural drift that a small helper cleanly removes. [ASSUMED]

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|-------------|-----------|---------|----------|
| Elixir / Erlang | ExUnit, Phoenix compilation | Yes | Elixir 1.19.5, OTP 28 | None needed. [VERIFIED: CLI] |
| Mix | ExUnit and aliases | Yes | Mix 1.19.5 | None needed. [VERIFIED: CLI] |
| Node.js | Playwright test runner | Yes | v22.14.0 | None needed. [VERIFIED: CLI] |
| npm | Playwright package scripts | Yes | 11.1.0 | None needed. [VERIFIED: CLI] |
| Playwright | admin-design visual/a11y tests | Yes | CLI 1.59.1 | None needed. [VERIFIED: CLI] |

**Missing dependencies with no fallback:** None found. [VERIFIED: CLI]  
**Missing dependencies with fallback:** None found. [VERIFIED: CLI]

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | ExUnit + Playwright + axe-core [VERIFIED: codebase grep] |
| Config file | `mix.exs`; `test/example/priv/playwright/playwright.config.ts` [VERIFIED: codebase grep] |
| Quick run command | `mix test test/sigra/install/features/admin_test.exs test/sigra/install/golden_diff_test.exs` |
| Full suite command | `mix test test/sigra/install/features/admin_test.exs test/sigra/install/golden_diff_test.exs && (cd test/example/priv/playwright && SIGRA_EXAMPLE_URL=http://localhost:4011 npx playwright test tests/admin-design.spec.ts --project=admin-design-chromium --project=admin-design-mobile --project=admin-design-dark) && bash scripts/ci/quality-ledger-monotonic.sh --base HEAD` |

### Phase Requirements -> Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|--------------|
| GROUP-01 | MG-1..MG-11 boards pass scorecard, no card nesting, right L1 components | Playwright DOM + screenshot + axe | `cd test/example/priv/playwright && SIGRA_EXAMPLE_URL=http://localhost:4011 npx playwright test tests/admin-design.spec.ts --project=admin-design-chromium --grep "board-mg|card nesting|right component"` | Yes, extend existing spec [VERIFIED: codebase grep] |
| GROUP-02 | Each group has populated/zero/loading/error state evidence | Playwright DOM + screenshot | `cd test/example/priv/playwright && SIGRA_EXAMPLE_URL=http://localhost:4011 npx playwright test tests/admin-design.spec.ts --project=admin-design-chromium --grep "group states"` | Yes, add tests [VERIFIED: codebase grep] |
| GROUP-03 | MG-5/MG-6 desktop/mobile representations are equivalent and responsive | Playwright viewport + DOM | `cd test/example/priv/playwright && SIGRA_EXAMPLE_URL=http://localhost:4011 npx playwright test tests/admin-design.spec.ts --project=admin-design-mobile --grep "MG-5|MG-6|equivalence|overflow"` | Yes, extend existing spec [VERIFIED: codebase grep] |
| GROUP-04 | Reused groups render byte-coherently | Playwright DOM/class snapshots or targeted structural assertions | `cd test/example/priv/playwright && SIGRA_EXAMPLE_URL=http://localhost:4011 npx playwright test tests/admin-design.spec.ts --project=admin-design-chromium --grep "coherent"` | Yes, add tests [VERIFIED: codebase grep] |

### Sampling Rate

- **Per task commit:** `mix test test/sigra/install/features/admin_test.exs test/sigra/install/golden_diff_test.exs`
- **Per wave merge:** full admin-design trio plus `bash scripts/ci/quality-ledger-monotonic.sh --base HEAD`
- **Phase gate:** Full suite green, snapshot canary guard green, intended deltas recaptured through the recapture gate, and both CSS mirrors byte-identical. [VERIFIED: codebase grep]

### Wave 0 Gaps

- [ ] Extend `test/example/priv/playwright/tests/admin-design.spec.ts` so `GROUP_BOARDS` contains all eleven MG boards. [VERIFIED: codebase grep]
- [ ] Add group-board responsive assertions at 320, 375, 768, 1024, and 1440px. [CITED: .planning/phases/188-meta-components-groups-l2/188-CONTEXT.md]
- [ ] Add MG-5/MG-6 desktop/mobile content-equivalence assertions. [CITED: .planning/phases/188-meta-components-groups-l2/188-UI-SPEC.md]
- [ ] Add no `.sg-card .sg-card` assertions for scored production/group-board markup, with explicit board-wrapper exception if used. [CITED: .planning/phases/188-meta-components-groups-l2/188-CONTEXT.md]
- [ ] Refactor D-11 dark-block/token extractor helpers and dedupe `readNoticeStyles` in `admin-theme.spec.ts`. [CITED: .planning/phases/188-meta-components-groups-l2/188-CONTEXT.md]

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|------------------|
| V2 Authentication | No direct change | Existing admin auth/session setup remains unchanged. [VERIFIED: codebase grep] |
| V3 Session Management | Yes, MG-11 touches session revocation confirmation UI | Preserve existing `Actions.revoke_session` / `Actions.revoke_all_sessions` event flow; change presentation only unless explicitly planned. [VERIFIED: codebase grep] |
| V4 Access Control | No direct change | Do not alter admin scope or policy boundaries while editing UI groups. [VERIFIED: codebase grep] |
| V5 Input Validation | Yes, filters/forms render in MG-2 | Preserve explicit labels, existing query normalization, and GET filter semantics. [VERIFIED: codebase grep] |
| V6 Cryptography | No | No cryptographic operations in scope. [VERIFIED: codebase grep] |

### Known Threat Patterns for Phoenix LiveView Admin UI

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Destructive action ambiguity | Tampering / Repudiation | Confirmation copy names action and consequence; keep confirm button visually secondary until armed/confirmed. [CITED: .planning/phases/188-meta-components-groups-l2/188-UI-SPEC.md] |
| Scope confusion between global/org admin | Elevation of privilege / Information disclosure | Preserve `scope_ribbon`, breadcrumbs, and scope-aware paths while refactoring groups. [CITED: guides/reference/admin-ui-principles.md] |
| Test-only evidence diverges from generated hosts | Repudiation | Move required group CSS into shipped `sigra_admin.css` and enforce byte parity. [VERIFIED: codebase grep] |

## Sources

### Primary (HIGH confidence)

- `.planning/phases/188-meta-components-groups-l2/188-CONTEXT.md` - locked decisions D-01..D-16.
- `.planning/phases/188-meta-components-groups-l2/188-UI-SPEC.md` - approved MG-1..MG-11 catalog, states, table/card contract, verification contract.
- `.planning/REQUIREMENTS.md` - GROUP-01..GROUP-04.
- `AGENTS.md` and `test/example/AGENTS.md` - project admin UI and deterministic test constraints.
- `guides/reference/admin-ui-principles.md` - admin IA, design-system, theme, motion, and testing principles.
- `guides/reference/admin-design-contract.md` - same-job-to-same-component and confirmation warning.
- `test/example/lib/example_web/live/admin/design_gallery_live.ex` - current MG-1..MG-5 boards.
- `test/example/priv/playwright/tests/admin-design.spec.ts` - current board snapshot, axe, responsive patterns.
- `priv/templates/sigra.install/admin/sigra_admin.css` and `test/example/priv/static/assets/css/app.css` - CSS source of truth audit.
- `lib/sigra/admin/live/*.ex` - production MG source surfaces.

### Secondary (MEDIUM confidence)

- `.planning/phases/187-individual-components-l1/187-VALIDATION.md` - proven validation commands and Phase 187 final gate shape.
- `.planning/phases/187-individual-components-l1/187-CSS-INVENTORY.md` - prior CSS migration precedent.
- `guides/reference/admin-fractal-scorecard.md` and `guides/reference/admin-quality-ledger.md` - current stale L2 text/rows.

### Tertiary (LOW confidence)

- None. No web-only sources were used.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - verified from local config and CLI versions.
- Architecture: HIGH - verified from repo files and locked Phase 188 context.
- Pitfalls: HIGH for stale catalog/CSS/modal drift; MEDIUM for byte-coherence test shape because final assertion details depend on implementation.

**Research date:** 2026-06-15  
**Valid until:** 2026-07-15, or until Phase 187/188 files change materially.
