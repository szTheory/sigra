---
phase: 259-compatibility-policy-pinned-source-and-copy-contract
plan: 17
subsystem: testing
tags: [generated-host, todo, enumeration-parity, registry, gap-closure, zero-shipped-bytes]

requires:
  - phase: 259-compatibility-policy-pinned-source-and-copy-contract
    provides: example-host repairs of the reset request page (Plan 259-14) and the confirm page (Plan 259-15), the named-surface rule (Plan 259-16), and the registry row password-reset-request flipped to parity
provides:
  - one new todo recording the generated host's reset request defects (live route without :new, user struct passed to a binary-only head), every generated-host claim labelled read in source, not executed
  - the generated-confirm todo narrowed to what remains after Phase 246 (non-live controller flavor), with the example-host-only status of the confirmation-resend row recorded
  - registry row password-reset-request wired to the new todo, with the parity test fixing the path and requiring the reference
affects: [259-18, BCOPY-03, BCOPY-07]

actuals:
  tokens: 4469
  tasks: 3
  commits: 4

plan_head_before: 7129199ec0109ec406d3286932cf7758ad5c4883
plan_head_after: c2b5915d5c77284d74943be82aaf34162acbc4da
commits: 4

tech-stack:
  added: []
  patterns:
    - "A repaired example host is test code; the generated-host equivalent is filed as a todo, labelled executed (example) versus read in source, not executed (generated), and wired into the registry row so a green row cannot be read as proof about an adopter app"
    - "Append-only status update on a historical todo: original text and front matter untouched, the update says which sections are now historical"

key-files:
  created:
    - .planning/todos/pending/2026-11-14-generated-reset-request-page-mount-and-user-struct-call.md
  modified:
    - .planning/todos/pending/2026-09-15-generated-confirm-routes-unreachable-both-session-states.md
    - test/fixtures/brand/public-surfaces.json
    - test/example/test/example_web/enumeration_parity_test.exs

key-decisions:
  - "Task 2 took the PRIMARY outcome: a residual remains in the non-live controller flavor, so the confirm todo was extended with a dated status update and left pending, not resolved. The registry row confirmation-resend keeps its todo path."
  - "The status update is dated 2026-11-15, the day it was written, not the plan's 2026-11-14 filing date."
  - "No pointer was added to deferred-items.md: it is outside this plan's file list. The new todo now covers deferred items 259-07 item 1, 259-13 item 1 and 259-10 item 2 for the generated host."

patterns-established:
  - "Every path:line citation in a todo is repo-relative and machine-checked to resolve to an existing file and line, with a planted bad citation proven to fail the check"

requirements-completed: [BCOPY-03, BCOPY-07]

coverage:
  - id: D1
    description: "A new todo records the generated host's reset request defects (core.ex emits the live route without :new while the generated view case-matches on live_action; both generated callers pass a user struct to the single binary-only head at auth.ex:428), each generated-host claim labelled read in source, not executed, with a suggested fix, the reason it was not fixed in Phase 259 and the shrink condition"
    requirement: BCOPY-07
    verification:
      - kind: other
        ref: "acceptance greps on the todo file (is_binary, core.ex, auth.ex, 'read in source' on 2 lines, password-reset-request, no home path with a planted-path control) and a duplicate check over .planning/todos/pending and .planning/seeds with a positive control (7 files in the phase directory match the same pattern)"
        status: pass
    human_judgment: true
    rationale: "The generated-host statements are source readings, not executions, and no test asserts them. All 15 path:line citations were machine-checked to resolve, but whether the readings are right is for the verifier to re-read or for a --live install run to settle."
  - id: D2
    description: "The existing generated-confirm todo carries an appended dated status update saying the LiveView flavor was repaired in Phase 246 (commits 6be7eff6b, 590eb4ed3; live_session :sigra_confirmation on :mount_current_scope; with_confirmation_user/2 and :sign_in_required; install-smoke probe asserting confirmed_at), narrowing what remains to the non-live controller flavor (read in source, not executed), and recording the confirmation-resend row as example-host evidence only"
    requirement: BCOPY-03
    verification:
      - kind: other
        ref: "grep 'Status update (Phase 259 gap closure)' = 1, 'sigra_confirmation' = 2, 'example-host evidence only' = 2; git diff against the pre-task base shows 0 removed lines (control: a deliberately edited copy shows 1); one confirm todo tracked; no home path"
        status: pass
    human_judgment: true
    rationale: "Same as D1: the residual in the non-live flavor is read in source, not executed, and there is no generated-host probe for that flavor."
  - id: D3
    description: "The password-reset-request registry row carries the new todo path, and the parity test fixes the path in @expected_todos and requires it in @new_todo_paths, so a registry edit that drops the reference or points it at a missing file goes red"
    requirement: BCOPY-03
    verification:
      - kind: integration
        ref: "test/example/test/example_web/enumeration_parity_test.exs#rows carry exactly the fixed todo paths, every other row carries null"
        status: pass
      - kind: integration
        ref: "test/example/test/example_web/enumeration_parity_test.exs#every non-null registry todo path is a real file, and the four new todos are referenced"
        status: pass
      - kind: integration
        ref: "mix test test/sigra/brand (331 tests, 0 failures, includes name_clearance_test)"
        status: pass
    human_judgment: false

