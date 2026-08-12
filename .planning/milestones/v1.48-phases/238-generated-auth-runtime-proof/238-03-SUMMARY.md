---
phase: 238-generated-auth-runtime-proof
plan: 03
subsystem: testing
tags: [playwright, axe, generated-auth, oauth, accessibility]
requires:
  - phase: 238-01
    provides: Fresh B2C generated-host lifecycle and loopback OAuth provider double.
  - phase: 238-02
    provides: Serial generated email-authentication journey and deterministic mailbox links.
provides:
  - Complete generated-host browser proof for the Google collision after the email journey.
  - State-scoped Axe, label/control, and duplicate-ID evidence for rendered B2C auth states.
  - Explicit allowlisted CI selection for the complete generated-auth spec.
affects: [238-04, AUTH-02, AUTH-03]
tech-stack:
  added: []
  patterns: [state-scoped Axe checks, scoped semantic form-control diagnostics, allowlisted CI spec selection]
key-files:
  created:
    - .planning/phases/238-generated-auth-runtime-proof/238-03-SUMMARY.md
  modified:
    - test/example/priv/playwright/tests/generated-auth.spec.ts
    - scripts/ci/generated-auth-runtime-proof.sh
key-decisions:
  - "The serial email journey uses the loopback double's fixed collision email because every CI run provisions a fresh generated host."
  - "Accessibility assertions scan only one ready main.sigra-auth root and include the named rendered state in every failure."
  - "The runtime harness accepts an explicit generated-auth selector while retaining the narrow OAuth probe selector."
patterns-established:
  - "Call assertAuthState explicitly after each observable material generated-auth render; redirects to non-auth pages are asserted as redirects."
requirements-completed: [AUTH-02, AUTH-03]
coverage:
  - id: D1
    description: Complete rendered email journey proves generated Google start, loopback callback, and existing-password-email collision without provider credentials.
    requirement: AUTH-02
    verification:
      - kind: automated_ui
        ref: GITHUB_WORKSPACE="$PWD" scripts/ci/generated-auth-runtime-proof.sh --spec generated-auth
        status: unknown
    human_judgment: false
  - id: D2
    description: Each material rendered B2C auth state has scoped Axe, form naming, and duplicate-ID assertions with state-specific diagnostics.
    requirement: AUTH-03
    verification:
      - kind: automated_ui
        ref: test/example/priv/playwright/tests/generated-auth.spec.ts#generated B2C email authentication journey
        status: unknown
    human_judgment: false
duration: 15min
completed: 2026-08-05
status: complete
---

# Phase 238 Plan 03: Generated Auth Collision and Accessibility Summary

**The serial fresh-host generated-auth journey now proves the local Google collision and runs named, root-scoped accessibility and semantic DOM gates for every material B2C auth render.**

## Performance

- **Duration:** 15 min
- **Started:** 2026-08-05T14:53:00Z
- **Completed:** 2026-08-05T15:08:35Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments

- Reused the loopback double's `oauth-collision@example.test` account after the complete email journey, then proved generated `/auth/google` start, signed state, PKCE, loopback-only discovery/authorization/token exchange, and logged-out collision handling.
- Added explicit `assertAuthState` calls for registration, login variants, magic-link request/sent, reset request/sent/token, logout, invalid-password, and Google-collision login renders.
- Scoped Axe to `main.sigra-auth` with the four established WCAG tag groups, and added deterministic label-target, accessible-name, and duplicate-ID diagnostics.
- Wired the existing fresh-host harness's explicit `--spec generated-auth` selector so the plan's required CI verification command is reachable without broadening test selection.

## Task Commits

1. **Task 1: Fold the generated Google collision into the complete serial suite** - `1e6f4805` (test), `402e9310` (feat)
2. **Task 2: Gate every material auth render with Axe and DOM invariants** - `6bbf0294` (test), `0997fb20` (feat)

## Files Created/Modified

- `test/example/priv/playwright/tests/generated-auth.spec.ts` - Complete serial email and Google-collision journey with per-state accessibility gates.
- `scripts/ci/generated-auth-runtime-proof.sh` - Explicit allowlisted runner for the focused OAuth probe or complete generated-auth spec.

## Decisions Made

- Used the provider double's fixed collision email instead of a timestamped address: every harness invocation provisions an isolated generated host, and the double must return the same existing password identity.
- Treated visible root, URL, flash, heading, and LiveView connection conditions as readiness evidence; no elapsed-time browser waits were added.
- Restricted CI selection to exactly `--probe-oauth` and `--spec generated-auth` so future test expansion remains deliberate.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking integration] Made the prescribed complete-spec runtime command reachable**
- **Found during:** Task 1
- **Issue:** `scripts/ci/generated-auth-runtime-proof.sh` accepted only `--probe-oauth`, while this plan and Plan 02 require `--spec generated-auth`.
- **Fix:** Added a two-entry explicit selector allowlist and passed its selected generated-host spec to the retained fresh-host Playwright invocation.
- **Files modified:** `scripts/ci/generated-auth-runtime-proof.sh`
- **Verification:** `bash -n` passes; source contract confirms the exact allowlisted selector and spec path; Playwright discovers the selected serial spec.
- **Committed in:** `402e9310`

**Total deviations:** 1 auto-fixed (Rule 3).

## Issues Encountered

- The full runtime command was not run locally. PostgreSQL is unavailable/unreachable and no local Playwright browser binary is installed; CI must execute `GITHUB_WORKSPACE="$PWD" scripts/ci/generated-auth-runtime-proof.sh --spec generated-auth` for fresh-host runtime proof. This result is recorded as `unknown`, not passed.

## Known Stubs

None.

## User Setup Required

None - CI provisions the disposable generated B2C host and loopback provider double.

## Next Phase Readiness

- Plan 238-04 can place the complete suite in its dedicated generated-auth Playwright project.
- The focused OAuth probe and complete journey have independently allowlisted harness entry points.

## Self-Check: PASSED

- Found `test/example/priv/playwright/tests/generated-auth.spec.ts` and `scripts/ci/generated-auth-runtime-proof.sh`.
- Found task commits `1e6f4805`, `402e9310`, `6bbf0294`, and `0997fb20` in git history.
- `bash -n` passed, `git diff --check` passed, and Playwright discovered one Chromium generated-auth journey.

---
*Phase: 238-generated-auth-runtime-proof*
*Completed: 2026-08-05*
