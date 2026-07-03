# Phase 216: Harness Foundation + Award Gradient - Research

**Researched:** 2026-07-03
**Domain:** Deterministic visual-quality evaluation harness (Playwright/TS render+probe substrate) + forward-only quality-ledger guards (bash/node), grafted onto Sigra's existing admin design-system CI
**Confidence:** HIGH (implementation surfaces grounded in actual repo files + external API facts verified this session)

## Summary

Phase 216 builds the deterministic substrate for an award-grade admin-UI ratchet: one bash entrypoint drives one new Playwright project (`admin-eval`) that renders the existing `/admin/_design` gallery (and the two pilot pages) into gitignored evidence bundles, computes a canonical `render_sha256` per (surface×cell), runs nine in-browser visual probes over live computed style/geometry, and commits only the small derived signal (SHA ledger + findings counts + award ledger). Four new deterministic guards (stale-render, evidence-anchor, findings-count-monotonic, award verify-then-climb) attach to the `fast_checks` lane beside `quality-ledger-monotonic.sh`, cloning its exact idiom. A one-line `ci.yml` base-ref fix (merge-base, not base-tip) corrects the down-ratchet math for the new guard and the two existing ones.

The 25 CONTEXT.md decisions already fix the architecture. This research pins the **implementation-level API surface** so the executor never guesses syntax: the DOM canonicalization pipeline (recommend parse5-based normalization primary, ARIA-snapshot as a lighter alternative), the exact `page.evaluate`/`getComputedStyle` patterns for reading `--sg-*` tokens and box longhands, the `@axe-core/playwright` `target-size` enablement (a disabled-by-default rule confirmed this session), the cheerio-over-outerHTML anchor check, and the concrete JSON schema for `admin-award-ledger.json` + `settled-findings.tsv` grounded against the frozen ledger grammar.

**Primary recommendation:** Clone `quality-ledger-monotonic.sh` + its `.test.sh` verbatim for every new bash guard; render via a single `admin-eval` Playwright project that inherits (never forks) `playwright.config.ts`; canonicalize DOM with **parse5 + a hand-rolled allowlist walker** (not raw outerHTML, not a denylist); read every token/box fact through `page.evaluate(() => getComputedStyle(...).getPropertyValue(...))` (never `toHaveCSS` for custom props); store the award vector as JSON with `band = min(axes)` derived and guarded; key `finding_id = sha256(surface \0 class \0 anchor)` identically to Phase 217.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Render admin surfaces → bundle | Browser (Playwright/TS) | — | Only a real browser has layout, `getComputedStyle`, axe; BEAM has none (D-02) |
| DOM canonicalization → `render_sha256` | Node/TS (post-capture) | — | parse5/cheerio run in Node beside the spec; harness is not BEAM (D-06) |
| In-browser visual probes | Browser (`page.evaluate`) | — | Geometry/computed-style only measurable live at capture (D-11) |
| Evidence-anchor integrity check | Node (cheerio, browser-free) | — | Operates on captured outerHTML string; no layout needed (D-09) |
| Stale-render / findings / award guards | Bash + node (`scripts/ci/`) | — | Clone the existing monotonic-guard idiom; attach to `fast_checks` (D-07/20/21) |
| Committed forward-only signal | Git (small text/JSON ledgers) | — | SHA ledger + award JSON + settled-findings.tsv are the reviewable diff (D-05) |
| Ephemeral bundles (DOM/PNG/axe) | CI artifact store (gitignored) | — | Keyed on `app_git_sha`; uploaded like `playwright-report/` (D-04) |

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `@playwright/test` | `^1.48.0` (already installed) | Render + in-browser probes + axe driver | Already the admin-design lane's engine; `page.evaluate`/`getComputedStyle`/`ariaSnapshot` all live here `[VERIFIED: test/example/priv/playwright/package.json]` |
| `@axe-core/playwright` | `^4.10.0` (already installed) | a11y engine incl. WCAG-2.2 `target-size` | Already in devDeps; axe-core 4.10 ships the `target-size` rule (WCAG 2.5.8) `[VERIFIED: package.json + CITED: deque.com axe-core 4.5 WCAG-2.2 blog]` |
| `parse5` | `^7.x` (verify at install) | HTML→AST for canonicalization allowlist walk | Spec-compliant HTML5 tree; the standard low-level parser both cheerio and jsdom build on; deterministic serialization `[ASSUMED]` |
| `cheerio` | `^1.0.0` (verify at install) | Anchor-presence check over captured outerHTML | jQuery-style selectors, htmlparser2-backed, no JS exec, ~faster + lower memory than jsdom `[CITED: cheerio.js.org; peterbe.com xmlMode bench]` |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `node:crypto` (builtin) | — | `sha256` for `render_sha256` + `finding_id` | Zero-dep hashing; `crypto.createHash('sha256')` |
| `jq` (system) OR `.mjs` | — | Award/findings guard JSON reads | D-20 guard: planner's discretion `.mjs` vs `.sh`+`jq` (CONTEXT Discretion) |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| parse5 allowlist walk | Playwright `locator.ariaSnapshot()` YAML as hash basis | ARIA-snapshot is a *pre-built semantic allowlist* (D-06) — less code, but loses non-ARIA structural attrs (`data-testid`, `href`) the CONTEXT allowlist wants; use as **secondary** or as a cross-check, not the sole basis `[CITED: playwright.dev/docs/aria-snapshots]` |
| parse5 | `rehype`/`hast` | Heavier unified-ecosystem toolchain; more deps for the same normalize-then-serialize; parse5 is the leaner primitive `[ASSUMED]` |
| cheerio (anchor check) | jsdom | jsdom executes scripts + builds a full DOM (slower, heavier); the captured HTML is already hydrated so no JS execution is needed — cheerio wins (D-09) `[CITED: cheerio.js.org — "does not execute JavaScript"]` |
| LazyHTML/lexbor | (Elixir-only) | Fast + spec-compliant, but it's a BEAM library; the harness runs in Node/Playwright, so it is **not applicable here** (D-06 notes it as the Elixir option only) `[VERIFIED: CONTEXT D-06]` |

**Installation:**
```bash
cd test/example/priv/playwright
npm install --save-dev parse5 cheerio
# @playwright/test and @axe-core/playwright already present
```

**Version verification (run before pinning):**
```bash
cd test/example/priv/playwright
npm view parse5 version        # confirm current 7.x
npm view cheerio version       # confirm current 1.x
npm ls @axe-core/playwright    # confirm 4.10.x installed
```

## Package Legitimacy Audit

> New external packages this phase installs: `parse5`, `cheerio`. `@playwright/test` and `@axe-core/playwright` are pre-existing (no new install).

