# Phase 187: Individual Components (L1) - Research

**Researched:** 2026-06-14  
**Domain:** Phoenix LiveView admin function components, shipped CSS parity, Playwright/axe board validation  
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

## Implementation Decisions

### Component-CSS source of truth — the central structural fix (COMP-01..03; escalated, ratified)
- **D-01:** **Migrate each component's visual/state CSS from the example-only
  `test/example/priv/static/assets/css/app.css` into the shipped, canonical
  `priv/templates/sigra.install/admin/sigra_admin.css`** as part of auditing/improving that
  component. **VERIFIED FINDING:** every one of the components' visual/state classes —
  `sg-metric` (30 occ in app.css / 0 in shipped), `sg-btn`+states (22/0), `sg-notice` tones (9/0),
  `sg-status-pill` (13/0), `sg-field-help` (10/0), `sg-list-row` (5/0),
  `sg-metric-link` (5/0), `sg-applied-chip` (3/0), `sg-empty-state` (3/0),
  `sg-skeleton` (2/0), `sg-card-hover` (1/0), `sg-code` (3/0) — lives ONLY in `app.css`.
  Phase 184 extracted tokens + layout primitives + structural container classes but left the
  per-component visual rules behind. Hosts link only `sigra_admin.css`, so they render components
  with layout but no component-level styling — the "sg-* CSS is example-trapped" gap.
- **D-02:** After migrating a component's rules into `sigra_admin.css`, **remove the now-duplicate
  `sg-*` rule from `app.css`** so the example stays a true host mirror. `app.css` keeps only
  `vt-*`/Vaultr glue.
- **D-03:** Migration must preserve **cascade-layer placement** — component rules belong in
  `@layer sg-components { … }` inside `sigra_admin.css`; each migrated rule must depend **only on
  `var(--sg-*)` tokens**.
- **D-04:** Every migration touches the **parity surfaces together**:
  `priv/templates/sigra.install/admin/sigra_admin.css` ≡
  `test/example/priv/static/assets/sigra_admin.css` ≡
  `test/fixtures/install_golden/tree/priv/static/assets/sigra_admin.css`.

### Interaction states, motion, and the 186 token-value lock (COMP-02, COMP-03)
- **D-05:** Give each component **complete, visually-distinct interaction states** per the L1
  add-on; motion is exact-property only, pointer-gated, keyboard-calm, interruptible, and stripped
  under `prefers-reduced-motion: reduce`.
- **D-06:** Resolve the **two Phase-186-deferred motion refinements HERE** by **adding net-new
  motion tokens, never re-tuning ratified values**: exit/enter asymmetry and a dropdown/tooltip
  duration tier faster than the 300ms modal ceiling.

### Byte-golden scoping, gallery state coverage, microcopy (COMP-04, COMP-05, COMP-06)
- **D-07:** **Default to CSS-only improvements → zero byte-golden churn.** Update strict component
  goldens only for intended markup deltas, with rationale in the same commit.
- **D-08:** **Enrich the `/admin/_design` gallery boards** with full **interaction-state matrices**
  per component.
- **D-09:** **Component microcopy (COMP-06)** — `empty_state`, `notice`, `field_help` text — comes
  from `guides/reference/admin-design-contract.md`; system-wide voice/glossary work is Phase 191.
- **D-10:** Verify **reflow at 320/375/768/1024/1440** and **per-component axe-clean light+dark** on
  each component's gallery board via the existing `admin-design-{chromium,mobile,dark}` lane + axe
  gate. Raise L1 ledger rows in `guides/reference/admin-quality-ledger.md`.

### the agent's Discretion
- Execution shape: per-component vs. batched-by-similarity.
- Exact net-new motion token names/values.
- Exact gallery state-matrix board layout/ids and intended-delta board slugs.
- Whether any component legitimately needs markup changes vs. CSS-only.
- Migration sequencing/commit granularity across parity surfaces.

