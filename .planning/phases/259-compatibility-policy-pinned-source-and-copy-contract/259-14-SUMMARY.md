---
phase: 259-compatibility-policy-pinned-source-and-copy-contract
plan: 14
subsystem: testing
tags: [enumeration-parity, phoenix-liveview, example-host, password-reset, claims-register]

requires:
  - phase: 259-compatibility-policy-pinned-source-and-copy-contract
    provides: enumeration parity harness and public-surfaces registry (Plan 259-07), claims register in ADR 006 (Plan 259-12)
provides:
  - example-host reset request page that mounts (:new live action) and delivers for an existing account (binary email)
  - password-reset-request registry row proven parity on status, redirect, flash and body, non-vacuously
  - ExampleWeb.ResetPasswordLiveTest regression suite (route, mount, existing, unknown, case, signed-in)
  - ADR 006 claims-register row restated as bounded, in step with the registry
affects: [259-15, 259-16, 259-17, 259-18, BCOPY-03, BCOPY-07]

actuals:
  tokens: 4200
  tasks: 3
  commits: 3

plan_head_before: 193f146de3a8312729e84bc0d56d45c880ade4bd
plan_head_after: 5c34cd08314c21adf6aa6b2068cdb255e3a03568
commits: 3

tech-stack:
  added: []
  patterns:
    - "LiveView redirect capture in the parity harness: assert_redirect/2 for the flash, follow_redirect/2 against a fresh conn for the landing page body"
    - "Library-path reach test: Repo query for the reset_password UserToken row proves the existing-email probe ran the real library path, not a no-op"

key-files:
  created:
    - test/example/test/example_web/live/reset_password_live_test.exs
  modified:
    - test/example/lib/example_web/router.ex
    - test/example/lib/example_web/live/reset_password_live.ex
    - test/fixtures/brand/public-surfaces.json
    - test/example/test/example_web/enumeration_parity_test.exs
    - .planning/decisions/006-name-clearance-search-log-and-claims-register.md

key-decisions:
  - "Repaired the example host instead of waiving the surface: a plan cannot shrink a roadmap success criterion, so password-reset-request went not_proven to parity rather than being re-described."
  - "The view calls the enumeration-safe context function unconditionally with the binary email and ignores its result; the context owns the existence lookup, so the view must not branch on it."
  - "Claims-register wording is bounded to the compared dimensions, one request, example host only; no timing, delivery or rate-limit claim and no generated-host claim."
  - "No owner override written; the probe was made deterministic, so the Contingency path was not needed."

patterns-established:
  - "A server redirect from a LiveView event is reported by the parity harness as status 302 (@live_redirect_status), mirroring the existing 200 for an in-place re-render."
  - "Registry flip and register restatement ship in the same plan, because name_clearance_test cross-checks every register status against the registry state."

requirements-completed: [BCOPY-03, BCOPY-07]

coverage:
  - id: D1
    description: "Example reset request page mounts (:new live action) and delivers for an existing account (binary email, no precheck)"
    requirement: BCOPY-03
    verification:
      - kind: integration
        ref: "test/example/test/example_web/live/reset_password_live_test.exs (6 tests)"
        status: pass
    human_judgment: false
  - id: D2
    description: "password-reset-request is a parity row proven :same on status, redirect, flash and body for existing versus unknown email, with real flash and non-empty body on both sides"
    requirement: BCOPY-03
    verification:
      - kind: integration
        ref: "test/example/test/example_web/enumeration_parity_test.exs#no parity row passes as empty-versus-empty"
        status: pass
      - kind: integration
        ref: "test/example/test/example_web/enumeration_parity_test.exs#every parity row compares :same for an existing versus an unknown identity"
        status: pass
      - kind: integration
        ref: "test/example/test/example_web/enumeration_parity_test.exs#password-reset-request reaches the library"
        status: pass
    human_judgment: false
  - id: D3
    description: "Positive control still goes red exactly once across the four parity rows"
    requirement: BCOPY-03
    verification:
      - kind: integration
        ref: "test/example/test/example_web/enumeration_parity_test.exs#every parity surface can go red"
        status: pass
    human_judgment: false
  - id: D4
    description: "Claims-register row for password-reset-request reads bounded and agrees with the registry state"
    requirement: BCOPY-07
    verification:
      - kind: unit
        ref: "mix test test/sigra/brand (331 tests, includes name_clearance_test and claims_docs_test)"
        status: pass
    human_judgment: false

