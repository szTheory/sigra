---
phase: "214"
plan: "04"
subsystem: test-infrastructure
tags: [chimeway, exunit, test-config, upgrade-test, health]
requires: []
provides: [chimeway-repo-test-config, conditional-upgrade-skip]
affects: [config/test.exs, test/test_helper.exs]
tech_stack:
  added: []
  patterns: [ExUnit.configure-conditional-exclude, config-DB-for-optional-dep]
key_files:
  created: []
  modified:
    - config/test.exs
    - test/test_helper.exs
decisions:
  - "Config-DB approach (D-18): give Chimeway.Repo valid DB config in config/test.exs so it starts cleanly without a connection error; no Sigra test uses Chimeway.Repo directly"
  - "Conditional :upgrade exclusion (D-19): phx_new_ok? check via mix archive.list before ExUnit.start(); exclusion fires only when phx_new-1.8.8 is absent locally; CI always has it installed so the upgrade test runs there"
  - "NOT a blanket :postgres exclusion (CLAUDE.md constraint): the upgrade exclusion is archive-presence conditional, not DB-presence conditional"
metrics:
  duration: "89s"
  completed: "2026-07-03"
  tasks: 2
  files: 2
status: complete
---

# Phase 214 Plan 04: Chimeway Repo Config + Conditional Upgrade Skip Summary

**One-liner:** Chimeway.Repo gets valid config-DB stanza in test.exs so it starts clean, and test_helper.exs gains a phx_new-1.8.8 presence check that conditionally excludes :upgrade tests when the archive is absent locally.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Add Chimeway.Repo config to config/test.exs (D-18) | 54c4b385 | config/test.exs |
| 2 | Conditional upgrade test preflight skip in test_helper.exs (D-19/D-20) | 72e5e2f9 | test/test_helper.exs |

## What Was Built

### Task 1: Chimeway.Repo config stanza (D-18)

Added a new config block to `/Users/jon/projects/sigra/config/test.exs` that provides `Chimeway.Repo` with valid database connection parameters. `Chimeway.Application` unconditionally supervises `Chimeway.Repo` at boot — without a config stanza, the repo logs DB connection errors on every test run even though no Sigra test exercises it. The stanza uses the same `SIGRA_TEST_PG_*` env var convention as `Sigra.Test.PostgresRepo` and sets `pool: Ecto.Adapters.SQL.Sandbox` consistent with the test environment.

### Task 2: Conditional :upgrade exclusion (D-19/D-20)

Updated `/Users/jon/projects/sigra/test/test_helper.exs` to insert a `phx_new_ok?` check before `ExUnit.start()`. The check shells out to `mix archive.list` and sets `ExUnit.configure(exclude: [:upgrade])` only when the `phx_new-1.8.8` archive is absent. This means:
- **Local dev without the archive:** upgrade tests gracefully skipped; zero spurious failures
- **CI (where phx_new 1.8.8 is installed):** upgrade test runs normally — the exclusion is NOT triggered
- **CLAUDE.md constraint honored:** no blanket `:postgres` exclusion; only `:upgrade` is conditionally excluded

## Verification Results

```
grep -c "chimeway, Chimeway.Repo" config/test.exs => 1  (PASS)
grep -c "phx_new_ok?" test/test_helper.exs         => 2  (PASS - assignment + unless condition)
grep -c 'ExUnit.configure(exclude: [:upgrade])'    => 1  (PASS - inside unless block, not unconditional)
```

All three verification checks from the plan pass.

## Deviations from Plan

None — plan executed exactly as written. The config stanza and test_helper pattern match the plan's specified code verbatim.

## Known Stubs

None.

## Threat Flags

None — changes affect only test environment configuration and test suite startup; no new network endpoints, auth paths, or trust boundaries.

## Self-Check: PASSED

- config/test.exs: exists with Chimeway.Repo stanza (commit 54c4b385)
- test/test_helper.exs: exists with phx_new_ok? block before ExUnit.start() (commit 72e5e2f9)
- Both commits exist in git log
