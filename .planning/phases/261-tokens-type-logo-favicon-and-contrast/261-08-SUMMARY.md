---
phase: 261-tokens-type-logo-favicon-and-contrast
plan: 08
subsystem: testing
tags: [playwright, axe, contrast, wcag-1-4-11, theme-matrix, font-tokens, real-dom]

# Dependency graph
requires:
  - phase: 261-tokens-type-logo-favicon-and-contrast
    provides: "261-03/04 the Kiln token values and the opt-in font tokens, 261-05 the v2 lockups, 261-07 helpers/brandSource.ts, brandFonts.ts, brandContrast.ts, 261-12 the repointed Rail Accent preset"
provides:
  - "admin-design.spec.ts: the axe gate records the incomplete count and rule ids from the same analyze() result as an axe-incomplete annotation (never asserted, never subtracted)"
  - "admin-design.spec.ts: an untagged non-text 3:1 test (focus ring, control edge, logo square) with a positive control and an exact measurement count, run in all three design projects"
  - "admin-theme.spec.ts: a six-combination theme matrix, a font default and opt-in computed-style probe, and a topbar overflow check at 375 and 390 wide"
  - "A recorded real run of every spec this phase touched or moved tokens under, against a booted example app on port 4011 with SIGRA_PNG_COMPARE_SKIP=1"
affects: [261-10, 261-11, 262]

# Actuals (#2632) - same estimateTokens scale (chars/4 over the added lines of the realized diff)
actuals:
  tokens: 3970
  tasks: 3
  commits: 3
commits: 3
plan_head_before: 85ecaf36b5354a19a2bbffe954265db70a23cc5d
plan_head_after: ed62f49bcc8e2192dcd59d68e7c310c340c3cda4

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Record what a gate cannot decide (axe incomplete) as an annotation from the same result, and never let it count as a pass"
    - "A real-DOM check carries a positive control and an exact measurement count so a missing element or colour cannot pass vacuously"
    - "Read computed colours only after the element's transitions have finished (getAnimations().finished), never a frame mid-transition"
    - "A new check is proven non-vacuous by planting a defect in the example's copy of the stylesheet, watching it fail, and restoring the copy byte for byte"

key-files:
  created: []
  modified:
    - test/example/priv/playwright/tests/admin-design.spec.ts
    - test/example/priv/playwright/tests/admin-theme.spec.ts

key-decisions:
  - "The axe test's TestInfo comes from test.info() inside assertNoAxeViolations, not from a new parameter: the phase 230 and phase 260 contract tests pin the axe test declaration line (`async ({ page }) => {`) verbatim, so changing the call site would have gone red for no behavioural reason"
  - "The dark primary hover contrast test now waits for the element's transitions to finish before reading colours; the 4.5 threshold is unchanged. With the Kiln tokens the label changes from white (light) to near-black (dark) across the theme switch, so a read during the 140ms tone transition measured a frame nobody sees (1.2 to 3.5)"
  - "No template stylesheet change: every real-DOM check passed against the shipped CSS, so the documented font fallback (drop the inherit fallback) was not needed and the template and example copy stay byte-identical"

patterns-established:
  - "The theme matrix drives the shown theme by setting or removing data-sg-admin-theme on html and data-theme on the shell, with prefers-color-scheme emulated, so the two combinations a missing explicit-block declaration breaks (OS light with Dark chosen, OS dark with Light chosen) are exercised without clicking"
  - "Chromium serialises a custom-property value with var() substituted at the element that declares it, so a ring declared on :root is stale on the shell under an explicit theme: the matrix reads --sg-focus-ring on the shell and so catches the missing restatement"

requirements-completed: [BTOK-03, BTOK-06, BTOK-01]

