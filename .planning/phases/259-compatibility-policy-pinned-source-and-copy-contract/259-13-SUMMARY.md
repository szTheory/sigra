---
phase: 259-compatibility-policy-pinned-source-and-copy-contract
plan: 13
subsystem: testing
tags: [exunit, enumeration, parity, todos, fix-tracking, shrink-discipline]

requires:
  - phase: 259-07
    provides: the public-surfaces registry whose todo fields fix the three paths this plan creates, and the parity test module this plan extends
provides:
  - three fix-tracking todos under .planning/todos/pending/ for the passkey options existence oracle, the lockout and rate-limit channels, and the deferred library moduledoc over-claims
  - one existence assertion in the parity test (every non-null registry todo path is a regular file; the three new todos are referenced) with a planted-control test for its pure helper
affects: [259-10, 259-11]

actuals:
  tokens: 5050
  tasks: 1
  commits: 1
commits: 1
plan_head_before: 4fd19fb8425829e9d64eaea558d0554e1582afde
plan_head_after: d3ca59e73d3ab43dd1d8ec2737526d8c1ef89c59

tech-stack:
  added: []
  patterns:
    - "Registry-to-todo integrity: a registry row cannot carry a dangling todo path, so a known divergence is always tracked to a filed fix"
    - "Pure helper with a planted control: missing_files/1 is shown to report a fake path, a directory and an absolute path before it is trusted"

key-files:
  created:
    - .planning/todos/pending/2026-11-13-passkey-options-email-existence-oracle.md
    - .planning/todos/pending/2026-11-13-lockout-and-rate-limit-enumeration-channels.md
    - .planning/todos/pending/2026-11-13-lib-moduledoc-enumeration-overclaims.md
  modified:
    - test/example/test/example_web/enumeration_parity_test.exs
    - .planning/phases/259-compatibility-policy-pinned-source-and-copy-contract/deferred-items.md

key-decisions:
  - "missing_files/1 treats an absolute path or a directory as missing (a todo path is repo-relative and must be a regular file) and de-duplicates its input, so three rows sharing one lockout todo report it once"
  - "The three new todo paths are named in the test module independently of @expected_todos, so a registry edit that drops a reference to one of them goes red even if the expected-path map is edited to match"
  - "The passkey todo records that the existing-email answer also carries allowCredentials built from the account's stored passkeys (template session_controller.ex:370 and :385-391), read in source and not compared by the harness"
  - "The lockout and rate-limit todo records that the generated reset controller and LiveView call the context only for an existing account, so for an unknown email neither the limiter nor the library dummy hash runs (read in source; timing is not compared)"

patterns-established:
  - "Todo text states what was compared and what was only read in source, and never claims a surface is safe; every file:line citation was re-read before it was written"

requirements-completed: [BCOPY-03, BCOPY-07]

coverage:
  - id: D1
    description: "Three fix-tracking todos exist at the exact paths the registry carries, in the existing 2026-11-13 frontmatter shape, with file:line evidence, the registry row ids, and shrink-discipline instructions"
    requirement: BCOPY-07
    verification:
      - kind: command
        ref: "ls .planning/todos/pending lists exactly the three 2026-11-13 files (count 3, control: duplicate-registration-timing-oracle count 1)"
        status: pass
    human_judgment: false
  - id: D2
    description: "The parity test asserts every non-null registry todo path is a regular file and that each of the three new todos is referenced by at least one row"
    requirement: BCOPY-03
    verification:
      - kind: integration
        ref: "cd test/example && MIX_ENV=test mix test --include example_app test/example_web/enumeration_parity_test.exs#registry (every non-null registry todo path is a real file)"
        status: pass
    human_judgment: false
  - id: D3
    description: "The existence helper is shown to report a planted fake path, a directory and an absolute path (planted control), and the new assertion was red while the files were absent"
    requirement: BCOPY-03
    verification:
      - kind: integration
        ref: "cd test/example && MIX_ENV=test mix test --include example_app test/example_web/enumeration_parity_test.exs#registry (the todo-path helper reports a planted fake path)"
        status: pass
    human_judgment: false
  - id: D4
    description: "Todo wording stays bounded to the compared dimensions and carries no safety claim, personal name, email or path"
    requirement: BCOPY-07
    verification:
      - kind: command
        ref: "grep -i -E 'enumeration-safe|enumeration safe' on the passkey and lockout todos prints nothing; privacy scan of the four files finds no home path or personal name"
        status: pass
    human_judgment: true
    rationale: "Whether each sentence stays inside the claim the harness supports is a reading judgment; the grep proves only the absence of the banned phrases"

duration: 5min
completed: 2026-11-14
status: complete
---

# Phase 259 Plan 13: Enumeration fix-tracking todos Summary

**Three fix-tracking todos (passkey options existence oracle, lockout and rate-limit channels, deferred lib moduledoc over-claims) plus a parity-test assertion that keeps every registry todo path a real file, with a planted control proving the helper can report a missing one.**

## Performance

- **Duration:** 5 min
- **Started:** 2026-11-14T16:56:17Z
- **Completed:** 2026-11-14T17:01:23Z
- **Tasks:** 1 (tracer)
- **Files:** 3 created, 1 modified, plus one entry appended to the phase `deferred-items.md`; zero bytes under lib/, priv/, brandbook/, brand/, .github/ or scripts/

