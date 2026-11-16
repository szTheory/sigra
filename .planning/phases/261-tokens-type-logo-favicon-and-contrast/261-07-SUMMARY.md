---
phase: 261-tokens-type-logo-favicon-and-contrast
plan: 07
subsystem: testing
tags: [playwright, brand, tokens, fonts, contrast, typescript, fail-closed]

# Dependency graph
requires:
  - phase: 261-tokens-type-logo-favicon-and-contrast
    provides: "261-02 the two self-hosted book faces and sigra_admin_brand.css (linked on every page of the example), 261-03/04 the new token values and font tokens, 261-05 the frozen-filename lockups"
provides:
  - "helpers/brandSource.ts: repoRoot(), readTemplateTokens() (light :root and dark @media :root of the template stylesheet), tokenValue(theme, name) that throws when absent, brandTokensJson(), hexToRgbString(hex)"
  - "helpers/brandFonts.ts: assertBrandFontsLoaded(page), a font guard that forces the load of Instrument Sans and Red Hat Mono and asserts a FontFace entry with status loaded for each, naming the missing face"
  - "helpers/brandContrast.ts: rgbChannels, oklabChannels, relativeLuminance, contrastRatio moved verbatim out of admin-theme.spec.ts"
  - "Playwright token pins in admin-generated.spec.ts and admin-theme.spec.ts that read their expected value from the template stylesheet or brand/tokens.json, with a state-aware active theme-switch text colour"
  - "The three Space Grotesk font guards replaced; the retired-face disposition (kept, with the grep)"
affects: [261-08, 261-10, 261-11, 262]

# Actuals (#2632) - same estimateTokens scale (chars/4 over the added lines of the realized diff)
actuals:
  tokens: 4024
  tasks: 3
  commits: 3
commits: 3
plan_head_before: 60a8658ccba915e1750b85e725de55f0c2450faa
plan_head_after: 14ce309104cb928e26944f6099f934f563e561a4

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "A pin reads its expected value from the source of truth at call time and throws when the value is absent: a pin that cannot read its source is red, never green"
    - "A font guard forces the load and reads FontFace status (document.fonts.check is vacuously true for an undeclared face); a rejected load() is recorded per face so the failure names it"
    - "A state-aware expectation: the active theme-switch text is ink when light is shown and on-brand-solid when dark is shown, instead of one colour for every state"

key-files:
  created:
    - test/example/priv/playwright/helpers/brandSource.ts
    - test/example/priv/playwright/helpers/brandFonts.ts
    - test/example/priv/playwright/helpers/brandContrast.ts
  modified:
    - test/example/priv/playwright/tests/admin-theme.spec.ts
    - test/example/priv/playwright/tests/admin-generated.spec.ts
    - test/example/priv/playwright/tests/admin-design.spec.ts
    - test/example/priv/playwright/tests/admin-design.setup.ts
    - test/example/priv/playwright/tests/admin-eval.spec.ts

key-decisions:
  - "Space Grotesk (woff2, @font-face, --font-sans override in the example app.css) is KEPT: default.css feeds that override to the html font of every Tasklane host element that is neither vt-* nor sg-*, so the grep cannot prove it dead. app.css and the woff2 are byte-untouched"
  - "assertBrandFontsLoaded catches a rejected document.fonts.load() per face and reports it in the assertion message, because a declared face whose file 404s makes load() reject and would otherwise surface as one anonymous evaluate() error"
  - "admin-design.setup.ts keeps only the fonts.ready wait (it runs on a Tasklane register page); the face assertions live in the two specs that visit Sigra-owned pages"
  - "tokenValue(dark, name) falls back to the light :root value when the dark block does not redeclare the token (theme-invariant tokens such as --sg-logo-rail-accent are declared once)"

patterns-established:
  - "Tests that need the contrast arithmetic import it from helpers/brandContrast.ts; demo-showcase.spec.ts keeps its own differently shaped helpers on purpose"
  - "No new spec file: spec-ownership.json and playwright.config.ts are untouched, later browser checks extend existing specs"

requirements-completed: [BTOK-07, BTOK-06]

