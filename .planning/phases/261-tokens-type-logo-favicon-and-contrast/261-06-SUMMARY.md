---
phase: 261-tokens-type-logo-favicon-and-contrast
plan: 06
subsystem: testing
tags: [brand, contrast, wcag, css-parser, oklab, color-mix, exunit, fail-closed]

# Dependency graph
requires:
  - phase: 261-tokens-type-logo-favicon-and-contrast
    provides: "261-01 contrast instrument (blocks/computed/resolve_color/to_hex/check_pair/unresolved_report/check_unresolved) that this plan extends and drives"
  - phase: 261-tokens-type-logo-favicon-and-contrast
    provides: "261-03 token values in all four blocks (dark on-brand is Char, focus ring is two layers) and 261-04 sunken/control-edge consumers, 261-05 shipped lockup SVGs; the CSS this plan proves"
provides:
  - "Sigra.Brand.ContrastPairsTest, 139 tests: all 30 brand.json contrast pairs evaluated over the implemented CSS in both ways each theme can be shown (60 evaluations), hex parity and ratio parity (0.01) with the book, the book minimum, focus read from the outer ring layer, artwork read from the shipped logos"
  - "Derived and state pairs read from the real rules (hover, active, armed, ghost, nav, theme-switch, nav-link active, table header, code chip, checked chip, the notice action in three states on five grounds), the four kept tones on page/panel/own soft ground, tones and muted on sunken and selected with an exact exempt list, disabled labelled exempt, token-level 3:1 pairs, opaque-ground checks"
  - "A fail-closed scan of every outermost colour call in the template stylesheet (78) and the .sg- rules of the example app.css (11), resolved in four scopes against a committed empty allowlist"
  - "Helper additions in Sigra.Test.Brand.CssContrast: scopes/1, scope_label/1, shadow_colors/1, svg_fills/1, report/2, rule_decls/2, color_expressions/2"
affects: [261-10, 261-11, 262]

# Actuals (#2632) - same estimateTokens scale (chars/4 over the added lines of the realized diff)
actuals:
  tokens: 15267
  tasks: 3
  commits: 6
commits: 6
plan_head_before: 1ce4ea65cb33102aa3c528519dff3eee4dfef772
plan_head_after: 3d6159dc798be6a83533c2b4b8f781b66fb008d8

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Bind a pair to the real rule, not only to a token: each state pair names {selector, property, expected token}, the colour is READ from the stylesheet and the declared expression must equal the expected one, so a rule drifting off its token fails by selector and property"
    - "Every proof has a planted control that fails: white on Kiln Bright, a dropped explicit-Light restatement, a drifted rule binding, a new low row, a stale exempt entry, an unevaluated row, a planted unresolvable expression, a planted translucent value"
    - "Exact two-direction set checks (exempt rows, unresolved allowlist): a new hole and a stale entry both fail"
    - "Fail-closed scanning: an unsupported colour function or an unbalanced call is returned and reported, never skipped"

key-files:
  created:
    - test/sigra/brand/contrast_pairs_test.exs
  modified:
    - test/support/brand/css_contrast.ex

key-decisions:
  - "rule_decls/2 merges every rule whose selector list contains the selector (later wins) instead of returning only the first. The plan says 'first rule', but .sg-code is named by a font rule (~line 531) and again by its colour rule (~line 1433), so first-rule would never see the chip background. The merge is a superset; every caller asserts the property it needs is present."
  - "State pairs are bound twice: to the token the UI-SPEC names (asserted equal to what the rule declares) and to the colour the rule actually resolves to. A harmless refactor of a rule therefore has to update the spec, which is the point."
  - "Notice-action and tone-on-soft-ground rows are composited over the panel as the plan states, and the notice action rows are also composited over the page (all pass): a notice can sit on either."
  - "color_expressions/2 scans every CSS colour function, not only color-mix() and rgba(), and returns an unbalanced call to the end of its rule. The stylesheets use only the two the plan names today, so the wider net costs nothing and an unsupported function can no longer slip through unscanned."
  - "The unresolved allowlist is compared on {selector, expression} pairs in the test, in addition to the helper's selector-level check_unresolved/2, so an allowlist entry cannot hide a different expression under the same selector."

