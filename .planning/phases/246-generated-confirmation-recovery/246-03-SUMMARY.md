---
phase: 246-generated-confirmation-recovery
plan: 03
subsystem: auth
tags: [elixir, phoenix-liveview, playwright, ci-evidence]
requires:
  - phase: 246-01
    provides: Explicit link confirmation, optional-scope routes, and fresh-host persisted-state proof.
  - phase: 246-02
    provides: Account-scoped spaced-code verification and visible retryable feedback.
provides:
  - Real generated-host Chromium proof for literal spaced-code paste, invalid feedback, retry, and success.
  - Static CI route contract connecting the browser journey to the required generated-host job and ci-gate.
  - Machine-readable local and recurring-CI evidence receipt bound to the exact final source SHA.
affects: [phase-246-generated-confirmation-recovery]
tech-stack:
  added: []
  patterns: [isolated generated-host Playwright project, bounded mailbox polling, committed CI evidence receipt]
key-files:
  created:
    - test/example/priv/playwright/tests/generated-confirmation.spec.ts
    - test/sigra/install/generated_confirmation_ci_contract_test.exs
    - .planning/phases/246-generated-confirmation-recovery/246-CI-EVIDENCE.json
    - .planning/phases/246-generated-confirmation-recovery/246-MIX-CI-BLOCKED.md
    - .planning/phases/246-generated-confirmation-recovery/246-MIX-CI-FAILURES.json
    - test/example/priv/playwright/spec-ownership.json
  modified:
    - test/example/priv/playwright/playwright.config.ts
    - scripts/ci/admin-acceptance-smoke.sh
    - test/sigra/install/auth_ui_contract_test.exs
    - test/sigra/planning/phase_242_shift_left_contract_test.exs
    - priv/templates/sigra.install/core/confirmation_live.ex
    - scripts/ci/generated-confirmation-probe.exs
    - test/sigra/templates/installer_drift_test.exs
    - test/sigra/planning/phase_234_playwright_inventory_contract_test.exs
    - .planning/phases/246-generated-confirmation-recovery/246-VALIDATION.md
decisions:
  - "The exact-source CI run and one failed-job retry passed after repairing the confirmation defects and refreshing the generated install golden."
  - "The workflow receipt binds required jobs and supporting browser lanes to one immutable source SHA."
metrics:
  duration: 45min initial execution plus 30min scoped verification follow-up
  completed: 2026-10-07
  commits: 9
  plan_head_before: d25c46bdf85d9ebba4978f2a680d162d11c728c9
  plan_head_after: fd75cad25fd29d1fd59c79bbf937e0cdd8aaf57a
actuals:
  tokens: 3082
  tasks: 2
  commits: 9
status: complete
---

# Phase 246 Plan 03: Generated Confirmation Recovery Summary

**The generated-host Chromium journey and required-CI route are implemented and verified on the exact final source.**

## Accomplishments

- Added the dedicated `generated-host-chromium` project and one scenario that registers an unconfirmed account, observes LiveView readiness, retrieves its real email, pastes the literal spaced code, sees invalid feedback, retries, and sees success.
- Added `--test confirmation` and included that scenario in required `--test all` before host teardown, preserving the admin suite and revocation recheck.
- Added a three-test source contract tying the runner to the existing generated-admin job and required `ci-gate`.
- Fixed WR-01: authorization precedes code validation, so every anonymous code shape receives sign-in guidance. The generated probe covers malformed and nil submissions as well as valid input.
- Reconciled the optional-scope installer guard and current Playwright ownership. The new current registry preserves the archived inventory's exact captured bytes and Phase 235 provenance.
- Retained exact-source test evidence, all four final CI failure messages, prior failure observations, clean code review, and honest missing workflow conclusions.

## Task Commits

| Change | Commit |
|---|---|
| Generated-host browser, project and runner | `09f9c468` |
| Required CI route contract | `17b2b97a` |
| Formatter corrections | `59d8deaf`, `78f973a4` |
| Anonymous malformed-input regression and fix | `a0826442`, `1ca5f21e` |
| Optional-scope installer drift guard | `6f10be85` |
| Current browser ownership and immutable archive preservation | `306a7865e`, `fd75cad25` |

