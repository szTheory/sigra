---
phase: 204-terminal-ratification
plan: "04"
subsystem: testing
tags: [playwright, install-golden, generated-host, phx_new, admin-ui, parity]

requires:
  - phase: 204-03
    provides: pill-contrast fix and mobile baseline recapture

provides:
  - "Install-golden byte-diff green against phx_new 1.8.7 pin (D-12 / SEED-004)"
  - "admin-acceptance-smoke.sh exit 0 on freshly generated phx_new 1.8.7 host (generated-host runtime parity)"
  - "Playwright assertion: styled elevated admin renders on generated host (post-pill-fix bar)"
  - "RATIFY-01 generated-host parity obligation closed"

affects: [204-05]

tech-stack:
  added: []
  patterns:
    - "Verification-only plan: no source changes, all proof via test suite execution"
    - "Generated-host parity proven two ways: byte-diff (install-golden) + runtime (admin-acceptance-smoke)"

key-files:
  created: []
  modified: []

key-decisions:
  - "204-04: Install-golden byte-diff is green against phx_new 1.8.7 (no archive drift, no fixture regeneration needed — SEED-004 / CLAUDE.md prohibition honored)"
  - "204-04: admin-acceptance-smoke.sh exit 0 on a freshly generated host — Playwright confirms styled elevated admin renders (generated-host runtime parity / RATIFY-01 closed)"
  - "204-04: Stale sigra_admin_smoke_dev DB on system Postgres (port 5432) from a prior partial run caused the first smoke invocation to fail ecto.migrate; dropped manually; second run clean"

requirements-completed: [RATIFY-01]

coverage:
  - id: D1
    description: "install-golden byte-diff suite green against phx_new 1.8.7 pin — no installer template or fixture was modified"
    requirement: RATIFY-01
    verification:
      - kind: integration
        ref: "test/sigra/install/golden_diff_test.exs — 2 tests, 0 failures"
        status: pass
    human_judgment: false
  - id: D2
    description: "admin-acceptance-smoke.sh scaffolds a fresh phx_new 1.8.7 host, installs Sigra, boots, and Playwright confirms styled elevated admin renders"
    requirement: RATIFY-01
    verification:
      - kind: e2e
        ref: "scripts/ci/admin-acceptance-smoke.sh --test chrome — 1 passed (1.3s), exit 0"
        status: pass
    human_judgment: false

duration: 5min
completed: 2026-06-27
status: complete
---

# Phase 204 Plan 04: Generated-Host Parity Proof Summary

**Byte-diff green (phx_new 1.8.7) + admin-acceptance-smoke exit 0 — freshly generated host renders the elevated styled admin, closing RATIFY-01 generated-host parity**

## Performance

- **Duration:** ~5 minutes
- **Started:** 2026-06-27T03:54:08Z
- **Completed:** 2026-06-27T03:58:42Z
- **Tasks:** 2
- **Files modified:** 0 (verification-only plan)

## Accomplishments

- `mix archive | grep phx_new` confirms `phx_new-1.8.7` (CI pin) — no newer archive drift
- `MIX_ENV=test mix test test/sigra/install/golden_diff_test.exs` — 2 tests, 0 failures; byte-diff green
- `scripts/ci/admin-acceptance-smoke.sh --test chrome` exits 0: scaffolds fresh Phoenix app, installs Sigra, migrates, seeds, boots on port 4017, all HTTP parity probes pass (non-5xx), Playwright assertion "generated host admin shell renders on desktop and mobile" passes (920ms)
- No installer templates (`priv/templates/`) or golden fixtures (`test/sigra/install/`) modified — prohibition honored

## Task Commits

This was a verification-only plan (no source changes). No per-task commits were created.

## Files Created/Modified

None — this plan is a proof-only plan with `files_modified: []` in its frontmatter.

## Decisions Made

- 204-04: Install-golden byte-diff is green against phx_new 1.8.7 with no archive drift and no fixture regeneration needed (SEED-004 / CLAUDE.md prohibition honored)
- 204-04: admin-acceptance-smoke.sh exit 0 on a freshly generated host — Playwright confirms styled elevated admin renders (generated-host runtime parity / RATIFY-01 closed)
- 204-04: Stale sigra_admin_smoke_dev DB on system Postgres (port 5432) from a prior partial run caused the first smoke invocation to fail ecto.migrate; dropped manually; second run clean

## Deviations from Plan

None - plan executed exactly as written. The only operational wrinkle was a stale `sigra_admin_smoke_dev` database on port 5432 from a prior smoke run that caused `mix ecto.migrate` to fail on the first attempt (duplicate table). This was resolved by dropping the stale DB manually (`psql -c "DROP DATABASE IF EXISTS sigra_admin_smoke_dev"`) — not a code defect and no plan deviation.

## Issues Encountered

**Stale smoke DB on port 5432:** The `admin-acceptance-smoke.sh` script connects to system Postgres on port 5432 (default, no PGPORT passed). A prior partial run left a `sigra_admin_smoke_dev` database with stale schema. The script's `mix ecto.drop || true` ran but the DB was recreated without a clean drop (the `|| true` swallowed any drop error). Resolution: manually dropped the stale DB, re-ran the script, it succeeded cleanly. Not a regression — the smoke's `rm -rf` of `TMP_APP_DIR` removes generated source but not the Postgres database.

## Next Phase Readiness

- RATIFY-01 is closed: generated-host parity proven byte-wise (install-golden) and at runtime (admin-acceptance-smoke)
- Plan 05 can proceed with final ratification / milestone closeout
- No blockers

---

## Self-Check

**Files:**
- SUMMARY.md created at `.planning/phases/204-terminal-ratification/204-04-SUMMARY.md` ✓

**Verification evidence:**
- 2 install-golden tests, 0 failures ✓
- 1 Playwright test passed (exit 0) ✓
- git status clean for priv/templates/ and test/sigra/install/ ✓

## Self-Check: PASSED

---
*Phase: 204-terminal-ratification*
*Completed: 2026-06-27*
