# Deferred Items — Phase 222

Out-of-scope discoveries logged during execution (not fixed, per SCOPE BOUNDARY —
only issues directly caused by the current task's changes are auto-fixed).

## Plan 01 — pre-existing actionlint/shellcheck warnings in ci.yml

`actionlint .github/workflows/ci.yml` reports 5 pre-existing shellcheck warnings at
unrelated `run:` blocks, confirmed present on `main` before this plan's changes
(same warnings, shifted by 5 line numbers to account for this plan's insertions):

- `SC2209` (`mix.sigra.fixture.rebless_golden --check` line) — unrelated to upgrade-smoke.
- `SC2010` (`ls | grep` pattern) x2 — unrelated jobs.
- `SC2034` (`status appears unused`) x2 — unrelated jobs.

None of these touch the `fast_checks` or `upgrade_smoke` jobs modified by Plan 01/02.
Verified via `git stash` diff: identical warning set exists on the pre-plan baseline.
Not fixed — out of scope for HARD-01 (upgrade-smoke resolver hardening).