| Package | Registry | Age | Downloads | Source Repo | Verdict | Disposition |
|---------|----------|-----|-----------|-------------|---------|-------------|
| parse5 | npm | ~10 yrs | ~50M+/wk | github.com/inikulin/parse5 | OK (well-known; the parser behind jsdom/cheerio/angular) | Approved — planner should still run `npm view parse5` at install |
| cheerio | npm | ~14 yrs | ~10M+/wk | github.com/cheeriojs/cheerio | OK (industry-standard server HTML) | Approved — planner should still run `npm view cheerio` at install |
| @playwright/test | npm | pre-existing | — | github.com/microsoft/playwright | OK | Already present |
| @axe-core/playwright | npm | pre-existing | — | github.com/dequelabs/axe-core-npm | OK | Already present |

**Packages removed due to [SLOP] verdict:** none.
**Packages flagged as suspicious [SUS]:** none.

*Note: parse5/cheerio identities here rest on training-data familiarity + their role as the substrate of jsdom/cheerio. Both are ubiquitous, but the planner MUST run `npm view <pkg> version` (and optionally `npm view <pkg> repository.url`) at install time to confirm the exact package on the npm registry before committing the lockfile. Tagged `[ASSUMED]` until that verification runs.*

## Architecture Patterns

### System Architecture Diagram

```
                       scripts/ci/admin-eval-harness.sh   (thin bash orchestrator, D-01)
                                     │
             ┌───────────────────────┼────────────────────────────┐
             │ boots example app (scripts/uat/up.sh)               │
             ▼                                                     │
   Playwright project `admin-eval`  (inherits playwright.config.ts, D-03)
             │  waitForLiveViewReady (font-gate + .phx-connected)  │
             ▼                                                     │
   FOR EACH (surface × cell = theme×viewport×state):               │
     ┌──────────────────────────────────────────────┐             │
     │ 1. capture: outerHTML, PNG, axe JSON          │             │
     │ 2. in-browser probes (page.evaluate) → facts  │  (D-11)     │
     │ 3. computed-style facts (--sg-* live reads)   │  (D-12)     │
     └──────────────────────────────────────────────┘             │
             │                                                     │
             ▼                                                     │
   bundle → test/example/priv/playwright/eval/<app_git_sha>/       │
              <surface>/<theme>-<viewport>-<state>/  (GITIGNORED, D-04)
             │                                                     │
   ┌─────────┴──────────┐                                          │
   ▼                    ▼                                          ▼
 canonicalize DOM    probe findings                     COMMITTED derived signal (D-05):
 (parse5 allowlist)  (machine-readable)                  - render_sha256 ledger
   │                    │                                 - open-finding counts
   ▼                    ▼                                 - admin-award-ledger.json
 render_sha256 ──────► (both feed the committed ledgers)  - settled-findings.tsv
                                                                   │
   fast_checks lane guards (bash/node, clone monotonic idiom):     │
     • stale-render-guard.sh        (bundle.app_git_sha == HEAD)   │  (D-07/08)
     • evidence-anchor-check.mjs    (cheerio: anchor present)      │  (D-09)
     • quality-findings-monotonic.sh(open count ↑ vs merge-base=FAIL)│(D-21)
     • award-guard.(mjs|sh)         (verify-then-climb, band==min) │  (D-20)
     • settled-findings-lint.sh     (sorted/deduped)               │  (D-22)
             │ all read merge-base from FIXED id:base step (D-10)  │
             ▼
        merge-blocking deterministic signal (LLM panel stays OFF this path)
```

### Recommended Project Structure
```
scripts/ci/
├── admin-eval-harness.sh          # thin orchestrator (clone snapshot-recapture-gate.sh shape)
├── stale-render-guard.sh          # D-07/08 (+ .test.sh)
├── stale-render-guard.test.sh
├── evidence-anchor-check.mjs      # D-09 cheerio (+ a node self-test)
├── quality-findings-monotonic.sh  # D-21 clone of quality-ledger-monotonic.sh (+ .test.sh)
├── quality-findings-monotonic.test.sh
├── award-guard.mjs                # D-20 (or .sh+jq; planner's discretion) (+ self-test)
├── settled-findings-lint.sh       # D-22 (+ .test.sh)
test/example/priv/playwright/
├── playwright.config.ts           # ADD `admin-eval` project (do NOT fork), D-03
├── tests/admin-eval.spec.ts       # render+probe+hash spec, sibling to admin-design.spec.ts
├── lib/eval/                      # canonicalize.ts, probes.ts, bundle.ts (shared TS helpers)
└── eval/<app_git_sha>/...         # GITIGNORED bundles (D-04)
guides/reference/
├── admin-award-ledger.json        # NEW award vector store (D-19)
├── settled-findings.tsv           # NEW suppression set (D-22)
├── admin-render-sha.json (or .tsv)# render_sha256 + open-finding counts (D-05; consolidation = planner's call)
```

### Pattern 1: Canonical DOM → render_sha256 (D-06) — RECOMMENDED PRIMARY
**What:** Capture post-hydration outerHTML, parse with parse5, walk the tree keeping an **allowlist** of semantic attrs + tag order + normalized text, strip volatile attrs, sort attrs/class tokens, serialize deterministically, sha256.
**When to use:** Every (surface×cell) bundle. This is the committed forward-only signal.
**Example:**
```typescript
// Source: parse5 API + CONTEXT D-06 allowlist. lib/eval/canonicalize.ts
import { parseFragment, serialize } from 'parse5';
import { createHash } from 'node:crypto';

// KEEP only these attrs (allowlist, not denylist — a denylist rots per LiveView release, D-06)
const KEEP_ATTRS = new Set(['type','name','role','aria-label','alt','data-testid']);
// href kept but digest/fingerprint-stripped; class kept but token-sorted.
const VOLATILE_PREFIXES = ['data-phx-','phx-'];        // all LiveView runtime attrs
const VOLATILE_EXACT = new Set(['nonce','integrity','id']); // id dropped unless data-testid present

const stripVsn = (v: string) => v.replace(/[?&]vsn=[^&"']*/g, '').replace(/-[0-9a-f]{32}(\.\w+)/,'$1');

function canonAttrs(attrs: {name:string; value:string}[]) {
  const out: {name:string; value:string}[] = [];
  for (const {name, value} of attrs) {
    if (VOLATILE_PREFIXES.some(p => name.startsWith(p))) continue;
    if (VOLATILE_EXACT.has(name)) continue;
    if (name === 'href') { out.push({name, value: stripVsn(value)}); continue; }
    if (name === 'class') {
      const sorted = value.split(/\s+/).filter(Boolean).sort().join(' ');
      out.push({name, value: sorted}); continue;
    }
    if (KEEP_ATTRS.has(name)) out.push({name, value});
  }
  return out.sort((a,b) => a.name.localeCompare(b.name));   // sort attrs
}

function walk(node: any) {                                  // depth-first, tree order
  if (node.nodeName === '#text') {
    const t = (node.value ?? '').replace(/\s+/g, ' ').trim();
    return t ? `#${t}` : '';                                // drop whitespace-only nodes
  }
  if (!node.tagName) return (node.childNodes ?? []).map(walk).join('');
  const attrs = canonAttrs(node.attrs ?? [])
    .map(a => `${a.name}=${a.value}`).join(' ');
  const kids = (node.childNodes ?? []).map(walk).join('');
  return `<${node.tagName}${attrs ? ' ' + attrs : ''}>${kids}`;
}