### Deferred Ideas (OUT OF SCOPE)
- Group/page/flow fractal audits (L2 groups → L3 pages → L4 flows) — Phases 188–191.
- System-wide microcopy/voice sweep + one-term-per-concept glossary — Phase 191.
- Final ratification / baseline-lock / generated-host parity (`RUN_PARITY=1`) — Phase 192.
- Byte-guarding / de-staling the example `sigra_auth.css` copy — future maintenance only.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| COMP-01 | All 13 components pass D1-D11 light/dark/mobile with exhaustive gallery matrices | Current component inventory and gallery board gaps mapped below [VERIFIED: `.planning/REQUIREMENTS.md`, `components.ex`, `design_gallery_live.ex`] |
| COMP-02 | Micro-interactions align with emilkowal.ski principles | Existing motion tokens and reduced-motion block located; 186 permits only net-new motion tokens [VERIFIED: `admin-token-reference.md`, `187-CONTEXT.md`, CSS grep] |
| COMP-03 | Complete, visually distinct states; disabled inert | State contract is per component in UI-SPEC; current gallery is incomplete for many states [VERIFIED: `187-UI-SPEC.md`, `design_gallery_live.ex`] |
| COMP-04 | Per-component axe clean, ARIA correct, goldens changed only intentionally | Axe board lane and strict literal goldens exist; `notice_link` lacks its own board entry today [VERIFIED: `admin-design.spec.ts`, `components_test.exs`] |
| COMP-05 | Reflow at 320/375/768/1024/1440 without overflow/clip/squish | Existing Playwright has overflow patterns but design lane does not yet cover all required widths [VERIFIED: Playwright grep] |
| COMP-06 | Component-local microcopy is on-brand and JTBD-serving | Copy contract identifies `empty_state`, `notice`, `field_help` text scope [VERIFIED: `187-UI-SPEC.md`, `admin-design-contract.md`] |
</phase_requirements>

## Summary

Phase 187 is a component-quality pass plus a required distribution fix. The 13 canonical
components already live in `Sigra.Admin.Components`, and the Phase 185 gallery/test lane already
exists, but the component visual/state CSS is still trapped in the example-only `app.css` rather
than the shipped `sigra_admin.css`. Planning must therefore couple each component audit with CSS
migration across the three parity surfaces. [VERIFIED: `187-CONTEXT.md`; CSS grep]

The most important planning risks are scope fragmentation and false-green evidence. A gallery-only
CSS improvement would not ship to generated hosts; a CSS-only change should not churn byte-goldens;
and a Playwright board matrix that omits a component/state cannot prove COMP-01/03/04. The current
`COMPONENT_BOARDS` array has 12 component boards and embeds `notice_link` inside `board-notice`,
so the planner should add a `board-notice_link` board or explicitly document why embedded coverage
satisfies the per-component contract. [VERIFIED: `admin-design.spec.ts`]

**Primary recommendation:** Plan by component families, not by one giant CSS move: first establish
inventory/guardrails, then migrate and audit related components together, expanding gallery matrices
and verification in the same slice. [ASSUMED]

## Project Constraints (from AGENTS.md)

- Preserve the `sg-*` cascade-layer/BEM design system. [CITED: `AGENTS.md`]
- Use Rail Accent brand assets from `brandbook/`. [CITED: `AGENTS.md`]
- Support Light, Dark, and System modes. [CITED: `AGENTS.md`]
- Keep Playwright/admin UI tests deterministic with role selectors, stable hooks, LiveView readiness,
  and no sleeps. [CITED: `AGENTS.md`]
- For admin UI work, follow `guides/reference/admin-ui-principles.md` and
  `guides/reference/admin-design-contract.md`. [CITED: `AGENTS.md`]

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|--------------|----------------|-----------|
| Component markup and ARIA | Library (`lib/sigra/admin/components.ex`) | Example gallery as caller | Components are lib-owned Phoenix function components; gallery imports the real module [VERIFIED: codebase grep] |
| Component visual/state CSS | Installer template CSS | Example mirror + install golden fixture | Hosts consume `priv/templates/.../sigra_admin.css`; parity test requires example copy alignment [VERIFIED: `admin_test.exs`] |
| Example-only state matrix | Example LiveView | Playwright design lane | `/admin/_design` is dev-route/example-only and never templated into installer [VERIFIED: `185-RESEARCH.md`, `design_gallery_live.ex`] |
| Browser/axe evidence | Playwright project trio | CI snapshot/allowlist guards | `admin-design-{chromium,mobile,dark}` projects run `admin-design.spec.ts` [VERIFIED: `playwright.config.ts`] |
| Quality ratification | Guides ledger | CI monotonic guard | Ledger tiers are machine-parseable and forward-only [VERIFIED: `admin-quality-ledger.md`, `quality-ledger-monotonic.sh`] |
| Motion-token additions | CSS `:root` + token reference | Component consumers | Phase 186 freezes existing values; 187 may add net-new motion tokens only [VERIFIED: `186-CONTEXT.md`, `187-CONTEXT.md`] |

## Standard Stack

### Core