duration: ~8min (start approximated from the commit-ledger timestamp; the start epoch was not captured at executor start)
completed: 2026-11-15
status: complete
---

# Phase 259 Plan 17: Generated-host reset and confirm todos, wired to the registry Summary

**The generated reset request page's two defects (a live route emitted without `:new`, and a user struct passed to a binary-only function head) are filed once with file:line evidence labelled read in source, the generated-confirm todo is narrowed to the non-live controller flavor that Phase 246 left open, and the `password-reset-request` row now references the new todo with the parity test requiring that reference to stay real.**

## Performance

- **Duration:** ~8 min
- **Started:** ~2026-11-15T14:03Z (approximate)
- **Completed:** 2026-11-15T14:11Z
- **Tasks:** 3 (all `auto`; Task 3 `tdd="true"`)
- **Files modified:** 4 (1 created, 3 modified)
- **Shipped bytes changed:** 0 (nothing under `lib/`, `priv/`, `brandbook/`, `brand/`, `.github/`, `scripts/`)

## Accomplishments

- **New todo, no duplicate.** `.planning/todos/pending/2026-11-14-generated-reset-request-page-mount-and-user-struct-call.md`. Before writing it, `.planning/todos/pending` and `.planning/seeds` were searched for `reset-password`, `ResetPasswordLive`, `reset_password_live` and `deliver_user_reset_password_instructions`. Two files matched and neither covers either defect: the lockout and rate-limit todo cites the same callers only as timing evidence, and SEED-010 lists the template for class unbranding. The todo says so in its body.
- **Defect 1, read in source, not executed.** `lib/sigra/install/features/core.ex:410-411` emits `live "/reset-password", ResetPasswordLive` with no live action; the committed golden router shows the same (`router.ex:119-120`); the generated view renders `:new` (`reset_password_live.ex:15`) and `:edit` (`:49`) and case-matches on `socket.assigns.live_action` in `mount/3` (`:132`). A route with no action leaves `live_action` nil. The example host reproduced exactly this (executed, five `CaseClauseError` failures before Plan 259-14).
- **Defect 2, read in source, not executed.** `priv/templates/sigra.install/core/auth.ex:428-429` has one head, `when is_binary(email)`; the golden accounts file shows the same. Both generated callers (`reset_password_controller.ex:23-29`, `reset_password_live.ex:154-160`) pass the user struct. Executed for the example host (Plan 259-14 mutation proof: `FunctionClauseError`).
- **Two more places that still carry the struct call**, recorded in the todo: the example host's unrouted `ResetPasswordController` copy (`test/example/lib/example_web/controllers/reset_password_controller.ex:24-28`) and the published guide, in both the request-handler snippet (`guides/flows/password-reset.md:20-25`) and the testing snippet (`:140`). The deferred-items file recorded only the first of the two guide spots.
- **Confirm todo re-checked against the generated sources, not its own text.** Phase 246 did repair the LiveView flavor: `core.ex:387-402` emits `live_session :sigra_confirmation` on `:mount_current_scope` and the live flavor's `redirect_scope_confirmation_routes` is empty (`:404`); the golden router shows it (`router.ex:98-102`) and `generator_wiring_test.exs:185` asserts it; the template's `with_confirmation_user/2` (`confirmation_live.ex:270-277`) reads `socket.assigns[:current_scope]` safely and renders `:sign_in_required` in place for an anonymous visitor. A generated-host probe now exists for it (`scripts/ci/generated-confirmation-probe.exs`, run by `scripts/ci/install-smoke.sh:240-247`) and asserts on `confirmed_at` in an anonymous session, in a signed-in visitor session and for anonymous code and resend events. That is the "Required test" the old todo asked for, so the old Problem, Solution and Required test sections are now historical for this flavor.
- **What remains in the confirm todo: the non-live controller flavor, read in source, not executed.** `core.ex:404` still puts the four controller routes inside the `redirect_if_user_is_authenticated` scope (`core.ex:522`, `:529`), which redirects a signed-in visitor before any action runs (`user_auth.ex:385-392`); `create/2` and `resend/2` read `conn.assigns.current_scope.user` (`confirmation_controller.ex:25-26`, `:94-95`), and `fetch_current_scope` assigns nil for an anonymous visitor (`user_auth.ex:164-170`, `:191`). No generated-host probe covers that flavor.
- **Registry wiring.** The row's `todo` field and note now point at the new todo; `@expected_todos` and `@new_todo_paths` name it, and the test name and comment say four.