## Accomplishments

- Tracer: wrote the todo-path assertion first and ran it red (it named the three absent files), then created the three todos and re-ran it green. Tracer gate: `gate` is not `blocking-human`, `human_verify_mode` is `end-of-phase` and the `<verify>` is automated-only, so the verify was re-run rather than checkpointed; logged "Tracer verified end-to-end - expanding" (it is the plan's only task, so nothing expanded).
- `passkey-options-email-existence-oracle`: cites the generated template (`session_controller.ex:141-153`), the example host (`:171-190`), the committed golden fixture (`:146`) and the route line, states that the harness compares status and top-level JSON keys only, and says that a green parity claim needs a later `priv/templates` fix plus a golden rebless.
- `lockout-and-rate-limit-enumeration-channels`: covers rows `password-signin-repeat-attempts` (asserted), `magic-link-rate-limit` and `password-reset-rate-limit` (not proven), with the limiter's existing-only branches cited and the harness limits stated.
- `lib-moduledoc-enumeration-overclaims`: a table of the eight over-claim locations (quoted, each with what the harness proves instead), marked deferred because the edits need `lib/` bytes.
- Parity test: 22 tests, 0 failures (20 before, plus the assertion and its control).

## Task Commits

1. **Task 1: Todo-path assertion, then the three fix-tracking todos (tracer)** - `d3ca59e73` (test)

**Plan metadata:** the `docs(259-13)` close-out commits that carry this SUMMARY, STATE.md, ROADMAP.md and REQUIREMENTS.md.

## Deviations from Plan

### Auto-fixed Issues

None.

### Interpretation choices

1. **`missing_files/1` also rejects absolute paths and directories and de-duplicates.** The plan asks for an existence check with a planted fake path; the extra cases cost one line each and close two ways a dangling pointer could pass (a directory, or an absolute path that only exists on one machine). The control test covers each.
2. **The lockout todo cites the generated catch-all (`session_controller.ex:101-105`) rather than saying "every error".** In an organizations-enabled install the same controller has a separate `:sso_required` clause, so the unqualified phrase would over-claim. That clause is not a registry row and was not investigated.
3. **One entry appended to `deferred-items.md`** (the sanctioned place for out-of-scope discoveries): the generated reset controller and LiveView pass a user struct to `deliver_user_reset_password_instructions/2`, whose only head requires a binary email. Read in source, confirmed in the golden fixture, not executed.

**Total deviations:** 0 auto-fixed, 3 interpretation choices. **Impact:** all within the plan's files plus the phase's deferred-items log.

## Deferred Issues

See `deferred-items.md` (phase directory), section "From Plan 259-13": the struct-versus-binary mismatch in the generated reset-request path. Not recorded in `.planning/WINDOWS.md` (a scope limit of this phase; an open entry would block `/gsd-ship`). It looks like a real generated-host defect and deserves its own todo or quick task.

## Issues Encountered

None. The registry carried exactly the three strings this plan needed, so the assertion was red for the intended reason only (files absent) and no registry edit was needed.

## Authentication Gates

None.

## Known Stubs

None. No stub patterns, skipped tests or unrun verifies in the files created.

## Threat Flags

None. Planning text and one test assertion; no new network, auth or file-access surface. T-259-38 is mitigated: the todos use "bounded to the compared dimensions" wording and the assertion fails on any dangling registry todo path.

## Verification Results

- `cd test/example && MIX_ENV=test mix test --include example_app test/example_web/enumeration_parity_test.exs`: 22 tests, 0 failures (red with 1 failure before the todos existed, naming the three files).
- Verify block 1 (listing): count of the three 2026-11-13 files is 3; positive control `duplicate-registration-timing-oracle` count is 1.
- Acceptance criteria: passkey todo starts with a frontmatter delimiter and has `created:` (1); `public-surfaces.json` named in both the passkey and lockout todos; `lib/sigra/lockout.ex` appears 4 times in the moduledoc todo; no `enumeration-safe` phrase in the passkey or lockout todos.
- Plan verification item 2 (zero shipped bytes, git failure cannot read clean): PASS. Item 3 (privacy gate with planted-failure control): PASS; the four files also scanned for personal names and emails, none found (only the `example.com` fixture addresses from Plan 07). Item 4: `mix format --check-formatted` clean at the root and in `test/example`.

## Next Phase Readiness

Plan 259-10 (depends on 13) and Plan 259-11 (depends on 07, 10, 12, 13) can cite the three todos by path. Plan 259-11's claims register still has to reference every non-parity row id listed in the Plan 259-07 SUMMARY. `STATE.md` `Current Plan` is a completed-count and reads 11 after this plan even though plan 259-10 (wave 3) is the next to run, because this plan was ordered by wave before 10-12; the disk-derived plan list is authoritative.

## Self-Check: PASSED

Created files exist on disk; commit `d3ca59e73` is an ancestor of HEAD and is the only commit in the plan range (`rev-list --count` = 1); every acceptance criterion and the plan-level verification commands were re-run green after the last code commit; no stub patterns found.
