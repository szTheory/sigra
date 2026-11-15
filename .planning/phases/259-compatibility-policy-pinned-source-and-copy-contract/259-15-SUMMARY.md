---
phase: 259-compatibility-policy-pinned-source-and-copy-contract
plan: 15
subsystem: testing
tags: [enumeration-parity, phoenix-liveview, example-host, confirmation, claims-register]

requires:
  - phase: 259-compatibility-policy-pinned-source-and-copy-contract
    provides: enumeration parity harness and registry (Plan 259-07), claims register (Plan 259-12), LiveView redirect capture helper (Plan 259-14)
provides:
  - example-host confirm page reachable in both session states (live_session :confirmation on :mount_current_scope, outside the redirect-if-authenticated scope)
  - nil-safe session_user/1 in ExampleWeb.ConfirmationLive; anonymous resend and code entry flash and redirect to log in instead of raising
  - ExampleWeb.ConfirmationLiveTest regression suite (9 tests, asserts confirmed_at and token rows)
  - confirmation-resend registry row proven parity (status, redirect, flash, body, result), non-vacuously, with a token-count control
  - ADR 006 claims-register row restated as bounded, in the same commit as the registry flip
affects: [259-16, 259-17, 259-18, BCOPY-03, BCOPY-07]

actuals:
  tokens: 5490
  tasks: 2
  commits: 2

plan_head_before: fda8d7b841f5bdce495faee3b411536cdd4155de
plan_head_after: 26f1039b34baf259166b550c50e63885bd325aca
commits: 2

tech-stack:
  added: []
  patterns:
    - "Probe helper split: anonymous_resend/1 is shared by probe/3 and the control test, so the control exercises the exact code path the parity row uses"
    - "Result dimension as a delivery oracle: confirmation_token_count/1 reads UserToken rows by sent_to, so a handler that acted on a payload email shows up even when the visible redirect is identical"

key-files:
  created:
    - test/example/test/example_web/live/confirmation_live_test.exs
  modified:
    - test/example/lib/example_web/router.ex
    - test/example/lib/example_web/live/confirmation_live.ex
    - test/fixtures/brand/public-surfaces.json
    - test/example/test/example_web/enumeration_parity_test.exs
    - .planning/decisions/006-name-clearance-search-log-and-claims-register.md
    - .planning/phases/259-compatibility-policy-pinned-source-and-copy-contract/deferred-items.md

key-decisions:
  - "Repaired the example host instead of waiving the surface: confirmation-resend went not_proven to parity, no owner override was written and the Contingency path was not needed."
  - "The identity the row proves is the email in the resend event payload, not an email-keyed resend form: the handler never reads params, no such form exists in the example or the generated page, and the registry note and register row say so (they keep the words payload and email-keyed resend form for Plan 259-16)."
  - "Anonymous behaviour in the example is flash-and-redirect to log in, a deliberate example-host choice that differs from the generated page's in-place sign-in-required render; the row claims the example host only."
  - "Kept the retained `_user = socket.assigns.current_scope.user` binding in handle_params, because installer_drift_test fix #9 pins it; the drift guard was not weakened."
  - "Task 2 is one commit covering probe, registry flip and register row, so name_clearance_test is green at every commit (Plan 259-14 left two commits red between its flip and its register edit)."

patterns-established:
  - "A registry flip and its claims-register restatement ship in one commit, because name_clearance_test cross-checks status against registry state."
  - "A zero-token count is only evidence once a control shows the same query goes above zero after a direct delivery."

requirements-completed: [BCOPY-03, BCOPY-07]

