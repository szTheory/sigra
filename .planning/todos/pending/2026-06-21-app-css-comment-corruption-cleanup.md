---
created: 2026-06-21T00:00:00.000Z
status: pending
title: app.css has stripped comment openers that silently drop the next CSS rule
area: example-css
resolves_phase: 214
files:
  - test/example/priv/static/assets/css/app.css
source: 260621-vbr (Vaultr mini-brand typography) — found while debugging why a new vt-* font rule didn't apply
---

## What

`test/example/priv/static/assets/css/app.css` has several comments whose opening
`/*` was stripped at some point, leaving orphaned `*/` fragments and a dangling
value. At **top level**, a stray `* … */` with no `/*` merges into the **next**
rule's selector and silently **drops that rule** — a real footgun for any future
edit to this file.

Known orphan sites (from reading the file 2026-06-21):
- The `VAULTR HOST APP` banner (~line 106) — **already fixed** in `d242d1a8`
  (restored its `/*`); this both fixed the new font rule and restored the original
  `.vt-home/.vt-auth/.vt-app-main { min-height; background; color }` rule that the
  stray text had been silently eating.
- Inside `@media (prefers-color-scheme: dark) { :root { … } }` (~lines 80–84):
  two `* … */` close-fragments + an orphaned `0 0 0 1px rgba(…)` value (looks like a
  `--vt-shadow` whose property line was deleted). Currently harmless (the malformed
  declaration is dropped inside the block, real tokens still parse) — but it means
  dark mode is silently missing an intended shadow override.
- The `:root` light block (~line 45): `/* Focus */` followed by an orphaned
  `color-mix(in oklab, var(--sg-color-brand) 35%, transparent);` (a focus-ring
  property line was deleted). Also `/* Z-index ladder */` and `/* Layout */` with no
  body — likely more deleted lines.

## Why this is NOT urgent

Only the top-level VAULTR-banner orphan dropped a whole rule; that's fixed. The
remaining orphans are **inside declaration blocks**, so CSS error-recovery drops just
one malformed declaration each and the rest of the block parses. The demo renders
correctly. But the file is fragile and a couple of intended tokens (a dark shadow, a
focus ring) are silently absent.

## Do

1. Audit `app.css` for every orphaned `*/` / commentless `* …` fragment and dangling
   value; reconstruct the intended declarations (git history / sibling light-vs-dark
   blocks will show what the deleted property lines were — e.g. the missing
   `--vt-shadow:` / `--sg-focus-ring:` openers).
2. After each fix, verify in a booted browser via `getComputedStyle` / `document
   .styleSheets[].cssRules` that the surrounding rules actually parse — a clean-looking
   file is not proof the parser accepted it (that's how this hid).
3. Consider a tiny CI guard: fail if `app.css` contains a top-level `*/` not preceded
   by a matching `/*` (cheap regex) so this can't silently return.

## References

- Memory: `project_vaultr_mini_brand` (the gotcha), `reference_example_css_split`
- Fixed instance: commit `d242d1a8`
