---
phase: 261-tokens-type-logo-favicon-and-contrast
plan: 10
subsystem: ui-testing
tags: [phoenix, liveview, playwright, admin-css, brand]
requires:
  - phase: 261-06
    provides: shared admin surfaces and phase-wide brand constraints
  - phase: 261-09
    provides: shipped logo and favicon assets with theme coverage
provides:
  - Installer and example copies ship the shared admin component styles used by generated hosts.
  - CSS gap coverage includes helper-generated admin classes and guards the shell surface in all themes.
  - Pre-rebless local, example-app, fresh-host, privacy, budget, and frozen-surface evidence.
affects: [261-11, generated-host-admin-ui]
actuals:
  tokens: 13324
  tasks: 3
  commits: 1
plan_head_before: a6724552889bfc1cb60b0140680c61b621367138
plan_head_after: e0b7bee47c12d399eba90068bdeb3a50bb06da01
# Task commits measured from plan_head_before; the summary metadata commit is separate.
commits: 1
tech-stack:
  added: []
  patterns:
    - Generated admin CSS is copied byte-for-byte between installer template and example host.
    - CSS coverage scans admin source tokens, including helper-generated classes.
key-files:
  created: []
  modified:
    - priv/templates/sigra.install/admin/sigra_admin.css
    - test/example/priv/static/assets/sigra_admin.css
    - test/example/priv/playwright/tests/admin-generated.spec.ts
    - test/sigra/install/css_undefined_classes_test.exs
    - test/support/brand/css_gap.ex
    - test/fixtures/brand/css-undefined-classes.txt
key-decisions:
  - "Treat generated-host screenshot defects as template acceptance failures and repair the shipped stylesheet before any rebless."
  - "Keep the fresh-host database on the isolated PostgreSQL port and verify generated configuration before database reset/create."
patterns-established:
  - "Generated admin styles: template and example CSS remain byte-identical."
  - "Theme surface checks: assert computed shell background and text colors, plus visible shell content."
requirements-completed: [BTOK-02, BTOK-03, BTOK-05, BTOK-06, BTOK-07, BTOK-08]
coverage:
  - id: D1
    description: "Generated admin pages receive the shared shell, navigation, tab, form, and feedback styles."
    requirement: BTOK-02
    verification:
      - kind: unit
        ref: "test/sigra/install/css_undefined_classes_test.exs"
        status: pass
      - kind: automated_ui
        ref: "scripts/ci/admin-acceptance-smoke.sh --test all"
        status: pass
    human_judgment: false
  - id: D2
    description: "Generated admin shell remains visible and readable in Light, Dark, and System Dark."
    requirement: BTOK-05
    verification:
      - kind: automated_ui
        ref: "test/example/priv/playwright/tests/admin-generated.spec.ts"
        status: pass
    human_judgment: false
duration: "multi-session; exact start unavailable in resumed context"
completed: 2026-11-16
status: complete
---

# Phase 261 Plan 10: Tokens, Type, Logo, Favicon, and Contrast Summary

**Generated-host admin styling now ships from the installer with a tested Light, Dark, and System theme surface.**

## Performance

- **Duration:** Multiple resumed work sessions; the original start timestamp was not available to this continuation.
- **Completed:** 2026-11-16
- **Tasks:** 3
- **Files modified:** 6 in the source-fix commit; this summary is the separate plan metadata change.

## Accomplishments

- Added the missing shared admin component rules to the installer CSS and kept the example copy byte-identical. This includes the shell surface, navigation links, generated tabs, and shared feedback components.
- Expanded the CSS gap ratchet to find `sg-*` classes in admin source and helper output, and removed the stale undefined-class defer fixture.
- Added computed theme surface and visible-content assertions for generated-host Light, Dark, and System Dark screenshots.
- Completed the pre-rebless local gates, example suite, isolated fresh-host smoke, planted-control privacy scan, process-budget audit, and frozen-surface checks without changing the golden fixture.

