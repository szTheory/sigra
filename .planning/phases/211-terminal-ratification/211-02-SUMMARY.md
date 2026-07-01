---
phase: 211-terminal-ratification
plan: "02"
subsystem: testing
tags: [playwright, smoke-test, phx_new, installer, golden-diff, parity, gate]

# Dependency graph
requires:
  - phase: 211-01
    provides: ledger lock + canary idempotency verification (GATE-01)
provides:
  - "phx_new 1.8.7 archive pinned (corrected from 1.8.8 blocker)"
  - "Install-golden byte-diff green under phx_new 1.8.7 (GATE-02 byte-parity)"
  - "admin-acceptance-smoke.sh exit 0 on fresh phx_new 1.8.7 host (GATE-02 runtime parity)"
  - "No installer-template drift found — priv/templates/sigra.install/ byte-stable vs test/example/"
affects: [211-03, 211-04, 211-05, milestone-close]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "smoke must run with explicit PGPORT=5432 when tmp/db.env exports PGPORT=58915 (Docker); the generated host config has no port: key, so Postgrex falls back to PGPORT env"
    - "stale sigra_admin_smoke_dev DB on system postgres (5432) causes duplicate_table on first run of each session; drop before re-running"

key-files:
  created: []
  modified: []

key-decisions:
  - "phx_new 1.8.7 pin (SEED-004) corrected before running any GATE-02 lane; do NOT regenerate the golden fixture to absorb 1.8.8 root_tag_attribute diff"
  - "smoke run with PGPORT=5432 explicitly to override tmp/db.env's PGPORT=58915; generated host uses system Homebrew Postgres (5432), not Docker test Postgres (58915)"
  - "No installer-template drift found — zero fix commits needed; priv/templates/sigra.install/ is byte-stable"

patterns-established:
  - "GATE-02 byte-parity pattern: install phx_new 1.8.7, run golden_diff_test.exs, accept 0 failures as byte-stable"
  - "GATE-02 runtime-parity pattern: PGPORT=5432 PGHOST=localhost PGUSER=postgres PGPASSWORD=postgres GITHUB_WORKSPACE=$(pwd) bash scripts/ci/admin-acceptance-smoke.sh"
  - "Stale smoke DB cleanup: drop sigra_admin_smoke_dev and sigra_admin_smoke_test from system postgres (5432) before re-running smoke"

requirements-completed: [GATE-02]

coverage:
  - id: D1
    description: "phx_new 1.8.7 archive installed and confirmed as the active pin"
    requirement: GATE-02
    verification:
      - kind: manual_procedural
        ref: "mix archive | grep phx_new → phx_new-1.8.7"
        status: pass
    human_judgment: false
  - id: D2
    description: "Install-golden byte-diff green under phx_new 1.8.7 (installer↔example byte-parity)"
    requirement: GATE-02
    verification:
      - kind: integration
        ref: "MIX_ENV=test mix test test/sigra/install/golden_diff_test.exs → 2 tests, 0 failures"
        status: pass
    human_judgment: false
  - id: D3
    description: "admin-acceptance-smoke.sh exits 0 on freshly generated phx_new 1.8.7 host; all 6 Playwright probes pass; elevated styled admin rendered"
    requirement: GATE-02
    verification:
      - kind: e2e
        ref: "PGPORT=5432 GITHUB_WORKSPACE=$(pwd) bash scripts/ci/admin-acceptance-smoke.sh → 6/6 passed, smoke_exit=0"
        status: pass
    human_judgment: false
  - id: D4
    description: "No installer-template drift: priv/templates/sigra.install/ is byte-stable vs test/example/"
    requirement: GATE-02
    verification:
      - kind: integration
        ref: "git status --short priv/templates/ → no output (clean)"
        status: pass
    human_judgment: false

# Metrics
duration: 9min
completed: 2026-07-01
status: complete
---

# Phase 211 Plan 02: GATE-02 Generated-Host Parity Summary

**phx_new 1.8.7 pin corrected (was 1.8.8), install-golden byte-diff green (2 tests, 0 failures), and admin-acceptance-smoke exits 0 with 6/6 Playwright probes passing on a fresh phx_new 1.8.7 host — GATE-02 runtime parity and byte-parity both proven**

## Performance

- **Duration:** 9min
- **Started:** 2026-07-01T20:10:20Z
- **Completed:** 2026-07-01T20:19:23Z
- **Tasks:** 2
- **Files modified:** 0 (verification-only plan; no code changes)

## Accomplishments

- Corrected the phx_new archive blocker: downgraded 1.8.8 → 1.8.7 via `mix archive.install --force hex phx_new 1.8.7` (SEED-004 / GATE-02 precondition)
- Install-golden byte-diff suite passes under phx_new 1.8.7: 2 tests, 0 failures — installer↔example byte-parity holds
- admin-acceptance-smoke.sh exits 0: scaffolded fresh phx.new 1.8.7 host, applied mix sigra.install, migrated, seeded, booted on PORT=4017, rendered elevated styled admin; all 6 Playwright probes passed
- No installer-template drift detected: priv/templates/sigra.install/ is byte-stable vs test/example/ (no fix commit needed)
- GATE-02 generated-host parity fully proven both byte-wise (golden fixture) and at runtime (acceptance smoke)