# Coverage metadata (#1602)
coverage:
  - id: D1
    description: "The axe gate stays green on /admin/_design in the light, mobile and dark design projects and records the incomplete count and rule ids from the same analyze() result as an annotation; incomplete is never asserted or subtracted"
    requirement: BTOK-03
    verification:
      - kind: automated_ui
        ref: "playwright admin-design.spec.ts 'axe: full-page WCAG 2.1/2.2 AA on the design gallery' on admin-design-chromium, -mobile, -dark (45 passed with the three setup projects); node --test scripts/ci/prohibitions/p02-axe-signal-not-reduced.test.mjs 4 pass"
        status: pass
    human_judgment: false
  - id: D2
    description: "Non-text 3:1 holds in the real DOM in both themes: focus ring of a focused .sg-btn--secondary and .sg-input against page and panel, control edge of .sg-input and .sg-btn--secondary against panel, the shown logo square against page; positive control and an exact measurement count"
    requirement: BTOK-03
    verification:
      - kind: automated_ui
        ref: "playwright admin-design.spec.ts 'non-text 3:1: focus ring, control edge and logo square' on all three design projects; measured 6.61/7.31 light and 7.50/6.85 dark ring, 4.42 light and 4.26 dark edge, 4.69 light and 7.50 dark logo square; planted pale control edge fails at 1.48"
        status: pass
    human_judgment: false
  - id: D3
    description: "A six-combination theme matrix (OS scheme x admin choice) asserts the shown theme drives --sg-color-brand, --sg-color-on-brand, --sg-focus-ring and the lockup opacity, including OS light with Dark chosen and OS dark with Light chosen"
    requirement: BTOK-01
    verification:
      - kind: automated_ui
        ref: "playwright admin-theme.spec.ts 'theme matrix: shown theme drives brand tokens, focus ring and lockup' on chromium; planted removal of the explicit-dark --sg-focus-ring fails with 'OS light, admin choice dark: --sg-focus-ring gap layer'"
        status: pass
    human_judgment: false
  - id: D4
    description: "With default tokens the admin shell, a .sg-btn and an input resolve to the host body face and code.sg-code to the system mono stack; with the example stylesheet present the shell is Instrument Sans, code is Red Hat Mono and both book faces load"
    requirement: BTOK-06
    verification:
      - kind: automated_ui
        ref: "playwright admin-theme.spec.ts 'font tokens: defaults inherit the host face and the example opts in' on chromium; planted shell font-family and planted root --sg-font-sans each fail the probe"
        status: pass
    human_judgment: false
  - id: D5
    description: "No horizontal overflow of the topbar at 375 and 390 wide, and the lockup keeps its 96px minimum; the existing board responsive overflow test stays green with the example's Red Hat Mono stack"
    requirement: BTOK-01
    verification:
      - kind: automated_ui
        ref: "playwright admin-theme.spec.ts 'topbar does not overflow at 375 and 390 wide' on chromium; admin-design.spec.ts 'component and group boards do not overflow at required responsive widths' on the three design projects"
        status: pass
    human_judgment: false
  - id: D6
    description: "Every spec this phase changed or moved tokens under passes whole against a booted example: admin-theme 22, untagged admin-design 14 per project (45 with setup), demo-showcase 4, admin-eval 192"
    requirement: BTOK-03
    verification:
      - kind: e2e
        ref: "the plan's automated verify, an && chain of four playwright runs against http://localhost:4011 with SIGRA_PNG_COMPARE_SKIP=1, exit 0 (VERIFY_EXIT=0)"
        status: pass
    human_judgment: false
  - id: D7
    description: "axe incomplete is recorded, not counted as a pass: two rules (aria-prohibited-attr, color-contrast) are undecided on the design gallery in every design project"
    requirement: BTOK-03
    verification:
      - kind: automated_ui
        ref: "axe-incomplete annotation on the three axe tests: '2: aria-prohibited-attr, color-contrast'"
        status: unknown
    human_judgment: true
    rationale: "Incomplete means axe could not decide, not that the surface is clean. Whether the color-contrast unknowns are the translucent topbar and alpha-ground chips the ExUnit contrast pairs composite exactly, and what the aria-prohibited-attr unknown is, needs a person (or a follow-up that names the nodes); this plan records it and by design does not resolve it"

# Metrics
duration: 45min
completed: 2026-11-16
status: complete
---

# Phase 261 Plan 08: Real-DOM Contrast, Theme Matrix and Font Probe Summary

**The existing axe gate now records what it cannot decide, a non-text 3:1 test measures the focus ring, control edge and logo square in both themes, a six-combination theme matrix proves the shown theme drives the brand tokens, focus ring and lockup, and a computed-style probe proves the font defaults, all run whole against a booted example app with no template change needed.**

## Performance

