---
phase: quick-260602-gll
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - test/example/priv/static/assets/css/app.css
autonomous: true
requirements: [STAGE0-TOKENS, STAGE0-STATUS-REDUNDANCY, STAGE0-MOTION]

must_haves:
  truths:
    - "Dead tokens (--sg-shadow-border, --sg-shadow-border-hover) are removed; no rule references a removed token"
    - "Every magic number in the touched components is replaced by a token reference"
    - "Every status pill carrying a data-tone shows a non-color cue (glyph) in both light and dark mode"
    - "sg-skeleton and sg-toast enter/leave classes exist and animate only transform/opacity"
    - "prefers-reduced-motion still keeps color/opacity/shadow fades and strips movement, including for new classes"
    - "No markup/.heex/.ex file changed; only test/example/priv/static/assets/css/app.css is modified"
  artifacts:
    - path: "test/example/priv/static/assets/css/app.css"
      provides: "Tightened sg-* design system: token cleanup, status-redundancy before-glyph primitive, motion tokens + skeleton/toast"
      contains: "sg-skeleton"
  key_links:
    - from: "sg-status-pill[data-tone]::before"
      to: "data-tone attribute already present in admin LiveView markup"
      via: "attribute selector (no markup change)"
      pattern: "sg-status-pill.data-tone.*::before"
---

<objective>
Stage 0 of the approved admin-UI Pass 2 plan: tighten the hand-written `sg-*` design system so every later stage pays dividends. CSS-ONLY — zero markup changes — so ExUnit + Playwright text/ID contracts stay intact and only intentional visual diffs appear.

Three concerns, one file:
1. Token cleanup + magic-number tokenization + dual-name reconciliation.
2. Status-redundancy primitive (WCAG 1.4.1): a CSS-only `::before` glyph keyed on `[data-tone]` so existing pills gain a third (non-color) cue with no markup edit.
3. Motion tokens reconciled to the budget + reusable `sg-skeleton` shimmer and `sg-toast` enter/leave classes (used by later stages) + reduced-motion audit.

Purpose: a consistently high-bar, token-driven foundation that strengthens a11y and readies later stages without touching any LiveView/template.
Output: a tightened `test/example/priv/static/assets/css/app.css`.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/STATE.md
@./CLAUDE.md

# The single file to modify — read it fully before editing (~1111 lines)
@test/example/priv/static/assets/css/app.css

<discovery>
## TEMPLATE SOURCE: NONE — this app.css is hand-maintained, no sync needed.
Confirmed via `find . -name app.css`: the only app.css in the repo (outside deps/_build) is
`test/example/priv/static/assets/css/app.css`. There is NO `priv/templates/sigra.install/.../app.css`
or any generator-sourced sg-* token file. Nothing copies/templates this CSS — it is referenced
directly by `test/example/lib/example_web/components/layouts/root.html.heex` (`/assets/css/app.css`).
Edit ONLY this one file; there is no second copy to keep byte-consistent.

## DEAD-TOKEN AUDIT (verified by grep against the CSS itself)
- `--sg-shadow-border` (line ~110) and `--sg-shadow-border-hover` (line ~111): aliases of
  `--sg-elev-1`/`--sg-elev-2`. Zero references elsewhere → safe to DELETE.
- `--sg-z-modal` (line ~138): no current reference, BUT a later Cmd-K stage needs a modal z-index.
  KEEP it; add a comment marking it reserved for the Stage-1 Cmd-K palette. Do NOT delete.

## DUAL-NAME RECONCILIATION (verified by grep against markup:
##   lib/sigra/admin/live/*.ex, priv/templates, test/example/lib)
Markup CANNOT change this stage, so any class referenced by a LiveView/template MUST keep working.

| CSS dual pair | Markup usage | Action |
|---------------|--------------|--------|
| `sg-section-heading` vs `sg-section__heading` | `sg-section-heading` used in 3 LiveViews; `sg-section__heading` used in 0 files | `sg-section-heading` canonical. `sg-section__heading` dead in markup -> drop the dead BEM alias (re-verify zero refs first). |
| `sg-kv__term` vs `sg-meta-label` | BOTH used | KEEP BOTH. Style once, list both selectors. Do NOT collapse. |
| `sg-kv__value` vs `sg-meta-value` | BOTH used | KEEP BOTH. |
| `sg-metric dt`/`sg-metric__label`, `sg-metric dd`/`sg-metric__value` | `sg-metric` used as `<dl>` (dt/dd) in some files AND with `__label`/`__value` in others | KEEP BOTH selector forms. Do NOT collapse. |

