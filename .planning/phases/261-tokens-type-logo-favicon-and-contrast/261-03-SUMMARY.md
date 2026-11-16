---
phase: 261-tokens-type-logo-favicon-and-contrast
plan: 03
subsystem: ui
tags: [brand, tokens, kiln, css-custom-properties, focus-ring, wcag, exunit, token-migration]

# Dependency graph
requires:
  - phase: 261-tokens-type-logo-favicon-and-contrast
    provides: "261-01 Sigra.Test.Brand.CssContrast (blocks/1, shared block extractors) and the three four-place token invariants"
provides:
  - 261-TOKEN-MIGRATION.md, the one reviewed old-to-new table (44 rows) read by a test
  - Sigra.Brand.TokenMigrationTest, table-to-stylesheet agreement with planted controls
  - Kiln token values live in all four blocks of sigra_admin.css, ten additive tokens, two-layer focus ring
  - admin-token-reference.md rows (110 tokens) re-pointed at brand/tokens.json
  - admin_test.exs pins read from brand/tokens.json and sigra_auth.css; one block parser remains
affects: [261-04, 261-06, 261-07, 261-08, 261-09, 261-10, 261-11, 262]

# Actuals (#2632) - same estimateTokens scale (chars/4 over the added lines of the realized diff)
actuals:
  tokens: 13865
  tasks: 3
  commits: 4
commits: 4
plan_head_before: 000e3aa743d4bacd06bafb949a918e926af88d8c
plan_head_after: 8db81b1e6772a4217e3bd5863dfd0a59928aa376

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "One reviewed old-to-new table committed beside the plan and enforced by a test that parses it (table and stylesheet cannot drift)"
    - "Pure row check over parsed table + parsed blocks, with an in-memory planted mismatch, so the check is seen to fire"
    - "Coverage by set equality derived from the stylesheet (no row-count threshold) with planted missing, duplicated and unexpected rows"
    - "Pins read their expectation from the pinned brand book (brand/tokens.json) or the sibling stylesheet, never a literal"

key-files:
  created:
    - .planning/phases/261-tokens-type-logo-favicon-and-contrast/261-TOKEN-MIGRATION.md
    - test/sigra/brand/token_migration_test.exs
  modified:
    - priv/templates/sigra.install/admin/sigra_admin.css
    - test/example/priv/static/assets/sigra_admin.css
    - guides/reference/admin-token-reference.md
    - guides/reference/admin-design-contract.md
    - test/sigra/install/features/admin_test.exs
    - .planning/phases/261-tokens-type-logo-favicon-and-contrast/deferred-items.md

key-decisions:
  - "Light values that equal the book value up to hex case (panel #ffffff, brand #c2410c, brand-strong #9a3412, on-brand #ffffff) are `kept` in the table and keep their lowercase bytes in the stylesheet; the test compares case-insensitively, so there is no churn for a case-only difference. New values are written upper-case as the book writes them."
  - "A `kept` dark cell with a literal old value is compared against BOTH dark blocks (stricter than the plan's Test 6 sentence, and what its Test 1 asks for), so an accidental edit of a kept dark tone fails. A `kept` + `inherited` dark cell only requires that a dark block, if it declares the token, agrees with the light value."
  - "--sg-focus-ring is `0 0 0 var(--sg-focus-ring-offset) var(--sg-color-subtle), 0 0 0 calc(var(--sg-focus-ring-offset) + 2px) var(--sg-color-brand-strong)` in all four blocks: a page-ground gap, then a 2px text-grade-accent ring that stays apart from a Kiln fill."
  - "The two weight rows that do not change (medium 600, semibold 700) take the disposition `kept, no book equivalent` because tokens.json has no weight token (the book states 400/600/700 in type rules); the Source cell says so."
  - "The /* sigra-admin-css: 1 */ version stamp is not bumped: no rule or selector changed, and the plan does not ask for it."

patterns-established:
  - "Phase-directory migration tables are located by wildcard under .planning/ so archiving the directory does not break the test, and exactly one match is required."
  - "Source-gap literals (dark selected #33281F from brand.json contrastPairs, dark control edge #8B7D72 from BRAND.md) are held once in the table and asserted against their named source."

requirements-completed: [BTOK-01, BTOK-07, BTOK-08]

