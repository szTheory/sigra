# Sigra Logo Options — Round 3

This round explores integrated typemarks (rail motif worked into the letterforms), boundary-breaking refined lockups, and one stacked wildcard — moving past the mark-beside-text pattern the Elixir ecosystem defaults to.

The active Sigra logo source set lives in the parent `brandbook/` directory.

Every candidate passed the Playwright render-critique gate (16/32/54px and hero, light and dark, plus a 50%-grayscale tattoo check) before inclusion. A3 was reworked mid-round: the crossbar-s concept failed the render gate twice (the bars crossed Syne's s counters), so the candidate pivoted to color-blocking the g's native descender plate; filenames keep the original `a3-crossbar-s-*` prefix.

## Files

| Option | File | What it tests |
| --- | --- | --- |
| A1 Rail-i typemark | [`a1-rail-i-typemark.svg`](a1-rail-i-typemark.svg) | Whether two restrained letterform edits (ember block tittle, extended g tail) carry a full identity with no separate mark. |
| A2 Descender-rail typemark | [`a2-descender-rail-typemark.svg`](a2-descender-rail-typemark.svg) | The g descender — the brief's prime integration point — as the sole motif carrier. |
| A3 Rail-g typemark | [`a3-crossbar-s-typemark.svg`](a3-crossbar-s-typemark.svg) | How far the brand can lean into Syne's display character while keeping infrastructure credibility. |
| A4 Ember-dot typemark | [`a4-ember-dot-typemark.svg`](a4-ember-dot-typemark.svg) | The conservative benchmark: does one accent on Inter Display Black clear the distinctiveness bar? |
| B1 Redesigned mark lockup | [`b1-redesigned-mark-primary.svg`](b1-redesigned-mark-primary.svg) | Whether the combination-lockup lane survives via simplification and baseline-breaking. |
| B2 Letterform substitution | [`b2-letterform-sub-primary.svg`](b2-letterform-sub-primary.svg) | The hybrid thesis: a lockup whose mark is a working letterform (ember rail-switchback s). |
| C1 Stacked wordmark | [`c1-stacked-primary.svg`](c1-stacked-primary.svg) | Whether breaking the single-line convention is worth the horizontal-context cost; favicon is the mark alone. |

Open [`index.html`](index.html) to compare mark-only, light/dark lockup, and favicon previews.

## Ratification (Phase 180)

**Date:** 2026-06-12 · **Decided by:** maintainer (szTheory), the milestone's single human gate.

**Ratified: D4 Linked Rail** — the round-4 refinement of **A1 Rail-i** (see [`../round-4/`](../round-4/README.md)).

- **Direction:** A1 Rail-i typemark, refined as D4 Linked Rail. Wordmark is "sigra" with the i tittle replaced by an ember rail block and the g tail extended leftward to x=557 so its tip aligns exactly under the tittle's left edge — tittle above, rail below, one bracketing rail system around "ig".
- **Typeface:** Space Grotesk v2.0 (OFL), wght 700, outlined to paths with opentype.js 2.0.0 — no font binaries in the repo.
- **Mark / favicon:** the abstract rail glyph from `d4-linked-rail-favicon.svg` (ink stem + leftward foot + ember block, no letter). The round-3 "ig" crop is retired permanently — the maintainer flagged it as reading like the Instagram logotype.
- **Palette:** ember-anchored with fine-tuning allowed within hue 15–40° during Phase 181 buildout; light-surface favicon accent is ember-700 `#c2410c` (ember-300 failed the 16px kill test on light).
- **Round-4 usage:** yes — the one budgeted refinement loop was used to fix the favicon and tighten the tittle/tail per gate feedback. Selection from the round-4 board is final; no further rounds.
- **Runner-ups:** D1 Overshoot Block (safest pick; lost on concept — no rail-system linkage, conventional rail-i favicon). Round-3 runner-ups: B2 Letterform Substitution (Geist's Vercel association; agent-recommended but not chosen), A2 Descender-Rail (weak mark-alone story), A3 Rail-g rejected explicitly ("g swirl … looks like a glitch"), A4/B1/C1 not shortlisted.

**Phase 181 builds the production asset set (primary, dark, subtitle variant, mark, monochrome, favicon, social cards) from D4 Linked Rail without reopening design questions.**
