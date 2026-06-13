---
plan: 180-01
phase: 180
status: complete
completed: 2026-06-12
requirements:
  - BRAND2-07
commits:
  - b9b5b64c (feat(180-01): round-4 candidate SVGs)
  - b6256e9e (feat(180-01): round-4 gallery index + README)
---

# Plan 180-01 Summary — Human Logo Ratification Gate

## Outcome

**Ratified: D4 Linked Rail** — round-4 refinement of A1 Rail-i.

- Space Grotesk v2.0 (OFL) wght 700, opentype.js-outlined paths, no font binaries.
- Wordmark: "sigra" with ember rail-block tittle; g tail extended to x=557 so its tip aligns under the tittle's left edge — one bracketing rail system around "ig".
- Mark/favicon: abstract rail glyph (ink stem + leftward foot + ember block, no letter).
- Palette: ember-anchored; fine-tuning allowed within hue 15–40° during Phase 181; light-surface favicon accent ember-700 `#c2410c`.

## Gate flow

1. Round-3 board (7 candidates) presented with per-card screenshots, strengths/risks, and recommendation (B2).
2. Maintainer chose **A1 Rail-i** instead and invoked the one budgeted round-4 loop with two mandates: replace the "ig" favicon (reads as Instagram) and tighten A1's deficiencies. A3 (Syne) explicitly rejected — descender plate "looks like a glitch."
3. Round-4 built 5 A1-family variants (D1–D5) across three axes: favicon replacement, 16px tittle pop, tail/letterform craft. All passed the render gate (16/32/54px + hero, light + dark, tattoo test); the all-ember-300 favicon was cut for failing the 16px kill test on light.
4. Round-4 board presented; maintainer ratified **D4 Linked Rail** (recommended). Selection is final per the one-loop budget.

## Decision record

`brandbook/logo-options/round-3/README.md` → "## Ratification (Phase 180)" (grep count = 1); STATE.md decision log updated.

## Deviations

- None of substance. Round-4 occurred as the budgeted refinement path anticipated by the plan.

## Hand-off to Phase 181

Build the full production asset set from `brandbook/logo-options/round-4/d4-linked-rail-*.svg` without reopening design questions. Open craft latitude: palette micro-tuning within hue 15–40° only.
