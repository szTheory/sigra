---
phase: 221-unblock-the-gate-ship-honest-generated-host-debt
plan: 02
subsystem: infra
tags: [bash, awk, ci, css, corruption-guard, regression-testing]

# Dependency graph
requires: []
provides:
  - "up.sh --help window widened to 2,26p so --print-env prints with headroom, no code leak"
  - "app-css-corruption-check.sh catches orphan bare values immediately after a ;-terminated :root declaration"
  - "Committed regression fixture + bash driver proving the guard's new behavior, wired into CI"
affects: [221-03, 221-04, 221-05]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "awk state-machine reset: single-line ;-terminated declarations reset last_was_prop=0 (not an opener); only genuine multi-line openers set last_was_prop=1"
    - "RED/GREEN self-test driver pattern mirroring settled-findings-lint.test.sh / stale-render-guard.test.sh — committed fixture proves the gap before the fix lands"

key-files:
  created:
    - test/fixtures/css/orphan_after_terminated_decl.css
    - scripts/ci/app-css-corruption-check.test.sh
  modified:
    - scripts/uat/up.sh
    - scripts/ci/app-css-corruption-check.sh
    - .github/workflows/ci.yml

key-decisions:
  - "up.sh --help widened to sed -n '2,26p' (not 2,30p) — stays strictly inside the comment block ending at line 25; 2,30p would leak 'set -euo pipefail' into --help output (Research Pitfall 3)"
  - "Framed SHIP-02b as hardening (add headroom), not 'un-truncate' — the --print-env line was already printing with zero headroom, not clipped"
  - "Committed a real corrupt CSS fixture + bash driver (not just a golden-diff assertion) so the guard's fix is regression-proof and CI-wired, per D-10"
  - "Patched both awk opener branches (--prop and word:) identically: reset last_was_prop=0 on a trailing ';' (complete single-line decl), keep =1 only for genuine multi-line openers"

requirements-completed: [SHIP-02, SHIP-03]

coverage:
  - id: D1
    description: "up.sh --help prints the --print-env usage line with headroom, and leaks no code lines (set -euo pipefail etc.)"
    requirement: "SHIP-02"
    verification:
      - kind: unit
        ref: "bash scripts/uat/up.sh --help | grep -q -- '--print-env' (exit 0); bash scripts/uat/up.sh --help | grep -q 'set -euo pipefail' (exit 1, no match)"
        status: pass
    human_judgment: false
  - id: D2
    description: "app-css-corruption-check.sh catches an orphan bare value immediately after a ;-terminated :root declaration (previously a false negative), while the real clean app.css still passes"
    requirement: "SHIP-03"
    verification:
      - kind: unit
        ref: "bash scripts/ci/app-css-corruption-check.sh test/fixtures/css/orphan_after_terminated_decl.css (exit 1); bash scripts/ci/app-css-corruption-check.sh (default, exit 0)"
        status: pass
    human_judgment: false
  - id: D3
    description: "Committed regression fixture + bash driver prove the guard's new behavior and are wired into CI as a self-test step"
    requirement: "SHIP-03"
    verification:
      - kind: unit
        ref: "bash scripts/ci/app-css-corruption-check.test.sh (exit 0, 2/2 pass); grep -q 'app-css-corruption-check.test.sh' .github/workflows/ci.yml"
        status: pass
    human_judgment: false

# Metrics
duration: 6min
completed: 2026-07-10
status: complete
---

# Phase 221 Plan 02: Corruption Guard False-Negative + up.sh --help Hardening Summary

**Fixed the app-css-corruption-check.sh awk state machine to reset `last_was_prop` on complete single-line declarations (closing the orphan-after-`;` false negative), proven by a net-new committed fixture + bash driver wired into CI; widened up.sh's `--help` window one line for `--print-env` headroom.**

## Performance

- **Duration:** ~6 min
- **Started:** 2026-07-10T16:36:30Z
- **Completed:** 2026-07-10T16:39:49Z
- **Tasks:** 3
- **Files modified:** 5 (2 created, 3 modified)