| Library / Tool | Version | Purpose | Why Standard |
|----------------|---------|---------|--------------|
| Phoenix | locked `1.8.7` | LiveView app framework and generated admin host contract | Existing project stack [VERIFIED: Hex registry, `mix.lock`] |
| Phoenix LiveView | locked `1.1.31` | Function components and `/admin/_design` LiveView | Existing component/gallery implementation [VERIFIED: Hex registry, `mix.lock`] |
| Elixir / Mix | `1.19.5` | ExUnit, component rendering tests, installer/golden tests | Local runtime available [VERIFIED: `mix --version`] |
| `@playwright/test` | installed `1.59.1`; latest `1.60.0` | Board screenshots, responsive assertions, theme projects | Already installed in example Playwright project [VERIFIED: package-lock + npm registry] |
| `@axe-core/playwright` | installed `4.11.2`; latest `4.11.3` | Per-board WCAG A/AA checks | Already used by `admin-design.spec.ts` [VERIFIED: package-lock + npm registry] |
| Hand-authored `sg-*` CSS | project-owned | Tokens, BEM classes, cascade layers | Explicitly required; no Tailwind/shadcn/Radix for this phase [VERIFIED: `187-UI-SPEC.md`, `AGENTS.md`] |

### Supporting

| Tool | Version | Purpose | When to Use |
|------|---------|---------|-------------|
| `scripts/ci/snapshot-recapture-gate.sh` | repo script | Deliberate visual baseline recapture | Any intended design-board delta [VERIFIED: script grep] |
| `scripts/ci/snapshot-canary-guard.sh` | repo script | Empty-allowlist/canary enforcement | After snapshot changes or before merge [VERIFIED: script grep] |
| `scripts/ci/quality-ledger-monotonic.sh` | repo script | Prevent tier decreases | After ledger edits [VERIFIED: script grep] |
| ExUnit component goldens | repo tests | Byte-golden markup contract | Only when markup/ARIA changes intentionally [VERIFIED: `components_test.exs`] |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Hand-rolled gallery | `phx_storybook` | Rejected/deferred for this milestone; current gallery is build-free and already wired [VERIFIED: `.planning/REQUIREMENTS.md`] |
| Project CSS system | Tailwind/shadcn/Radix/Base UI | Contradicts `sg-*` source-of-truth and Phoenix function-component stack [VERIFIED: `187-UI-SPEC.md`] |
| Screenshot-only proof | DOM/axe/overflow assertions plus curated screenshots | Screenshots alone cannot prove ARIA, inert disabled states, or 320/375/1440 overflow [ASSUMED] |

**Installation:** No new install is recommended. [VERIFIED: local stack]

## Package Legitimacy Audit

No new packages should be installed for this phase. [VERIFIED: `187-UI-SPEC.md`; codebase stack]

| Package | Registry | Age | Downloads | Source Repo | slopcheck | Disposition |
|---------|----------|-----|-----------|-------------|-----------|-------------|
| `@axe-core/playwright` | npm | created 2021-06-02 | npm registry checked; download count not returned by `npm view downloads` | `github.com/dequelabs/axe-core-npm` | OK with `--ecosystem npm`; root auto-detect incorrectly checked PyPI | Existing dependency only |
| `@playwright/test` | npm | created 2020-09-24 | npm registry checked; download count not returned by `npm view downloads` | `github.com/microsoft/playwright` | OK with `--ecosystem npm`; root auto-detect incorrectly checked PyPI | Existing dependency only |

**Packages removed due to slopcheck [SLOP] verdict:** none.  
**Packages flagged as suspicious [SUS]:** none.  
**Audit note:** `slopcheck install @axe-core/playwright @playwright/test` from repo root auto-detected PyPI and produced a false SLOP result; rerunning `slopcheck install --ecosystem npm ...` returned OK. [VERIFIED: local command]

## Architecture Patterns

### System Architecture Diagram

```text
Sigra.Admin.Components (13 Phoenix function components)
        |
        | emits sg-* classes + ARIA/state attrs
        v
Canonical shipped CSS: priv/templates/sigra.install/admin/sigra_admin.css
        |
        | byte-parity copy
        v
Example mirror: test/example/priv/static/assets/sigra_admin.css
        |
        | install golden fixture copy
        v
test/fixtures/install_golden/tree/priv/static/assets/sigra_admin.css

Example-only gallery /admin/_design
        |
        | renders state-matrix boards with real components
        v
Playwright admin-design-{chromium,mobile,dark}
        |
        | per board: axe wcag2a/wcag2aa + screenshot
        v
snapshot baselines + allowlist-design + canary

Ledger update
        |
        | L1 component rows tier 1/2 with evidence
        v
quality-ledger-monotonic.sh prevents regression
```

### Recommended Project Structure

