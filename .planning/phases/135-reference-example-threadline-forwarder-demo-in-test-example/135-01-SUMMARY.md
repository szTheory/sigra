---
phase: 135-reference-example-threadline-forwarder-demo-in-test-example
plan: "01"
subsystem: test/example
tags:
  - threadline
  - audit-forwarder
  - integration-test
  - reference-example
dependency_graph:
  requires:
    - phase-131 (Sigra.Audit.Forwarders.Threadline library code)
    - phase-132 (threadline recipe)
  provides:
    - runnable Threadline forwarder demo in test/example/
    - Threadline dep + migrations committed to test/example/
    - integration test proving session.create → audit_actions projection
  affects:
    - test/example/mix.exs
    - test/example/mix.lock
    - test/example/priv/repo/migrations/ (three new Threadline migrations)
    - test/example/lib/example/accounts.ex
    - test/example/config/config.exs
    - test/example/AGENTS.md
    - test/example/test/example_web/threadline_forwarder_test.exs
tech_stack:
  added:
    - threadline 0.6.0 (resolved from ~> 0.5; DB-based audit projection)
    - nimble_csv 1.3.0 (threadline transitive dep)
  patterns:
    - attach telemetry forwarder in test setup (not at app boot)
    - detach boot-attached :default handler before test attach to prevent double projection
    - dispatch: :sync with repo: Example.Repo for SQL Sandbox ownership
key_files:
  created:
    - test/example/priv/repo/migrations/20260528152137_threadline_audit_schema.exs
    - test/example/priv/repo/migrations/20260528152138_threadline_semantics_schema.exs
    - test/example/priv/repo/migrations/20260528152139_threadline_governance_schema.exs
    - test/example/test/example_web/threadline_forwarder_test.exs
  modified:
    - test/example/mix.exs (threadline dep added)
    - test/example/mix.lock (updated with threadline 0.6.0 + nimble_csv)
    - test/example/lib/example/accounts.ex (forwarders: block under audit:)
    - test/example/config/config.exs (mirrored forwarders: block under audit:)
    - test/example/AGENTS.md (Threadline audit forwarder demo section appended)
decisions:
  - "threadline 0.6.0 resolved (not 0.5.0) — ~> 0.5 allows minor bumps; API and schema compatible"
  - "three migrations not two — 0.6.0 adds governance schema (export_jobs, retention_runs, saved_views, evidence_records); committed all three"
  - "timestamp collision fixed: all three generated with same prefix 20260528152137; bumped semantics +1s (152138), governance +2s (152139)"
  - "test detaches :default boot-attached handler before attaching :test handler — Sigra.Application.start/2 calls attach_forwarders() which auto-attaches from config.exs; without explicit detach two handlers fire producing duplicate audit_actions rows"
  - "dispatch: :auto in config (recipe-parity); dispatch: :sync in test setup (deterministic)"
metrics:
  duration: 297s
  completed_date: "2026-05-28"
  tasks_completed: 3
  tasks_total: 3
  files_created: 4
  files_modified: 5
---

# Phase 135 Plan 01: Threadline Forwarder Demo Summary

**One-liner:** End-to-end Sigra→Threadline audit projection demo in test/example/: dep + three DB migrations + dual forwarders: config + integration test asserting session.create materializes as audit_actions row joined on correlation_id.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Add Threadline dep + committed migrations | 22790c4 | mix.exs, mix.lock, 3 migration files |
| 2 | Add forwarders: config block + AGENTS.md section | e4add7c | accounts.ex, config.exs, AGENTS.md |
| 3 | Write integration test (full projection chain) | b39a9ba | threadline_forwarder_test.exs |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Bug] Threadline 0.6.0 resolved instead of 0.5.0**
- **Found during:** Task 1 (mix deps.get)
- **Issue:** `~> 0.5` in Elixir/Hex allows minor version bumps, so Hex resolved 0.6.0 (latest) rather than 0.5.0 (root mix.lock pin). The test/example is a separate mix project with its own lock.
- **Fix:** Used 0.6.0 — API is compatible (record_action/2 signature, AuditAction schema, ActorRef struct all unchanged). Updated mix.lock committed.
- **Files modified:** test/example/mix.lock