- **Duration:** about 45 min (2026-11-16T01:09:47Z to the SUMMARY write), most of it two full runs of the 192-test eval file (11 to 14 min each)
- **Tasks:** 3 (Task 1 tracer, Task 2 and Task 3 auto)
- **Files modified:** 2 specs, both existing and both under `test/example/priv/playwright/tests/`. `helpers/brandContrast.ts` is listed in the plan's `files_modified` but was reused as is. No byte under `lib/`, `priv/templates/`, `scripts/`, `.github/`, `brand/`, the example stylesheets, `spec-ownership.json` or `playwright.config.ts` changed, and no screenshot file was touched.
- **Playwright listing:** `npx playwright test --list` exits 0 and prints `Total: 400 tests in 22 files` (394 after plan 261-07, plus 3 non-text tests across the three design projects, plus 3 new admin-theme tests).

## Accomplishments

- **axe incomplete, recorded and never counted.** `assertNoAxeViolations` destructures `incomplete` from the same `analyze()` result and pushes an `axe-incomplete` annotation (`count: sorted rule ids`). The violations assertion is untouched, `incomplete` is never an argument of `expect`, and the helper keeps its `wcag2a, wcag2aa, wcag21a, wcag21aa, wcag22aa` tags and no `.include()`.
- **Non-text 3:1 (WCAG 1.4.11) in the real DOM.** One untagged test, so it runs on the PR lane in all three design projects. It reads the page and panel grounds from probe elements carrying `var(--sg-color-subtle)` and `var(--sg-color-panel)`, focuses an enabled `.sg-btn--secondary` and an `.sg-input` by Tab (programmatic focus fallback), asserts `:focus-visible`, takes the last box-shadow layer as the ring, reads the resting control edges, and reads the shown logo square from the fetched SVG. Positive control: identical colours are below 3. Measured colours are counted (7, or 8 when a `.sg-select` is on the gallery; none is, so 7). Measured ratios match the UI-SPEC table:

  | Check | Light | Dark |
  |-------|-------|------|
  | Focus ring vs page, secondary and input | 6.61 | 7.50 |
  | Focus ring vs panel, secondary and input | 7.31 | 6.85 |
  | Control edge, `.sg-input` and `.sg-btn--secondary`, vs panel | 4.42 | 4.26 |
  | Logo square vs page | 4.69 | 7.50 |

- **Theme matrix.** Six combinations of OS scheme and admin choice, each asserting `--sg-color-brand`, `--sg-color-on-brand`, `--sg-focus-ring` (both layers) and the lockup opacity (polled, since the swap is a 140ms transition) against `tokenValue(shown, ...)` read from the template stylesheet. A guard asserts the two themes differ for `--sg-color-subtle` and `--sg-color-brand-strong`, so the ring assertion can tell them apart, and the loop count is asserted to be 6.
- **Font probe.** With the opt-in stylesheet present the shell is Instrument Sans and differs from its parent, code is Red Hat Mono. With the `sigra_admin_brand` link removed, the shell equals its parent's face (the host's Space Grotesk stack), `.sg-btn` and an `input` equal the shell, and `code.sg-code` contains `ui-monospace`. The link is restored and both book faces are asserted loaded. The documented fallback in the template was not needed.
- **Topbar overflow.** At 375 and 390 wide, `scrollWidth` does not exceed `innerWidth` and the lockup keeps at least 96px.
- **Whole files, real run.** See Verification.

## Task Commits

1. **Task 1: Tracer, record axe incomplete and add the non-text 3:1 test** - `26f46ee11` (test). Tracer feedback gate: config auto mode off, `human_verify_mode` end-of-phase, the `<verify>` is automated only, so it was re-run (listing exit 0, 3 `non-text 3:1` entries); `Tracer verified end-to-end - expanding`.
2. **Task 2: Theme matrix, font probe and topbar overflow** - `2d0a32220` (test)
3. **Task 3: Run the whole touched specs against a booted app** - `ed62f49bc` (test), the one defect the run revealed (a racy existing contrast test, below). No template change.

**Plan metadata:** the docs commit that follows this file (SUMMARY, STATE, ROADMAP, REQUIREMENTS).

## Verification

Server: `MIX_ENV=dev`, `PORT=4011` exported for the compile and for `mix phx.server`, a dedicated database on the ephemeral test Postgres (dropped afterwards), migrated and seeded as the shared boot action does. The stale example build (compiled with port 4000) was removed from `test/example/_build/dev/lib/example` (gitignored) so the compile-time port matched. The server was stopped by its recorded PID only after the final verify passed; `lsof -ti :4011` then printed nothing.