## Local gate (pre-rebless)

- `mix format --check-formatted`, locked dependency checks, compile with warnings as errors, admin CSS conformance, token completeness, and both guard self-test scripts passed.
- The non-golden installer/upgrade suites (`double_install`, Passkeys JS, passkeys opt-out, idempotency, vault promotion, and upgrade), plus `mix sigra.dep_off`, passed. The first Hex cache write was denied by the sandbox; the exact suite was retried with escalation and passed without cache cleanup.
- Final `mix test --exclude scaffold` completed with 33 doctests, 3 properties, 3,445 tests, and 12 skips; its only 3 failures were the expected stale golden-copy legs in `Sigra.Install.AssetParityTest` for `sigra-logo-primary-dark.svg`, `sigra-logo-primary.svg`, and `sigra_admin.css`. No `GoldenDiffTest` failure or other failure header appeared. These are the only failures permitted before Plan 11's single rebless.
- The earlier default-sandbox root run also hit two Phase 235 subprocess failures because the nested macOS network-denial sandbox could not start under the outer sandbox. The same 16 Phase 235 tests passed on the escalated retry; the final escalated root run had only the three expected golden-copy failures.
- CSS gap/contract and theme-focused checks passed after the source fix; the final frozen-surface, policy-docs, and source-pin gate passed with 86 tests and 0 failures.
- `cd test/example && MIX_ENV=test mix test --include example_app` passed with 443 tests and 0 failures.

## Fresh host

- The fresh host was generated with the installed `phx_new-1.8.8` archive and exercised with the real login and generated admin acceptance suite. Final smoke result: `admin-acceptance: success`; the admin target had 8 passing tests and 1 intentional skip, followed by passing generated-confirmation and revocation-denial checks.
- The stock smoke host config initially resolved to PostgreSQL port 5432 despite the sourced isolated environment. An earlier attempt reset `sigra_admin_smoke_dev` on 5432 before that mismatch was caught. The final run used a scratch-only wrapper, a unique temporary host, and port 58482; it verified generated `dev` and `test` configuration before database operations. Port 5432 was left untouched for the final run.
- One initial browser attempt failed 9 cases at Chromium launch before assertions ran. The final isolated rerun passed after using the background browser process and prebuilding the generated host assets before its server started. The repository smoke script and installer templates were not changed for this harness adjustment.
- The first rendered page also exposed missing shipped admin selectors. Those were added at the source and copied to the example CSS. The generated host then served its CSS successfully, with zero body margin and the expected sans-serif stack.

## Screenshots looked at

All three final theme screenshots were opened and inspected. They show the complete shell and dashboard without unstyled regions or overlap with the top bar:

- `admin-light.png`: Paper surface, Kiln accents, readable text and borders, selected controls, and the v2 lockup in the shell.
- `admin-dark.png`: Char surface with the dark lockup, readable text and borders, and the same complete navigation and dashboard structure.
- `admin-system-dark.png`: populated System Dark shell and dashboard, visually equivalent to explicit Dark as expected; the shell and heading visibility assertions passed at capture time.

The screenshots remain under the generated-host Playwright output directory and were not committed.

## Privacy gate (each leg ran with its planted control)

| Leg | Planted control | Result |
| --- | --- | --- |
| Home-directory shapes, including temporary-directory forms | Detected | Pass; clean scan |
| Address-shaped tokens outside allowed test/example domains | Detected | Pass; clean scan |
| Local username | Detected | Pass; clean scan |
| Configured maintainer address | Detected | Pass; clean scan |
| Vendored book authoring origin, scanning the full diff and phase planning directory | Detected | Pass; clean scan |
| Added binary/SVG metadata, asset byte parity, and approved asset-set check | Detected | Pass; clean scan |

The scan included the separately committed `.impeccable/config.json` in the full-diff accounting. Derived identity and origin values remained in the scratch-only harness and are not recorded here. The scratch script is outside the repository and untracked.

## Budgets and shipped-byte diff