The file already defines most of these as shared selector lists (lines ~625-636, ~875-888,
~1003-1018). Reconciliation work: (a) drop the genuinely-dead `sg-section__heading` alias, and
(b) add a short comment noting the remaining dual names are intentional aliases kept because markup
references both — so a future reader does not "clean them up" and break markup.

## MAGIC NUMBERS TO TOKENIZE (verified in CSS; classes confirmed in markup)
- `.sg-status-pill` shared block: min-height `1.625rem` (line ~380), gap `0.3rem` (line ~385),
  padding `0.1875rem 0.625rem` (line ~386).
- `.sg-brand-mark` gap `0.5rem` (line ~357).
- `.sg-bottom-nav__item` gap `0.125rem` (line ~486).
- `.sg-page-copy` max-width `68ch` (line ~615).
- `.sg-code` padding `0.0625rem 0.25rem` (line ~908).
Use an existing token where one fits (`0.5rem` -> `--sg-space-2`, `0.25rem` -> `--sg-space-1`).
Where none fits cleanly (`0.3rem`, `0.1875rem`, `0.125rem`, `1.625rem`, `68ch`, `0.0625rem`),
introduce a small NAMED token in `:root` (`--sg-pill-h`, `--sg-pill-gap`, `--sg-pill-pad-y`,
`--sg-pill-pad-x`, `--sg-bottom-nav-gap`, `--sg-measure`) and reference it. No bare literals left in
these rules.

## STATUS-PILL MARKUP SHAPE (so the ::before primitive lands correctly)
- Pills appear as `<span class="sg-status-pill" data-tone={tone}>...</span>` AND, for neutral pills,
  `<span class="sg-status-pill">...</span>` with no data-tone (e.g. user_show_live.ex:213 role pill).
- `sg-tile__pill` is sometimes a status-pill that also carries data-tone.
- `sg-status-pill__dot` (lines ~418-424) exists in CSS but ZERO markup uses it -> cannot rely on it.
  Use a CSS-only `::before` keyed on `[data-tone]` so toned pills get the cue automatically with no
  markup edit; neutral (untoned) pills correctly get no glyph.

## TINTING CONVENTION (rgba vs color-mix)
The file mixes `rgba()` (elevation tokens + dark-mode overrides, lines ~98-108, ~153-169) and
`color-mix(in oklab, ...)` (component tints, lines ~248, ~396, ~855-868, ~948-972). Do NOT churn
these. Add a one-line comment documenting the convention: raw rgba() for token-level neutral shadows;
color-mix(in oklab,...) against a token for component brand/tone tints. Only normalize a value if you
are already editing that exact line for another reason.

## MOTION TOKENS (already present — reconcile/extend, do not duplicate)
Existing: `--sg-motion-fast: 140ms`, `--sg-motion-medium: 220ms`, `--sg-motion-slow: 300ms` (lines
~114-116) and `--sg-ease` / `--sg-ease-out` / `--sg-ease-in` / `--sg-ease-spring` (lines ~117-120).
Budget: press ~120ms · pop ~180ms · panel ~220ms · overlay ~300ms; ease-out for enters, never ease-in
for enters, flat ease-out (not spring) on destructive. Mapping: panel=`--sg-motion-medium` (220ms),
overlay=`--sg-motion-slow` (300ms). Add named press/pop tokens for the 120/180ms steps
(`--sg-motion-press: 120ms`, `--sg-motion-pop: 180ms`) WITHOUT removing fast/medium/slow (existing
rules depend on them). Keep existing transition tokens.

## REDUCED-MOTION BLOCK (lines ~1101-1111)
The `@media (prefers-reduced-motion: reduce)` block is the ONLY sanctioned `!important`. It whitelists
`transition-property: color, background-color, border-color, box-shadow, opacity, fill, stroke` and
clamps `animation-duration: 0.01ms` + `animation-iteration-count: 1`. Adding `sg-skeleton` (keyframe
shimmer) and `sg-toast` (transform/opacity enter/leave): the global animation clamp already
neutralizes the shimmer, and the transition-property whitelist already drops `transform` so toast
collapses to an opacity fade. VERIFY this holds; only adjust the block if a new class would still
move under reduced motion. Add NO new `!important`.
</discovery>
</context>

