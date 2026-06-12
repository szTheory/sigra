# Sigra Logo v2 Design Brief

This brief encodes the hard constraints, ratified scope decisions, OFL typeface research, letterform anatomy, and candidate-direction guidance for Phase 179 logo exploration. It is derived from the pressure-test-audit-v2.md Section 8 REWORK verdict. Phase 179 reads this file as its primary input; no other pre-reading is required to begin candidate generation.

---

## Brief Provenance

The logo system REWORK verdict in `brandbook/pressure-test-audit-v2.md` Section 8 identified the primary failure mode — mark-beside-text is the generic lockup pattern in the Elixir ecosystem — and directed the creation of this brief. Evidence: `brandbook/logo-primary.svg` (mark-left-of-text construction), failure mode: generic lockup pattern identical to Phoenix/Ash/Oban Pro in the target developer audience's visual field; Phoenix Framework, Ash Framework, and Oban Pro all use mark-beside-text constructions. The audit's Section 13 action plan places Phase 179 exploration as the immediate next step. This brief commits the constraints so Phase 179 does not re-open scope.

---

## Hard Constraints (Non-Negotiable)

1. **No rectangular background behind the logomark.** The mark must work on transparent and colored surfaces without a rectangular or rounded-rectangle container behind it; boundary-breaking compositions are encouraged.

2. **Logotype sits appropriately close to the logomark.** In combination lockups, the wordmark is visually adjacent to the mark — not separated by whitespace that makes them feel like two independent elements.

3. **Primary lockup carries no subtitle or slogan.** The main combination lockup is mark+wordmark only. A separate with-subtitle variant is a required deliverable but is a distinct design problem requiring the same craft attention as the primary lockup — not an afterthought of appended text.

4. **Integrated typemark variants are required.** At least 2 of the 5–7 candidates must be fully integrated typemarks: the rail/brand motif is worked into the letterforms structurally (crossbar, counter, stroke terminal, descender) — not placed beside the type as a separate glyph.

5. **The primary lockup is not mark-beside-text.** The mark-left-of-logotype construction (Option A Core Rails) is the v1 reference baseline; it is archived, not built upon. Candidates that are mark-beside-text are acceptable as non-typemark options only if they demonstrate markedly better integration quality than v1.

6. **Font and color are tunable within the ember anchor.** The typeface may change from Inter Display Black if a stronger OFL candidate exists. Palette tuning means shade variation within the warm amber range (hue 15–40 degrees on the color wheel, from brick-red through amber to apricot). No candidate uses a hue outside this range. The ember-700 value (`#c2410c`) is the anchor; deep-ember (`#9a3412`) and accent-soft (`#fdba74`) are the tuning poles.

7. **Options must be shown for human selection at Phase 180.** No candidate is implicitly ratified. Phase 180 is the explicit human gate. Phase 179 commits gallery only; Phase 180 records the decision.

---

## Ratified Scope Decisions

| Decision | Answer |
| --- | --- |
| Palette freedom | Ember-anchored, tunable — warm ember (`#c2410c`) as anchor; shade/secondary tuning within hue 15–40 degree range; no unrelated palettes |
| README and social adoption | Deferred as a gsd-quick fast-follow after v1.38 ships |
| Committed asset format | SVG-only; Playwright renders are QA/gallery-only, not committed |

---

## Current Brand Anchor