# Coverage metadata (#1602)
coverage:
  - id: D1
    description: "One reviewed old-to-new table (44 rows: every colour, logo, weight and focus token :root declares at HEAD, the ten additive tokens, the two font tokens) with orange-family convergence, known deviations and not-edited sections"
    requirement: BTOK-01
    verification:
      - kind: other
        ref: "Task 1 <verify> command over 261-TOKEN-MIGRATION.md (every derived name has exactly one row; 44 rows, 32 derived from :root)"
        status: pass
      - kind: unit
        ref: "test/sigra/brand/token_migration_test.exs#has exactly one row per token the stylesheet declares, plus the two font tokens"
        status: pass
    human_judgment: false
  - id: D2
    description: "Kiln values applied by hand in all four blocks (light :root, dark @media, explicit Light, explicit Dark); table and stylesheet agree row by row under test; explicit Light restates brand and on-brand; dark @media and explicit Dark identical"
    requirement: BTOK-01
    verification:
      - kind: unit
        ref: "test/sigra/brand/token_migration_test.exs#every row's new light and dark values are what the four blocks declare"
        status: pass
      - kind: unit
        ref: "test/sigra/brand/token_parity_test.exs (three four-place invariants)"
        status: pass
      - kind: unit
        ref: "test/sigra/brand/css_contrast_test.exs (every colour token and color-mix resolves in all six scopes, empty allowlist)"
        status: pass
    human_judgment: false
  - id: D3
    description: "Ten additive tokens as literal hex in all four blocks, each with a doc row; no new sg-* class and no CSS consumer"
    requirement: BTOK-08
    verification:
      - kind: unit
        ref: "test/sigra/brand/token_migration_test.exs#the ten additive tokens are literal hex in all four blocks"
        status: pass
      - kind: other
        ref: "bash scripts/ci/admin-token-completeness.sh (PASS, 110 tokens, :root == doc)"
        status: pass
    human_judgment: false
  - id: D4
    description: "--sg-focus-ring redefined as the two-layer ring in all four blocks; every :focus-visible consumer in the template and app.css that has a ring reads the token"
    requirement: BTOK-01
    verification:
      - kind: unit
        ref: "test/sigra/brand/token_migration_test.exs#--sg-focus-ring is the two-layer ring in all four blocks"
        status: pass
    human_judgment: false
  - id: D5
    description: "Dark brand-strong pin reads brand/tokens.json, dark ember parity compares admin dark with sigra_auth.css dark, and admin_test.exs uses the shared block extractors (5 private copies deleted, 31 tests before and after); both pins proven to fire by mutation"
    requirement: BTOK-07
    verification:
      - kind: unit
        ref: "test/sigra/install/features/admin_test.exs (31 tests, 0 failures)"
        status: pass
    human_judgment: false
  - id: D6
    description: "Example stylesheet is a byte-identical cp of the template; conformance guard green; sigra_auth.css, Profile and Config untouched"
    requirement: BTOK-01
    verification:
      - kind: unit
        ref: "test/sigra/install/features/admin_test.exs#example copy is byte-identical to the installer template"
        status: pass
      - kind: other
        ref: "bash scripts/ci/admin-css-conformance.sh (PASS) and git diff --name-only -- priv/templates/sigra.install/core lib (empty)"
        status: pass
    human_judgment: false

# Metrics
duration: 8min
completed: 2026-11-16
status: complete
---

# Phase 261 Plan 03: Kiln Token Values Summary

**The Kiln values are live in both themes under unchanged token names: one reviewed 44-row old-to-new table applied by hand to all four blocks of sigra_admin.css (dark accent Kiln Bright with a Char label, weights 400/600/700/700, ten additive tokens, a two-layer focus ring), proven equal to the stylesheet row by row under test, documented against brand/tokens.json, with the two pinned admin_test assertions reading from source and one block parser left in the suite.**

## Performance

- **Duration:** about 8 min timed (from the first command to the last test run; the initial read of the plan and its inputs was not timed)
- **Started:** 2026-11-16T00:17:12Z
- **Completed:** 2026-11-16T00:26:00Z
- **Tasks:** 3 (Task 2 is TDD: RED and GREEN commits)
- **Files modified:** 8 (2 created, 6 modified; nothing under `lib/` or `priv/templates/sigra.install/core/`)

## Accomplishments