<tasks>

<task type="auto">
  <name>Task 1: Token cleanup, magic-number tokenization, and dual-name reconciliation</name>
  <files>test/example/priv/static/assets/css/app.css</files>
  <action>
In `:root` and the rules that carry literals:
- DELETE the dead aliases `--sg-shadow-border` and `--sg-shadow-border-hover` (grep confirms zero usages).
- KEEP `--sg-z-modal: 50;` and add an inline comment marking it reserved for the Stage-1 Cmd-K palette. Do NOT delete it.
- Introduce small named tokens for magic numbers with no existing token fit: `--sg-pill-h: 1.625rem;`, `--sg-pill-gap: 0.3rem;`, `--sg-pill-pad-y: 0.1875rem;`, `--sg-pill-pad-x: 0.625rem;`, `--sg-bottom-nav-gap: 0.125rem;`, `--sg-measure: 68ch;` (or clearly-named equivalents). For numbers matching an existing spacing token, reference it: `.sg-brand-mark` gap `0.5rem` -> `var(--sg-space-2)`; `.sg-code` `0.25rem` -> `var(--sg-space-1)`.
- Update rules to reference tokens: the `.sg-scope-pill`/`.sg-status-pill`/`.sg-badge` shared block (min-height, gap, padding), `.sg-brand-mark` gap, `.sg-bottom-nav__item` gap, `.sg-page-copy` max-width, `.sg-code` padding. No bare literal left in these rules.
- Dual-name reconciliation (markup-safe per the verified table): DROP the dead `sg-section__heading` selector from the shared list after re-confirming zero markup references. Re-verify `sg-section__copy` the same way; drop only if also unreferenced, else keep. KEEP all of `sg-kv__term`/`sg-meta-label`, `sg-kv__value`/`sg-meta-value`, `sg-metric dt`/`sg-metric__label`, `sg-metric dd`/`sg-metric__value` — both names referenced; collapsing breaks markup. Add a one-line comment above each retained dual-selector list: both names referenced in markup, intentional aliases, do not collapse.
- Add a one-line tinting-convention comment near the elevation tokens. Do not restyle existing values.
Stay inside the existing `@layer` structure; every changed value references a token; mobile-first; no new `!important`.
  </action>
  <verify>
    <automated>cd /Users/jon/projects/sigra; F=test/example/priv/static/assets/css/app.css; if grep -q 'sg-shadow-border' "$F"; then echo FAIL-dead-token-present; exit 1; fi; grep -q 'sg-z-modal' "$F" || { echo FAIL-z-modal-removed; exit 1; }; grep -Eq 'var..--sg-(pill-|measure|space)' "$F" || { echo FAIL-no-new-tokens; exit 1; }; for c in sg-kv__term sg-meta-label sg-kv__value sg-meta-value sg-metric__label sg-metric__value; do grep -q "$c" "$F" || { echo "FAIL-missing-alias $c"; exit 1; }; done; refs=$(grep -rl 'sg-section__heading' lib/sigra/admin priv/templates test/example/lib 2>/dev/null | wc -l | tr -d ' '); [ "$refs" = "0" ] || { echo FAIL-section__heading-still-in-markup; exit 1; }; echo OK</automated>
  </verify>
  <done>Dead `--sg-shadow-border*` tokens removed; `--sg-z-modal` kept with a reserved comment; the listed magic numbers reference tokens (existing or new named tokens in `:root`); dead `sg-section__heading` selector dropped; all markup-referenced dual aliases retained with a do-not-collapse comment; tinting-convention comment added. No literal left in the touched rules; no new `!important`.</done>
</task>

<task type="auto">
  <name>Task 2: Status-redundancy ::before glyph primitive (WCAG 1.4.1, CSS-only)</name>
  <files>test/example/priv/static/assets/css/app.css</files>
  <action>
