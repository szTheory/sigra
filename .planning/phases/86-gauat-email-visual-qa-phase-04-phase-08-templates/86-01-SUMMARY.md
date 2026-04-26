---
phase: 86-gauat-email-visual-qa-phase-04-phase-08-templates
plan: 01
subsystem: testing
tags: [elixir, email, wcag, accessibility, css-lint, caniemail, exunit, contrast]

# Dependency graph
requires:
  - phase: priv/templates/sigra.install/core/emails.ex
    provides: "9 transactional email template builders already compiled in example app"
  - phase: test/example/test/example/accounts/emails_security_html_test.exs
    provides: "Existing structural HTML assertions for Phase 04 templates"
  - phase: test/example/test/example/accounts/emails_lifecycle_html_test.exs
    provides: "Existing structural HTML assertions for Phase 08 templates"
provides:
  - "Sigra.A11y.Contrast WCAG 2.2 relative_luminance/1 and ratio/2 with error handling"
  - "Example.EmailAssertions G1-G6 shared helpers (contrast, byte budget, URL parity, recipient, XSS, deny-list)"
  - "Sigra.Email.CssLint with vendored caniemail policy for Gmail/Outlook/Apple Mail"
  - "priv/sigra/email/caniemail-allowlist.json vendored policy for deterministic CI lint"
  - "CTA button color bumped from #2563eb to #1d4ed8 (6.70:1 vs #ffffff; unambiguous WCAG AA)"
  - "121 email tests in example app closing G1-G9 rubric across all 9 Phase 04 + Phase 08 templates"
  - "13 unit tests for Sigra.A11y.Contrast"
  - "11 unit tests for Sigra.Email.CssLint"
affects:
  - 86-02-PLAN
  - example_unit_smoke CI job

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Vendored build-time JSON policy read with @external_resource + Jason.decode! at compile time (zero I/O in CI)"
    - "WCAG 2.2 linearize-then-ratio contrast implementation: (L+0.05)/(L2+0.05)"
    - "Regex-based CTA bg-color extraction from role=link anchor tags for contrast assertions"
    - "String-pattern CSS deny-list gate (no AST parsing needed for the 5 targeted constructs)"

key-files:
  created:
    - lib/sigra/a11y/contrast.ex
    - lib/sigra/email/css_lint.ex
    - priv/sigra/email/caniemail-allowlist.json
    - test/example/test/support/email_assertions.ex
    - test/sigra/a11y/contrast_test.exs
    - test/sigra/email/css_lint_test.exs
  modified:
    - priv/templates/sigra.install/core/emails.ex
    - test/example/lib/example/accounts/emails.ex
    - test/example/test/example/accounts/emails_security_html_test.exs
    - test/example/test/example/accounts/emails_lifecycle_html_test.exs

key-decisions:
  - "Use string-pattern matching for CSS deny-list gate (no CSS AST parsing): sufficient for the 5 targeted constructs (flex, grid, position, background-image, style-block)"
  - "Implement Sigra.A11y.Contrast under lib/sigra/a11y/ (own namespace) to allow future reuse for LiveView UI assertions"
  - "Load caniemail allowlist at compile time with @external_resource + Jason.decode! — zero I/O during CI test runs"
  - "#2563eb contrast is actually 5.17:1 (plan doc stated 4.36 — plan had incorrect WCAG ratio). #1d4ed8 is 6.70:1. Both clear 4.5 AA; bump is still correct direction (stronger gate, eliminates large-text-bold edge case discussion)"
  - "G9 boundary: remaining <= 2 triggers low-codes warning (not <= 3). Test confirms remaining: 3 is first safe value"
  - "Example.EmailAssertions regex extracts CTA color from both role/style ordering combinations in anchor tags"

patterns-established:
  - "Phase 86 G1-G9 locked rubric: each email test file imports Example.EmailAssertions and calls assert_cta_contrast, assert_under_gmail_clip, assert_text_part_mirrors_html, assert_email_to, assert_xss_escaped, assert_no_outlook_landmines"
  - "CssLint.lint/1 called inline per-test as: assert :ok = CssLint.lint(email.html_body)"

requirements-completed: [GAUAT-01, GAUAT-02]

# Metrics
duration: 27min
completed: 2026-04-26
---

# Phase 86 Plan 01: GAUAT Email Visual QA — ExUnit Harness and Accessibility Guardrails

**WCAG contrast calculator, caniemail CSS lint gate, and 121-test G1-G9 rubric for all 9 Phase 04/08 email templates with CTA color bumped from #2563eb to #1d4ed8 (6.70:1 on white)**

## Performance

- **Duration:** ~27 min
- **Started:** 2026-04-26T17:35:00Z
- **Completed:** 2026-04-26T18:02:21Z
- **Tasks:** 3
- **Files modified:** 10

## Accomplishments

- Created `Sigra.A11y.Contrast` with WCAG 2.2-compliant `relative_luminance/1` and `ratio/2` functions, verified by 13 unit tests including D-86-07 threshold assertions
- Created `Sigra.Email.CssLint` with vendored `caniemail-allowlist.json` policy for Gmail web / new Outlook web / Apple Mail, verified by 11 unit tests covering all 5 deny-list CSS constructs
- Bumped CTA button color from `#2563eb` to `#1d4ed8` in both the template source and the generated example app (contrast improves from 5.17:1 to 6.70:1 — eliminates large-text-bold edge case discussion)
- Extended `emails_security_html_test.exs` and `emails_lifecycle_html_test.exs` from 17 total tests to 121, closing all 9 Phase 86 rubric gaps (G1 contrast, G2 byte budget, G3 URL parity, G4 recipient correctness, G5 XSS escaping, G6 Outlook deny-list, G7 image tripwire, G8 default-arg DateTime.utc_now/0 branches, G9 backup-code boundaries at remaining: 1/2/3)

