---
phase: 261-tokens-type-logo-favicon-and-contrast
plan: 04
subsystem: ui
tags: [brand, fonts, css-custom-properties, control-edge, table-header, wcag, exunit, token-docs]

# Dependency graph
requires:
  - phase: 261-tokens-type-logo-favicon-and-contrast
    provides: "261-03 Kiln token values in all four blocks, including the additive --sg-color-sunken and --sg-color-control-edge, and the reviewed migration table with two deferred:261-04 font rows"
  - phase: 261-tokens-type-logo-favicon-and-contrast
    provides: "261-02 sigra_admin_brand.css (the example's opt-in --sg-font-sans and --sg-font-mono values) and the vendored woff2 files"
  - phase: 261-tokens-type-logo-favicon-and-contrast
    provides: "261-01 Sigra.Test.Brand.CssContrast (blocks/1, computed/2, read_css/0)"
provides:
  - "--sg-font-sans (inherit) and --sg-font-mono (system mono stack) in the light :root only; no @font-face, no font binary"
  - "Selectors that apply them in the existing sg-components layer with no new class: shell family, control inheritance, mono for code, tabular numerals on table cells"
  - "Interactive-control edges in --sg-color-control-edge and the table header on --sg-color-sunken"
  - "Sigra.Brand.CssContractTest, a comment-stripped rule reader with planted controls and the arrow-glyph markup guard"
  - "Token reference rows for both font tokens with the opt-in book stack documented, not shipped"
affects: [261-07, 261-08, 261-10, 261-11, 262]

# Actuals (#2632) - same estimateTokens scale (chars/4 over the added lines of the realized diff)
actuals:
  tokens: 6702
  tasks: 3
  commits: 6
commits: 6
plan_head_before: 528950e574f273a0499997b24a961d4a118e79b7
plan_head_after: df5b8899a04299b84b194cd39434d9972bbc5488

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Rule-level CSS contract test: parse comment-stripped CSS into rules, find rules by an exact selector inside the comma list, assert declarations (not substrings), and plant a stylesheet that lacks the rule so the check is seen to fail"
    - "Fallback-form inheritance: a theme-invariant font token defaults to the CSS-wide keyword inherit, so the usage site supplies inheritance with var(--sg-font-sans, inherit)"
    - "Control edge versus divider: controls draw a 1px inset ring in the Control Edge token; surfaces keep the divider token"

key-files:
  created:
    - test/sigra/brand/css_contract_test.exs
  modified:
    - priv/templates/sigra.install/admin/sigra_admin.css
    - test/example/priv/static/assets/sigra_admin.css
    - test/example/priv/static/assets/css/app.css
    - guides/reference/admin-token-reference.md
    - .planning/phases/261-tokens-type-logo-favicon-and-contrast/261-TOKEN-MIGRATION.md
    - .planning/phases/261-tokens-type-logo-favicon-and-contrast/deferred-items.md

key-decisions:
  - "The table numeral declaration went into the existing combined rule for .sg-table-panel td/th and .sg-table td/th rather than a new rule, so there is one rule and no new selector; the contract test finds it through a rule that lists both selectors."
  - "The font rules sit together at the start of the existing ADMIN SHELL CHROME section (as the plan places them) instead of beside .sg-code, so every consumer of the two tokens is in one place."
  - "Decision 9 fallback was not exercised: the rule uses the plan's primary form var(--sg-font-sans, inherit). The browser computed-style probe that would trigger the one-line fallback belongs to plan 261-08."
  - ".sg-color-field__input and .sg-cmdk__trigger in app.css are controls with divider-grade edges but were left alone to honour the plan's one-line app.css numstat criterion; logged in deferred-items.md."

patterns-established:
  - "Contract tests assert non-empty results before content, so a renamed or dropped selector fails loudly instead of passing on nothing"
  - "Markup scanners fail closed: an unterminated element runs to the end of the text"

requirements-completed: [BTOK-06, BTOK-08]