## Task Commits

1. **Task 1: File the generated reset request page todo** - `958a03834` (docs)
2. **Task 2: Update the generated confirm todo to what remains** - `d82879faf` (docs)
3. **Task 3: Wire the new todo to the password-reset-request row** - `fb64a53c5` (test)
4. **Citation clean-up (in-scope fix to Tasks 1 and 2, see Deviations)** - `c2b5915d5` (docs)

**Plan metadata:** the SUMMARY commit that follows this file, then a STATE/ROADMAP commit.

## Task 2 outcome

**Primary outcome taken** (a residual remains), not the alternative. The file stays under `.planning/todos/pending/` with status pending and the fast-follow disposition unchanged; the registry row `confirmation-resend` keeps the path, and `@expected_todos` still lists it. Evidence for the residual is the file:line list under "What remains" above; evidence that the LiveView half is closed is the Phase 246 list. The change is additions only: `git diff` against the pre-task base shows 0 removed lines, and the control (a deliberately edited copy) shows 1.

## TDD Evidence

**Task 3 RED, observed before the registry edit.** The expectation was added first: `password-reset-request` in `@expected_todos` and the new path in `@new_todo_paths`, with the registry untouched. Run (`MIX_ENV=test mix test --include example_app test/example_web/enumeration_parity_test.exs`): 33 tests, 2 failures, and both were the planned assertions: `rows carry exactly the fixed todo paths, every other row carries null` (`row password-reset-request todo is nil, expected ".planning/todos/pending/2026-11-14-generated-reset-request-page-mount-and-user-struct-call.md"`) and `every non-null registry todo path is a real file, and the four new todos are referenced` (`no registry row references the todo ...`). The other 31 tests passed, so this was not a load or compile fault, and the count was 33, not zero. Semantic assessment: both targets executed and failed on the intended assertion for the intended reason. This RED was not run through `gsd_run check tdd-red-evidence` (ExUnit output is not a supported report format, and the plan is `type: execute`).

**Task 3 GREEN:** after setting the registry `todo` field and appending the note sentence, 33 tests, 0 failures.

**Mutation proof (restored from a backup copy; the restored file has exactly one occurrence of the real filename and none of the planted one):** pointing the registry todo at `.planning/todos/pending/2026-11-14-this-todo-was-never-filed.md` turned two tests red by name, `every non-null registry todo path is a real file ...` (`registry todo paths that are not files under the repo root: [...never-filed.md]`) and `rows carry exactly the fixed todo paths ...`. The dropped-reference direction is the RED run itself (todo null, both tests red).

### TDD Gate Compliance

Task 3 is `tdd="true"` but is one `test(259-17)` commit (test and fixture together), as the plan specifies, so there is no separate GREEN `feat` commit. The RED is the observed failing run above. The plan is `type: execute`, so no plan-level gate sequence is mandated. Flagged here rather than hidden.

## Files Created/Modified

- `.planning/todos/pending/2026-11-14-generated-reset-request-page-mount-and-user-struct-call.md` - new todo (front matter in the sibling 2026-11-13 shape; sections: duplicate check, registry row, defect 1, defect 2, other places, suggested fix, why not fixed, shrink discipline)
- `.planning/todos/pending/2026-09-15-generated-confirm-routes-unreachable-both-session-states.md` - appended "Status update (Phase 259 gap closure) - 2026-11-15" (three subsections); original text and front matter untouched
- `test/fixtures/brand/public-surfaces.json` - `password-reset-request` row: `todo` set, one sentence appended to the note (2 insertions, 2 deletions, nothing else)
- `test/example/test/example_web/enumeration_parity_test.exs` - one `@expected_todos` entry, one `@new_todo_paths` entry, updated comments and test name (three to four)

## Decisions Made

