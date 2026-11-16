---
phase: 261-tokens-type-logo-favicon-and-contrast
verified: 2026-11-16T19:16:00Z
status: human_needed
score: 4/5 must-haves verified
covered_files:
  - .planning/phases/261-tokens-type-logo-favicon-and-contrast/261-01-PLAN.md
  - .planning/phases/261-tokens-type-logo-favicon-and-contrast/261-01-SUMMARY.md
  - .planning/phases/261-tokens-type-logo-favicon-and-contrast/261-02-PLAN.md
  - .planning/phases/261-tokens-type-logo-favicon-and-contrast/261-02-SUMMARY.md
  - .planning/phases/261-tokens-type-logo-favicon-and-contrast/261-03-PLAN.md
  - .planning/phases/261-tokens-type-logo-favicon-and-contrast/261-03-SUMMARY.md
  - .planning/phases/261-tokens-type-logo-favicon-and-contrast/261-04-PLAN.md
  - .planning/phases/261-tokens-type-logo-favicon-and-contrast/261-04-SUMMARY.md
  - .planning/phases/261-tokens-type-logo-favicon-and-contrast/261-05-PLAN.md
  - .planning/phases/261-tokens-type-logo-favicon-and-contrast/261-05-SUMMARY.md
  - .planning/phases/261-tokens-type-logo-favicon-and-contrast/261-06-PLAN.md
  - .planning/phases/261-tokens-type-logo-favicon-and-contrast/261-06-SUMMARY.md
  - .planning/phases/261-tokens-type-logo-favicon-and-contrast/261-07-PLAN.md
  - .planning/phases/261-tokens-type-logo-favicon-and-contrast/261-07-SUMMARY.md
  - .planning/phases/261-tokens-type-logo-favicon-and-contrast/261-08-PLAN.md
  - .planning/phases/261-tokens-type-logo-favicon-and-contrast/261-08-SUMMARY.md
  - .planning/phases/261-tokens-type-logo-favicon-and-contrast/261-09-PLAN.md
  - .planning/phases/261-tokens-type-logo-favicon-and-contrast/261-09-SUMMARY.md
  - .planning/phases/261-tokens-type-logo-favicon-and-contrast/261-10-PLAN.md
  - .planning/phases/261-tokens-type-logo-favicon-and-contrast/261-10-SUMMARY.md
  - .planning/phases/261-tokens-type-logo-favicon-and-contrast/261-11-PLAN.md
  - .planning/phases/261-tokens-type-logo-favicon-and-contrast/261-11-SUMMARY.md
  - .planning/phases/261-tokens-type-logo-favicon-and-contrast/261-12-PLAN.md
  - .planning/phases/261-tokens-type-logo-favicon-and-contrast/261-12-SUMMARY.md
  - .planning/phases/261-tokens-type-logo-favicon-and-contrast/261-CONTACT-SHEET.html
  - .planning/phases/261-tokens-type-logo-favicon-and-contrast/261-TOKEN-MIGRATION.md
  - .planning/phases/261-tokens-type-logo-favicon-and-contrast/deferred-items.md
  - guides/reference/admin-design-contract.md
  - guides/reference/admin-token-reference.md
  - priv/templates/sigra.install/admin/components/admin_shell.ex
  - priv/templates/sigra.install/admin/sigra-logo-primary-dark.svg
  - priv/templates/sigra.install/admin/sigra-logo-primary.svg
  - priv/templates/sigra.install/admin/sigra_admin.css
  - test/example/lib/example/demo/branding.ex
  - test/example/lib/example_web.ex
  - test/example/lib/example_web/components/admin_shell.ex
  - test/example/lib/example_web/components/layouts.ex
  - test/example/lib/example_web/components/layouts/root.html.heex
  - test/example/priv/playwright/helpers/brandContrast.ts
  - test/example/priv/playwright/helpers/brandFonts.ts
  - test/example/priv/playwright/helpers/brandSource.ts
  - test/example/priv/playwright/tests/admin-design.setup.ts
  - test/example/priv/playwright/tests/admin-design.spec.ts
  - test/example/priv/playwright/tests/admin-eval.spec.ts
  - test/example/priv/playwright/tests/admin-generated.spec.ts
  - test/example/priv/playwright/tests/admin-theme.spec.ts
  - test/example/priv/playwright/tests/demo-showcase.spec.ts
  - test/example/priv/static/assets/css/app.css
  - test/example/priv/static/assets/css/sigra_admin_brand.css
  - test/example/priv/static/assets/fonts/OFL-InstrumentSans.txt
  - test/example/priv/static/assets/fonts/OFL-RedHatMono.txt
  - test/example/priv/static/assets/fonts/instrument-sans-var.woff2
  - test/example/priv/static/assets/fonts/red-hat-mono-var.woff2
  - test/example/priv/static/assets/sigra_admin.css
  - test/example/priv/static/favicon.svg
  - test/example/priv/static/images/sigra-favicon.ico
  - test/example/priv/static/images/sigra-logo-primary-dark.svg
  - test/example/priv/static/images/sigra-logo-primary.svg
  - test/example/test/example_web/admin_favicon_test.exs
  - test/example/test/example_web/admin_shell_test.exs
  - test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp_web/components/admin_shell.ex
  - test/fixtures/install_golden/tree/priv/static/assets/sigra_admin.css
  - test/fixtures/install_golden/tree/priv/static/images/sigra-logo-primary-dark.svg
  - test/fixtures/install_golden/tree/priv/static/images/sigra-logo-primary.svg
  - test/sigra/brand/contrast_pairs_test.exs
  - test/sigra/brand/css_contract_test.exs
  - test/sigra/brand/css_contrast_test.exs
  - test/sigra/brand/logo_contract_test.exs
  - test/sigra/brand/token_migration_test.exs
  - test/sigra/brand/token_parity_test.exs
  - test/sigra/brand/vendored_assets_test.exs
  - test/sigra/install/css_undefined_classes_test.exs
  - test/sigra/install/features/admin_test.exs
  - test/support/brand/css_contrast.ex
  - test/support/brand/css_gap.ex