```text
lib/sigra/admin/
└── components.ex                       # markup/ARIA only when needed

priv/templates/sigra.install/admin/
└── sigra_admin.css                     # canonical component CSS target

test/example/priv/static/assets/
├── sigra_admin.css                     # byte mirror of canonical template
└── css/app.css                         # remove migrated sg-* component rules; keep vt-* glue

test/fixtures/install_golden/tree/priv/static/assets/
└── sigra_admin.css                     # fixture copy for golden_diff

test/example/lib/example_web/live/admin/
└── design_gallery_live.ex              # exhaustive state matrices

test/example/priv/playwright/tests/
└── admin-design.spec.ts                # board list, axe, responsive/state checks

guides/reference/
├── admin-quality-ledger.md             # raise L1 rows
└── admin-token-reference.md            # add only net-new motion tokens
```

### Pattern 1: Component-Family Slices

**What:** Batch related components with their CSS migration, gallery states, verification, and ledger evidence. [ASSUMED]  
**When to use:** Use families to keep diffs reviewable while preventing parity drift. [ASSUMED]

Recommended families:

| Family | Components | Why |
|--------|------------|-----|
| Metrics | `stat`, `stat_link`, `summary_chip` | Shared `sg-metric*`, help tooltip, link/read-only distinctions [VERIFIED: `components.ex`, CSS grep] |
| Actions/chips | `task_card`, `applied_chip`, `page_back` | Shared `sg-btn`, CTA/link, remove affordance, disabled/active states [VERIFIED: `components.ex`, CSS grep] |
| Status/content | `notice`, `notice_link`, `empty_state`, `scope_ribbon`, `audit_row` | Tone/status/microcopy/list-row rules [VERIFIED: `components.ex`, CSS grep] |
| Help/loading/code | `field_help`, `skeleton`, `audit_row` code/status details | Tooltip JS, reduced motion, decorative skeleton, `sg-code` [VERIFIED: `admin_hooks.js`, CSS grep] |

### Pattern 2: CSS Migration With Parity Commit Discipline

**What:** Move only the component's `sg-*` visual/state rules from `app.css` into
`sigra_admin.css @layer sg-components`, then sync the example and fixture copies. [VERIFIED: `187-CONTEXT.md`]  
**When to use:** Every component audit slice. [VERIFIED: `187-CONTEXT.md`]

```bash
# Verification pattern after each migration slice:
mix test test/sigra/install/features/admin_test.exs test/sigra/install/golden_diff_test.exs
mix test test/sigra/admin/components_test.exs
bash scripts/ci/quality-ledger-monotonic.sh --base HEAD
```

### Pattern 3: Gallery State Matrix Before Visual Claims

**What:** Expand each board to render applicable states before claiming Ratified/Award-grade. [VERIFIED: `187-CONTEXT.md`, `187-UI-SPEC.md`]  
**When to use:** Before recapturing baselines or raising ledger rows. [ASSUMED]

Required matrix dimensions:

| Component Type | States to Render |
|----------------|------------------|
| Static read-only (`stat`, `empty_state`, `scope_ribbon`) | default plus size/copy/tone variants where applicable [VERIFIED: `187-UI-SPEC.md`] |
| Links/buttons (`stat_link`, `task_card` CTA, `page_back`, `notice_link`, `applied_chip` remove) | default, hover, focus-visible, active, disabled/inert if supported/applicable [VERIFIED: `187-UI-SPEC.md`] |
| Tooltip/help (`summary_chip` help, `field_help`) | closed, open, focus, touch/click/Escape behavior, reduced motion [VERIFIED: `components.ex`, `admin_hooks.js`] |
| Status/tone (`notice`, `audit_row`, `summary_chip`) | neutral/ok/warn/risk/info plus copy and non-color signal [VERIFIED: `design_gallery_live.ex`, `187-UI-SPEC.md`] |
| Loading (`skeleton`) | decorative skeleton plus container `aria-busy` example and reduced-motion static state [VERIFIED: `187-UI-SPEC.md`] |

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Component docs/gallery | New storybook framework | Existing `/admin/_design` gallery | Phase 185 already built the approved instrument [VERIFIED: `185-RESEARCH.md`] |
| A11y scanner | Custom DOM walker | `@axe-core/playwright` in existing spec | Already wired to WCAG A/AA per board [VERIFIED: `admin-design.spec.ts`] |
| Visual baseline gating | Ad hoc screenshot review | `snapshot-recapture-gate.sh` + allowlists + canary | Existing CI recognizes design slugs [VERIFIED: script grep] |
| Markup snapshots | New snapshot library | Existing strict literal ExUnit strings | Contract explicitly forbids snapshot-library churn [VERIFIED: `components_test.exs`] |
| Motion system | Per-component raw durations | Ratified `--sg-motion-*` plus net-new tokens only | Existing values are locked by Phase 186 [VERIFIED: `186-CONTEXT.md`] |
| CSS architecture | Tailwind/util override layer | `sg-*` BEM classes in cascade layers | Required by AGENTS and UI-SPEC [CITED: `AGENTS.md`, `187-UI-SPEC.md`] |