# Coverage metadata (#1602)
coverage:
  - id: D1
    description: "--sg-font-sans (inherit) and --sg-font-mono (ui-monospace, 'SF Mono', Consolas, monospace) are declared once each in the light :root only, never in a theme block, with no @font-face in sigra_admin.css"
    requirement: BTOK-06
    verification:
      - kind: unit
        ref: "test/sigra/brand/css_contract_test.exs#font tokens (BTOK-06) the light :root declares each token once with the shipped default; no theme block restates it"
        status: pass
      - kind: unit
        ref: "test/sigra/brand/css_contract_test.exs#font tokens (BTOK-06) the stylesheet ships no @font-face rule; a comment that names it is not a rule"
        status: pass
    human_judgment: false
  - id: D2
    description: "The type selectors read the tokens through existing classes: .sg-admin-shell family with an inherit fallback, controls inherit, .sg-code and shell code take the mono token with ligatures off and a slashed zero, table cells use tabular numerals"
    requirement: BTOK-06
    verification:
      - kind: unit
        ref: "test/sigra/brand/css_contract_test.exs#font tokens (BTOK-06) (shell, controls, code, table numerals) with planted missing-rule controls"
        status: pass
      - kind: other
        ref: "bash scripts/ci/admin-css-conformance.sh (PASS) and test/sigra/install/css_undefined_classes_test.exs (no new class)"
        status: pass
    human_judgment: false
  - id: D3
    description: "Interactive controls (.sg-btn--secondary, .sg-btn--danger, .sg-filter-chip, .sg-theme-switch, and .sg-input and .sg-select in the example) draw their edge in --sg-color-control-edge; non-controls keep the divider edge"
    requirement: BTOK-08
    verification:
      - kind: unit
        ref: "test/sigra/brand/css_contract_test.exs#control edges (BTOK-08)"
        status: pass
    human_judgment: false
  - id: D4
    description: "The sticky table header reads --sg-color-sunken, which is an opaque six-digit hex in all six scopes"
    requirement: BTOK-08
    verification:
      - kind: unit
        ref: "test/sigra/brand/css_contract_test.exs#table header ground (BTOK-08)"
        status: pass
    human_judgment: false
  - id: D5
    description: "No arrow glyph (character, named entity or numeric reference) sits inside a code element or an .sg-code element in the admin markup, because Red Hat Mono has no arrows; the scanner is shown to fire on planted entity, numeric, literal and class-based cases"
    requirement: BTOK-06
    verification:
      - kind: unit
        ref: "test/sigra/brand/css_contract_test.exs#arrow glyph guard (BTOK-06)"
        status: pass
    human_judgment: false
  - id: D6
    description: "The font tokens are documented with the shipped default, the opt-in book stack and the no-font-binary note; the example stylesheet is a byte-identical copy; the migration table's font rows are additive"
    requirement: BTOK-06
    verification:
      - kind: other
        ref: "bash scripts/ci/admin-token-completeness.sh (PASS, 112 tokens, :root == doc) and cmp of template and example stylesheet"
        status: pass
      - kind: unit
        ref: "test/sigra/brand/token_migration_test.exs (13 tests)"
        status: pass
    human_judgment: false
  - id: D7
    description: "How the default (host-inherited) sans and the system mono stack actually render in a real browser, including that the shell inherits the host face with the fallback form"
    requirement: BTOK-06
    verification: []
    human_judgment: true
    rationale: "Inheritance through a custom property that holds a CSS-wide keyword is subtle; the oracle is a browser computed-style probe, which plan 261-08 owns. This plan asserts the declarations, not the rendered result."

# Metrics
duration: 6min
completed: 2026-11-16
status: complete
---

# Phase 261 Plan 04: Font Tokens, Control Edges and the Sunken Header Summary

**The two additive font tokens (host-inherited sans, system mono) and the selectors that apply them, interactive-control edges moved to the Control Edge token and the table header to the sunken ground, all as values on existing selectors with no new class, pinned by a 20-test rule-level contract file with planted controls and an arrow-glyph guard over the admin markup.**