patterns-established:
  - "Sorted thinnest-margin printout over every asserted pair, asserted to lead with selected-status light (+0.11), so an empty or no-op run cannot pass"
  - "Tone and muted text on the new sunken and selected grounds are computed and printed; the below-4.5 set equals a committed list with the stated reason"

requirements-completed: [BTOK-02]

# Coverage metadata (#1602)
coverage:
  - id: D1
    description: "All 30 book pairs (15 ids x light and dark) evaluated over the implemented CSS in both ways each theme is shown (OS light/no theme, OS dark/explicit Light; OS dark/no theme, OS light/explicit Dark): text and ground hex equal the book, ratio within 0.01, at least the book minimum; focus from the outer ring layer, artwork from the shipped logo squares"
    requirement: BTOK-02
    verification:
      - kind: unit
        ref: "test/sigra/brand/contrast_pairs_test.exs#the 30 book pairs: hex parity with the book / ratio parity with the book and the minimum (60 tests), focus, artwork"
        status: pass
    human_judgment: false
  - id: D2
    description: "The proof can fail: planted white on #F08A55 (2.48:1), a planted dropped explicit-Light on-brand/brand restatement, and a drifted rule binding each go red by pair or selector name; the thinnest-margin printout leads with selected-status light"
    requirement: BTOK-02
    verification:
      - kind: unit
        ref: "test/sigra/brand/contrast_pairs_test.exs#planted controls: the instrument can go red; the thinnest-margin printout"
        status: pass
    human_judgment: false
  - id: D3
    description: "Derived and state pairs hold under every scope: primary rest/hover/active, ghost and nav hover (over panel and page), danger armed and hover, theme-switch active segment (light and dark text, all 12 active-segment rule selectors bound), nav-link active (app.css), table header on sunken, code chip resting and hover (exact oklab), checked filter chip, notice action rest/hover/active on the default and four tone grounds, the four kept tones on page/panel/own soft ground, muted on panel-alt"
    requirement: BTOK-02
    verification:
      - kind: unit
        ref: "test/sigra/brand/contrast_pairs_test.exs#derived and state pairs, read from the real rules; the four kept tones and muted on their grounds"
        status: pass
    human_judgment: false
  - id: D4
    description: "Tones and muted on sunken and selected are computed and printed; the rows below 4.5 are exactly light warn on sunken (4.30) and on selected (3.95), with the stated reason; disabled primary composited at opacity 0.5 is computed, printed and labelled exempt (2.22 light, 2.76 dark); token-level 3:1 pairs (control edge, selected edge, focus ring) and opaque sunken/selected/control-edge hold"
    requirement: BTOK-02
    verification:
      - kind: unit
        ref: "test/sigra/brand/contrast_pairs_test.exs#tones and muted on the sunken and selected grounds; disabled; non-text pairs at 3:1; opaque grounds"
        status: pass
    human_judgment: false
  - id: D5
    description: "Fail-closed scan: 78 outermost colour calls in the template and 11 in the app.css .sg- rules all resolve in four scopes against an empty committed allowlist; the demo's vt-* rules are provably out of scope; a planted unresolvable expression, a stale entry and an unbalanced call are all reported"
    requirement: BTOK-02
    verification:
      - kind: unit
        ref: "test/sigra/brand/contrast_pairs_test.exs#fail-closed scan of every colour expression; color_expressions/2"
        status: pass
    human_judgment: false

# Metrics
duration: 12min
completed: 2026-11-16
status: complete
---

# Phase 261 Plan 06: Contrast Proof over the Implemented CSS Summary

**All 30 brand.json contrast pairs, every hover, active, armed, notice and chip state, the four kept tones on the new grounds and the token-level 3:1 pairs are proven over the shipped stylesheet in both ways each theme is shown, with exact oklab compositing, a fail-closed scan of every colour expression, and planted controls that go red, in `mix test` with no new script or job.**

## Performance

- **Duration:** about 12 min (2026-11-16T00:46:13Z to the SUMMARY write)
- **Tasks:** 3 (Task 1 tracer, Task 2 and Task 3 auto TDD)
- **Files modified:** 2, both test-only; `git diff 1ce4ea65c..HEAD --name-only` lists exactly `test/sigra/brand/contrast_pairs_test.exs` and `test/support/brand/css_contrast.ex`. No byte under `lib/`, `priv/`, `scripts/` or `.github/` changed.

## Accomplishments