- **The table.** `261-TOKEN-MIGRATION.md` holds one seven-column row per token: the 32 colour, logo, weight and focus tokens `:root` declares at HEAD (derived by the verify command from the stylesheet, not counted by hand), the ten additive tokens and the two font tokens (44 rows). The two source-gap literals (dark selected `#33281F`, dark control edge `#8B7D72`) are cited once with their source. Three sections follow: orange-family convergence (which non-book oranges Phase 262 revisits), known deviations not adopted, and not-edited.
- **The values, in four places.** Neutrals map to Soot/Chalk, Paper/Char, Muted Soot/Muted Chalk, Char Surface and the now-opaque Paper Line/Char Line. Dark brand, brand-strong and brand-solid are Kiln Bright `#F08A55`; dark on-brand and on-brand-solid are Char `#17120F` (white on Kiln Bright is 2.48:1). Dark fill hover `#F4A27C` and fill active `#E07A45` are forced. Weights are 400/600/700/700. `--sg-logo-core` and `--sg-logo-rail-ember` follow the book. The explicit Light block gained `--sg-color-brand` and `--sg-color-on-brand`; dark `@media` and explicit Dark stay declaration-identical.
- **Additive tokens.** `--sg-status-active|unconfirmed|locked|deleting|suspended`, `--sg-color-selected`, `--sg-color-selected-edge`, `--sg-color-current-tab`, `--sg-color-sunken`, `--sg-color-control-edge`, each a literal hex in all four blocks, each with a doc row. No new class, no consumer (consumers are Phase 262).
- **Focus ring.** A page-ground gap of `--sg-focus-ring-offset`, then a 2px ring in `--sg-color-brand-strong`, declared in all four blocks (invariant 3). The old 35% halo was 1.67:1 on Paper.
- **Table cannot drift from CSS.** `Sigra.Brand.TokenMigrationTest` (13 tests) parses the table and compares each row with `:root`, the dark `@media` block, explicit Light and explicit Dark; coverage is a set equality derived from the stylesheet with planted missing, duplicated and unexpected rows; a planted mismatch is reported; every `brand/tokens.json` path a row cites resolves to a hex that row ships; the two source-gap literals are asserted against `brand.json` and `BRAND.md`.
- **Docs.** `admin-token-reference.md` has new values and `brand/tokens.json` paths for every changed token, "kept, no book equivalent" for the rest, a rewritten Dark AA note, a "Kiln Additions" section (ten rows) and a two-layer focus ring row; the completeness guard passes at 110 tokens. The design-contract dark brand-strong sentence points at the current value.
- **Pins and one parser (BTOK-07, first half).** The dark brand-strong pin builds its expectation from `brand/tokens.json` (`color.dark.kiln-bright`); the dark ember parity compares the admin dark `@media` value with the `sigra_auth.css` dark-block value after asserting both extractions are non-empty. The five private extractors in `admin_test.exs` are deleted and replaced by one `import` of the shared ones. Mutation controls confirmed both pins fire (a dark brand-strong of `#fdba74` in both dark blocks, and a one-digit change to the dark `@media` risk value) and the stylesheet was restored byte-for-byte.

## Task Commits

1. **Task 1: the reviewed old-to-new table** - `efee8ee05` (docs)
2. **Task 2: table-to-CSS agreement test, then the values in all four places**
   - RED `a5be033b7` (test): 13 tests, 5 failures, all on real table-versus-stylesheet mismatches (the planted-control tests pass by design)
   - GREEN `3dc853c0a` (feat): stylesheet plus byte-identical example copy; 13 tests pass
3. **Task 3: docs, the two pin rewrites and the extractor consolidation** - `8db81b1e6` (docs)

**Plan metadata:** the docs commit that follows this file (SUMMARY, deferred item, then STATE, ROADMAP and REQUIREMENTS).

## Files Created/Modified

- `.planning/phases/261-tokens-type-logo-favicon-and-contrast/261-TOKEN-MIGRATION.md` - the reviewed table (created)
- `test/sigra/brand/token_migration_test.exs` - `Sigra.Brand.TokenMigrationTest`, 13 tests (created)
- `priv/templates/sigra.install/admin/sigra_admin.css` - new values in four places, additive tokens, weights, two-layer focus ring
- `test/example/priv/static/assets/sigra_admin.css` - `cp` of the template
- `guides/reference/admin-token-reference.md` - value, rationale and brand-ref updates, ten new rows, rewritten AA note, 110-token baseline
- `guides/reference/admin-design-contract.md` - dark brand-strong note updated
- `test/sigra/install/features/admin_test.exs` - two pins rewritten, five private extractors removed, shared import added
- `.planning/phases/261-tokens-type-logo-favicon-and-contrast/deferred-items.md` - one out-of-scope observation logged

## Decisions Made

