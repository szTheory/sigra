---
phase: 238-generated-auth-runtime-proof
verified: 2026-08-05T16:09:39Z
status: gaps_found
score: 0/3 must-haves verified
behavior_unverified: 0
overrides_applied: 0
gaps:
  - truth: "Browser coverage proves registration, confirmation, password sign-in and logout, magic-link request/verification, and password-reset completion in a generated B2C host."
    status: failed
    reason: "The authoritative exact-SHA generated-host runtime job is red; no successful browser execution exists."
    artifacts:
      - path: "scripts/ci/generated-auth-runtime-proof.sh"
        issue: "After changing into the disposable generated app, assert_locked_contract reads relative $0 and cannot find the harness."
    missing:
      - "Repair the self-reference, then obtain a successful exact-SHA Generated auth runtime proof job."
  - truth: "A deterministic provider double proves Google OAuth start, callback, and account-link collision behavior without CI credentials."
    status: failed
    reason: "Both exact-SHA CI attempts failed before the Playwright proof could establish the Google start/callback/collision behavior."
    artifacts:
      - path: "scripts/ci/generated-auth-runtime-proof.sh"
        issue: "The corrected-SHA runtime job 92359472633 failed at the focused-probe self-reference check."
    missing:
      - "A green exact-SHA CI run of the focused OAuth probe and the full generated-auth suite."
  - truth: "Every rendered B2C auth state passes Axe plus stable label/control and duplicate-ID checks."
    status: failed
    reason: "The assertions are present in source but no successful generated-host browser run exercised them."
    artifacts:
      - path: "test/example/priv/playwright/tests/generated-auth.spec.ts"
        issue: "State-scoped Axe and DOM checks are blocked behind the failing fresh-host harness."
    missing:
      - "A successful exact-SHA browser execution covering the rendered states."
---

# Phase 238: Generated Auth Runtime Proof Verification Report

**Phase Goal:** Establish deterministic browser and accessibility proof for the generated B2C email and Google authentication journeys without provider credentials.
**Verified:** 2026-08-05T16:09:39Z
**Status:** gaps_found
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
| --- | --- | --- | --- |
| 1 | Browser coverage proves registration, confirmation, password sign-in/logout, magic-link request/verification, and password-reset completion in a generated B2C host. | ✗ FAILED | The direct runtime job failed on both available exact SHAs. No browser test ran successfully against the fresh host. |
| 2 | A deterministic provider double proves Google OAuth start, callback, and account-link collision behavior without CI credentials. | ✗ FAILED | The full runtime job is red on `85b94ff5`; the harness still checks relative `$0` after `cd "${APP_DIR}"`, so it cannot locate itself. |
| 3 | Every rendered B2C auth state passes Axe plus stable label/control and duplicate-ID checks. | ✗ FAILED | `generated-auth.spec.ts` contains the checks, but the authoritative runtime execution failed before it could exercise them. |

**Score:** 0/3 truths verified (0 present, behavior-unverified)

## Required Artifacts

| Artifact | Expected | Status | Details |
| --- | --- | --- | --- |
| `scripts/ci/generated-auth-runtime-proof.sh` | Fresh-host lifecycle and local OIDC double | ✗ FAILED | Exists (250 lines), substantive, and selected by CI, but its runtime self-check uses `rg ... "$0"` after changing into the temporary app. The corrected exact-SHA job fails there. |
| `test/example/priv/playwright/tests/generated-auth-oauth-probe.spec.ts` | Browser proof of generated Google start/callback/collision | ⚠️ BLOCKED | Exists (36 lines) and is allowlisted/wired to the dedicated project, but has no passing generated-host execution. |
| `test/example/priv/playwright/tests/generated-auth.spec.ts` | Serial email journey plus state-scoped accessibility checks | ⚠️ BLOCKED | Exists (221 lines), uses generated forms and mailbox links, and is wired to the harness/project; its runtime assertions remain unexecuted. |
| `test/example/priv/playwright/fixtures/mailbox.ts` | Bounded, no-sleep mail link extraction | ✓ VERIFIED (source) | Uses `expect.poll`, recipient/route filtering, newest timestamp ordering, and no fixed-delay wait. This does not prove the end-to-end journey. |
| `test/example/priv/playwright/playwright.config.ts` | Isolated generated-auth project | ✓ VERIFIED (source) | Dedicated `generated-auth` Desktop Chrome project; global workers 1 and retries 0; generic projects ignore generated-host specs. |
| `.github/workflows/ci.yml` | Direct PostgreSQL/Chromium proof lane | ✓ VERIFIED (wiring) | Unconditional `generated_auth_runtime_proof` job runs the harness with PostgreSQL and Chromium. Its two recorded runs are failures, so the lane does not supply acceptance evidence. |

## Key Link Verification