## Accomplishments
- `scripts/uat/up.sh --help` now shows the `--print-env` line with one line of headroom (`2,26p` vs `2,25p`), verified to leak no code lines
- Closed a merge-blocking-guard false negative: `app-css-corruption-check.sh` previously absorbed an orphan bare value line into the preceding `;`-terminated declaration's multi-line-continuation branch, silently passing corrupted CSS
- Added a committed regression fixture (`test/fixtures/css/orphan_after_terminated_decl.css`) and a bash self-test driver (`app-css-corruption-check.test.sh`) that assert non-zero exit on the corrupt fixture and 0 on clean CSS — wired into CI immediately after the existing corruption-check step
- Followed a RED-then-GREEN sequence: Task 2 committed the fixture/driver while the guard was still broken (driver failed, proving the gap was real), Task 3 landed the fix and turned it GREEN

## Task Commits

Each task was committed atomically:

1. **Task 1: SHIP-02b — widen the up.sh --help / --print-env window** - `c039f890` (fix)
2. **Task 2: SHIP-03 (RED) — commit regression fixture + bash driver, wire into CI** - `079b2edf` (test)
3. **Task 3: SHIP-03 (GREEN) — reset last_was_prop on single-line declarations** - `0cbb62b7` (fix)

**Plan metadata:** (pending — final docs commit)

_Note: Task 2/3 form a RED/GREEN pair per the plan's explicit instructions, though the plan is not formally `tdd="true"`._

## Files Created/Modified
- `scripts/uat/up.sh` - `--help` printer window widened from `2,25p` to `2,26p` (line 745)
- `test/fixtures/css/orphan_after_terminated_decl.css` - net-new regression fixture: `:root` block with a `;`-terminated decl immediately followed by an orphan bare value
- `scripts/ci/app-css-corruption-check.test.sh` - net-new bash self-test driver (Test A: corrupt fixture flagged; Test B: clean CSS not flagged), executable, mirrors `settled-findings-lint.test.sh` structure
- `scripts/ci/app-css-corruption-check.sh` - both awk opener branches (`--prop` and `word:`) now reset `last_was_prop=0` when the line is a complete single-line declaration (ends in `;`), only setting `=1` for genuine multi-line openers
- `.github/workflows/ci.yml` - added "app.css corruption guard self-test" step immediately after "Check app.css for orphaned corruption" (~line 154)

## Decisions Made
- `up.sh --help` window: `2,26p`, not `2,30p` — verified the comment block truly ends at line 25 (blank line 26, code starts line 27); `2,30p` would have leaked `set -euo pipefail` and other code into `--help` output (Research Pitfall 3)
- Framed the `up.sh` fix as hardening headroom, not "un-truncating" — the line was already printing at zero headroom, not actually clipped, per the plan's own framing note
- Chose a bash driver over ExUnit for the corruption-guard regression proof, matching existing `*.test.sh` self-test precedent (`settled-findings-lint.test.sh`, `stale-render-guard.test.sh`) and keeping the guard's proof colocated with the guard
- Patched both `--prop` and `word:` opener branches identically (not just one) since both feed the same `last_was_prop` state and either could precede an orphan

## Deviations from Plan

None - plan executed exactly as written. The RED confirmation in Task 2's acceptance criteria was explicitly verified (`bash scripts/ci/app-css-corruption-check.sh test/fixtures/css/orphan_after_terminated_decl.css` exited 0 before Task 3), and Task 3 turned it GREEN with no scope changes.

## Issues Encountered

None. The `gsd_run` bash wrapper needed `"$GSD_TOOLS" "$@"` invoked directly (not via `node`) since the resolved shim on this machine is an asdf shim script, not a raw `.cjs` file — resolved before any file edits by re-testing the init-context bootstrap snippet; no impact on plan execution.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- The corruption guard's D-10 regression proof is now a permanent CI gate — the SHIP-03 gap cannot silently reopen
- `up.sh --help` DX nit closed (SHIP-02b)
- No golden-tree impact; Plans 221-03/04/05 (Hex publish + release-lane hardening) are unaffected by and do not depend on this plan's changes

---
*Phase: 221-unblock-the-gate-ship-honest-generated-host-debt*
*Completed: 2026-07-10*

## Self-Check: PASSED

All created/modified files found on disk (`scripts/uat/up.sh`, `test/fixtures/css/orphan_after_terminated_decl.css`, `scripts/ci/app-css-corruption-check.test.sh`, `scripts/ci/app-css-corruption-check.sh`, `.github/workflows/ci.yml`). All 3 task commits (`c039f890`, `079b2edf`, `0cbb62b7`) verified present in `git log`.