See `key-decisions` in the frontmatter. In short: case-only differences stay `kept` (no byte churn); `kept` dark cells are compared against both dark blocks; the focus ring gap uses `--sg-color-subtle`; unchanged book-compatible weights are `kept, no book equivalent` because tokens.json has no weight token; the stylesheet version stamp is not bumped.

## Focus consumers (Checker Addendum 7)

Every `:focus-visible` rule in the template and in the example `app.css`, and whether it reads `var(--sg-focus-ring)`:

| File | Selector | Reads the token |
|------|----------|-----------------|
| template | `.sg-theme-switch__button` | yes |
| template | `.sg-btn` | yes |
| template | `.sg-field-help__trigger` | yes |
| template | `.sg-applied-chip__remove` | yes |
| template | `.sg-notice__action` | yes |
| template | `.sg-metric[data-sg-metric-help-root]` | yes (`var(--sg-elev-1), var(--sg-focus-ring)`) |
| template | `.sg-metric-link` | yes |
| app.css | `.sg-scope-switch > summary` | yes |
| app.css | `.sg-input`, `.sg-select` | yes |
| app.css | `.sg-color-field__input` | yes |
| app.css | `.sg-tile` | yes |
| app.css | `.sg-posture-strip__risk` | yes |
| app.css | `.sg-scope-switch__item`, `.sg-nav-link` | no: hover tint with `outline: none`, no ring colour of its own (logged in deferred-items.md; Phase 262) |
| app.css | `.vt-*` (demo-owned) | out of scope |

No consumer set its own ring colour, so no consumer needed to be changed to the token: all of them inherit the new two-layer value.

## Deviations from Plan

### Auto-fixed Issues

None. No bug, blocker or missing critical functionality was found in existing code.

### Additions and interpretations (each within the plan's goal; none weakens a criterion)

**1. [Rule 2 - Missing critical functionality] Provenance tests beyond the seven the plan lists**
- **Why:** the plan's goal is "reviewed, tested, documented provenance". A table row citing a `tokens.json` path that does not exist, or one that resolves to a hex the row does not ship, would pass the table-to-CSS check and still mislead a reviewer.
- **Fix:** three added tests: every cited `color.*` path resolves and its hex is one the row ships (with a planted wrong hex and a planted missing path), the two literals `tokens.json` lacks match `brand.json` and `BRAND.md`, and each additive token has the disposition `additive`. 13 tests in total against a minimum of 7.
- **Files:** `test/sigra/brand/token_migration_test.exs`; **Commit:** `a5be033b7`

**2. [Interpretation] `kept` dark cells and the plan's Test 1 versus Test 6 wording**
- Test 1 says a `kept` cell must equal the Old column literal; Test 6 says `kept` cells are not compared against the dark blocks. Resolved by the stricter reading of Test 1: a `kept` dark cell with a literal old value is compared against both dark blocks, so an accidental edit of a kept dark tone fails. A `kept` + `inherited` dark cell requires only that a declaring dark block agrees with the light value.

**3. [Interpretation] Fixed disposition vocabulary versus unchanged book-compatible weights**
- `--sg-weight-medium` (600) and `--sg-weight-semibold` (700) are inside the book's allowed set, so "no book equivalent" reads oddly, but `brand/tokens.json` has no weight token and the vocabulary is fixed by the plan. They take `kept, no book equivalent` with a Source cell that says so.

**4. [Interpretation] Case-only differences**
- UI-SPEC writes `#FFFFFF (unchanged)` and `#C2410C (same)` where the stylesheet holds lowercase. These rows are `kept` and the lowercase bytes are untouched (the test compares case-insensitively), so the diff carries no churn for a case-only difference.

**5. [Interpretation] TDD gate evidence**
- The plan type is `execute`, so the format-based RED classifier does not apply; the RED evidence is the recorded failure count (5 of 13, on real mismatches) at `a5be033b7`. The planted-control tests pass against the old stylesheet by design, because they exercise the pure check, not the file.

---

**Total deviations:** 0 auto-fixed bugs; 1 Rule 2 addition and 4 interpretations.
**Impact on plan:** none negative. Every acceptance criterion is met as written.

## Authentication Gates

None.

## Issues Encountered

- A stray draft file was first written to a mistyped scratchpad path (outside the repo) and moved to the correct scratchpad immediately; nothing under the repo was affected.
- `mix format` rewrote one assertion in `admin_test.exs` into a form the compiler rejected (a pipe into `in`); fixed by binding the expected string first. The 31 admin_test tests are unchanged in count.
- Pre-existing, not mine and left untouched: `.planning/config.json` and `.planning/state.json` carried uncommitted changes before this plan started. One out-of-scope observation (two `app.css` focus rules with a tint only) is in `deferred-items.md`.

