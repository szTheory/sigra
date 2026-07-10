# Admin Graphic-Design Lens

This file is the **graphic-design judge instrument** for Sigra admin surfaces. It is a sibling
of `admin-persona-jtbd-rubric.md`, not an appendix to it. Both instruments must pass for a
surface to warrant Tier-2 ratification.

---

## IMPORTANT DISAMBIGUATION

The 3 lenses in `admin-persona-jtbd-rubric.md` are **operator/UX lenses** — they judge whether
the surface does the right job for the right admin-console operator (platform admin, support
investigator, org admin). Those lenses read DOM structure, IA hierarchy, and JTBD fitness.

This lens is a **perceptual / visual-quality lens** — it judges the RENDERED PNGs (committed
evidence bundles from `admin-eval-harness.sh`). It asks whether the rendered output _looks_ right
to the human eye: salience, emphasis semantics, and compositional coherence across light and dark
themes.

| Instrument | Judges | Evidence input | Output class prefix |
|------------|--------|----------------|---------------------|
| `admin-persona-jtbd-rubric.md` | UX fitness-for-purpose | DOM excerpt + facts.json | `platform_admin:`, `support_investigator:`, `org_admin:` |
| this file | Perceptual visual quality | `screenshot.png` (light + dark) + DOM for anchoring only | `graphic_design:` |

**Deterministic probes take precedence.** This lens owns ONLY the perceptual half of each
question — the measurable / structural half is explicitly delegated to the probe or proxy that
owns it (see each question below). Where a deterministic probe fires, its verdict supersedes
this lens's judgment on that question's structural dimension.

---

## The Seven Named Sigra Pillars

Every finding from this lens must cite one of these named pillars. Generic design critique
("looks busy", "feels unbalanced") that does not map to a named pillar fails the forced-finding
floor.

| Pillar | Definition | Source citation |
|--------|------------|-----------------|
| hierarchy/salience | Primary actions and key status signals must dominate attention; secondary elements recede | `admin-ui-principles.md` §Information Architecture — "make the next action obvious" |
| restraint | Accent color and visual weight are spent only where they carry meaning | `admin-ui-principles.md` §Brand Application — "Ember accent is for … ownership-boundary emphasis. Do not use it for every heading or icon" |
| ember-as-boundary | Ember (`#c2410c` light / `#fdba74` dark) marks Sigra identity, primary actions, selected states, and ownership-boundary highlights — it is a semantic signal, not decoration | `brandbook/brand-book.md` §Color — "Ember is for Sigra identity, primary CTAs, selected states, and ownership-boundary highlights" |
| consistency | Same job → same component; identical patterns across sibling surfaces | `admin-ui-principles.md` §Design System — "Same job means same component" |
| typographic coherence | Type hierarchy is legible, unambiguous, and consistent with Space Grotesk weight conventions | `brandbook/brand-book.md` §Logo System — "wordmark is outlined from Space Grotesk v2.0 … wght=700" |
| dark/light emphasis parity | Emphasis signals (weight, color contrast, size) land with equal clarity in both light and dark themes; no emphasis that only works in one theme | `admin-ui-principles.md` §Theme And Motion — "Admin supports Light, Dark, and System" |
| composition/balance | Gestalt grouping, whitespace rhythm, and visual weight are distributed so the layout reads as an intentional whole | `admin-ui-principles.md` §Design System — "8px visual rhythm derived from the 4px token scale" |

---

## Verdict Scale

Identical to the persona rubric's 3-point scale.

| Verdict | Anchor | Worked example |
|---------|--------|----------------|
| `keep` | Element earns its place visually; no change warranted | Ember border on a selected nav item is semantically correct ember-as-boundary; hierarchy/salience pillar is satisfied |
| `tighten` | Visual problem exists but element has a purpose; edit, do not remove | An ember background chip on a secondary label — ember is present but the element is not a CTA or selection boundary; restraint pillar violated but the chip itself is useful |
| `kill` | Visual element actively harms perception; remove or replace | A full-bleed ember header on a list page where no ownership boundary exists; ember-as-boundary and restraint pillars both violated; the signal is noise |

**Disposition rollup rule (worst-verdict across ALL 4 lenses):** A `kill` from any lens — the
three persona lenses OR this graphic-design lens — is a `kill` for the element. A `tighten` and
no `kill` → `tighten`. All lenses `keep` → `keep`.

