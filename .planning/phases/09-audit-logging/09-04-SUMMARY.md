---
phase: 09-audit-logging
plan: 04
subsystem: audit
tags: [audit, retention, oban, worker]
requires:
  - "09-01"
  - "09-02"
  - "09-05"
provides:
  - Sigra.Workers.AuditCleanup
  - Sigra.Application
affects:
  - lib/sigra/workers/audit_cleanup.ex
  - lib/sigra/application.ex
  - mix.exs
tech-stack:
  added:
    - Sigra OTP application callback (Sigra.Application)
  patterns:
    - Oban worker cloning TokenCleanup (queue, max_attempts, perform/1 shape)
    - Inline fallback via Sigra.Audit.cleanup/1 when Oban absent
    - Boot-time optional-dep warning via Code.ensure_loaded?/1
key-files:
  created:
    - lib/sigra/workers/audit_cleanup.ex
    - lib/sigra/application.ex
  modified:
    - mix.exs
decisions:
  - "Added Sigra.Application as OTP callback (mod: {Sigra.Application, []}) so boot-time warnings have a landing spot; supervisor is empty since Sigra starts no long-lived processes"
  - "String.to_existing_atom/1 used for all job-arg module resolution (T-9-08 mitigation)"
requirements:
  - AUDIT-03
metrics:
  duration: ~5min
  tasks_completed: 1
  tests_passing: 5
  completed: 2026-04-09
---

# Phase 09 Plan 04: Audit Retention Cleanup Worker Summary

Ships the optional `Sigra.Workers.AuditCleanup` Oban worker for AUDIT-03 retention cleanup, cloning the `Sigra.Workers.TokenCleanup` pattern and honoring D-09 (forever default), D-10 (inline fallback), and Phase 1 D-36 (fail-open `max_attempts: 1`).

## Outcome

- Optional Oban worker deletes audit rows older than `retention_days` via `Sigra.Audit.do_cleanup/3`.
- `nil` retention → no-op (D-09).
- Direct `cleanup/3` entrypoint so host apps without Oban can schedule cleanup themselves.
- `Sigra.Application.start/2` logs a single startup warning when `retention_days` is configured but Oban is not loaded, advising the inline `Sigra.Audit.cleanup/1` fallback path.
- 5/5 tests in `test/sigra/workers/audit_cleanup_test.exs` now pass (was RED Wave 0 scaffold).

## Task 1: Worker + startup warning

- Created `lib/sigra/workers/audit_cleanup.ex`:
  - `use Oban.Worker, queue: :sigra_mailer, max_attempts: 1` (matches TokenCleanup).
  - `perform/1` reads `repo`, `audit_schema`, `retention_days` from job args using `String.to_existing_atom/1` (T-9-08 mitigation: prevents atom-table exhaustion and restricts to host-loaded modules).
  - `cleanup/3` direct callable delegates to `Sigra.Audit.do_cleanup/3` for the inline fallback path.
- Created `lib/sigra/application.ex`:
  - OTP `Application` callback with empty supervisor (Sigra runs no long-lived processes — this exists solely to host boot-time diagnostics).
  - `maybe_warn_audit_cleanup_fallback/0` uses `cond` to short-circuit when `retention_days` is `nil` or `Oban` is loaded, otherwise emits a single `Logger.warning/1` with the exact `Sigra.Audit.cleanup/1` invocation advice.
- Wired `mod: {Sigra.Application, []}` into `mix.exs` `application/0`.
- Commit: `2979aa4`

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Created missing `lib/sigra/application.ex`**
- **Found during:** Task 1 read_first phase
- **Issue:** Plan referenced `lib/sigra/application.ex` and `Sigra.Application.start/2`, but no Application module existed in the project. `mix.exs` `application/0` had only `extra_applications`, no `mod:` entry.
- **Fix:** Created `Sigra.Application` with an empty supervisor (Sigra starts no long-lived processes) to host the boot-time warning, and added `mod: {Sigra.Application, []}` to `mix.exs`.
- **Why safe:** Adding an OTP application callback is standard for libraries that need boot diagnostics. The supervisor is empty, so there is no new runtime footprint beyond one warning check at boot.
- **Files modified:** `lib/sigra/application.ex` (new), `mix.exs`
- **Commit:** `2979aa4`

## Verification

```bash
$ mix compile --warnings-as-errors
Compiling 76 files (.ex)
Generated sigra app

$ mix test test/sigra/workers/audit_cleanup_test.exs
5 tests, 0 failures
```

Acceptance greps all passed:
- `use Oban.Worker`, `queue: :sigra_mailer`, `max_attempts: 1`, `Sigra.Audit.do_cleanup` in worker
- `maybe_warn_audit_cleanup_fallback`, `Code.ensure_loaded?(Oban)` in application

## Threat Mitigations Applied

- **T-9-04 (Repudiation — silent retention failure):** `max_attempts: 1` surfaces failures immediately in the Oban dashboard; `nil` default preserves the forensic trail unless developer explicitly opts in.
- **T-9-08 (Tampering — malicious job args):** `String.to_existing_atom/1` rejects atoms not already loaded; host apps schedule jobs from their own code, never user input.

## Known Stubs

None.

## Threat Flags

None — no new network, auth, or schema surface introduced.

## Self-Check: PASSED

- FOUND: `lib/sigra/workers/audit_cleanup.ex`
- FOUND: `lib/sigra/application.ex`
- FOUND: `mix.exs` (modified with `mod:` entry)
- FOUND: commit `2979aa4`
- Tests: 5/5 passing