- The phase budget measured 59 phase commits, excluding the separate user-requested config commit, and 74 unique paths.
- `priv/` changed exactly four paths: `admin_shell.ex`, the two primary logo SVGs, and `sigra_admin.css`.
- No `.github`, workflow, script, or `lib/` changes; protected brand/config/auth/README/favicon-wiring/spec-ownership/architecture-contract surfaces were unchanged.
- `test/fixtures/install_golden` had zero changes. No screenshots or scratch scripts were tracked.
- Template and example copies of `sigra_admin.css` are byte-identical.

## Task commits

1. **Task 2: Repair generated admin styles and coverage checks** - `e0b7bee47` (`fix(261-10)`).

The Task 1 and Task 3 work consisted of verification and scratch-only evidence; no source changes were needed for those tasks.

## Files created/modified

- `priv/templates/sigra.install/admin/sigra_admin.css` - shared styles shipped to generated admin hosts.
- `test/example/priv/static/assets/sigra_admin.css` - synchronized example copy.
- `test/example/priv/playwright/tests/admin-generated.spec.ts` - computed surface and visible-content theme assertions.
- `test/sigra/install/css_undefined_classes_test.exs` and `test/support/brand/css_gap.ex` - helper-aware CSS coverage contract.
- `test/fixtures/brand/css-undefined-classes.txt` - removed stale defer baseline.

## Decisions made

- A template-observed generated-host defect must be fixed before rebless, even when the example app has its own styles.
- The fresh-host smoke must explicitly bind its generated host to the isolated test database before any database operation.

## Deviations from plan

### Auto-fixed issues

**1. [Rule 1 - Bug] Shipped the missing generated admin component styles**
- **Found during:** Task 2 (fresh-host screenshots).
- **Issue:** Shared admin markup referenced selectors present only in the example stylesheet; generated hosts showed default list/link styling and a light shell surface in dark mode.
- **Fix:** Added the shared selectors, explicit shell theme surface rules, and helper-aware CSS gap coverage; synchronized template and example copies.
- **Files modified:** the six source paths listed above.
- **Verification:** CSS-focused gates, 443-test example suite, fresh-host smoke, and final screenshot inspection passed.
- **Committed in:** `e0b7bee47`.

**2. [Rule 3 - Blocking issue] Isolated the fresh-host smoke database and asset startup**
- **Found during:** Task 2.
- **Issue:** The generated host defaulted to port 5432, and the first browser run raced the generated asset build.
- **Fix:** Used a scratch-only wrapper to route the generated host to port 58482 after checking its config, and prebuilt assets before server startup. Added deterministic screenshot readiness assertions in the Playwright spec.
- **Files modified:** `test/example/priv/playwright/tests/admin-generated.spec.ts`; smoke wrapper and screenshots remained outside git.
- **Verification:** Final isolated fresh-host smoke passed and all three theme screenshots were inspected.
- **Committed in:** `e0b7bee47` for the screenshot assertions; scratch harness changes were not committed.

**Total deviations:** 2 auto-fixed. Both were needed to satisfy the plan's pre-rebless generated-host acceptance criteria.

## Issues encountered

- The early smoke attempt reset `sigra_admin_smoke_dev` on port 5432 before the generated-host port mismatch was identified. The final run used only the isolated port and left 5432 untouched.
- The pre-rebless root suite retains only the three named stale golden asset-copy failures; Plan 11's authorized single rebless is the next step.

## User setup required

None.

## Next phase readiness

Plan 10's gates are complete. Plan 11 can perform the phase's single golden rebless and rerun the golden readers. No additional phase has been started.

---
*Phase: 261-tokens-type-logo-favicon-and-contrast*
*Completed: 2026-11-16*

## Self-Check: PASSED

- Summary file exists at the planned path.
- Task commit `e0b7bee47` is an ancestor of the current HEAD.
- Privacy, budget, and frozen-surface checks pass; golden fixtures remain unchanged.
