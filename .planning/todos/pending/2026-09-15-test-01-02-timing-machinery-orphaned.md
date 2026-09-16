---
created: 2026-09-15
source: v1.47 CI-EFFICIENCY milestone audit (re-audit at close)
severity: high
requirements: [TEST-01, TEST-02]
audit_acknowledged: v1.47
resolves_phase: 241
---

# TEST-01/TEST-02: library timing machinery is orphaned at HEAD

`Sigra.CI.ExUnitTimingFormatter` (`test/support/ci/ex_unit_timing_formatter.ex`) and the
`SIGRA_EXUNIT_TIMING_PATH` env contract have **zero references** in `.github/`, `scripts/`,
or `mix.exs`. The only live references are the module itself and its own unit test.

`library_tests_shard` (`.github/workflows/ci.yml:500-548`) is a **single non-matrix job**
whose only test command is `MIX_ENV=test mix ci` (`ci.yml:548`) — no `--partitions`,
no `--formatter`, no two cost-balanced shards. TEST-02's "two shards finish within
comparable time of each other" has no shards to compare.

## How it got here
`git log -S SIGRA_EXUNIT_TIMING_PATH`: 233-01 added it to `ci.yml`; **234-01
`feat(234-01): route CI through contributor gate`** removed it (`ci.yml | 219 +---`).
Phase 235.1 commits that re-wire partition receipts (`c45c5217`, `4b322cfd`) are **not
ancestors of main** — they live on the parked `ci/phase-235-16-source-complete` branch.

## Why the guard did not catch it
`test/sigra/planning/phase_233_library_economics_contract_test.exs:19` was rewritten to
assert `length(Regex.scan(~r/MIX_ENV=test mix ci/, shard)) == 1`, `refute body =~ "mix test"`
for every library job, and `refute workflow =~ "library_tests_scaffold:"`. The TEST-01/02/03
contract now *requires* the single-owner topology — so it passes at HEAD, which is why
Phase 233 re-verified green. The guard blesses the regression rather than detecting it.

## Options
1. Re-wire the formatter + two-shard partition (the work exists on the 235.1 branch).
2. Deliberately retire TEST-01/TEST-02 as superseded by the single-owner `mix ci` design,
   delete the orphaned module, and rewrite the contract test to say so explicitly.

Option 2 is probably right — the single-owner gate delivered the milestone's performance
goal — but it must be a recorded decision, not a silent regression behind a rewritten guard.
