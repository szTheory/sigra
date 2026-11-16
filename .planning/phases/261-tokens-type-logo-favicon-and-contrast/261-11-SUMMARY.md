---
phase: 261-tokens-type-logo-favicon-and-contrast
plan: 11
subsystem: brand-and-release-gates
tags: [css, contrast, logo, favicon, fonts, golden-install]
requirements-completed: [BTOK-01, BTOK-02, BTOK-03, BTOK-04, BTOK-05, BTOK-06, BTOK-07, BTOK-08]
completed: 2026-11-16
status: complete
---

# Phase 261 Plan 11: Golden Rebless and Phase Closeout

**The golden install fixture now matches the final generated templates, the full local gate is green, and the phase closes with a searchable visual review sheet and test ledger.**

## Single rebless

- Before reblessing, `MIX_ENV=test mix sigra.fixture.rebless_golden --check` exited 2 and reported the expected drift in the template-derived CSS, two logo assets, and generated `admin_shell.ex`.
- Ran `MIX_ENV=test mix sigra.fixture.rebless_golden` exactly once on 2026-11-16. Reviewed its grouped diff; it changed exactly four paths and no other fixture files.
- Rebless commit: `f0b0b93e8` (`test(261): rebless golden install fixture`).
- The post-rebless `--check` passed. Template and example CSS and logo copies are byte-identical; the generated shell differs only in the expected 96×39 lockup dimensions.

## Golden readers and final gate

- `MIX_ENV=test mix ci.install_golden`: 33 tests, 0 failures, 3 excluded.
- `mix test test/sigra/install/asset_parity_test.exs test/sigra/install/features/admin_test.exs test/sigra/brand/ test/sigra/planning/`: 1,000 tests, 0 failures, 12 skipped.
- Final `MIX_ENV=test mix ci`: 33 doctests, 3 properties, 3,445 tests, 0 failures, 12 skipped; the additional CI unit group reported 65 tests, 0 failures.
- The frozen-surface and policy-docs check passed again. No snapshot baselines were changed.
- The generated-host smoke had one early attempt point at the local database port; the final smoke used an isolated PostgreSQL port after checking the generated configuration. The initial attempt affected only its smoke-named database. The later isolated run passed, served the stylesheet, and passed the Light, Dark, and System Dark DOM checks.

## Privacy and budgets (final diff)

Each privacy leg used its planted control, detected that control, then found the final diff clean:

| Leg | Final result |
| --- | --- |
| Home-directory-shaped text | Control detected; phase diff clean |
| Address-shaped text | Control detected; added lines clean |
| Local username | Control detected; phase diff clean |
| Configured maintainer address | Control detected; phase diff clean |
| Brand-book authoring origin | Control detected; diff and phase planning directory clean |
| Binary/SVG metadata | Control detected; asset set, brand-byte parity, logo-title parity, and SVG markers clean |

Final budget measurement after closeout: 62 phase commits and 81 unique paths, excluding the separately requested intentional-font configuration commit. The phase changes exactly four `priv/` paths and exactly four golden fixture paths in the single rebless commit. No `.github`, `scripts`, `lib`, frozen-surface, or workflow additions were found. No screenshot, generator, or scratch script was added to the repository.

## Requirement to oracle ledger

