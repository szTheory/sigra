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
  - Machine-readable exact-source required-CI evidence receipt with successful job conclusions.
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
  - "Repaired the inherited CI contract drift before producing the required exact-source run; retained the initial failures and their history."
  - "A managed macOS local mix ci sandbox limitation remains separate from the successful GitHub required workflow and is not reported as a pass."
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
status: complete
---

# Phase 246 Plan 03: Generated Confirmation Recovery Summary

**The generated-host Chromium journey is implemented and verified in the required workflow for exact source `2232272d77a4ebfccafe43ddec877bf3ad6195a7`.**

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

## Required-CI Remediation

| Change | Commit |
|---|---|
| Repair inherited fast-check, golden-fixture and install-guidance contracts | `60eb84770` |
| Stabilize admin-audit URL transition after LiveView query canonicalization | `766f3e0be` |
| Await the server-rendered password-strength response before mobile registration submit | `2232272d7` |

Final reviewed and CI-tested source: `2232272d77a4ebfccafe43ddec877bf3ad6195a7`.

## Verification

| Check | Observed result |
|---|---|
| Required GitHub workflow | [Run 37558299754](https://github.com/szTheory/sigra/actions/runs/37558299754): **success** for exact source `2232272d77a4ebfccafe43ddec877bf3ad6195a7`. |
| Required install smoke | **Success** (fresh `phx.new` host and `sigra.install`), job 112589589901. |
| Required generated-admin Playwright smoke | **Success**, including confirmation browser journey, job 112589569731. |
| Required CI gate | **Success**, job 112591516371. |
| Example Playwright shards | **All five success:** admin behavior, admin checkpoints, design gallery, demo showcase, and non-admin mobile/browser journey; the full lifecycle aggregate also succeeded. |
| Admin-eval render and probe | **Success**, job 112589569771. |
| Fast checks, install matrices, library tests, dependency-off tests, upgrade, HTTP smoke, and example unit smoke | **All success** in the same workflow run. |
| Local `MIX_ENV=test mix ci` | The original four contract failures were repaired. A later local run remains **environment-limited** by nested macOS `sandbox-exec` denial and cold Threadline build output; the dependency-off subset passed **65 tests, 0 failures**. Remote exact-source CI is the required proof. |
| Re-review | **19 source files, 0 findings**; WR-01 remains recorded as fixed. |

`246-CI-EVIDENCE.json` binds every required job conclusion to the exact tested SHA and retains the original failed-run fingerprints. `246-MIX-CI-FAILURES.json` preserves the pre-repair diagnostics and earlier async Oban observation. The original failures are resolved; the local sandbox limitation remains separate from required workflow proof.

## Deviations from Plan

- **Rule 3 — required formatter prerequisite:** formatting-only repairs to two tests allowed the local gate to progress.
- **Rule 3 — exact-source environment:** a clean detached verification checkout and private Hex cache avoided mixed dependency versions. A fresh compile removed stale dependency-off output. Nested sandbox fixtures were verified with the enclosing sandbox limitation removed.
- **Review fix:** observed malformed-anonymous regression RED (5 tests, 1 failure), repaired scope checking, then observed GREEN (5 tests, 0 failures) and the 8-test fresh-host installer proof.
- **Phase integration repair:** updated the optional-scope drift guard and exact browser ownership mapping. An initial archived inventory edit exposed its captured hash dependency; the historical bytes were restored and live reconciliation moved to `spec-ownership.json`. Current and historical inventory contracts pass together.
- **Browser environment and retry:** installed Chromium matching committed Playwright 1.59.1 after a missing-executable launch. The first actual suite timed out on existing admin branding LiveView readiness; its single retry passed. The initial failure is retained.

## Required CI Gate Resolution

**Resolved.** The four failures concerned the older Phase 232 cache-key expectation, Phase 236 and Phase 242 archived evidence paths, and the README install tuple. The later mobile browser flake was fixed by waiting for the registration LiveView's password-strength response before submit. Every required job then passed in run 37558299754. See `246-MIX-CI-BLOCKED.md` for the historical diagnosis and resolution record.

Plan 246-03's implementation, required run, and exact-source receipt are complete. CONF-01 through CONF-03 have automated coverage, and the validation map is Nyquist-compliant. Final phase-level goal-backward verification remains the next workflow step; phase completion must wait for it.

## TDD Gate Compliance

The new browser exercises wrong-code/retry/success without sleeps. The malformed-anonymous probe was observed RED then GREEN. Global phase `tdd_mode` is false. Missing recurring CI is retained as a blocker.

## Known Stubs

None found in the changed source. Required CI proof is missing evidence, not a stub.

## Self-Check: COMPLETE

Source artifacts, task commits, local receipts, required exact-source CI, and review evidence exist. Plan 246-03 is complete; phase-level verification remains separate.
