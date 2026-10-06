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
  - Machine-readable local and recurring-CI evidence receipt with an honest blocked conclusion.
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
  - "Required CI was not dispatched after the clean-source local gate failed. Phase-induced drift and ownership regressions were repaired; four older contract failures remain."
  - "Kept recurring CI job conclusions as not-run; the local generated-host smoke is recorded separately and is not presented as workflow evidence."
metrics:
  duration: 45min initial execution plus 30min scoped verification follow-up
  completed: 2026-10-06
  commits: 9
  plan_head_before: d25c46bdf85d9ebba4978f2a680d162d11c728c9
  plan_head_after: fd75cad25fd29d1fd59c79bbf937e0cdd8aaf57a
actuals:
  tokens: 3082
  tasks: 2
  commits: 9
status: blocked
---

# Phase 246 Plan 03: Generated Confirmation Recovery Summary

**The generated-host Chromium journey and required-CI route are implemented; actual recurring CI proof remains blocked.**

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
| Final-source scoped ExUnit suite | **236 tests, 0 failures**, including auth, generation, UI, CI route, installer drift, current ownership and historical ratification. |
| Fresh-host installer | **8 tests, 0 failures**, generated at `6f10be8504075d3b8a676f6ef1b064dd2783387b`; generation and probe sources are byte-identical to final source. |
| Final-source `admin-acceptance-smoke.sh --test all` | **8 admin tests passed, 1 planned skip; confirmation 1 passed; revocation recheck 1 passed**, after one retry of an existing admin LiveView-readiness timeout. |
| Clean-source `MIX_ENV=test mix ci` | **Exit 2: 2623 tests, 4 failures, 12 skips, 22 exclusions**; subsequent threadline guard **65 tests, 0 failures**. |
| Example `mix precommit` | **Blocked:** existing test-environment `/dev/mailbox` route warning fails compile with warnings-as-errors. |
| Re-review | **19 source files, 0 findings**; WR-01 remains recorded as fixed. |
| Required GitHub CI | **Not dispatched.** No run ID/URL or current-source job conclusions exist. |

`246-CI-EVIDENCE.json` binds receipts to their actual source SHAs and retains log fingerprints and the first browser timeout. `246-MIX-CI-FAILURES.json` retains complete final failure diagnostics and the earlier async Oban observation. Local success is separate from required workflow proof.

## Deviations from Plan

- **Rule 3 — required formatter prerequisite:** formatting-only repairs to two tests allowed the local gate to progress.
- **Rule 3 — exact-source environment:** a clean detached verification checkout and private Hex cache avoided mixed dependency versions. A fresh compile removed stale dependency-off output. Nested sandbox fixtures were verified with the enclosing sandbox limitation removed.
- **Review fix:** observed malformed-anonymous regression RED (5 tests, 1 failure), repaired scope checking, then observed GREEN (5 tests, 0 failures) and the 8-test fresh-host installer proof.
- **Phase integration repair:** updated the optional-scope drift guard and exact browser ownership mapping. An initial archived inventory edit exposed its captured hash dependency; the historical bytes were restored and live reconciliation moved to `spec-ownership.json`. Current and historical inventory contracts pass together.
- **Browser environment and retry:** installed Chromium matching committed Playwright 1.59.1 after a missing-executable launch. The first actual suite timed out on existing admin branding LiveView readiness; its single retry passed. The initial failure is retained.

## Required CI Gate Blocker

The final four failures concern the older Phase 232 cache-key expectation, Phase 236 and Phase 242 archived evidence paths, and the committed README install tuple. Existing dirty workflow/package/docs work was preserved. The first run's classification of all 17 failures as unrelated was corrected; the phase-induced failures were repaired. See `246-MIX-CI-BLOCKED.md` for the final scope and retained diagnostics.

Task 1's local browser proof is complete. Task 2's runner/route implementation is complete, while its actual required run and conclusions remain missing. Plan 246-03 stays **blocked**, phase progress stays **2/3**, and requirements stay pending. Final phase verification and completion have not run. Resume `$gsd-execute-phase 246` after the inherited gate failures are resolved within their authorized scope.

## TDD Gate Compliance

The new browser exercises wrong-code/retry/success without sleeps. The malformed-anonymous probe was observed RED then GREEN. Global phase `tdd_mode` is false. Missing recurring CI is retained as a blocker.

## Known Stubs

None found in the changed source. Required CI proof is missing evidence, not a stub.

## Self-Check: BLOCKED

Source artifacts, task commits, local receipts and review exist. Required CI is unproven; no completion claim is made.