**Surface-level disposition:** Any `kill` element → `blocked`; any `tighten` and no `kill` →
`actionable`; all elements `keep` across all 4 lenses → `clean`. A `clean` disposition across
all 4 lenses qualifies the surface for the **A3 award** (extends `admin-fractal-scorecard.md`
D-17 / 216 award bands; A3 = all 4 lenses read `clean`).

---

## Three Refutation Questions

Each question is phrased as a **refutation prompt**. The reviewer starts by assuming something is
wrong and searches for evidence to support that assumption. Each question targets a perceptual
failure mode that no deterministic probe can own.

### Q1: `salience` — Does the eye land on the wrong thing first?

**`class = graphic_design:salience`**

**Named pillar:** hierarchy/salience

**Target failure mode:** Perceived first-fixation dominance of the wrong element — the eye
lands on a secondary or decorative element before the primary action or key status signal.

**Deferred to probe #9:** The above-fold geometry (element heights, viewport coverage) and
target-size measurements (touch target ≥ 44px) are owned by probe #9. This question picks up
probe #9's deferred salience call — the perceptual judgment of whether the primary action
_looks_ dominant on the rendered PNG, not whether it is geometrically above the fold.

**Refutation probe:** Name one element in this PNG that draws the eye MORE than the primary
action or the key status signal. If none, say so explicitly, including what you searched for.

**What counts as an answer:**

- A decorative graphic, illustration, or brand mark that outweighs the primary CTA in visual
  mass (size, contrast, saturation) on the rendered output
- A secondary navigation element or sibling surface link rendered at equivalent or greater
  weight than the primary content area
- A status indicator, badge, or chip that radiates more visual energy (ember use, high contrast)
  than the key decision-bearing element, inverting the salience hierarchy

**NONE path:** `NONE — searched for: <description of what was reviewed, e.g. "decorative
elements competing with the primary CTA" or "secondary status chips dominating the KPI strip">`

**Citation:** `admin-ui-principles.md` §Information Architecture — "make the next action
obvious; Overview pages explain where to go next"; `brandbook/brand-book.md` §Design Principles
— "Proof over mood: every visual claim should point back to a real capability"

---

### Q2: `emphasis_ember` — Is emphasis (especially ember) earning its meaning, or decorating?

**`class = graphic_design:emphasis_ember`**

**Named pillars:** restraint + ember-as-boundary

**Target failure mode:** Semantic drift of the ember accent — used decoratively where no
ownership boundary, primary action, or selection state exists; OR under-emphasis of
meaning-bearing elements that should carry ember or strong weight and do not.

**Brand-v2 ember values (cite these; ignore pre-v2 brand info):**
- Light theme: `#c2410c` (CSS token `--sigra-accent`)
- Dark theme: `#fdba74` (CSS token `--sigra-accent-strong` in dark mode)
- Space Grotesk weight conventions apply to wordmarks and display headings (wght=700)
- Core Rails visual identity: the rail-block mark + linked g-tail lockup

**Deferred to probe #4:** The structural allowlist of ember-bearing elements (which
`data-testid` / `sg-*` selectors are permitted to carry ember) is owned by probe #4's ember
structural allowlist. This question owns the perceptual half: whether a visible ember
application _reads_ as semantically meaningful on the rendered PNG (does it mark a boundary or
a primary action?), and whether meaning-bearing elements that should be emphasized are
visually undersold.

**Refutation probe:** Name one place in this PNG where ember is applied decoratively (not at an
ownership boundary, CTA, or selection state), OR name one meaning-bearing element that is
under-emphasized (should carry ember or heavier weight and does not). If neither, say so
explicitly, including what you searched for.

**What counts as an answer:**

- Ember background or border applied to a display heading, illustrative element, or ambient
  section divider that does not mark a selection, action, or ownership boundary
- Multiple unrelated elements in ember simultaneously, diluting the signal (restraint pillar
  violated)
- A primary CTA, selected nav item, or ownership-boundary component rendered in a neutral
  color when ember would clarify the semantic role
- Dark-theme rendering where `#fdba74` appears on a surface where it reads as decorative
  warmth rather than semantic ownership signal (light/dark parity failure)

**NONE path:** `NONE — searched for: <description, e.g. "decorative ember on section headings"
or "under-emphasized primary CTA on the dark-theme screenshot">`

