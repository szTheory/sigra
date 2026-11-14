---
phase: 236-flake-root-cause-reproduce-name-fix
plan: 03
subsystem: testing
tags: [ci, playwright, prohibition-guard, node-test, ci-yml]

requires:
  - phase: 236-flake-root-cause-reproduce-name-fix (plan 01)
    provides: "The reproduction profile (80 uncontended attempts, 0 failures; 50 contended attempts, 41 failures) that motivates why a retry wrapper would have masked this exact flake"
provides:
  - "scripts/ci/prohibitions/p17-no-playwright-retry-wrapper.test.mjs, observed RED against a committed known-bad fixture and GREEN against the real playwright.config.ts"
  - "Deletion of the dead PLAYWRIGHT_RETRIES: 1 env key from ci.yml, proven absent by a parsed contract test"
  - "Corrected STACK.md claims that flaky-run traces already exist (they never did)"
  - "p17/p18 guard-number collision pre-resolved before Phase 241 is written"
affects: [241]

actuals:
  tokens: 6600
  tasks: 3
  commits: 4

tech-stack:
  added: []
  patterns:
    - "Six-pattern retryWrapperIssue(text) pure checker applied uniformly to the substitutable config subject and every real spec file, deliberately not split by artifact type (per D-24's one-substitutable-subject doctrine)"
    - "Two non-vacuity floors (retries: line located; >=10 spec files found) with the repo-wide 'the parse broke, this is not a pass' message convention"

key-files:
  created:
    - scripts/ci/prohibitions/p17-no-playwright-retry-wrapper.test.mjs
    - test/fixtures/prohibitions/p17-playwright-retry-wrapper.ts
    - test/sigra/planning/phase_236_retry_wrapper_prohibition_test.exs
  modified:
    - .github/workflows/ci.yml
    - .planning/research/STACK.md
    - .planning/REQUIREMENTS.md
    - .planning/ROADMAP.md

key-decisions:
  - "retryWrapperIssue(text) is one shared pure function, applied to both the config subject and every real spec file's text, rather than split 'config patterns' vs 'spec patterns' — per the plan's explicit prohibition, since the D-26 fixture packs all three violation flavors into one substitutable file and a split checker would leave it unable to go RED on flavors only checked against real (clean) specs."
  - "Pattern 1 ('no retries: line found') is enforced as its own dedicated non-vacuity-floor test scoped to the config subject only, not applied to spec files (which never declare retries:) — this reconciles 'all six patterns apply to the substituted subject text' with not falsely flagging every clean spec file for lacking a retries: declaration it was never supposed to have."
  - "PLAYWRIGHT_RETRIES deleted, not wired (D-28) — wiring it would have made the flagship generated-host parity job actually retry, instantly violating the p17 guard written in this same plan."

requirements-completed: [GREEN-02]

coverage:
  - id: D1
    description: "p17 guard mechanically enforces 'no retry wrapper' and is observed RED against a committed known-bad fixture and GREEN against the real config"
    requirement: "GREEN-02"
    verification:
      - kind: unit
        ref: "node --test scripts/ci/prohibitions/p17-no-playwright-retry-wrapper.test.mjs (GSD_PROHIB_SUBJECT=fixture => exit 1; unset => exit 0)"
        status: pass
      - kind: unit
        ref: "node --test --test-reporter=tap scripts/ci/prohibitions/*.test.mjs (71/71 pass, shared glob unaffected)"
        status: pass
    human_judgment: false
  - id: D2
    description: "Dead PLAYWRIGHT_RETRIES env key deleted from ci.yml with zero other workflow edits, absence proven by a parsed contract test"
    requirement: "GREEN-02"
    verification:
      - kind: unit
        ref: "test/sigra/planning/phase_236_retry_wrapper_prohibition_test.exs (7/7 pass)"
        status: pass
      - kind: other
        ref: "git diff HEAD~4..HEAD~3 -- .github/workflows/ci.yml (exactly one deleted line, zero additions)"
        status: pass
    human_judgment: false
  - id: D3
    description: "STACK.md no longer claims flaky-run traces already exist; p17/p18 guard-number collision pre-resolved in REQUIREMENTS.md and ROADMAP.md"
    verification:
      - kind: other
        ref: "grep -c 'traces that already exist' .planning/research/STACK.md == 0; grep -n p17-/p18- REQUIREMENTS.md ROADMAP.md"
        status: pass
    human_judgment: false