# Coverage metadata (#1602)
coverage:
  - id: D1
    description: "Three non-spec helpers: brandSource (template and tokens.json readers that throw when a value is absent), brandFonts (non-vacuous font guard), brandContrast (contrast helpers moved verbatim); every Playwright file still lists with an unchanged test count"
    requirement: BTOK-07
    verification:
      - kind: other
        ref: "cd test/example/priv/playwright && npx playwright test --list -> exit 0, Total: 394 tests in 22 files (before and after); the moved function bodies diff-identical to HEAD~3"
        status: pass
    human_judgment: false
  - id: D2
    description: "The Playwright pins held old token literals now read their expected value from source: active theme-switch fill and state-aware text and the light brand token read the template stylesheet, the dark brand-strong pin reads brand/tokens.json color.dark.kiln-bright; no old literal remains in either edited assertion"
    requirement: BTOK-07
    verification:
      - kind: other
        ref: "git grep -n -e fdba74 -e 'rgb(253, 186, 116)' -e 'rgb(21, 21, 21)' -- admin-generated.spec.ts admin-theme.spec.ts prints nothing (HEAD=8); playwright test --list exits 0"
        status: pass
      - kind: automated_ui
        ref: "throwaway static-page run (not committed): the template stylesheet in Chromium, 3 preferences x 4 states = 12 combinations, computed fill and text equal the state-aware expectation; planted control: the old rgb(21, 21, 21) text is not the dark text"
        status: pass
    human_judgment: false
  - id: D3
    description: "The three Space Grotesk font guards no longer assert the retired face: admin-design.spec.ts and admin-eval.spec.ts assert both book faces loaded via the status check, admin-design.setup.ts only waits for fonts.ready"
    requirement: BTOK-06
    verification:
      - kind: other
        ref: "git grep -n -i 'space grotesk' -- admin-design.spec.ts admin-design.setup.ts admin-eval.spec.ts prints nothing (HEAD=7); playwright test --list exits 0; bash scripts/ci/app-css-corruption-check.sh OK"
        status: pass
      - kind: automated_ui
        ref: "throwaway Chromium run (not committed): positive control passes with both faces served; negative controls fail and name the face for an undeclared Red Hat Mono, a 404 Instrument Sans (with the load() rejection text) and a page with no faces"
        status: pass
    human_judgment: false
  - id: D4
    description: "Retired suite face disposition: Space Grotesk kept, with the classified grep and the reason, in this SUMMARY"
    requirement: BTOK-06
    verification: []
    human_judgment: true
    rationale: "Keep-or-remove of a retired suite face is a design call. The grep proves a live dependency (the html font of every non-vt, non-sg host element) but not that Tasklane host chrome should keep it; the owner may retire it together with a host-chrome typeface decision."

# Metrics
duration: 7min
completed: 2026-11-16
status: complete
---

# Phase 261 Plan 07: Playwright Token Pins Read From Source Summary

**The Playwright token pins now read their expected value from the template stylesheet or brand/tokens.json (with a state-aware active theme-switch text), three small helper files carry the readers, the contrast arithmetic and a non-vacuous Instrument Sans plus Red Hat Mono font guard, and the three Space Grotesk guards are gone with no new spec file.**

## Performance

- **Duration:** about 7 min (2026-11-16T01:01:19Z to the SUMMARY write)
- **Tasks:** 3 (Task 1 tracer, Task 2 and Task 3 auto)
- **Files modified:** 8, all under `test/example/priv/playwright/`; `git diff 60a8658cc..HEAD --name-only` lists exactly the three new helpers and the five edited specs. No byte under `lib/`, `priv/templates/`, `scripts/`, `.github/`, `brand/`, the example `app.css`, `spec-ownership.json` or `playwright.config.ts` changed.
- **Playwright listing count (recorded as the tracer criterion asks):** `npx playwright test --list` printed `Total: 394 tests in 22 files` before the plan and `Total: 394 tests in 22 files` after each task and at the end.

## Accomplishments