covered_digest: "v4:sha256:e8df2b20444bd4d471d9e5c54ae9bafe891f9d044b1f4a6bc8fc89f2b256f00b"
behavior_unverified: 0
overrides_applied: 0
decision_coverage:
  honored: 0
  total: 0
  not_honored: []
human_verification:
  - test: "After the owner authorizes the token changes to be pushed for review, verify `ci-gate` on the first token-only PR."
    expected: "The PR containing the Phase 261 token changes receives a green `ci-gate`; current local `mix ci` is not a substitute for this PR-path check."
    why_human: "The current open PR #380 is still at commit aeda7273 and covers the planning start; it does not contain the local Phase 261 commits. Project instructions require explicit owner approval before pushing."
---

# Phase 261: Tokens, Type, Logo, Favicon and Contrast — Verification Report

**Phase Goal:** Sigra's own surfaces carry the Kiln visual identity (values, type, logo, favicon) in Light and Dark, with every token name unchanged and contrast proven over the implemented CSS and the real DOM.
**Verified:** 2026-11-16T19:16:00Z
**Status:** human_needed
**Re-verification:** No — first verification report

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|---|---|---|
| 1 | New token values come from the reviewed old→new table, token names stay frozen, auth fallbacks are unchanged, one rebless is used, and the first token-only PR has a green `ci-gate`. | ⚠️ UNCERTAIN — implementation verified; PR gate pending | `261-TOKEN-MIGRATION.md` is parsed by `token_migration_test.exs`; that test checks one row per stylesheet token, four theme blocks, book provenance and planted mismatch controls. `sigra_auth.css` and `mix.exs` do not appear in the Phase 261 diff from its plan base. The single fixture rebless is commit `f0b0b93e8`, and final `MIX_ENV=test mix ci` passed (3 doctests, 3 properties, 3,445 tests, 0 failures, 12 skipped). The open PR lookup found only #380 at earlier commit `aeda7273`; its CI run does not cover the Phase 261 commits, so the PR-path requirement is not yet proven. |
| 2 | Thirty contrast pairs and derived states pass against the implementation, a planted bad color fails, axe remains green, incomplete results are recorded, and non-text 3:1 checks cover the real DOM. | ✓ VERIFIED | `contrast_pairs_test.exs` binds the book's 30 light/dark rows to computed CSS and includes bad-color and missing-declaration controls. `admin-design.spec.ts` leaves axe and non-text checks untagged; the axe helper records incomplete rule IDs as an annotation from that same analysis result. The final local CI passed; the recorded browser run reports the touched admin specs green and incomplete counts separately. |
| 3 | The v2 lockup and favicon assets keep the frozen filenames, render at required sizes, and receive owner approval for distinctness and 16–24px legibility. | ✓ VERIFIED | `logo_contract_test.exs`, `admin_shell_test.exs`, and `admin-theme.spec.ts` verify SVG titles, empty image alts in the labelled link, lockup geometry, favicon ownership, bytes and 16/32px pixels. The example rail files were removed and the demo preset was repointed. The owner reviewed `261-CONTACT-SHEET.html` and explicitly approved the new lockup and favicon. |
| 4 | Additive font tokens inherit the host by default; Sigra-owned example surfaces self-host the book fonts with licenses; installer templates contain no font binaries; source-driven pins and token docs are current. | ✓ VERIFIED | `sigra_admin.css` declares inherited/system defaults and no `@font-face`; `sigra_admin_brand.css` scopes two self-hosted faces to `.sg-admin-shell`; the example contains matching WOFF2 files and OFL texts. `vendored_assets_test.exs` checks byte parity, file kinds and absence of installer binaries; `admin-theme.spec.ts` probes host inheritance and opt-in computed fonts. |
| 5 | Frozen surfaces, privacy and process limits hold; generated-host Light/Dark/System works; no Phase 261 change alters ExDoc wiring, Profile/Config defaults or `sigra_auth.css`. | ✓ VERIFIED | The current generated admin stylesheet is byte-identical to the example copy; a Light and System Dark generated-host screenshot was inspected and shows the full shell with the expected palette. `MIX_ENV=test mix ci` passed. The committed final privacy/budget evidence reports all planted controls detected and clean scans, 62 phase commits/81 paths, four `priv/` paths and one four-path golden rebless commit, with no `.github`, script, library or frozen-surface changes. The Phase 261 diff from its plan base excludes `mix.exs`, `sigra_auth.css`, `lib/`, and the `Profile`/`Config` defaults. |