**2. [Rule 1 - Bug] Three migrations generated (not two) with timestamp collision**
- **Found during:** Task 1 (mix threadline.install)
- **Issue:** Threadline 0.6.0 generates THREE migrations (capture, semantics, governance) all with identical timestamp 20260528152137 — the Pitfall 2 collision from RESEARCH. The plan described two migrations based on 0.5.0.
- **Fix:** Committed all three migrations verbatim; bumped semantics timestamp to 152138 (+1s) and governance to 152139 (+2s). Correct ordering: capture < semantics (semantics ALTERs audit_transactions) < governance (independent tables).
- **Files modified:** renamed 20260528152137_threadline_semantics_schema.exs → 20260528152138_threadline_semantics_schema.exs, 20260528152137_threadline_governance_schema.exs → 20260528152139_threadline_governance_schema.exs

**3. [Rule 1 - Bug] Double projection due to Sigra.Application auto-attaching at boot**
- **Found during:** Task 3 (test run failed with Ecto.MultipleResultsError — 2 rows for same correlation_id)
- **Issue:** `Sigra.Application.start/2` calls `attach_forwarders()` which reads `config.exs` and auto-attaches `{Sigra.Audit.Forwarders.Threadline, :default}` at Sigra library boot. The test then attaches `{Sigra.Audit.Forwarders.Threadline, :test}` as a SECOND handler. Both handlers fire for the same telemetry event, inserting two `audit_actions` rows with the same `correlation_id`. `Repo.one` raises `Ecto.MultipleResultsError`.
- **Fix:** Added explicit `:telemetry.detach({Sigra.Audit.Forwarders.Threadline, :default})` in test setup BEFORE attaching the `:test` handler. This ensures exactly one handler is active during the test.
- **Files modified:** test/example/test/example_web/threadline_forwarder_test.exs

## Verification Results

All phase-level checks pass:

1. **New test green:** `mix test test/example_web/threadline_forwarder_test.exs --include example_app` exits 0 (1 test, 0 failures)
2. **Lane parity:** `mix test --include example_app` exits 0 (236 tests, 0 failures — all example CI lanes stay green)
3. **Migrations apply in order:** capture (152137) → semantics (152138) → governance (152139), no duplicate-version or missing-table errors
4. **Grep discoverability:** `grep -ril threadline test/example/` returns mix.exs, mix.lock, accounts.ex, config.exs, AGENTS.md, and all 3 migration files and the test file
5. **No dead secrets:** `grep -r "THREADLINE_ENDPOINT|THREADLINE_API_KEY|api_key:" test/example/lib test/example/config` returns nothing
6. **Frozen library invariant:** `git status --porcelain lib/` shows no changes
7. **No new examples/ dir or CI jobs:** confirmed via git status
8. **Compile clean:** `MIX_ENV=test mix compile --warnings-as-errors` exits 0

## Known Stubs

None — the integration test asserts real DB rows; no placeholder data.

## Threat Flags

No new network endpoints, auth paths, or trust boundary changes introduced. All new files are scoped to `test/example/` with `only: [:dev, :test]` dep scope.

## Self-Check: PASSED

- test/example/mix.exs: FOUND
- test/example/mix.lock: FOUND
- test/example/priv/repo/migrations/20260528152137_threadline_audit_schema.exs: FOUND
- test/example/priv/repo/migrations/20260528152138_threadline_semantics_schema.exs: FOUND
- test/example/priv/repo/migrations/20260528152139_threadline_governance_schema.exs: FOUND
- test/example/lib/example/accounts.ex (forwarders: block): FOUND
- test/example/config/config.exs (forwarders: block): FOUND
- test/example/AGENTS.md (Threadline demo section): FOUND
- test/example/test/example_web/threadline_forwarder_test.exs: FOUND
- Commits 22790c4, e4add7c, b39a9ba: FOUND
