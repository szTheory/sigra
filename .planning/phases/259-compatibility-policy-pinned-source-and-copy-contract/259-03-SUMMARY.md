---
phase: 259-compatibility-policy-pinned-source-and-copy-contract
plan: 03
subsystem: testing
tags: [playwright, copy-contract, login-selector, lazy-html, test-only-helper]

requires:
  - phase: 259-01
    provides: copy-contract decision that browser tests must not depend on login button text
provides:
  - test/example/priv/playwright/helpers/loginSubmit.ts, a test-only helper exporting LOGIN_SUBMIT_SELECTOR and loginSubmit(page)
  - All 11 text-based 'Log in' submit locators in 6 Playwright files replaced by the helper
  - test/example/test/example_web/login_submit_selector_test.exs, a deterministic exactly-one-match proof of the selector (7 tests)
affects: [259-11, 262, 263]

actuals:
  tokens: 4071
  tasks: 2
  commits: 2

tech-stack:
  added: []
  patterns:
    - "Selector-as-single-source: the ConnTest regex-extracts the LOGIN_SUBMIT_SELECTOR literal from the TypeScript helper, so test and helper cannot drift"
    - "Count-based ambiguity proof: Playwright strict mode throws on more than one match, so the test asserts the selector resolves to exactly one element in the rendered page, with planted controls that can go red"
    - "Source assertion for unrenderable generated markup, labelled as a source assertion and not a render"

key-files:
  created:
    - test/example/priv/playwright/helpers/loginSubmit.ts
    - test/example/test/example_web/login_submit_selector_test.exs
  modified:
    - test/example/priv/playwright/helpers/adminFlows.ts
    - test/example/priv/playwright/tests/golden-path.spec.ts
    - test/example/priv/playwright/tests/passkey-options.spec.ts
    - test/example/priv/playwright/tests/ga-uat-shift-left.spec.ts
    - test/example/priv/playwright/tests/organizations.spec.ts
    - test/example/priv/playwright/tests/demo-showcase.spec.ts

key-decisions:
  - "Selector is '#login_form button:not([type=\"button\"])': the example host button has no type attribute and the generated sigra_auth_button defaults type to submit, while the passkey control is type=button in a different form"
  - "The selector is also exported as a string constant because demo-showcase passes a selector string to a probe function; every other site uses the loginSubmit(page) locator factory"
  - "The helper keeps LOGIN_SUBMIT_SELECTOR as one single-quoted line so the ConnTest regex can read it"

patterns-established:
  - "Acceptance is the grep, not the count: the requirement text says eight specs, the repo had 11 sites in 6 files; the gate is zero text-based submit locators outside comments"

requirements-completed: [BCOPY-06]

coverage:
  - id: D1
    description: "loginSubmit.ts exports LOGIN_SUBMIT_SELECTOR and a loginSubmit(page) factory, is test-only, imports Page as a type only, and imports under node"
    requirement: "BCOPY-06"
    verification:
      - kind: command
        ref: "node --input-type=module import of helpers/loginSubmit.ts prints 'helper ok'"
        status: pass
    human_judgment: false
  - id: D2
    description: "Every one of the 11 text-based login submit locators is replaced; no 'has-text(\"Log in\")' remains outside comments anywhere under the Playwright subproject"
    requirement: "BCOPY-06"
    verification:
      - kind: command
        ref: "repo-wide grep gate over test/example/priv/playwright (empty outside comments; positive control on the base commit golden-path file finds 2 sites)"
        status: pass
    human_judgment: false
  - id: D3
    description: "The selector resolves to exactly one element on the example host's rendered /users/log_in page, ignores type=button controls, ignores buttons in other forms, and the count assertion can go red"
    requirement: "BCOPY-06"
    verification:
      - kind: unit
        ref: "test/example/test/example_web/login_submit_selector_test.exs#GET /users/log_in (example host render)"
        status: pass
      - kind: unit
        ref: "test/example/test/example_web/login_submit_selector_test.exs#planted controls"
        status: pass
    human_judgment: false
  - id: D4
    description: "The generated login markup (not renderable in the example host) has exactly one sigra_auth_button call and no type=button inside the id=login_form block, and the component's type attr defaults to submit; asserted against template source"
    requirement: "BCOPY-06"
    verification:
      - kind: unit
        ref: "test/example/test/example_web/login_submit_selector_test.exs#generated login markup (source assertion, not a render)"
        status: pass
    human_judgment: false
  - id: D5
    description: "The five edited Playwright specs and adminFlows.ts still log in correctly in a real browser"
    requirement: "BCOPY-06"
    verification: []
    human_judgment: true
    rationale: "Playwright is not installed locally; the browser-runtime proof is the PR example_playwright_shard lanes, which this phase never triggers. Not run locally."

