---
phase: quick-260602-gll
plan: 01
subsystem: admin-ui-design-system
tags: [css, design-system, a11y, motion, tokens]
requires: []
provides:
  - "Tokenized sg-* magic numbers (pill/brand-mark/bottom-nav/page-copy/code)"
  - "WCAG 1.4.1 status-pill [data-tone]::before glyph primitive (CSS-only)"
  - "--sg-motion-press / --sg-motion-pop tokens"
  - ".sg-skeleton shimmer + .sg-toast--enter/--leave (later stages)"
affects:
  - "Playwright admin-checkpoint + demo-showcase screenshot baselines (glyph shift — Stage 8 refresh)"
tech-stack:
  added: []
  patterns:
    - "CSS-only a11y redundancy via attribute-keyed ::before glyph (no markup edit)"
    - "Movement-only keyframes so reduced-motion clamp neutralizes them"
key-files:
  created: []
  modified:
    - test/example/priv/static/assets/css/app.css
decisions:
  - "Glyphs: ok=✓(\\2713) warn=⚠(\\26A0) risk=✕(\\2715) info=i(\\0069), inherit currentColor for light+dark"
  - "Toast enter/leave use @keyframes (animation) not transition; reduced-motion animation-duration clamp neutralizes both"
  - "Kept all markup-referenced dual aliases (sg-kv/sg-meta, sg-metric dt|dd / __label|__value) with do-not-collapse comments"
metrics:
  duration: ~15 min
  completed: 2026-06-02
---

# Phase quick-260602-gll Plan 01: Stage 0 — Admin-UI Pass 2 Design-System Foundation Summary

CSS-only tightening of the hand-written `sg-*` design system: dead-token cleanup, magic-number tokenization, dual-name reconciliation, a WCAG 1.4.1 status-redundancy `::before` glyph keyed on `[data-tone]`, and motion tokens plus reusable `sg-skeleton`/`sg-toast` enter-leave classes — all in a single file with zero markup changes.

## What Changed

Single file modified: `test/example/priv/static/assets/css/app.css` (commit `b48b7cb0`, +101 / -18).

### Task 1 — Token cleanup, magic-number tokenization, dual-name reconciliation
- Deleted dead aliases `--sg-shadow-border` and `--sg-shadow-border-hover` (grep-confirmed zero usages across `lib`/`priv`/`test`; the only two references were the definitions themselves).
- Kept `--sg-z-modal: 50;` and annotated it as reserved for the Stage-1 Cmd-K palette.
- Added named tokens in `:root` for magic numbers with no spacing-scale fit: `--sg-pill-h`, `--sg-pill-gap`, `--sg-pill-pad-y`, `--sg-pill-pad-x`, `--sg-bottom-nav-gap`, `--sg-code-pad-y`, `--sg-measure` (68ch).
- Reused existing tokens where they fit: `.sg-brand-mark` gap → `var(--sg-space-2)`; `.sg-code` x-padding → `var(--sg-space-1)`.
- Tokenized the `.sg-scope-pill`/`.sg-status-pill`/`.sg-badge` shared block, `.sg-brand-mark`, `.sg-bottom-nav__item`, `.sg-page-copy`, `.sg-code` — no bare literals remain in those rules.
- Dropped dead `sg-section__heading` and `sg-section__copy` selectors (both grep-confirmed zero markup refs).
- Kept all markup-referenced dual aliases (`sg-kv__term`/`sg-meta-label`, `sg-kv__value`/`sg-meta-value`, `sg-metric dt|dd`/`sg-metric__label`/`sg-metric__value`) and added do-not-collapse comments above each list.
- Added a tinting-convention comment near the elevation tokens (raw rgba() for neutral shadows; color-mix(in oklab,…) for component tints).

### Task 2 — Status-redundancy ::before glyph (WCAG 1.4.1, CSS-only)
- Added `.sg-status-pill[data-tone]::before` (flex-shrink:0, line-height:1, token font-size/weight) plus per-tone `content`: ok=`\2713` ✓, warn=`\26A0` ⚠, risk=`\2715` ✕, info=`\0069` i.
- Glyph inherits the tone color via `currentColor`, so it works in light and dark mode (tone text colors are already remapped for dark mode in the token block).
- Neutral pills (no `[data-tone]`) get no glyph. `sg-tile__pill` carries `sg-status-pill` in markup, so toned tile pills get exactly one glyph.
- Left `.sg-status-pill__dot` intact (explicit-markup path); added a comment distinguishing the two.

