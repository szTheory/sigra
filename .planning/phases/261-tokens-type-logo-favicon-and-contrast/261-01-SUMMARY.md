---
phase: 261-tokens-type-logo-favicon-and-contrast
plan: 01
subsystem: testing
tags: [brand, contrast, wcag, css-parser, oklab, color-mix, exunit, token-parity]

# Dependency graph
requires:
  - phase: 260-deterministic-output-before-catalog-and-png-park
    provides: css_gap.ex pure-check plus in-memory planting pattern; RegenGuard scan over test/support/brand
provides:
  - Sigra.Test.Brand.CssContrast, a test-only contrast instrument over the implemented admin stylesheet (parse, two-level cascade, rgba compositing, color-mix in srgb and oklab, fail-closed unresolved reporting)
  - Sigra.Brand.CssContrastTest, the tracer body pair plus planted bad colour and every colour-maths control
  - Sigra.Brand.TokenParityTest, the three four-place token invariants with planted violations
  - consolidated block extractors (extract_css_block/2, extract_css_blocks/2, extract_sg_declarations/1, take_balanced_block/1) for admin_test.exs to import in plan 261-03
affects: [261-03, 261-04, 261-06, 261-10, 261-11]

# Actuals (#2632) - same estimateTokens scale (chars/4 over the realized files)
actuals:
  tokens: 17346
  tasks: 3
  commits: 5
commits: 5
plan_head_before: 129a7907e3edfb4795f5d981ba976f5416124ebc
plan_head_after: 9c01c01ebe0e786210bc6d360288e5b03cd60981

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Pure check functions over a parsed block map, so a planted violation runs in memory and proves the check can fail"
    - "Fail-closed colour resolution: {:unresolved, reason} plus an exact-match allowlist (empty) instead of a silent pass"
    - "Two-level cascade model (root element, then shell element) instead of a flat merge, so the alias footgun is observable"

key-files:
  created:
    - test/support/brand/css_contrast.ex
    - test/sigra/brand/css_contrast_test.exs
    - test/sigra/brand/token_parity_test.exs
  modified: []

key-decisions:
  - "computed/2 is a two-level cascade: level one is the root element (:root, then the dark @media block under a dark OS) with every var() substituted where it is declared; level two is the .sg-admin-shell element, which inherits the level-one computed values and applies its explicit block. This is what makes an alias declared only in :root stay light inside an explicit-Dark shell."
  - "blocks/1 parses with a small rule tokenizer (selector list split on commas, exact match, at-rule context tracked) instead of substring search, so a nested rule or an @media-scoped rule cannot be mistaken for a token block."
  - "Invariant 3 treats 'theme-variant' as the dark @media token set closed over any :root token that references one, so an alias of an alias is held to the same all-four-blocks rule (a strict superset of the UI-SPEC wording; no false positive on the current stylesheet)."
  - "check_unresolved/2 compares unique selectors against the allowlist, so one selector unresolved in several scopes needs one allowlist entry; a stale entry fails as hard as a new hole."
  - "mix/4 is mix(space, rgba1, rgba2, {p1, p2}) with nil meaning omitted, which carries the full CSS Color 5 percentage rules (remainder, normalise over 100, scale alpha under 100)."

patterns-established:
  - "Test-support modules under test/support/brand derive the repo root from __DIR__ and never name the environment API; the RegenGuard scan fails on the literal text even in a comment."
  - "Every real-file brand test asserts the parse is non-empty first, so a broken extraction cannot pass vacuously."

requirements-completed: [BTOK-02]

