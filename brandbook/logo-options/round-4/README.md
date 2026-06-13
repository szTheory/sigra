# Sigra Logo Options — Round 4

Round 4 is the one budgeted refinement loop after the Phase 180 gate ratified the **A1 Rail-i direction** (Space Grotesk Bold "sigra", ember rail-block tittle, leftward-extended g tail). Two mandates drove it:

1. **Replace the favicon.** The round-3 favicon cropped "ig" from the wordmark and read as the Instagram logotype. It is dead; every round-4 candidate ships a purpose-built mark.
2. **Tighten the wordmark's weak spots.** The ember tittle was small and faint at 16px (round-3 used ember-300 even on light), and the g tail needed to read as a deliberate rail continuation, never an accidental cutoff (the A3/Syne rejection).

All candidates keep the ratified A1 spine — the glyph outlines are byte-identical to the ratified round-3 paths (Space Grotesk v2.0 OFL, wght 700, outlined with opentype.js 2.0.0) except D4's tail extension. Every candidate passed the Playwright render gate (16/32/54px + hero, light and dark) and the 50%-grayscale tattoo test before landing here. One favicon treatment was cut mid-round: the all-ember-300 rail-i failed the 16px kill test on light surfaces (the apricot block disappears), so light-surface favicons use ember-700 across the board.

## Files

| Option | File | What it tests |
| --- | --- | --- |
| D1 Overshoot Block | [`d1-overshoot-block-typemark.svg`](d1-overshoot-block-typemark.svg) | Whether enlarging the tittle (174→210u, overshoot above x-height) and deepening it to ember-700 on light takes A1 to production grade. Favicon: standalone rail-i. |
| D2 Rail-Bar Tittle | [`d2-rail-bar-typemark.svg`](d2-rail-bar-typemark.svg) | How far the tittle can stretch toward pure rail geometry (3:2 bar, wider than the stem) before it stops reading as an i. Favicon: rail-bar i. |
| D3 Monogram-S | [`d3-monogram-s-typemark.svg`](d3-monogram-s-typemark.svg) | Whether the first letter beats the i as the avatar identity; wordmark widens the block/stem ink trap 58→90u. Favicon: s + ember block monogram. |
| D4 Linked Rail | [`d4-linked-rail-typemark.svg`](d4-linked-rail-typemark.svg) | Whether aligning the tail tip under the tittle's left edge (both at x=557) makes the two edits one explicit rail system. Favicon: abstract rail glyph, no letter. |
| D5 Quiet Ember | [`d5-quiet-ember-typemark.svg`](d5-quiet-ember-typemark.svg) | The control — the ratified ember-300 apricot kept on both modes; is that personality worth a two-value accent system (its favicon must darken to ember-700 on light)? |

Favicon treatments across the set: **standalone rail-i** (D1, D2, D5), **s monogram** (D3), **abstract rail glyph** (D4). All three survived the 16px kill test; D3's is the most size-sensitive (block reads at ~3px at 16px, clean from 24px up).

Open [`index.html`](index.html) to compare light/dark lockups, subtitle previews, and favicon scale strips. Selection from this board is final; the decision is recorded in [`../round-3/README.md`](../round-3/README.md) under the Phase 180 ratification section, and Phase 181 builds the production asset set from it.