duration: ~12min (approximate; start epoch was not captured at executor start)
completed: 2026-11-15
status: complete
---

# Phase 259 Plan 14: Reset request page repair and password-reset-request parity Summary

**Example-host reset request page repaired (route `:new` live action, binary-email call) and `password-reset-request` flipped from not_proven to a non-vacuous parity row, with a 6-test regression suite and a bounded claims-register row.**

## Performance

- **Duration:** ~12 min (approximate; start time was not recorded)
- **Completed:** 2026-11-15
- **Tasks:** 3 (1 tracer, 2 auto)
- **Files modified:** 6 (1 created, 5 modified)

## Accomplishments

- The example reset request page now mounts: `router.ex` routes `/reset-password` with `:new`, so `ResetPasswordLive.mount/3` no longer raises `CaseClauseError` on a nil live action.
- `send_instructions` passes the submitted binary email straight to `Example.Accounts.deliver_user_reset_password_instructions/2`; the `get_user_by_email` precheck and the user-struct argument (a `FunctionClauseError` for any existing account) are gone.
- `password-reset-request` is a parity row (compare status, redirect, flash, body; blocker null). The probe submits the real LiveView form for an existing and an unknown email, reads the redirect flash with `assert_redirect/2`, follows the redirect on a fresh conn and compares `:same`.
- The probe is non-vacuous: the existing WR-08 test asserts the real info flash `If your email is in our system, you will receive reset instructions shortly.` and a non-empty body on both sides, and a separate test shows the existing email wrote exactly one `reset_password` UserToken for that account while the unknown email wrote none.
- The positive control still goes red exactly once, now across four parity rows (password-signin, magic-link-request, password-reset-request, mfa-challenge).
- ADR 006 claims-register row for `password-reset-request` reads `bounded`, with wording limited to the compared dimensions, one request, example host only.

## Task Commits

1. **Task 1: Repair the reset request page and prove password-reset-request parity end to end** - `8bf865b66` (test)
2. **Task 2: Regression suite for the repaired example reset request page** - `7341af79e` (test)
3. **Task 3: Restate the claims-register row as bounded** - `5c34cd083` (docs)

**Plan metadata:** the SUMMARY commit that follows this file, then a STATE/ROADMAP commit.

## TDD / Tracer Evidence

**Task 1 (tracer), RED observed before the repair.** After adding the registry flip, probe, `capture_live_redirect/3`, expected-flash clause and library-path test, and BEFORE touching the router or view, the parity suite ran 26 tests with 5 failures, every one `CaseClauseError ... nil` at `reset_password_live.ex:146` raised from `ResetPasswordLive.mount/3` (route has no `:new` action). Semantic assessment: the target tests executed and failed on the planned defect, not on a syntax, compile or fixture fault. This RED was not committed separately (the plan makes the tracer one commit) and was not run through `gsd_run check tdd-red-evidence`, since ExUnit output is not one of the classifier's supported report formats and the plan is `type: execute`, not `type: tdd`.

**Task 1 GREEN:** after the two repairs, 26 tests, 0 failures.

**Task 1 mutation proof:** restoring `if user = ...get_user_by_email(email)` with the user struct turned 5 tests red by name, including `password-reset-request reaches the library an existing email writes one reset token ...`, all with `FunctionClauseError ... deliver_user_reset_password_instructions/2`. Reverted.

**Task 2 mutation proofs (the RED for a regression suite over already-repaired code):**
- Removing `:new` from the router: route test, mount test and both submit tests plus the case-letter test went red by name (5 of 6); the signed-in test stayed green, as expected, because it redirects before mount. Restored.
- Restoring the user-struct call: `submitting an existing account's email redirects to log in and writes one reset token` and `an email in a different letter case than the stored one still reaches the account` went red. Restored.

### TDD Gate Compliance

Task 2 is `tdd="true"`, but its code under test was repaired in Task 1, so there is no `test(259-14)` commit preceding a `feat(259-14)` commit for it and the plan has no `feat(259-14)` commit at all. The RED for Task 2 is the mutation proofs above, run against the pre-repair code shape, not a committed failing test. Flagged here rather than hidden. The plan is `type: execute`, so no plan-level gate sequence is mandated.