# Coverage metadata (#1602)
coverage:
  - id: D1
    description: "Tracer: the body pair (ink on subtle) is parsed from the shipped stylesheet, resolved through the cascade, composited and run through Sigra.Branding.Contrast.contrast_ratio/2 in light and dark, at least 4.5:1 (light 16.75, dark 16.04)"
    requirement: BTOK-02
    verification:
      - kind: unit
        ref: "test/sigra/brand/css_contrast_test.exs#tracer: the body pair, end to end on the real stylesheet"
        status: pass
    human_judgment: false
  - id: D2
    description: "Positive control: a planted white-on-#F08A55 pair (2.48:1) fails the pair check, so the instrument can go red"
    requirement: BTOK-02
    verification:
      - kind: unit
        ref: "test/sigra/brand/css_contrast_test.exs#positive control: the pair check can go red"
        status: pass
    human_judgment: false
  - id: D3
    description: "Colour maths: rgba compositing, disabled-state opacity compositing (2.22 light, 2.76 dark), OKLab reference vectors, color-mix in srgb and oklab (premultiplied, percentages, nested, multi-line, var operands); all 39 color-mix expressions and every colour token of the shipped stylesheet resolve in all six OS-by-theme scopes with an empty allowlist"
    requirement: BTOK-02
    verification:
      - kind: unit
        ref: "test/sigra/brand/css_contrast_test.exs (compositing, OKLab, color-mix(), nested and multi-line, fail closed, color_mix_expressions/1)"
        status: pass
    human_judgment: false
  - id: D4
    description: "Fail-closed unresolved reporting: an unresolvable expression is listed by selector, and an allowlist of the wrong size (either direction) returns {:error, :allowlist_mismatch}"
    requirement: BTOK-02
    verification:
      - kind: unit
        ref: "test/sigra/brand/css_contrast_test.exs#fail closed: unresolved expressions"
        status: pass
    human_judgment: false
  - id: D5
    description: "Three four-place token invariants hold on the shipped stylesheet and each fails, naming the token, when a violation is planted in memory (and when planted into the real stylesheet shape)"
    requirement: BTOK-02
    verification:
      - kind: unit
        ref: "test/sigra/brand/token_parity_test.exs"
        status: pass
    human_judgment: false
  - id: D6
    description: "Block extractors consolidated as public functions with the private contracts (ArgumentError where the private copies flunk), so plan 261-03 can delete the admin_test.exs copies"
    verification:
      - kind: unit
        ref: "test/sigra/brand/css_contrast_test.exs#extractors (consolidated for plan 261-03 to import)"
        status: pass
    human_judgment: false

# Metrics
duration: 8min
completed: 2026-11-15
status: complete
---

# Phase 261 Plan 01: Contrast Helper Tracer Summary

**A test-only contrast instrument that parses the shipped admin stylesheet, resolves any `--sg-*` token through a two-level cascade (with rgba compositing and `color-mix` in srgb and oklab), runs `Sigra.Branding.Contrast.contrast_ratio/2`, and fails closed on anything it cannot evaluate, plus the three four-place token invariants, all proven on the current stylesheet before any token value changes.**

## Performance

- **Duration:** about 8 min timed (the first commit guard to the last commit; the initial context read and design were not timed)
- **Started:** 2026-11-15T23:50:25Z
- **Completed:** 2026-11-15T23:58:00Z
- **Tasks:** 3
- **Files modified:** 3 (all created, all test-only; no byte under `priv/` or `lib/` changed)

## Accomplishments

- **Tracer green on the live stylesheet.** The body pair (`--sg-color-ink` on `--sg-color-subtle`) resolves through parse, cascade, composite and `Contrast.contrast_ratio/2`: 16.75:1 light (`#151515` on `#F6F5F2`, the current values) and 16.04:1 dark. The tracer feedback gate passed (verify re-run, `⚡ Tracer verified end-to-end - expanding`) before any expansion.
- **Positive control proven.** A planted white label on `#F08A55` computes 2.48:1 and `check_pair/5` reports `pass?: false`; a good pair and a custom minimum are asserted alongside it.
- **Every colour shape in the stylesheet evaluates.** All 39 outermost `color-mix(...)` expressions (single-line, multi-line, nested `var()`, operands that are themselves `rgba()` with alpha) and every `--sg-color-*`, `--sg-logo-*` and `--sg-status-*` token resolve in all six OS-scheme by admin-theme scopes against an empty `@unresolved_allowlist`. OKLab matches the published vectors for white, black, red, green and blue to 0.001 and round-trips within 1 per channel.
- **Fail-closed, with controls.** `currentColor`, `oklch()`, `light-dark()` and an undefined `var()` return `{:unresolved, reason}`; a planted unresolvable expression is reported by selector; an allowlist of the wrong size in either direction returns `{:error, :allowlist_mismatch}`.
- **Four-place invariants.** Dark `@media` equals explicit-Dark; every dark-overridden token is restated in explicit-Light with the `:root` value; an alias of a theme-variant token is declared in all four blocks (`--sg-elev-inset` is the live witness). Each has planted violations (10 planted cases) that name the offending token.
- **One block parser.** `extract_css_block/2`, `extract_css_blocks/2`, `extract_sg_declarations/1` and `take_balanced_block/1` are public with the private functions' contracts, ready for plan 261-03 to delete the `admin_test.exs` copies.