**Key insight:** The hard part is preserving truth across distribution, gallery evidence, and tests. Custom local shortcuts can make the example look good while generated hosts still ship incomplete components. [VERIFIED: `187-CONTEXT.md`]

## Common Pitfalls

### Pitfall 1: Example-Green, Host-Bare CSS

**What goes wrong:** Component states are fixed in `app.css`, so gallery/screenshots pass but generated hosts do not receive the CSS. [VERIFIED: `187-CONTEXT.md`]  
**Why it happens:** Existing visual/state component rules live in example-only `app.css`. [VERIFIED: CSS grep]  
**How to avoid:** Move component CSS to `sigra_admin.css`, remove duplicates from `app.css`, and sync parity surfaces in the same slice. [VERIFIED: `187-CONTEXT.md`]  
**Warning signs:** `rg ".sg-component" priv/templates/sigra.install/admin/sigra_admin.css` returns no rule while `app.css` has it. [VERIFIED: CSS grep]

### Pitfall 2: `notice_link` Falls Through the Per-Component Gate

**What goes wrong:** The current design spec board list has 12 component boards, not 13; `notice_link` is only embedded in `board-notice`. [VERIFIED: `admin-design.spec.ts`]  
**Why it happens:** `notice_link` is naturally a child of `notice`, but Phase 187 says every canonical component. [VERIFIED: `.planning/REQUIREMENTS.md`]  
**How to avoid:** Add `board-notice_link` or add an explicit planner decision that embedded coverage is sufficient and how axe/screenshot evidence is attributed. [ASSUMED]  
**Warning signs:** `COMPONENT_BOARDS` lacks `board-notice_link`. [VERIFIED: `admin-design.spec.ts`]

### Pitfall 3: Golden Churn From CSS Work

**What goes wrong:** Strict byte-goldens are updated even though the change was CSS-only. [VERIFIED: `187-CONTEXT.md`]  
**Why it happens:** Component visual changes can tempt broad "update expected" edits. [ASSUMED]  
**How to avoid:** Only edit `components.ex`/goldens when state semantics require markup/ARIA deltas. [VERIFIED: `187-CONTEXT.md`]  
**Warning signs:** `components_test.exs` diff without a matching markup rationale. [ASSUMED]

### Pitfall 4: Token-Value Regression

**What goes wrong:** Existing `--sg-*` values are retuned in Phase 187. [VERIFIED: `186-CONTEXT.md`]  
**Why it happens:** Motion refinements need new behavior, but existing values are locked. [VERIFIED: `187-CONTEXT.md`]  
**How to avoid:** Add net-new tokens for exit/dropdown needs and document them in `admin-token-reference.md`; never modify existing ratified values. [VERIFIED: `187-CONTEXT.md`]  
**Warning signs:** Diff changes lines for existing `--sg-motion-*`, color, spacing, radius, shadow values. [VERIFIED: `admin-token-reference.md`]

### Pitfall 5: Responsive Widths Are Under-Specified

**What goes wrong:** The mobile Playwright project uses iPhone 13, but COMP-05 asks 320/375/768/1024/1440. [VERIFIED: `playwright.config.ts`, `.planning/REQUIREMENTS.md`]  
**Why it happens:** Existing design lane is a snapshot lane, not a five-width overflow scanner. [VERIFIED: Playwright grep]  
**How to avoid:** Add a deterministic overflow/clip pass for component boards at those widths, likely in `admin-design.spec.ts` or a sibling focused test. [ASSUMED]  
**Warning signs:** Only `admin-design-mobile` screenshots exist as responsive evidence. [VERIFIED: `playwright.config.ts`]

## Component Inventory And Current Coverage