duration: 4min
completed: 2026-11-14
plan_head_before: 59307e8a199a9482b0e74c048e619051f23b8fce
plan_head_after: f57c437d2083f063a3c9b62bf9a534cf976e2fb3
commits: 2
status: complete
---

# Phase 259 Plan 03: Copy-independent loginSubmit helper Summary

**A test-only `loginSubmit` Playwright helper (`#login_form button:not([type="button"])`) now replaces all 11 "Log in" button-text locators across 6 files, with an example-host ConnTest proving the selector matches exactly one element, so the Phase 262/263 copy changes cannot break browser tests.**

## Performance

- **Duration:** 4 min
- **Started:** 2026-11-14T15:46:59Z
- **Completed:** 2026-11-14T15:50:30Z
- **Tasks:** 2 (Task 1 was the tracer)
- **Files modified:** 2 created, 6 modified

## Accomplishments

- `helpers/loginSubmit.ts` exports the string constant `LOGIN_SUBMIT_SELECTOR` and `loginSubmit(page)`. It carries a test-only header comment, imports `Page` as a type only, and explains why it is text-independent and why the string constant exists.
- 11 sites replaced: golden-path 2, ga-uat-shift-left 1, organizations 3 (the third uses `loginSubmit(inviteePage)`), demo-showcase 3, passkey-options 1, helpers/adminFlows 1. The demo-showcase probe call receives `LOGIN_SUBMIT_SELECTOR`, the locator assignment becomes `loginSubmit(page)`, and the click becomes `loginSubmit(page).click()`. Each file keeps its own quote style. Heading assertions (`Log in to ...`, still 5 in demo-showcase) and comments are untouched.
- `login_submit_selector_test.exs` (7 tests, flat, AAA) reads the selector out of the helper by regex and asserts, with LazyHTML over the real rendered `GET /users/log_in`, that it matches exactly 1 element. Planted controls: two submit buttons give 2, a `type="button"` control is ignored (1), buttons in `passkey_login_form` and `magic_link_form` are not matched (1).
- For the generated template (cannot be rendered in the example host) the test is explicitly a source assertion: the `id="login_form"` block in `priv/templates/sigra.install/core/login_html.ex` has exactly one `<.sigra_auth_button` and no `type="button"`; `sigra_auth_components.ex` defaults the `type` attr to `"submit"`; a planted two-button block is detected as 2. The templates are read only, never written.
- Red probe done by hand: temporarily widening the helper selector to `#login_form button` made the `type=button is ignored` planted control fail (7 tests, 1 failure); the helper was restored byte-for-byte and the suite is green again.
- Note, not a defect of this plan: the generated login button text is "Sign in with password", so the old `has-text("Log in")` locator could never have matched a generated host. The new selector matches both markups.

## Task Commits

1. **Task 1: Helper + adminFlows.ts + golden-path + passkey-options call sites, with import check and ConnTest (tracer)** - `4624ffbbe` (test)
2. **Task 2: Remaining specs (ga-uat-shift-left, organizations, demo-showcase) and the repo-wide grep gate** - `f57c437d2` (test)

The tracer gate ran after Task 1: auto mode off (`_auto_chain_active` and `auto_advance` false), `human_verify_mode` end-of-phase, tracer verify automated-only, so the verify was re-run (node import `helper ok`, per-file import loop, ConnTest 7 tests 0 failures) and expansion continued with no checkpoint.