duration: 55min
completed: 2026-09-15
status: complete
---

# Phase 236 Plan 03: Prohibition Guard + Dead Env Var Summary

**Added `p17-no-playwright-retry-wrapper.test.mjs` — observed RED against a committed known-bad fixture and GREEN against the real Playwright config — deleted the dead `PLAYWRIGHT_RETRIES: 1` env key from `ci.yml` with zero other workflow edits, and corrected two now-false "traces already exist" claims in `STACK.md`.**

## Performance

- **Duration:** 55 min
- **Tasks:** 3 (all `type="auto"`)
- **Files created:** 3 — `p17-no-playwright-retry-wrapper.test.mjs`, `p17-playwright-retry-wrapper.ts`, `phase_236_retry_wrapper_prohibition_test.exs`
- **Files modified:** 4 — `.github/workflows/ci.yml`, `.planning/research/STACK.md`, `.planning/REQUIREMENTS.md`, `.planning/ROADMAP.md`

## Accomplishments

- Wrote `scripts/ci/prohibitions/p17-no-playwright-retry-wrapper.test.mjs`: a `retryWrapperIssue(text)` pure checker for six retry-wrapper patterns (non-zero `retries`, `retries` sourced from `process.env`, a per-project `retries:` override, `test.describe.configure({ retries`, `page.waitForTimeout(`, `test.slow(`), applied uniformly to the one substitutable subject (`test/example/priv/playwright/playwright.config.ts`, via `GSD_PROHIB_SUBJECT`) and to every real `tests/*.spec.ts` (20 files at HEAD, read via `readdirSync` + `readRepoFile`, never through `readSubject`). Two non-vacuity floors guard against a silently-passing checker.
- Observed and recorded BOTH halves in `236-EVIDENCE.md`'s new `AFTER-P17-GUARD-OBSERVED` slot: RED (exit 1, named message: `a `retries` value is read from `process.env` — recovering a failed attempt via an env-controlled retry count masks the isolation evidence a flake investigation depends on`) against the committed known-bad fixture `test/fixtures/prohibitions/p17-playwright-retry-wrapper.ts`, and GREEN (exit 0) against the real, unmodified config. The shared `node --test scripts/ci/prohibitions/*.test.mjs` glob passes 71/71 with the new guard added.
- Deleted the single dead `PLAYWRIGHT_RETRIES: 1` line from `ci.yml` (D-28) — zero other workflow edits. Added `phase_236_retry_wrapper_prohibition_test.exs`: a parsed contract (job-block walk, not a bare grep count) proving the key is gone, the surviving `env:` keys (`PGUSER`/`PGPASSWORD`/`PGHOST`/`GITHUB_WORKSPACE`) are unchanged, the step's `env:` block itself survives (so deleting the whole step can't pass silently), the `p17` guard's only CI entry point (`ci.yml:393`'s `node --test --test-reporter=tap scripts/ci/prohibitions/*.test.mjs` glob) is intact, and `mix.exs`'s `ci:` alias never references `scripts/ci/prohibitions`.
- Corrected `STACK.md` at both sites that falsely claimed flaky-run traces already exist and can be harvested — `playwright.config.ts:59` hardcodes `retries: 0`, so `trace: 'on-first-retry'` never fires on a first-attempt failure, and `PLAYWRIGHT_RETRIES` had zero readers before this plan deleted it. Replaced both with the true statement, citing 236-01's actual reproduction path (`236-EVIDENCE.md`'s `BEFORE-FLAKE-RED` slot).
- Pre-resolved the `p17`/`p18` guard-number collision: Phase 241's still-unwritten SURF-04 renamed from `p17-*` to `p18-*` in one line each in `.planning/REQUIREMENTS.md` and `.planning/ROADMAP.md`, scope and wording otherwise unchanged.

