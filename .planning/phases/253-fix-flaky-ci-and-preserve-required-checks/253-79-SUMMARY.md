---
phase: 253-fix-flaky-ci-and-preserve-required-checks
plan: "79"
subsystem: ci-reliability
tags: [ci-reliability, load-recovery, runner-fix, account-count, re-freeze, r5]
requires:
  - phase: 253-fix-flaky-ci-and-preserve-required-checks
    provides: halted 253-73 R4 lineage and the accepted first_complete R4 window
provides:
  - R5-only schema-qualified account count with bounded redacted psql stderr
  - real-Postgres fail-closed integration test of that count
  - R5 ledger, R4-lineage history reader, carried-first-window binding, freeze create/validate/check, evidence init and path routing
affects: [253-80, 253-81, 253-82, 253-83]
actuals:
  tokens: 26200
  tasks: 3
  commits: 6
plan_head_before: 09c9d1f16795373f9c2be49fdaeaed0c8204e2ab
plan_head_after: 8bc755025b4cc7c9488f7af826c9d8913e6645b7
tech-stack:
  added: []
  patterns: [additive R-revision beside frozen code, injected-deps temp-checkout freeze tests, real-psql positive control]
key-files:
  created:
    - scripts/ci/ci-registration-recovery.pg.test.mjs
  modified:
    - scripts/ci/ci-registration-recovery.mjs
    - scripts/ci/ci-registration-recovery.test.mjs
key-decisions:
  - "R5-only fix, not a shared one (see Decisions Made)"
requirements-completed: ["CIREL-01", "CIREL-02"]
coverage:
  - id: D1
    description: "R5 account count queries the schema-qualified users table, derived from the two frozen sources"
    requirement: CIREL-01
    verification:
      - kind: unit
        ref: "scripts/ci/ci-registration-recovery.test.mjs#R5 account schema is derived from the two frozen sources and must agree"
        status: pass
      - kind: integration
        ref: "scripts/ci/ci-registration-recovery.pg.test.mjs#R5 account count against a real migrated example database"
        status: pass
    human_judgment: false
  - id: D2
    description: "psql stderr is kept bounded and redacted in a sidecar and in the receipt; the verifier names the first error line"
    requirement: CIREL-01
    verification:
      - kind: unit
        ref: "scripts/ci/ci-registration-recovery.test.mjs#R5 verifier names the psql error and rejects wrong query, schema, email and credential forms"
        status: pass
    human_judgment: false
  - id: D3
    description: "R5 ledger carries 2359703 ms, 9 launches, eleven spent identities; accepted first window bound and re-verified; freeze, init and routing"
    requirement: CIREL-02
    verification:
      - kind: unit
        ref: "scripts/ci/ci-registration-recovery.test.mjs#R5 ledger / history reader / carried first window / R5 freeze / R5 paths route"
        status: pass
    human_judgment: false
duration: 55min
completed: 2026-10-14
status: complete
---

# Phase 253 Plan 79: R5 runner count fix, ledger, carry and freeze Summary

**Schema-qualified R5 account count (auth.users) with redacted psql stderr, proven against a real migrated example database, plus the R5 ledger (2359703 ms / 9 launches / 11 spent), R4-lineage history reader, bound accepted first window and R5 freeze/init/routing, all beside untouched v1-R4 code.**

## Performance

- **Duration:** about 55 min
- **Completed:** 2026-10-14T20:48:38Z
- **Tasks:** 3 (tracer, then two auto TDD tasks)
- **Files modified:** 3 (1 created)

## Accomplishments

- Task 1: `accountSchemaR5`, `accountSchemaSourcesR5`, `accountCountQueryR5`, `captureOwnedAccountCountR5` (v2 receipt, `schema_binding`, stderr sha256/bytes/truncated/first line, sibling `.stderr.log`), `captureOwnedDatabaseAbsenceR5` (shared receipt unchanged plus a redacted sidecar), `verifyAccountCountReceiptR5`. The real-Postgres test creates an owned `sigra_253_control_r5itest_*` database through `mix ecto.setup`, shows count 0, inserts one account, shows count 1, reproduces the legacy exit 3 as the positive control, proves a wrong schema fails with a redacted diagnosable error, drops the database and proves absence.
- Task 2: `buildLoadRecoveryLedgerR5`, `loadRecoverySlotDefinitionsR5`, `readLoadHistoryR5` (re-hashes the five R4 lineage files, every raw file and the preserved revision refs, reuses `readLoadHistoryR4`), `carriedFirstWindowR5` (git blob at commit 0596dd97a re-verified through the unchanged R4 verifier, terminal source binding, canonical-JSON attempt equality, raw files and 18 context ids).
- Task 3: `createLoadRecoveryFreezeR5`, `validateLoadRecoveryFreezeR5`, `checkLoadRecoveryFreezeFileR5`, `readCommittedApprovalR5`, `initializeLoadRecoveryEvidenceR5`, `verifyLoadRecoveryFileR5` (clean rejection until 253-80), `--create-load-recovery-r5` and R5 routing of check/init/verify (prepare/run throw a clear "not until 253-80" error).

## Task Commits

