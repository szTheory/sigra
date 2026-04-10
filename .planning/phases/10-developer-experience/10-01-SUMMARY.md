---
phase: 10
plan: 01
subsystem: developer-experience
tags: [dx, testing, audit, docs]
requires:
  - .planning/REQUIREMENTS.md (DX-01 wording)
  - lib/sigra/testing.ex (existing 1007 LOC monolithic helper module)
  - test/support/audit_test_event.ex (Sigra.Test.AuditEvent stand-in schema)
  - lib/sigra/audit.ex (Phase 9 audit_events shape)
provides:
  - Sigra.Testing.audit_event_fixture/1
  - Sigra.Testing.assert_audit_event/2
  - Sigra.Testing section headers (9 clusters)
  - REQUIREMENTS.md DX-01 wording reconciled with shipped signatures
affects:
  - downstream Phase 10 plans that build on Sigra.Testing organization
tech-stack:
  added: []
  patterns:
    - StubRepo Agent-backed in-process fake (mirrors test/sigra/audit_test.exs precedent)
    - Section comment headers (# --- Cluster ---) over monolithic test helper
key-files:
  created:
    - test/sigra/testing_audit_test.exs
  modified:
    - .planning/REQUIREMENTS.md
    - lib/sigra/testing.ex
  deleted:
    - test/support/audit_fixtures.ex
decisions:
  - D-01 enacted: REQUIREMENTS.md DX-01 names log_in_user/3, register_user/2, setup_totp/2, create_api_token/3 (no aliases, no renames)
  - D-18 enacted: audit_event_fixture/1 + assert_audit_event/2 shipped in Sigra.Testing
  - D-19 enacted: 9 section headers added; module remains monolithic
  - Open Q3 resolved: deleted test/support/audit_fixtures.ex (no callers); one canonical location
metrics:
  duration: ~25 minutes
  completed: 2026-04-09
  tasks: 2
  files_modified: 4
---

# Phase 10 Plan 01: DX-01 reconciliation and Sigra.Testing audit helpers Summary

Closed the Phase 9 audit-helper carryover, reconciled REQUIREMENTS.md DX-01 wording with shipped signatures, and added section comment headers to the monolithic `Sigra.Testing` module — establishing the canonical organization downstream Phase 10 plans build on.

## What Shipped

### Task 1 — REQUIREMENTS.md DX-01 reconciliation (D-01)

Replaced the DX-01 bullet in `.planning/REQUIREMENTS.md` with the four shipped signatures:

- `YourAppWeb.ConnCase.log_in_user/3` (generated)
- `YourApp.Accounts.register_user/2` (generated)
- `Sigra.Testing.setup_totp/2`
- `Sigra.Testing.create_api_token/3`

The wording explicitly notes the rationale: arities reflect real option needs (`:mfa`, `:config`), names follow phx.gen.auth (Phase 1 D-43), and Phase 7 D-63 standardized "token" over "key". Appended a dated footer recording the reconciliation.

### Task 2 — Section headers + audit helpers in `Sigra.Testing` (D-18, D-19)

**Section headers (D-19):** Inserted nine `# --- Cluster ---` headers above the first function in each cluster — no functions moved, no signatures changed. The pre-existing two-dash `# -- Phase N --` comments are preserved alongside the new three-dash headers (the acceptance regex `^\s*# --- .* ---\s*$` matches three dashes only).

Order matches the existing function order in the file:

1. `# --- Core Assertions ---` (line 21)
2. `# --- Email ---` (line 79)
3. `# --- Lockout ---` (line 144)
4. `# --- MFA ---` (line 216)
5. `# --- API Tokens ---` (line 503)
6. `# --- Account Lifecycle ---` (line 680)
7. `# --- Hooks ---` (line 879)
8. `# --- OAuth ---` (line 913)
9. `# --- Audit (Phase 9) ---` (line 1019)

**Audit helpers (D-18):**

- `audit_event_fixture/1` — inserts directly via the configured repo, bypassing `Ecto.Multi` wrapping. Required keyword opts: `:repo`, `:audit_schema`. Optional: `:action` (default `"test.event"`), `:outcome` (`"success"`), `:actor_id`, `:actor_type` (`"user"`), `:target_id`, `:target_type`, `:metadata` (`%{}`), `:occurred_at`. Returns the inserted struct.
- `assert_audit_event/2` — checks the most recent audit row (or `position:` Nth-most-recent) against an expected map. Top-level keys compared with strict equality; `:metadata` deep-matches as a subset (extras allowed; tolerates atom or string keys). Raises `ExUnit.AssertionError` with diff-style messages on mismatch.

**Old scaffold removed:** `test/support/audit_fixtures.ex` (the Phase 9 Wave 0 scaffold) had no remaining callers (`grep "Sigra.Test.AuditFixtures"` showed only the file's own definition). Deleted per Open Q3 resolution to keep one canonical location.

### Tests

`test/sigra/testing_audit_test.exs` — 7 tests covering:

1. `audit_event_fixture/1` defaults
2. `audit_event_fixture/1` with all overrides
3. `assert_audit_event/2` happy path
4. `assert_audit_event/2` mismatch raising `ExUnit.AssertionError`
5. `assert_audit_event/2` metadata subset deep-match (ignores extras)
6. `assert_audit_event/2` with `position: 1` and `position: 0`
7. `assert_audit_event/2` raising when no event exists at the requested position

The test uses an in-process Agent-backed `StubRepo` keyed by test pid (so async tests stay isolated), mirroring the precedent in `test/sigra/audit_test.exs`. The stub interprets `Ecto.Query` `order_by`/`limit`/`offset` to support the helper's query shape.

## Verification Results

- `mix test test/sigra/testing_audit_test.exs` — **7 tests, 0 failures**
- `mix compile --warnings-as-errors --force` — **clean** (76 files compiled, 0 warnings)
- `rg -c '^\s*# --- .* ---\s*$' lib/sigra/testing.ex` → **9** ✅
- `rg -n 'def audit_event_fixture\(' lib/sigra/testing.ex` → **1 match** ✅
- `rg -n 'def assert_audit_event\(' lib/sigra/testing.ex` → **1 match** ✅
- `rg -n 'create_api_token/3' .planning/REQUIREMENTS.md` → **1 match** ✅
- `rg -n 'log_in_user/3' .planning/REQUIREMENTS.md` → **1 match** ✅
- `rg -n 'setup_totp/2' .planning/REQUIREMENTS.md` → **1 match** ✅
- `rg -n 'register_user/2' .planning/REQUIREMENTS.md` → **1 match** ✅
- `rg -n 'create_api_key' .planning/REQUIREMENTS.md` → **0 matches** ✅
- `rg -n 'Sigra.Test.AuditFixtures|test/support/audit_fixtures' test/` → **0 matches** ✅

## Deviations from Plan

None — plan executed exactly as written. Two minor judgment calls within the plan's allowed space:

1. **Three-dash headers coexist with existing two-dash headers.** The plan required adding the nine `# --- ... ---` headers; the file already had five `# -- ... --` (two-dash) Phase markers. I left the existing two-dash markers in place rather than mutating them — they don't match the acceptance regex (which is three-dash only) and the plan said "Do NOT move functions; only insert comment lines", suggesting minimal-change discipline. The result is an explicit, unambiguous nine three-dash headers that downstream tooling can grep deterministically.
2. **`require Ecto.Query` inside `assert_audit_event/2`** rather than top-of-module — keeps the audit cluster self-contained without forcing every other function in `Sigra.Testing` to load `Ecto.Query` macros at compile time.

## Deferred Issues

**Pre-existing failing test:** `test/sigra/audit/cursor_portability_test.exs:31` — `paginates deterministically across cursor boundary on this adapter` was failing **before** this plan's changes (verified via `git stash && mix test ...`). It is unrelated to `Sigra.Testing` or audit helpers — out of scope per the executor scope boundary. Logged here for visibility; should be addressed in a Phase 9 follow-up or a separate quick fix.

## Threat Surface Scan

No new attack surface introduced. The two new helpers are test-only:

- `audit_event_fixture/1` writes to a repo passed by the caller via opts; it does not escape the test sandbox. T-10-06 disposition (accept) holds: production `Sigra.Audit.log/2` path is unchanged.
- `assert_audit_event/2` only reads via the same caller-provided repo; diff messages use `inspect/1` on the *expected* map, never dumping the full event record. T-10-07 disposition (mitigate) is enforced by the implementation.
- T-10-08 disposition (mitigate) is satisfied by Task 1: REQUIREMENTS.md DX-01 wording now exactly matches shipped signatures.

No `## Threat Flags` section needed.

## Commits

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1    | Update REQUIREMENTS.md DX-01 to shipped signatures | `cb61fb3` | .planning/REQUIREMENTS.md |
| 2 (RED) | Failing tests for audit_event_fixture/assert_audit_event | `bde4e05` | test/sigra/testing_audit_test.exs |
| 2 (GREEN) | Section headers + audit helpers, delete old scaffold | `d891e2b` | lib/sigra/testing.ex, test/support/audit_fixtures.ex (deleted) |

## Self-Check

- `[ -f .planning/REQUIREMENTS.md ]` → FOUND
- `[ -f lib/sigra/testing.ex ]` → FOUND
- `[ -f test/sigra/testing_audit_test.exs ]` → FOUND
- `[ ! -f test/support/audit_fixtures.ex ]` → CONFIRMED DELETED
- Commit `cb61fb3` → FOUND in `git log`
- Commit `bde4e05` → FOUND in `git log`
- Commit `d891e2b` → FOUND in `git log`

## Self-Check: PASSED