## Task Commits

TDD tasks carry a RED and a GREEN commit; Task 3's invariants hold on the current stylesheet from the start, so its planted tests are the controls and it has one commit.

1. **Task 1: Tracer, body pair through parse, cascade, composite and ratio, plus planted bad colour**
   - RED `da64a8299` (test): 31 tests, all invalid because `Sigra.Test.Brand.CssContrast` did not exist (the plan's stated RED, "module missing")
   - GREEN `578e44655` (feat): 31 tests pass
2. **Task 2: Colour maths: rgba compositing, color-mix in srgb and oklab, fail-closed unresolved**
   - RED `f88b00f06` (test): 23 of 58 tests fail on missing `mix/4`, `oklab/1`, `from_oklab/1`, `unresolved_report/1`, `check_unresolved/2` and `color-mix` evaluation
   - GREEN `ede29263a` (feat): 60 tests pass
3. **Task 3: Token-block invariants with planted violations** - `9c01c01eb` (test): 16 tests pass

**Plan metadata:** the docs commit that follows this file (SUMMARY, then STATE and ROADMAP).

## Files Created/Modified

- `test/support/brand/css_contrast.ex` - `Sigra.Test.Brand.CssContrast`: `css_path/0`, `read_css/0`, the four extractors, `blocks/1`, `computed/2`, `resolve_color/2`, `resolve_hex/3`, `composite/2`, `to_hex/2`, `ratio/2`, `check_pair/4,5`, `mix/4`, `oklab/1`, `from_oklab/1`, `color_mix_expressions/1`, `unresolved_report/1`, `check_unresolved/2`
- `test/sigra/brand/css_contrast_test.exs` - `Sigra.Brand.CssContrastTest`, 60 tests, carries `@unresolved_allowlist []`
- `test/sigra/brand/token_parity_test.exs` - `Sigra.Brand.TokenParityTest`, 16 tests

## Decisions Made

See `key-decisions` in the frontmatter. In short: a two-level cascade rather than a flat merge; a rule tokenizer rather than substring search; invariant 3 closed over transitive aliases; the allowlist compared on unique selectors.

## Deviations from Plan

### Auto-fixed Issues

None. No bug, blocker or missing critical functionality was found in existing code; no shipped file was touched.

### Additions beyond the plan's listed surface

These are additive, within the plan's stated goal ("evaluates every colour shape the stylesheet uses", fail closed), and each has tests:

**1. [Rule 2 - Missing critical functionality] `color_mix_expressions/1` and a real-stylesheet scan**
- **Why:** the plan's success criteria require the instrument to evaluate every colour shape the stylesheet uses, and a fail-closed instrument that only checks planted strings proves little about the real file. Without it, the first unresolvable expression a later plan introduces would surface as a red in an unrelated pair test.
- **Fix:** a public pure extractor returns every outermost `color-mix(...)` with its rule selector (comments excluded, whitespace collapsed); two tests resolve all 39 expressions and every colour token in the six scopes against the empty allowlist, each with a non-vacuous count guard.
- **Files:** `test/support/brand/css_contrast.ex`, `test/sigra/brand/css_contrast_test.exs`
- **Commit:** `ede29263a`

**2. [Rule 2] `resolve_hex/3` and public `composite/2`**
- Convenience for plans 261-03 and 261-06 (resolve a token or expression and composite over an opaque ground in one call). `to_hex/2` is `composite/2` plus formatting; both are exercised by the compositing and body-pair tests.
- **Commit:** `578e44655`

**3. [Interpretation] Plan text conflicts, resolved without weakening anything**
- `unresolved_report/1` accepts both `{selector, value}` (behaviour list) and `{selector, value, computed}` (action text).
- `check_unresolved/2` compares unique selectors, so one selector unresolved in several scopes costs one allowlist entry; exact-match fail-closed behaviour in both directions is preserved and tested.
- Invariant 3 is closed over transitive aliases (alias of an alias), a strict superset of the UI-SPEC wording, with no false positive on the current stylesheet and a planted test for it.
- RED for Tasks 1 and 2 is "module or function missing", as the plan states; the format-based RED classifier (`gsd_run check tdd-red-evidence`) does not apply because the plan type is `execute` and ExUnit text is not one of its supported report formats. The RED evidence is the recorded failure counts above.

---

**Total deviations:** 0 auto-fixed bugs; 3 additive or interpretive notes (2 Rule 2 additions, 1 interpretation).
**Impact on plan:** none negative. All additions are test-support only and widen the fail-closed coverage; every plan acceptance criterion is met as written.

## Authentication Gates

None.

## Issues Encountered

- A credo nesting finding in `mix/4` (depth 3) was fixed by extracting `premultiplied_mix/4` before the GREEN commit.
- A compile-time warning about matching `0.0` on OTP 27+ in one test was fixed by asserting the alpha with `==`.
- Pre-existing, not mine and left untouched: `.planning/config.json` and `.planning/state.json` carried uncommitted changes before this plan started.

## Verification

- `mix test test/sigra/brand/css_contrast_test.exs test/sigra/brand/token_parity_test.exs test/sigra/brand/regen_guard_test.exs test/sigra/install/features/admin_test.exs`: green (the admin_test.exs D-11 parity tests are untouched and pass alongside the new invariants).
- Broader: `mix test test/sigra/brand test/sigra/planning test/sigra/install/features/admin_test.exs test/sigra/install/css_undefined_classes_test.exs`: 760 tests, 0 failures, 12 skipped.
- `mix format --check-formatted` clean on the three files; `mix credo --strict` reports no issues on them; `MIX_ENV=test mix compile --warnings-as-errors` clean.
- `grep -n "System\.\(get_env\|fetch_env\)"` over the three files prints nothing; `git diff --name-only <plan base>..HEAD` lists exactly the three `files_modified`; no path under `priv/` or `lib/`.

## Known Stubs

None.

## Threat Flags

None. The helper reads repo files only; no network, no environment, no new trust boundary. T-261-01 (resolver false green) is mitigated as planned: fail-closed `{:unresolved, reason}`, the committed (empty) allowlist, the planted bad colour and planted unresolvable controls, and non-empty guards on every real-file test.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Plans 261-03 and 261-04 must keep `TokenParityTest` and the existing D-11 parity tests green as they add `--sg-color-on-brand` and `--sg-color-brand` to the dark `@media` block, restate them in explicit-Light and explicit-Dark, and redefine `--sg-focus-ring` (it becomes an alias of a theme-variant token, so it must then appear in all four blocks). If invariant 2 or 3 goes red there, the stylesheet is wrong, not the test.
- Plan 261-03 Task 3 should delete the five private extractors in `admin_test.exs` and import `Sigra.Test.Brand.CssContrast`.
- Plan 261-06 builds the 30 book pairs and state pairs on `computed/2`, `resolve_hex/3`, `to_hex/2`, `check_pair/5` and `unresolved_report/1`. The `colour_token?/1` prefixes in the real-file scan already include `--sg-status-`. `@unresolved_allowlist` is `[]`; if a later plan introduces a colour the helper cannot evaluate, extend the helper rather than the allowlist.
- Any new file under `test/support/brand/` or `test/sigra/brand/` must not contain the literal environment-read text the RegenGuard scan looks for, even in a comment.

## Self-Check: PASSED

- FOUND: `test/support/brand/css_contrast.ex`, `test/sigra/brand/css_contrast_test.exs`, `test/sigra/brand/token_parity_test.exs`
- FOUND commits: `da64a8299`, `578e44655`, `f88b00f06`, `ede29263a`, `9c01c01eb` (all ancestors of HEAD)
- Measured: 5 commits since `plan_head_before` `129a7907e3edfb4795f5d981ba976f5416124ebc`

---
*Phase: 261-tokens-type-logo-favicon-and-contrast*
*Completed: 2026-11-15*