| Component | Current Function | Current Board | Current Known Gap |
|-----------|------------------|---------------|-------------------|
| `stat` | yes | `board-stat` | Static only; CSS in app.css needs migration [VERIFIED: codebase grep] |
| `stat_link` | yes | `board-stat_link` | Needs hover/focus/active matrix and shipped `sg-metric-link` CSS [VERIFIED: codebase grep] |
| `task_card` | yes | `board-task_card` | CTA/button states depend on migrated `sg-btn`/`sg-card-hover` CSS [VERIFIED: codebase grep] |
| `summary_chip` | yes | `board-summary_chip` | Help open/focus/tone matrix needs complete evidence [VERIFIED: `design_gallery_live.ex`] |
| `applied_chip` | yes | `board-applied_chip` | Remove affordance states and inert/disabled semantics need decision [VERIFIED: `187-UI-SPEC.md`] |
| `empty_state` | yes | `board-empty_state` | Copy in current board says “Adjust your filters.”; UI-SPEC says “Try adjusting your filters.” [VERIFIED: `design_gallery_live.ex`, `187-UI-SPEC.md`] |
| `page_back` | yes | `board-page_back` | Current label “Dashboard” differs from contract leaf-return style [VERIFIED: `design_gallery_live.ex`, `admin-design-contract.md`] |
| `scope_ribbon` | yes | `board-scope_ribbon` | Static variants present; shipped CSS/rhythm still needs migration audit [VERIFIED: `design_gallery_live.ex`] |
| `notice` | yes | `board-notice` | Canary board; all tones present, but state/link attribution must remain stable [VERIFIED: `design_gallery_live.ex`] |
| `notice_link` | yes | embedded only | Missing standalone board in `COMPONENT_BOARDS` [VERIFIED: `admin-design.spec.ts`] |
| `field_help` | yes | `board-field_help` | Board renders hidden panel only; needs open/focus/click/Escape states [VERIFIED: `design_gallery_live.ex`, `admin_hooks.js`] |
| `skeleton` | yes | `board-skeleton` | Needs reduced-motion/static proof and `aria-busy` container example [VERIFIED: `187-UI-SPEC.md`] |
| `audit_row` | yes | `board-audit_row` | Tones/compact/full present; status pill/code CSS migration required [VERIFIED: `design_gallery_live.ex`, CSS grep] |

## Code Examples

### Existing Axe + Board Screenshot Pattern

```typescript
// Source: test/example/priv/playwright/tests/admin-design.spec.ts
const { violations } = await new AxeBuilder({ page })
  .withTags(['wcag2a', 'wcag2aa'])
  .analyze();
expect(violations, `${label}: axe violations\n${detail}`).toHaveLength(0);

await expect(page.locator(`#${boardId}`)).toHaveScreenshot(`${boardId}.png`, {
  maxDiffPixels: ci ? 200_000 : dark ? 75_000 : mobile ? 45_000 : 30_000,
  maxDiffPixelRatio: ci ? 0.22 : dark ? 0.1 : mobile ? 0.08 : 0.06,
});
```

### Existing Strict Component Golden Pattern

```elixir
# Source: test/sigra/admin/components_test.exs
html =
  render_component(&Components.task_card/1,
    title: "Invite your team",
    body: "Add teammates.",
    href: "/admin/users/invite",
    action: "Send invitations"
  )

assert html == @task_card_golden,
       "task_card drifted — see admin-design-contract.md; do not re-record Playwright baselines"
```

### Existing Field Help Markup Contract

```elixir
# Source: lib/sigra/admin/components.ex
<button
  type="button"
  class="sg-field-help__trigger"
  aria-label={"Help: " <> @label}
  aria-controls={@id}
  aria-describedby={@id}
  aria-expanded="false"
  data-sg-field-help-trigger="true"
>
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Example-owned admin CSS | Shipped `sigra_admin.css` with example byte mirror | Phase 184 | 187 must finish migrating component rules, not add more `app.css` styling [VERIFIED: `184` artifacts, `187-CONTEXT.md`] |
| Page-only visual checkpoints | Component/group board snapshots with axe | Phase 185 | 187 can prove per-component states in the gallery [VERIFIED: `185-RESEARCH.md`] |
| Token tuning during audits | Token values locked after L0 | Phase 186 | 187 may add tokens but not retune existing values [VERIFIED: `186-CONTEXT.md`] |
| Single default board examples | Exhaustive state matrices | Phase 187 target | Planner must expand boards before claiming COMP-01/03 [VERIFIED: `.planning/REQUIREMENTS.md`] |

**Deprecated/outdated:**
- Adding new `sg-*` component CSS to `test/example/priv/static/assets/css/app.css` is outdated for component-owned styles; use shipped `sigra_admin.css`. [VERIFIED: `187-CONTEXT.md`]
- Using `transition: all` is forbidden; use exact-property transitions. [VERIFIED: `187-UI-SPEC.md`, `admin-ui-principles.md`]
- Treating color alone as status is insufficient; pair tone with copy/border/icon/glyph/shape. [VERIFIED: `admin-ui-principles.md`, `187-UI-SPEC.md`]

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Family-based execution is better than one component per plan or one giant plan. | Summary, Pattern 1 | Planner may choose different slicing; verification remains the same. |
| A2 | Screenshot-only proof is insufficient for state quality. | Alternatives | Low risk; axe/DOM/overflow requirements independently require non-screenshot assertions. |
| A3 | Add a standalone `board-notice_link` unless embedded coverage is explicitly justified. | Pitfalls | Could add one more baseline than desired, but aligns with 13-component requirement. |
| A4 | Add a deterministic five-width overflow pass in Playwright. | Pitfalls | Exact implementation may differ, but COMP-05 requires width evidence. |

