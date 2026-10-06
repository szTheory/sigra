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
  modified:
    - test/example/priv/playwright/playwright.config.ts
    - scripts/ci/admin-acceptance-smoke.sh
    - test/sigra/install/auth_ui_contract_test.exs
    - test/sigra/planning/phase_242_shift_left_contract_test.exs
    - .planning/phases/246-generated-confirmation-recovery/246-VALIDATION.md
decisions:
  - "The required workflow was not pushed or dispatched because the mandatory clean-source local mix ci gate failed on unrelated planning contract gaps."
  - "Kept recurring CI job conclusions as not-run; the local generated-host smoke is recorded separately and is not presented as workflow evidence."
metrics:
  duration: 45min
  completed: 2026-10-06
  commits: 4
  plan_head_before: d25c46bdf85d9ebba4978f2a680d162d11c728c9
  plan_head_after: 78f973a43e24b0813029b0dec2285dd3f5f54a8b
actuals:
  tokens: 3082
  tasks: 2
  commits: 4
status: blocked
---

# Phase 246 Plan 03: Generated Confirmation Recovery Summary

**A fresh generated Phoenix host now proves the literal spaced email code can be pasted, rejected visibly when wrong, retried, and accepted; recurring CI proof is held by unrelated failures in the required local gate.**

## Performance

- **Duration:** approximately 45 minutes
- **Completed:** 2026-10-06
- **Tasks implemented:** 2
- **Source changes:** 6 files, 12329 bytes of zero-context diff (approximately 3082 tokens)

## Accomplishments

- Added a dedicated `generated-host-chromium` Playwright project that runs only the confirmation journey and excludes it from the general example-app projects.
- The browser journey registers an unconfirmed user, waits for LiveView connection, polls the generated mailbox with a bounded retry, pastes the exact six digits plus five spaces, asserts visible invalid-code feedback, then submits the real value and asserts visible success.
- Added focused `--test confirmation` and wired `--test all` to run the confirmation browser target before generated-server teardown. The full smoke still runs existing admin coverage and the revocation recheck.
- Added an ExUnit route contract proving the confirmation journey remains in the recurring generated-admin job and that the required `ci-gate` keeps that job as a dependency.
- Added a machine-readable receipt. It records current-source local browser and contract success, prior Plan 246-02 fresh-host evidence separately, and the absence of any current-source GitHub workflow run.

## Task Commits

1. **Task 1: Exercise literal email-code paste in the generated-host browser** — `09f9c468`
2. **Task 2: Lock the required CI route and retain its result** — `17b2b97a`
3. **Task 2 formatter correction:** `59d8deaf`
4. **Authorized prerequisite formatter fixes for the required local gate:** `78f973a4`

## Verification

| Check | Result |
|---|---|
| `PLAYWRIGHT_BROWSERS_PATH=/tmp/sigra-playwright-browsers bash scripts/ci/admin-acceptance-smoke.sh --test all` | Passed at `78f973a43e24b0813029b0dec2285dd3f5f54a8b`: 8 admin tests passed, 1 planned skip; confirmation journey 1 passed; revocation recheck 1 passed. |
| `MIX_ENV=test mix test test/sigra/install/generated_confirmation_ci_contract_test.exs` | Passed: 3 tests, 0 failures. |
| `MIX_ENV=test mix ci` in a clean committed-source checkout | **Blocked:** exit 2; full suite reported 2623 tests, 17 failures, 12 skips, 22 exclusions. Detailed failure categories are in `246-MIX-CI-BLOCKED.md`. |
| Required GitHub CI workflow | Not dispatched because the mandatory local gate failed. No run ID, URL, or job conclusions exist for this source SHA. |

The initial clean checkout could not safely reuse the main worktree's dependency directory because its installed `plug_crypto` version diverged from the committed lockfile. A private Hex cache and clean checkout resolved dependencies at the committed versions; the remaining `mix ci` failures are cross-phase planning contracts, not a dependency-resolution failure.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Formatted prerequisite files failing the required formatter gate**
- **Found during:** Task 2 local `mix ci`
- **Issue:** `test/sigra/install/auth_ui_contract_test.exs` and `test/sigra/planning/phase_242_shift_left_contract_test.exs` were not formatter-clean, preventing the required gate from progressing.
- **Fix:** Applied formatting-only changes after confirming both paths had no pre-existing dirty edits; no assertion or behavior changed.
- **Files modified:** the two test files above.
- **Commit:** `78f973a4`

**2. [Rule 3 - Blocking] Isolated locked dependencies for exact committed-source verification**
- **Found during:** Task 2 local `mix ci`
- **Issue:** Reusing `deps/` from the mixed main checkout loaded a `plug_crypto` version incompatible with the committed Phoenix lockfile; the default shared Hex cache also rejected writes.
- **Fix:** Ran the clean detached checkout with its own dependencies and a private `HEX_HOME`.
- **Files modified:** none.

### Required CI Gate Blocker

The clean-source full suite reports cross-phase failures: Phase 242's committed README/closeout evidence contract, missing Phase 236 evidence, Phase 234 inventory contracts, Phase 235 completion contracts, plus Phase 232 cache-key and Threadline forwarder tests. The exact gate output is summarized in the committed blocker note. Those unrelated files were left unchanged. Since the local gate did not pass, no evidence branch was pushed and no GitHub workflow was dispatched; the plan's actual recurring-CI success criterion remains unproven.

## TDD Gate Compliance

Task 1's browser scenario is committed and passed against the final source SHA, including the wrong-code/retry/success sequence. The browser runner's initial failure was an environment sandbox launch failure, not an observed product assertion failure; the retry used the installed pinned browser under the permitted environment. The route contract also passes at the final SHA. Global phase `tdd_mode` is false; task-level test-first execution was applied without a phase-wide TDD gate.

## Known Stubs

None found in the files changed by this plan.

## Self-Check: PASSED

- Browser spec, runner wiring, scoped CI contract, validation map, CI receipt, blocker note, and summary exist.
- Task commits `09f9c468`, `17b2b97a`, `59d8deaf`, and `78f973a4` are ancestors of the recorded source SHA.
- Current-source generated-host acceptance and the focused three-test CI route contract passed.
- Required recurring CI is explicitly recorded as not dispatched and not passed.