- **The first red was already resolved, so everything is green on the first real run.** The dark primary button label was fixed to Char (7.50:1) in plan 261-03; all 30 evaluations over the implemented CSS match the book's recorded hexes and ratios (within 0.01) in all four scope combinations, and no CSS correction was needed. The example stylesheet is still byte-identical to the template (`cmp`), and `261-TOKEN-MIGRATION.md` is untouched.
- **Both ways each theme is shown.** Light is (OS light, no theme) and (OS dark, explicit Light); dark is (OS dark, no theme) and (OS light, explicit Dark). A missing explicit-block declaration only breaks the second of each, so every pair is evaluated in both.
- **The proof was shown able to fail against the real stylesheet (throwaway, not committed, file restored by `git checkout` and `cmp`):** setting the dark `--sg-color-on-brand` back to white turned 10 tests red (`button dark` hex and ratio, primary rest/hover/active, danger armed, nav active, the printout); deleting the explicit-Light `--sg-color-on-brand` restatement turned `button light`, the parity invariant and the derived pairs red. This verification lives in `test/sigra/brand/contrast_pairs_test.exs` (planted controls) and runs in `mix test`; the mutation run itself is not recorded in CI.
- **Real thinnest margins** (printed; the first line is selected-status light, as the research predicted): selected-status light 4.61 (+0.11), warn on the page light 4.70 (+0.20), primary hover light 4.84 (+0.34), warn on its soft ground light 4.87 (+0.37), button and primary rest light 5.18 (+0.68), selected-row light 5.52 (+1.02), the three ochre status words light 6.06, artwork light 4.69 (+1.69 over 3:1).
- **Exempt rows are exactly the predicted two.** Tones and muted on sunken and selected: the only rows below 4.5 are light warn on sunken (4.30) and light warn on selected (3.95), carrying the stated reason ("never bare text on this ground; use a pill with its own soft ground or a --sg-status-* token"). No other row is below 4.5 (the next thinnest are light ok on selected 4.96, risk on selected 5.00, info on selected 5.10). The check is exact in both directions with planted new-low, stale and unevaluated cases.
- **Disabled is computed, never skipped.** Primary at the opacity read from `.sg-btn[disabled]` (0.5) composites to 2.22:1 light and 2.76:1 dark, printed labelled `exempt: inactive component`; a unit case shows a black label at 0.5 over white is `#808080`.
- **Token-level non-text pairs at 3:1 hold** in every scope: control edge on panel and on sunken, selected edge on selected, focus ring on page and panel. `--sg-color-sunken`, `--sg-color-selected` and `--sg-color-control-edge` are opaque (alpha 1) in all scopes, so the sticky table header stays opaque; a planted `rgba(..., 0.9)` is reported as translucent.
- **Fail-closed scan.** 78 outermost colour calls in the template (39 `color-mix()` and 39 outermost `rgba()`) and 11 in the app.css rules naming `.sg-` all resolve in four scopes; the committed `@unresolved_allowlist` is empty. The demo-owned `vt-*` rules are provably not scanned (the filtered count is below the whole-file count and no scanned selector lacks `.sg-`).

## Task Commits

1. **Task 1: Tracer, the 30 book pairs in every scope with planted controls and the thinnest-margin printout**
   - RED `07b98d18b` (test): 76 tests, all invalid because `scopes/1`, `shadow_colors/1`, `svg_fills/1`, `report/2` and `scope_label/1` did not exist
   - GREEN `952f1f66d` (feat): 76 tests pass; tracer feedback gate re-ran the verify (152 tests across the three files, then 655 across `test/sigra/brand/`), `Tracer verified end-to-end - expanding`
2. **Task 2: Derived and state pairs, kept tones on the new grounds, disabled, token-level non-text pairs**
   - RED `03e552fc3` (test): 130 tests, 38 failing on the undefined `rule_decls/2`; the 92 token-level tests (tones, exempt list, non-text, opaque) passed already because they need no rule reader
   - GREEN `46e4bd9dd` (feat): 130 tests pass, conformance and token-completeness PASS, `cmp` identical
3. **Task 3: Fail-closed scan of every colour expression in the shipped and example stylesheets**
   - RED `4f93187eb` (test): 139 tests, 7 failing on the undefined `color_expressions/2`
   - GREEN `3d6159dc7` (feat): 139 tests pass; `mix test test/sigra/brand/` 718 tests, 0 failures; `mix format --check-formatted` clean

