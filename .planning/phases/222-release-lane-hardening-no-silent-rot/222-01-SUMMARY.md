---
phase: 222-release-lane-hardening-no-silent-rot
plan: 01
subsystem: infra
tags: [ci, bash, shellcheck, upgrade-smoke, hex, release-lane]

requires:
  - phase: 221-unblock-gate-ship-honest-generated-host-debt
    provides: "the SIGRA_UPGRADE_SMOKE_START_VERSION D-13 stopgap pin (1.3.0) that this plan retires"
provides:
  - "a durable, self-maintaining resolve_latest_sigra_source stray-exclusion (scripts/ci/lib/resolve-sigra-source.sh)"
  - "an offline, hermetic self-test proving the resolver never selects a known immutable Hex stray"
  - "removal of the hand-maintained SIGRA_UPGRADE_SMOKE_START_VERSION pin from ci.yml"
  - "extended phase_147 structural coverage locking both the pin-absence and the new resolver artifact"
affects: [223-get-current-on-hex-terminal-currency-proof]

tech-stack:
  added: []
  patterns:
    - "sourceable scripts/ci/lib/*.sh helper mirroring free-port.sh / mix-deps-get-retry.sh"
    - "offline hermetic *.test.sh self-test with a stub `mix` on PATH, mirroring app-css-corruption-check.test.sh"

key-files:
  created:
    - scripts/ci/lib/resolve-sigra-source.sh
    - scripts/ci/upgrade-smoke.test.sh
    - .planning/phases/222-release-lane-hardening-no-silent-rot/deferred-items.md
  modified:
    - scripts/ci/upgrade-smoke.sh
    - .github/workflows/ci.yml
    - test/sigra/planning/phase_147_upgrade_migration_lanes_test.exs

key-decisions:
  - "Exact-line fixed-string exclusion (grep -vxF) via SIGRA_UPGRADE_SMOKE_EXCLUDE_VERSIONS (default 1.20.0, comma-configurable) replaces the D-03 retired-filter mechanism, which RESEARCH Finding 1 proved matches zero rows against live Hex output."
  - "SIGRA_UPGRADE_SMOKE_START_VERSION escape hatch and the resolve_latest_sigra_source function name are preserved unchanged in upgrade-smoke.sh, per phase_147 structural test contract."
  - "Pre-existing, unrelated actionlint/shellcheck warnings in ci.yml (confirmed present on baseline main) are logged to deferred-items.md rather than fixed, per SCOPE BOUNDARY."

requirements-completed: [HARD-01]

coverage:
  - id: D1
    description: "resolve_latest_sigra_source durably excludes the stray 1.20.0 and selects the real GA 1.3.0, with a comma-configurable exclusion list and fail-closed behavior on an empty candidate set"
    requirement: "HARD-01"
    verification:
      - kind: unit
        ref: "scripts/ci/upgrade-smoke.test.sh (Cases A-D)"
        status: pass
    human_judgment: false
  - id: D2
    description: "the ci.yml upgrade_smoke job no longer carries the SIGRA_UPGRADE_SMOKE_START_VERSION D-13 stopgap pin, and the escape hatch + resolver function name survive in upgrade-smoke.sh"
    requirement: "HARD-01"
    verification:
      - kind: unit
        ref: "test/sigra/planning/phase_147_upgrade_migration_lanes_test.exs#147-01"
        status: pass
    human_judgment: false

duration: 9min
completed: 2026-07-11
status: complete
---

# Phase 222 Plan 01: Retire the D-13 stopgap pin with a durable stray-exclusion resolver Summary

**Extracted the upgrade-smoke version resolver into a sourceable lib with an exact-line stray-exclusion (`grep -vxF`, `SIGRA_UPGRADE_SMOKE_EXCLUDE_VERSIONS`, default `1.20.0`), proved it offline with a 4-case hermetic self-test, and removed the hand-maintained `SIGRA_UPGRADE_SMOKE_START_VERSION: "1.3.0"` pin from ci.yml.**

## Performance

- **Duration:** 9 min
- **Started:** 2026-07-10T23:58:01Z
- **Completed:** 2026-07-11T00:06:47Z
- **Tasks:** 2
- **Files modified:** 6 (3 created, 3 modified)

## Accomplishments
- New `scripts/ci/lib/resolve-sigra-source.sh`: sourceable resolver lib (mirrors `free-port.sh`) carrying `validate_source_series`, `series_regex`, `resolve_latest_sigra_source`, `validate_override_version`, with the durable stray-exclusion inserted between the series filter and `sort -V | tail -1`.
- New `scripts/ci/upgrade-smoke.test.sh`: offline hermetic self-test (stub `mix` on PATH, no network) proving all four RESEARCH Finding 1 cases — default exclusion picks the real GA, comma-configurable exclusion list, fail-closed on empty candidates, series regex unaffected by exclusion.
- Wired the new self-test into `ci.yml`'s `fast_checks` job alongside the sibling `*.test.sh` guards.
- Removed the `SIGRA_UPGRADE_SMOKE_START_VERSION: "1.3.0"` env pin and its Phase 221 / D-13 comment block from the `upgrade_smoke` job in `ci.yml` — `grep -c SIGRA_UPGRADE_SMOKE_START_VERSION ci.yml` is now 0.
- Extended `phase_147_upgrade_migration_lanes_test.exs` (test "147-01") with a `refute` on the pin string and an `assert` that the resolver lib carries the exclusion env, while keeping all pre-existing resolver/escape-hatch assertions intact.

## Task Commits

Each task was committed atomically:

1. **Task 1: Extract the version resolver into a sourceable lib with a durable stray-exclusion + offline self-test** - `c3633edf` (feat)
2. **Task 2: Remove the ci.yml:643 D-13 stopgap pin and extend the phase_147 structural test** - `6f11c6be` (fix)

## Files Created/Modified
- `scripts/ci/lib/resolve-sigra-source.sh` - sourceable resolver lib with the durable `grep -vxF` stray-exclusion
- `scripts/ci/upgrade-smoke.sh` - now sources the lib; call site and escape hatch unchanged
- `scripts/ci/upgrade-smoke.test.sh` - offline self-test, 4 cases (A-D), stub `mix` on PATH
- `.github/workflows/ci.yml` - self-test wired into `fast_checks`; D-13 pin + comment removed from `upgrade_smoke`
- `test/sigra/planning/phase_147_upgrade_migration_lanes_test.exs` - extended structural assertions (pin absent, exclusion env present)
- `.planning/phases/222-release-lane-hardening-no-silent-rot/deferred-items.md` - logged 5 pre-existing unrelated actionlint/shellcheck warnings (out of scope)

## Decisions Made
- Used the exact `grep -vxF -f <(printf '%s\n' "${exclude_arr[@]}")` shape from RESEARCH Finding 1, converting the comma-separated exclusion list to a bash array (`IFS=',' read -ra`) instead of unquoted word-splitting, to keep shellcheck clean (avoids SC2086) without changing behavior.
- Added `# shellcheck disable=SC2329` above the test script's trap-invoked `cleanup()` function — a local shellcheck 0.11.0 false positive ("function never invoked") that also reproduces identically on the pre-existing, mirrored `app-css-corruption-check.test.sh` pattern. Scoped the disable to the new file only; did not touch the pre-existing file (out of scope).
- Logged, but did not fix, 5 pre-existing actionlint/shellcheck warnings in unrelated `ci.yml` jobs (confirmed present on baseline `main` via `git stash` diff before this plan's changes) — out of scope per SCOPE BOUNDARY.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] shellcheck SC2086 risk in the exclusion-list expansion**
- **Found during:** Task 1 (writing `resolve_latest_sigra_source`'s exclusion logic)
- **Issue:** The RESEARCH-cited snippet uses unquoted `${exclude//,/ }` word-splitting to feed `grep -vxF -f <(...)`, which shellcheck flags as SC2086 (unquoted expansion).
- **Fix:** Split the comma-separated exclusion string into a bash array via `IFS=',' read -ra exclude_arr <<<"${exclude}"` and passed `"${exclude_arr[@]}"` (quoted) to `printf` instead — same behavior, shellcheck-clean.
- **Files modified:** scripts/ci/lib/resolve-sigra-source.sh
- **Verification:** `shellcheck scripts/ci/lib/resolve-sigra-source.sh` exits 0; all 4 self-test cases still pass.
- **Committed in:** c3633edf (Task 1 commit)

**2. [Rule 3 - Blocking] shellcheck SC2329 false positive on trap-invoked cleanup()**
- **Found during:** Task 1 (writing `scripts/ci/upgrade-smoke.test.sh`, mirroring the `app-css-corruption-check.test.sh` pattern per the plan's `read_first`)
- **Issue:** Local shellcheck 0.11.0 flags the `cleanup()` function (invoked only via `trap cleanup EXIT`) as "never invoked" (SC2329). Confirmed this is a version-dependent false positive: the identical pattern in the pre-existing, committed `app-css-corruption-check.test.sh` reproduces the same warning locally.
- **Fix:** Added a scoped `# shellcheck disable=SC2329` comment above `cleanup()` in the new file only.
- **Files modified:** scripts/ci/upgrade-smoke.test.sh
- **Verification:** `shellcheck scripts/ci/lib/resolve-sigra-source.sh scripts/ci/upgrade-smoke.test.sh` exits 0.
- **Committed in:** c3633edf (Task 1 commit)

---

**Total deviations:** 2 auto-fixed (both Rule 3 - blocking shellcheck findings needed to satisfy the plan's own verify command).
**Impact on plan:** Both fixes are mechanical shellcheck-compliance adjustments with no behavior change. No scope creep.

## Issues Encountered
- `actionlint .github/workflows/ci.yml` reports 5 pre-existing shellcheck warnings at unrelated `run:` blocks (line numbers shift by the 5 lines this plan inserted, but the warning set is identical). Verified via `git stash` that these exist on baseline `main` before this plan's changes. Logged to `deferred-items.md`, not fixed — out of scope for HARD-01 (upgrade-smoke resolver hardening). The plan's own verify command (`actionlint .github/workflows/ci.yml`) is understood to pass modulo this pre-existing, unrelated noise; no new actionlint findings were introduced by this plan's edits.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- HARD-01's resolver half is done: the stray `1.20.0` can never again silently win version resolution, and the mechanism is self-maintaining (no future hand-maintained floor needed for new real releases).
- Plan 02 owns the loud-red-main-signal half of HARD-01 (PR-visibility / notify-on-red-main) and HARD-02 (release-please auto-publish verification + runbook) — no blockers from this plan.
- The 5 pre-existing unrelated actionlint/shellcheck warnings logged in `deferred-items.md` remain available for a future maintenance pass; they do not block Phase 222 or 223.

---
*Phase: 222-release-lane-hardening-no-silent-rot*
*Completed: 2026-07-11*

## Self-Check: PASSED

All created files verified present on disk; both task commits (`c3633edf`, `6f11c6be`) verified present in `git log --oneline --all`.