## Files Created/Modified

- `test/example/lib/example_web/router.ex` - `live "/reset-password", ResetPasswordLive, :new`
- `test/example/lib/example_web/live/reset_password_live.ex` - `send_instructions` passes the binary email unconditionally
- `test/fixtures/brand/public-surfaces.json` - `password-reset-request` row: state parity, compare status/redirect/flash/body, blocker null, new bounded note
- `test/example/test/example_web/enumeration_parity_test.exs` - `@live_redirect_status`, `submit_reset_request/1`, `capture_live_redirect/3`, probe clause, expected-flash clause, `reset_tokens/1`, library-reach test
- `test/example/test/example_web/live/reset_password_live_test.exs` - new `ExampleWeb.ResetPasswordLiveTest` (6 tests)
- `.planning/decisions/006-name-clearance-search-log-and-claims-register.md` - Evidence and Status cells of one row

## Decisions Made

- Repair rather than waive: the surface is proven, not re-described, because a plan cannot shrink a roadmap success criterion.
- The view does not branch on account existence; the context function owns the lookup and is the enumeration-safe entry point.
- A `{:error, :rate_limited}` result is ignored in the view (same flash shown), as the plan specified.
- Register wording claims no more than the compare list: one request, example host only, delivery/timing/rate limit/generated page not compared.

## Deviations from Plan

None - plan executed exactly as written.

The plan asked that any further example-host defect exposed by mounting or submitting be fixed minimally and listed here for Plan 259-17. None appeared: the two documented repairs were sufficient, and no import or gettext fault surfaced.

**Total deviations:** 0 auto-fixed.

## Issues Encountered

- **Intentional intermediate red.** Commits `8bf865b66` and `7341af79e` each leave `test/sigra/brand/name_clearance_test.exs` red (1 failure, `{"password-reset-request", :status_mismatch}`), because Task 1 flips the registry before Task 3 restates the register. I confirmed this as a control before editing the register. The plan scopes the green requirement to its final commit, which is `5c34cd083` (brand suite: 331 tests, 0 failures). It is a bisect hazard for those two commits only.
- `mix format` is run only on the files this plan touched, per the plan (it must not be run across `test/example`).

## Verification Results

| Check | Result |
|-------|--------|
| Parity suite + reset suite (`--include example_app`) | 32 tests, 0 failures |
| Whole example suite (`--include example_app`) | 375 tests, 0 failures |
| `mix test test/sigra/brand` | 331 tests, 0 failures |
| Zero shipped bytes vs `62ef40442` (lib, priv, brandbook, brand, .github, scripts) | pass; control: tracked shipped paths exist and a non-empty shipped diff makes `test -z` fail |
| Privacy gate (no `/Users/...` or `/home/...` in the diff outside the phase dir) | pass; control: planted path matched |
| `mix format --check-formatted` (repo root) | pass |
| Acceptance greps | `ResetPasswordLive, :new` = 1; `get_user_by_email` in view = 0; not_proven = 4; parity = 4; probe = 1; register row has 0 `not proven`, 1 `bounded` |

## Known Stubs

None.

## Threat Flags

None. No new network endpoint, auth path or trust-boundary file access was introduced; the only changed behavior is in the example host (test code).

## Handoff to later plans

- **259-17 (generated-host todo):** the generated templates carry the same two defects (`priv/templates/sigra.install/core/reset_password_live.ex` and `reset_password_controller.ex` pass a user struct to a binary-only head; the generated route may lack `:new`). This plan did not touch `lib/` or `priv/`. The registry row `password-reset-request` still has `todo: null`, which 259-17 wires. The 259-07 item 1 entry in `deferred-items.md` is now resolved for the example host only.
- **259-18:** the "Where it appears" cell for this register row (README and guide wording) was deliberately left unchanged for that plan.
- **Requirements:** `BCOPY-03` and `BCOPY-07` are declared by sibling plans 15-18 that have no SUMMARY yet, so `requirements.ready-ids` reports both blocked and they are not marked complete here.

## Self-Check: PASSED

All six created/modified files exist; commits `8bf865b66`, `7341af79e`, `5c34cd083` are ancestors of HEAD (a planted bogus hash is reported MISSING).

---
*Phase: 259-compatibility-policy-pinned-source-and-copy-contract*
*Completed: 2026-11-15*
