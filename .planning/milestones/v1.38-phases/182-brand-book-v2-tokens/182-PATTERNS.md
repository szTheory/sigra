# Phase 182: Brand Book v2 + Tokens — Pattern Map

**Mapped:** 2026-06-12
**Files analyzed:** 8 new/modified files
**Analogs found:** 7 / 8 (1 partial — `brand-book.md` has no close structural analog outside itself)

---

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `brandbook/index.html` | static document | request-response (disk-open) | `brandbook/index.html` (current v1) | self — extend in-place |
| `brandbook/brand-book.md` | documentation | none | `brandbook/brand-book.md` (current) | self — extend in-place |
| `brandbook/README.md` | documentation | none | `brandbook/README.md` (current) | self — extend in-place |
| `brandbook/tokens.json` | config/data | none | `brandbook/tokens.json` (current) | self — patch bump |
| `brandbook/tokens.css` | config/stylesheet | none | `brandbook/tokens.css` (current) | self — header addition only |
| `brandbook/examples/landing-hero.svg` | static asset/specimen | none | `brandbook/logo-mark.svg` | partial — extract D4 geometry |
| `brandbook/examples/readme-header.svg` | static asset/specimen | none | `brandbook/logo-mark.svg` | partial — same fix as landing-hero |
| `scripts/brand/axe-brandbook.mjs` | utility/script | request-response | `scripts/brand/critique-render.mjs` | role-match |

---

## Pattern Assignments

### `brandbook/index.html` (static document — extend in-place)

**Analog:** `brandbook/index.html` lines 322–543 (current structure)

**Existing nav pattern** (lines 330–339) — new nav links must be added here:
```html
<nav class="nav" aria-label="Brand book sections" tabindex="0">
  <a href="#judgment">Judgment</a>
  <a href="#dna">DNA</a>
  <a href="#tokens">Tokens</a>
  <a href="#logo">Logo</a>
  <a href="#examples">Examples</a>
  <a href="#voice">Voice</a>
  <a href="#blueprint">Blueprint</a>
  <a href="#artifacts">Artifacts</a>
</nav>
```

**Divergence for v2:** Add `<a href="#suite">Suite</a>` and `<a href="#scorecard">Scorecard</a>` (for the unnamed section that needs an `id`). New sections must come before `#artifacts`.

**Existing section pattern** (lines 428–457, `#logo` section) — extend this section, do not rewrite:
```html
<section id="logo">
  <p class="eyebrow">Logo system</p>
  <h2>Rail Accent tight lockup plus durable small marks.</h2>
  <p class="lead">...</p>
  <div class="logo-strip">
    <div class="logo-box light lockup"><img src="logo-primary.svg" alt="Sigra primary logo for light surfaces"></div>
    <div class="logo-box dark lockup"><img src="logo-primary-dark.svg" alt="Sigra primary logo for dark surfaces"></div>
    <div class="logo-box mark"><img src="logo-mark.svg" alt="Sigra Rail Accent mark"></div>
    <div class="logo-box favicon"><img src="favicon.svg" alt="Sigra favicon mark"></div>
  </div>
  <div class="rules" style="margin-top:var(--sigra-space-4)">
    <article class="panel">
      <h3>Use</h3>
      <ul class="rule-list">...</ul>
    </article>
    <article class="panel">
      <h3>Avoid</h3>
      <ul class="rule-list">...</ul>
    </article>
  </div>
</section>
```

**CSS classes available for new logo-system expansion** (lines 203–228):
```css
.logo-strip { display: grid; grid-template-columns: repeat(auto-fit, minmax(12rem, 1fr)); ... }
.logo-box   { display: grid; min-height: 10rem; place-items: center; ... }
.logo-box.light  { background: #f6f5f2; color: #151515; }
.logo-box.dark   { background: #171614; color: #f4f1eb; }
.logo-box img    { max-height: 84px; }
.logo-box.lockup img  { width: min(270px, 100%); }
.logo-box.mark img    { width: 84px; height: 84px; }
.logo-box.favicon img { width: 64px; height: 64px; }
```