coverage:
  - id: D1
    description: "Example /users/confirm mounts for anonymous and signed-in visitors; an anonymous resend or code entry redirects to log in with an error flash and never raises"
    requirement: BCOPY-03
    verification:
      - kind: integration
        ref: "test/example/test/example_web/live/confirmation_live_test.exs (9 tests, 0 failures)"
        status: pass
    human_judgment: false
  - id: D2
    description: "A signed-in unconfirmed visitor can resend and confirm with the emailed code, proven on the confirmed_at column; a confirmed visitor is redirected home; an anonymous visitor cannot confirm even with the real code"
    requirement: BCOPY-03
    verification:
      - kind: integration
        ref: "test/example/test/example_web/live/confirmation_live_test.exs#the correct emailed code confirms the account"
        status: pass
      - kind: integration
        ref: "test/example/test/example_web/live/confirmation_live_test.exs#submitting a code redirects to log in and confirms no account, even the right code"
        status: pass
    human_judgment: false
  - id: D3
    description: "confirmation-resend is a parity row proven :same on status, redirect, flash, body and confirmation tokens created, with the real flash and a non-empty body on both sides"
    requirement: BCOPY-03
    verification:
      - kind: integration
        ref: "test/example/test/example_web/enumeration_parity_test.exs#every parity row compares :same for an existing versus an unknown identity"
        status: pass
      - kind: integration
        ref: "test/example/test/example_web/enumeration_parity_test.exs#no parity row passes as empty-versus-empty: each probe captures the surface's real response"
        status: pass
      - kind: integration
        ref: "test/example/test/example_web/enumeration_parity_test.exs#confirmation-resend probe is real (2 tests, includes the token-count control 0 to 2)"
        status: pass
    human_judgment: false
  - id: D4
    description: "Positive control still goes red exactly once across five parity rows"
    requirement: BCOPY-03
    verification:
      - kind: integration
        ref: "test/example/test/example_web/enumeration_parity_test.exs#every parity surface can go red: leaking any one yields exactly that one diff"
        status: pass
    human_judgment: false
  - id: D5
    description: "ADR 006 claims-register row for confirmation-resend reads bounded and agrees with the registry state"
    requirement: BCOPY-07
    verification:
      - kind: unit
        ref: "mix test test/sigra/brand test/sigra/templates/installer_drift_test.exs (355 tests, includes name_clearance_test and claims_docs_test)"
        status: pass
    human_judgment: false

duration: ~6min (start epoch captured at executor start)
completed: 2026-11-15
status: complete
---

# Phase 259 Plan 15: Confirm page repair and confirmation-resend parity Summary

**Example-host confirm page made reachable in both session states (`live_session :confirmation` on `:mount_current_scope` plus a nil-safe `session_user/1`), and `confirmation-resend` flipped from not_proven to a non-vacuous parity row whose probe asserts identical redirect, flash, body and zero tokens for a payload email that is an existing account versus an unknown address.**

## Performance

- **Duration:** ~6 min
- **Started:** 2026-11-15T13:52:09Z
- **Completed:** 2026-11-15
- **Tasks:** 2 (both `auto`; Task 1 `tdd="true"`)
- **Files modified:** 7 (1 created, 6 modified, including `deferred-items.md`)

## Accomplishments