- **Helpers, not specs.** `helpers/brandSource.ts` reads the template stylesheet lazily (never at import), scans for the first top-level `:root` block and the `:root` inside the top-level `@media (prefers-color-scheme: dark)` with a depth-0 brace scanner (comments stripped, multi-line values collapsed), and throws, naming the token, when a token or a whole block is absent. It found 112 light and 40 dark declarations. `helpers/brandContrast.ts` holds the five contrast functions moved verbatim (diff-identical to the pre-move bodies; `linearSrgbToChannel` stays private).
- **A font guard that cannot pass vacuously.** `assertBrandFontsLoaded(page)` awaits `document.fonts.load` for each face, then `document.fonts.ready`, then asserts a `FontFace` entry containing the family with status `loaded`. Controls run in a throwaway Chromium spec (not committed): both faces served passes; an undeclared Red Hat Mono fails with `Red Hat Mono must be declared and loaded ... document.fonts holds: Instrument Sans (loaded)`; a declared Instrument Sans whose file 404s fails with `... load() rejected: NetworkError ... Instrument Sans (error), Red Hat Mono (loaded)`; a page with no faces fails with `no FontFace entries at all`.
- **Pins read from source.** `admin-generated.spec.ts` deleted both literal constants: the active fill is `--sg-logo-rail-accent` and the text is `--sg-color-ink` (light) or the dark `--sg-color-on-brand-solid` (dark shown), chosen by whether the state label contains "dark"; the DIST-06 brand check compares to the template's light `--sg-color-brand` case-insensitively. `admin-theme.spec.ts` compares the dark brand-strong to `brand/tokens.json` `color.dark["kiln-bright"].$value.hex` case-insensitively and its comments no longer cite the old lightened value or dark panel hex; the composited-ratio computation and its 4.5 threshold are unchanged.
- **The state-aware text expectation was checked against the real stylesheet.** A throwaway static page (the template stylesheet in Chromium, no app boot) over 3 preferences x 4 states (system light, explicit light, explicit dark, system dark) produced `rgb(31, 26, 23)` for the two light states and `rgb(23, 18, 15)` for the two dark states on an `rgb(253, 186, 116)` fill, equal to the expectation in all 12; the old `rgb(21, 21, 21)` is not the dark text. Plan 261-08 runs the committed specs against a booted app.
- **Font guards.** `admin-design.spec.ts` and `admin-eval.spec.ts` call the helper (the eval spec's stale fourth mention in a comment was reworded too); `admin-design.setup.ts` runs on a Tasklane register page and keeps only `fonts.ready`, with a comment saying where the faces are asserted.

## Task Commits

Each task was committed atomically:

1. **Task 1: Tracer, helper files plus one moved helper proven by listing every spec** - `4164d7a03` (feat). Tracer feedback gate: config auto mode off and `human_verify_mode` end-of-phase, the `<verify>` is automated only, so it was re-run: listing exit 0, 394 tests in 22 files, no `Error:`/`SyntaxError`/`Cannot find module`; `Tracer verified end-to-end - expanding`.
2. **Task 2: Rewrite the Playwright token pins to read from source** - `0a7025f7e` (test)
3. **Task 3: Replace the three font guards and record the retired-face disposition** - `14ce30910` (test)

**Plan metadata:** the docs commit that follows this file (SUMMARY, then STATE, ROADMAP and REQUIREMENTS, plus deferred-items.md).

## Files Created/Modified

- `test/example/priv/playwright/helpers/brandSource.ts` - template stylesheet and tokens.json readers, `tokenValue`, `hexToRgbString`, `repoRoot`
- `test/example/priv/playwright/helpers/brandFonts.ts` - `assertBrandFontsLoaded`
- `test/example/priv/playwright/helpers/brandContrast.ts` - contrast helpers, moved verbatim
- `test/example/priv/playwright/tests/admin-theme.spec.ts` - imports `contrastRatio`, dark brand-strong pin from `brand/tokens.json`, comments rewritten
- `test/example/priv/playwright/tests/admin-generated.spec.ts` - active-switch and brand-token expectations from the template, text colour state-aware
- `test/example/priv/playwright/tests/admin-design.spec.ts`, `admin-eval.spec.ts` - `assertBrandFontsLoaded` replaces the retired-face guard
- `test/example/priv/playwright/tests/admin-design.setup.ts` - face assertion removed, `fonts.ready` kept

## Retired suite face disposition

**Verdict: KEPT.** `space-grotesk-var.woff2`, its `@font-face` and the `--font-sans` override in the example `app.css` are unchanged (`git diff --name-only -- test/example/priv/static/assets/css/app.css` is empty).

Classified `git grep -n -i -e 'space grotesk' -e space-grotesk` over the tracked tree, excluding `brandbook`, `brand`, `.planning`, `docs` and `CHANGELOG`:

| Hit | Class | Depends on the face? |
|-----|-------|----------------------|
| `test/example/priv/static/assets/css/app.css:2419-2420` (`@font-face` for Space Grotesk and its woff2 URL) | the face itself | n/a, this is what would be removed |
| `test/example/priv/static/assets/css/app.css:2445` (`:root { --font-sans: 'Space Grotesk', ... }`) | live consumer | **Yes.** `default.css:31` sets `--default-font-family: var(--font-sans)` and `default.css:50` applies it to `html, :host`, so every Tasklane host element that is neither `vt-*` (own Fraunces or Inter) nor `sg-*` (the admin shell now reads its opt-in Instrument Sans) inherits it. Removing it would move that base face to the OS system stack |
| `test/example/priv/static/assets/css/app.css:54, 91, 2413` | comments | no; stale wording (sg-* no longer "keeps the Sigra font", the admin shell opts into the book faces). Left alone: app.css has a stray-comment hazard and the plan forbids editing it |
| `test/example/priv/playwright/tests/demo-showcase.spec.ts:332, 338, 344` | negative assertion | no; asserts only that `vt-*` titles and body do NOT use the face |
| `test/fixtures/install_golden/tree/priv/static/images/sigra-logo-primary{,-dark}.svg:3` (`<desc>` "Font: Space Grotesk v2.0 ... outlined") | stale golden fixture | no; outlined artwork, not a font load. The shipped lockups no longer carry a `<desc>` (plan 261-05); the golden is stale until plan 261-11's single rebless |
| `test/sigra/brand/logo_contract_test.exs:67, 138` | retired-phrase guard | no; it asserts the phrase is ABSENT from the lockups |
| `guides/reference/admin-fractal-scorecard.md:27`, `guides/reference/admin-graphic-design-lens.md:44, 125, 203, 424`, `scripts/panel/lenses.mjs:104, 184` | docs and panel prompt text | no runtime dependency; still describe the old type. These three files are already named in the pending todo `2026-11-13-residual-brandbook-pointers.md` (outside the BPOL-06 approval); logged in `deferred-items.md` |
| `.github/workflows/ci.yml:1894, 1952` | historical PR-body text | no; not edited (no `.github` edits in this plan) |

Reason: the live dependency in row two is not provable dead by grep, and the plan keeps the face unless the grep proves nothing depends on it. The retire-or-keep call for Tasklane host chrome belongs with a host typeface decision, not with this test-pin plan.

## Decisions Made

See `key-decisions` in the frontmatter. In short: the face is kept; the guard records a rejected `load()` per face so its message names the face; the setup file only waits for `fonts.ready`; `tokenValue(dark, ...)` falls back to the light root for theme-invariant tokens.

## Deviations from Plan

None - plan executed exactly as written.

Notes that are not deviations:

- The first draft of `assertBrandFontsLoaded` let a rejected `document.fonts.load()` escape as an anonymous `page.evaluate: NetworkError`, which would have gone red but not named the face. The negative control caught it before the first commit and the helper now records the rejection per face (the plan requires the message to name the missing face). Nothing shipped with the flaw.
- The throwaway verification (a font-guard control spec and a static-page theme-switch spec, 5 and 13 tests, all green) lived in an untracked scratch directory that was deleted before the docs commit; none of it is committed or recorded in CI. The committed specs are exercised against a booted app by plan 261-08.
- `admin-eval.spec.ts` calls `waitForLiveViewReady` after `/users/register` as well as on Sigra pages. The full guard is sound there only because `sigra_admin_brand.css` is linked from the root layout on every page (plan 261-02). If that link is ever scoped to Sigra-owned pages the eval spec's register step goes red, by design.

## Authentication Gates

None.

## Issues Encountered

- Pre-existing, not mine and left untouched: `.planning/config.json` and `.planning/state.json` carried uncommitted changes before this plan started. `state.json` and `config.json` were snapshotted (sha256) before the first state call and are byte-identical to the snapshot after the writers ran.
- zsh expands a word starting with `=` as command substitution, so an `echo "=====..."` separator aborted a chained command once; unrelated to the code.

## Verification

- `cd test/example/priv/playwright && npx playwright test --list`: exit 0 (status captured, not read through a pipe), `Total: 394 tests in 22 files`, unchanged.
- `grep -c "function contrastRatio" tests/admin-theme.spec.ts`: 0 (HEAD=1). `git diff --name-only -- spec-ownership.json playwright.config.ts .github` and `... -- app.css`: nothing.
- `git grep -n -e fdba74 -e 'rgb(253, 186, 116)' -e 'rgb(21, 21, 21)' -- admin-generated.spec.ts admin-theme.spec.ts`: nothing (HEAD=8). `git grep -n -i 'space grotesk' -- <the three font-guard files>`: nothing (HEAD=7). `git grep -n -e tokenValue -e brandTokensJson -- tests`: both specs import from `helpers/brandSource`.
- `bash scripts/ci/app-css-corruption-check.sh`: `OK: no orphaned value fragments in :root block`.
- Contract tests that reference these files: `mix test` over phase 230, 232, 234, 235 and 260 planning tests: 58 tests, 0 failures; `node --test scripts/ci/prohibitions/p02-axe-signal-not-reduced.test.mjs`: 4 pass; `mix test test/sigra/brand/`: 718 tests, 0 failures.
- Golden-reading tests were not run and are expected stale until plan 261-11's single rebless; `rebless` was not run here. No Elixir file changed, so `mix format --check-formatted` is unaffected.

## Known Stubs

None.

## Threat Flags

None. Test-only change: node built-ins only, no package install, no network, no environment read, no new trust boundary. T-261-10 (a pin or font guard passing without reading or loading anything) is mitigated as planned: `tokenValue` throws when a token or a whole block is missing, the font guard asserts `FontFace` status `loaded` after an explicit load and names the face on failure, and plan 261-08 runs both against a booted app.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Plan 261-08 can run the committed specs against a booted example app: `assertBrandFontsLoaded` (design and eval specs), the state-aware active switch and the dark brand-strong pin, and can import `brandContrast`, `tokenValue` and `readTemplateTokens` for new checks without adding a spec file.
- Known unknown for 261-08: the pins and the guard were proven against the real template stylesheet and a controlled font page, not against the booted example. If a booted run disagrees, the likely cause is a page the guard runs on that does not link `sigra_admin_brand.css`.
- Space Grotesk is still shipped in the example for Tasklane host chrome; retiring it is a host typeface decision, not a Phase 261 test-pin change.

## Self-Check: PASSED

- FOUND: `helpers/brandSource.ts`, `helpers/brandFonts.ts`, `helpers/brandContrast.ts` and the five edited specs under `test/example/priv/playwright/`; this SUMMARY
- FOUND commits: `4164d7a03`, `0a7025f7e`, `14ce30910` (all ancestors of HEAD)
- Measured: 3 commits since `plan_head_before` `60a8658ccba915e1750b85e725de55f0c2450faa`
- Re-run of every acceptance criterion and the plan-level `<verification>` after the last commit: listing exit 0 with 394 tests in 22 files; zero old literals in the two pins; zero retired-face guards in the three files; `spec-ownership.json`, `playwright.config.ts`, `.github` and `app.css` untouched; no home path, user name or authoring origin in the changed files or this SUMMARY

---
*Phase: 261-tokens-type-logo-favicon-and-contrast*
*Completed: 2026-11-16*