All with `SIGRA_EXAMPLE_URL=http://localhost:4011 SIGRA_PNG_COMPARE_SKIP=1`, `--retries=0`, no `--grep` subset in the acceptance run, never `--update-snapshots`:

| Command | Result |
|---------|--------|
| `admin-theme.spec.ts --project=chromium` (whole file) | 22 passed (19 existing, including 'overview notice action link is visibly actionable' and 'keeps primary button hover contrast readable in dark mode', plus 3 new) |
| `admin-design.spec.ts` on `admin-design-chromium`, `-mobile`, `-dark`, `--grep-invert '@snapshot'` | 45 passed: 14 per project plus the 3 setup projects; the 28 `@snapshot` board compares are not run |
| `demo-showcase.spec.ts --project=demo-showcase-chromium` | 4 passed, 0 skipped (includes the Rail Accent preset logo src assertion repointed by plan 261-12) |
| `admin-eval.spec.ts` on `admin-eval`, `admin-eval-mobile`, `admin-eval-dark` | 192 passed (64 per project) |

The plan's automated verify, an `&&` chain of the four, exits 0 (`VERIFY_EXIT=0`).

**axe `incomplete`, recorded, not counted as a pass** (from the `--reporter=json` run of command 2, exit 0; the incomplete count is the number of rules axe could not decide):

| Project | Incomplete rules | Rule ids |
|---------|------------------|----------|
| `admin-design-chromium` | 2 | `aria-prohibited-attr`, `color-contrast` |
| `admin-design-mobile` | 2 | `aria-prohibited-attr`, `color-contrast` |
| `admin-design-dark` | 2 | `aria-prohibited-attr`, `color-contrast` |

The `color-contrast` unknowns are the kind the UI-SPEC predicted (the translucent topbar, alpha-ground chips). The `aria-prohibited-attr` unknown was not predicted and nothing here names the nodes. Both are unknown, not clean.

**Controls (the new checks are not vacuous).** Each defect was planted in the example's copy of the stylesheet only (never the template), the named test was run and watched fail, and the copy was restored (`cmp` against the template exits 0):

- Removing the explicit-dark `--sg-focus-ring` restatement: the matrix fails with `OS light, admin choice dark: --sg-focus-ring gap layer`. (Removing it from the `@media (prefers-color-scheme: dark)` `:root` block does not fail, correctly: `:root` substitutes `var()` on the same element that holds the dark tokens. The restatement only matters in the explicit blocks that apply to `.sg-admin-shell`, a different element.)
- A pale control edge (`#DDD3C8`): the non-text test fails with `control edge of .sg-input vs panel must reach 3:1` at 1.48.
- `.sg-admin-shell { font-family: Georgia }` and, separately, `:root { --sg-font-sans: Georgia }`: the font probe fails at the opt-in and the default assertion respectively.

Other checks: `node --test scripts/ci/prohibitions/p02-axe-signal-not-reduced.test.mjs` 4 pass; `mix test` over the phase 230, 232, 234, 235 and 260 planning contract tests 0 failures; `git diff --name-only -- .github spec-ownership.json playwright.config.ts brand` and `git status --short -- *-snapshots` print nothing; no home path, user name or authoring origin in the diff.

## Decisions Made

See `key-decisions`. In short: `test.info()` instead of a new parameter (contract tests pin the declaration line), the hover contrast test reads the settled state, and no template change was needed.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] The axe TestInfo comes from `test.info()`, not a new parameter**
- **Found during:** Task 1
- **Issue:** The plan asked `assertNoAxeViolations` to take `TestInfo` and the axe test call site to pass `testInfo`. That changes the axe test's declaration line to `async ({ page }, testInfo) => {`, which `phase_230_design_gallery_split_test.exs` ("the full-page axe test exists and is untagged") and `phase_260_png_park_contract_test.exs` ("the untagged design-gallery axe test is still present") pin verbatim; both went red.
- **Fix:** The helper reads `test.info().annotations` and the call site and declaration line are unchanged. Same recorded annotation, same single analyze() result.
- **Files modified:** `test/example/priv/playwright/tests/admin-design.spec.ts`
- **Verification:** both contract tests and the P02 prohibition test pass; the annotation is present in all three projects.
- **Commit:** `26f46ee11`

