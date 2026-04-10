---
phase: 10
plan: 02
subsystem: dx
tags: [dx, fixtures, mfa, session, scenario]
requires:
  - priv/templates/sigra.install/auth_fixtures.ex (pre-existing primitives)
  - priv/templates/sigra.install/conn_case_helpers.ex (log_in_user/3)
provides:
  - AuthFixtures.anonymous_fixture/0
  - AuthFixtures.authenticated_fixture/1
  - AuthFixtures.mfa_pending_fixture/1
  - AuthFixtures.mfa_complete_fixture/1
  - AuthFixtures.sudo_fixture/1
  - AuthFixtures.locked_fixture/1
  - AuthFixtures.unconfirmed_fixture/1
  - AuthFixtures.scenario/2
affects:
  - priv/templates/sigra.install/auth_fixtures.ex
tech-stack:
  added: []
  patterns:
    - "Scenario wrappers compose primitives without duplication"
    - "Non-uniform return shapes per D-04 (no nil-padded keys)"
key-files:
  created:
    - test/sigra/auth_fixtures_scenario_test.exs
    - .planning/phases/10-developer-experience/deferred-items.md
  modified:
    - priv/templates/sigra.install/auth_fixtures.ex
decisions:
  - "Content-level template tests (read-and-assert) instead of EEx-rendering because host-app bindings only exist in a generated project; runtime behavior deferred to plan 10-06 via test/example/ app"
  - "Import log_in_user/2,/3 from ConnCaseHelpers despite alias-back-reference because alias != compile dep — no cycle"
metrics:
  duration: ~15 minutes
  completed: 2026-04-09
requirements: [DX-03]
---

# Phase 10 Plan 02: Scenario Fixtures Summary

One-liner: Seven scenario wrappers + `scenario/2` dispatcher on the generated AuthFixtures template, composing existing primitives with non-uniform return shapes per D-04/D-07.

## What Shipped

- Seven scenario fixture functions added to `priv/templates/sigra.install/auth_fixtures.ex`:
  - `anonymous_fixture/0` → `%{conn}`
  - `authenticated_fixture/1` → `%{user, session, conn}`
  - `mfa_pending_fixture/1` → delegates to `mfa_pending_session_fixture/1`; no `:conn`
  - `mfa_complete_fixture/1` → `%{user, session (type: "standard"), conn, totp_secret}`
  - `sudo_fixture/1` → `%{user, session (sudo_at set), conn}`
  - `locked_fixture/1` → `%{user}`; composes `user_fixture` + `locked_user_fixture`; no `:conn`
  - `unconfirmed_fixture/1` → `%{user}`; no `:conn`
- `scenario/2` dispatcher: head + 7 atom clauses. String input raises `FunctionClauseError` (Open Q5 resolution).
- New imports near top of template:
  - `import Phoenix.ConnTest, only: [build_conn: 0]`
  - `import <%= web_module %>.ConnCaseHelpers, only: [log_in_user: 2, log_in_user: 3]`
- Content-level unit tests in `test/sigra/auth_fixtures_scenario_test.exs` (23 tests, async) covering all nine plan behaviors plus pitfall guard rails.

## Behaviors Verified (Plan Mapping)

| # | Behavior | Asserted via |
|---|----------|--------------|
| 1 | anonymous_fixture returns `%{conn}` | regex match on `%{conn: build_conn()}` body |
| 2 | authenticated_fixture returns user/session/conn | body contains `user_fixture`, `session_fixture`, `log_in_user(build_conn()` |
| 3 | mfa_pending_fixture returns pending data, no conn | delegates to primitive; refute `log_in_user` in body |
| 4 | mfa_complete_fixture returns standard-type session | body contains `type: "standard"`, `log_in_user`, `totp_secret` |
| 5 | sudo_fixture composes sudo_session_fixture + conn | body contains both markers |
| 6 | locked_fixture uses locked_user_fixture, no conn/session | composition + refutes |
| 7 | unconfirmed_fixture returns just the user, no conn | composition + refutes |
| 8 | scenario/2 has head + 7 atom clauses | `def scenario(` count == 8; each `:atom` clause present |
| 9 | No is_binary clause (strings rejected) | regex refute on `def scenario(... is_binary` |

Plus guard rails: no `type: :standard`/`type: :mfa_pending` atoms, no `mfa_verified_at` references, `import Phoenix.ConnTest`/`ConnCaseHelpers` present.

## Deviations from Plan

None. Plan executed exactly as written:

- Used content-level template tests (Option 2 from plan Step C — "assert string presence for each fixture name and the dispatcher clauses"), matching the existing `test/sigra/templates/session_templates_test.exs` pattern. Plan explicitly authorized this fallback.
- No deviations under Rules 1-4.

## Pitfalls Honored

- **Pitfall 2** (atom vs string session.type): All `type:` assignments use string `"standard"`. Verified by grep in both source and test.
- **Pitfall 3** (no `mfa_verified_at` field): `mfa_complete_fixture` returns a post-transition `"standard"` session (Open Q1 resolution (a)), not a `mfa_verified_at`-stamped one. Verified by grep.
- **Pitfall 5** (circular compile): Import of `ConnCaseHelpers` is safe because ConnCaseHelpers references `<%= context_module %>Fixtures` only via `alias` (runtime resolution, not compile dep). No cycle.

## Deferred Issues

One pre-existing compile warning discovered during verification (not caused by this plan) logged to `.planning/phases/10-developer-experience/deferred-items.md`:

- `lib/sigra/testing.ex:488` — calls deprecated `Sigra.MFA.Trust.cookie_opts/0`. Out of scope; likely addressed by plan 10-03 (cookie_domain config).

## Verification Results

- `mix test test/sigra/auth_fixtures_scenario_test.exs` → 23 tests, 0 failures
- `rg 'def (anonymous|authenticated|mfa_pending|mfa_complete|sudo|locked|unconfirmed)_fixture' priv/templates/sigra.install/auth_fixtures.ex` → 7 matches (lines 191, 198, 209, 224, 236, 246, 255)
- `rg 'def scenario\(' priv/templates/sigra.install/auth_fixtures.ex` → 8 matches (head + 7 clauses)
- `rg 'type: :standard|type: :mfa_pending|mfa_verified_at|is_binary' priv/templates/sigra.install/auth_fixtures.ex` → 0 matches
- `mix compile --warnings-as-errors` → fails on pre-existing unrelated `Sigra.Testing.trust_browser/3` deprecation; template is priv-dir EEx, not compiled by the library.

## Commits

- `1b7926b` test(10-02): add failing test for scenario fixtures (RED)
- `24ecd7c` feat(10-02): add scenario fixtures to AuthFixtures template (GREEN)

## Follow-ups (not blocking)

- Runtime behavior verification of scenario fixtures happens in plan 10-06 against the committed `test/example/` app (install + compile + call each scenario end-to-end).
- Plan 10-06 should also assert `scenario/2` runtime raises `FunctionClauseError` on `scenario("authenticated", %{})` — plan 10-02 only guards the absence of an `is_binary` clause statically.

## Self-Check: PASSED

- [x] `priv/templates/sigra.install/auth_fixtures.ex` modified (7 new fixtures + dispatcher + 2 imports) — verified by grep
- [x] `test/sigra/auth_fixtures_scenario_test.exs` created — verified by File.read in test setup
- [x] `.planning/phases/10-developer-experience/deferred-items.md` created
- [x] Commit `1b7926b` (RED) present in `git log`
- [x] Commit `24ecd7c` (GREEN) present in `git log`
- [x] All 23 scenario tests pass