export function renderSha256(outerHTML: string): string {
  const doc = parseFragment(outerHTML);
  const canon = walk(doc);
  return createHash('sha256').update(canon).digest('hex');
}
```
**Geometry facts are NOT hashed raw** (D-06): bucket to tolerance before they enter the canonical string, e.g. `Math.round(rect.width * 2) / 2` for a ±0.5px epsilon, or drop geometry from the hash entirely and store it only as pre-computed `bundle.facts` (D-11). Never let a sub-pixel float into `render_sha256` — it makes the hash non-reproducible across CI runs.

### Pattern 1-alt: ARIA-snapshot as the hash basis (D-06 secondary)
```typescript
// Source: playwright.dev/docs/aria-snapshots
const yaml = await page.locator('#surface-root').ariaSnapshot(); // deterministic, whitespace-collapsed
const sha = createHash('sha256').update(yaml).digest('hex');
```
Pro: zero canonicalization code, Playwright already collapses whitespace + is order-sensitive. Con: the accessibility tree omits `data-testid`/non-semantic structure the CONTEXT allowlist wants. **Recommendation:** use parse5 primary; optionally emit the ARIA-snapshot alongside as a coarse cross-check, but hash the parse5 canonical form. `[CITED: playwright.dev/docs/aria-snapshots]`

### Pattern 2: In-browser token/box probe (D-11..D-13)
**What:** Read the live `--sg-*` scale off `:root`, read box longhands, normalize rem→px, diff focus box-shadow.
**When to use:** Every probe. Runs inside `page.evaluate` at capture.
**Example:**
```typescript
// Source: CONTEXT D-12/D-13 + Playwright #12629. lib/eval/probes.ts (runs via page.evaluate)
const facts = await page.evaluate(() => {
  const root = document.documentElement;
  const cs = getComputedStyle(root);
  const rootFontPx = parseFloat(cs.fontSize);                 // for rem→px
  const remToPx = (v: string) => v.endsWith('rem') ? parseFloat(v) * rootFontPx : parseFloat(v);

  // Live --sg-* scale (NEVER a duplicated JS constant table — proven drift risk, D-12)
  const spaceScale = [1,2,3,4,5,6,7,8,10,12].map(n =>
    remToPx(cs.getPropertyValue(`--sg-space-${n}`).trim()));  // getPropertyValue, NOT toHaveCSS (#12629)
  const radiusScale = ['xs','sm','md','lg'].map(k =>
    remToPx(cs.getPropertyValue(`--sg-radius-${k}`).trim()));
  const controlScale = ['xs','sm','md','lg'].map(k =>
    remToPx(cs.getPropertyValue(`--sg-control-${k}`).trim()));

  const el = document.querySelector('#surface-root .sg-btn') as HTMLElement;
  const es = getComputedStyle(el);
  // Longhands, never shorthand (D-12): clamp()/color-mix()/oklab resolve to concrete px under getComputedStyle
  const box = {
    paddingTop: parseFloat(es.paddingTop), paddingRight: parseFloat(es.paddingRight),
    paddingBottom: parseFloat(es.paddingBottom), paddingLeft: parseFloat(es.paddingLeft),
    radii: [es.borderTopLeftRadius, es.borderTopRightRadius,
            es.borderBottomRightRadius, es.borderBottomLeftRadius].map(parseFloat),
  };
  return { rootFontPx, spaceScale, radiusScale, controlScale, box };
});
```

### Pattern 3: Focus-ring probe diffs box-shadow, not outline (D-13)
```typescript
// Source: sigra_admin.css:449-451 authors focus as `outline:none; box-shadow: var(--sg-focus-ring)`
const focusRingPresent = await page.evaluate(() => {
  const el = document.querySelector('#surface-root .sg-btn') as HTMLElement;
  const before = getComputedStyle(el);
  const b = { shadow: before.boxShadow, outline: before.outlineWidth };
  el.focus();
  const after = getComputedStyle(el);
  // PASS if EITHER box-shadow OR outline changes (D-13); presence suffices for the gate.
  return after.boxShadow !== b.shadow || after.outlineWidth !== b.outline;
});
```
`--sg-focus-ring` is `0 0 0 3px color-mix(...)` (3px ≥ WCAG 2.4.13 floor) `[VERIFIED: sigra_admin.css:148-150]` — a presence check gates; leave the 3:1 contrast-delta to warn/LLM.

### Pattern 4: axe target-size probe (D-14) — rule is DISABLED BY DEFAULT
```typescript
// Source: @axe-core/playwright + deque docs. target-size (2.5.8) is OFF even with wcag22aa tag.
import AxeBuilder from '@axe-core/playwright';
const { violations } = await new AxeBuilder({ page })
  .include('#surface-root')
  .withTags(['wcag22aa'])
  .options({ rules: { 'target-size': { enabled: true } } })   // MUST explicitly enable
  .analyze();
