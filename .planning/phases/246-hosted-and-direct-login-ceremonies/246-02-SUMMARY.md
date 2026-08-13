---
phase: 246-hosted-and-direct-login-ceremonies
plan: 02
subsystem: auth
tags: [hosted-login, pkce, app-session, postgresql]
requires:
  - phase: 246-01
    provides: Locked hosted-code exchange and app-session issuance
provides:
  - Static first-party profile registry with exact callback policy
  - S256 PKCE validation and signed explicit-approval continuation
affects: [246-03, 246-07, 246-08, hosted-login]
tech-stack:
  added: []
  patterns: [static profile lookup, literal callback matching, digest-only authorization code]
key-files:
  created: [lib/sigra/app_login/pkce.ex]
  modified: [lib/sigra/config.ex, lib/sigra/app_login.ex, lib/sigra/app_login/attempt.ex, test/sigra/config_test.exs, test/sigra/app_login_test.exs]
key-decisions:
  - "Hosted codes retain only the S256 challenge digest, never a PKCE verifier."
  - "Every authenticated browser must explicitly approve before code persistence."
requirements-completed: [APP-02]
coverage:
  - id: D1
    description: Static profiles accept only literal registered callbacks and strict S256/start state.
    requirement: APP-02
    verification:
      - kind: integration
        ref: test/sigra/config_test.exs and test/sigra/app_login_test.exs
        status: pass
    human_judgment: false
  - id: D2
    description: Explicit approval persists a digest-only code for exactly 60 seconds and exchanges it with S256 proof.
    requirement: APP-02
    verification:
      - kind: integration
        ref: test/sigra/app_login_test.exs#starts-explicitly-approves-and-exchanges-one-S256-bound-hosted-ceremony
        status: pass
    human_judgment: false
duration: 16min
completed: 2026-08-13
status: complete
---

# Phase 246 Plan 02: Hosted Ceremony Contract Summary

**Static first-party hosted login now enforces literal callbacks, state, PKCE S256, signed approval continuation, and a 60-second digest-only code.**

## Accomplishments

- Added finite host-owned first-party profile and paired ceremony-schema validation.
- Added strict RFC 7636 verifier/challenge primitives and bound exchange to the persisted S256 challenge.
- Added explicit approve/cancel flow; no existing browser session can silently issue app credentials.

## Task Commits

1. Task 1 — `a6d86f14` (test), `d251ca12` (feat), `4ee44e48` (test)

## Deviations from Plan

### Auto-fixed Issues

1. [Rule 2 - Security] Replaced raw-verifier digest storage with the S256 challenge digest.
- Found during: Task 1
- Fix: Approval stores `SHA256(code_challenge)` and exchange derives the S256 challenge from the submitted verifier.
- Verification: focused config and hosted-login suite passed.
- Commit: `d251ca12`

## Self-Check: PASSED