## Verification

- `mix test test/sigra/brand/ test/sigra/install/features/admin_test.exs`: 570 tests, 0 failures (this selection does not read the golden tree).
- `mix test test/sigra/brand/token_migration_test.exs test/sigra/brand/token_parity_test.exs test/sigra/brand/css_contrast_test.exs`: 89 tests, 0 failures. `mix test test/sigra/install/features/admin_test.exs test/sigra/brand/token_migration_test.exs`: 44 tests, 0 failures (31 + 13).
- `bash scripts/ci/admin-css-conformance.sh` PASS; `bash scripts/ci/admin-css-conformance.test.sh` 24 passed; `bash scripts/ci/admin-token-completeness.sh` PASS (110 tokens, `:root` == doc).
- `cmp` template and example stylesheet identical; `git diff --name-only <plan base>..HEAD -- priv/templates/sigra.install/core lib` prints nothing.
- `mix format --check-formatted` clean; `mix credo --strict` reports no issues on the two test files.
- Neighbouring suites run after the change: `css_undefined_classes_test`, `admin/components_test`, `architecture_guides_contract_test`, `branding_test`, `asset_parity_test`: 120 tests, 1 failure, the golden-copy leg of `asset_parity_test.exs` for `sigra_admin.css`, which is stale by design until plan 261-11's single rebless. `golden_diff_test` was not run (also golden-reading). No rebless was run here.

## Known Stubs

None. The ten additive tokens have no CSS consumer by design (consumers are Phase 262); they are defined, documented and tested token to token.

## Threat Flags

None. No network, auth, file-access or schema surface was added; the change is CSS values, tests and docs. T-261-04 (hand edit drifting from the reviewed table) is mitigated as planned: the agreement test with a planted mismatch, plus the four-place invariants in `token_parity_test`. T-261-05 (paths or names leaking): the Task 1 grep and a grep over every file this plan touched print nothing.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Plan 261-04 (fonts) flips the two `deferred:261-04` rows of the table to `additive` when it ships `--sg-font-sans` and `--sg-font-mono`, and adds their doc rows (the completeness guard then expects 112 tokens; update the "110" baseline sentence in `admin-token-reference.md`).
- Plan 261-06 builds the 30 book pairs and the state pairs on `CssContrast.computed/2` and `resolve_hex/3`; the new tokens (`--sg-status-*`, `--sg-color-selected`, `--sg-color-sunken`, `--sg-color-control-edge`) resolve in all six scopes already (the real-file scan in `css_contrast_test.exs` covers `--sg-color-*` and `--sg-status-*`).
- Plans 261-07 to 261-09 own the Playwright pins (`admin-generated.spec.ts`, `admin-theme.spec.ts`) and the example `app.css` control edges, which these tokens now enable.
- Plan 261-11 owns the single `MIX_ENV=test mix sigra.fixture.rebless_golden`; until then the golden copy of `sigra_admin.css` is stale and the golden-reading legs fail by design. Nothing is pushed before it is green.
- The `/* sigra-admin-css: 1 */` stamp is unchanged; revisit only if a later plan changes a selector or rule.

## Self-Check: PASSED

- FOUND files: `261-TOKEN-MIGRATION.md`, `test/sigra/brand/token_migration_test.exs`, `priv/templates/sigra.install/admin/sigra_admin.css`, `test/example/priv/static/assets/sigra_admin.css`, `guides/reference/admin-token-reference.md`, `guides/reference/admin-design-contract.md`, `test/sigra/install/features/admin_test.exs`
- FOUND commits (all ancestors of HEAD): `efee8ee05`, `a5be033b7`, `3dc853c0a`, `8db81b1e6`
- Measured: 4 commits since `plan_head_before` `000e3aa743d4bacd06bafb949a918e926af88d8c`
- All three tasks' acceptance criteria re-run: Task 1 verify command (VERIFY_PASS, 44 rows, 32 derived); Task 2 (13 tests, `grep -c "^  --sg-status-"` is 5, conformance exit 0, no diff under core/branding/config); Task 3 (completeness PASS, no `#fdba74` in admin_test.exs, 0 private extractor definitions, 4 matching token-reference rows, no diff under core).

---
*Phase: 261-tokens-type-logo-favicon-and-contrast*
*Completed: 2026-11-16*
