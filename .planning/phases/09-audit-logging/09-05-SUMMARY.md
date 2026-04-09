---
phase: 09-audit-logging
plan: 05
subsystem: audit
tags: [tdd, wave-0, scaffolding, tests]
requires: []
provides:
  - test/sigra/audit/changeset_test.exs
  - test/sigra/audit/cursor_test.exs
  - test/sigra/audit/query_test.exs
  - test/sigra/audit/cursor_portability_test.exs
  - test/sigra/audit_test.exs
  - test/sigra/audit_integration_test.exs
  - test/sigra/audit_observability_test.exs
  - test/sigra/audit_sensitive_data_test.exs
  - test/sigra/audit_security_test.exs
  - test/sigra/audit_property_test.exs
  - test/sigra/workers/audit_cleanup_test.exs
  - test/support/audit_fixtures.ex
  - test/support/audit_test_event.ex
affects:
  - mix.exs (added :stream_data dep)
tech_stack:
  added:
    - "stream_data ~> 1.1 (test/dev only)"
  patterns:
    - "Stand-in Ecto schema in test/support for shared use across test files"
    - "Module-level StubRepo per test file (matches existing api_token_test.exs pattern)"
    - "Runtime lookup of Sigra.Audit.Changeset.forbidden_keys/0 (avoids compile-time coupling before Plan 02)"
key_files:
  created:
    - test/sigra/audit/changeset_test.exs
    - test/sigra/audit/cursor_test.exs
    - test/sigra/audit/query_test.exs
    - test/sigra/audit/cursor_portability_test.exs
    - test/sigra/audit_test.exs
    - test/sigra/audit_integration_test.exs
    - test/sigra/audit_observability_test.exs
    - test/sigra/audit_sensitive_data_test.exs
    - test/sigra/audit_security_test.exs
    - test/sigra/audit_property_test.exs
    - test/sigra/workers/audit_cleanup_test.exs
    - test/support/audit_fixtures.ex
    - test/support/audit_test_event.ex
  modified:
    - mix.exs
decisions:
  - "Used per-module StubRepo instead of plan-prescribed Sigra.DataCase (which does not exist in this project) — matches established api_token_test.exs pattern"
  - "Moved TestEvent stand-in schema to test/support/audit_test_event.ex for cross-file sharing (was originally inlined in changeset_test.exs)"
  - "forbidden_keys lookup is runtime, not @attribute, to keep tests compiling before Plan 02 lands the Changeset module"
metrics:
  duration: "~5 minutes"
  completed: 2026-04-09
  tasks: 2
  test_files: 11
  support_files: 2
  total_tests: 54
  red_tests_expected: 54
requirements:
  - AUDIT-01
  - AUDIT-02
  - AUDIT-03
  - AUDIT-04
---

# Phase 9 Plan 05: Wave 0 Test Scaffolding Summary

Wave 0 TDD test scaffolds for Sigra.Audit covering changeset validators, cursor pagination, query composition, top-level API, transactional integration, telemetry observability, sensitive-data regression, security guardrails, retention worker, and property-based invariants — 54 RED tests across 11 files plus 2 shared support modules, ready to turn green as Plans 02-04 land their implementations.

## What Was Built

Eleven test files and two test-support modules that describe the complete behavioral contract for `Sigra.Audit`, `Sigra.Audit.Changeset`, `Sigra.Audit.Cursor`, `Sigra.Audit.Query`, and `Sigra.Workers.AuditCleanup` — none of which exist yet. The tests compile cleanly under `mix compile --warnings-as-errors`, discover 54 test cases (3 properties + 51 unit/integration), and fail at runtime with `UndefinedFunctionError` against the missing modules. This is the intentional Wave 0 RED state: the tests are the executable specification that Plans 02-04 will turn green.

The plan also adds `stream_data ~> 1.1` to `mix.exs` (dev/test only) to support the property-based tests, and creates two shared support modules:

- `Sigra.Test.AuditEvent` — minimal stand-in Ecto schema mirroring D-05 for use as the `audit_schema:` argument in tests
- `Sigra.Test.AuditFixtures` — `audit_event_fixture/1` builder, `assert_audit_event/2` helper, `clear_audit_events/1` cleanup

## Tasks Completed

| Task | Name                                                                              | Commit  | Files                                                                                                                                                                              |
| ---- | --------------------------------------------------------------------------------- | ------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1    | stream_data dep + unit/property test scaffolds (changeset, cursor, query)         | 4819063 | mix.exs, mix.lock, test/sigra/audit/{changeset,cursor,query}_test.exs, test/sigra/audit_property_test.exs, test/support/audit_test_event.ex                                        |
| 2    | Integration + observability + sensitive-data + security + worker tests + fixtures | 43e4a11 | test/sigra/audit_test.exs, audit_integration_test.exs, audit_observability_test.exs, audit_sensitive_data_test.exs, audit_security_test.exs, workers/audit_cleanup_test.exs, audit/cursor_portability_test.exs, test/support/audit_fixtures.ex |

## Test Coverage Inventory

**Unit (Plan 02 surface):**
- `audit/changeset_test.exs` — 10 tests across 5 describe blocks: action regex (D-19), outcome whitelist, reserved-prefix guardrail (D-17/D-18, parameterized over 7 prefixes), metadata size cap (D-20), forbidden keys (D-23, atom + string variants)
- `audit/cursor_test.exs` — 4 tests: encode/decode roundtrip, garbage rejection (3 cases)
- `audit/query_test.exs` — 9 tests: each D-12 filter, paginate cursor expansion (RESEARCH A3)

**Property (Plan 02 + 03):**
- `audit_property_test.exs` — 3 properties: cursor roundtrip over arbitrary (DateTime, UUID), forbidden-keys universal rejection, valid-action regex generator