- The example confirm page no longer sits in the `redirect_if_user_is_authenticated` scope. `router.ex` serves `live "/confirm"` from `live_session :confirmation` (on_mount `:mount_current_scope`) inside the `scope "/users"` that pipes through `:browser` only, the same shape as `live_session :mfa_challenge`. A signed-in unconfirmed visitor is no longer bounced to `/app` before mount, and an anonymous visitor mounts with `current_scope` nil.
- `ExampleWeb.ConfirmationLive` reads the session user through a private `session_user/1` that pattern-matches `socket.assigns[:current_scope]`. With no session, resend flashes `Log in to request a new confirmation email.` and redirects to `/users/log_in`; code entry flashes `Log in to confirm your email with a code.` and redirects the same way. The resend handler still ignores its event payload.
- `ExampleWeb.ConfirmationLiveTest` (9 tests) covers both session states and ends every state-changing test on database state: `confirmed_at` (the todo's required assertion) and the `confirm` / `confirm_code` token rows. An anonymous visitor submitting the REAL emailed code confirms nothing (T-259-49).
- `confirmation-resend` is a parity row (compare `status`, `redirect`, `flash`, `body`, `result`; blocker null). The probe sends `render_click(view, "resend", %{"email" => email})` from an anonymous mount for an existing unconfirmed account versus an unknown address and adds the confirmation-token count for that address to the response, so a handler that acted on the payload would differ on `result` even if the redirect looked identical.
- The probe is non-vacuous. The existing non-vacuity test asserts the real error flash and a non-empty followed login page on both sides, and a control shows `confirmation_token_count/1` goes from 0 to 2 after a direct `deliver_user_confirmation_instructions/2` call for the same kind of account.
- The positive control still goes red exactly once, now across five parity rows (password-signin, magic-link-request, password-reset-request, confirmation-resend, mfa-challenge).
- The ADR 006 register row reads `bounded` with the narrowed claim "An anonymous confirmation resend ignores a visitor-supplied email", example host only, in the same commit as the registry flip.

## Task Commits

1. **Task 1: Make /users/confirm reachable in both session states and cover it with a regression suite** - `9735db18a` (test)
2. **Task 2: Add the confirmation-resend parity probe, flip the registry row and restate the register row** - `26f1039b3` (test; the plan allowed `test` and `docs` types, one commit was used so the register and registry never disagree at any commit)

**Plan metadata:** the SUMMARY commit that follows this file, then a STATE/ROADMAP commit.

## TDD Evidence

**Task 1 RED, observed before the repair.** The new suite was written first and run against the unrepaired router and view: 9 tests, 8 failures, every failure on the planned defect and not on a syntax or fixture fault: five signed-in tests died on `{:error, {:redirect, %{to: "/app", flash: %{}}}}` at the `live/2` mount (the second half of the defect), three anonymous tests died on `BadMapError ... nil` at `confirmation_live.ex:158` (the first half), and the routing test saw the route still in `live_session :redirect_if_user_is_authenticated`. Only the anonymous-mount test passed, as expected. This RED was not committed separately (the plan makes Task 1 one commit) and was not run through `gsd_run check tdd-red-evidence` (ExUnit output is not a supported report format and the plan is `type: execute`).

**Task 1 GREEN:** after the router and view repair, 9 tests, 0 failures; the controller route_info test, `user_auth_test` and `installer_drift_test` stayed green (22 and 24 tests).

**Mutation proofs (all reverted; files restored byte-identical from a backup and the diff against the commit was empty):**
- Re-adding the redirect-if-authenticated behaviour to the confirm session (`on_mount :redirect_if_user_is_authenticated`): 4 of 9 red by name, including `signed-in visitor an unconfirmed visitor mounts the page and a resend delivers a new confirmation` (Test 5), plus the confirmed-visitor, correct-code and wrong-code tests. Anonymous tests stayed green.
- Restoring the unguarded `socket.assigns.current_scope.user` read in resend/code entry: 3 of 9 red by name with `BadMapError`, including `anonymous visitor resend redirects to log in with an error flash and creates no confirmation token` (Test 3). Signed-in tests stayed green.
- Making resend act on `params["email"]` (a clause that looks the user up and delivers, then shows the same flash and redirect): `every parity row compares :same` failed with `confirmation-resend: [{:result, %{confirmation_tokens: 2}, %{confirmation_tokens: 0}}]` (only the `result` dimension, flash and body stayed identical), both positive-control tests failed on that row, and `an anonymous resend carrying an unconfirmed account's email creates no token` failed with 2 versus 0.

### TDD Gate Compliance

Task 1 is `tdd="true"` but is one commit (suite plus repair together), so there is no separate `test(259-15)` RED commit followed by a `feat(259-15)` commit, and the plan has no `feat(259-15)` commit at all. The RED is the observed failing run above, taken before the repair. The plan is `type: execute`, so no plan-level gate sequence is mandated. Flagged here rather than hidden.

## Files Created/Modified

- `test/example/lib/example_web/router.ex` - `live_session :confirmation` serving `live "/confirm", ConfirmationLive`; the line is gone from `live_session :redirect_if_user_is_authenticated`; `get "/confirm/:token"` untouched
- `test/example/lib/example_web/live/confirmation_live.ex` - `session_user/1`, `resend_confirmation/2`, `confirm_with_code/3`; anonymous branches flash and redirect
- `test/example/test/example_web/live/confirmation_live_test.exs` - new `ExampleWeb.ConfirmationLiveTest` (9 tests)
- `test/fixtures/brand/public-surfaces.json` - `confirmation-resend` row: state parity, compare adds `result`, blocker null, new bounded note
- `test/example/test/example_web/enumeration_parity_test.exs` - probe clause, `anonymous_resend/1`, `confirmation_token_count/1`, expected-flash clause, `confirmation-resend probe is real` describe (2 tests)
- `.planning/decisions/006-name-clearance-search-log-and-claims-register.md` - Claim, Evidence and Status cells of one row
- `.planning/phases/259-compatibility-policy-pinned-source-and-copy-contract/deferred-items.md` - Plan 259-15 section (item 2 under 259-07 resolved for the example host; one new finding)

## Decisions Made

- Repair rather than waive: the surface is proven, not re-described, because a plan cannot shrink a roadmap success criterion. No override was written and `accepted_by` was not touched.
- The identity this row proves is stated plainly: a visitor-supplied payload email is ignored. The note and the register row both say an email-keyed resend form does not exist and nothing covers one, so the row is not read as an account-existence probe like sign-in, magic-link and password-reset request. Plan 259-16 keys its id class on the words `payload` and `email-keyed resend form`, both kept in the note.
- The row claims the example host only. The generated host's LiveView confirm flow was repaired in Phase 246 (installer emits `live_session :sigra_confirmation` on `:mount_current_scope`; the template's `with_confirmation_user/2` renders `:sign_in_required` in place for an anonymous visitor). That behaviour differs from this example's flash-and-redirect, and nothing here edits `lib/` or `priv/`. Plan 259-17 re-reads the generated sources.
- The drift guard was left alone: `test/sigra/templates/installer_drift_test.exs` entry "fix #9" requires `_user = socket.assigns.current_scope.user` to stay in the example, so the `handle_params(%{"token" => token}, ...)` clause is unchanged.