- Primary outcome for the confirm todo, because the non-live controller flavor still has the redirect-scope placement and the two direct `current_scope.user` reads (read in source). It is not closed on the strength of the LiveView repair alone.
- The suggested fix for the reset defects keeps `generator_wiring_test.exs:190` in view: it asserts `live "/reset-password", ResetPasswordLive` as a substring, so adding `, :new` keeps it green. Recorded in the todo so the later fixer does not trip on it.
- No `.planning/WINDOWS.md` entry was opened for either defect: an open entry blocks `/gsd-ship`, and these are a scope limit of this zero-shipped-bytes phase (the plan says so explicitly).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing critical functionality] Shorthand citations were not checkable**
- **Found during:** SUMMARY preparation, running a citation check over both todos
- **Issue:** A script that resolves every `path:line` citation in a todo found 7 shorthand citations (`core.ex:416-419`, `core.ex:380-383`, `core.ex:404`, `core.ex:522`, `user_auth.ex:164-170` and two `.../controllers/...` and `.../live/...` golden paths) that name no repo-relative file, so a later fixer could not resolve them. The plan's own purpose is evidence a fixer can follow.
- **Fix:** expanded each to its full repo-relative path. Both todos then check clean (15 and 16 citations, 0 bad), and a planted bad citation (line 99999 in `core.ex`, a missing file) fails the same check. The confirm todo stays additions-only against its original text (0 removed lines).
- **Files modified:** both todos
- **Commit:** `c2b5915d5`

**Total deviations:** 1 auto-fixed (1 missing-critical). **Impact:** none on scope; two todo files, no shipped byte. The check script lives in the session scratchpad and was not committed (the plan adds no tool).

## Issues Encountered

- The line numbers the plan gave for the parity test (`~86-101`, `~106-110`, `~208-236`) had moved after Plan 259-16 (they are now `126-141`, `146-150`, `330-342`). The edits were located by content, not by number.
- The plan's cited line for the generated `handle_event` was `~155-160`; the actual span is `154-160` (the function head is `:154`, the call `:156-159`). The todo uses the measured lines.
- Negative checks use `test -z "$(...)"`, not `wc -l | grep -qx 0`, and each was shown able to fail (planted home path matched; control diff showed a removal; planted bad citation failed; bogus commit hash `deadbeef0` reported MISSING).

## Verification Results

| Check | Result |
|-------|--------|
| Parity suite, RED (expectation first, registry unchanged) | 33 tests, 2 failures, both on the planned todo assertions |
| Parity suite after the registry edit and after the mutation restore | 33 tests, 0 failures each |
| Mutation: registry todo pointed at a missing file | 2 failures by name, restored byte-identical to the backup |
| `mix test test/sigra/brand` | 331 tests, 0 failures |
| Zero shipped bytes vs `62ef40442` (lib, priv, brandbook, brand, .github, scripts) | pass; control: a diff over an older commit that touched `lib/` is non-empty |
| Privacy gate over the diff outside the phase dir | pass; control: planted `/Users/someone/y` matched |
| `mix format --check-formatted` (repo root) | pass |
| Task 1 acceptance | is_binary 1, core.ex 4, auth.ex 2, 'read in source' on 2 lines, password-reset-request 2; duplicate grep lists no todo recording the mount crash (control: 7 phase-dir files match the pattern) |
| Task 2 acceptance | status-update heading 1, sigra_confirmation 2, example-host evidence only 2, removed lines 0, one confirm todo tracked |
| Task 3 acceptance | registry 1, parity test 2, JSON valid, new todo tracked (`git ls-files --error-unmatch`), registry diff is the todo field and note only |
| Citation check (both todos) | 15 and 16 citations, 0 unresolved; planted bad citation fails |

## Known Stubs

None. No placeholder, hardcoded empty value or unwired data source in any file touched.

## Threat Flags

None. No `lib/` or `priv/` byte changed; the plan edits two planning todos, one test fixture and one test file. The threat register (T-259-54, T-259-55, T-259-56) is mitigated: the defects are filed and referenced from the registry with the parity test asserting it, every generated-host claim is labelled read in source, and the privacy gate passed with a planted-failure control.

## Handoff to later plans

- **259-18:** BCOPY-03 is also declared by that sibling, so `requirements.ready-ids` decides whether it can be marked complete here.
- `deferred-items.md` still lists 259-07 item 1, 259-13 item 1 and 259-10 item 2 as open; the new todo now tracks the generated-host half of each. It was not edited (outside this plan's file list), so a later plan may add a pointer.
- A fix for the generated reset page needs a `lib/` and `priv/` change, a golden rebless under phx_new 1.8.8, the guide snippets and a runtime check; the non-live confirm flavor needs its own generated-host check. Both are in the todos with the shrink condition.

## Self-Check: PASSED

All four modified or created files exist; commits `958a03834`, `d82879faf`, `fb64a53c5` and `c2b5915d5` are ancestors of HEAD (a planted bogus hash `deadbeef0` is reported MISSING). The evaluation-scope resolver returns the plan's commits on this branch.

---
*Phase: 259-compatibility-policy-pinned-source-and-copy-contract*
*Completed: 2026-11-15*