**Plan metadata:** the docs commit that follows this file (SUMMARY, then STATE, ROADMAP and REQUIREMENTS).

## Files Created/Modified

- `test/sigra/brand/contrast_pairs_test.exs` - `Sigra.Brand.ContrastPairsTest`, 139 tests; carries `@pair_bindings`, `@state_specs`, `@notice_specs`, `@exempt_rows`, `@unresolved_allowlist`
- `test/support/brand/css_contrast.ex` - additions: `scopes/1`, `scope_label/1`, `shadow_colors/1`, `svg_fills/1`, `report/2`, `rule_decls/2`, `color_expressions/2`

## Decisions Made

See `key-decisions` in the frontmatter. In short: `rule_decls/2` merges rather than first-rule (needed for `.sg-code`); state pairs are bound to the real rule and its declared token; the scan covers every CSS colour function and keeps unbalanced calls; the allowlist is compared on `{selector, expression}`.

## Deviations from Plan

### Auto-fixed Issues

None. No bug, blocker or missing critical functionality was found in existing code, and no contrast failure was found against the implemented CSS, so no stylesheet, example copy or migration-table row was changed. (Task 2 allows a CSS correction if the test demands one; it did not.)

### Interpretations and additions beyond the plan's listed surface

All are within the plan's stated goal, none weakens a criterion, and each has tests.

**1. [Interpretation] `rule_decls/2` merges all matching rules instead of returning "the first rule"**
- **Why:** `.sg-code` is named by two rules (the mono font rule and the colour rule). Returning only the first would never see the chip background, which Task 2 Test 4 and the plan's own `.sg-code` row need.
- **Effect:** a superset of "first rule"; callers assert the property they need exists. Documented in the function's `@doc` and unit-tested (later wins, `@layer`/`@media` nesting, whitespace-collapsed multi-line selectors and values, a `;` inside a string).
- **Commit:** `46e4bd9dd`

**2. [Rule 2 - strengthening] State pairs are read from the real rules and bound to the expected tokens**
- The plan allows token-level pairs for hover and active states; this plan reads `color` and `background` from the real rule (template or app.css) and asserts the declared expression equals the UI-SPEC token. A rule that drifts off its token fails by selector and property, and a planted drift test proves it. The theme-switch pair also binds all 12 active-segment rule selectors (light 3, dark 9).
- **Commit:** `03e552fc3`, `46e4bd9dd`

**3. [Addition] Notice-action and ghost rows composited over the page as well as the panel**
- The plan states "composited over panel"; a notice can sit directly on the page, so the notice action rows also use the page ground. All pass. Ghost and nav hover use both as the plan states.
- **Commit:** `46e4bd9dd`

**4. [Addition] `color_expressions/2` scans every CSS colour function and keeps unbalanced calls**
- The plan names `color-mix()` and `rgba()`; the stylesheets use only those today. The scan also returns `rgb()`, `hsl()`, `oklab()`, `oklch()`, `light-dark()` and the rest, and returns an unbalanced call to the end of its rule. Fail-closed, so a new unsupported function is reported instead of silently skipped. (The older `color_mix_expressions/1` from plan 261-01 returns `[]` for an unbalanced call; it is left untouched because its own tests pin its behaviour, and this plan does not use it.)
- **Commit:** `3d6159dc7`

