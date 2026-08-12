---
phase: 242-close-gap-xw-01-xw-02-add-rendered-crosswake-start-control
verified: 2026-08-12T03:12:57Z
status: gaps_found
score: 4/4 must-haves verified
behavior_unverified: 0
overrides_applied: 0
gaps:
  - truth: "The unchanged Crosswake fail-closed continuation security matrix supplies deterministic passing evidence for XW-02."
    status: failed
    reason: "The required aggregate adapter/continuation/controller matrix failed in CrosswakeContinuationsTest: cleanup expected two rows after deleting 500 expired continuations, but observed five. The browser proof and P14 prohibition checks pass, but this failure leaves the complete XW-02 security-matrix evidence incomplete."
    artifacts:
      - path: "test/example/test/example/accounts/crosswake_continuations_test.exs"
        issue: "The cleanup test at line 224 fails under the configured shared example_test database (expected 2 rows, got 5)."
    missing:
      - "Restore deterministic isolation/cleanup for terminal Crosswake continuation rows, then rerun the complete required security matrix."
---

# Phase 242: Close gap: XW-01/XW-02 — add rendered Crosswake start control Verification Report

**Phase Goal:** Authenticated example-host users can initiate the existing Crosswake flow from a rendered, accessible `/app` control and complete the unchanged secure return journey.
**Verified:** 2026-08-12T03:12:57Z
**Status:** gaps_found
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
| --- | --- | --- | --- |
| 1 | An authenticated user can see and operate a plainly named Tasklane control on `/app` that performs the existing CSRF-protected `POST /crosswake/start`. | ✓ VERIFIED | `AppLive` renders one native `app-crosswake-start` POST form and submit button; `MIX_ENV=test mix test test/example_web/live/app_live_test.exs` passed 4/4. Router keeps the target inside `[:browser, :require_authenticated]`, and `:browser` applies `protect_from_forgery`. |
| 2 | The rendered control submits no user-selected Crosswake, session, evaluator, route, destination, or navigation values; protocol authority remains server-owned. | ✓ VERIFIED | The rendered-form test proves the CSRF hidden input, no protocol input names, and no `phx-` binding. The P14 repository, bad-fixture fail-first, and clean-fixture checks all completed with their expected results. |
| 3 | The real browser cookie jar reaches the existing Crosswake return and fixed `/app` destination by clicking the rendered control, without DOM fabrication. | ✓ VERIFIED | `scripts/ci/hosted-session-interop-proof.sh --browser-only` passed its one Chromium test: it uses the accessible button click, observes `/crosswake/return`, checks exactly `continuation`/`state`, no Referer, and final `/app` readiness. |
| 4 | The focused proof remains role-driven, readiness-driven, sleep-free, serial with one worker, and zero-retry. | ✓ VERIFIED | Browser source uses `getByRole` plus visible/readiness assertions; no synthetic submission or sleep appears. Playwright configuration retains `fullyParallel: false`, `workers: 1`, and `retries: 0`; the source-contract test passed 8/8. |

**Score:** 4/4 truths verified (0 present, behavior-unverified)

The rendered journey itself is proven. The overall status remains `gaps_found` because the Phase 242 acceptance security matrix for XW-02 has an independently reproduced failing test; successful narrower checks cannot substitute for that missing deterministic evidence.

### Required Artifacts

| Artifact | Expected | Status | Details |
| --- | --- | --- | --- |
| `test/example/lib/example_web/live/app_live.ex` | Visible native Crosswake POST control on authenticated Tasklane hub | ✓ VERIFIED | Substantive `vt-*` panel includes native `Phoenix.Component.form`, `action={~p"/crosswake/start"}`, `method="post"`, stable hook, and submit button. |
| `test/example/test/example_web/live/app_live_test.exs` | Rendered route, method, accessible-name, and zero-protocol-input contract | ✓ VERIFIED | Focused rendered HTML assertions passed 4/4. The artifact query reported a false missing literal because the regex encodes the slash as `\/`; the test and source contain the real route. |
| `test/example/priv/playwright/tests/crosswake-hosted-runtime.spec.ts` | Role-driven real-cookie-jar Crosswake journey | ✓ VERIFIED | Passed one-worker Chromium journey using `getByRole('button', { name: 'Continue to Crosswake' }).click()`. |
| `test/sigra/planning/phase_240_3_hosted_crosswake_runtime_test.exs` | Source guard for rendered entry and browser/security contract | ✓ VERIFIED | Reads `@app_live`, locks POST markers and button name, rejects `phx-*` bindings and fabricated browser submission; passed 8/8. |

### Key Link Verification