**2. [Rule 1 - Bug] The dark primary hover contrast test read a mid-transition frame**
- **Found during:** Task 3 (the plan's verify chain, first full run)
- **Issue:** 'keeps primary button hover contrast readable in dark mode' (an existing test the plan runs whole) failed at 3.49 against the 4.5 bar, and failed in at least 7 of 12 repeated runs (1.2 to 3.5). It passed in the first whole-file run, by timing. It clicks Dark, hovers, then reads computed colours at once, inside the 140ms `--sg-transition-tone` colour transition. With the Kiln tokens the label changes from white (light on-brand) to near-black (dark on-brand `#17120F`) across the switch, so the mid-transition frame has both endpoints' average. This is a test race, not a wrong settled colour.
- **Fix:** wait for the element's animations to finish (`getAnimations().finished`) before reading. The 4.5 threshold is unchanged. 15 of 15 repeated runs pass; the new tests and the other contrast tests (30 runs across 5 tests) pass.
- **Files modified:** `test/example/priv/playwright/tests/admin-theme.spec.ts`
- **Commit:** `ed62f49bc`

**Total deviations:** 2 auto-fixed (1 blocking, 1 bug). **Impact:** none on scope; both are test-only and keep every threshold.

## Authentication Gates

None.

## Issues Encountered

- One transient failure in the first `admin-eval` run: `admin-eval-mobile` `render bundle: board-mg-4/populated` failed in the shared `registerUser` step (`waitForURL` timeout, the registration form POST never fired on the WebKit iPhone project). It is registration flakiness, not a token or font result (the font guard runs after registration), the same test and its three siblings pass on a rerun (4 of 4), and the whole `admin-eval` file passed (192 of 192) in the final verify.
- Pre-existing, not mine and left untouched: `.planning/config.json` and `.planning/state.json` carried uncommitted changes before this plan started. Both were snapshotted (sha256) and are byte-identical to the snapshot after the state writers ran.
- Known unknown carried forward: the `aria-prohibited-attr` incomplete on the design gallery (see Verification). It is recorded, never counted, and has no named node yet.

## Known Stubs

None.

## Threat Flags

None. Test-only change: no package install (`npm ci` was already satisfied), no new network surface beyond fetching the two shipped logo SVGs from the app under test, no environment read beyond the existing `SIGRA_EXAMPLE_URL`. T-261-11 (axe incomplete silently counted as a pass) is mitigated as planned: `incomplete` is only recorded, never asserted or subtracted, and the violations assertion is unchanged.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Plan 261-10 and 261-11 can rely on a tree where the template stylesheet and the example copy are byte-identical (`cmp` exit 0) and every spec this phase touches has passed whole against a booted app, before the single golden rebless. No rebless was run here.
- Golden-reading ExUnit tests remain expected-stale until plan 261-11; none was run.
- Carried to Phase 262 (already in `deferred-items.md`): the `.sg-select` control edge is not on the design gallery, so the non-text test counts 7 measurements, not 8; `.sg-color-field__input` and `.sg-cmdk__trigger` still carry divider-grade edges; hover and checked states of the secondary button and filter chip replace the resting control edge.

## Self-Check: PASSED

- FOUND: `test/example/priv/playwright/tests/admin-design.spec.ts` and `admin-theme.spec.ts`; this SUMMARY
- FOUND commits: `26f46ee11`, `2d0a32220`, `ed62f49bc` (all ancestors of HEAD)
- Measured: 3 commits since `plan_head_before` `85ecaf36b5354a19a2bbffe954265db70a23cc5d`
- Re-run of every acceptance criterion: listing shows `non-text 3:1` once per design project (3); `axe-incomplete` annotation present and no `expect(` takes `incomplete`; matrix loop count asserted 6; `Instrument Sans` opt-in assertion present; `spec-ownership.json`, `playwright.config.ts`, `.github`, `brand` and every snapshot directory untouched; `cmp` template vs example copy exits 0; port 4011 free; the whole-file runs and the plan's verify exit 0

---
*Phase: 261-tokens-type-logo-favicon-and-contrast*
*Completed: 2026-11-16*