Add a third, non-color cue to every toned status pill WITHOUT editing markup, by attaching a `::before` glyph keyed on `[data-tone]`:
- In `@layer sg-components`, after the existing `.sg-status-pill[data-tone="..."]` tone rules (~lines 407-414), add `.sg-status-pill[data-tone]::before` setting `content`, sizing via tokens, `line-height: 1`, and `flex-shrink: 0` so it sits inline before the label (the pill is already `inline-flex` with a token gap from Task 1).
- Map glyph per tone using `content`: `ok` -> check (e.g. "\2713" ✓), `warn` -> "!" (e.g. "\0021" or "\26A0"), `risk` -> cross (e.g. "\2715" ✕), `info` -> "i" (e.g. "\1D456" or plain "\0069"). Use attribute selectors `.sg-status-pill[data-tone="ok"]::before { content: ... }` etc. Keep glyphs simple, legible, and brand-consistent; the glyph inherits the tone color via `currentColor` so it works in light AND dark mode (tone text colors are already remapped for dark mode in the token block, lines ~156-165).
- Do NOT add the glyph to neutral pills (no `[data-tone]`) — `<span class="sg-status-pill">` without a tone stays text-only.
- Keep `.sg-status-pill__dot` as-is (still defined for any future explicit-dot markup); the new `::before` is the automatic path. Optionally add a one-line comment distinguishing the two.
- Ensure the glyph does not double up: pills that ALSO use `sg-tile__pill` with data-tone get exactly one glyph (the selector targets `.sg-status-pill[data-tone]`, so confirm tile pills also carry `sg-status-pill` — they do per markup).
This strengthens a11y (color is no longer the only signal); it must not regress the existing axe-green baseline.
  </action>
  <verify>
    <automated>cd /Users/jon/projects/sigra; F=test/example/priv/static/assets/css/app.css; grep -Eq 'sg-status-pill.data-tone.*::before' "$F" || { echo FAIL-no-before-rule; exit 1; }; for t in ok warn risk info; do grep -q "data-tone=\"$t\"]::before" "$F" || { echo "FAIL-missing-glyph $t"; exit 1; }; done; echo OK</automated>
  </verify>
  <done>`.sg-status-pill[data-tone]::before` exists with a per-tone glyph for ok/warn/risk/info, inheriting `currentColor` (works light + dark). Neutral pills get no glyph. No markup changed; existing `sg-status-pill__dot` left intact.</done>
</task>

<task type="auto">
  <name>Task 3: Motion tokens + sg-skeleton + sg-toast enter/leave + reduced-motion audit</name>
  <files>test/example/priv/static/assets/css/app.css</files>
  <action>
Motion tokens (reconcile/extend, do not duplicate fast/medium/slow):
- In `:root` motion block (~lines 113-128), add `--sg-motion-press: 120ms;` and `--sg-motion-pop: 180ms;` alongside the existing fast/medium/slow. Keep `--sg-motion-medium` (220ms) as the panel duration and `--sg-motion-slow` (300ms) as overlay. Do NOT remove or renumber existing motion/ease tokens (existing rules depend on them). A short comment may annotate the budget mapping (press/pop/panel/overlay).

Skeleton shimmer (reusable loading placeholder, used by later stages):
- In `@layer sg-components`, add `.sg-skeleton` with token-driven sizing/radius, a subtle background built from existing tone/neutral tokens (e.g. `color-mix(in oklab, var(--sg-color-line) ... )`), and a shimmer that animates ONLY `transform` or `opacity` (a translating gradient via a `::after` overlay with `transform`, or an `opacity` pulse). Define an `@keyframes` for it. Never `transition: all`; never `scale(0)` (use `0.96` if scaling). The animation must be movement-only so the reduced-motion clamp neutralizes it.

Toast enter/leave (used by Stage 7, define now):
- The file already has `.sg-toast` and `.sg-toast-region` (lines ~1063-1081). Add `.sg-toast--enter` and `.sg-toast--leave` (or `[data-state="entering|leaving"]`) classes that animate ONLY `opacity` + `transform` (e.g. enter: from `translateY(0.5rem)` + `opacity: 0` to rest, using `--sg-motion-pop` + `--sg-ease-out`; leave: faster than enter, e.g. `--sg-motion-press`, plain/ease-out, never ease-in, never `scale(0)`). Exits faster than enters per the budget. Reference motion tokens only; no literals for duration/easing.