**Score:** 4/5 roadmap truths verified; the first token-only PR's CI gate remains external-gate dependent.

### Deferred Items

None. The two outstanding checks are requirements of this phase, not work explicitly assigned to a later phase.

### Required Artifacts

| Artifact | Expected | Status | Details |
|---|---|---|---|
| `261-TOKEN-MIGRATION.md` | Reviewed token mapping | VERIFIED | 44 rows; the parser test checks table coverage and agreement with CSS blocks. |
| `priv/templates/sigra.install/admin/sigra_admin.css` | Shipped theme tokens and admin rules | VERIFIED | Matches the example copy byte-for-byte; no font binaries or `@font-face`. |
| `test/example/priv/static/assets/css/sigra_admin_brand.css` | Example-only font opt-in | VERIFIED | Two licensed local faces scoped to `.sg-admin-shell`. |
| `test/example/priv/playwright/tests/admin-theme.spec.ts` | Real DOM theme, lockup, favicon, font and responsive proofs | VERIFIED | Current test declarations cover six theme combinations, geometry, favicon byte/pixel checks, font inheritance and 375/390px overflow. |
| `261-CONTACT-SHEET.html` | Owner review artifact | PRESENT — review pending | Contact sheet exists and the ledger leaves the owner answer pending. |

### Key Link Verification

| From | To | Via | Status | Details |
|---|---|---|---|---|
| Token migration table | Installer CSS | `token_migration_test.exs` parses both | VERIFIED | Four theme blocks agree with the table; table rows cite book paths or named source-gap facts. |
| Installer CSS | Example CSS copy | File parity | VERIFIED | `cmp` reports byte equality. |
| Brand font assets | Example font assets | SHA parity and `@font-face` URL | VERIFIED | Test checks exact byte copies, the self-hosted URLs, and OFL text files. |
| Example layout | Favicon assets | Sigra-owned page predicate | VERIFIED | `layouts.ex` scopes both icon links to `/admin` and descendants; test checks host-facing pages keep the demo icon. |
| Real DOM | Contrast checks | Playwright computed-style probes | VERIFIED | Axe annotations and non-text checks are wired into untagged design-project tests. |