## Deviations from Plan

None - plan executed exactly as written.

The only choice the plan left open was commit grouping for Task 2 ("Commit types test(259-15) and docs(259-15)"). Registry flip, probe and register row went into one `test(259-15)` commit because `name_clearance_test` cross-checks the register status against the registry state and `expected_parity_flash` is cross-checked against the parity rows, so any split leaves a commit red (the hazard Plan 259-14's summary recorded). Both commits of this plan are green on their own: Task 1 does not touch the registry or the register.

**Total deviations:** 0 auto-fixed.

## Issues Encountered

- **Pre-existing quirk, not fixed (verified by running it).** An anonymous visitor on `/users/confirm?token=...` still crashes the example confirm LiveView with `BadMapError` at the retained `_user = socket.assigns.current_scope.user` binding (`confirmation_live.ex:104`). It is not new: before this plan an anonymous visitor reached the same `handle_params` clause through the old redirect session. It is retained because `installer_drift_test` fix #9 pins that binding, and it is off the normal flow (the example serves emailed links through `ExampleWeb.ConfirmationController` at `/users/confirm/:token`). Logged in `deferred-items.md`; removing it needs a change to the drift test, outside this phase's file set.
- `mix format` was run only on the touched files from the repo root, per the plan (never inside `test/example`); `mix format --check-formatted` at the root passes.

## Verification Results

| Check | Result |
|-------|--------|
| Task 1 verify: confirmation_live_test + confirmation_controller_test + user_auth_test (`--include example_app`) | 22 tests, 0 failures |
| `mix test test/sigra/templates/installer_drift_test.exs` | 24 tests, 0 failures |
| Parity suite + confirmation suite (`--include example_app`) | 37 tests, 0 failures |
| `mix test test/sigra/brand/name_clearance_test.exs test/sigra/brand/claims_docs_test.exs` | 62 tests, 0 failures |
| Whole example suite (`--include example_app`) | 386 tests, 0 failures (384 after Task 1: 375 + 9) |
| `mix test test/sigra/brand test/sigra/templates/installer_drift_test.exs` | 355 tests, 0 failures |
| Zero shipped bytes vs `62ef40442` (lib, priv, brandbook, brand, .github, scripts) | pass; control: tracked shipped paths exist and a non-empty diff makes `test -z` fail |
| Privacy gate (no `/Users/...` or `/home/...` in the diff outside the phase dir) | pass; control: planted path matched |
| `mix format --check-formatted` (repo root) | pass |
| Acceptance greps | `live_session :confirmation` = 1; `assigns.current_scope.user` = 1 line (the retained binding; HEAD had 3); `test "` = 9; `confirmed_at` refs = 9; parity rows = 5 (HEAD 4, control); `probe("confirmation-resend"` = 1; register `not proven` = 0 (HEAD 1, control), `bounded` = 1; remaining not_proven rows = magic-link-rate-limit, password-reset-rate-limit, lib-moduledoc-claims |

## Known Stubs

None.

## Threat Flags

None. Moving `/users/confirm` into a `:mount_current_scope` session does not add a reachable surface (an anonymous visitor already reached the page), and the code-entry path stays scoped by the session user (T-259-49, asserted by the anonymous real-code test). No `lib/` or `priv/` byte changed.

## Handoff to later plans

- **259-16:** the `confirmation-resend` note keeps the words `payload` and `email-keyed resend form`; its row is the payload-ignored class, not an account-existence probe.
- **259-17 (generated-host todo):** the todo `2026-09-15-generated-confirm-routes-unreachable-both-session-states.md` is still linked from the row and still describes the generated defect as open. Re-read the generated sources (Phase 246 already moved the LiveView flavor onto `:mount_current_scope`; the non-live controller flavor reads `conn.assigns.current_scope.user` directly, read in source and not executed) and update the todo to what remains. This plan did not edit it.
- **259-18:** the "Where it appears" cell for this register row ("No published page") was left unchanged.
- **Requirements:** `BCOPY-03` and `BCOPY-07` are still declared by sibling plans 16-18 with no SUMMARY, so `requirements.ready-ids` is expected to report them blocked; they are not marked complete here.

## Self-Check: PASSED

All created and modified files exist (including `deferred-items.md`); commits `9735db18a` and `26f1039b3` are ancestors of HEAD (a planted bogus hash is reported MISSING).

---
*Phase: 259-compatibility-policy-pinned-source-and-copy-contract*
*Completed: 2026-11-15*