## Performance

- **Duration:** about 6 min timed (from the first command after loading the plan to the last verification; the initial read of the plan and its inputs was not timed)
- **Started:** 2026-11-16T00:28:58Z
- **Completed:** 2026-11-16T00:35:39Z
- **Tasks:** 3 (Tasks 1 and 2 are TDD: RED and GREEN commits each; Task 1 is the tracer)
- **Files modified:** 7 (1 created, 6 modified; nothing under `lib/`, `brand/`, `.github/`, `priv/templates/sigra.install/core/` or `sigra_auth.css`)

## Accomplishments

- **Tracer.** One slice end to end first: the two font tokens in the light `:root`, applied through the shell, control, code and table-cell rules, proven by a contract test and the conformance guard before anything else was built. The tracer gate re-ran the plan's `<verify>` at the committed HEAD (10 tests, conformance PASS), then expansion continued.
- **Font tokens.** `--sg-font-sans: inherit` and `--sg-font-mono: ui-monospace, 'SF Mono', Consolas, monospace`, declared once each in the light `:root`, absent from the dark `@media` block and both explicit blocks. `sigra_admin.css` has no `@font-face` (count 0) and the installer still ships text only. The book stack stays opt-in and is documented.
- **Selectors, no new class.** `.sg-admin-shell` reads `var(--sg-font-sans, inherit)`; `.sg-admin-shell :is(button, input, select, textarea)` inherits it; `.sg-code, .sg-admin-shell code` take `var(--sg-font-mono)` with ligatures off and `font-feature-settings: "zero"`; table cells in both table families use tabular numerals. The css-undefined-classes baseline and the frozen-surface ratchet are green.
- **Control edges and header ground.** Four template controls moved from the divider shadow to `inset 0 0 0 1px var(--sg-color-control-edge)`; the example `.sg-input` and `.sg-select` border moved to the same token (one changed line in `app.css`); the sticky header reads `--sg-color-sunken`, and a test proves that token is an opaque hex in all six scopes.
- **Arrow guard.** `arrow_in_code/1` scans every `.ex`, `.heex` and `.eex` under `lib/sigra/admin` and `priv/templates/sigra.install/admin` (37 files) and returns no offender; it fires on a planted entity, numeric reference, literal arrow and an `.sg-code` element, and stays quiet on an arrow outside code, a look-alike class and a self-closing tag.
- **Docs and sync.** Token reference rows for both font tokens (default, opt-in stack, rationale, "the installer ships no font binary", Brand Ref `font.sans` and `font.mono`), a weights note (400, 600, 700 only), baseline now 112 tokens; the migration table's two font rows moved from `deferred:261-04` to `additive`; the example stylesheet is a byte-identical copy.

## Classified edge consumers (Task 2 `<read_first>`: every `--sg-elev-inset` and `--sg-color-line-strong` consumer)

Template `priv/templates/sigra.install/admin/sigra_admin.css` (line numbers at the plan base):

| Selector | Line | Edge token before | Disposition | Reason |
|----------|------|-------------------|-------------|--------|
| `.sg-theme-switch` | 582 | `--sg-elev-inset` | **moved** to control edge | the segmented control's boundary is its only edge (the plan names it) |
| `.sg-btn--secondary` | 789 | `--sg-elev-inset` | **moved** | interactive; the boundary is its only edge on a white panel |
| `.sg-btn--danger` | 804 | `--sg-elev-inset` | **moved** | interactive, transparent ground, the edge is the only boundary |
| `.sg-filter-chip` | 1005 | `--sg-elev-inset` | **moved** | interactive checkbox or radio chip, the edge is its boundary |
| `.sg-status-pill`, `.sg-badge` | 671 | `--sg-elev-inset` | kept | read-only status; a divider-grade edge is right |
| `.sg-list-row` | 1293 | `--sg-elev-inset` | kept | container row, not a control |
| `.sg-notice` | 1345 | `--sg-elev-inset` | kept | container, not a control |
| `.sg-empty-state` | 1393 | dashed `--sg-color-line-strong` | kept | empty-state container, not a control |
| `.sg-metric-link:active` | 1700 | `--sg-elev-inset` | kept | a pressed-state shadow on a link card that has no resting edge, not a control boundary |
| `.sg-table th` rules, table row rules | 1081 | `--sg-color-line` | kept | dividers |