**5. [Addition] Allowlist compared on `{selector, expression}` in the test**
- `check_unresolved/2` compares unique selectors (plan 261-01's contract). The test additionally compares `{selector, expression}` pairs, both directions, so an allowlist entry cannot cover a different expression under the same selector. Both checks are asserted.

**6. [Addition] `report/2` (options) rather than `report/1`, plus `scope_label/1`**
- `report/2` takes `exempt: :exclude | :only | :include` so the disabled and exempt rows are printed from the same function; `report/1` is the default-options call the plan names. A row with no evaluated ratio raises instead of printing.

---

**Total deviations:** 0 auto-fixed bugs; 6 interpretive or additive notes. 
**Impact on plan:** none negative. Every acceptance criterion is met as written (Task 1: 76 tests >= 40, printout leads with selected-status, `git diff --name-only -- lib` empty; Task 2: 130 tests >= 60, both exempt strings printed, `grep -c exempt` = 38 >= 3; Task 3: `mix test test/sigra/brand/` green, min count and allowlist equality asserted with planted failures, `git diff --name-only -- scripts .github` empty).

## Authentication Gates

None.

## Issues Encountered

- A `~s(...)` sigil with parentheses delimiters cannot hold a selector containing `:not(...)`; those three selectors use `~s|...|`. An attribute written `@notice_specs for ... do ... end` binds the do-block to the attribute name; it is wrapped in parentheses.
- The ExUnit failure output for a rule-driven test prints the whole stylesheet in the stack trace (the function argument is the CSS text). It is noisy in the RED phase only; the green tests print nothing of the kind.
- Pre-existing, not mine and left untouched: `.planning/config.json` and `.planning/state.json` carried uncommitted changes before this plan started; `state.json` was snapshotted and restored byte for byte after the state writers ran.

## Verification

- `mix test test/sigra/brand/contrast_pairs_test.exs test/sigra/brand/css_contrast_test.exs test/sigra/brand/token_parity_test.exs`: 152 tests (before Task 2), green; after Task 3 `mix test test/sigra/brand/`: 718 tests, 0 failures.
- `mix test test/sigra/brand/contrast_pairs_test.exs test/sigra/brand/token_migration_test.exs`: 143 tests, 0 failures.
- `bash scripts/ci/admin-css-conformance.sh`: PASS. `bash scripts/ci/admin-token-completeness.sh`: PASS (112 tokens, `:root` equals the doc). `cmp` template vs example stylesheet: identical.
- `mix format --check-formatted`: clean. `mix credo --strict` on the two changed files: no issues.
- `git diff 1ce4ea65c..HEAD --name-only -- lib scripts .github priv`: prints nothing.
- `grep` for environment reads (`System.get_env`/`fetch_env`) in the two files: none; the RegenGuard scan (`test/sigra/brand/regen_guard_test.exs`) passes inside the 718.
- Golden-reading tests (`golden_diff_test`, asset-parity golden legs) were not run and are expected stale until plan 261-11's single rebless; `rebless` was not run here.

## Known Stubs

None. The two scan constants (`@unresolved_allowlist []`) and the exempt list are intentional committed data, not stubs.

## Threat Flags

None. The change is test-only: no network, no environment read, no new trust boundary. T-261-09 (a contrast test passing without evaluating a pair or expression) is mitigated as planned: recorded-hex and ratio parity per pair, four scope combinations, a planted bad colour, a planted dropped explicit block, a planted unresolvable expression and a planted translucent value, non-empty and minimum-count guards, the thinnest-margin printout asserted to lead with selected-status light, and an exact exempt list.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Plans 261-10 and 261-11 can rely on `mix test test/sigra/brand/` being green; this plan changed no shipped byte, so the single golden rebless in 261-11 is unaffected.
- When Phase 262 gives the additive tokens consumers (`--sg-color-selected`, `--sg-color-selected-edge`, `--sg-color-current-tab`, `--sg-status-*`) or re-points status pills, add real-rule specs to `@state_specs` in `contrast_pairs_test.exs`; the token-level pairs for them already hold. A deliberate edit to a rule named in `@state_specs` or `@notice_specs` (for example replacing `--sg-logo-rail-accent` on the theme-switch active segment) must update that spec in the same change, by design.
- Light warn on sunken and selected is the only committed exemption; Phase 262 must not use bare `--sg-color-warn` text on those grounds.

## Self-Check: PASSED

- FOUND: `test/sigra/brand/contrast_pairs_test.exs`, `test/support/brand/css_contrast.ex`, this SUMMARY
- FOUND commits: `07b98d18b`, `952f1f66d`, `03e552fc3`, `46e4bd9dd`, `4f93187eb`, `3d6159dc7` (all ancestors of HEAD)
- Measured: 6 commits since `plan_head_before` `1ce4ea65cb33102aa3c528519dff3eee4dfef772`
- Re-run of every acceptance criterion and the plan-level `<verification>` after the last commit: `mix test test/sigra/brand/` 718 tests, 0 failures; conformance and token-completeness PASS; template and example stylesheet identical; `git diff --name-only -- lib scripts .github` empty; no environment read, no home path, no personal name in the changed files or this SUMMARY

---
*Phase: 261-tokens-type-logo-favicon-and-contrast*
*Completed: 2026-11-16*