| From | To | Via | Status | Details |
| --- | --- | --- | --- | --- |
| `scripts/ci/generated-auth-runtime-proof.sh` | Phase 237 fresh-host lifecycle | copied scaffold/install/generate/migrate/boot flow | ✓ WIRED (source) | Script scaffolds, installs with `--no-admin --no-organizations --no-passkeys`, generates Google OAuth, migrates, boots, and invokes Playwright. |
| `generated-auth-oauth-probe.spec.ts` | generated `/auth/google` controller path | browser navigation and redirect | ⚠️ BLOCKED | Source begins at `/auth/google` and observes the loopback authorize request; no successful runtime result verifies the transition. |
| `generated-auth.spec.ts` | mailbox fixture | emitted confirmation/magic/reset links | ⚠️ BLOCKED | Imported extractors are called for all three routes; fresh-host execution remains blocked. |
| `.github/workflows/ci.yml` | harness | `GITHUB_WORKSPACE="$PWD" scripts/ci/generated-auth-runtime-proof.sh --all` | ✗ FAILED | Wiring is present, but both exact-SHA job conclusions are `failure`. |

## Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
| --- | --- | --- | --- | --- |
| `generated-auth.spec.ts` | confirmation/magic/reset URLs | `/dev/mailbox/json` through `expect.poll` | Designed to consume generated-host mailbox data; no successful runtime response captured | ⚠️ BLOCKED |
| `generated-auth-oauth-probe.spec.ts` | authorization request/callback result | loopback OIDC discovery/authorize/token endpoints | Local provider double is implemented, but red CI prevents proof that generated traffic completes it | ⚠️ BLOCKED |

## Behavioral Spot-Checks

| Behavior | Command / evidence | Result | Status |
| --- | --- | --- | --- |
| Harness parses | `bash -n scripts/ci/generated-auth-runtime-proof.sh` | Exit 0 | ✓ PASS (syntax only) |
| Source guards remain installed | `MIX_ENV=test mix test test/sigra/planning/phase_238_generated_auth_runtime_proof_test.exs` | 3 tests, 0 failures | ✓ PASS (source contract only) |
| Exact evidence validates as green | Plan 05 `jq -e` success predicate | Exit 1; `.workflow.conclusion` is absent and run/job conclusions are `failure` | ✗ FAIL |
| Fresh-host browser suite | CI run `31021611104`, job `92359472633`, SHA `85b94ff503dd3513847b4ae20bd87ca6b1a7bdc8` | Job conclusion `failure` | ✗ FAIL |

## Probe Execution

| Probe | Command | Result | Status |
| --- | --- | --- | --- |
| Generated auth runtime proof | `GITHUB_WORKSPACE="$PWD" scripts/ci/generated-auth-runtime-proof.sh --all` in CI | `31019501361` / SHA `13a9f12e`: failed before harness execution because the file was not executable; `31021611104` / SHA `85b94ff5`: failed in harness due to relative `$0` after `cd` | ✗ FAILED |

## Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
| --- | --- | --- | --- | --- |
| AUTH-01 | 238-02, 238-04, 238-05 | Generated-host email registration, confirmation, password, magic-link, and reset journey | ✗ BLOCKED | Browser spec exists, but the only direct CI runtime evidence is red. |
| AUTH-02 | 238-01, 238-03, 238-04, 238-05 | Generated Google start/callback/collision through deterministic provider double | ✗ BLOCKED | Loopback double/probes exist, but neither exact-SHA job provides a successful browser result. |
| AUTH-03 | 238-03, 238-04, 238-05 | Axe, label/control, and duplicate-ID checks on each rendered auth state | ✗ BLOCKED | Assertions exist only as unexecuted source until the fresh-host lane is green. |

## Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
| --- | --- | --- | --- | --- |
| `scripts/ci/generated-auth-runtime-proof.sh` | 199 | Reads relative `$0` in `assert_locked_contract` after `boot_and_run_spec` changes working directory to `APP_DIR` at line 212 | 🛑 Blocker | Stops the CI harness before it can run either browser spec, leaving all AUTH runtime requirements unproven. |

No untracked `TBD`, `FIXME`, or `XXX` markers were found in Phase 238 source files. The workflow's unrelated tracked TODO references are outside the phase lane.

## Disconfirmation Pass

- **Partial requirement:** the CI lane and browser specs are implemented, but no exact-SHA execution proves their behavior; source presence cannot satisfy AUTH-01 through AUTH-03.
- **Misleading passing test:** the three passing ExUnit tests inspect source strings and project configuration. They do not create a generated host, execute Playwright, or prove an OAuth callback/accessibility transition.
- **Uncovered error path:** the harness changes directory before validating its own focused-probe entry point. The red CI result demonstrates this path was not exercised by the source contract.

## Gaps Summary

The phase goal is not achieved. Phase 238 explicitly made a green exact-commit PostgreSQL/Chromium run the acceptance boundary; both available runs fail, and the committed runtime harness still contains the deterministic failure recorded in `238-EVIDENCE.json`. The required recovery is to make the harness self-reference absolute (for example, use the already-computed `CI_DIR`), then obtain and record a green direct `Generated auth runtime proof` job on the corrected implementation SHA. Human UAT, local source-contract tests, or an unrelated SHA cannot close these gaps.

_Verified: 2026-08-05T16:09:39Z_
_Verifier: the agent (gsd-verifier)_