**New assets to surface** — these SVGs exist in `brandbook/` and are NOT yet shown in `#logo`:
- `logo-primary-subtitle.svg` — use `class="logo-box light lockup"` with `alt="Sigra primary logo with subtitle, light surface"`
- `social-card.svg` — use `class="logo-box light"` with `alt="Sigra social card preview"`
- `social-card-dark.svg` — use `class="logo-box dark"` with `alt="Sigra social card preview, dark surface"`
- `logo-monochrome.svg` — already referenced in prose but not shown in the strip; add `class="logo-box light mark"` with `alt="Sigra monochrome mark"`

**Unnamed scorecard section fix** (lines 403–413) — add `id="scorecard"`:
```html
<!-- BEFORE -->
<section>
  <p class="eyebrow">Scorecard</p>

<!-- AFTER -->
<section id="scorecard">
  <p class="eyebrow">Scorecard</p>
```

**New suite section pattern** — follow the `#blueprint` table section pattern (lines 503–518) for the table, and the `#judgment` grid-of-panels pattern (lines 364–382) for the onboarding rules:
```html
<section id="suite">
  <p class="eyebrow">Suite architecture</p>
  <h2>Seven libraries, one coherent system.</h2>
  <!-- table-wrap panel for the lib table -->
  <div class="table-wrap panel">
    <table>
      <thead><tr><th>Library</th><th>Domain metaphor</th><th>Accent hue</th></tr></thead>
      <tbody>...</tbody>
    </table>
  </div>
  <!-- grid for the 3 onboarding rules -->
  <div class="grid" style="margin-top:var(--sigra-space-4)">
    <article class="panel"><h3>Rule 1</h3>...</article>
    ...
  </div>
</section>
```

**WCAG / axe constraint:** Every new `<img>` in the expanded `#logo` section MUST have a non-empty descriptive `alt` attribute. The existing pattern always provides full alt text (see analog lines 433–436). Decorative-only images use `alt=""` — logo specimens are NOT decorative.

**Dependency-free constraint:** No new `<link>`, `<script src>`, `@import`, or `http` URLs. The single `<link rel="stylesheet" href="tokens.css">` on line 7 is the only external reference. All new content uses the same embedded `<style>` block and `--sigra-*` CSS variables.

---

### `brandbook/brand-book.md` (documentation — extend in-place)

**Analog:** `brandbook/brand-book.md` lines 77–106 (Logo System section)

**Stale font reference** (line 96) — replace:
```markdown
<!-- BEFORE (line 96) -->
The lockup wordmark is outlined from Inter Display Black v4.1.

<!-- AFTER -->
The lockup wordmark is outlined from Space Grotesk v2.0 (OFL) wght=700, using opentype.js 2.0.0.
```

**Logo System section divergence for v2:** The file listing at lines 82–88 must add `logo-primary-subtitle.svg` and `social-card-dark.svg`. Update the file list to match the actual assets (same format as existing list):
```markdown
- Primary light lockup: `logo-primary.svg`
- Primary dark lockup: `logo-primary-dark.svg`
- Subtitle variant lockup: `logo-primary-subtitle.svg`
- Free-standing mark: `logo-mark.svg`
- Monochrome mark: `logo-monochrome.svg`
- Favicon source: `favicon.svg`
- Social card (light): `social-card.svg`
- Social card (dark): `social-card-dark.svg`
```

**ADD sections per audit BRAND2-09 directive:**
- Integrated-typemark anatomy (rail-block tittle + g-tail extension). Follow the existing "Concept:" prose pattern (line 90).
- Three-surface ember parity rule (document that `ember-700: #c2410c` is shared across brandbook tokens, admin `--sg-color-brand`, and auth `--sigra-auth-light-accent`).
- Suite architecture section (shared vs per-library decision framework, same factual skeleton from RESEARCH.md Section 5).

---

### `brandbook/README.md` (documentation — extend in-place)

**Analog:** `brandbook/README.md` lines 9–24 (Files table)

**Files table pattern** (lines 11–24) — every row follows this format:
```markdown
| [`filename`](filename) | Purpose prose. |
```

**Table rows to fix** — five entries still say "Rail Accent" in the Purpose column (lines 16–20). Replace with D4 Linked Rail language matching the Logo System section prose. Add two missing rows:
```markdown
| [`logo-primary-subtitle.svg`](logo-primary-subtitle.svg) | D4 Linked Rail lockup with subtitle line for tall-format contexts. |
| [`social-card-dark.svg`](social-card-dark.svg)           | SVG social preview source for dark-background platforms.           |
```