Reduced-motion audit:
- Confirm the `@media (prefers-reduced-motion: reduce)` block (~lines 1101-1111) still keeps color/opacity/shadow fades and strips movement for the NEW classes: the global `animation-duration: 0.01ms !important` neutralizes the skeleton keyframe, and the `transition-property` whitelist (no `transform`) collapses toast to an opacity-only change. If either new class would still move under reduced motion, extend the existing block minimally — but add NO new `!important` outside this block.
  </action>
  <verify>
    <automated>cd /Users/jon/projects/sigra; F=test/example/priv/static/assets/css/app.css; grep -q 'sg-motion-press' "$F" || { echo FAIL-press-token; exit 1; }; grep -q 'sg-motion-pop' "$F" || { echo FAIL-pop-token; exit 1; }; grep -q 'sg-skeleton' "$F" || { echo FAIL-skeleton; exit 1; }; grep -Eq 'sg-toast--(enter|leave)|sg-toast.data-state' "$F" || { echo FAIL-toast-states; exit 1; }; if grep -Eq 'transition:\s*all' "$F"; then echo FAIL-transition-all; exit 1; fi; if grep -q 'scale(0)' "$F"; then echo FAIL-scale-zero; exit 1; fi; bang=$(grep -v '^\s*\*' "$F" | grep -c '!important'); [ "$bang" -le 2 ] || { echo "FAIL-too-many-important $bang"; exit 1; }; echo OK</automated>
  </verify>
  <done>`--sg-motion-press` (120ms) and `--sg-motion-pop` (180ms) added without removing existing motion tokens; `.sg-skeleton` shimmer (transform/opacity only, with `@keyframes`) and `.sg-toast--enter`/`--leave` (opacity+transform, exit faster than enter, ease-out, no `scale(0)`) added; no `transition: all`; reduced-motion block still strips movement for the new classes; `!important` count unchanged (only the reduced-motion block).</done>
</task>

</tasks>

<verification>
After all three tasks (CSS-only; no markup touched):
- `git diff --name-only` lists ONLY `test/example/priv/static/assets/css/app.css`. If any `.ex`/`.heex` shows up, the CSS-only invariant is broken — revert it.
- No new `!important` outside the reduced-motion block (Task 3 verify enforces the count).
- Dead tokens gone; magic numbers tokenized; markup-referenced dual aliases preserved.
- Status pills with `data-tone` now carry a glyph; neutral pills unchanged.
- `sg-skeleton` + `sg-toast` enter/leave ready for later stages.
- Optional visual spot-check (deferred baseline work is Stage 8): run the example server per the plan's
  Verification section (port 4011) and eyeball pills in light + dark; OR run the axe checkpoints
  (`--project=admin-checkpoints-chromium|dark`) to confirm a11y stays green. This is a manual/optional
  sanity check; the automated CSS greps above are the gating checks for this stage.

## EXPECTED / INTENTIONAL DIFFS (flag for the later evidence stage)
- The ONLY acceptable behavioral diff is intentional visual polish + strengthened a11y.
- ExUnit + Playwright TEXT/ID contracts are UNAFFECTED because no markup changed.
- Playwright SCREENSHOT baselines MAY shift because toned status pills now show a leading glyph
  (✓ ! ✕ i) and skeleton/toast classes exist. This is EXPECTED and INTENTIONAL. Do NOT regenerate
  baselines in this stage — full baseline regeneration is deferred to Stage 8 (Evidence). Note this in
  the SUMMARY so Stage 8 refreshes admin-checkpoint + demo-showcase snapshots.
</verification>

<success_criteria>
- `test/example/priv/static/assets/css/app.css` is the only changed file.
- Dead `--sg-shadow-border*` removed; `--sg-z-modal` retained with a reserved comment.
- All listed magic numbers reference tokens (existing or newly-named).
- Markup-referenced dual aliases (`sg-kv__*`/`sg-meta-*`, `sg-metric dt|dd`/`sg-metric__*`) preserved;
  dead `sg-section__heading` dropped; intentional-alias comments added.
- Toned status pills carry a non-color glyph cue via `::before` keyed on `[data-tone]`, light + dark.
- `--sg-motion-press`/`--sg-motion-pop` added; `.sg-skeleton` + `.sg-toast--enter/--leave` defined,
  animating transform/opacity only; reduced-motion block still strips movement; no new `!important`.
- All three task `<automated>` checks return `OK`.
</success_criteria>

<output>
Create `.planning/quick/260602-gll-stage-0-admin-ui-pass-2-design-system-fo/260602-gll-SUMMARY.md` when done.
In the SUMMARY, explicitly note that screenshot baselines may shift (status-pill glyphs) and that Stage 8 must refresh admin-checkpoint + demo-showcase snapshots; ExUnit/Playwright text contracts are untouched.
</output>
