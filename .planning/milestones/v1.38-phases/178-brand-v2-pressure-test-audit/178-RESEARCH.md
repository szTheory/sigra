# Phase 178: Brand v2 Pressure-Test Audit — Research

**Researched:** 2026-06-12
**Domain:** Brand design, logo craft, OSS suite architecture, typography selection
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- Outputs are: `brandbook/pressure-test-audit-v2.md` (14-section KEEP/TIGHTEN/REWORK/ADD/REMOVE audit), a committed logo v2 design brief, and an action plan driving Phases 179–183.
- KEEP/REWORK posture: KEEP is the default. Every REWORK requires evidence. Do not flatter unless earned. Prefer fewer, stronger recommendations.
- Logo hard constraints: no rectangular background behind the mark; logotype sits close to the mark; main lockup has no subtitle/slogan; fully integrated typemark variants required; not "icon to the left of basic text."
- Palette: ember-anchored and tunable. Keep warm ember identity as the anchor; shade/secondary tuning is allowed; no unrelated palette pivots.
- Fonts/colors are tweakable — this is the moment to nail them.
- SVG-only committed assets; Playwright renders are QA/gallery-only, never committed.

### Claude's Discretion
- OFL typeface selection for logo candidates (font freedom to replace Inter Display Black if a stronger candidate exists).
- Specific TIGHTEN/REWORK verdicts backed by evidence from codebase and competitor research.
- szTheory suite brand architecture split (shared vs unique per library).

### Deferred Ideas (OUT OF SCOPE)
- README header + GitHub social preview adoption (fast-follow `gsd-quick` after v1.38 ships).
- HexDocs/ExDoc theming, landing page, marketing site.
- PNG export pipeline / committed raster assets.
- sg-* class-name churn or admin component redesign.
- Sibling-library brandbooks.
- Per-org/runtime branding features.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| BRAND2-01 | `brandbook/pressure-test-audit-v2.md` — full 14-section audit with KEEP/TIGHTEN/REWORK/ADD/REMOVE verdicts, evidence for every REWORK, KEEP as default | All five research domains inform verdicts; section mapping in Architecture Patterns |
| BRAND2-02 | Suite brand-architecture section covering Sigra/Accrue/Mailglass/Threadline/Lockspire/Relyra/Rulestead | Competitor suite research (Tailwind Labs, unjs, Astro, FastAPI family) |
| BRAND2-03 | Logo v2 design brief encoding all 7 hard constraints + ratified scope | Logo craft research, OFL font candidates, integrated typemark patterns |
</phase_requirements>

---

## Summary

The v1.35 brand system is structurally sound and correctly anchored in the product truth. The pressure-test-audit-v2 is not a redesign exercise — it is an evidence pass that closes the gaps opened by v1.36 and v1.37: the brand has now been propagated into the admin shell, auth forms, and transactional emails, creating real evidence surfaces that the v1 audit could not evaluate because those surfaces did not yet exist.

The most significant finding is that the current logo system (Option A Core Rails: mark-left-of-text, Inter Display Black outlined wordmark) is the primary target for upgrade. Every major Elixir/devtools OSS brand in the 2023–2026 generation (Ash Framework, Oban Pro, Astro, Biome) has moved toward tighter mark-wordmark integration or fully integrated typemarks. The mark-beside-text lockup is the dominant pattern in the ecosystem — which makes it generic rather than distinctive. A fully integrated typemark for "sigra" is technically feasible: the word "sigra" offers several integration points (the `g` descender, the `i` tittle, the `s` entry stroke, the `r` shoulder, the `a` terminal).