```
CONFIRMED this session: axe-core's `target-size` "is disabled by default, until WCAG 2.2 is more widely adopted" — the `wcag22aa` tag alone will NOT run it. `[CITED: deque.com axe-core docs; github.com/dequelabs/axe-core rule-descriptions]`. Inherit axe's built-in 24×24 + spacing-exception math (D-14) rather than reimplementing it.

### Pattern 5: Card-in-card probe (D-14) — lift verbatim
Copy `admin-design.spec.ts:349-361` verbatim: `board.querySelectorAll('.sg-card .sg-card:not(.sg-skeleton)')`, honoring the `data-sg-card-nesting-audit-only` suppression attribute. Reuse the same `data-sg-<probe>-audit-only` convention as every probe's escape hatch (D-14) — do not invent a new suppression mechanism. `[VERIFIED: admin-design.spec.ts:349-361]`

### Pattern 6: Evidence-anchor check (D-09) — cheerio over outerHTML
```javascript
// Source: cheerio.js.org loading docs. scripts/ci/evidence-anchor-check.mjs
import { load } from 'cheerio';
const $ = load(html);                     // HTML mode (default); do NOT pass { xmlMode: true }
for (const finding of findings) {
  // anchor MUST be a structural selector / data-* hook — never prose/text (survives copy edits, D-09)
  if ($(finding.anchor).length === 0) {
    console.error(`evidence-anchor-check: FAIL: anchor absent for ${finding.finding_id}: ${finding.anchor}`);
    process.exitCode = 1;
  }
}
```
cheerio (not jsdom): the string is already hydrated, no JS execution needed; cheerio is faster + lower-memory `[CITED: cheerio.js.org]`. Geometry-dependent facts (misalignment, below-fold, focus-ring) **cannot** be recomputed here (no layout) — they were produced in-browser at capture (D-11).

### Pattern 7: Guard cloned from quality-ledger-monotonic.sh (D-21)
The findings-count guard is a structural clone with the comparator **inverted** (FAIL on increase):
```bash
# Source: scripts/ci/quality-ledger-monotonic.sh:22-55 (clone + invert). Uses merge-base per D-10.
declare -A BASE_COUNTS=()
while IFS=$'\t' read -r item cnt; do BASE_COUNTS["$item"]="$cnt"; done \
  < <(git -C "$ROOT" show "${BASE}:${LEDGER}" 2>/dev/null | extract_open_counts)
# skip-on-empty-base is CORRECT for the up-ratchet tier guard, but D-08/D-21: for findings,
# an EMPTY base still means "no prior findings" — an increase from 0 IS a real regression.
# Follow the tier guard's skip-on-empty-base ONLY if the ledger file is absent at base
# (initial commit); otherwise compare. (Document which branch you take in the .test.sh.)
for item in "${!HEAD_COUNTS[@]}"; do
  base="${BASE_COUNTS[$item]:-0}"; head="${HEAD_COUNTS[$item]}"
  if (( head > base )); then                 # INVERTED vs tier guard's `<`
    echo "quality-findings-monotonic: FAIL: open findings increased for '${item}': ${base} → ${head}" >&2
    violations=1
  fi