The ember palette is a genuine differentiator in the Elixir ecosystem. Phoenix Framework and Ash Framework both use higher-chroma orange (#F75B27-range); Sigra's `ember-700` (`#c2410c`) occupies a distinctly darker, more brick-red position [CITED: 178-RESEARCH.md Competitor/Ecosystem Visual Audit]. This distinction is the palette identity to preserve and anchor Phase 179 candidate exploration. The deep-ember (`#9a3412`) and accent-soft (`#fdba74`) are tuning poles within the same warm family — Phase 179 candidates may shift between them but must not pivot to an unrelated hue.

**Ember token reference (from brandbook/tokens.json lines 18–21):**

| Token | Value | Role |
| --- | --- | --- |
| `ember-050` | `#fff0e8` | Lightest ember tint — background wash |
| `ember-300` | `#fdba74` | Accent soft — secondary/highlight |
| `ember-700` | `#c2410c` | Primary ember — anchor; canonical accent |
| `ember-800` | `#9a3412` | Deep ember — dark mode accent / tuning pole |

---

## OFL Typeface Candidates

The "sigra" wordmark is currently set in Inter Display Black v4.1 [VERIFIED: brandbook/logo-primary.svg]. Inter Display Black is an excellent OFL choice and remains the reference; however it is the de facto standard for Elixir devtools wordmarks, which reduces distinctiveness [CITED: 178-RESEARCH.md Competitor/Ecosystem Visual Audit]. Phase 179 must render at least Inter Display Black (reference) plus two strong alternatives.

| Font | Version | OFL Source | Download URL | Key Characteristics | Integration Potential |
| --- | --- | --- | --- | --- | --- |
| **Inter Display Black** (current) | v4.1 | rsms.me/inter / Google Fonts | https://rsms.me/inter/ | Neutral grotesque; redesigned display glyphs; tight spacing at display sizes; double-story `g` and `a` | Medium — `g` descender is a clean integration point but font is overused in devtools ecosystem |
| **Space Grotesk Bold** | — | fonts.floriankarsten.com / Google Fonts | https://fonts.google.com/specimen/Space+Grotesk | Mono-inspired squared terminals; technical character via Space Mono heritage; open counters; distinctive `g` bowl shape | High — squared terminals can be echoed in the rail motif; technically distinctive |
| **Syne ExtraBold/Black** | — | Google Fonts / github.com/google/fonts | https://github.com/google/fonts/tree/main/ofl/syne | Art-center origin (Synesthésie Paris); widens with weight (unusual); high x-height; open counters; geometric `a` | High — wider-at-heavier-weight forces strong layout decisions; `g` is clean single-story; rail-width analog |
| **Geist Black** | — | github.com/vercel/geist-font (OFL) | https://github.com/vercel/geist-font/releases | Swiss geometry; variable weight axis (100–900); designed for display + code; modern grotesque | Medium — clean but associated with Vercel/Next.js branding; reduces distinctiveness in devtools context |
| **Plus Jakarta Sans ExtraBold** | — | github.com/tokotype/PlusJakartaSans (OFL) | https://github.com/tokotype/PlusJakartaSans/releases | Inspired by Neuzeit Grotesk + Futura; monolinear; pointy curves; 1930s grotesque character; distinctive `a` and `g` | High — pointy curves can echo sharp rail geometry; `g` descender curves back distinctively |
| **Bricolage Grotesque ExtraBold** | — | ateliertriay.github.io/bricolage (OFL) | https://ateliertriay.github.io/bricolage | Historical French/British grotesque hybrid; emotional/expressive; variable axes incl. optical size and width | Low — expressiveness is editorial not infrastructure; conflicts with security/infrastructure brand register |

**Candidate direction note:** Space Grotesk Bold and Plus Jakarta Sans ExtraBold are the highest-potential alternatives to Inter Display Black for a security/infrastructure brand — they carry technical character without being expressive or editorial. Syne is the wildcard: if the integrated typemark direction leans into the rail-metaphor's graphic strength (wider-at-heavier is a visual analog to weight-bearing rails), Syne ExtraBold/Black's unusual width expansion is a strong conceptual fit. Bricolage Grotesque is deprioritized — its editorial expressiveness conflicts with the security/infrastructure brand register. [ASSUMED: final recommendation — Phase 179 renders are the authority]

---

## Sigra Letterform Integration Anatomy

The word "sigra" (lowercase, 5 letters: s, i, g, r, a) offers four integration points for the rail metaphor.

**Four integration points:**

1. **g descender** — The prime integration opportunity. The descender of the `g` can be shaped into a rail continuation, a track curve, or a signal path. The `g` descender in all candidate fonts terminates freely below the baseline — this is the most structurally significant modification available in the wordmark.

2. **i tittle** — The dot above the `i` can become the ember accent dot. Applied as the only colored element in an otherwise black/monochrome wordmark, it echoes the current mark's accent logic and provides a color anchor without a separate mark element.

3. **s entry and exit strokes** — Can echo the staggered-bar rail motif from the Rail Accent mark by giving the `s` terminal strokes a flat, horizontal cut instead of an angled finish. This reinforces the motif structurally without requiring a separate glyph.

4. **r shoulder** — The arm of the `r` can terminate in a rail-bar geometry (flat-cut or bracketed) to reinforce the motif without disrupting readability. The shoulder is a secondary integration point — it should support points 1–3, not carry the motif alone.

### Integration Pitfalls to Avoid

- **Forced ligature** — Connecting `g`+`r` or `r`+`a` so they read as a single glyph rather than two distinct letters. This damages wordmark legibility at small sizes.
- **Gimmick letter** — Making only the `s` or `i` distinctive while the rest of the word is plain — looks accidental rather than designed.
- **Stroke contrast damage** — Thick-thin contrast in the motif that clashes with the typeface's inherent contrast level; the integrated element's weight must match surrounding strokes.
- **Kerning distortion** — Rail insertions that change optical spacing require manual kerning correction; failing to correct this reads as broken lettering.
- **Scale fragility** — Motif detail that disappears at 32px and below; all candidates must pass the 16/32/54px render gate before gallery presentation.

### Optical Adjustments Required Post-Integration

1. Check visual weight of the integrated element against surrounding letterforms — the motif must not be heavier or lighter than the typeface's native stroke weight.
2. Verify the silhouette reads as a coherent word at 50% opacity grayscale (the "tattoo test") — if the word is not readable in silhouette, the integration has damaged legibility.
3. Check letter spacing after motif insertion — modified letterforms typically need 5–15% tighter tracking.

---

## Render-Critique Rubric

| Test | Pass Condition | Scale to Apply |
| --- | --- | --- |
| Wordmark legibility | "sigra" is readable as five distinct letters | 16px, 32px, 54px, hero |
| Integration coherence | Motif reads as structural part of the letterform, not a decorative overlay | 32px and hero |
| Ecosystem distinctiveness | Silhouette does not resemble Phoenix, Ash, Oban Pro, or Elixir Lang at glance distance | Hero |
| Ember anchor | Dominant hue falls within hue 15–40 degree warm amber range | Hero and social card |
| Scale durability | The 16px favicon render has a readable silhouette without the wordmark | 16px favicon |
| Tattoo test | At 50% opacity grayscale the wordmark silhouette is coherent and word-shaped | 54px |

---

## Required Lockup Deliverables (Phase 179)

- **Primary lockup (light):** Candidate SVGs in `brandbook/logo-options/round-3/` — filenames: `[direction-id]-primary.svg`
- **Primary lockup (dark):** `[direction-id]-primary-dark.svg`
- **Free-standing mark:** `[direction-id]-mark.svg` (if a mark is retained or redesigned for the candidate)
- **Favicon source:** `[direction-id]-favicon.svg`
- **Integrated typemark (no separate mark):** `[direction-id]-typemark.svg` for fully-integrated-typemark candidates that carry no separate mark element
- **Gallery:** `brandbook/logo-options/round-3/index.html` — standalone HTML linking `tokens.css`, consistent with round-2 format

---

## Candidate Direction Guidance

Phase 179 should produce 5–7 candidates covering at least two structural directions.

**Direction A — Integrated typemark:** Wordmark with rail/ember motif worked structurally into the `g` descender and/or `i` tittle. No separate mark element; the wordmark is the complete identity. This is the primary direction the brief is optimizing for.

**Direction B — Refined combination lockup:** Mark redesigned for better scale durability at 16px favicon, combined with a distinctive-typeface wordmark (not Inter Display Black unless the render shows it is superior). Tighter mark-wordmark proximity. No rectangular container. This is the upgrade of the current v1 construction.

**Direction C — Wildcard (optional):** Only if the executor finds a concept that satisfies all 7 hard constraints and does not fit Direction A or B. Must still pass the render-critique rubric.

**Do not produce:**
- Mark-beside-text using Inter Display Black without modification
- Rectangular-background lockup
- Any candidate with a hue outside the 15–40 degree warm amber range
- A candidate with subtitle/slogan baked into the primary lockup SVG

---

## Sources

- `brandbook/pressure-test-audit-v2.md` Section 8 — REWORK verdict and audit provenance
- `.planning/phases/178-brand-v2-pressure-test-audit/178-RESEARCH.md` — competitor audit, OFL candidates, integrated typemark craft notes, szTheory suite architecture
- `.planning/phases/178-brand-v2-pressure-test-audit/178-CONTEXT.md` — user brief, 7 hard constraints, ratified scope decisions
- `brandbook/tokens.json` — ember palette raw values (ember-050/300/700/800)
- `brandbook/logo-primary.svg` — current v1 reference (mark-left-of-text, Inter Display Black outlined wordmark)