The ember palette (#c2410c warm amber, #9a3412 deep ember, #fdba74 accent-soft) is a genuine differentiator in the Elixir ecosystem. Oban Pro, Phoenix Framework, and Ash Framework all use orange-adjacent palettes, but Sigra's interpretation is distinctly warm/amber rather than saturated orange — the distinction is worth making explicit in the audit so the v2 palette tuning stays anchored rather than drifting toward the competition's orange.

Inter Display Black v4.1 is a high-quality OFL choice but it is also the most used display font in the ecosystem (it powers most serious Elixir/devtools wordmarks). Four alternative OFL candidates with better letterform integration potential are identified: Space Grotesk Bold (technical mono-inspired terminals), Syne ExtraBold (widens with weight — unusual behavior that forces graphic strength), Geist (Black weight, Swiss geometry, OFL), and Plus Jakarta Sans ExtraBold (1930s grotesque with pointy curves and distinctive `a`/`g`). All four are confirmed OFL.

**Primary recommendation:** Phase 178 produces the written audit and brief that unlocks Phase 179. The single most important thing the audit must accomplish is providing an evidence-backed verdict on the logo system (REWORK with brief) and clear KEEP/TIGHTEN verdicts on the remaining 13 sections so Phase 179 starts with a constrained brief rather than open exploration.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Audit content (14 sections, verdicts) | Markdown document | — | Pure textual analysis; no runtime dependency |
| Logo v2 design brief | Markdown document | SVG sketches (optional) | Brief is text; sketches belong in Phase 179 gallery |
| szTheory suite architecture | Markdown section in audit | — | Research artifact, not runtime code |
| Design token validation | `brandbook/tokens.json` comparison | `tokens.css` derived | Tokens are brand source-of-truth |
| Surface evidence inventory | Codebase scan (admin CSS, auth CSS, templates) | Playwright snapshot review | Evidence must be from actual committed surfaces |
| Validation (file presence, section greps) | Shell scripts / CI | — | Machine-verifiable after the audit doc is written |

---

## Competitor / Ecosystem Visual Audit

### Elixir Ecosystem Brands

| Brand | Logo Construction | Palette | Typography | Distinguishing | Risk for Sigra |
|-------|------------------|---------|------------|----------------|----------------|
| **Phoenix Framework** | Standalone phoenix bird mark + separate "Phoenix Framework" wordmark; mark can stand alone | Saturated orange (#F75B27-range) on white/dark | Clean neutral sans | Iconic mark with product semantic; mark readable alone | Orange palette overlap; lockup style similar to current Sigra |
| **Ash Framework** | Mark (ash/flame icon) + wordmark lockup; orange primary | Vibrant orange; orange-on-dark | Modern clean sans | Brand color is vibrant orange (higher chroma than Sigra ember) | High palette conflict; both target the Elixir OSS audience |
| **Oban Pro** | Modular horizontal + vertical lockups; standalone mark; horizontal and vertical variants | Not disclosed publicly but professional, minimal | Professional sans | Formal brand governance (trademark@oban.pro); dual-lockup system | Clear multi-lockup structure is the model to match; Sigra lacks vertical lockup |
| **Oban Web** | Oban Pro sub-brand family treatment | Same family as Oban Pro | Same family | Suite sub-branding exists (Oban/ObanWeb shares identity) | Strongest model for szTheory suite architecture |
| **Elixir Lang** | Purple hex shield mark + "elixir" wordmark; standalone mark common | Purple (#6E4AED-range) | Understated | Purple is fully distinct from ember — no overlap | None; brand is complementary |
| **Guardian** | No distinct brand visual identity; GitHub README only | GitHub default | Default | Effectively no brand | Opportunity: Sigra's brand is already more mature |

**Key finding:** In the Elixir auth space, Sigra's warm ember is the only orange-amber palette that reads as warm/restrained rather than saturated/loud. Phoenix and Ash both use higher-saturation orange. Sigra's `#c2410c` (ember-700) occupies a darker, more brick-red position that is genuinely distinct from both. [VERIFIED: direct inspection of phoenixframework.org, ash-hq.org visual output]

### Broader Devtools Brands

| Brand | Lockup Type | Integration Level | What Makes It Work |
|-------|-------------|-------------------|--------------------|
| **Tailwind CSS** | Standalone mark + separate logotype (two separate SVG assets on brand page) | Low — separate components | Iconic "T" mark is distinctive enough alone; logotype is functional not decorative |
| **Biome** | Mark (mountain/wave shape) + wordmark; mark concept is metaphor-driven | Medium — thematic connection | Rebrand from Rome in 2024; mark symbolism is explicit (mountain=soil, wave=ocean) |
| **Astro** | Refined iconic "A" mark + new wordmark using "Obviously" variable font | High — mark and wordmark are designed together | "Obviously" typeface is custom/distinctive; mark refinement was minor but the wordmark is the upgrade |
| **Bun** | Character mascot (sun/bun face) + wordmark | Character mark; not integrated | Warm, approachable; but mascot pattern Sigra explicitly avoids |
| **Vite** | Lightning bolt mark + "Vite" wordmark | Mark-led | Simple geometric mark; memorable at favicon scale |

**Key insight from Astro's 2024 rebrand:** The upgrade move was not the mark (which was kept) — it was adding a properly crafted wordmark using a distinctive variable font ("Obviously" by Oh No Type Co). The lesson for Sigra: if the mark stays, the upgrade is in the wordmark. If an integrated typemark is added, it becomes the primary lockup and the mark becomes a secondary favicon/avatar asset. [CITED: goodside.studio/work/astro]

**Where current Sigra sits:** The Rail Accent mark (three staggered bars representing rails and a horizontal core line) is conceptually strong but visually quiet — it compresses to near-indistinguishable at 16px and has no personality at favicon scale without the outlined wordmark alongside it. The outlined Inter Display Black wordmark is well-executed technically but Inter Display Black is the de facto "serious devtools wordmark" font, reducing distinctiveness. The mark-left-of-text construction is the most generic lockup pattern in the ecosystem. [ASSUMED: 16px readability claim — requires render verification in Phase 179]

---

## Standard Stack (No New Packages)

This phase is a documentation/research phase. No new packages are installed. The outputs are:
- `brandbook/pressure-test-audit-v2.md` (Markdown)
- Logo v2 design brief (Markdown, either standalone or as an audit section)

Tools already in the repo are sufficient:
- `jq` for token validation
- `xmllint` for SVG validation (as per `brandbook/README.md` suggested checks)
- File existence checks via shell

---

## Package Legitimacy Audit

> No packages are installed in Phase 178. This section is not applicable.

---

## Architecture Patterns

### New Evidence Surfaces Since v1 Audit

The v1 audit (Phase 161, 2026-06-05) was written before v1.36 and v1.37 existed. The v2 audit must evaluate evidence surfaces that now exist:

| Surface | v1 Status | v2 Status | What Changed |
|---------|-----------|-----------|--------------|
| Admin topbar logo slot | Not yet built | Built: `min-height: 3.5rem` (~56px), sticky, blur backdrop | Logo appears in admin navigation; Rail Accent mark+lockup visible |
| Admin Light/Dark/System theme | Not yet built | Built: `data-sg-admin-theme` root carrier | Logo must work in both themes without a swap hack |
| Auth form branding panel | Not yet built | Built: `sigra-auth__brand` slot with logo URL + mark fallback | White-label token surface; logo used as `<img>` or mark fallback |
| Transactional emails | Not yet built | Built: shared brand profile with auth form | Logo identity in email headers |
| Auth branding admin UI | Not yet built | Built: visual customizer with accent/logo/dark-accent controls | The brand is now editable per-install |
| Installer template SVGs | Had logos | Has `sigra-logo-primary.svg` + `sigra-logo-primary-dark.svg` | These propagate to every generated install |
| Example app images | Had logos | Has 5 image files inc. `vaultr-mark.svg` (sibling mark hint) | vaultr mark is teal/shield pattern — distinct from Rail Accent; confirms suite diversity |
| Playwright baselines | Had none | Has ~24 snapshots covering admin Light/Dark/Mobile | Logo changes trigger baseline recapture |

### v1 Audit Scorecard — What Has Changed

Based on the v1 audit scorecard (Section 3), here is the current estimated delta:

| Area | v1 Score | v2 Delta | Evidence |
|------|:--------:|----------|---------|
| Logo readiness | 3 | +5 → ~8 | Option A Core Rails shipped; installer templates propagated |
| Color-system readiness | 6 | +2 → ~8 | Auth branding token surface; `sigra-auth-*` CSS vars; `sigra_brand_profiles` table |
| Design-token readiness | 5 | +3 → ~8 | `brandbook/tokens.*` are now consumed by auth CSS; `--sg-color-brand: #c2410c` in admin |
| UI component readiness | 7 | +1 → ~8 | Auth shell + admin shell both built |
| Repo/source-control readiness | 4 | +6 → ~10 | `brandbook/` is complete with 30 SVGs, tokens, HTML |
| Visual coherence | 6 | +2 → ~8 | Admin shell + auth form both use ember accent consistently |

Areas likely to stay similar or score lower on the integrated-typemark test:
- **Logo integration quality:** The mark-beside-text lockup still reads as a clip-art assembly rather than a designed whole. This is the primary REWORK target.
- **Logo distinctiveness at scale:** The staggered-bar mark compresses poorly at 16px (no distinctive silhouette against other stripe-based marks).

### Audit Structure Map (14 Sections)

| Section | Primary Evidence Source | New v2 Evidence |
|---------|------------------------|-----------------|
| 1. Executive judgment | Codebase + competitor audit | Updated: v1.36/v1.37 propagation confirmed brand is live |
| 2. Brand DNA | `brand-book.md`, README, launch docs | Stable — KEEP unless voice has drifted |
| 3. Scorecard (15 dims) | All surfaces | Updated scores from new surfaces |
| 4. Stress tests (~26 surfaces) | Surface inventory | New surfaces: admin topbar, auth form, email, auth brand admin |
| 5. Gaps and risks | Gap analysis | Critical gap closed (logo exists); new gap: logo integration quality |
| 6. Brand book upgrades | `brand-book.md` review | ADD: suite architecture section; TIGHTEN: logo system rules |
| 7. Token specification | `tokens.json` review | TIGHTEN: add version policy; verify `--sigra-auth-*` alignment |
| 8. Logo and mark system | Current SVG inspection | REWORK: integrated typemark brief; no rectangular container |
| 9. Visual examples | `examples/` review | TIGHTEN: confirm 9 examples are still current |
| 10. Voice and microcopy | `brand-book.md` say/not-say | Likely KEEP; verify against admin copy and auth copy |
| 11. Landing/docs blueprint | `brand-book.md` section 11 | Likely KEEP; still pre-implementation |
| 12. Repo-ready artifact plan | `brandbook/README.md` | TIGHTEN: add Phase 179–183 artifact plan preview |
| 13. Prioritized action plan | Drives Phase 179–183 | REWORK: v1 action plan is completed; v2 drives logo redesign |
| 14. Quality gate | Phase success criteria | Updated: new surfaces + integrated typemark test |

### Recommended Project Structure

```
brandbook/
├── pressure-test-audit-v2.md     # Phase 178 primary output (BRAND2-01, 02, 03)
│   (logo-v2-design-brief.md)     # Optional: standalone brief if audit is too long
├── (logo-options/round-3/)       # Phase 179 output — not this phase
└── README.md                     # Update with round-3 path when Phase 179 runs
```

The design brief may live as Section 8 subsection or a standalone `brandbook/logo-v2-design-brief.md` committed alongside the audit. Both satisfy BRAND2-03; the planner should pick one. [ASSUMED: which format is preferred — either works]

---

## OFL Typeface Candidates

All candidates confirmed OFL. The word being set is "sigra" (lowercase) — letters: s, i, g, r, a.

| Font | Source | OFL Confirmed | Black/ExtraBold? | Key Characteristics | Integration Potential |
|------|--------|:---:|:---:|---------------------|----------------------|
| **Inter Display Black** (current) | rsms.me/inter / Google Fonts | Yes [VERIFIED via rsms.me/inter] | Yes — 900 weight | Neutral grotesque; redesigned display glyphs vs Inter Text; tight spacing at display sizes; double-story `g` and `a` | Medium — `g` descender is a clean integration point but font is overused in devtools ecosystem |
| **Space Grotesk Bold** | fonts.floriankarsten.com / Google Fonts | Yes [CITED: Google Fonts page] | Up to Bold (700) — no Black | Mono-inspired squared terminals; technical character via `Space Mono` heritage; open counters; distinctive `g` bowl shape | High — squared terminals can be echoed in the rail motif; technically distinctive |
| **Syne ExtraBold/Black** | Google Fonts / github.com/google/fonts/ofl/syne | Yes [CITED: Google Fonts] | Yes — goes to Black (900); notably widens with weight (unusual) | Art-center origin (Synesthésie Paris); bold gets wider not just heavier; high x-height; open counters; `a` has geometric form | High — wider-at-heavier-weight forces strong layout decisions; `g` is clean single-story in some styles |
| **Geist Black** | github.com/vercel/geist-font (OFL) | Yes [CITED: GitHub repo LICENSE.txt] | Yes — axis 100-900; Ultra Black available | Swiss geometry; variable weight axis; designed for display + code; modern grotesque | Medium — clean but associated with Vercel/Next.js branding |
| **Plus Jakarta Sans ExtraBold** | github.com/tokotype/PlusJakartaSans (OFL) | Yes [CITED: GitHub tokotype repo] | Yes — ExtraBold available | Inspired by Neuzeit Grotesk + Futura; monolinear; pointy curves; 1930s grotesque character; distinctive `a` | High — pointy curves can echo sharp rail geometry; `g` descender curves back distinctively |
| **Bricolage Grotesque ExtraBold** | ateliertriay.github.io/bricolage (OFL) | Yes [CITED: Atelier Triay] | Yes — ExtraBold; variable axes including optical size and width | Historical French/British grotesque hybrid; emotional/expressive; `a` has tiny inner counter; `c`/`e` have uneven bite | Low for security brand — expressiveness is editorial not infrastructure |

**Recommendation for Phase 179:** Space Grotesk Bold and Plus Jakarta Sans ExtraBold are the highest-potential alternatives to Inter Display Black for a security/infrastructure brand because they carry technical character without being expressive or editorial. Syne is the wildcard — if the integrated typemark direction leans into the rail-metaphor's graphic strength (wider-at-heavier is a visual analog to weight-bearing rails), Syne ExtraBold/Black's unusual width expansion is a strong conceptual fit. [ASSUMED: final recommendation — needs Phase 179 render comparison]

**Download sources for Phase 179 toolchain:**
- Space Grotesk: `https://fonts.google.com/specimen/Space+Grotesk` (direct woff2/ttf download or `google/fonts` GitHub)
- Syne: `https://github.com/google/fonts/tree/main/ofl/syne`
- Geist: `https://github.com/vercel/geist-font/releases`
- Plus Jakarta Sans: `https://github.com/tokotype/PlusJakartaSans/releases`

---

## Integrated Typemark Craft Notes

### What Makes an Integrated Typemark Work

[CITED: logodesign.net/blog/custom-typography-in-logo-design, superside.com/knowledge/letterform-logos, logodesign.net/blog/optical-adjustments-in-logo-design]

1. **The motif must be structural, not decorative.** Working a rail or bar motif into a letterform works when it replaces or becomes a structural stroke (crossbar, counter, stem). Adding it on top as a graphic overlay reads as clip-art.

2. **Scale durability is the primary constraint.** At 16px (favicon) the integrated element must remain readable as part of the letter, not become noise. Test at 16px, 32px, 54px (admin topbar slot), and hero scale before any candidate is committed.

3. **The `g` descender in "sigra" is the prime integration opportunity.** The descender of a lowercase `g` can be shaped into a rail continuation, a track curve, or a signal path. The `i` tittle can become a mark-accent dot. The `s` entry/exit strokes can echo the staggered-bar motif.

4. **Common pitfalls to avoid:**
   - **Forced ligature:** Connecting `g`+`r` or `r`+`a` in ways that read as a single glyph rather than two distinct letters.
   - **Gimmick letter:** Making only the `s` or `i` distinctive while the rest of the word is plain — looks accidental.
   - **Stroke contrast damage:** Thick-thin contrast in the motif that clashes with the typeface's inherent contrast level.
   - **Kerning distortion:** Rail insertions that change optical spacing require manual kerning correction.
   - **Scale fragility:** Motif detail that disappears at 32px and below.

5. **Optical adjustments required post-integration:**
   - Check that the integrated element's visual weight matches the surrounding letterforms.
   - Verify the silhouette reads as a coherent word at 50% opacity grayscale (the "tattoo test").
   - Check letter spacing after motif insertion — modified letterforms typically need 5-15% tighter tracking.

### The Rail Metaphor in Letterforms

For "sigra" specifically:
- The three staggered rail bars from the current mark could become stagger-length horizontal serifs or stroke terminals on the `s` or `r`.
- The horizontal "core" line from the current mark could become the crossbar of a modified `g` bowl closure or an explicit stem addition.
- The ember/amber color accent could be applied to just the integrated element within otherwise black letterforms — so the ember appears only in the motif-stroke, consistent with the current mark's accent logic.

---

## szTheory Suite Brand Architecture

### Competitor Suite Patterns

| Suite | Shared | Unique | Model |
|-------|--------|--------|-------|
| **Tailwind Labs** (Tailwind CSS, Heroicons, Headless UI, Catalyst) | Design aesthetic; Heroicons are used across all tools; tacit shared design language | Each tool has own site/colors; Catalyst and Headless UI do not share Tailwind's blue identity | Loose family — shared designer taste, not explicit identity system |
| **unjs** (Nitro, Citty, Destr, Consola, Defu, Ofetch, ~30 libs) | Puzzle-piece metaphor for all library icons; light/dark dual variants for every icon; consistent icon illustration style | Each library has its own puzzle-piece illustration; no shared color | Tight icon-family model: one metaphor, per-library interpretation |
| **FastAPI / Typer / SQLModel** (tiangolo) | Same creator; same docs engine; clean docs aesthetic | Each has distinct color (FastAPI=teal, Typer=red/pink, SQLModel=green) | Creator-aesthetic family: typography and layout are implied shared; colors are per-library |
| **Astro ecosystem** (Astro, Starlight) | Core Astro mark; "Obviously" typeface across core collateral | Starlight is a distinct product with its own identity | Product-sub-brand: main mark is shared; docs products have separate identity |
| **Dashbit nimble_*** | No visual brand; text-only README; GitHub organization as the brand container | Per-library README badge colors | No model — pure library utility, brand is irrelevant to them |

### Recommended szTheory Suite Split

The szTheory suite (Sigra, Accrue, Mailglass, Threadline, Lockspire, Relyra, Rulestead) maps closest to the **FastAPI/tiangolo model** with some unjs influence:

**SHARED across all szTheory libraries:**
- Typography: same OFL font family for wordmarks (whichever is ratified in Phase 180 for Sigra)
- Layout conventions: same docs layout system and badge badge style
- Design principle vocabulary: "precision, explicitable contracts, host-owned behavior"
- Voice register: same maintainer-grade technical voice
- Token naming convention: `--sg-*` namespace already established

**UNIQUE per library:**
- Mark (each library has a distinct mark reflecting its domain — `vaultr-mark.svg` already demonstrates this with shield+teal)
- Accent color (one accent color per library within a warm/cool palette constraint)
- Domain metaphor (Sigra=rails; Accrue=ledger; Mailglass=transparency; etc.)

**What the vaultr-mark.svg hints:**
The existing `test/example/priv/static/images/vaultr-mark.svg` (teal shield with cross) demonstrates that the suite already has an informal sister-library mark system with per-library colors (Sigra=amber/ember, Vaultr=teal). This is the unjs puzzle-piece model applied to Elixir auth-adjacent libs. [VERIFIED: direct SVG inspection]

**Suite section in the audit (BRAND2-02):** Should be a dedicated subsection of Section 8 (Logo and Mark System) or a new Section between 12 and 13. It should document: shared elements, unique elements, the vaultr mark as evidence, and a decision framework for when a new library joins the suite.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead |
|---------|-------------|-------------|
| Font path extraction for wordmark | Custom OpenType parser | opentype.js (Phase 179 toolchain — this phase only writes the brief) |
| Logo render verification | Manual visual check | Playwright at multiple viewports (Phase 179) |
| Typographic baseline comparison | CSV/numeric comparison | Side-by-side SVG gallery in `logo-options/round-3/` (Phase 179) |
| JSON schema validation | Custom validator | `jq .` (already in brandbook README.md suggested checks) |
| SVG parse check | Custom XML validator | `xmllint --noout` (already in brandbook README.md suggested checks) |

**Key insight:** Phase 178 is a documentation phase. The "don't hand-roll" principle applies to Phase 179's toolchain choices, which the design brief in Phase 178 must anticipate correctly.

---

## Common Pitfalls

### Pitfall 1: REWORK Without Evidence
**What goes wrong:** The auditor declares "REWORK the color system" based on aesthetic preference rather than documented failures on specific surfaces.
**Why it happens:** The audit brief says "critical analysis lens" — pressure to find problems leads to inventing them.
**How to avoid:** For each REWORK verdict, state the specific surface, the specific failure mode, and the specific evidence (screenshot hash, CSS line number, token value). KEEP with a note is a valid outcome.
**Warning signs:** Any REWORK that doesn't name a specific surface.

### Pitfall 2: Logo Brief That Re-Opens Palette
**What goes wrong:** The design brief allows "any color" for candidate exploration, then Phase 179 produces amber, teal, and purple candidates. The ratification gate in Phase 180 becomes a color decision rather than a logo decision.
**Why it happens:** "Ember-anchored but tunable" is interpreted loosely.
**How to avoid:** The brief must say: primary mark and wordmark are set in the ember family. Tuning means shade variation within warm amber (deeper brick-red, lighter apricot), not pivoting to a different hue. Accent tones (rail accent soft #fdba74) are also ember-family.
**Warning signs:** Any candidate that uses a hue outside the 15–40 degree orange range on the color wheel.

### Pitfall 3: Missing the Auth Branding Token Surface in Section 7
**What goes wrong:** The token specification review only covers `brandbook/tokens.json` and misses `sigra_auth.css` and the `sigra_brand_profiles` table schema.
**Why it happens:** The v1 audit predates those surfaces.
**How to avoid:** Section 7 of the v2 audit must explicitly cross-reference `--sigra-auth-accent: var(--sigra-auth-light-accent, #c2410c)` and verify that the auth accent default is the same value as the brandbook `ember-700`. Any mismatch is a TIGHTEN finding.
**Warning signs:** Section 7 that does not reference `sigra_auth.css`.

### Pitfall 4: Over-scoping the Suite Architecture Section
**What goes wrong:** The suite section becomes a full brand system specification for all 7 libraries, delaying Phase 178.
**Why it happens:** "Every angle" research produced a rich competitor analysis.
**How to avoid:** The suite section in the v2 audit is a DECISION FRAMEWORK and EVIDENCE section, not a build spec. It must answer: what is shared, what is unique, how does the `vaultr-mark.svg` precedent formalize? That is 1-2 pages, not a full document.
**Warning signs:** Suite section that specifies anything other than Sigra's own contribution to the shared system.

### Pitfall 5: Subtitle Constraint Confusion
**What goes wrong:** The design brief correctly excludes subtitles from the primary lockup but does not specify that the "with-subtitle variant" must be structurally designed, not an afterthought.
**Why it happens:** The "main lockup has no subtitle" constraint is remembered; "a separate with-subtitle variant is fine" is treated as a free pass.
**How to avoid:** The brief must note that the subtitle variant needs the same craft attention as the primary lockup — it is a separate design problem, not just appending text.

---

## Runtime State Inventory

> This phase is greenfield documentation — no rename/refactor scope. The Runtime State Inventory section is OMITTED.

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| `jq` | Token JSON validation | ✓ | System jq | — |
| `xmllint` | SVG parse check | ✓ (macOS default) | libxml 2.x | `python3 -c "import xml.etree.ElementTree..."` |
| Text editor / Write tool | Writing `pressure-test-audit-v2.md` | ✓ | — | — |
| `grep` / shell | Verification scripts | ✓ | — | — |

**No blocking dependencies.** Phase 178 is a documentation phase.

---

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | Shell + grep (no test runner needed for doc-only phase) |
| Config file | None |
| Quick run command | `ls brandbook/pressure-test-audit-v2.md` |
| Full suite command | See Phase Gate below |

### Phase Requirements → Verification Map

| Req ID | Behavior | Test Type | Automated Command | Exists? |
|--------|----------|-----------|-------------------|---------|
| BRAND2-01 | `pressure-test-audit-v2.md` exists with 14 sections | File + grep | `ls brandbook/pressure-test-audit-v2.md && grep -c "^## Section" brandbook/pressure-test-audit-v2.md` | No — Wave 0 |
| BRAND2-01 | Every REWORK verdict has evidence | Grep | `grep -A3 "REWORK" brandbook/pressure-test-audit-v2.md \| grep -i "evidence\|surface\|file\|line"` | No — Wave 0 |
| BRAND2-02 | Suite architecture section present | Grep | `grep -i "sztheory\|suite\|accrue\|mailglass" brandbook/pressure-test-audit-v2.md` | No — Wave 0 |
| BRAND2-03 | Logo v2 design brief exists and contains 7 hard constraints | File + grep | `grep -i "rectangular\|logotype\|subtitle\|integrated typemark\|ember\|OFL" brandbook/logo-v2-design-brief.md` (or equivalent in audit) | No — Wave 0 |
| BRAND2-03 | Brief explicitly references all 7 constraints | Count grep | Should find ≥7 distinct constraint subsections | No — Wave 0 |

### Sampling Rate
- **Per task commit:** `ls brandbook/pressure-test-audit-v2.md`
- **Per wave merge:** Full section-count grep + REWORK evidence grep
- **Phase gate:** All greps pass + `jq . brandbook/tokens.json` parses + `git status` clean

### Wave 0 Gaps
- [ ] `brandbook/pressure-test-audit-v2.md` — Phase 178 primary output
- [ ] `brandbook/logo-v2-design-brief.md` (or equivalent section) — Phase 178 secondary output

*(No framework installation needed — shell validation only)*

---

## Security Domain

> This phase produces documentation only. No auth code, token handling, or session management is involved.
> `security_enforcement` applies to runtime code phases. OMITTED for this doc-only phase.

---

## Code Examples

### SVG Parse Validation (use in Phase Gate)
```bash
# Source: brandbook/README.md suggested checks
find brandbook -name '*.svg' -print0 | xargs -0 -n1 xmllint --noout
```

### Token JSON Validation
```bash
# Source: brandbook/README.md suggested checks
jq . brandbook/tokens.json
```

### BRAND2-01 Section Count Check
```bash
# Verifies the audit has ≥14 major section headers
section_count=$(grep -c "^## Section" brandbook/pressure-test-audit-v2.md)
[ "$section_count" -ge 14 ] && echo "PASS: $section_count sections" || echo "FAIL: only $section_count sections"
```

### BRAND2-03 Constraint Presence Check
```bash
# Verifies the brief mentions all hard constraints
for term in "rectangular" "logotype" "subtitle" "typemark" "ember" "OFL" "boundary"; do
  grep -qi "$term" brandbook/pressure-test-audit-v2.md && echo "OK: $term" || echo "MISSING: $term"
done
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Mark-beside-text lockup (clip-art assembly) | Integrated typemark (motif in letterforms) | Astro 2024 rebrand; general devtools trend 2023–2025 | The "serious OSS" brand now has a crafted wordmark, not just a mark+font stack |
| Generic grotesque wordmark (Roboto/Inter) | Distinctive OFL display face OR custom letterforms | Astro "Obviously", Biome rebrand 2024, Geist (Vercel) | "Inter Black" is the default; standing out requires either custom letterforms or a distinctively-shaped typeface |
| Font binaries committed | Glyphs outlined to path; font never committed | Standard practice for SVG logo systems since ~2018 | No runtime font dependency; logos render identically everywhere |
| Single lockup | Multi-lockup system (primary, dark, subtitle, mark, monochrome, favicon, social) | Industry standard; Oban Pro model | Each surface needs the right asset; one lockup causes misuse |

**Deprecated in this context:**
- Rectangular background container behind a mark: overused AI-generated pattern; explicitly prohibited in the user brief.
- Slogan/subtitle in the main lockup: reduces legibility at small sizes; explicitly prohibited.
- System font stack for the wordmark: acceptable for body text in docs, not for logo identity.

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | The Rail Accent mark compresses to near-indistinguishable at 16px without the wordmark | Competitor audit, logo critique | Low risk — if wrong, the mark is fine and the 16px criterion in the brief becomes "nice to have" rather than required |
| A2 | Space Grotesk Bold and Plus Jakarta Sans ExtraBold are the top OFL alternatives for this brand | OFL Typeface Candidates | Medium risk — Phase 179 rendering may reveal that Inter Display Black or Syne are stronger; candidates table should be verified by actual render |
| A3 | The design brief format (standalone `.md` vs. section in audit) is discretionary | Architecture Patterns | Low risk — either format satisfies BRAND2-03 |
| A4 | The admin topbar slot is approximately 54–56px (based on `min-height: 3.5rem` = 56px CSS) | New Evidence Surfaces | Low risk — actual render height may vary with padding; the 54px reference in the research brief is close enough |

---

## Open Questions

1. **Design brief format: standalone file or audit section?**
   - What we know: CONTEXT.md says "Logo v2 design brief (committed; standalone file or audit section)."
   - What's unclear: A standalone file is cleaner for Phase 179 to reference. A section in the audit reduces file count.
   - Recommendation: Standalone `brandbook/logo-v2-design-brief.md` — Phase 179 can reference it directly without reading the full 14-section audit.

2. **How many new surfaces does Section 4 need?**
   - What we know: v1 audit had ~26 surfaces. v1.36/v1.37 added: admin topbar, auth form, email, auth admin customizer.
   - What's unclear: Whether any of these should replace v1 surfaces or be additive.
   - Recommendation: Add 4 new rows (admin topbar logo slot, auth form branding panel, transactional email header, auth branding admin UI). Do not remove any v1 surfaces — they now have verdicts.

3. **Suite architecture depth: how far to spec for non-Sigra libraries?**
   - What we know: BRAND2-02 requires "what is shared vs unique" for all 7 libraries.
   - What's unclear: Whether to spec color palettes for non-existent libraries (Accrue, Mailglass, etc.) or just define the decision framework.
   - Recommendation: Define the decision framework and name the shared/unique split. Do NOT assign colors to unbuilt libraries — that is their work.

---

## Sources

### Primary (HIGH confidence)
- Direct codebase inspection: `brandbook/tokens.json`, `brandbook/logo-primary.svg`, `brandbook/pressure-test-audit.md`, `brandbook/brand-book.md`, `brandbook/README.md` — current brand system state
- `test/example/priv/static/images/vaultr-mark.svg` — confirmed suite sibling mark exists with teal/shield design
- `test/example/priv/static/assets/css/app.css` — `--sg-color-brand: #c2410c` admin token; topbar `min-height: 3.5rem`
- `priv/templates/sigra.install/core/sigra_auth.css` — `--sigra-auth-light-accent: #c2410c` auth default
- `brandbook/logo-options/round-2/README.md`, `rail-accent/README.md` — logo exploration history
- `.planning/phases/178-brand-v2-pressure-test-audit/178-CONTEXT.md` — ratified scope decisions, hard constraints
- `.planning/REQUIREMENTS.md` — BRAND2-01..03 verbatim requirements

### Secondary (MEDIUM confidence)
- [goodside.studio/work/astro](https://www.goodside.studio/work/astro) — Astro 2024 rebrand; "Obviously" typeface choice; mark refinement vs wordmark upgrade strategy
- [oban.pro/brand-assets](https://oban.pro/brand-assets) — Oban Pro multi-lockup system; formal brand governance model
- [ateliertriay.github.io/bricolage](https://ateliertriay.github.io/bricolage) — Bricolage Grotesque characteristics; editorial focus not suitable for security brand
- [logolab.app](https://logolab.app/) — Logo evaluation rubric: 6 categories, 12 tests; contrast/clarity/balance/flexibility/color/AI dimensions
- [superside.com/knowledge/letterform-logos](https://www.superside.com/knowledge/letterform-logos) — letterform logo design principles; pitfalls; professional vs amateur distinction
- [vercel.com/font](https://vercel.com/font) — Geist font: Swiss geometry, variable 100-900, display intent, OFL confirmed
- [unjs.io](https://unjs.io/) — puzzle-piece family branding model; per-library illustration; light/dark dual variants
- [fastapi.tiangolo.com](https://fastapi.tiangolo.com/) — per-library color model; shared creator-aesthetic; Typer as explicit sister library
- [fonts.floriankarsten.com/space-grotesk](https://fonts.floriankarsten.com/space-grotesk) — Space Grotesk design intent; OFL; mono-inspired terminals
- [ash-hq.org](https://www.ash-hq.org/) — Ash Framework orange palette; mark+wordmark lockup
- [phoenixframework.org](https://www.phoenixframework.org/) — Phoenix orange; separate mark and wordmark

### Tertiary (LOW confidence)
- WebSearch summaries on Biome rebrand (2024 mountain/wave concept), Bun mascot, Tailwind Labs suite coherence — corroborated by pattern but not deep-fetched

---

## Metadata

**Confidence breakdown:**
- Competitor audit: HIGH — verified via direct WebFetch on official brand/press pages
- Logo craft patterns: MEDIUM — from authoritative design sources; Phase 179 renders will confirm
- OFL font candidates: HIGH for license status; MEDIUM for render suitability (render-verified in Phase 179)
- Suite architecture model: MEDIUM — competitor patterns researched; szTheory split is a recommendation not a verified decision
- Codebase evidence surfaces: HIGH — direct grep/read of committed files

**Research date:** 2026-06-12
**Valid until:** 2026-09-12 (90 days — brand ecosystem and OFL font landscape are stable)