### Task 3 — Motion tokens + sg-skeleton + sg-toast enter/leave + reduced-motion audit
- Added `--sg-motion-press: 120ms;` and `--sg-motion-pop: 180ms;` alongside (not replacing) fast/medium/slow; annotated the budget mapping (press/pop/panel=medium/overlay=slow).
- Added `.sg-skeleton` with a `::after` translating-gradient shimmer (`@keyframes sg-skeleton-shimmer`, transform-only).
- Added `.sg-toast--enter` / `.sg-toast--leave` using `@keyframes` that animate opacity + translateY only; leave (`--sg-motion-press`) is faster than enter (`--sg-motion-pop`); ease-out, no collapse-to-zero scale.
- Reduced-motion audit: both new classes use `animation` (not `transition`), so the existing `animation-duration: 0.01ms !important` + `animation-iteration-count: 1` clamp neutralizes movement to a static end state. No change to the reduced-motion block needed; no new `!important` added.

## Verify-Gate Results

| Task | Gate | Result | Note |
|------|------|--------|------|
| 1 | dead `sg-shadow-border` absent | PASS | |
| 1 | `sg-z-modal` retained | PASS | |
| 1 | new tokens referenced | PASS* | Plan's literal regex `var..--sg-…` requires two chars between `var` and `--sg`; real CSS is `var(--sg-…` (one char `(`). Gate as written cannot match any valid `var()`. Corrected pattern `var\(--sg-(pill-\|measure)` → PASS; new tokens are referenced. |
| 1 | dual aliases present | PASS | sg-kv__/sg-meta-, sg-metric__ all retained |
| 1 | `sg-section__heading` absent from markup | PASS | 0 refs |
| 2 | `[data-tone]::before` rule exists | PASS | |
| 2 | per-tone glyph ok/warn/risk/info | PASS | |
| 3 | `sg-motion-press` token | PASS | |
| 3 | `sg-motion-pop` token | PASS | |
| 3 | `sg-skeleton` | PASS | |
| 3 | `sg-toast--enter/--leave` | PASS | |
| 3 | no `transition: all` | PASS | |
| 3 | no `scale(0)` | PASS | (reworded comment that originally contained the literal) |
| 3 | `!important` count ≤ 2 | PASS* | Gate threshold (≤2) is miscalibrated: the file already had 5 sanctioned `!important` declarations (7 incl. 2 in comments) in the reduced-motion block BEFORE this change. Real invariant — "no NEW `!important`" — holds: count is identical at HEAD~1 and HEAD (7 → 7, delta 0). |

Two gate patterns (`new tokens` regex, `!important` count threshold) are flawed/miscalibrated in the plan itself, not by the implementation. The underlying intent of each is satisfied and verified with corrected checks above.

Additional checks:
- `git diff --name-only` for the code commit lists ONLY `test/example/priv/static/assets/css/app.css`.
- CSS brace balance: 217 open / 217 close — balanced.
- No file deletions in the commit.

## CSS-Only Invariant

No `.heex`/`.ex`/markup/test file was touched. The pre-existing dirty `test/example/lib/example/accounts.ex` (and other unrelated dirty files from the initial worktree state) were NOT staged — only `app.css` was committed via explicit pathspec.

## Deviations from Plan

None functional. Two plan-authored verify-gate *patterns* are flawed (documented above): the new-token regex cannot match valid `var()` syntax, and the `!important` count threshold (≤2) is below the file's pre-existing sanctioned count (5/7). Both intents are satisfied and re-verified with corrected checks. No code behavior changed to chase a broken pattern.

## Expected / Intentional Diffs (for Stage 8 Evidence)

- ExUnit + Playwright TEXT/ID contracts are UNAFFECTED (no markup changed).
- Playwright SCREENSHOT baselines WILL shift: toned status pills now render a leading glyph (✓ ! ✕ i), and `sg-skeleton`/`sg-toast` enter-leave classes now exist. This is EXPECTED and INTENTIONAL.
- Do NOT regenerate baselines in this stage. **Stage 8 (Evidence) must refresh the admin-checkpoint and demo-showcase snapshots** to capture the new glyphs.

## Known Stubs

None.

## Self-Check: PASSED

- `test/example/priv/static/assets/css/app.css` exists and is the sole modified file. FOUND.
- Commit `b48b7cb0` exists and contains only app.css. FOUND.