| Requirement | Automation and oracle |
| --- | --- |
| BTOK-01 | `test/sigra/brand/token_migration_test.exs` (one row per declared token; light/dark values and focus ring), `test/sigra/brand/token_parity_test.exs`, and `test/example/priv/playwright/tests/admin-theme.spec.ts` (“theme matrix: shown theme drives brand tokens, focus ring and lockup”). |
| BTOK-02 | `test/sigra/brand/contrast_pairs_test.exs` (30 book pairs, derived states, non-text pairs and fail-closed checks) and `test/sigra/brand/css_contrast_test.exs` (implemented stylesheet and theme scopes). |
| BTOK-03 | `test/example/priv/playwright/tests/admin-design.spec.ts` (full-page axe and “non-text 3:1: focus ring, control edge and logo square”); `test/example/priv/playwright/tests/admin-generated.spec.ts` (generated-host Light, Dark, System Dark surface and visible content). Axe incomplete findings are recorded as incomplete, not passes. |
| BTOK-04 | `test/sigra/brand/logo_contract_test.exs` (book-byte parity, metadata, lockup geometry and markup), `test/example/test/example_web/admin_shell_test.exs`, and `admin-theme.spec.ts` (“lockup keeps 2T clear space at 96px minimum in Light and Dark”). Plan 261-12 also removes the retired demo rail files and checks their absence. |
| BTOK-05 | `test/sigra/brand/vendored_assets_test.exs`, `test/example/test/example_web/admin_favicon_test.exs`, and `admin-theme.spec.ts` (favicon scope, book bytes, unchanged root asset, and 16/32px pixel render); the non-blocking visual handoff is `261-CONTACT-SHEET.html`. |
| BTOK-06 | `test/sigra/brand/vendored_assets_test.exs` (byte parity and text-only installer), `test/sigra/brand/css_contract_test.exs` (host-inherited defaults and selectors), and `admin-theme.spec.ts` (“font tokens: defaults inherit the host face and the example opts in”). |
| BTOK-07 | `test/sigra/brand/token_migration_test.exs`, `scripts/ci/admin-token-completeness.sh`, and source-pinned assertions in `admin-design.spec.ts`, `admin-design.setup.ts`, and `admin-eval.spec.ts`. |
| BTOK-08 | `test/sigra/brand/token_migration_test.exs` (additive token values), `test/sigra/brand/css_contract_test.exs` (control edges and opaque sticky-header ground), and `test/sigra/brand/contrast_pairs_test.exs` (derived and non-text pairs). |

## UI Considerations coverage

| UI-SPEC consideration | Plan and test oracle |
| --- | --- |
| Loading lockup: reserve space before the SVG decodes | Plan 05; `logo_contract_test.exs` (“lockup box and clearance”) and `admin-theme.spec.ts` lockup geometry. The 96×39 image dimensions match the reserved 96×40 CSS box. |
| Error lockup: empty image alt keeps the link’s accessible name | Plan 05; `logo_contract_test.exs` shell-markup contract asserts both empty alts and `aria-label="Sigra admin overview"`; `admin_shell_test.exs` checks the rendered link and lockup markup. |
| Loading web fonts | Plans 02, 07, and 08; `vendored_assets_test.exs` checks `font-display: swap`; `admin-theme.spec.ts` waits for `document.fonts.ready` and checks the computed font tokens and loaded example faces. |
| Empty status and tone tokens | Plan 06; `contrast_pairs_test.exs` checks all 30 book pairs plus derived and state pairs directly from the implemented CSS. |
| Topbar overflow at 375px and 390px | Plans 08 and 10; `admin-theme.spec.ts` (“topbar does not overflow at 375 and 390 wide”) and the generated-host responsive assertions in `admin-generated.spec.ts`. |
| Long `.sg-code` text under Red Hat Mono and the system mono fallback | Plans 07 and 08; `admin-design.spec.ts` (“component and group boards do not overflow at required responsive widths”) exercises the boards at required widths; font readiness is guarded by the font-token test. |
| Dark sticky table header remains opaque over scrolling rows | Plan 04; `css_contract_test.exs` checks the sticky header uses `--sg-color-sunken` and that its value is opaque in every theme scope; `contrast_pairs_test.exs` checks the corresponding contrast and non-text grounds. |

## Human gate hand-off

`approved: owner approved the lockup and favicon review on 2026-11-16`

The owner reviewed the self-contained contact sheet and approved the new lockup's distinctness and the favicon's legibility. The sheet shows the retired and new lockups at 96, 120, and 192 CSS pixels; the retired favicon, responsive SVG, and ICO frames at 16, 24, and 32 CSS pixels; Light and Dark grounds; device scales 1× and 2×; and source SHA256 values. It contains no local paths or authoring-origin metadata.

## Task commits

- `f0b0b93e8` — the one reviewed golden rebless.
- The contact sheet and this closeout ledger are committed together as phase documentation.

---
*Phase: 261-tokens-type-logo-favicon-and-contrast*
*Completed: 2026-11-16*