## Task Commits

Each task was committed atomically:

1. **Task 1: Write the `p17` guard and its committed known-bad fixture, observe the RED** — `aa2ec673` (test)
2. **Task 2: Delete the dead `PLAYWRIGHT_RETRIES` env key and prove its absence** — `39b6591a` (fix)
3. **Task 3: Correct STACK.md's false trace claims and pre-resolve the p17/p18 collision** — `206c1209` (docs)

**Deviation fix:** `dd4251c4` (fix) — `mix format` applied to the ExUnit contract test after `MIX_ENV=test mix ci` caught a formatting violation (Rule 3 auto-fix, see Deviations below).

**Plan metadata:** committed alongside this SUMMARY (see below).

## Files Created/Modified

- `scripts/ci/prohibitions/p17-no-playwright-retry-wrapper.test.mjs` — the guard
- `test/fixtures/prohibitions/p17-playwright-retry-wrapper.ts` — committed known-bad fixture (all three violation flavors in one file)
- `test/sigra/planning/phase_236_retry_wrapper_prohibition_test.exs` — parsed contract proving the env-key deletion
- `.github/workflows/ci.yml` — one line deleted (`PLAYWRIGHT_RETRIES: 1`)
- `.planning/research/STACK.md` — two false "traces already exist" claims corrected
- `.planning/REQUIREMENTS.md`, `.planning/ROADMAP.md` — `p17-*` → `p18-*` for Phase 241's SURF-04

## Decisions Made

