# Phase 178 Context: Brand v2 Pressure-Test Audit

**Source:** User kickoff brief (2026-06-11/12) + approved plan `~/.claude/plans/brand-book-pressure-test-squishy-eich.md`. This file substitutes for discuss-phase: the user supplied a complete brief and ratified scope decisions interactively, so this is a lossless capture rather than a fresh questioning round.

## What the user asked for (verbatim intent)

- "Pressure test our brand book, make sure it's high fidelity... high quality from graphic design perspective, maximally useful from a UI/UX buildout perspective and for making marketing materials like landing pages, websites, design tokens, UX microcopy, brand voice, acceptable imagery."
- "I don't want to cause thrash for no reason — take a critical analysis lens... all killer no filler."
- "We already did a brand prompt deep research, then a brand book; now I want a brand stress test and to take the brand to the next level. We can consider new variations, new ideas/concepts, but the goal is an amazing, perfect brand design and we'll want to redo the logo — more integrated, thoughtful, creative/cool/playful (or whatever fits the brand), very professional."
- "Think deeply, go above and beyond, research using subagents, every angle."
- The audit must follow the full 14-section pressure-test structure the user supplied (same structure as v1.35's `brandbook/pressure-test-audit.md`): (1) Executive judgment, (2) Brand DNA extraction, (3) Pressure-test scorecard (15 scored dimensions), (4) Stress tests across ~26 real surfaces, (5) Gaps and risks by severity, (6) Recommended brand book upgrades, (7) Design token specification, (8) Logo and mark system, (9) Visual examples and screenshot guidance, (10) Brand voice and microcopy, (11) Landing page and docs blueprint, (12) Repo-ready artifact plan, (13) Prioritized action plan, (14) Final quality gate.
- Decision framework: **KEEP / TIGHTEN / REWORK / ADD / REMOVE**. KEEP is the default; every REWORK requires evidence. "Do not flatter the existing brand book unless it earns it. Do not invent false certainty. Mark assumptions explicitly. Prefer fewer, stronger recommendations. Preserve good existing work. Do not recommend a full redesign unless the existing brand system truly fails."

## Logo v2 design brief inputs (hard constraints from the user)

1. **No rectangular background shape behind the logomark.** "AI always forces a rectangular BG shape onto these logomarks and I do NOT like that — we like somewhat breaking the boundaries."
2. **Logotype appropriately close to the logomark** — "not too separated visually."
3. **Main logomark+logotype combo has NO subtitle/slogan.** A separate with-subtitle variant is fine. "Slogan/subtitle is not great in a logo (IMO)."
4. **Fully integrated typemark options required:** "variations that are logotype... a type treatment with some kind of motif/flourish/playful creative element worked in, instead of the default logomark to the left of text — a fully worked-in custom type treatment for a really nice fully integrated designed SVG typemark."
5. **Not "a shitty icon to the left of basic text."** "The imagery and typography should be very unique and brand based."
6. **Fonts/colors are tweakable:** "you have the option to tweak the fonts/colors etc — this was just a seed. NOW is your chance to nail it, knock it out of the park."
7. **Options must be shown for human choice:** "ABSOLUTELY IMPORTANT that you show me logo options so I can choose."

## Ratified scope decisions (asked and answered 2026-06-12)

| Decision | Answer |
| --- | --- |
| Palette freedom | **Ember-anchored, tunable** — keep warm ember identity as anchor; shade/secondary tuning allowed per candidate; no unrelated palettes |
| README/social adoption | **Deferred** as `gsd-quick` fast-follow after v1.38 ships |
| Raster policy | **SVG-only committed assets**; Playwright renders are QA/gallery-only, never committed |

## Research directives for this phase (user: "research using subagents every angle")

- Competitor/ecosystem visual audit: Oban, Ash, Phoenix, Pow, Elixir-ecosystem and broader devtools brands — what reads credible vs generic; where Rail Accent sits.
- Graphic-design lenses: "consider pros/cons/tradeoffs of different scopes and approaches... lessons learned... through the lens of graphic design / brand designer... all of the best-practices lenses."
- OFL typography research: distinctive display faces suitable for outlining (current wordmark is outlined Inter Display Black v4.1; candidates may keep or replace).
- Multi-library brand architecture: shared vs per-library identity across the szTheory suite (Sigra, Accrue, Mailglass, Threadline, Lockspire, Relyra, Rulestead). Note `test/example/priv/static/images/vaultr-mark.svg` exists as a demo sibling-mark hint.
- Constraint: programmatic generation — "we are programmatically generating this brand"; everything must be reproducible from committed text/SVG sources.

## Existing material (audit subject)

- `brandbook/` (v1.35, 276KB, all text/SVG): `brand-book.md`, `index.html`, `tokens.json`/`tokens.css` (`--sigra-*`), `pressure-test-audit.md` (v1 audit), logo system (Rail Accent: `logo-primary.svg` = mark + outlined Inter wordmark side-by-side, `logo-primary-dark.svg`, `logo-mark.svg`, `logo-monochrome.svg`, `favicon.svg`, `social-card.svg`), `examples/` (9 specimens), `logo-options/` (rounds 1–2 archives).
- Known v1 lockup critique to test: mark-left-of-text construction, logotype separation, integration quality.
- Propagated consumers (constrain REWORK ripple): installer templates `priv/templates/sigra.install/admin/sigra-logo-primary{,-dark}.svg`, example app images, sg-* token values in `test/example/priv/static/assets/css/app.css`, `sigra_auth.css` accent defaults, admin design contract, ~30 Playwright baselines.

## Outputs this phase must produce

1. `brandbook/pressure-test-audit-v2.md` — full 14-section audit with verdicts + evidence (BRAND2-01), including szTheory suite architecture section (BRAND2-02).
2. Logo v2 design brief (committed; standalone file or audit section) encoding all 7 hard constraints above plus the ratified scope decisions (BRAND2-03).
3. Prioritized action plan that directly drives Phases 179–183 scope.
