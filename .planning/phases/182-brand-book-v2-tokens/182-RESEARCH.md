# Phase 182: Brand Book v2 + Tokens — Research

**Researched:** 2026-06-12
**Domain:** Static HTML brand collateral, axe accessibility, design token versioning, SVG specimen updates
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Already done — do not redo:**
- Production logo SVGs at `brandbook/*.svg` are the ratified v2 D4 Linked Rail assets (Phase 181). Do NOT regenerate logo assets.
- `README.md` already states v2 assets exist and `archive-v1/` holds v1. Its Files table still labels 5 entries "Rail Accent" and omits `logo-primary-subtitle.svg` + `social-card-dark.svg` — fix the table.

**index.html v2 (BRAND2-09):**
- Standalone, disk-openable, NO build/CDN/web-font/runtime dependency (already links only `tokens.css` — keep it that way).
- Expand the `#logo` section: multi-lockup set (primary, dark, subtitle variant, mark-only, monochrome, favicon, social cards), integrated-typemark anatomy (rail-block tittle + linked g-tail), clearspace, minimum sizes, misuse examples.
- Add szTheory suite architecture section (shared-vs-per-library, naming all 7 libs).
- Existing 8-section structure (#judgment #dna #tokens #logo #examples #voice #blueprint #artifacts) is sound — extend, don't rewrite.

**Tokens (BRAND2-10):**
- `tokens.json`: increment `version` (currently `1.0.0`) and add a `changed` date to `meta`. Token VALUES unchanged.
- `tokens.css`: hand-sync from tokens.json; add provenance header comment. No generator script.
- Token change policy: add section to `README.md` describing semver on `tokens.json version`, what a bump means for consumers (admin sg-*, auth sigra_auth.css), and that consuming surfaces reference the token not a hardcoded hex.

**Specimens (BRAND2-09 criterion 4):**
- `examples/landing-hero.svg` is stale (draws v1 Rail Accent mark inline) — update to D4 mark geometry.
- `examples/readme-header.svg` is ALSO stale (same v1 staggered bars path) — discovered during research.
- Remaining 7 specimens (palette, docs-page, code-block, architecture-diagram, terminal, typography, component-states) are CLEAN — verified, no update needed.

**axe (BRAND2-09 criterion 2):**
- Create committed script `scripts/brand/axe-brandbook.mjs` (reuse playwright-core + @axe-core/playwright from `test/example/priv/playwright/node_modules` via `createRequire`).
- Script must exit 0 on zero violations, non-zero otherwise.
- Do NOT commit screenshots.

### Claude's Discretion
- Exact prose of the suite-architecture and token-change-policy sections.
- Whether the axe runner is a new committed `scripts/brand/axe-brandbook.mjs` or folded into the existing playwright project. **Research recommendation: committed script (`scripts/brand/axe-brandbook.mjs`) for self-containment and repeatability in Phase 183.**
- index.html layout details for the expanded logo-system section (must stay dependency-free).

### Deferred Ideas (OUT OF SCOPE)
- Propagation into `priv/templates`, `test/example`, `sg-*` tokens, `sigra_auth.css`, admin-design-contract → Phase 183
- Playwright admin baseline recapture → Phase 183
- README header / GitHub social preview adoption → post-milestone fast-follow
- Sibling-library brandbooks (suite architecture documents the framework; building them is separate work)
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| BRAND2-09 | `brandbook/index.html` upgraded to standalone v2, opening from disk with no build/CDN/web-font dependency, passing an axe accessibility check, reflecting all audit verdicts and the ratified D4 logo system | Axe harness recipe (Section 1), probable violations pre-empted (Section 2), structural content direction (Section 5) |
| BRAND2-10 | `tokens.json` and `tokens.css` version-bumped per ratified decisions with documented token change policy; `examples/` specimens with old mark regenerated | Token bump mechanics (Section 3), sync mechanics (Section 4), two stale specimens identified (Section 5) |
</phase_requirements>

---

## Summary

Phase 182 is a brand collateral upgrade: no runtime Elixir code changes, no installer template propagation (that's Phase 183). The work is bounded to `brandbook/` and `scripts/brand/`. The design decisions are largely locked — the research focus is execution mechanics for the five technical risks: (1) the axe harness recipe, (2) likely violations in the current HTML, (3) token version policy conventions, (4) tokens.css sync provenance, and (5) which specimens are actually stale.

The axe harness is solved cleanly: `scripts/brand/axe-brandbook.mjs` can reuse the `createRequire` pattern already proven in `critique-render.mjs` to load `playwright-core` from `test/example/priv/playwright/node_modules`, and then load `@axe-core/playwright` from the same location. `@axe-core/playwright` v4.11.2 is already installed there; its peer dependency is `playwright-core >= 1.0.0` (confirmed). The script serves `brandbook/index.html` via a localhost `python3 -m http.server` subprocess (preferred over `file://` for axe script injection reliability), runs `AxeBuilder({page}).withTags(['wcag2a','wcag2aa']).analyze()` (same tags as admin-checkpoints.spec.ts), and exits 0 on zero violations. No new npm installs needed.

The current `index.html` is substantially clean against `wcag2a`/`wcag2aa`: all computed color contrasts pass (lowest is muted text #686868 on warm bg #f6f5f2 at 5.11:1, well above the 4.5 threshold), all images have alt text, the document has `lang="en"`, all nav links have text, meters have proper ARIA attributes. The one genuine structural fix needed before the axe pass is adding `id="scorecard"` and an `aria-labelledby` to the unnamed `<section>` (the scorecard section), which is the only section without an id. Two specimens were found stale: `landing-hero.svg` and `readme-header.svg` both embed the v1 staggered-bars geometry — both need updating to the D4 mark geometry.

**Primary recommendation:** Commit `scripts/brand/axe-brandbook.mjs` as a reusable harness (mirrors critique-render.mjs pattern), fix the unnamed scorecard section before the axe pass, and treat the two stale specimens as a single task since they share the same v1 mark geometry.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| axe accessibility check | scripts/brand/ harness | playwright-core (via test/example install) | Brand-toolchain-only concern; no Phoenix/LiveView involved |
| index.html content | brandbook/ (static HTML) | tokens.css (CSS variables) | Self-contained; no server, no build |
| Token version policy | brandbook/README.md | brandbook/tokens.json meta | Documentation lives adjacent to the artifact it documents |
| Specimen SVG updates | brandbook/examples/ | (none) | Purely static SVG authoring |
| tokens.css sync | brandbook/tokens.css | brandbook/tokens.json | Hand-maintained sync; no generator |

---

## Section 1: axe Harness — Concrete Recipe

### Approach: localhost http server + AxeBuilder

`file://` URLs work with Playwright for screenshots (proven in `critique-render.mjs`), but axe-core injects itself via `page.evaluate()` and some browsers have stricter CORS behavior on `file://` origins for injected scripts. The safest, most reproducible approach is a short-lived `python3 -m http.server` subprocess serving `brandbook/` on an ephemeral port. This is:
- Zero new dependencies (python3 is confirmed available at 3.14.4)
- Consistent with how real browsers serve HTML
- Avoids any CORS / `file://` ambiguity

### Key Facts Verified

| Fact | Source | Confidence |
|------|--------|------------|
| `@axe-core/playwright` v4.11.2 installed at `test/example/priv/playwright/node_modules` | `ls node_modules/@axe-core` [VERIFIED: filesystem] | HIGH |
| `@axe-core/playwright` peer dep is `"playwright-core": ">= 1.0.0"` | `package.json` peerDependencies [VERIFIED: filesystem] | HIGH |
| `playwright-core` v1.59.1 installed at `test/example/priv/playwright/node_modules` | `package.json` version field [VERIFIED: filesystem] | HIGH |
| Chromium binary available at `~/Library/Caches/ms-playwright/chromium-1223/` | `ls ~/Library/Caches/ms-playwright/` [VERIFIED: filesystem] | HIGH |
| `AxeBuilder` is named export AND default export | `node -e "Object.keys(require(...))"` [VERIFIED: runtime] | HIGH |
| `AxeBuilder` constructor signature: `constructor({ page, axeSource })` | `dist/index.js` line 137 [VERIFIED: filesystem] | HIGH |
| `createRequire` pattern works to load from `test/example/priv/playwright/` | Proven in `scripts/brand/critique-render.mjs` [VERIFIED: codebase] | HIGH |
| `admin-checkpoints.spec.ts` uses `.withTags(['wcag2a', 'wcag2aa'])` | Line 120-122 [VERIFIED: filesystem] | HIGH |

### `scripts/brand/axe-brandbook.mjs` — Script Skeleton

```javascript
#!/usr/bin/env node
// axe accessibility check for brandbook/index.html
// Usage: node scripts/brand/axe-brandbook.mjs
// Exits 0 on zero violations; non-zero otherwise.
// Prerequisites: python3 available; playwright-core + @axe-core/playwright
//   already installed at test/example/priv/playwright/node_modules/.

import { createRequire } from 'module';
import { spawn } from 'child_process';
import { resolve, dirname } from 'path';
import { fileURLToPath } from 'url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const playwrightBase = resolve(__dirname, '../../test/example/priv/playwright/');
const require = createRequire(playwrightBase + '/package.json');
const { chromium } = require('playwright-core');
const { default: AxeBuilder } = require('@axe-core/playwright');

const brandbookDir = resolve(__dirname, '../../brandbook');
const PORT = 7743; // arbitrary free-ish port

// Start python3 static server
const server = spawn('python3', ['-m', 'http.server', String(PORT), '--directory', brandbookDir], {
  stdio: 'ignore',
});

// Give the server a moment to bind
await new Promise(r => setTimeout(r, 600));

let exitCode = 0;
try {
  const browser = await chromium.launch({ headless: true });
  const page = await browser.newPage();
  await page.goto(`http://localhost:${PORT}/index.html`);
  const { violations } = await new AxeBuilder({ page })
    .withTags(['wcag2a', 'wcag2aa'])
    .analyze();

  if (violations.length === 0) {
    console.log('axe: PASS — zero violations on brandbook/index.html');
  } else {
    console.error(`axe: FAIL — ${violations.length} violation(s):`);
    for (const v of violations) {
      console.error(`  [${v.impact}] ${v.id}: ${v.description}`);
      for (const node of v.nodes.slice(0, 2)) {
        console.error(`    node: ${node.target.join(', ')}`);
      }
    }
    exitCode = 1;
  }
  await browser.close();
} finally {
  server.kill();
}

process.exit(exitCode);
```

### Gotchas and Notes

- **`file://` vs localhost:** axe-core uses `page.evaluate()` to inject the axe script. While file:// generally works with Playwright/Chromium, localhost avoids any potential CORS-adjacent issues with script injection from a different origin. Using `python3 -m http.server` adds ~600ms startup but is zero-dep. [VERIFIED: python3 3.14.4 available on this machine]
- **`@axe-core/playwright` does NOT require `@playwright/test`:** the peer dep is `playwright-core >= 1.0.0` only. The `AxeBuilder` constructor takes a `Page` object; `playwright-core` provides the same `Page` interface. [VERIFIED: package.json peerDependencies]
- **CJS/ESM:** `scripts/brand/package.json` has `"type": "module"`. The `createRequire` pattern from `critique-render.mjs` handles requiring CJS modules from an ESM context — the same pattern loads `@axe-core/playwright` and `playwright-core`.
- **Port collision:** Port 7743 is not commonly assigned. If the planner wants to be extra safe, use a dynamic port with `net.createServer` probe first — but this adds complexity. 7743 is low-risk for a short-lived script.
- **No screenshots:** Do not call `page.screenshot()` in this script. CONTEXT explicitly says "do NOT commit screenshots."
- **Script location:** `scripts/brand/axe-brandbook.mjs` — consistent with `critique-render.mjs` and `outline-wordmark.mjs` siblings.
- **No new `npm install` needed:** Both `playwright-core` and `@axe-core/playwright` are already installed; `scripts/brand/package.json` does not need updating.

---

## Section 2: Probable axe Violations in Current index.html

### Pre-computed Color Contrasts [VERIFIED: computed from hex values in tokens.css + index.html inline styles]

All ratios are against `wcag2a`/`wcag2aa` thresholds (4.5:1 for normal text, 3:1 for large text ≥18pt or bold ≥14pt).

| Pair | Foreground | Background | Ratio | Pass? |
|------|------------|------------|-------|-------|
| Body text | #151515 | #f6f5f2 | 16.75 | PASS |
| Muted text | #686868 | #ffffff (surface) | 5.57 | PASS |
| Muted text | #686868 | #f6f5f2 (warm bg) | 5.11 | PASS |
| Accent text (eyebrow) | #c2410c | #ffffff | 5.18 | PASS |
| Accent text | #c2410c | #f6f5f2 | 4.75 | PASS |
| Asset links | #9a3412 | #fff0e8 | 6.57 | PASS |
| Button text | #ffffff | #c2410c | 5.18 | PASS |
| Ember-800 on soft | #9a3412 | #fff0e8 | 6.57 | PASS |
| Swatch: white on ink | #ffffff | #151515 | 18.26 | PASS |
| Swatch: fdba74 on dark-900 | #fdba74 | #171614 | 10.72 | PASS |
| Terminal text | #f4f1eb | #151515 | 16.20 | PASS |
| Dark mode: muted | #bdb5aa | #171614 | 8.92 | PASS |
| Footer muted on bg | #686868 | #f6f5f2 | 5.11 | PASS |

**Contrast verdict: NO violations expected.** All pairs pass WCAG AA. The lowest ratio (4.75 for accent eyebrow text on warm bg) is still above 4.5.

### Structural Analysis [VERIFIED: direct inspection of index.html]

| Check | Status | Notes |
|-------|--------|-------|
| `<html lang="en">` | PASS | Present |
| `<title>Sigra Brand Book</title>` | PASS | Present |
| All `<img>` have alt text | PASS | favicon.svg in brand-chip has `alt=""` (decorative — correct); all others have descriptive alt |
| Heading order | PASS | h1 → h2 → h3 → h2 → h3 ... (no skipped levels) |
| `<nav aria-label="Brand book sections">` | PASS | Label present |
| `<figure>` elements with `<figcaption>` | PASS | All 6 figures have captions |
| All `<a>` have accessible text | PASS | All 12 links have non-empty text content |
| Meter role ARIA attrs | PASS | All 5 meters have `aria-label`, `aria-valuemin`, `aria-valuemax`, `aria-valuenow` |
| `<pre tabindex="0">` | PASS | Makes scrollable region keyboard-accessible (required by `scrollable-region-focusable` rule) |
| `<main>` landmark | PASS | Present |
| `<aside>` landmark | NOTE | No `aria-label` on aside — but `landmark-complementary` needing a label is a `best-practice` rule, NOT `wcag2a`/`wcag2aa`. Scoped tags exclude it. |

### One Genuine Fix Needed

**Unnamed `<section>` (scorecard section):** There is one `<section>` without an `id` attribute (the scorecard section, between `#dna` and `#tokens`). The axe `region` rule fires when a `<section>` has no accessible name. However, `region` is tagged **`best-practice`**, not `wcag2a` or `wcag2aa`. With `.withTags(['wcag2a', 'wcag2aa'])` this will NOT fire.

**Verdict: No pre-emptive structural fixes required for the axe pass with `wcag2a`/`wcag2aa` tags.** The planner should still add an `id="scorecard"` to that section as part of the content expansion (needed for the new nav link anyway), which eliminates any future concern.

### Risk Summary

| Risk | Likelihood | Mitigation |
|------|-----------|------------|
| Color contrast violations | LOW — all pairs verified > 4.5:1 | Pre-computed above |
| Missing alt text on new logo images added in v2 | MEDIUM — new logo-system section will add more `<img>` tags | Planner must ensure all new `<img>` in logo-system section have alt text |
| `region` rule on unnamed section | NOT APPLICABLE — scoped to wcag2a/wcag2aa | Noted above |
| New content in v2 introduces contrast issue | LOW — all palette values are tokens with verified ratios | Apply same tokens, no new color values |
| `file://` CORS on axe injection | MITIGATED — using localhost server | Harness recipe above |

---

## Section 3: Token Change-Policy Conventions

### Design Tokens Community Group (DTCG) Norms [ASSUMED — based on DTCG community conventions and industry practice; not verified against a live DTCG document in this session]

The DTCG format spec (`$schema: https://design-tokens.github.io/community-group/format/`) does not mandate a version field. The existing `tokens.json` uses a non-prefixed `"version"` at top level (not `"$version"`), which is consistent with a custom extension rather than a DTCG-native field.

Industry norm for design token versioning in mature systems (Tailwind, Radix, IBM Carbon) follows **semver semantics** applied to the token file version:

| Change type | Semver level | Example |
|-------------|-------------|---------|
| New token added | minor (`X.Y+1.0`) | Added `social-card-dark` color token |
| Token VALUE changed | minor if additive, major if breaking | Accent hue shift |
| Token REMOVED or RENAMED | major (`X+1.0.0`) | Deletes a consuming surface's variable |
| Metadata only (version/changed) | patch (`X.Y.Z+1`) | Added `changed` field |

For Phase 182: no token values change, only metadata (`changed` date added). This is a **patch bump**: `1.0.0` → `1.0.1`.

### Proposed Version Bump

```json
{
  "name": "Sigra brand tokens",
  "version": "1.0.1",
  "meta": {
    "source": "...",
    "policy": "...",
    "license": "...",
    "changed": "2026-06-12"
  }
}
```

### Proposed Token Change Policy Text (for README.md)

Add as a new `## Token Change Policy` section in `brandbook/README.md`:

```markdown
## Token Change Policy

`tokens.json` follows semantic versioning on the `version` field:

- **Patch** (`1.0.x`): metadata-only changes — `changed` date, `source` annotation updates. No consuming surface requires changes.
- **Minor** (`1.x.0`): new tokens added. Consuming surfaces (`--sg-*` in admin CSS, `--sigra-auth-*` in sigra_auth.css) may reference the new token but are not required to.
- **Major** (`x.0.0`): token value changed or token removed. Consuming surfaces **must** review the diff and update hardcoded fallbacks before shipping.

**Three-surface ember parity rule:** `ember-700: #c2410c` is the canonical accent value consumed by three independent surfaces — `brandbook/tokens.json`, admin CSS (`--sg-color-brand`), and auth CSS (`--sigra-auth-light-accent`). Any new surface carrying the Sigra brand accent must reference the brandbook token rather than hardcoding `#c2410c`. When the token value changes (major bump), all three surfaces must be updated atomically in the same PR.

The `meta.changed` date uses ISO 8601 (`YYYY-MM-DD`). It records the last date any token value or file structure changed — metadata-only patches do not reset it.
```

This is SHORT, idiomatic, and precise. It does not use "semver for design tokens" as a formal spec name — it applies the concept directly. [ASSUMED — policy shape; exact prose is Claude's discretion per CONTEXT]

---

## Section 4: tokens.css ↔ tokens.json Sync Mechanics

### Current State [VERIFIED: direct comparison of both files]

All CSS custom property values in `tokens.css` match the resolved values in `tokens.json`. Spot-checked 14 key pairs (all semantic light-mode color tokens, all typography, all spacing, all radius values) — zero discrepancies found.

The `tokens.css` file has **no provenance header comment**. It begins directly with `:root {`. This needs to be added.

### Provenance Header to Add

```css
/* Sigra brand tokens — CSS custom properties
 * Derived from brandbook/tokens.json v1.0.1
 * Hand-maintained sync. When tokens.json version changes, update this file
 * and increment the version reference above.
 * Do not add web fonts, external imports, or CDN links.
 */
```

### Hand-Sync vs Generator Decision

CONTEXT locks this as hand-sync (no generator script). This is **reasonable** given:
- The file is ~165 lines, clearly structured, rarely changes
- A generator would add complexity (`node scripts/brand/generate-tokens.mjs`) for a phase with zero token value changes
- The Phase 182 change is purely additive (one header comment + version bump in the header)
- The README `Maintenance Rules` already states: "Token changes must update both `tokens.json` and `tokens.css`."

**Recommendation: keep hand-sync.** The provenance header comment is the only addition needed. A generator is a nice-to-have for a future phase with significant token additions. [VERIFIED: hand-sync is locked in CONTEXT; this confirms it is reasonable]

---

## Section 5: szTheory Suite Architecture Section — Factual Skeleton

### Source Material [VERIFIED: `brandbook/pressure-test-audit-v2.md` Section 8; `test/example/priv/static/images/vaultr-mark.svg`]

**vaultr-mark.svg exists and shows:** A teal/dark-teal shield with a cross (+) and an arc/smile beneath — domain metaphor: vault + protection. Colors: `#13b7a7` to `#045f73` (linear gradient), `#0d242b` background, `#e8fbf7` cross. Accent hue ~175° (teal) — contrast to Sigra's ember (hue ~15°). This confirms the per-library color diversity principle.

**The seven libraries (from STATE.md and audit):** Sigra, Accrue, Mailglass, Threadline, Lockspire, Relyra, Rulestead.

**Domain metaphors (from audit Section 8):**
- Sigra = rails (protected core framed by host-code rails)
- Accrue = ledger (accumulation, precision)
- Mailglass = transparency (visible delivery)
- Threadline = trace
- Lockspire = lock/spire
- Relyra = reliability
- Rulestead = governance

### Shared vs Per-Library Framework

| Element | Shared | Per-Library | Evidence |
|---------|--------|-------------|----------|
| OFL wordmark typeface | Yes — whichever Phase 180 ratified (Space Grotesk v2.0) | No | Audit Section 8: "OFL font family for wordmarks" |
| Design vocabulary | Yes — precision, explicitable contracts, host-owned behavior | No | Audit Section 8 |
| Voice register | Yes — maintainer-grade technical | No | Audit Section 8 |
| Token naming convention | Yes — `--sg-*` namespace established | No | VERIFIED: app.css lines 67–76 |
| Layout conventions | Yes — same docs layout + badge style | No | Audit Section 8 |
| Mark/glyph | No | Yes — distinct per domain | vaultr-mark.svg (teal shield vs Sigra ember rail) |
| Accent color | No | Yes — unique hue, ≥15° from any sibling | vaultr-mark.svg ~175°; Sigra ember ~15° |
| Domain metaphor in mark | No | Yes — see domain list above | Audit Section 8 |

### New Library Onboarding Decision Framework (3 rules)

1. Inherit the ratified Suite wordmark typeface (Space Grotesk v2.0, wght 700, OFL).
2. Adopt a unique mark reflecting the library's domain metaphor.
3. Select an accent hue at least 15° from any existing sibling's accent on the color wheel.

No other shared-element constraint applies; the library owns its own brandbook.

### Suite Architecture Section Placement in index.html

Add as a subsection within or after the expanded `#logo` section (or as a standalone `#suite` section). The audit recommends "add, not redesign" — a new `<section id="suite">` is the cleanest approach. Content: table of 7 libs (name, domain metaphor, accent hue) + 3 onboarding rules. The section should show vaultr-mark.svg as a concrete per-library color diversity example (it is already committed at `test/example/priv/static/images/vaultr-mark.svg`, but that path is outside `brandbook/` — reference by description, or copy the SVG into `brandbook/examples/` for self-containment, or render it inline).

**Recommendation:** Reference vaultr-mark.svg by description (don't copy it — that would be cross-cutting scope). In the suite section, describe the per-library mark principle without embedding an external file. [ASSUMED — prose approach; Claude's discretion per CONTEXT]

---

## Section 6: Stale Specimens — What to Fix

### Confirmed Stale [VERIFIED: direct inspection of SVG path data]

| File | Stale Element | Fix |
|------|--------------|-----|
| `examples/landing-hero.svg` | `<g transform="translate(98 96)">` paths: `M17 14v14`, `M32 23v18`, `M47 36v14`, `M17 36v14`, `M47 14v14`, `M17 32h30` — the v1 staggered vertical bars + horizontal core line geometry | Replace inline mark `<g>` with D4 geometry: vertical stem + leftward foot (ink) + ember block (rect) |
| `examples/readme-header.svg` | Same v1 paths at `<g transform="translate(88 88) scale(0.9)">` | Same fix |

### Confirmed Clean [VERIFIED: grep of path data + Rail Accent text]

- `examples/palette.svg` — no mark geometry
- `examples/typography.svg` — no mark geometry
- `examples/component-states.svg` — no mark geometry
- `examples/code-block.svg` — no mark geometry
- `examples/terminal.svg` — no mark geometry
- `examples/docs-page.svg` — no mark geometry
- `examples/architecture-diagram.svg` — no mark geometry

### D4 Mark Geometry for Inline SVG Specimens

From `brandbook/logo-mark.svg` [VERIFIED: filesystem]:

```svg
<!-- viewBox="-70 -60 1040 1040" -->
<!-- Ink group: vertical stem + leftward foot -->
<rect x="540" y="360" width="180" height="580" />  <!-- stem -->
<rect x="180" y="760" width="540" height="180" />  <!-- foot -->
<!-- Ember rail block (above the i tittle) -->
<rect x="400" y="-20" width="320" height="320" />
```

Colors: `fill: #151515` on ink group, `fill: #c2410c` on rail block (light); `fill: #f4f1eb` + `fill: #fdba74` (dark via `prefers-color-scheme`).

For the SVG specimens (which are static, not dark-mode-aware), use light-surface values: ink `#151515`, ember block `#c2410c`.

The mark occupies approximately `x:180-720, y:-20-940` in its own coordinate space (viewBox `"-70 -60 1040 1040"`). When embedding inline at a small scale (~54px rendered height), apply a `transform="scale(0.06) translate(-180 -20)"` or similar to fit it into the specimen's header area. The planner should target roughly the same spatial footprint as the existing staggered-bars group in each specimen.

---

## Standard Stack

No new packages needed. Phase 182 uses existing tooling only.

| Tool | Version | Available | Purpose |
|------|---------|-----------|---------|
| `playwright-core` | 1.59.1 | YES — `test/example/priv/playwright/node_modules` | Headless Chromium for axe harness |
| `@axe-core/playwright` | 4.11.2 | YES — `test/example/priv/playwright/node_modules` | AxeBuilder API |
| `python3` | 3.14.4 | YES — system | Static file server for axe harness |
| `xmllint` | system | YES | SVG/HTML parse validation |
| `jq` | system | Assumed | tokens.json validation |

[VERIFIED: playwright-core v1.59.1, @axe-core/playwright v4.11.2 confirmed by package.json inspection. python3 3.14.4 confirmed by shell. node v22.14.0 confirmed by shell.]

---

## Package Legitimacy Audit

No new packages are installed in this phase. All tooling is pre-existing.

| Package | Registry | Already Installed | Disposition |
|---------|----------|-------------------|-------------|
| `@axe-core/playwright` | npm | Yes (v4.11.2) | Approved — already installed and in use |
| `playwright-core` | npm | Yes (v1.59.1) | Approved — already installed and in use |

**No new npm installs. No slopcheck required.**

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead |
|---------|-------------|-------------|
| Accessibility checking | Custom contrast checker | `AxeBuilder` from `@axe-core/playwright` |
| Static file serving for axe | Custom HTTP server | `python3 -m http.server` |
| Token value verification | Manual reading | `jq` against tokens.json |
| SVG parse checking | Manual | `xmllint --noout` |

---

## Common Pitfalls

### Pitfall 1: `file://` CORS on axe injection
**What goes wrong:** `@axe-core/playwright` injects the axe script via `page.evaluate()`. On some Chromium configurations, injecting from a non-origin context on `file://` can fail silently or produce incomplete results.
**Why it happens:** Browsers treat `file://` origins as opaque; script injection may be blocked.
**How to avoid:** Use `python3 -m http.server` to serve `brandbook/` over localhost. Already accounted for in the harness recipe.
**Warning signs:** `analyze()` returns empty violations array but also zero nodes analyzed (check `results.passes.length` too).

### Pitfall 2: New `<img>` tags in logo-system section missing alt text
**What goes wrong:** Adding new logo images (subtitle variant, monochrome, social cards) to the expanded `#logo` section without alt text triggers `image-alt` rule, failing the axe gate.
**Why it happens:** Easy to forget when adding many images in a batch.
**How to avoid:** Every `<img>` in the new logo-system grid must have a descriptive `alt` attribute (not empty, since these images communicate meaning — they're logo specimens, not decorative).
**Warning signs:** `axe: FAIL — 1 violation(s): [critical] image-alt`.

### Pitfall 3: Adding external dependency to index.html
**What goes wrong:** Accidentally linking a Google Font, CDN CSS, or `<script>` tag breaks the standalone disk-open requirement.
**Why it happens:** Templating from external sources or copy-paste from marketing pages.
**How to avoid:** The dependency-free check in Validation Architecture grep catches this immediately.

### Pitfall 4: Updating tokens.css values without matching tokens.json or vice versa
**What goes wrong:** The two files diverge; downstream consumers reference one but not the other.
**Why it happens:** Editing one file and forgetting the other.
**How to avoid:** The provenance header comment in tokens.css explicitly states the version — if the version in the header doesn't match `tokens.json version`, something is out of sync. The `jq` check in validation catches it.

### Pitfall 5: Wrong version bump type
**What goes wrong:** Bumping to 2.0.0 for a metadata-only change, or keeping at 1.0.0 when the `changed` date is new.
**Why it happens:** Unclear policy.
**How to avoid:** Policy is now documented: metadata-only = patch. Phase 182 has no value changes, so 1.0.0 → 1.0.1.

---

## Validation Architecture

**nyquist_validation is enabled** (config.json: `workflow.nyquist_validation: true`).

### Test Framework

| Property | Value |
|----------|-------|
| Framework | None (brand asset phase) — scripted shell checks + axe harness |
| Config file | n/a |
| Quick run command | `find brandbook -maxdepth 1 -name '*.svg' \| xargs -n1 xmllint --noout` |
| Full suite command | Machine-verifiable check suite below |
| Estimated runtime | ~30 seconds (including axe harness ~10s) |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| BRAND2-09 | index.html zero axe violations | axe harness | `node scripts/brand/axe-brandbook.mjs` exits 0 | ❌ Wave 0 |
| BRAND2-09 | index.html has no external dependencies | grep | `grep -c 'http\|cdn\|@import\|<script src' brandbook/index.html` (expected 0) | ✅ |
| BRAND2-09 | index.html links only tokens.css | grep | `grep -c '<link' brandbook/index.html` (expected 1); `grep -c 'tokens.css' brandbook/index.html` (expected 1) | ✅ |
| BRAND2-09 | All brandbook HTML/SVG parse valid | xmllint | `xmllint --noout brandbook/index.html; find brandbook -maxdepth 1 -name '*.svg' \| xargs -n1 xmllint --noout` | ✅ |
| BRAND2-09 | landing-hero.svg updated (v1 mark removed) | grep | `grep -c 'M17 14v14' brandbook/examples/landing-hero.svg` (expected 0) | ✅ |
| BRAND2-09 | readme-header.svg updated (v1 mark removed) | grep | `grep -c 'M17 14v14' brandbook/examples/readme-header.svg` (expected 0) | ✅ |
| BRAND2-10 | tokens.json version bumped to 1.0.1 | jq | `jq -r '.version' brandbook/tokens.json` (expected 1.0.1) | ✅ |
| BRAND2-10 | tokens.json has changed date in meta | jq | `jq -r '.meta.changed' brandbook/tokens.json` (expected ISO date, not null) | ✅ |
| BRAND2-10 | tokens.css has provenance header | grep | `head -3 brandbook/tokens.css \| grep -c 'tokens.json'` (expected 1) | ✅ |
| BRAND2-10 | README.md has Token Change Policy section | grep | `grep -c 'Token Change Policy' brandbook/README.md` (expected 1) | ✅ |
| BRAND2-10 | README.md Files table updated (no "Rail Accent" entries) | grep | `grep -c 'Rail Accent' brandbook/README.md` (expected 0 in Files table — verify by context) | ✅ |
| BRAND2-10 | No font binaries committed | git | `git ls-files -- '*.ttf' '*.otf' '*.woff' '*.woff2' \| wc -l` (expected 0) | ✅ |

### Sampling Rate

- **Per task commit:** `find brandbook -maxdepth 1 -name '*.svg' | xargs -n1 xmllint --noout && xmllint --noout brandbook/index.html`
- **Per wave:** Full check suite below
- **Phase gate:** All checks green + `node scripts/brand/axe-brandbook.mjs` exits 0 before `/gsd:verify-work`

### Wave 0 Gaps

- [ ] `scripts/brand/axe-brandbook.mjs` — axe harness script (Wave 0: must exist before axe task runs)

No other Wave 0 gaps: all other files exist and are being edited in-place.

### Full Phase Check Suite

```bash
# 1. axe: zero violations on index.html
node scripts/brand/axe-brandbook.mjs

# 2. No external dependencies in index.html (expected: 0)
grep -cE 'http[s]?://|cdn\.|@import|<script[[:space:]]+src' brandbook/index.html

# 3. Only one <link> tag and it's tokens.css (expected: 1, 1)
grep -c '<link' brandbook/index.html
grep -c 'tokens.css' brandbook/index.html

# 4. All brandbook SVGs and index.html parse as valid XML/HTML
xmllint --noout brandbook/index.html
find brandbook -maxdepth 1 -name '*.svg' | xargs -n1 xmllint --noout

# 5. Stale v1 mark paths removed from specimens (expected: 0, 0)
grep -c 'M17 14v14' brandbook/examples/landing-hero.svg
grep -c 'M17 14v14' brandbook/examples/readme-header.svg

# 6. tokens.json version bumped to 1.0.1
jq -r '.version' brandbook/tokens.json

# 7. tokens.json meta.changed is set
jq -r '.meta.changed' brandbook/tokens.json

# 8. tokens.css provenance header present
head -3 brandbook/tokens.css | grep 'tokens.json'

# 9. README.md Token Change Policy section added
grep -c 'Token Change Policy' brandbook/README.md

# 10. README Files table no longer has "Rail Accent" for main logo files
# (Note: "Rail Accent" may still appear in archive/ path descriptions — check the Files table rows only)
grep -A 20 '| File' brandbook/README.md | grep 'Rail Accent'

# 11. No font binaries committed (expected: 0)
git ls-files -- '*.ttf' '*.otf' '*.woff' '*.woff2' | wc -l

# 12. No SVG in brandbook root exceeds 250KB (expected: empty output)
find brandbook -maxdepth 1 -name '*.svg' -size +250k -print

# 13. brandbook/ size delta reasonable (expected: < 50KB net increase)
du -sh brandbook/
```

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| `playwright-core` + Chromium | axe harness | YES | 1.59.1 / chromium-1223 | — |
| `@axe-core/playwright` | axe harness | YES | 4.11.2 | — |
| `python3` | Static file server for axe | YES | 3.14.4 | `npx serve` (not preferred) |
| `node` | Script execution | YES | v22.14.0 | — |
| `xmllint` | SVG/HTML parse check | Assumed (macOS) | system | `python3 -c "import xml.etree.ElementTree as ET; ET.parse('file.svg')"` |
| `jq` | tokens.json checks | Assumed (macOS) | system | `python3 -c "import json; ..."` |

**Missing dependencies with no fallback:** None.

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `file://` protocol may cause CORS issues with axe script injection | Section 1 | If wrong, the harness can use `file://` and skip the python server startup, reducing ~600ms overhead |
| A2 | Patch bump `1.0.0 → 1.0.1` is appropriate for metadata-only token change | Section 3 | If the project prefers minor bumps for any change, use `1.1.0` instead — the policy text in README must match |
| A3 | Port 7743 is free on the development machine | Section 1 | If in use, the axe harness fails to bind; fix: probe for a free port at runtime |
| A4 | vaultr-mark.svg should be referenced by description, not copied into brandbook/ | Section 5 | If the suite section needs a live visual example, copy to `brandbook/examples/vaultr-mark.svg` — minor scope expansion |
| A5 | The token change policy prose shape proposed is acceptable | Section 3 | Claude's discretion per CONTEXT — adjust wording in planner |

**If this table is empty:** N/A — 5 assumptions, all low-risk, all flagged.

---

## Open Questions (RESOLVED)

All resolved autonomously per instructions.

1. **Does @axe-core/playwright require @playwright/test or does playwright-core suffice?**
   RESOLVED: `playwright-core` suffices. Peer dep is `"playwright-core": ">= 1.0.0"`. The `AxeBuilder` constructor takes a plain `Page` object; `playwright-core`'s `chromium.launch()` provides it. [VERIFIED: package.json peerDependencies]

2. **Does file:// work with axe or is a localhost server required?**
   RESOLVED: Use localhost server (python3 -m http.server) to eliminate any CORS/injection ambiguity. The marginal cost is ~600ms script startup. critique-render.mjs already uses file:// for screenshots, but axe script injection is a different operation. [ASSUMED: CORS risk is low but localhost is strictly safer — zero downside]

3. **What WCAG tags/ruleset to assert?**
   RESOLVED: `.withTags(['wcag2a', 'wcag2aa'])` — same scope as `admin-checkpoints.spec.ts`. This excludes `best-practice` rules (which would flag the unnamed scorecard section) and is the correct posture for a WCAG compliance gate. [VERIFIED: admin-checkpoints.spec.ts line 120-122]

4. **Should the axe script be committed or throwaway?**
   RESOLVED: Committed as `scripts/brand/axe-brandbook.mjs`. It will be needed in Phase 183 to re-verify after propagation, and it's consistent with the committed brand toolchain (`critique-render.mjs`, `outline-wordmark.mjs`). [CONTEXT says "committed preferred"]

5. **What version bump for tokens.json?**
   RESOLVED: `1.0.0 → 1.0.1` (patch). No token values change; only metadata (`changed` date) is added. Patch is the correct semver level for metadata-only changes. [ASSUMED per DTCG/semver conventions]

6. **Which specimens are stale?**
   RESOLVED: `landing-hero.svg` AND `readme-header.svg` — both confirmed stale by grep of v1 path data `M17 14v14`. The other 7 specimens are clean. [VERIFIED: grep of all examples/]

---

## Sources

### Primary (HIGH confidence — direct filesystem inspection)
- `brandbook/index.html` — current markup, ARIA attributes, alt text, heading order, inline styles
- `brandbook/tokens.json` — version field (1.0.0), meta structure, all token values
- `brandbook/tokens.css` — all CSS custom property values (spot-checked 14 pairs against tokens.json)
- `brandbook/examples/landing-hero.svg` — v1 stale mark paths confirmed
- `brandbook/examples/readme-header.svg` — v1 stale mark paths confirmed
- `brandbook/logo-mark.svg` — D4 geometry for porting to specimens
- `test/example/priv/playwright/node_modules/@axe-core/playwright/package.json` — version 4.11.2, peerDeps
- `test/example/priv/playwright/node_modules/playwright-core/package.json` — version 1.59.1
- `test/example/priv/playwright/tests/admin-checkpoints.spec.ts` — `assertNoAxeViolations` pattern with `withTags(['wcag2a','wcag2aa'])`
- `scripts/brand/critique-render.mjs` — `createRequire` pattern for loading playwright-core
- `scripts/brand/package.json` — scripts/brand dependency structure
- `brandbook/pressure-test-audit-v2.md` — Section 6 upgrades list, Section 8 suite architecture
- `.planning/phases/181-ratified-logo-system-buildout/181-VALIDATION.md` — VALIDATION.md format reference
- `test/example/priv/static/images/vaultr-mark.svg` — per-library color diversity evidence
- Color contrast calculations: all computed programmatically from hex values in this session

### Secondary (MEDIUM confidence)
- `.planning/STATE.md` — Phase 181 carry-forwards, ember parity confirmation
- `.planning/phases/182-brand-book-v2-tokens/182-CONTEXT.md` — locked decisions
- `brandbook/README.md` — current Files table state, maintenance rules

### Tertiary (LOW / ASSUMED)
- DTCG semver conventions for token versioning — [ASSUMED] based on industry conventions (Tailwind/Radix/Carbon), not a live DTCG spec verification in this session

---

## Metadata

**Confidence breakdown:**
- axe harness recipe: HIGH — all key facts verified from filesystem + runtime
- Probable axe violations: HIGH — color contrasts computed from actual hex values; structural issues verified by parsing HTML
- Token change policy: MEDIUM/ASSUMED — conventions are standard but not verified against a live DTCG document
- Stale specimens: HIGH — grep of actual path data
- Suite architecture skeleton: HIGH — sourced from the committed audit document

**Research date:** 2026-06-12
**Valid until:** 2026-07-12 (stable domain; main risk is if @axe-core/playwright or playwright-core versions change)