Final reviewed source: `fd75cad25fd29d1fd59c79bbf937e0cdd8aaf57a`. Planning-only evidence commits follow this source commit.

## Verification

| Check | Observed result |
|---|---|
| Original scoped ExUnit suite | **236 tests, 0 failures** at source `fd75cad25fd29d1fd59c79bbf937e0cdd8aaf57a`; the later follow-up regression suite passed **48/0** at `228b359b8`. |
| Fresh-host installer | **8 tests, 0 failures** locally at `6f10be8504075d3b8a676f6ef1b064dd2783387b`; the exact final source also passed the required remote install-smoke lane. |
| Golden/idempotency contract | **4 tests, 0 failures** at exact final source `90ec16f72a71d33224c0816ad77762e2e7262c76`. |
| Generated-host browser smoke | Local full acceptance passed at the reviewed behavior source; the exact final source passed `generated_admin_playwright_smoke` in required CI. |
| Historical clean-source `MIX_ENV=test mix ci` | **Exit 2: 2623 tests, 4 failures, 12 skips, 22 exclusions** at source `fd75cad25`; the exact final-source CI library lane passed. |
| Historical example `mix precommit` | **Failed** at source `fd75cad25`: test-environment `/dev/mailbox` route warning fails compile with warnings-as-errors. The required exact-source CI lanes passed. |
| Re-review | **19 files, 0 findings** in the original broad review; follow-up review resolved CR-01 and CR-02, and the final golden-only change was inspected. |
| Required GitHub CI | **Passed** at exact source `90ec16f72a71d33224c0816ad77762e2e7262c76`: run [37676348766](https://github.com/szTheory/sigra/actions/runs/37676348766), attempt 2. `ci-gate`, fresh install smoke, generated-admin Playwright, all five example Playwright shards, and admin-eval passed. |

`246-CI-EVIDENCE.json` binds the successful receipt to the exact final source and retains earlier local diagnostics. The first workflow attempt exposed a transient Ubuntu dependency-fetch stall, an aggregate cancellation, and one admin-eval navigation timeout; the single failed-job rerun on the same SHA passed all checks. `246-MIX-CI-FAILURES.json` remains the historical local diagnostic record.

## Deviations from Plan

- **Rule 3 — required formatter prerequisite:** formatting-only repairs to two tests allowed the local gate to progress.
- **Rule 3 — exact-source environment:** a clean detached verification checkout and private Hex cache avoided mixed dependency versions. A fresh compile removed stale dependency-off output. Nested sandbox fixtures were verified with the enclosing sandbox limitation removed.
- **Review fix:** observed malformed-anonymous regression RED (5 tests, 1 failure), repaired scope checking, then observed GREEN (5 tests, 0 failures) and the 8-test fresh-host installer proof.
- **Phase integration repair:** updated the optional-scope drift guard and exact browser ownership mapping. An initial archived inventory edit exposed its captured hash dependency; the historical bytes were restored and live reconciliation moved to `spec-ownership.json`. Current and historical inventory contracts pass together.
- **Browser environment and retry:** installed Chromium matching committed Playwright 1.59.1 after a missing-executable launch. The first actual suite timed out on existing admin branding LiveView readiness; its single retry passed. The initial failure is retained.

## Required CI Gate

The earlier local `mix ci` failure was recorded against source `fd75cad25fd29d1fd59c79bbf937e0cdd8aaf57a` and retained in `246-MIX-CI-BLOCKED.md`. The final exact-source workflow subsequently ran the `Library tests` shard (`MIX_ENV=test mix ci`) and every required phase gate successfully on `90ec16f72a71d33224c0816ad77762e2e7262c76`.

Task 1's local browser proof and Task 2's exact-source CI receipt are complete. Plan 246-03 is **complete**; phase-level verification is recorded in `246-VERIFICATION.md`.

## TDD Gate Compliance

The new browser exercises wrong-code/retry/success without sleeps. The malformed-anonymous probe was observed RED then GREEN. Global phase `tdd_mode` is false. The exact-source CI receipt closes the recurring-CI evidence requirement.

## Known Stubs

None found in the changed source. Required CI proof is missing evidence, not a stub.

## Self-Check: COMPLETE

Source artifacts, task commits, local receipts, clean code review, security audit, and exact-source required CI exist. Phase-level verification is recorded separately.