**Top-level API (Plan 02):**
- `audit_test.exs` — 8 tests: log/3 happy path, invalid action, reserved prefix, default outcome, query/1 type, count/2, list/2 contract, stream/2

**Integration (Plan 02):**
- `audit_integration_test.exs` — 4 tests: log_multi/3 appends :audit step, log_multi rejects reserved prefix, __log_internal__ bypass, atomicity rollback shape

**Observability (Plan 02):**
- `audit_observability_test.exs` — 3 tests: telemetry fires once on success, never on validation failure, payload shape (D-24)

**Sensitive data (Plan 03 net):**
- `audit_sensitive_data_test.exs` — 2 tests: forbidden-key sweep (D-23), required canonical keys present

**Security (Plan 02):**
- `audit_security_test.exs` — 3 tests: 7 reserved prefixes rejected on public log/3 (D-17), __log_internal__ docs hidden (D-15), configurable reserved_prefixes (D-18)

**Worker (Plan 04):**
- `workers/audit_cleanup_test.exs` — 5 tests: cleanup/3 export, nil retention no-op (D-09), positive retention triggers delete, perform/1 export, max_attempts = 1

**Cross-DB portability (Plan 02 + Manual):**
- `audit/cursor_portability_test.exs` — 1 tagged test (`@moduletag :cursor_portability`) — 5-row pagination smoke covering RESEARCH A3 or-expanded tiebreak. Runs on whichever adapter CI selects; the other adapter is covered via VALIDATION.md Manual-Only Verifications.

**Total:** 54 tests (51 unit/integration + 3 properties) across 11 files. All 54 RED with `UndefinedFunctionError` — the expected Wave 0 state.

## Verification

```
mix compile --warnings-as-errors → 0 warnings
mix test test/sigra/audit/ test/sigra/audit_property_test.exs --no-start → 28 failures (3 properties + 25 tests)
mix test test/sigra/audit_test.exs test/sigra/audit_integration_test.exs test/sigra/audit_observability_test.exs test/sigra/audit_sensitive_data_test.exs test/sigra/audit_security_test.exs test/sigra/workers/audit_cleanup_test.exs test/sigra/audit/cursor_portability_test.exs --include cursor_portability --no-start → 26 failures
```

All failures are `UndefinedFunctionError` against `Sigra.Audit.*` and `Sigra.Workers.AuditCleanup` — no compile errors, no false positives, no flaky behavior. Plans 02-04 will turn each one green as the corresponding module lands.

## Deviations from Plan

### [Rule 3 — Blocking] Sigra.DataCase does not exist in this project

- **Found during:** Task 2, before writing the first integration test file
- **Issue:** The plan's task action templates assume `use Sigra.DataCase` and a real `Repo` (e.g. `Sigra.Repo` or `Sigra.TestRepo`). Sigra has neither — there is no Ecto sandbox, no DataCase, and `Sigra.TestRepo` is referenced as a bare atom in `test/sigra/workers/token_cleanup_test.exs` and `test/sigra/plug/fetch_bearer_test.exs` but never defined as an `Ecto.Repo`.
- **Fix:** Followed the established project pattern from `test/sigra/api_token_test.exs`: each test file defines a per-module `StubRepo` with the minimal `insert/1`, `all/1`, `aggregate/3`, `transaction/1`, `delete_all/1` callbacks the test needs. Tests still drive the real `Sigra.Audit` API surface and still go RED with `UndefinedFunctionError` until Plan 02 lands. When Plan 02 wires a real test repo (or sandbox), the StubRepo modules can be replaced in a single sweep.
- **Files modified:** All seven Task 2 test files use `use ExUnit.Case` + module-level `StubRepo` instead of `use Sigra.DataCase`.
- **Commit:** 43e4a11

### [Rule 3 — Blocking] Inline TestEvent struct could not cross test-file boundaries

- **Found during:** Task 1 first compile pass
- **Issue:** The plan inlined a `TestEvent` Ecto schema inside `Sigra.Audit.ChangesetTest`. The property test then referenced `%Sigra.Audit.ChangesetTest.TestEvent{}`, which fails because test files compile in arbitrary order — the struct must exist in `test/support/` to be guaranteed available.
- **Fix:** Extracted the schema to `test/support/audit_test_event.ex` as `Sigra.Test.AuditEvent` (also reused by all Task 2 tests as `audit_schema:` value).
- **Commit:** 4819063

### Auth gates

None encountered.

## Self-Check: PASSED

**Files exist:**
- mix.exs (modified) — FOUND
- test/sigra/audit/changeset_test.exs — FOUND
- test/sigra/audit/cursor_test.exs — FOUND
- test/sigra/audit/query_test.exs — FOUND
- test/sigra/audit/cursor_portability_test.exs — FOUND
- test/sigra/audit_test.exs — FOUND
- test/sigra/audit_integration_test.exs — FOUND
- test/sigra/audit_observability_test.exs — FOUND
- test/sigra/audit_sensitive_data_test.exs — FOUND
- test/sigra/audit_security_test.exs — FOUND
- test/sigra/audit_property_test.exs — FOUND
- test/sigra/workers/audit_cleanup_test.exs — FOUND
- test/support/audit_fixtures.ex — FOUND
- test/support/audit_test_event.ex — FOUND

**Commits exist:**
- 4819063 — FOUND (Task 1)
- 43e4a11 — FOUND (Task 2)

**Acceptance criteria:**
- stream_data in mix.exs — verified
- mix compile --warnings-as-errors exits 0 — verified
- describe block count in changeset_test.exs == 5 — verified (≥5 required)
- All marker greps from plan acceptance section — verified