## Task Commits

Both tasks were verification-only — no code changes were introduced:

1. **Task 1: Pre-flight phx_new 1.8.7 pin + install-golden byte-diff** — No commit (verification only; mix archive install is a local tool state change, not a repo change; golden_diff_test.exs = 2 tests, 0 failures; git status clean)
2. **Task 2: admin-acceptance-smoke renders elevated styled admin on fresh host** — No commit (verification only; smoke exits 0 with 6/6 Playwright passes; git status clean)

**Plan metadata:** (see final commit below)

## Files Created/Modified

None — this plan was entirely verification/confirmation. No repository files were modified or created.

## Decisions Made

- **phx_new 1.8.7 pin (SEED-004):** The research flagged 1.8.8 as the blocker; installed 1.8.7 before running any GATE-02 lane. The golden fixture was NOT regenerated (SEED-004 prohibition).
- **PGPORT isolation for smoke:** The smoke script requires system Postgres (port 5432), but `tmp/db.env` exports `PGPORT=58915` (Docker). Running with explicit `PGPORT=5432 PGHOST=localhost` prevents Postgrex from reading the Docker port. This is a local execution pattern, not a change to the smoke script.
- **No installer-template drift commit:** The smoke completed without surfacing any elevated sg-* selector in test/example that was missing from priv/templates/sigra.install/. The `if-drift-fix-commit` path in the plan was not triggered.

## Deviations from Plan

### Environmental Issues (Rule 3 — auto-diagnosed and resolved)

**1. [Rule 3 - Blocking] Stale sigra_admin_smoke_dev database on system Postgres (5432)**
- **Found during:** Task 2 first smoke run
- **Issue:** Prior partial smoke run left a `sigra_admin_smoke_dev` database with an existing `auth` schema; subsequent `mix ecto.drop || true` + `mix ecto.create` recreated the DB but migration failed with `duplicate_table` (auth.users already existed from the prior partial state)
- **Fix:** Dropped both stale DBs (`sigra_admin_smoke_dev` + `sigra_admin_smoke_test`) from system Postgres (port 5432) before re-running; per 204-04 documented pattern
- **Files modified:** None
- **Verification:** Clean smoke run succeeded on retry

**2. [Rule 3 - Blocking] PGPORT=58915 from tmp/db.env interferes with generated-host smoke**
- **Found during:** Task 2 second smoke run (after dropping stale DBs)
- **Issue:** Sourcing `tmp/db.env` at executor start exported `PGPORT=58915` (the ephemeral Docker test Postgres). The smoke script overrides PGUSER/PGPASSWORD/PGHOST but not PGPORT. The generated app's Elixir config has no `port:` key, so Postgrex falls back to `PGPORT` env var. With `PGPORT=58915`, `mix ecto.drop||true` passed (|| true swallows the error), `mix ecto.create` succeeded (Elixir static config ignores PGPORT for mix tasks in some scenarios), but `mix ecto.migrate` failed: "database does not exist" on the Docker Postgres
- **Fix:** Ran smoke with explicit `PGPORT=5432 PGHOST=localhost PGUSER=postgres PGPASSWORD=postgres` to override the inherited Docker port
- **Files modified:** None
- **Verification:** Third smoke run succeeded: exit 0, 6/6 Playwright tests passed

---

**Total deviations:** 2 environmental issues, both auto-diagnosed and resolved without code changes
**Impact on plan:** Environmental pre-conditions only; no code drift found; GATE-02 proven cleanly after environment correction

## Issues Encountered

1. **Stale sigra_admin_smoke_dev DB on system Postgres:** First smoke run hit a `duplicate_table` error on `auth.users`. Researched the 204-04 precedent (same pattern, same fix: drop stale DB before re-running). Dropped both stale smoke DBs and re-ran.
2. **PGPORT env var contamination from tmp/db.env:** Second smoke run hit "database does not exist" on the Docker Postgres (58915). Root cause: `tmp/db.env` exports `PGPORT=58915` which Postgrex reads when no port is in the Elixir config. Fix: explicit `PGPORT=5432` override. This is the correct operational pattern for local smoke execution in this project setup.

Both issues are documented as known patterns for future re-runs (see patterns-established in frontmatter).

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- GATE-02 generated-host parity is fully proven (byte-wise + runtime)
- phx_new 1.8.7 pin is active locally (matches CI pin per SEED-004)
- Ready for Phase 211 Plan 03 (adversarial milestone audit / gsd-audit-milestone)
- No blockers from this plan

---

## Self-Check

### Created files exist:
- `211-02-SUMMARY.md`: being written now (this file)

### Commits: No per-task commits (verification-only plan with no file modifications)

### Self-Check: PASSED

---
*Phase: 211-terminal-ratification*
*Completed: 2026-07-01*