## Task Commits

Each task was committed atomically via TDD RED/GREEN cycle:

1. **Task 1 RED: Failing contrast tests** — `cff1bf5` (test)
2. **Task 1 GREEN: Sigra.A11y.Contrast + Example.EmailAssertions** — `84f5057` (feat)
3. **Task 2 RED: Failing CssLint tests** — `68cf988` (test)
4. **Task 2 GREEN: CssLint + allowlist JSON + CTA color bump** — `d75b75a` (feat)
5. **Task 3: Extend Phase 04/08 email tests to close G1-G9** — `6e860ec` (feat)

## Files Created/Modified

- `/lib/sigra/a11y/contrast.ex` — WCAG 2.2 luminance + contrast ratio with error tuples on malformed input
- `/lib/sigra/email/css_lint.ex` — String-pattern CSS deny-list gate, policy loaded from vendored JSON at compile time
- `/priv/sigra/email/caniemail-allowlist.json` — Curated caniemail policy for gmail-web, outlook-web-new, apple-mail-macos
- `/test/example/test/support/email_assertions.ex` — G1-G6 shared helpers: assert_cta_contrast, assert_under_gmail_clip, assert_text_part_mirrors_html, assert_email_to, assert_xss_escaped, assert_no_outlook_landmines
- `/test/sigra/a11y/contrast_test.exs` — 13 AAA-flat unit tests for contrast math
- `/test/sigra/email/css_lint_test.exs` — 11 unit tests for lint/1 and allowlist/0 API
- `/priv/templates/sigra.install/core/emails.ex` — CTA color bump #2563eb → #1d4ed8
- `/test/example/lib/example/accounts/emails.ex` — Same CTA color bump in generated example app
- `/test/example/test/example/accounts/emails_security_html_test.exs` — Extended from 3 to ~35 tests with G1-G9 coverage for Phase 04 templates
- `/test/example/test/example/accounts/emails_lifecycle_html_test.exs` — Extended from ~14 to ~86 tests with G1-G9 coverage for Phase 08 templates

## Decisions Made

- **String-pattern CSS lint** (not AST parsing): sufficient for the 5 deny-list constructs; simpler, zero external deps
- **Contrast calculation correction**: Plan doc claimed `#2563eb` = 4.36:1 but actual WCAG formula yields 5.17:1 (both old and new colors clear AA for normal text). Updated test to assert `#1d4ed8` > `#2563eb` (still correct direction at 6.70:1 vs 5.17:1). The bump remains valid.
- **`Sigra.A11y.Contrast` placed under `lib/sigra/a11y/`**: own namespace for future reuse beyond email (LiveView UI contrast assertions)
- **Compile-time JSON loading**: `@external_resource` + `Jason.decode!` ensures zero I/O during CI test runs
- **G9 boundary confirmed**: `remaining <= 2` (not `<= 3`) triggers the low-codes warning per the template implementation

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Plan contrast ratio for #2563eb was incorrect (5.17:1, not 4.36:1)**
- **Found during:** Task 1 GREEN (Sigra.A11y.Contrast implementation)
- **Issue:** Plan doc stated `#2563eb` = 4.36:1 contrast on white. Actual WCAG formula (and cross-checked with Python) gives 5.17:1. The test asserting `< 4.5` would have failed.
- **Fix:** Updated test to assert `#1d4ed8` (6.70:1) > `#2563eb` (5.17:1) — both clear 4.5 AA, but new color is unambiguously stronger. The CTA color bump rationale (eliminating the large-text-bold edge case discussion) remains valid.
- **Files modified:** `test/sigra/a11y/contrast_test.exs`
- **Committed in:** `84f5057` (Task 1 GREEN commit)

---

**Total deviations:** 1 auto-fixed (Rule 1 - bug in plan documentation)
**Impact on plan:** Minimal. The D-86-07 CTA bump direction is preserved. The contrast gate now asserts `>= 4.5` for both old and new colors (correctly). The new default `#1d4ed8` provides a stronger, unambiguous WCAG AA pass.

## Issues Encountered

None — plan executed cleanly after the contrast ratio correction.

## Known Stubs

None — all test assertions use real rendered HTML from the live example app builders.

## Threat Flags

No new trust boundaries introduced. The CSS lint module reads a vendored file at compile time (zero runtime I/O). The contrast module performs pure math. Both modules are test-only tooling.

## Self-Check: PASSED

Files verified:
- `lib/sigra/a11y/contrast.ex` — FOUND
- `lib/sigra/email/css_lint.ex` — FOUND
- `priv/sigra/email/caniemail-allowlist.json` — FOUND
- `test/example/test/support/email_assertions.ex` — FOUND
- `test/sigra/a11y/contrast_test.exs` — FOUND
- `test/sigra/email/css_lint_test.exs` — FOUND

Commits verified:
- `cff1bf5` — test(86-01): RED contrast tests
- `84f5057` — feat(86-01): Sigra.A11y.Contrast + EmailAssertions
- `68cf988` — test(86-01): RED CSS lint tests
- `d75b75a` — feat(86-01): CssLint + allowlist + CTA color bump
- `6e860ec` — feat(86-01): extended G1-G9 email tests

## Next Phase Readiness

- Plan 01 (Commit A) complete: ExUnit harness, contrast gate, CSS lint, CTA color, and G1-G9 test coverage are all landed
- Plan 02 (Commit B) can now begin: Premailex + Playwright visual regression spec, `mix sigra.email.snapshot` task, 36 baseline PNGs, `email_visual_regression` CI job, evidence artifacts

---
*Phase: 86-gauat-email-visual-qa-phase-04-phase-08-templates*
*Completed: 2026-04-26*