See `key-decisions` in frontmatter. Most consequential: `retryWrapperIssue(text)` stays one shared function applied identically to the config subject and every spec, per the plan's explicit "do not split by artifact type" instruction — reconciled with the reality that spec files never declare `retries:` by scoping the "no retries: line found" non-vacuity floor to the config subject alone, as its own dedicated test rather than folding it into every text the shared checker evaluates.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] `mix format` violation in the new ExUnit contract test**
- **Found during:** Running `MIX_ENV=test mix ci` (the plan's own verification step) after Task 2's commit.
- **Issue:** `test/sigra/planning/phase_236_retry_wrapper_prohibition_test.exs` had a multi-line `flunk(...)` call and a multi-item `for key <- [...]` list that `mix format --check-formatted` collapses/wraps differently than what was written, failing the format gate.
- **Fix:** Ran `mix format test/sigra/planning/phase_236_retry_wrapper_prohibition_test.exs`. No behavior change; 7/7 tests still pass.
- **Files modified:** `test/sigra/planning/phase_236_retry_wrapper_prohibition_test.exs`
- **Verification:** `MIX_ENV=test mix test test/sigra/planning/phase_236_retry_wrapper_prohibition_test.exs` — 7/7 pass; `mix format --check-formatted` clean on re-run.
- **Committed in:** `dd4251c4`

**2. [Rule 1 - Bug, environmental] Stale threadline compile artifact caused 9 spurious test failures on first `mix ci` attempt**
- **Found during:** First `MIX_ENV=test mix ci` run.
- **Issue:** `test/sigra/audit/forwarders/threadline_test.exs` (9 tests, unrelated to this plan's files) failed with `UndefinedFunctionError` on `Sigra.Audit.Forwarders.Threadline.attach/1` because the conditionally-compiled `Threadline` module had gone stale in `_build/test` relative to the `threadline` dependency. This exact issue and fix are already documented in plan 236-02's SUMMARY as a known transient local build-cache artifact, not a code or dependency defect.
- **Fix:** `MIX_ENV=test mix deps.compile threadline --force && MIX_ENV=test mix compile --force` (matching 236-02's documented resolution). No source change.
- **Files modified:** none (build artifact only).
- **Verification:** `MIX_ENV=test mix test test/sigra/audit/forwarders/threadline_test.exs` — 6/6 pass after the recompile; re-ran full `mix ci` afterward and the threadline failures did not recur.
- **Committed in:** N/A (no source change to commit).

---

**Total deviations:** 2 (1 Rule 3 auto-fix, 1 environmental Rule 1 recompile with no code change).
**Impact on plan:** None on scope. Both fixes were necessary for `mix ci` to run cleanly and neither touched files outside this plan's declared scope beyond the one test file the formatter itself rewrote.

## Issues Encountered

**Pre-existing, out-of-scope `mix ci` red (confirmed, not caused by this plan):** `MIX_ENV=test mix ci` still exits non-zero after this plan's changes, with exactly 3 test failures — all in `test/sigra/planning/phase_235_fast_01_gap_closure_contract_test.exs` and `phase_235_fast_01_source_complete_contract_test.exs`. These assert against v1.47-era `REQUIREMENTS.md` content (`FAST-01`, `GATE-05`) that was replaced wholesale for v1.48 at `cc6f17e4` (2026-09-15 14:19), over three hours before this phase's first commit. A todo is already filed (`.planning/todos/pending/2026-09-15-phase-235-fast-01-contract-tests-stale-post-v148-rollover.md`) and 236-02's own SUMMARY documents the identical finding. Distinguished from this plan's own diff: none of the 4 commits in this plan touch `REQUIREMENTS.md`'s FAST-01/GATE-05 content or the two stale contract test files. Not fixed here — out of scope per the plan's own file list and per this phase's todo-filing convention.

All other `mix ci` steps (`format --check-formatted`, `deps.get --check-locked`, `deps.unlock --check-unused`, `compile --warnings-as-errors`, `ci.install_golden` [65/65 pass], `sigra.dep_off` [mix.lock unchanged after]) pass cleanly.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- ROADMAP SC-4 is satisfied: a retry wrapper mechanically fails `p17-no-playwright-retry-wrapper.test.mjs`, demonstrated RED against a committed known-bad fixture, and the dead `PLAYWRIGHT_RETRIES: 1` is deleted with a parsed contract proving its absence.
- Zero workflow edits beyond the one-line deletion; `mix ci` alias topology unchanged (never referenced `scripts/ci/prohibitions`, asserted by the new contract test).
- Phase 241's SURF-04 is pre-cleared to claim `p18-*` without colliding with this phase's `p17-*`.
- No blockers for wave 2 close-out. Plan 236-04 (if any) or phase-level verification can proceed.

## Self-Check: PASSED

- `test -f scripts/ci/prohibitions/p17-no-playwright-retry-wrapper.test.mjs` → FOUND
- `test -f test/fixtures/prohibitions/p17-playwright-retry-wrapper.ts` → FOUND
- `test -f test/sigra/planning/phase_236_retry_wrapper_prohibition_test.exs` → FOUND
- `git log --oneline --all | grep -q aa2ec673` → FOUND
- `git log --oneline --all | grep -q 39b6591a` → FOUND
- `git log --oneline --all | grep -q 206c1209` → FOUND
- `git log --oneline --all | grep -q dd4251c4` → FOUND
- `GSD_PROHIB_SUBJECT=test/fixtures/prohibitions/p17-playwright-retry-wrapper.ts node --test scripts/ci/prohibitions/p17-no-playwright-retry-wrapper.test.mjs` → exit 1 (RED confirmed)
- `node --test scripts/ci/prohibitions/p17-no-playwright-retry-wrapper.test.mjs` → exit 0 (GREEN confirmed)
- `node --test --test-reporter=tap scripts/ci/prohibitions/*.test.mjs` → 71/71 pass
- `MIX_ENV=test mix test test/sigra/planning/phase_236_retry_wrapper_prohibition_test.exs` → 7/7 pass
- `grep -c PLAYWRIGHT_RETRIES .github/workflows/ci.yml` → 0
- `grep -c 'traces that already exist' .planning/research/STACK.md` → 0
- `grep -n p17-\|p18- .planning/REQUIREMENTS.md .planning/ROADMAP.md` → both now `p18-*`
- `git status --short` → clean (only pre-existing untracked `.gsd/`, `.planning/milestone.lock`)

---
*Phase: 236-flake-root-cause-reproduce-name-fix*
*Completed: 2026-09-15*
