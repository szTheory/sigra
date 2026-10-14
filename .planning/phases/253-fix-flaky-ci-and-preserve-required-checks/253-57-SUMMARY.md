---
phase: 253-fix-flaky-ci-and-preserve-required-checks
plan: "57"
subsystem: auth
tags: [security, enumeration, sigra-auth, generator-output, load-recovery, r3]
requires: []
provides:
  - "Sigra.Auth.register/3 enumeration-safe for unsafe_validate_unique and DB-constraint duplicates"
  - "Example and generated registration LiveViews render flash"
affects: [253-58, 253-59]
actuals:
  tokens: 9000
  tasks: 3
  commits: 2
plan_head_before: 728bb64495b044d8ecb14e323658e7ae485ed23a
plan_head_after: ae40f7439
key-files:
  modified:
    - lib/sigra/auth.ex
    - test/sigra/auth_test.exs
    - test/example/lib/example_web/live/registration_live.ex
    - test/example/test/example_web/live/registration_live_test.exs
    - test/example/test/example_web/smoke/register_login_logout_test.exs
    - priv/templates/sigra.install/core/registration_live.ex
    - test/fixtures/install_golden/tree/lib/sigra_install_golden_tmp_web/live/registration_live.ex
    - test/sigra/install/auth_ui_contract_test.exs
    - CHANGELOG.md
key-decisions:
  - "D-04 exception approved by Jon: library enumeration fix plus generated-host output change"
requirements-completed: ["CIREL-01"]
duration: 25min
completed: 2026-10-14
status: complete
coverage:
  - id: D1
    description: "register/3 returns {:error, :email_taken} for unsafe_unique rejections and withholds the uniqueness error when other errors coexist"
    requirement: "CIREL-01"
    verification:
      - kind: unit
        ref: "test/sigra/auth_test.exs#register/3 (3 new cases)"
        status: pass
    human_judgment: false
  - id: D2
    description: "Example registration page renders flash; duplicate email shows the generic message and never 'has already been taken'"
    requirement: "CIREL-01"
    verification:
      - kind: integration
        ref: "test/example/test/example_web/live/registration_live_test.exs#duplicate email registration"
        status: pass
    human_judgment: false
  - id: D3
    description: "Generated registration template and golden fixture pass flash={@flash}; changelog discloses the change"
    requirement: "CIREL-01"
    verification:
      - kind: integration
        ref: "test/sigra/install/golden_diff_test.exs; test/sigra/install/auth_ui_contract_test.exs"
        status: pass
    human_judgment: false
---

# Phase 253 Plan 57: Enumeration-safe duplicate registration Summary

**Sigra.Auth.register/3 now treats `validation: :unsafe_unique` duplicates as `{:error, :email_taken}` (stripping the uniqueness error when other errors coexist), and the example, installer template and golden fixture render the flash so the generic message is visible.**

## Task 1: D-04 decision (checkpoint:decision, blocking)

Resolved before this executor ran. Jon answered **"approve"** on 2026-10-14 via the orchestrator (option chosen: "Approve (Recommended)" - approve the library enumeration fix and the generator output change as a D-04 exception). No note attached.

## Task Commits

1. Task 1: decision only, no commit.
2. Task 2 (tracer, TDD): `fd7d65693` - library fix, example flash rendering, unit and LiveView tests.
3. Task 3: `ae40f7439` - template + golden fixture flash, contract test, smoke test expectation, CHANGELOG Security entry.

`commits:` measured from ledger: 2 (base 728bb6449).

## RED outputs (before edits)

- `mix test test/sigra/auth_test.exs`: 2 failures. The unsafe_unique-only case returned `{:error, #Ecto.Changeset<errors: [email: {"has already been taken", [validation: :unsafe_unique, ...]}]>}` instead of `{:error, :email_taken}`; the mixed case kept the email uniqueness entry in `errors`.
- Example `registration_live_test.exs`: 2 failures. Duplicate submit rendered "has already been taken" and no generic message; page HTML had no `id="flash-group"`.
- `auth_ui_contract_test.exs`: 1 failure, template still had bare `<.sigra_auth_page>`.

## GREEN results

- `mix test test/sigra/auth_test.exs`: 74 tests, 0 failures.
- Example `registration_live_test.exs`: 6 tests, 0 failures.
- `mix test golden_diff_test auth_ui_contract_test templates_layout_test auth_test --include integration`: 87 tests, 0 failures.
- Full example suite (`cd test/example && mix test`): 254 tests, 0 failures (83 excluded by default tag).
- phx_new archive: `phx_new-1.8.8` (confirmed with `mix archive`).

## Decisions Made

- Example page uses `<Layouts.flash_group flash={@flash} />` (existing idiom); `.flash` only emits `role="alert"` when a message is present. Form ids, labels and required attributes unchanged.
- Audit failure reason stays `"email_taken"` whenever a uniqueness error is present (including mixed-error responses), `"validation"` otherwise; telemetry untouched.
- Template change is the single `flash={@flash}` attribute, mirroring `confirmation_live.ex`.

## Deviations from Plan

None - plan executed exactly as written. (A first macOS `sed -0,/re/` attempt failed harmlessly before any write; redone with Python.)

## Issues Encountered

None. `user.ex` untouched. No Playwright launch, no GitHub request.

## Follow-ups

The `:pending_email` / email-change path (`user.ex` `email_changeset`, `email_change.ex`) has a similar uniqueness shape and is out of scope for this plan; it may leak the same way and should be reviewed separately.

## Remaining gaps

Full Phase 253 verification remains not_started. Existing adopters see the generic message only after adding `flash={@flash}` or regenerating (disclosed in CHANGELOG).

## Known Stubs

None.

## Self-Check: PASSED

All nine declared files exist and are committed; commits fd7d65693 and ae40f7439 are ancestors of HEAD.