done
```

### Anti-Patterns to Avoid
- **`toHaveCSS` for `--sg-*` custom props** — returns empty / "Unknown expect matcher" (#12629). Always `evaluate` + `getComputedStyle().getPropertyValue()`. `[CITED: github.com/microsoft/playwright/issues/12629]`
- **Duplicated JS token constant table** — drifts from CSS (the example↔source CSS-split incident). Read live from `:root` (D-12).
- **Denylist of volatile attrs** — rots on every LiveView release. Use an allowlist (D-06).
- **mtime freshness check** — `actions/checkout` stamps run-time mtime → 100% false-pass in CI. Use git plumbing (D-07). `[CITED: actions/checkout#468]`
- **Decorators in ledger tier column-4** — `2*`/`2+` are invisible to the `awk /^[012]$/` parse → silent false-pass (Test D). Keep the markdown column grammar FROZEN; put award data in JSON (D-19). `[VERIFIED: quality-ledger-monotonic.test.sh Test D]`
- **Hashing raw sub-pixel geometry** — non-reproducible across runs. Bucket to ±0.5px or exclude from hash (D-06).
- **Forking playwright.config.ts** — creates a second determinism brain. Add a project (D-03).
- **`--depth=1` on the base fetch** — shallows history so `git merge-base` fails. Full history is needed (D-10).

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Target-size (24×24 + spacing math) | Custom bounding-box comparison | axe-core `target-size` rule (enable it) | Deque already handles overlap/spacing exceptions; reimplementing invites the "incorrect offset" bug class (D-14) `[CITED: axe-core#4295]` |
| HTML canonicalization | Regex over outerHTML | parse5 tree walk | Regex can't reason about tree structure / attr order; parse5 is spec-compliant (D-06) |
| Anchor-presence over HTML | jsdom full DOM build | cheerio `load()` + `$(sel).length` | No JS execution needed on hydrated HTML; cheerio faster/leaner (D-09) |
| Monotonic guard scaffolding | New bash from scratch | Clone `quality-ledger-monotonic.sh` + `.test.sh` | Proven git-base-diff + associative-array + hermetic self-test idiom (D-21) |
| Card-in-card detection | New selector logic | Lift `admin-design.spec.ts:349-361` verbatim | Already handles the suppression attr + skeleton exclusion (D-14) |
| Font-ready gating | New wait logic | Reuse `waitForLiveViewReady` | Font-gate + `.phx-connected` already battle-tested (D-03) `[VERIFIED: admin-design.spec.ts:15-26]` |
| ARIA snapshot / a11y tree | Custom DOM→semantic serializer | `locator.ariaSnapshot()` | Playwright emits deterministic YAML (D-06 alt) |

**Key insight:** Nearly every primitive this phase needs already exists in the repo (the monotonic-guard idiom, the card-in-card check, `waitForLiveViewReady`, `getComputedStyle` usage, the `/admin/_design` render matrix, `@axe-core/playwright`). The work is **wiring and canonicalization**, not net-new engines. The two genuinely new external deps (parse5, cheerio) are ubiquitous parsers.

## Common Pitfalls

### Pitfall 1: axe `target-size` silently never runs
**What goes wrong:** `.withTags(['wcag22aa'])` looks like it should include 2.5.8, but the rule is disabled by default, so the probe reports zero violations forever — a false-clean gate.
**Why:** Deque ships `target-size` off until WCAG 2.2 is widely required. `[CITED: deque.com]`
**How to avoid:** Add `.options({ rules: { 'target-size': { enabled: true } } })`. Prove it with a fixture element deliberately < 24×24 that the probe MUST flag.
**Warning signs:** target-size probe passes on a surface known to have a sub-minimum control.

### Pitfall 2: render_sha256 non-reproducible across CI runs
**What goes wrong:** Two identical-source runs produce different SHAs → every PR shows a spurious ledger diff.
**Why:** Raw geometry floats, unsorted attrs/classes, LiveView `data-phx-*`/`nonce`/`?vsn=` fingerprints, or whitespace leak into the canonical string.
**How to avoid:** Strip all volatile attrs (allowlist), sort attrs + class tokens, normalize whitespace, bucket/exclude geometry (D-06). Add a determinism self-test: canonicalize the same captured HTML twice → identical SHA; canonicalize with a mutated `data-phx-id` → identical SHA.
**Warning signs:** SHA changes when only a `nonce` or asset digest changed.

### Pitfall 3: merge-base guard false-fails when main moves ahead
**What goes wrong:** The down-ratchet guard fails a PR whose branch is fine, because it diffs against the base-branch TIP, which has commits the fork hasn't merged.
**Why:** The `id: base` step emits `origin/${base_ref}` (tip) via a `--depth=1` fetch, while installer-detect uses three-dot merge-base — an existing inconsistency (D-10). `[VERIFIED: ci.yml:66-73 vs :88]`
**How to avoid:** Change the `id: base` step to `MB=$(git merge-base origin/${{ github.base_ref }} HEAD)` and emit `MB`; drop `--depth=1` (checkout already sets `fetch-depth: 0` so full history is present) `[VERIFIED: ci.yml:63 fetch-depth: 0]`. This one change fixes the new findings guard, the existing tier guard, and `snapshot-canary-guard.sh` simultaneously.
**Warning signs:** guard fails on a PR that added nothing to the guarded ledger.

### Pitfall 4: bundles committed to git by accident
**What goes wrong:** DOM/PNG/axe bundles under `test/example/priv/playwright/eval/` get `git add`ed → repo bloat + churn.
**Why:** Only `/test-results/` and `test/example/_build/` are currently gitignored; `test/example/priv/playwright/` is NOT `[VERIFIED: .gitignore]`, and there is no `playwright-report` ignore for the example subproject.
**How to avoid:** Add explicit ignores: `test/example/priv/playwright/eval/`, `test/example/priv/playwright/playwright-report/`, `test/example/priv/playwright/test-results/`. Commit only the derived SHA/award/settled ledgers (D-04/D-05). Upload bundles as CI artifacts.
**Warning signs:** `git status` shows PNGs under `eval/`.

### Pitfall 5: stale-render guard skips instead of fails on missing bundles
**What goes wrong:** If bundles are absent, a naive guard (copying the tier guard's skip-on-empty-base) exits 0 → an untrustworthy/absent render passes.
**Why:** The tier guard's skip-on-empty-*base* is correct there (a decrease is impossible with no baseline) but HARNESS-02 forbids trusting absent renders (D-08).
**How to avoid:** Absence of bundles = hard FAIL (D-08). The captured sha lives inside the current run's bundle, so there is no first-phase bootstrap problem — the guard is self-contained against current HEAD. `git cat-file -e <sha>` must error loudly if the bundle sha is unreachable rather than skip (D-07).
**Warning signs:** guard passes when the `eval/` dir is empty.

### Pitfall 6: user-show pilot cites a stale modal claim
**What goes wrong:** The ledger's `user-show-live` cell cites `admin-modal-interaction.spec.ts` APG claims, but the design contract says the confirm overlay *moved to `UserSessionsLive`* — the cited claim may be stale.
**Why:** Manual-era ledger prose can drift from where the component actually lives (D-24).
**How to avoid:** The user-show pilot's FIRST job is to re-verify modal ownership against rendered output. This is a **feature** (proves the harness catches a stale prior claim), not a blocker (D-24). Do not assume the modal is on user-show; assert where it actually renders.
**Warning signs:** overlay-axe/focus-trap probe finds no modal on user-show.

## Ledger / Award JSON Schema (D-17..D-22)

### `guides/reference/admin-award-ledger.json` (D-18/D-19/D-20)
```jsonc
{
  "schema_version": 1,
  "cells": {
    "users-index-live": {
      "axes": {                          // fixed 4-axis vector (D-18)
        "token_fidelity": "A1",          // ordinal A0..A3 (D-17)
        "rhythm":         "A1",
        "a11y_polish":    "A2",
        "states":         "A1"
      },
      "band": "A1",                      // DERIVED = min(axes) (D-18) — guard recomputes, never hand-typed
      "verified_at_sha": "abc1234",      // app_git_sha of the render that earned this (D-20)
      "rendered": true,                  // false forbids any raised axis (D-20c)
      "evidence_ref": ["probe:off-token-spacing","probe:target-size","test:assertUserResultEquivalence"]
                                         // each must resolve to a known probe id / test id / conformance selector (D-20c)
    },
    "user-show-live": {
      "axes": { "token_fidelity": "A1", "rhythm": "A1", "a11y_polish": "A1", "states": "A1" },
      "band": "A1", "verified_at_sha": "abc1234", "rendered": true,
      "evidence_ref": ["probe:focus-ring","probe:card-in-card"]
    }
  }
}
```
**Band semantics (D-17, additive — cannot hold A2 without A1):**
- **A0 Nominated** — Tier-2 + every applicable probe has a *rendered* evidence key.
- **A1 Shortlisted** — + the 3 manual proxies (motion / whitespace-rhythm / target-size) converted to rendered probes (D-16).
- **A2 Commended** — + adversarial states (zero/loading/error) rendered & axe-clean, content-equivalence proven.
- **A3 Award-grade** — + persona-JTBD panel `clean` + cross-viewport/theme render parity. **Pilots cap at A2** (D-25) since the persona panel isn't re-run at HEAD.

**Award guard (D-20) FAIL conditions — the `.test.sh`/self-test must cover each:**
1. An axis band rose but `verified_at_sha` did not change → FAIL (climb without fresh render).
2. `band != min(axes)` → FAIL.
3. Any raised axis has `rendered:false` OR an `evidence_ref` that doesn't resolve → FAIL.
4. Any axis band decreased vs merge-base → FAIL.
5. No-change run → PASS. Legit climb (axis A1→A2 + fresh `verified_at_sha` + resolving evidence) → PASS.

**Ordinal comparison:** map `A0..A3` → `0..3` for `min()` and monotonic comparison. Keep the markdown ledger column-4 (`0/1/2`) FROZEN; append at most one sentence to the evidence cell cross-referencing the JSON (D-19).

### `guides/reference/settled-findings.tsv` (D-22)
```
# finding_id\tsurface\tclass\tanchor\tdisposition\twaived_by\tnote   (header comment; sorted, one entry/line)
<sha256>	users-index-live	off-token-spacing	[data-testid="admin-users-desktop-results"] .sg-applied-chip	waived	jon	dense-control exempt
```
**Key (MUST match Phase 217 AUTOFIX-01 exactly — plan both together, D-22):**
```
finding_id = sha256(surface + "\0" + class + "\0" + anchor)
```
Note Phase 217's requirement text says `hash of surface+lens+question+anchor` — reconcile with D-22's `surface+class+anchor` when planning 217; **the deterministic-substrate key that lands in 216 is `surface\0class\0anchor`** (probes have a `class`, not a `lens`/`question`). The planner should flag this as a cross-phase contract to lock jointly.
- Anchor is a **structural selector / data-* hook**, never prose/line-number (the Betterer merge-conflict lesson).
- `disposition ∈ {waived, resolved}`.
- `settled-findings-lint.sh` (D-22) FAILs if unsorted/deduped; regen helper `--add … --disposition` so humans never hand-edit ordering.
- A settled entry whose anchor no longer appears in any current bundle is flagged **stale** (non-blocking prune).
- `Open` count = total findings − settled, computed by the harness from ONE source (never hand-maintained → no drift, D-21).

### Ledger grammar this schema must NOT break
- The markdown tier column-4 is parsed positionally by `awk -F'|'` with `/^[012]$/`; ANY decorator breaks it silently (Test D). Award data goes in JSON precisely so a guard can enforce what awk cannot (D-19). `[VERIFIED: admin-quality-ledger.md:14-31; quality-ledger-monotonic.test.sh Test D]`
- The persona-rubric already carries a "D-07 column-4 integer prohibition" contract (compliant values are `keep/tighten/kill/clean` — non-integer strings) `[VERIFIED: admin-persona-jtbd-rubric.md:272-284]`. The award JSON's `min()` roll-up mirrors the rubric's existing **worst-verdict floor rule** (`kill` from any lens = kill) `[VERIFIED: admin-persona-jtbd-rubric.md:73-79]`.

## Harness Wiring

### 1. Add the `admin-eval` Playwright project (D-03 — do NOT fork config)
Append one project to the `projects: [...]` array in `playwright.config.ts`. It inherits the top-level `use` block (baseURL, longpoll timeouts) and `expect` determinism (the config has no top-level `animations`/`caret`; those are per-`toHaveScreenshot` — the eval spec should pass them explicitly if it screenshots). Mirror the design lanes:
```typescript
{ name: 'admin-eval', testMatch: /admin-eval\.spec\.ts/, use: { ...devices['Desktop Chrome'] } },
// geometry probes HARD-GATE only in this DPR1 chromium project (D-15);
// add -mobile / -dark siblings that emit the same probes as WARN-only.
```
Reuse `waitForLiveViewReady(page)` before any capture (font-gate + `.phx-connected`) `[VERIFIED: admin-design.spec.ts:15-26]`.

### 2. Bash entrypoint (D-01) — clone `snapshot-recapture-gate.sh` shape
Thin orchestrator: boots the example app (via `scripts/uat/up.sh` or an already-booted `SIGRA_EXAMPLE_URL`), runs `npx playwright test tests/admin-eval.spec.ts --project=admin-eval`, then invokes the node canonicalize + the guards. Mirror `snapshot-recapture-gate.sh`'s `ROOT`/`PW`/`SIGRA_EXAMPLE_URL` conventions `[VERIFIED: snapshot-recapture-gate.sh:16-18]`.

### 3. Fix the shared `id: base` step (D-10) — the ONE-LINE semantics change
In `ci.yml` `fast_checks` (~L66-73), replace:
```yaml
git fetch origin "${{ github.base_ref }}" --depth=1
echo "ref=origin/${{ github.base_ref }}" >> "$GITHUB_OUTPUT"
```
with:
```yaml
git fetch origin "${{ github.base_ref }}"          # NO --depth=1 (merge-base needs history)
MB=$(git merge-base "origin/${{ github.base_ref }}" HEAD)
echo "ref=${MB}" >> "$GITHUB_OUTPUT"
```
`fetch-depth: 0` on checkout already provides HEAD's full history `[VERIFIED: ci.yml:63]`; only the base ref was being shallow-fetched. All `--base "${{ steps.base.outputs.ref }}"` consumers (snapshot-canary ×2, quality-ledger-monotonic) then get merge-base for free.

### 4. Attach new guards to `fast_checks` (the deterministic lane, NEVER a Playwright/nightly lane — JUDGE-CI-01)
Add `run:` steps beside the existing `Quality ledger monotonic guard` step (~L109) `[VERIFIED: ci.yml:109-116]`:
```yaml
- name: Stale-render guard
  run: bash scripts/ci/stale-render-guard.sh
- name: Evidence anchor integrity check
  run: node scripts/ci/evidence-anchor-check.mjs
- name: Quality findings monotonic guard
  run: bash scripts/ci/quality-findings-monotonic.sh --base "${{ steps.base.outputs.ref }}"
- name: Quality findings monotonic guard self-test
  run: bash scripts/ci/quality-findings-monotonic.test.sh
- name: Award ledger verify-then-climb guard
  run: node scripts/ci/award-guard.mjs --base "${{ steps.base.outputs.ref }}"
- name: Settled findings lint
  run: bash scripts/ci/settled-findings-lint.sh
```
Note: the render+probe (Playwright) itself is expensive and NOT in `fast_checks`; only its cheap deterministic *derivatives* (the SHA/findings/award ledgers) gate merges. The render job runs where the existing design lanes run (its own Playwright job), and the guards read the committed derived ledgers — matching the invariant that the merge-blocking signal is 100% deterministic and off the LLM path.

### 5. Gate-vs-warn split (D-15 — flake containment)
- **HARD GATE (chromium DPR1 only):** #1 off-token spacing, #4 ember-reserved-for, #5 off-scale radius + control-height, #6 target-size @24×24, #7 missing focus-ring, #8 card-in-card.
- **WARN-ONLY:** #2 1-6px misalignment, #3 size/weight budget, #5 shadow-composite, #6 44×44 advisory, #9 below-fold geometry (salience routes to Phase-217 panel).
- `-mobile`/`-dark` runs of the geometry probes emit WARNINGS, never hard-gate.
- Fold line uses `documentElement.clientHeight` (excludes scrollbar) `[CONFIRMED: standard DOM — clientHeight excludes scrollbar]`.

## Runtime State Inventory

> This phase adds new committed files + gitignore entries + CI steps. It is not a rename/refactor, but it touches CI runtime config and git-tracked state, so the relevant categories:

| Category | Items Found | Action Required |
|----------|-------------|------------------|
| Stored data | None — bundles are ephemeral, keyed on `app_git_sha`, gitignored (D-04). No DB writes. | None |
| Live service config | `.github/workflows/ci.yml` `id: base` step + `fast_checks` steps — config lives in git, but changing base-ref semantics affects EVERY consumer (snapshot-canary ×2, tier guard). | Code edit (D-10) + verify all consumers |
| OS-registered state | None | None |
| Secrets/env vars | `SIGRA_EXAMPLE_URL` reused (existing); no new secrets. | None |
| Build artifacts | `test/example/priv/playwright/eval/` + `playwright-report/` will be generated but must NOT be tracked. `test/example/priv/playwright/` is NOT currently gitignored. | Add `.gitignore` entries (Pitfall 4) |

## Validation Architecture

> `workflow.nyquist_validation` treated as enabled (no explicit false found).

### Test Framework
| Property | Value |
|----------|-------|
| Framework (TS) | Playwright `@playwright/test ^1.48.0` (existing lanes) `[VERIFIED: package.json]` |
| Framework (guards) | bash `.test.sh` hermetic self-tests (mktemp throwaway git repo) `[VERIFIED: quality-ledger-monotonic.test.sh]` |
| Framework (Elixir) | ExUnit (unchanged; no lib code in this phase) |
| Config file | `test/example/priv/playwright/playwright.config.ts` (add project, no fork) |
| Quick run command | `cd test/example/priv/playwright && npx playwright test tests/admin-eval.spec.ts --project=admin-eval` |
| Guard self-tests | `bash scripts/ci/<guard>.test.sh` (each guard) |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| HARNESS-01 | One command emits bundles (DOM+PNG+axe+facts+sha) for the matrix | integration | `bash scripts/ci/admin-eval-harness.sh` (asserts bundle presence) | ❌ Wave 0 |
| HARNESS-01 | `render_sha256` is reproducible (canonicalization determinism) | unit | node self-test: same HTML → same sha; mutated `data-phx-*`/`nonce`/`?vsn=` → same sha | ❌ Wave 0 |
| HARNESS-02 | Stale-render guard fails when `app_git_sha ≠ HEAD` or admin source newer | unit | `bash scripts/ci/stale-render-guard.test.sh` (hermetic: mismatched sha FAIL, match PASS, empty-bundle FAIL, unreachable-sha errors) | ❌ Wave 0 |
| HARNESS-02 | Evidence-anchor check rejects a finding whose anchor is absent | unit | node test: present-anchor PASS, absent-anchor exit 1 | ❌ Wave 0 |
| HARNESS-03 | Each of the 9 probe classes flags a seeded defect | integration | `admin-eval.spec.ts` with a fixture element per probe (esp. target-size < 24×24, focus-ring present, card-in-card nested) | ❌ Wave 0 |
| HARNESS-03 | target-size rule actually runs (not silently disabled) | unit | axe probe flags a deliberate < 24×24 control | ❌ Wave 0 |
| RATCHET-01 | Award guard fails climb-without-render / band≠min / unresolved evidence / decrease | unit | `node scripts/ci/award-guard.mjs` self-test — 5 cases in D-20 list | ❌ Wave 0 |
| RATCHET-01 | Verify-then-climb re-verifies a Tier-2 claim against rendered output | integration | pilot run on users-index-live + user-show-live; user-show modal-ownership re-verified (D-24) | ❌ Wave 0 |
| RATCHET-02 | Findings-count guard fails on open-count increase vs merge-base | unit | `bash scripts/ci/quality-findings-monotonic.test.sh` — 3→4 FAIL, no-change PASS, 4→3 PASS, decorated-cell-invisible documented (Test-D lesson) | ❌ Wave 0 |
| RATCHET-02 | settled-findings.tsv lint fails if unsorted/deduped | unit | `bash scripts/ci/settled-findings-lint.sh` self-test — sorted PASS, unsorted FAIL, dup FAIL | ❌ Wave 0 |
| D-10 (foundation) | Base-ref emits merge-base; existing guards still green | integration | run snapshot-canary + tier guard against the new `id: base` output on a synthetic ahead-of-main branch | ❌ Wave 0 |

### Sampling Rate
- **Per task commit:** the relevant guard `.test.sh` (< 5s each, hermetic).
- **Per wave merge:** full `admin-eval.spec.ts` on `admin-eval` chromium + all guard self-tests.
- **Phase gate:** two pilots complete render→probe→ratchet end-to-end with zero guard regressions; `fast_checks` green.

### Wave 0 Gaps
- [ ] `scripts/ci/stale-render-guard.sh` + `.test.sh` — HARNESS-02
- [ ] `scripts/ci/evidence-anchor-check.mjs` + node self-test — HARNESS-02
- [ ] `scripts/ci/quality-findings-monotonic.sh` + `.test.sh` — RATCHET-02 (clone monotonic guard)
- [ ] `scripts/ci/award-guard.mjs` (or `.sh`+jq) + self-test — RATCHET-01
- [ ] `scripts/ci/settled-findings-lint.sh` + `.test.sh` — RATCHET-02
- [ ] `scripts/ci/admin-eval-harness.sh` — HARNESS-01 orchestrator
- [ ] `test/example/priv/playwright/tests/admin-eval.spec.ts` + `lib/eval/{canonicalize,probes,bundle}.ts` — HARNESS-01/03
- [ ] `admin-eval` project in `playwright.config.ts` — HARNESS-01
- [ ] `parse5` + `cheerio` install (`npm view` verify first) — HARNESS-01/02
- [ ] `.gitignore` entries for `eval/` + `playwright-report/` + `test-results/` under `test/example/priv/playwright/` — HARNESS-01
- [ ] `ci.yml` `id: base` merge-base fix + new guard steps — D-10 + wiring
- [ ] `guides/reference/admin-award-ledger.json`, `settled-findings.tsv`, `render-sha` ledger — RATCHET-01/02

## Security Domain

> `security_enforcement` treated as enabled. This phase is CI/tooling + evaluation infrastructure — it ships NO runtime auth code, NO new endpoints, NO user data handling. The rendered surface is the dev-only `/admin/_design` gallery (static literal assigns) + two admin pages already gated by `Example.SigraAdminPolicy`.

### Applicable ASVS Categories
| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | No auth code changed; harness registers a test admin via existing flow |
| V3 Session Management | no | No session code |
| V4 Access Control | no | `/admin/_design` is dev-only; admin pages use existing policy |
| V5 Input Validation | minor | Guards parse committed ledgers + captured HTML; treat bundle JSON/HTML as untrusted input — use structural parsers (parse5/cheerio), never `eval`; anchors are selectors run via cheerio `$()`, not shell-interpolated |
| V6 Cryptography | minor | `sha256` via `node:crypto` for content-addressing only (not a security boundary) — do not hand-roll |
| V14 Config | yes | CI workflow change (D-10) — verify no secret exposure; base-ref fetch is public-repo git only |

### Known Threat Patterns for this stack
| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| cite-and-flip (claim cites code, not rendered output) | Tampering | Evidence-anchor check over CAPTURED DOM; structural anchors only (D-09) — impossible by construction |
| Optimistically-flipped ledger cell | Tampering | Award guard verify-then-climb: `verified_at_sha` freshness + resolvable `evidence_ref` (D-20) |
| Shell injection via anchor/finding text into a guard | Injection | Anchors go through cheerio `$()`, never `bash`/`eval`; findings are JSON-parsed, not interpolated |
| Malicious/oversized bundle DoS in CI | DoS | Bundles are self-produced in the same run; parse with bounded structural parsers |

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `parse5 ^7.x` / `cheerio ^1.0.0` are the current, correct packages | Standard Stack | Low — ubiquitous; planner runs `npm view` at install to confirm exact versions |
| A2 | `rehype` is heavier than parse5 for this normalize+serialize task | Alternatives | Low — either works; parse5 is the leaner primitive |
| A3 | `finding_id = sha256(surface\0class\0anchor)` is the substrate key (vs 217's `surface+lens+question+anchor`) | Ledger Schema | MEDIUM — cross-phase contract; planner MUST reconcile 216↔217 key jointly (D-22 says plan together). Flag for confirmation. |
| A4 | The award-guard is a node `.mjs` (vs `.sh`+jq) | Wiring | None — CONTEXT explicitly leaves this to planner discretion |
| A5 | Consolidation of render-sha + finding-counts into one JSON vs separate files | Structure | None — CONTEXT leaves to planner discretion (each guard reads one authoritative source + merge-base) |

## Open Questions

1. **`finding_id` composition across 216/217**
   - What we know: D-22 says `surface\0class\0anchor`; Phase 217 AUTOFIX-01 text says `surface+lens+question+anchor`. Probes have a `class`; LLM lenses have `lens+question`.
   - What's unclear: whether the shared key uses `class` (deterministic probe) as the analog of `lens+question`, or whether 217 supersets it.
   - Recommendation: Lock the 216 substrate key as `sha256(surface\0class\0anchor)` and have 217 map its `lens+question` into the same `class` slot (or define a namespaced key). Plan both phases' key together per D-22 — do not finalize 216's TSV columns without 217's queue schema in view.

2. **Where exactly does the render+probe Playwright job live in `ci.yml`?**
   - What we know: guards go in `fast_checks`; the render itself is expensive (not fast_checks).
   - What's unclear: whether to add an `admin-eval` job beside the existing design-lane Playwright job, or fold into it.
   - Recommendation: separate job (mirrors design-lane partitioning); the committed ledgers are the seam so `fast_checks` never depends on the render job's runtime.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Node/npm | Playwright + guards | ✓ (CI + local) | (existing) | — |
| `@playwright/test` | render+probe | ✓ | `^1.48.0` | — |
| `@axe-core/playwright` | target-size + axe | ✓ | `^4.10.0` | — |
| parse5 | canonicalization | ✗ (new) | 7.x (verify) | ariaSnapshot-based hash (D-06 alt) |
| cheerio | anchor check | ✗ (new) | 1.x (verify) | jsdom (heavier; not recommended) |
| Postgres (example app) | booting the surfaces | ✓ (scripts/db/up.sh, dynamic port) | 15 | — |
| jq | award guard (if .sh path) | usually present | — | write guard as `.mjs` (no jq dep) |

**Missing dependencies with no fallback:** none.
**Missing dependencies with fallback:** parse5 (→ ariaSnapshot), cheerio (→ jsdom).

## Sources

### Primary (HIGH confidence)
- `scripts/ci/quality-ledger-monotonic.sh` + `.test.sh` — guard idiom to clone (git-base-diff, associative-array, hermetic self-test, Test-D decorator lesson)
- `scripts/ci/snapshot-canary-guard.sh`, `snapshot-recapture-gate.sh` — bash-over-Playwright orchestrator + `--base` consumers
- `.github/workflows/ci.yml:58-130` — `fast_checks` lane + `id: base` step (the D-10 tip-vs-merge-base inconsistency, verified L66-73 vs L88)
- `test/example/priv/playwright/playwright.config.ts` — project array, `use` defaults, `pathTemplate`
- `test/example/priv/playwright/tests/admin-design.spec.ts:15-26,349-361` — `waitForLiveViewReady`, card-in-card check, `getComputedStyle`/`data-sg-*-audit-only` precedent
- `test/example/priv/static/assets/sigra_admin.css:22-100,148-150,449-451` — `--sg-space/radius/control` scale, `--sg-focus-ring` box-shadow authoring
- `test/example/lib/example_web/live/admin/design_gallery_live.ex` — `data-testid="mg-N-{populated,zero,loading,error}"` render matrix
- `guides/reference/admin-quality-ledger.md:14-39,58-95` — frozen column-4 grammar + full cell inventory
- `guides/reference/admin-persona-jtbd-rubric.md:73-79,272-284` — worst-verdict floor rule + column-4 integer prohibition
- `guides/reference/admin-fractal-scorecard.md:160-174` — the 3 documented-as-manual proxies (D-16)
- `test/example/priv/playwright/package.json` — `@axe-core/playwright ^4.10.0`, `@playwright/test ^1.48.0`

### Secondary (MEDIUM confidence, verified this session)
- [github.com/microsoft/playwright/issues/12629](https://github.com/microsoft/playwright/issues/12629) — `toHaveCSS` can't read custom props; use `evaluate` + `getComputedStyle().getPropertyValue()`
- [deque.com axe-core docs / rule-descriptions](https://github.com/dequelabs/axe-core/blob/develop/doc/rule-descriptions.md) — `target-size` disabled by default; enable via `rules:{'target-size':{enabled:true}}`
- [playwright.dev/docs/aria-snapshots](https://playwright.dev/docs/aria-snapshots) — `ariaSnapshot()`/`toMatchAriaSnapshot` deterministic YAML
- [cheerio.js.org](https://cheerio.js.org/docs/basics/loading/) — HTML mode, no JS execution, faster/leaner than jsdom
- [actions/checkout#468](https://github.com/actions/checkout/issues/468) — checkout stamps run-time mtime (grounds D-07)

### Tertiary (LOW confidence)
- parse5/rehype relative weight — training knowledge; either works, planner verifies at install

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — 2 of 4 deps already installed + verified; parse5/cheerio are ubiquitous (verify exact versions at install)
- Architecture: HIGH — every pattern grounded in an actual repo file + CONTEXT decision
- Pitfalls: HIGH — axe target-size + toHaveCSS #12629 + mtime + column-4 decorator all verified this session or in-repo
- Schema: HIGH — grounded against the frozen ledger/rubric grammar in-repo
- Cross-phase `finding_id`: MEDIUM — flagged as an open contract to reconcile with Phase 217

**Research date:** 2026-07-03
**Valid until:** 2026-08-03 (stable domain; re-verify parse5/cheerio versions + axe `target-size` default status if axe-core majors before install)