| From | To | Via | Status | Details |
| --- | --- | --- | --- | --- |
| `app_live.ex` | `router.ex` | Native POST form → existing authenticated controller route | ✓ WIRED | Form action is `/crosswake/start`; router maps that POST to `CrosswakeController.start` inside browser/authenticated pipelines. |
| Browser spec | `app_live.ex` | Accessible role/name locator clicks rendered submit control | ✓ WIRED | Browser proof visibly locates and clicks `Continue to Crosswake`; the proof passed. |
| Browser spec | `crosswake_controller.ex` | Existing return navigation uses real cookie jar | ✓ WIRED | Pre-registered return request observer verifies `/crosswake/return`; controller owns start/return and the passing browser test reaches final `/app`. |

`verify.key-links` returned structural false negatives because it expects direct cross-file references/regexes rather than Phoenix route indirection and multi-line callback predicates. Manual source tracing and executed browser evidence above verify all three links.

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
| --- | --- | --- | --- | --- |
| `app_live.ex` Crosswake form | N/A | Native CSRF form submission to router/controller | N/A — no dynamic data is rendered or client-supplied | ✓ VERIFIED |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
| --- | --- | --- | --- |
| Rendered native form and no protocol inputs | `source tmp/db.env; cd test/example && MIX_ENV=test mix test test/example_web/live/app_live_test.exs` | 4 tests, 0 failures | ✓ PASS |
| Source contract for form, click, and serial configuration | `MIX_ENV=test mix test test/sigra/planning/phase_240_3_hosted_crosswake_runtime_test.exs` | 8 tests, 0 failures | ✓ PASS |
| Real cookie-jar journey | `scripts/ci/hosted-session-interop-proof.sh --browser-only` | 1 Chromium test passed | ✓ PASS |
| XW-02 fail-closed aggregate security matrix | Adapter + continuation + controller + P14 real/bad/clean command from the plan | 28 tests, 1 failure: cleanup count expected 2, got 5; P14 was then run separately and passed repository/fail-first/clean controls | ✗ FAIL |

### Probe Execution

No Phase 242 probe scripts were declared or discovered; the browser runner above is the phase’s runnable integration proof.

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
| --- | --- | --- | --- | --- |
| XW-01 | `242-01-PLAN.md` | A backend-validated personal-account session can project to `crosswake_sigra` without organization invention or credential/token exposure. | ✓ SATISFIED | Rendered native entry, real browser journey, and P14 authority/secret checks all pass. |
| XW-02 | `242-01-PLAN.md` | Missing, expired, revoked, or account-switched state fails closed; return data alone never grants access. | ✗ BLOCKED | P14 controls pass, but the required aggregate continuation security matrix fails before it can provide a clean deterministic XW-02 result. |

`REQUIREMENTS.md` maps XW-01/XW-02 to the original Phase 239 and does not list Phase 242 in its traceability table. Both IDs are nevertheless explicitly declared in this phase plan and have been checked; no additional Phase 242 requirement IDs are orphaned.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
| --- | --- | --- | --- | --- |
| `test/example/lib/example_web/live/app_live.ex` | 128 | `mix format --check-formatted` fails on new `<.form>` layout | ⚠️ Warning | Reproduced advisory formatter defect; does not affect rendered route, CSRF form behavior, accessibility, or browser journey. |
| `test/example/test/example_web/live/app_live_test.exs` | 47-48 | `mix format --check-formatted` fails on new regex assertions | ⚠️ Warning | Reproduced advisory formatter defect; focused test behavior passes. |
| `test/sigra/planning/phase_240_3_hosted_crosswake_runtime_test.exs` | 222-229 | `mix format --check-formatted` fails, including changed assertions and pre-existing long calls | ⚠️ Warning | Reproduced advisory formatter defect; source contract passes. |

The three formatter warnings from `242-REVIEW.md` are real and should be fixed, but they are quality warnings rather than must-have implementation failures: they do not block the Phase 242 user flow. No `TBD`, `FIXME`, `XXX`, placeholder, empty implementation, fabricated submission, or sleep was found in the four phase files.

### Gaps Summary

One gap blocks certification: the required aggregate XW-02 security matrix currently fails at `CrosswakeContinuationsTest`’s terminal-row cleanup assertion (`expected 2`, `got 5`). The failure occurs in an unchanged predecessor test file and is consistent with residual/shared database state, but that explanation is not passing evidence. Repair deterministic isolation or cleanup and rerun the full security matrix before declaring the unchanged secure-return journey completely verified.

---

_Verified: 2026-08-12T03:12:57Z_
_Verifier: the agent (gsd-verifier)_