## Open Questions

1. **Should `notice_link` get a standalone board?**
   - What we know: It is canonical and has a component function; current board list omits it. [VERIFIED: `components.ex`, `admin-design.spec.ts`]
   - What's unclear: Whether embedded coverage inside `board-notice` is acceptable to the reviewer.
   - Recommendation: Add `board-notice_link` for clean per-component attribution. [ASSUMED]

2. **Which components truly need markup changes?**
   - What we know: CSS-only changes should cause zero byte-golden churn. [VERIFIED: `187-CONTEXT.md`]
   - What's unclear: Disabled/inert/loading/error states may require attributes/classes on some components.
   - Recommendation: Decide per component during audit; require a one-line golden rationale for every markup delta. [VERIFIED: `187-CONTEXT.md`]

3. **How much behavior testing should accompany tooltip states?**
   - What we know: JS hooks implement summary metric and field-help open/close/Escape/outside behavior. [VERIFIED: `admin_hooks.js` grep]
   - What's unclear: Whether Phase 187 should add behavior assertions or only render open states in gallery.
   - Recommendation: Add minimal deterministic behavior checks for `field_help` and `summary_chip` help because their states are JS-dependent. [ASSUMED]

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|-------------|-----------|---------|----------|
| Elixir / Mix | ExUnit component/install tests | yes | Elixir/Mix `1.19.5` | none needed |
| Erlang/OTP | Elixir runtime | yes | OTP `28` | none needed |
| Node.js | Playwright | yes | `v22.14.0` | none needed |
| npm | Playwright deps/scripts | yes | `11.1.0` | none needed |
| `@playwright/test` | Browser tests | yes | installed `1.59.1` | none needed |
| `@axe-core/playwright` | Axe board scans | yes | installed `4.11.2` | none needed |
| `ctx7` | Optional docs lookup | no | — | codebase/project docs are sufficient for this local-stack phase |
| `slopcheck` | Package audit | yes | command available | Force `--ecosystem npm` for scoped npm packages |

**Missing dependencies with no fallback:** none found.  
**Missing dependencies with fallback:** `ctx7` absent; this phase is governed by local project docs and existing code, so no package API doc lookup is blocking. [VERIFIED: local command]

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | ExUnit + Playwright + axe-core [VERIFIED: `mix.exs`, `package-lock.json`, `admin-design.spec.ts`] |
| Config file | `mix.exs`; `test/example/priv/playwright/playwright.config.ts` |
| Quick run command | `mix test test/sigra/admin/components_test.exs test/sigra/install/features/admin_test.exs` |
| Full suite command | `mix test test/sigra/admin/components_test.exs test/sigra/install/features/admin_test.exs test/sigra/install/golden_diff_test.exs && (cd test/example/priv/playwright && npx playwright test tests/admin-design.spec.ts --project=admin-design-chromium --project=admin-design-mobile --project=admin-design-dark)` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|--------------|
| COMP-01 | 13 components render exhaustive state matrices | Playwright + DOM | `cd test/example/priv/playwright && npx playwright test tests/admin-design.spec.ts --project=admin-design-chromium` | yes, needs board expansion |
| COMP-02 | Motion exact-property, pointer-gated, reduced-motion | CSS grep + Playwright reduced-motion check | `rg "transition: all" priv/templates/sigra.install/admin/sigra_admin.css test/example/priv/static/assets/css/app.css` plus focused Playwright | partial |
| COMP-03 | States visually distinct and disabled inert | Playwright DOM/state assertions + screenshots | `cd test/example/priv/playwright && npx playwright test tests/admin-design.spec.ts --project=admin-design-chromium` | partial |
| COMP-04 | Axe light/dark clean and ARIA/goldens intentional | Playwright axe + ExUnit | `mix test test/sigra/admin/components_test.exs && cd test/example/priv/playwright && npx playwright test tests/admin-design.spec.ts --project=admin-design-dark` | yes |
| COMP-05 | No overflow/clip/squish at 320/375/768/1024/1440 | Playwright viewport loop | Needs new/focused assertions in `admin-design.spec.ts` | no |
| COMP-06 | Component-local microcopy on-brand | ExUnit/rendered gallery review + snapshots | `mix test test/sigra/admin/components_test.exs` plus board review | partial |