**Citation:** `brandbook/brand-book.md` §Color — "Ember is for Sigra identity, primary CTAs,
selected states, and ownership-boundary highlights. Do not use accent color for every icon or
heading. Dark mode must use the lightened accent-strong token (#fdba74) for text on dark
ember-soft surfaces"; `admin-ui-principles.md` §Brand Application — "Ember accent is for Sigra
identity, primary actions, selected states, and ownership-boundary emphasis. Do not use it for
every heading or icon"

---

### Q3: `composition` — Does grouping / type hierarchy / balance read coherently in BOTH themes?

**`class = graphic_design:composition`**

**Named pillars:** consistency + typographic coherence + dark/light emphasis parity +
composition/balance

**Target failure mode:** Compositional breakdown — gestalt grouping that reads as unintentional,
type-hierarchy descent that is ambiguous or inverted, visual balance that tips uncomfortably, or
emphasis that works in one theme but not the other.

**Screenshot requirement:** This is the ONLY question that requires BOTH the light-theme AND the
dark-theme `screenshot.png` for the cell. Q3 must cite which theme(s) the finding was observed
on: `evidence_cell: light`, `evidence_cell: dark`, or `evidence_cell: both`.

**Deferred to probes / D-16 proxies:** Measured spacing values and rhythm (pixel distances,
padding ratios) are owned by the deterministic probes and D-16 spacing proxies. Contrast ratio
correctness is owned by the axe audit. This question owns the perceptual coherence judgment:
does the layout read as intentional and balanced, does the type hierarchy communicate descent
correctly, and does emphasis land equivalently in both themes?

**Deferred to probe #9 / probe #2:** Target-size geometry (above-fold) is probe #9. Explicit
misalignment pixel-diffs are probe #2. This lens only fires when no deterministic probe owns
the perceptual dimension.

**Refutation probe:** Name one place where gestalt grouping, type-hierarchy descent, or visual
balance breaks on the rendered PNGs — in either or both themes. If none, say so explicitly for
each theme, including what you searched for.

**What counts as an answer:**

- Elements that read as peers but are semantically subordinate/superordinate (type size or
  weight does not communicate the hierarchy)
- A layout that tips left/right or top/bottom such that the visual center of mass is far from
  the intended content center (composition/balance pillar)
- Type-hierarchy descent that reads in light but inverts or flattens in dark (dark/light
  emphasis parity pillar)
- Groupings that do not cohere (two related elements separated by unrelated elements; unrelated
  elements sharing a card boundary)
- Body text weight or size that reads as a heading, or a heading rendered at body weight,
  breaking the Space Grotesk typographic convention (typographic coherence pillar)

**NONE path:** `NONE — searched for: <description, e.g. "type-hierarchy inversion on the dark
screenshot" or "gestalt grouping failures between the stat strip and the task cards">`

**Citation:** `admin-ui-principles.md` §Design System — "8px visual rhythm derived from the
4px token scale; same job means same component"; §Theme And Motion — "Admin supports Light,
Dark, and System"; `brandbook/brand-book.md` §Layout — "8px visual rhythm; prefer full-width
bands and constrained inner content; docs and README surfaces should prioritize scanning over
drama"

---

## Adversarial Framing and Forced-Finding Floor

The following instruction applies to every graphic-design lens review. It is a standing
instruction and **must be followed verbatim**. Partial compliance invalidates the review.

> **Standing lens instruction:**
>
> For each question cell (`salience`, `emphasis_ember`, `composition`), find the **strongest
> case against this surface**. Do not anchor on what looks fine. Start by assuming something is
> wrong and search for evidence to support that assumption.
>
> A verdict of `keep` with zero findings is valid ONLY after you have:
> (a) actively tried to find a fault for this question, AND
> (b) stated what you searched for in the `NONE — searched for: <what>` token.
>
> **Forced-finding floor:** every question cell in the output holds either:
> - A cited element with a concrete structural anchor (`data-testid`, `sg-*` BEM class, `role`,
>   `aria-label`, semantic CSS class — from the canonicalized DOM, validated by
>   `evidence-anchor-check.mjs`), an `observation` (perceptual prose), and `evidence_cell`
>   (which PNG), OR
> - The literal token `NONE — searched for: <what>` where `<what>` is a specific description
>   of the hypothesis tested and found not to hold.
>
> A cell is **never** left blank. A cell is **never** filled with vague praise ("looks great",
> "balanced", "no issues") without the explicit `NONE — searched for:` token.
>
> Every finding must cite **both** a perceptual observation (prose) **and** a structural anchor
> (DOM selector). A finding that is all prose and no anchor is a vibe — it fails the
> forced-finding floor and must be replaced or promoted to a `NONE` token.
>
> Every finding must name the **Sigra pillar** it violates. A finding that does not name a
> pillar is generic AI design critique and fails the floor.

**Why adversarial framing?** The heuristic-evaluation and LLM-judge literature shows that
non-adversarial prompts produce rubber-stamped outputs at high rates. The forced-finding floor
and explicit `NONE — searched for:` token are the device that makes verdict distributions
low-variance across both human and LLM reviewers. The named-pillar requirement ensures the lens
speaks Sigra's language, not Nielsen boilerplate.

---

## Output Schema

Every graphic-design lens review produces output with this structure. The schema is a **parallel
sibling** to the persona-JTBD output schema — the `class` prefix distinguishes the two.

### YAML Frontmatter (machine-rollup-able)

```yaml
---
surface: <surface-id matching ledger row, e.g. "users-index-live">
lens: graphic_design
rubric_version: "1.0"
disposition: clean | actionable | blocked
verdicts:
  salience: keep | tighten | kill
  emphasis_ember: keep | tighten | kill
  composition: keep | tighten | kill
findings:
  - element: "<structural anchor: data-testid value, sg-* BEM class, role, or aria-label>"
    question: salience | emphasis_ember | composition
    pillar: "<named Sigra pillar from the Seven Named Sigra Pillars table>"
    observation: "<perceptual prose — what the eye sees, not a structural assertion>"
    anchor: "<DOM selector, validated by evidence-anchor-check.mjs>"
    evidence_cell: light | dark | both
    verdict: tighten | kill
    none_searched_for: null | "<description of hypothesis tested (only when verdict: keep)>"
---
```

**Frontmatter field rules:**

- `surface` — matches the row key in `admin-quality-ledger.md` exactly
- `lens` — static string `"graphic_design"`
- `rubric_version` — static string `"1.0"` until a breaking schema change is ratified
- `disposition` — computed from worst verdict across the three question cells: any `kill` →
  `blocked`; any `tighten` and no `kill` → `actionable`; all `keep` → `clean`
- `verdicts` — all three keys (`salience`, `emphasis_ember`, `composition`) present, never
  omitted
- `findings` — list of actionable rows; only non-`keep` verdicts generate a finding row. A
  `clean` disposition produces `findings: []`
- `none_searched_for` — required (non-null, non-empty) for every `keep` verdict cell; null for
  non-`keep` finding rows
- `pillar` — must be one of the seven named pillars from the table above; "other" is not valid

### Markdown Body (human-auditable refutation log)

The document body contains one section per question, in order:

1. `## Q1: Salience`
2. `## Q2: Emphasis Ember`
3. `## Q3: Composition`

Each section contains the refutation prose + finding or NONE token. The forced-finding floor
applies to the body: every section ends with either a cited finding (pillar + observation +
anchor + evidence_cell) or a `NONE — searched for:` token.

### Example per-question section structure

```markdown
## Q1: Salience

`class = graphic_design:salience` | Pillar: hierarchy/salience

[Finding or NONE token]

**Observation:** [perceptual prose]
**Anchor:** `[data-testid="..." or .sg-*]`
**Evidence cell:** [light | dark | both]
**Verdict:** [tighten | kill]
**Pillar violated:** hierarchy/salience
```

---

## `finding_id` Computation

The `finding_id` for graphic-design findings uses the same byte-identical formula as all other
findings in the harness:

```
finding_id = sha256(surface + "\0" + class + "\0" + anchor)
```

Where `class` is the full `graphic_design:<key>` string (e.g. `graphic_design:salience`).
This means graphic-design findings share a key space with probe findings and persona findings,
enabling `settled-findings.tsv` waivers and fix-queue entries to reference them by the same
`finding_id` without re-tooling.

---

## What This Lens Does NOT Own

The following dimensions are **deterministic** and are owned by dedicated probes or guards.
This lens must NOT re-score them, even if the PNG surfaces something that looks related.

| Dimension | Owner | Why this lens defers |
|-----------|-------|---------------------|
| Explicit misalignment (pixel delta > threshold) | Probe #2 | Measured by pixel diff; deterministic; not a perceptual call |
| Radius / shadow / control-height off-token | Probe #5 | Measured from computed CSS; deterministic |
| Focus-ring visibility | Probe #7 | Measured from rendered focus state; deterministic |
| Card-in-card nesting | Probe #8 | Detected from DOM structure; deterministic |
| Motion / transition violations | D-16 proxy | Measured from CSS properties; deterministic |
| Responsive reflow / overflow | Deterministic viewport probe | Measured at specified breakpoints |
| Above-fold geometry / target-size measurements | Probe #9 | Pixel and geometry measurements; deterministic (probe #9 defers salience judgment to Q1 of this lens) |
| Contrast ratio correctness | axe audit | WCAG 1.4.3 measured; deterministic |
| Measured spacing / padding values | D-16 proxies | Pixel measurements from computed styles |

**Summary:** If a dimension can be expressed as a threshold test on a measured value, it belongs
to a probe. This lens only fires where the judgment is irreducibly perceptual — where a
reviewer must look at a rendered PNG and make a call that no pixel measurement can fully
capture.

---

## A3 Award Extension

The **A3 award** is earned when a surface reads `clean` across all **four** lenses:

1. Platform admin lens (`admin-persona-jtbd-rubric.md`) → `clean`
2. Support investigator lens (`admin-persona-jtbd-rubric.md`) → `clean`
3. Org admin lens (`admin-persona-jtbd-rubric.md`) → `clean`
4. Graphic-design lens (this file) → `clean`

A3 extends the 216 award bands (A0/A1/A2/A3). The graphic-design lens is the gating fourth
lens for A3. An A2 surface (all deterministic probes `clean`) becomes A3 only after a panel run
with all four lenses returning `clean`.

A3 cannot be earned from the panel alone — the deterministic award band A2 is a prerequisite.
The panel proposes; the committed `admin-award-ledger.json` disposes.

---

## Relationship to Quality Ledger

### Column-4 integer prohibition

The quality ledger's `awk -F'|'` monotonic guard parses the tier value from column four of
every `| [a-z]`-prefixed table row using the pattern `tier ~ /^[012]$/`. Any bare integer (`keep`,
`tighten`, `kill`, `clean`, `actionable`, `blocked` are all safe). **This document must never
place a bare `0`, `1`, or `2` in the fourth pipe-delimited column of any markdown table.**

The tables in this document use string values (`keep`, `tighten`, `kill`, `clean`, `actionable`,
`blocked`, or descriptive non-integer strings) in every column. This is compliant with the
column-four integer prohibition.

### What feeds the ledger vs the panel

The quality ledger records **scorecard tier** (Tier 0/1/2) from deterministic scorecard
dimensions. The graphic-design panel records **perceptual disposition** (`keep/tighten/kill`)
from rendered-PNG evidence. Panel findings do NOT enter the deterministic `open_findings` count;
they live in a parallel `panel-findings.json` written beside `findings.json` in the gitignored
bundle directory.

### Cross-references

- `admin-persona-jtbd-rubric.md` — the sibling UX/operator lens instrument; same verdict scale,
  same forced-finding floor, same `NONE — searched for:` token
- `admin-fractal-scorecard.md` — D-17 award bands (A0/A1/A2); A3 is the extension added by
  this lens
- `admin-quality-ledger.md` — the monotonic guard; panel findings do NOT write to the ledger
- `guides/reference/admin-panel-verdicts.json` — the committed per-surface content-hash skip
  cache for the graphic-design panel
- `scripts/ci/panel-forced-floor-check.mjs` — the guard that validates the `graphic_design:*`
  cells are complete, anchors resolve, and NONE tokens are non-empty
- `scripts/ci/evidence-anchor-check.mjs` — the `isStructuralAnchor` check used to validate
  every cited anchor before hashing the `finding_id`
- `brandbook/brand-book.md` + `brandbook/tokens.css` — brand-v2 token source of truth (ember
  `#c2410c` light / `#fdba74` dark; Space Grotesk; Core Rails)
- `guides/reference/admin-ui-principles.md` — the admin-specific application rules this lens
  enforces perceptually

---

Cross-reference: `admin-persona-jtbd-rubric.md`, `admin-fractal-scorecard.md`,
`admin-quality-ledger.md`, `brandbook/brand-book.md`