**Plan metadata:** recorded in the follow-up `docs(259-03)` commit (STATE, ROADMAP, REQUIREMENTS).

## Files Created/Modified

- `test/example/priv/playwright/helpers/loginSubmit.ts` - test-only selector constant and locator factory (23 lines)
- `test/example/test/example_web/login_submit_selector_test.exs` - exactly-one-match proof, planted controls, generated-template source assertion (7 tests)
- `test/example/priv/playwright/helpers/adminFlows.ts`, `tests/golden-path.spec.ts`, `tests/passkey-options.spec.ts`, `tests/ga-uat-shift-left.spec.ts`, `tests/organizations.spec.ts`, `tests/demo-showcase.spec.ts` - call-site replacements plus one import each

## Decisions Made

- Selector excludes `type="button"` rather than matching `[type="submit"]`: the example host button has no type attribute, so a `[type=submit]` selector would match nothing there.
- Keep the constant on one single-quoted line (it fits in 80 columns) so the ConnTest regex stays trivial.
- Extra planted control (buttons in other forms are not matched) beyond the two the plan named; it guards the exact property the helper relies on (the passkey and magic-link controls live in other forms).

## Deviations from Plan

None - plan executed exactly as written.

The plan's own prose notes the requirement text says 8 locators while the repo had 11; acceptance was the grep, as the plan directs. The plan's example `grep -rn` positive control reads from stdin; BSD grep with `-r` and no file operand recurses the working directory (returned 18), so the control was re-run as `git show ... | grep -n ... | grep -c .` and returned 2, the real base-commit count.

**Total deviations:** 0.

## Issues Encountered

None blocking. Node 26 prints a `MODULE_TYPELESS_PACKAGE_JSON` warning when importing the `.ts` helper (the Playwright `package.json` has no `"type": "module"`); the import and the assertions succeed, and the warning was left alone because changing package.json is out of scope.

## Known Stubs

None.

## Verification Results

- Grep gate over `test/example/priv/playwright` (`--include='*.ts'`, comment-only lines excluded): before 11 matching lines (all code), after 0 (including comments: 0). Positive control on the base commit golden-path file: 2.
- `loginSubmit(` call-style sites: 10 (11 total minus the one that passes the string constant); `LOGIN_SUBMIT_SELECTOR` in demo-showcase appears in the import and the probe argument.
- `node --input-type=module` import of the helper prints the exact selector and `helper ok`.
- `source tmp/db.env && cd test/example && MIX_ENV=test mix test --include example_app test/example_web/login_submit_selector_test.exs`: 7 tests, 0 failures. `mix format --check-formatted` clean for the new test.
- Plan-level: zero shipped bytes (`lib priv brandbook brand .github scripts` diff and status empty against `aeda7273d`, planning diff and tracked-tree sample as controls) PASS; privacy gate over the phase diff with planted control PASS; `spec-ownership.json` diff empty; `mix test test/sigra/planning/phase_234_playwright_inventory_contract_test.exs`: 6 tests, 0 failures.

**Playwright is not installed locally; the behavioral proof of these edits is the PR example_playwright_shard lanes (golden-path, ga-uat-shift-left, passkey-options, organizations, demo-showcase). Not run locally.** Nothing was pushed, no PR was opened and no CI was triggered from this plan.

## Threat Flags

None. Test-only files; no new network, auth, file-access or schema surface. T-259-08 (ambiguous selector) is mitigated by the exactly-one-match ConnTest and its planted controls, with the CI shards as the behavioral proof; T-259-09 (claiming local Playwright green) is mitigated by the verbatim honesty statement above.

## Next Phase Readiness

Plan 259-11's phase gate and the Phase 262/263 copy changes can now rename the login button text without touching the specs. If the CI shards report the selector as ambiguous, tighten the selector in `loginSubmit.ts` only; do not edit product templates or host components.

## Self-Check: PASSED

- FOUND: `test/example/priv/playwright/helpers/loginSubmit.ts`, `test/example/test/example_web/login_submit_selector_test.exs`
- FOUND commits: `4624ffbbe`, `f57c437d2`
- evaluation-scope (commits-only) resolved both plan commits on this branch