### Sampling Rate

- **Per task commit:** `mix test test/sigra/admin/components_test.exs test/sigra/install/features/admin_test.exs` [ASSUMED]
- **Per wave merge:** Full design lane for affected boards plus `golden_diff_test.exs` and `quality-ledger-monotonic.sh --base HEAD` [ASSUMED]
- **Phase gate:** Full admin design trio, snapshot canary/recapture as needed, install golden, component goldens, ledger monotonic green. [VERIFIED: existing scripts/specs]

### Wave 0 Gaps

- [ ] Add `board-notice_link` or document embedded-board attribution for COMP-01/04. [VERIFIED: current board list]
- [ ] Add five-width overflow/clip assertions for component boards at 320/375/768/1024/1440. [VERIFIED: COMP-05; Playwright grep]
- [ ] Add or expose deterministic open states for `field_help` and summary-chip help in gallery. [VERIFIED: current gallery hidden/default states]
- [ ] Inventory exact `sg-*` CSS blocks by component before moving them; use the inventory as the migration checklist. [VERIFIED: CSS grep]

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|------------------|
| V2 Authentication | no | Existing admin auth/session gates are not changed in this phase [VERIFIED: phase scope] |
| V3 Session Management | no | Existing LiveView/session behavior unchanged [VERIFIED: phase scope] |
| V4 Access Control | no | Gallery remains example/dev-only; no installer route leakage [VERIFIED: `185-RESEARCH.md`] |
| V5 Input Validation | yes, limited | Do not add dynamic inputs; keep component assigns escaped by HEEx and tested by render goldens [VERIFIED: Phoenix component pattern in `components.ex`] |
| V6 Cryptography | no | No cryptographic behavior in scope [VERIFIED: phase scope] |

### Known Threat Patterns for Phoenix LiveView Admin Components

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Gallery route leaks into generated hosts | Information Disclosure | Keep gallery under `test/example`; contract guard from Phase 185 [VERIFIED: `185-RESEARCH.md`] |
| Tooltip/help content becomes interactive and traps focus poorly | Denial of Service / Accessibility failure | Keep `role="tooltip"` non-interactive; use native button trigger and Escape/outside close [VERIFIED: `admin-design-contract.md`, `admin_hooks.js`] |
| Disabled visual state remains clickable | Elevation of Privilege / Tampering via mistaken action | Ensure disabled components are inert, not just dimmed [VERIFIED: `187-UI-SPEC.md`] |
| Raw HTML in component slots | XSS | Keep HEEx escaping and avoid unsafe raw rendering in component-local microcopy [VERIFIED: `components.ex` pattern] |

## Sources

### Primary (HIGH confidence)

- `.planning/phases/187-individual-components-l1/187-CONTEXT.md` — locked decisions and scope.
- `.planning/phases/187-individual-components-l1/187-UI-SPEC.md` — UI contract, state/motion/copy requirements.
- `.planning/REQUIREMENTS.md` — COMP-01..06.
- `.planning/ROADMAP.md` — Phase 187 dependency and success criteria.
- `AGENTS.md`, `guides/reference/admin-ui-principles.md`, `guides/reference/admin-design-contract.md` — admin UI constraints.
- `guides/reference/admin-fractal-scorecard.md`, `guides/reference/admin-quality-ledger.md`, `guides/reference/admin-token-reference.md` — scorecard, ledger, token/motion lock.
- `lib/sigra/admin/components.ex` — component inventory and markup/ARIA.
- `test/example/lib/example_web/live/admin/design_gallery_live.ex` — current gallery coverage.
- `test/example/priv/playwright/tests/admin-design.spec.ts` and `playwright.config.ts` — board screenshot/axe lane.
- `test/sigra/admin/components_test.exs`, `test/sigra/install/features/admin_test.exs`, `test/sigra/install/golden_diff_test.exs` — golden/parity tests.

### Secondary (MEDIUM confidence)

- npm registry checks for `@axe-core/playwright` and `@playwright/test` latest versions and repository URLs.
- Hex registry checks for `phoenix` and `phoenix_live_view` locked/recent versions.

### Tertiary (LOW confidence)

- Assumed execution slicing and exact assertion placement where the planner has discretion.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — verified from lockfiles, registry commands, and local config.
- Architecture: HIGH — governed by locked context plus codebase evidence.
- Pitfalls: HIGH for identified code/test gaps; MEDIUM for recommended exact remediation shape.

**Research date:** 2026-06-14  
**Valid until:** 2026-07-14 for local architecture; 2026-06-21 for npm latest-version references.