### Data-Flow Trace (Level 4)

Not applicable to dynamic database data. The verified values are static brand tokens and files; tests trace expected values to the pinned brand book and CSS sources.

### Behavioral Spot-Checks

| Behavior | Command/evidence | Result | Status |
|---|---|---|---|
| Library and example regression gate | Final `MIX_ENV=test mix ci` log | 3,445 tests, 0 failures; 12 skipped | PASS |
| Generated host theme rendering | Existing fresh-host screenshots and Playwright results; Light and System Dark screenshots inspected | Shell and palette render coherently | PASS |
| Token PR CI gate | Read-only PR lookup (`gh pr view 380`) | PR #380 is at `aeda7273`; it does not contain local Phase 261 changes | NEEDS OWNER-AUTHORIZED PR CHECK |
| Direct golden check attempt | `MIX_ENV=test mix sigra.fixture.rebless_golden --check` | Could not reach the check: Hex failed to persist `/Users/jon/.hex/cache.ets` with `:eaccess` before scaffolding; no rebless ran and no tracked files changed. The final CI evidence remains green. | ENVIRONMENT BLOCKED; NO CODE FAILURE |

### Requirements Coverage

| Requirement | Status | Evidence |
|---|---|---|
| BTOK-01 | Satisfied locally; PR gate pending | Migration table/parser, four-block parity, single rebless; token-only PR `ci-gate` still needs proof. |
| BTOK-02 | Satisfied | 30 book pairs and derived state tests over implemented CSS. |
| BTOK-03 | Satisfied by automation | Real-DOM axe annotation and non-text contrast checks; human contact-sheet review remains under BTOK-05. |
| BTOK-04 | Satisfied by automation | Frozen filename, title/alt, shell parity and geometry assertions. |
| BTOK-05 | Needs owner review | Asset byte, ownership and render checks pass; distinctness and small-size judgment is pending. |
| BTOK-06 | Satisfied | Font parity, licensing, inheritance, scoped opt-in and installer-binary guards. |
| BTOK-07 | Satisfied | Pinned CSS expectations read from source; token reference points to `brand/tokens.json`. |
| BTOK-08 | Satisfied | Additive status, selected-row and current-tab tokens are in the table and checked against CSS. |

### Test Quality Audit

The migration and contrast tests use the pinned brand book as their independent source and contain planted negative controls. Logo and font tests compare shipped/example copies to `brand/` assets. No requirement-linked check was found to have only a skipped test. The conditional `@snapshot` pixel tests are intentionally parked on PR/push; the axe and non-text tests are untagged and remain on the PR path. The `admin-generated.spec.ts` conditional skip is for the separate revoked-admin smoke and does not cover a Phase 261 requirement. No circular expected-output generation was found in the scoped requirement tests.

### Anti-Patterns Found

None blocking. No source change in the phase modifies `mix.exs`, `sigra_auth.css`, or library `Profile` defaults. The intentional, narrowly scoped overused-font ignores already exist for `Space Grotesk`, `Fraunces`, and `Inter` with references to the host/demo decisions; this verification made no ignore or CSS change.

### Decision Coverage

The GSD decision coverage query returned `skipped: true`, `reason: no trackable decisions`, `total: 0`. The Phase 261 context contains implementation decisions but no trackable `<decisions>` entries.

### Human Verification Required

1. **First token-only PR CI gate**
   - **Test:** After explicitly authorizing the push, run the token-only PR through CI and confirm `ci-gate` is green.
   - **Expected:** The PR containing Phase 261 token changes passes `ci-gate`.
   - **Why human:** The current open PR is still at an older planning-only commit, and project instructions require owner approval before pushing.

### Gaps Summary

The implementation, local CI, generated-host rendering, automated visual/contrast contracts, and owner review are verified. The phase remains `human_needed` because no PR containing Phase 261 changes has run the required `ci-gate`. No code defect was identified. The direct golden-check retry was blocked by Hex cache permissions before the check ran; no mutation occurred.

---

_Verified: 2026-11-16T19:16:00Z_  
_Verifier: gsd-verifier_