1. Task 1 RED `ea4b6ba16`, GREEN `8957bad8f`
2. Task 2 RED `7940e60de`, GREEN `5a60fdab0`
3. Task 3 RED `89db76201`, GREEN `8bc755025`

## Test Counts

- Unit: `ci-registration-recovery.test.mjs` 198 pass / 0 fail / 0 skip (179 pre-existing, assertions unchanged, plus 5 + 8 + 6 new). Together with `ci-playwright-load.test.mjs` (16): 214 pass, 0 fail, 0 skipped.
- Integration (`ci-registration-recovery.pg.test.mjs`, real psql and mix): `# tests 2`, `# pass 2`, `# fail 0`, `# skipped 0`. The first test is the 5-step real-database scenario; the second proves an unreachable Postgres fails with "Postgres unavailable: source tmp/db.env (scripts/db/up.sh)".
- RED was observed before each GREEN (5, 8 and 6 failing tests; the pg test failed with `accountSchemaR5 is not a function` after its `mix ecto.setup` succeeded).
- Leftover-database query after every pg run: empty. `example_test` and `sigra_test` were never connected to.

## Decisions Made

- **R5-only fix, not a shared one.** The carry-forward of the accepted R4 first window depends on the R4 judging code staying byte-identical. v1, R2 and R3 are terminal and never run again, so a shared edit buys nothing. The R4 evidence receipts pin the legacy literal in their `query` field and `readLoadHistoryR5` asserts it as lineage. The reconciliation contracts do not pin the runner blob, so no contract drifts from this plan. The only edits to shared code are two replaced main() routing lines (the check ternary and the verify selector), each gaining an R5 arm; no v1-R4 constant, schema string, function body or message changed (`git diff` shows exactly those 2 removed lines).
- `account_count.schema` in the freeze is the string `auth`; per-attempt count receipts keep their object under `schema_binding`.
- Freeze `plan` field is `253-82` (the plan that creates it); the unit tests use injected seams (`r4Source`, `r4Blob`, `accountSchema`, `carriedFirst`) so the flow runs offline in a temp committed checkout.
- `readCommittedApprovalR5` was added now (mirrors R4) so `--init-load-recovery` for R5 is gated on a committed, budget- and freeze-bound approval from day one. `recordBudgetApprovalR5` is not part of this plan; the later plan that records Jon's decision must add it.

## Raw-SQL Audit

Commands: `grep -nE "SELECT |INSERT INTO|DELETE FROM|FROM users" scripts/ci/*.mjs scripts/ci/*.sh scripts/ci/*.py test/example/priv/playwright/tests/admin-eval.spec.ts`, plus `grep -nEi "psql|select |insert into|from users" test/example/priv/playwright/helpers/registrationControls.mjs test/example/priv/playwright/tests/admin-eval.spec.ts`. Result: only the three queries below in non-test code; the helper and spec send no SQL (empty result).

| Query | Location | Decision |
|---|---|---|
| `DATABASE_ABSENCE_QUERY` (pg_database, maintenance db) | runner ~2209 | Safe: pg_catalog is always on the search path. It dropped stderr; R5 fixes that only through `captureOwnedDatabaseAbsenceR5`. |
| `ACCOUNT_COUNT_QUERY` (`FROM users`) used for prior_collision_absence / created_account at the v1 (~3744/3780), R2 (~4372/4409), R3 (~5287/5324) and R4 (~6053/6090) runners | runner | Unsafe (unqualified relation), frozen: those revisions are terminal and never run again. Not edited. |
| `accountCountQueryR5` (`FROM "auth".users`) | runner, new | Safe; proven on a real migrated database. |

## Deviations from Plan

None - plan executed exactly as written. (One test-authoring slip, a placeholder assertion in the validation test, was corrected before the RED commit.)

## Issues Encountered

None. Planning-time checks reproduced: the R4 first-window revision re-verifies, the context ids number 18, and the real HEAD source delta against the R4 freeze is exactly the runner, its test, the new pg test (changed/added) and the migration (added, blob-equal at the R4 checkout 4fdbc82b4), so `createLoadRecoveryFreezeR5` will accept the current tree in 253-82.

## Known Stubs

None. `verifyLoadRecoveryFileR5` and the R5 prepare/run paths intentionally reject until 253-80 and are documented as such in their error text.

## Out-of-scope Follow-ups (recorded, not acted on)

- Review the `:pending_email` change-email path for the same `unsafe_unique` enumeration leak fixed in 253-57.
- Phase verification (`/gsd-verify-work`) after 253 closes; full Phase253 verification stays not_started.
- Re-apply the Claude-tier config after phase 253 (orchestrator-owned).
- The latent R2-path annotation double count at ~:2357 (known since R4).

## Self-Check: PASSED

- Created: `scripts/ci/ci-registration-recovery.pg.test.mjs` found; modified runner and unit test found.
- Commits ea4b6ba16, 8957bad8f, 7940e60de, 5a60fdab0, 89db76201, 8bc755025 are ancestors of HEAD.
- Plan verification commands re-run: unit 214/214, integration pass 2 skip 0 fail 0, no leftover r5itest database, R3/R4 lineage sha256 unchanged, R4 verify exits 3 with "R4 native load recovery evidence rejected:" and no crash text.