**New Token Change Policy section** — add after the Maintenance Rules section (after line 86). Pattern follows the existing `## Maintenance Rules` heading + bullet-list style:
```markdown
## Token Change Policy

`tokens.json` follows semantic versioning on the `version` field:

- **Patch** (`1.0.x`): metadata-only changes — `changed` date, `source` annotation updates.
  No consuming surface requires changes.
- **Minor** (`1.x.0`): new tokens added. Consuming surfaces (`--sg-*` in admin CSS,
  `--sigra-auth-*` in `sigra_auth.css`) may reference the new token but are not required to.
- **Major** (`x.0.0`): token value changed or token removed. Consuming surfaces **must**
  review the diff and update hardcoded fallbacks before shipping.

**Three-surface ember parity rule:** `ember-700: #c2410c` is the canonical accent value
consumed by three independent surfaces — `brandbook/tokens.json`, admin CSS
(`--sg-color-brand`), and auth CSS (`--sigra-auth-light-accent`). Any new surface carrying
the Sigra brand accent must reference the brandbook token rather than hardcoding `#c2410c`.
When the token value changes (major bump), all three surfaces must be updated atomically
in the same PR.

The `meta.changed` date uses ISO 8601 (`YYYY-MM-DD`). It records the last date any token
value or file structure changed — metadata-only patches do not update it.
```

---

### `brandbook/tokens.json` (config/data — patch bump only)

**Analog:** `brandbook/tokens.json` lines 1–9 (current meta block)

**Current state** (lines 1–9):
```json
{
  "$schema": "https://design-tokens.github.io/community-group/format/",
  "name": "Sigra brand tokens",
  "version": "1.0.0",
  "meta": {
    "source": "Derived from Sigra repository voice, launch docs, security posture, and v1.34 admin UI tokens.",
    "policy": "Durable, source-controlled tokens for brandbook, docs, landing pages, and marketing collateral. These tokens do not change generated application UI by themselves.",
    "license": "MIT repository asset; no embedded fonts or proprietary binary assets."
  },
```

**Required change** — increment `version` and add `changed` to `meta`:
```json
{
  "$schema": "https://design-tokens.github.io/community-group/format/",
  "name": "Sigra brand tokens",
  "version": "1.0.1",
  "meta": {
    "source": "Derived from Sigra repository voice, launch docs, security posture, and v1.34 admin UI tokens.",
    "policy": "Durable, source-controlled tokens for brandbook, docs, landing pages, and marketing collateral. These tokens do not change generated application UI by themselves.",
    "license": "MIT repository asset; no embedded fonts or proprietary binary assets.",
    "changed": "2026-06-12"
  },
```

Token VALUES are unchanged. Only `version` and `meta.changed` are added/bumped.

---

### `brandbook/tokens.css` (config/stylesheet — header addition only)

**Analog:** `brandbook/tokens.css` line 1 (current first line is `:root {`)

**Current state** (line 1):
```css
:root {
  color-scheme: light dark;
  ...
```

**Required change** — prepend provenance header before `:root {`:
```css
/* Sigra brand tokens — CSS custom properties
 * Derived from brandbook/tokens.json v1.0.1
 * Hand-maintained sync. When tokens.json version changes, update this file
 * and increment the version reference above.
 * Do not add web fonts, external imports, or CDN links.
 */
:root {
  color-scheme: light dark;
  ...
```

All CSS custom property VALUES are unchanged. No token values need to be edited.

---

### `brandbook/examples/landing-hero.svg` (static specimen — stale mark replacement)

**Analog:** `brandbook/logo-mark.svg` (full file, 10 lines) — D4 geometry source

**Stale v1 mark group to REMOVE** (landing-hero.svg lines 14–18):
```svg
<g transform="translate(98 96)">
  <path d="M17 14v14M32 23v18M47 36v14" fill="none" stroke="#fdba74" stroke-width="8" stroke-linecap="round"/>
  <path d="M17 36v14M47 14v14" fill="none" stroke="#c2410c" stroke-width="8" stroke-linecap="round"/>
  <path d="M17 32h30" fill="none" stroke="#9a3412" stroke-width="4" stroke-linecap="round"/>
</g>
```

**D4 geometry from `brandbook/logo-mark.svg`** — the authoritative source coordinates (viewBox `"-70 -60 1040 1040"`):
```svg
<!-- From logo-mark.svg -->
<g id="glyphs">
  <rect x="540" y="360" width="180" height="580" />  <!-- vertical stem -->
  <rect x="180" y="760" width="540" height="180" />  <!-- leftward foot -->
</g>
<rect id="rail-block" x="400" y="-20" width="320" height="320" />
```

**Replacement group for landing-hero.svg** — the mark occupies `x:180–720, y:-20–940` in its own coordinate space. The existing v1 group at `translate(98 96)` produced a ~54×54px visual footprint. To match that footprint using D4 geometry (with inline light-surface colors, no CSS variables — specimens are static):

```svg
<!-- D4 mark at roughly 54px rendered height, light surface -->
<!-- Scale factor: target ~54px height from 940px logical height → ~0.057 -->
<!-- translate(-70 -60) aligns to logical origin, then offset to match v1 position -->
<g transform="translate(98 96) scale(0.057) translate(70 60)">
  <g fill="#151515">
    <rect x="540" y="360" width="180" height="580"/>
    <rect x="180" y="760" width="540" height="180"/>
  </g>
  <rect fill="#c2410c" x="400" y="-20" width="320" height="320"/>
</g>
```

**Colors:** Use light-surface values only — `fill="#151515"` for ink group, `fill="#c2410c"` for rail block. No dark-mode CSS in static SVG specimens.

**Validation:** After replacement, `grep -c 'M17 14v14' brandbook/examples/landing-hero.svg` must return `0`.

---

### `brandbook/examples/readme-header.svg` (static specimen — same fix)

**Analog:** Same as landing-hero.svg above (identical v1 path geometry).

**Stale v1 mark group to REMOVE** (readme-header.svg lines 6–10):
```svg
<g transform="translate(88 88) scale(0.9)">
  <path d="M17 14v14M32 23v18M47 36v14" fill="none" stroke="#fdba74" stroke-width="8" stroke-linecap="round"/>
  <path d="M17 36v14M47 14v14" fill="none" stroke="#c2410c" stroke-width="8" stroke-linecap="round"/>
  <path d="M17 32h30" fill="none" stroke="#9a3412" stroke-width="4" stroke-linecap="round"/>
</g>
```

**Replacement** — same D4 geometry as landing-hero.svg, but apply to the `translate(88 88) scale(0.9)` container position. The `scale(0.9)` wrapper produces a slightly smaller mark (~48px). Preserve the spatial relationship with the "Sigra" text at `x="154" y="132"`:

```svg
<!-- D4 mark at ~48px rendered height, light surface -->
<g transform="translate(88 88) scale(0.9) scale(0.057) translate(70 60)">
  <g fill="#151515">
    <rect x="540" y="360" width="180" height="580"/>
    <rect x="180" y="760" width="540" height="180"/>
  </g>
  <rect fill="#c2410c" x="400" y="-20" width="320" height="320"/>
</g>
```

**Validation:** `grep -c 'M17 14v14' brandbook/examples/readme-header.svg` must return `0`.

---

### `scripts/brand/axe-brandbook.mjs` (NEW utility script)

**Analog:** `scripts/brand/critique-render.mjs` (full file, 75 lines)

**`createRequire` pattern** (critique-render.mjs lines 12–24) — copy this pattern exactly, changing only the target modules loaded:
```javascript
import { createRequire } from 'module';

// Reuse playwright-core from the existing test/example install — avoids a duplicate install.
const playwrightBase = new URL(
  '../../test/example/priv/playwright/',
  import.meta.url
).pathname;
const require = createRequire(playwrightBase + 'package.json');
const { chromium } = require('playwright-core');
```

**Divergence from critique-render.mjs:** Also load `@axe-core/playwright` via the same `require`:
```javascript
const { default: AxeBuilder } = require('@axe-core/playwright');
```

**AxeBuilder + assertNoAxeViolations pattern** (admin-checkpoints.spec.ts lines 115–126) — adapt from TypeScript to ESM JavaScript:
```javascript
// admin-checkpoints.spec.ts pattern (TypeScript):
const { violations } = await new AxeBuilder({ page })
  .withTags(['wcag2a', 'wcag2aa'])
  .analyze();

// axe-brandbook.mjs equivalent:
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
```

**Divergence from critique-render.mjs:** Uses a localhost `python3 -m http.server` subprocess (not `file://`) for reliable axe script injection. The full skeleton is provided verbatim in RESEARCH.md Section 1 — use it directly; no deviation needed.

**scripts/brand/package.json** does NOT need updating — no new npm dependencies. `@axe-core/playwright` and `playwright-core` are loaded via `createRequire` from `test/example/priv/playwright/node_modules/`, not from `scripts/brand/node_modules/`.

**Shebang and module type:** Follow the critique-render.mjs pattern:
```javascript
#!/usr/bin/env node
// ... doc comment
import { createRequire } from 'module';
import { spawn } from 'child_process';
import { resolve, dirname } from 'path';
import { fileURLToPath } from 'url';
```

`scripts/brand/package.json` has `"type": "module"` — top-level `await` is valid.

---

## Shared Patterns

### Dependency-Free HTML Constraint
**Source:** `brandbook/index.html` line 7 (the single `<link>` tag)
**Apply to:** All additions to `brandbook/index.html`
```html
<link rel="stylesheet" href="tokens.css">
```
This is the ONLY external reference in the document. No new `<link>`, `<script src>`, `@import`, CDN, or web font may be added. New CSS goes inside the embedded `<style>` block (lines 8–319).

### CSS Token Variable Usage
**Source:** `brandbook/tokens.css` lines 1–30 (`:root` block)
**Apply to:** All new CSS in `brandbook/index.html`'s embedded `<style>` block
```css
/* All color, spacing, radius, font, and shadow values come from --sigra-* variables */
background: var(--sigra-surface);
color: var(--sigra-text);
border-radius: var(--sigra-radius-md);
padding: var(--sigra-space-5);
```
Do not hardcode hex values in `<style>` except where a specific non-token color is architecturally required (e.g., the `.logo-box.light/.dark` background overrides that must be absolute values for logo specimen fidelity).

### Section Structure Pattern
**Source:** `brandbook/index.html` lines 364–457 (any existing section)
**Apply to:** New `#suite` section and expanded `#logo` content
```html
<section id="<id>">
  <p class="eyebrow"><Short label></p>
  <h2><Section heading></h2>
  <p class="lead"><Optional intro></p>
  <!-- content using .grid, .panel, .table-wrap, .rules, .logo-strip etc. -->
</section>
```

### D4 Mark Geometry (Canonical Source)
**Source:** `brandbook/logo-mark.svg` lines 5–9
**Apply to:** `brandbook/examples/landing-hero.svg` and `brandbook/examples/readme-header.svg`
```svg
<!-- Ink group: vertical stem + leftward foot; fill: #151515 on light surface -->
<rect x="540" y="360" width="180" height="580" />
<rect x="180" y="760" width="540" height="180" />
<!-- Rail block; fill: #c2410c on light surface -->
<rect x="400" y="-20" width="320" height="320" />
```
The logical coordinate system is viewBox `"-70 -60 1040 1040"`. Scale to ~0.057 to achieve ~54px rendered height. Use `translate(70 60)` to align to the logical origin before scaling.

### createRequire from playwright Base
**Source:** `scripts/brand/critique-render.mjs` lines 19–24
**Apply to:** `scripts/brand/axe-brandbook.mjs`
```javascript
const playwrightBase = new URL(
  '../../test/example/priv/playwright/',
  import.meta.url
).pathname;
const require = createRequire(playwrightBase + 'package.json');
const { chromium } = require('playwright-core');
```

---

## No Analog Found

| File | Role | Reason |
|------|------|--------|
| (none) | — | All files have at least a partial analog or are self-analogs (edit in-place). |

**Note:** `brand-book.md` and `README.md` are self-analogs — the planner edits them in-place following their own existing heading and list conventions. No external structural analog exists in the codebase.

---

## Metadata

**Analog search scope:** `brandbook/`, `scripts/brand/`, `test/example/priv/playwright/tests/`
**Files scanned:** 10 (index.html, brand-book.md, README.md, tokens.json, tokens.css, logo-mark.svg, examples/landing-hero.svg, examples/readme-header.svg, scripts/brand/critique-render.mjs, test/example/priv/playwright/tests/admin-checkpoints.spec.ts)
**Pattern extraction date:** 2026-06-12