Example `app.css` (read for classification; one line changed):

| Selector | Disposition |
|----------|-------------|
| `.sg-input`, `.sg-select` (line 2017) | **moved** to `--sg-color-control-edge` (the plan's one changed line) |
| `.sg-color-field__input` (2067, line-strong), `.sg-cmdk__trigger` (2392, line) | controls with divider-grade edges; **not changed** (plan scope), logged in `deferred-items.md` |
| `.sg-posture-strip` (2203), `.sg-capability__item` (2226) | kept, containers |
| `.sg-breadcrumb__sep` (1917), table and card dividers | kept |

## Task Commits

1. **Task 1 (tracer): font token pair applied through the existing selectors, proven by a contract test**
   - RED `4707a2d96` (test): 10 tests, 5 failures, all on the missing tokens and rules; the rule-reader controls and the `@font-face` check pass by design
   - GREEN `ecf05f1b2` (feat): 10 tests pass, conformance PASS, 2 font tokens
2. **Task 2: control edges, sunken header, arrow-glyph guard**
   - RED `fe3f3c6a7` (test): 20 tests, 3 failures, all on the pending edits (the example `app.css` parsed, so the failure is the declaration, not the reader)
   - GREEN `a56ad8563` (feat): five template lines and one `app.css` line; 20 tests pass
3. **Task 3: example copy, font token docs, migration rows** - `e3718fe8a` (docs)
4. **Comment and doc correction (deviation 1 below)** - `df5b8899a` (docs)

**Plan metadata:** the docs commit that follows this file (SUMMARY, deferred item, then STATE, ROADMAP and REQUIREMENTS).

## Files Created/Modified

- `test/sigra/brand/css_contract_test.exs` - `Sigra.Brand.CssContractTest`, 20 tests (created)
- `priv/templates/sigra.install/admin/sigra_admin.css` - two font tokens, three shell and code rules, tabular numerals, four control edges, the sunken header, a corrected token comment
- `test/example/priv/static/assets/sigra_admin.css` - `cp` of the template (byte-identical)
- `test/example/priv/static/assets/css/app.css` - the `.sg-input`, `.sg-select` border colour only (1 line added, 1 removed)
- `guides/reference/admin-token-reference.md` - two font rows, weights note, 112-token baseline, corrected consumer note
- `.planning/phases/261-tokens-type-logo-favicon-and-contrast/261-TOKEN-MIGRATION.md` - font rows `additive`, corrected consumer note
- `.planning/phases/261-tokens-type-logo-favicon-and-contrast/deferred-items.md` - three out-of-scope observations

## Decisions Made

See `key-decisions` in the frontmatter. In short: numerals joined the existing table-cell rule; the type rules are grouped in the shell chrome section; the decision-9 fallback form was not needed here; two app.css controls were left for a later change to honour the plan's one-line criterion.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Stale "no rule consumes the additive tokens" notes**
- **Found during:** SUMMARY drafting after Task 3
- **Issue:** this plan gave `--sg-color-sunken` and `--sg-color-control-edge` consumers, but the template token-block comment, the token reference ("no rule in the stylesheet consumes them yet") and the migration table ("no CSS consumer in this phase") still said none of the ten additive tokens had one. A false statement caused by this plan's own change.
- **Fix:** reworded all three to say two have consumers (the table header and interactive-control edges) and the other eight do not yet; the stylesheet change is a comment only and the example copy was re-synced byte for byte.
- **Files modified:** `priv/templates/sigra.install/admin/sigra_admin.css`, `test/example/priv/static/assets/sigra_admin.css`, `guides/reference/admin-token-reference.md`, `261-TOKEN-MIGRATION.md`
- **Verification:** `cmp` identical, completeness PASS (112), conformance PASS, 602 tests green
- **Committed in:** `df5b8899a`

### Additions and interpretations (each within the plan's goal; none weakens a criterion)

**2. [Rule 2 - Missing critical functionality] Tests beyond the twelve the plan asks for**
- The plan asks for at least 7 then 12 tests. The file has 20: the rule reader gets its own four controls (nesting, a comma inside `:is(...)`, an absent selector, a selector that appears only in a comment), plus a planted control for every assertion, a non-control test (status pill, badge, list row, notice and the dashed empty state keep the divider edge), and the opacity check for the sunken ground. Without the reader controls a parser that returns nothing would pass every "declares" assertion.
- **Committed in:** `4707a2d96`, `fe3f3c6a7`

**3. [Interpretation] Intermediate commits are not individually green for two unrelated guards**
- By the plan's task order, the example stylesheet copy and the token reference rows land in Task 3, so at the Task 1 and Task 2 commits the byte-identity test in `admin_test.exs` and `admin-token-completeness.sh` are expected to be red; each task's own `<verify>` is green, and Task 3 restores both. These intermediate commits were not separately run against those two guards.

**4. [Interpretation] TDD gate evidence**
- The plan type is `execute`, so the format-based RED classifier does not apply; RED evidence is the recorded failure counts at `4707a2d96` (5 of 10) and `fe3f3c6a7` (3 of 20), each on a real missing rule or declaration.

**5. [Interpretation] Weight rows**
- The plan allows updating the regular and bold rows "if 261-03 left stale prose"; both were already correct, so only the intro sentence changed to state that the book allows 400, 600 and 700 only. The medium and semibold rows still cite `typography.weight.*` paths that `tokens.json` lacks; that is part of the wider pre-existing Brand Ref staleness logged in `deferred-items.md`.

---

**Total deviations:** 1 auto-fixed (Rule 1), 1 Rule 2 addition, 3 interpretations.
**Impact on plan:** none negative. Every acceptance criterion is met as written.

## Authentication Gates

None.

## Issues Encountered

- The contract test parses the whole example `app.css` to reach one rule, and that file has a known stray-comment hazard that silently drops the next rule. Both checks came out clean: the Task 2 RED run found the `.sg-input, .sg-select` rule before failing on its declaration (so the parse reaches it), and `scripts/ci/app-css-corruption-check.sh` is green after the edit.
- Pre-existing, not mine and left untouched: `.planning/config.json` and `.planning/state.json` carried uncommitted changes before this plan started and were never staged.

## Verification

- `mix test test/sigra/brand/ test/sigra/install/features/admin_test.exs test/sigra/install/css_undefined_classes_test.exs`: 602 tests, 0 failures. `mix test test/sigra/brand/css_contract_test.exs`: 20 tests, 0 failures. `test/sigra/brand/token_migration_test.exs`: 13 tests, 0 failures. `test/sigra/brand/frozen_surface_test.exs` is in `test/sigra/brand/` and green.
- `bash scripts/ci/admin-css-conformance.sh` PASS; `bash scripts/ci/admin-css-conformance.test.sh` and `admin-token-completeness.test.sh` PASS; `bash scripts/ci/admin-token-completeness.sh` PASS (112 tokens, `:root` == doc); `bash scripts/ci/app-css-corruption-check.sh` PASS.
- `cmp` template and example stylesheet identical. Acceptance counts: font tokens `grep -c "^  --sg-font-"` is 2; `sg-color-control-edge` in the template is 9 (four token declarations, four consumers, one comment mention) against a floor of 8; `app.css` numstat against the plan base is `1 1`; `@font-face` in the template is 0; deferred font rows 0.
- Neighbouring suites: `architecture_guides_contract_test` and the phase 198, 233 and 260 contract tests: 31 tests, 0 failures. `asset_parity_test`, `test/sigra/templates`, `test/sigra/admin`, `branding_test`: 280 tests, 1 failure, the golden-copy leg of `asset_parity_test.exs` for `sigra_admin.css`, which is stale by design until plan 261-11's single rebless. `golden_diff_test` was not run (also golden-reading). No rebless was run here.
- `mix format --check-formatted` clean; `mix credo --strict` reports no issues on the new test file. No Elixir file under `test/example/` changed, so the example compile check was not needed.
- Privacy grep over the added text lines (home paths, personal handles, local file URLs): nothing. Diff against the plan base under `priv/templates/sigra.install/core`, `lib`, `brand`, `.github` and `sigra_auth.css`: empty.

## Known Stubs

None. The eight additive tokens that still have no consumer (`--sg-status-*`, `--sg-color-selected`, `--sg-color-selected-edge`, `--sg-color-current-tab`) are defined, documented and tested token to token by design; their consumers are Phase 262.

## Threat Flags

None. The change is CSS values and selectors, one example border colour, tests and docs; no network, auth, file-access or schema surface was added. T-261-06 (raw hex or px outside token blocks, or a new undefined class) is mitigated as planned: `admin-css-conformance.sh` and `css_undefined_classes_test.exs` are green at every task and in the plan-level verification. T-261-SC accepted: no package-manager install and no font binary reached the installer.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Plan 261-08 owns the browser computed-style probe for decision 9: with default tokens the computed `font-family` of `.sg-admin-shell`, a `.sg-btn`, an `input` and `code.sg-code` must equal the host body font (sans) and the system mono stack. If the probe shows the `, inherit` fallback form does not inherit, the one-line change is `font-family: var(--sg-font-sans)` on `.sg-admin-shell`; `css_contract_test.exs` pins the current form and would need the same one-line edit.
- Plan 261-07 and 261-08 can assert the real-DOM control edge (`.sg-input`, `.sg-select`, `.sg-btn--secondary`) at 3:1 now that the token is applied; `.sg-color-field__input` and `.sg-cmdk__trigger` are not asserted until they move (see `deferred-items.md`).
- Plan 261-10's token-doc sweep inherits a docs baseline of 112 tokens and the sentence that two of the ten additive tokens have consumers.
- Plan 261-11 owns the single `MIX_ENV=test mix sigra.fixture.rebless_golden`; until then the golden copy of `sigra_admin.css` is stale and the golden-reading legs fail by design.
- The `/* sigra-admin-css: 1 */` stamp is unchanged; new rules were added but no selector the stamp guards was renamed or removed.

## Self-Check: PASSED

- FOUND files: `test/sigra/brand/css_contract_test.exs`, `priv/templates/sigra.install/admin/sigra_admin.css`, `test/example/priv/static/assets/sigra_admin.css`, `test/example/priv/static/assets/css/app.css`, `guides/reference/admin-token-reference.md`, `261-TOKEN-MIGRATION.md`, `deferred-items.md`
- FOUND commits (all ancestors of HEAD): `4707a2d96`, `ecf05f1b2`, `fe3f3c6a7`, `a56ad8563`, `e3718fe8a`, `df5b8899a`
- Measured: 6 commits since `plan_head_before` `528950e574f273a0499997b24a961d4a118e79b7`
- All three tasks' acceptance criteria re-run at the final HEAD: Task 1 (20 tests in the file, conformance exit 0, 2 font tokens); Task 2 (20 tests, 9 control-edge references, numstat `1 1`, consumers listed above); Task 3 (completeness PASS, `cmp` ok, font rows name the opt-in stack and the no-binary note, deferred count 0, `token_migration_test` 13 green)

---
*Phase: 261-tokens-type-logo-favicon-and-contrast*
*Completed: 2026-11-16*
